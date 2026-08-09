# Release signing

EchoMeet deliberately refuses to assemble an Android release when upload-key
signing is absent. Debug builds continue to use the local debug key.

1. Create or obtain the Play upload keystore through the release owner.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Fill in the four values. Keep `key.properties` and the keystore private;
   both patterns are ignored by Git.
4. Build the App Bundle and verify the resulting certificate fingerprint before
   uploading it to Play Console.

For iOS, the Apple team, distribution certificate/profile, App Attest
environment, Push Notifications capability, APNs key, and production
`aps-environment` must be configured and verified by the release owner in
Xcode/Apple Developer/Firebase. These credentials are intentionally not stored
in this repository.
