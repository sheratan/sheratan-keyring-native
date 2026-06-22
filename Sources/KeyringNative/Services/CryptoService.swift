import CommonCrypto
import CryptoKit
import Foundation
import Security

struct CryptoService {
    static let minimumIterations: UInt32 = 600_000

    func randomData(count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        guard status == errSecSuccess else { throw VaultError.corruptedData }
        return data
    }

    func derivePasswordKey(
        password: String,
        configuration: KDFConfiguration
    ) throws -> SymmetricKey {
        guard configuration.iterations >= Self.minimumIterations else {
            throw VaultError.corruptedData
        }
        let passwordData = Data(password.precomposedStringWithCompatibilityMapping.utf8)
        let outputCount = 32
        var output = Data(count: outputCount)
        let result = output.withUnsafeMutableBytes { outputBytes in
            configuration.salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        configuration.salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        configuration.iterations,
                        outputBytes.bindMemory(to: UInt8.self).baseAddress,
                        outputCount
                    )
                }
            }
        }
        guard result == kCCSuccess else { throw VaultError.corruptedData }
        return SymmetricKey(data: output)
    }

    func calibratedIterations(password: String, targetSeconds: Double = 0.6) throws -> UInt32 {
        let sampleIterations = Self.minimumIterations
        let sample = KDFConfiguration(
            iterations: sampleIterations,
            salt: try randomData(count: 32)
        )
        let start = CFAbsoluteTimeGetCurrent()
        _ = try derivePasswordKey(password: password, configuration: sample)
        let elapsed = max(CFAbsoluteTimeGetCurrent() - start, 0.001)
        let estimate = UInt32(min(5_000_000, Double(sampleIterations) * targetSeconds / elapsed))
        return max(Self.minimumIterations, estimate)
    }

    func recoveryKey(from text: String) throws -> SymmetricKey {
        let normalized = text.uppercased().filter(\.isHexDigit)
        guard normalized.count == 64, let bytes = Data(hex: normalized) else {
            throw VaultError.invalidRecoveryKey
        }
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: bytes),
            salt: Data("Keyring Recovery v1".utf8),
            info: Data(),
            outputByteCount: 32
        )
    }

    func generateRecoveryKey() throws -> String {
        try randomData(count: 32).hexString.uppercased().chunked(every: 4).joined(separator: "-")
    }

    func seal(_ data: Data, with key: SymmetricKey, context: String) throws -> SealedPayload {
        let nonce = try AES.GCM.Nonce(data: randomData(count: 12))
        let box = try AES.GCM.seal(data, using: key, nonce: nonce, authenticating: Data(context.utf8))
        guard let combined = box.combined else { throw VaultError.corruptedData }
        return SealedPayload(combined: combined)
    }

    func open(_ payload: SealedPayload, with key: SymmetricKey, context: String) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: payload.combined)
            return try AES.GCM.open(box, using: key, authenticating: Data(context.utf8))
        } catch {
            throw VaultError.corruptedData
        }
    }

    func keyData(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}

extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var result = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let value = UInt8(hex[index..<next], radix: 16) else { return nil }
            result.append(value)
            index = next
        }
        self = result
    }

    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}

extension String {
    func chunked(every size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start..<end])
        }
    }
}
