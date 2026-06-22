# Keyring

Keyring is now a native macOS credential vault. The delivered application does
not require a browser, Node.js, Python, or third-party runtime packages.

## Run the native app

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

## First launch

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

## Encrypted backups

Open Settings > Backups:

1. Enter a separate backup password containing at least 12 characters.
2. Choose `Configure Automatic Backups`.
3. Select a local or cloud-synchronized folder.

Automatic retention keeps one snapshot per day for 30 days and one snapshot
per month for 12 months. Manual export, verification, and restore are also
available. Backup files use the `.keyringbackup` extension.

## Migrate from the browser prototype

1. Run the old web prototype with `npm run dev`.
2. Select `Export migration` in its sidebar.
3. Accept the plaintext warning and save the JSON file.
4. In the native app, open Settings > Migration and import the JSON file.
5. Confirm the records were imported, then delete the plaintext JSON and empty
   Trash.
6. Clear site data for the old browser prototype.

The web project remains only to support this one-time migration.

## Security checks

```bash
./script/test_security.sh
```

The checks exercise production PBKDF2, AES-GCM authentication and tamper
detection, recovery-key normalization, encrypted backup round trips, wrong
password rejection, and plaintext exclusion.

## Build requirements

- macOS 14 or later
- Apple Swift 6 / Command Line Tools

Full Xcode is optional for source development but required for conventional
XCTest UI tests, Developer ID signing, notarization, and App Store distribution.
