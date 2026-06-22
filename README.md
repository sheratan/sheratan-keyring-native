# Keyring

This repository contains two applications with different purposes:

| Application | Status | Directory | Intended use |
| --- | --- | --- | --- |
| **Native macOS app** | Current, supported application | `Sources/KeyringNative/` | Store and manage real credentials in an encrypted local vault |
| **Web app** | Legacy migration utility | `src/` | Export records previously saved by the browser prototype for one-time import |

> [!IMPORTANT]
> Use the **native macOS application** for normal credential management. The
> web application stores records unencrypted in browser local storage and must
> not be used as a password manager.

## Which application should I use?

### Use the native macOS app when you want to:

- Create an encrypted credential vault.
- Protect the vault with a master password and recovery key.
- Unlock using Touch ID.
- Store passwords, API keys, tokens, and secure notes.
- Create and restore encrypted backups.
- Use automatic locking and clipboard clearing.

The native app does not require a browser, Node.js, Python, or third-party
runtime packages after it has been built.

### Use the web app only when you need to:

- Access records that were previously saved in the original browser prototype.
- Export those records into the versioned migration JSON format.
- Import that migration file into the native app.

The web app is retained for migration compatibility. It is not receiving the
native app's encryption, backup, Touch ID, or recovery features.

## Repository layout

```text
Sources/KeyringNative/       Native SwiftUI application
Tests/SecurityChecks.swift   Native cryptography and backup checks
script/build_and_run.sh      Build, sign, and launch the native app
script/test_security.sh      Run native security checks

src/                         Legacy React browser migration utility
package.json                 Web utility dependencies and commands
vite.config.js               Web utility build configuration

output/pdf/                  User manual
```

## Native macOS application

### Run the native app

```bash
./script/build_and_run.sh
```

The script builds, packages, ad-hoc signs, and opens:

```text
dist-native/KeyringNative.app
```

Optional modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --debug
```

### First launch

1. Create a master password containing at least 12 characters.
2. Save the generated recovery key offline.
3. Enter the requested recovery-key groups.
4. Open Settings to enable Touch ID and encrypted automatic backups.

The encrypted vault is stored at:

```text
~/Library/Application Support/KeyringNative/vault.keyring
```

It contains an AES-256-GCM encrypted payload, wrapped vault keys, salts, and
version metadata. The master password is never stored.

### Encrypted backups

Open Settings > Backups:

1. Enter a separate backup password containing at least 12 characters.
2. Choose `Configure Automatic Backups`.
3. Select a local or cloud-synchronized folder.

Automatic retention keeps one snapshot per day for 30 days and one snapshot
per month for 12 months. Manual export, verification, and restore are also
available. Backup files use the `.keyringbackup` extension.

## Web migration utility

The web utility requires Node.js only while performing a migration. Start it
with:

```bash
npm install
npm run dev
```

Do not add new real credentials to the web utility.

### Migrate from the browser prototype

1. Run the old web prototype with `npm run dev`.
2. Select `Export migration` in its sidebar.
3. Accept the plaintext warning and save the JSON file.
4. In the native app, open Settings > Migration and import the JSON file.
5. Confirm the records were imported, then delete the plaintext JSON and empty
   Trash.
6. Clear site data for the old browser prototype.

The web project remains only to support this one-time migration.

### Migration-file warning

The exported JSON migration file contains plaintext secrets. Import it into the
native application immediately, verify the imported records, then delete the
file and empty Trash. The native application encrypts imported records before
saving its vault.

## Development and validation

### Native security checks

```bash
./script/test_security.sh
```

The checks exercise production PBKDF2, AES-GCM authentication and tamper
detection, recovery-key normalization, encrypted backup round trips, wrong
password rejection, and plaintext exclusion.

### Web utility checks

```bash
npm run lint
npm run build
```

### Build requirements

- macOS 14 or later
- Apple Swift 6 / Command Line Tools
- Node.js and npm only if the legacy web migration utility is needed

Full Xcode is optional for source development but required for conventional
XCTest UI tests, Developer ID signing, notarization, and App Store distribution.
