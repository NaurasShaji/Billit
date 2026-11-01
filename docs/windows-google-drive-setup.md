# Windows Google Drive setup

Windows uses a separate Google OAuth desktop flow. Android continues to use the existing Google Sign-In plugin and is not switched to the Windows implementation.

## Google Cloud configuration

1. Open the Google Cloud project used by Billit.
2. Enable the Google Drive API.
3. Configure the OAuth consent screen and add the intended test users if the app is still in testing.
4. Create an OAuth client ID with application type **Desktop app**.
5. Copy the desktop client ID. A desktop client ID is a public identifier; do not add a client secret to the Flutter app.

## Build Windows

Pass the desktop client ID at build time:

```powershell
flutter pub get
flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_DESKTOP_CLIENT_ID
```

For a release build:

```powershell
flutter build windows --release --dart-define=GOOGLE_DESKTOP_CLIENT_ID=YOUR_DESKTOP_CLIENT_ID
```

The Windows flow opens the system browser, uses an ephemeral localhost callback and PKCE, then stores the refresh token using `flutter_secure_storage`. The app requests the Drive `drive.file` scope plus basic account identity.

## Backup folder migration

The shared Drive folder is now named **Billit**. On the first backup list/upload after updating, the app looks for the previous `FloralBillingBackups` folder and renames it to `Billit` rather than creating a new folder. Existing JSON backups remain in that folder.

## Verification checklist

- Sign in using the Windows app and confirm the account email is shown.
- Close and reopen the app; verify silent session restoration.
- Upload a Windows backup and confirm it appears in the Billit folder.
- Restore an Android-created backup on Windows.
- Restore a Windows-created backup on Android.
- Test disconnect, revoked consent, offline refresh and an expired access token.

A successful Windows build and live OAuth round-trip must be verified locally with the configured desktop client ID before release.
