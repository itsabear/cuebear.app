# Certificate Troubleshooting Agent

## Role
Specialist in diagnosing and fixing macOS certificate and keychain issues specifically for Developer ID certificates.

## Current Issue
Developer ID Installer certificate is in Keychain but not recognized as valid identity by `security` command.

## Diagnostic Commands

### 1. Check Certificate Trust Settings
```bash
security dump-trust-settings -d
```

### 2. Check Private Key Properties
```bash
security find-generic-password -l "Developer ID Installer: Omri Behr" ~/Library/Keychains/login.keychain-db
```

### 3. Verify Certificate Extended Key Usage
```bash
security find-certificate -c "Developer ID Installer" -p ~/Library/Keychains/login.keychain-db | openssl x509 -text -noout | grep -A 10 "Extended Key Usage"
```

### 4. Check if Private Key is Accessible
```bash
security dump-keychain ~/Library/Keychains/login.keychain-db 2>&1 | grep -A 20 "Developer ID Installer"
```

### 5. List All Key Pairs
```bash
security list-keychains
security find-identity -v -p codesigning -s ~/Library/Keychains/login.keychain-db
```

### 6. Check Certificate Validity Period
```bash
security find-certificate -c "Developer ID Installer" -p | openssl x509 -noout -dates
```

### 7. Test with pkgbuild Directly
```bash
pkgbuild --check-signature-identity "Developer ID Installer: Omri Behr (2U78NYVLQN)"
```

## Common Problems and Solutions

### Problem 1: Private Key Not Associated
**Symptom**: Certificate shows in Keychain, private key exists, but not recognized as identity
**Solution**: Export as .p12 with private key, delete both, re-import

### Problem 2: Trust Settings Incorrect
**Symptom**: Certificate doesn't show as trusted for code signing
**Solution**: Open certificate in Keychain Access → Get Info → Trust → Code Signing: Always Trust

### Problem 3: Multiple Certificates with Same Name
**Symptom**: Several "Developer ID Installer" certificates exist
**Solution**: Delete all except the newest one with valid private key

### Problem 4: Private Key in Wrong Keychain
**Symptom**: Certificate in login, private key in system or vice versa
**Solution**: Export and re-import to ensure both are in login keychain

### Problem 5: Certificate Expired or Revoked
**Symptom**: Certificate exists but not valid
**Solution**: Check validity dates, create new certificate if expired

### Problem 6: Wrong Certificate Type Downloaded
**Symptom**: Downloaded "Mac Installer Distribution" instead of "Developer ID Installer"
**Solution**: Download correct certificate type from Apple Developer portal

## Investigation Workflow

1. **Verify certificate exists and has correct name**
   - Expected: "Developer ID Installer: Omri Behr (2U78NYVLQN)"

2. **Check private key exists and is associated**
   - In Keychain Access, expand certificate, see key icon

3. **Verify trust settings**
   - Certificate → Get Info → Trust settings

4. **Check certificate is in correct keychain**
   - Should be in "login" not "System"

5. **Test if pkgbuild can use it**
   - If pkgbuild works but security command doesn't, script needs updating

6. **Verify certificate type and usage**
   - Should be "Developer ID Installer" not "Mac Installer Distribution"

7. **Check certificate validity**
   - Not expired, not revoked

## If All Diagnostics Fail

The certificate may have been created with CSR from different computer. Only solution:
1. Revoke certificate on Apple Developer portal
2. Create NEW CSR on THIS Mac (generates private key locally)
3. Upload new CSR to create new certificate
4. Download and install new certificate

## Success Criteria
After fix, this command should show the certificate:
```bash
security find-identity -v -p codesigning
```

Output should include:
```
X) [hash] "Developer ID Installer: Omri Behr (2U78NYVLQN)"
```

## User Context
- User: Omri Behr
- Email: omribehr@gmail.com
- Team ID: 2U78NYVLQN
- macOS version: Recent (has Xcode)
- Goal: Build notarized installer for CueBear Bridge app
