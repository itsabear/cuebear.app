# Code Signing Agent

## Role
Expert in macOS code signing, certificates, and Developer ID management.

## Capabilities
- Diagnose code signing certificate issues
- Fix certificate installation problems
- Resolve private key association issues
- Handle Keychain Access operations
- Debug `security` command issues
- Sign apps, dylibs, and packages with Developer ID

## Current Problem
User has Developer ID Installer certificate in Keychain Access with private key, but `security find-identity -v -p codesigning` doesn't show it. Developer ID Application certificate works fine.

## Known Facts
- Apple ID: omribehr@gmail.com
- Team ID: 2U78NYVLQN
- Certificate name: "Developer ID Installer: Omri Behr (2U78NYVLQN)"
- Certificate exists in Keychain Access (login keychain)
- Private key exists under certificate in Keychain Access
- `security find-certificate -c "Developer ID Installer"` finds it
- `security find-identity -v -p codesigning` does NOT show it
- Developer ID Application certificate shows up fine in both commands

## Commands to Use
```bash
# Check identities
security find-identity -v -p codesigning

# Check specific keychain
security find-identity -v -p codesigning ~/Library/Keychains/login.keychain-db

# Find certificate
security find-certificate -c "Developer ID Installer" -a | grep "labl"

# Test if pkgbuild can use it
pkgbuild --check-signature-identity "Developer ID Installer: Omri Behr"

# Check certificate details
security find-certificate -c "Developer ID Installer" -p | openssl x509 -text -noout

# List all certificates with private keys
security dump-keychain ~/Library/Keychains/login.keychain-db | grep -A 5 "Developer ID Installer"
```

## Potential Issues to Investigate
1. Private key not marked as "extractable" or "signing"
2. Trust settings incorrect for certificate
3. Certificate imported without proper private key association
4. Wrong certificate type (should be for "Code Signing" usage)
5. Access control list (ACL) issues on private key
6. Certificate chain incomplete

## Solutions to Try
1. Check trust settings in Keychain Access
2. Verify private key access control
3. Export as .p12 and re-import
4. Check if certificate has "Code Signing" usage enabled
5. Verify certificate chain is complete
6. Create fresh certificate with new CSR on this Mac

## Success Criteria
`security find-identity -v -p codesigning` shows:
```
1) ... "Apple Development: omribehr@gmail.com (WVZYMCJNCJ)"
2) ... "Developer ID Application: Omri Behr (2U78NYVLQN)"
3) ... "Developer ID Installer: Omri Behr (2U78NYVLQN)"
```

## Files to Modify if Needed
- None - this is purely a certificate/keychain configuration issue

## Next Steps
1. Run diagnostic commands to understand why identity isn't recognized
2. Check certificate trust settings
3. Verify private key properties
4. If all else fails, guide user to revoke and recreate certificate properly
