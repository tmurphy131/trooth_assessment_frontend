# Android Release Signing & App Links Guide

## 1. Generate Keystore
keytool -genkeypair -v -keystore keystore.jks -alias troothRelease -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass 'W3@re1T3am' -keypass 'W3@re1T3am' \
  -dname 'CN=Trooth,O=Trooth,L=City,ST=State,C=US'



(Make sure you have a JDK installed; Java 11+ required.)

## 2. Create key.properties
Copy android/key.properties.example to android/key.properties and fill real values:

storeFile=keystore.jks
storePassword=actualStorePassword
keyAlias=troothRelease
keyPassword=actualKeyPassword

## 3. Build Release APK / AAB
flutter build appbundle --release
# or
flutter build apk --release

## 4. Get SHA-256 for App Links
keytool -list -v -keystore keystore.jks -alias troothRelease -storepass 'CHANGE_ME_STRONG' | grep 'SHA-256'

Record the SHA-256; needed for Play Console (Digital Asset Links) and assetlinks.json if self-hosting.

## 5. Sample assetlinks.json (host at https://links.trooth.app/.well-known/assetlinks.json)
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.trooth_assessment",
      "sha256_cert_fingerprints": [
        "YOUR:SHA256:FINGERPRINT:COLON:SEPARATED"
      ]
    }
  }
]

## 6. iOS apple-app-site-association (at https://links.trooth.app/apple-app-site-association)
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.example.trooth_assessment",
        "paths": [ "/agreements/sign/*" ]
      }
    ]
  }
}

Replace TEAMID with your Apple Developer Team ID and update the bundle identifier if you change applicationId.

## 7. Change Application ID (Optional Production Namespace)
Edit android/app/build.gradle.kts -> defaultConfig.applicationId and iOS bundle identifier (Runner) consistently. Also update assetlinks.json & apple-app-site-association accordingly.

## 8. Verify App Links (after install)
adb shell "am start -a android.intent.action.VIEW -d https://links.trooth.app/agreements/sign/test/x"  # Should open the app

## 9. Troubleshooting
- If App Links open browser: Ensure assetlinks.json is reachable (HTTP 200, correct content-type application/json, no HTML wrapping) and SHA-256 matches release cert.
- If signing fails: Check path to keystore in key.properties; should be relative to android/ directory or absolute.
- Clean build: ./gradlew clean (from android/) then rebuild.

## 10. Security Notes
- Never commit key.properties or keystore.jks.
- Rotate keys if leaked; update Play Console with new cert (possible only for upload key if using Play App Signing).
