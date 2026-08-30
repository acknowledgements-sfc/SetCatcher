# SetCatcher Private Beta — Ad-Hoc Mac Install

This guide is for a small group of trusted testers using the ad-hoc macOS beta. It is not a notarized or Developer ID distribution.

## Before installing

- Confirm the download is `SetCatcher-0.1.0-4a66eaa.zip`.
- Confirm its SHA-256 checksum matches the value supplied with the invitation.
- Keep the previous SetCatcher build until the new build has been verified.
- Do not delete or move original DJ recordings.

## Install

1. Unzip the download and move `SetCatcher.app` to Applications.
2. Open it once. macOS may block the app because this build is not notarized.
3. Open System Settings → Privacy & Security, choose **Open Anyway**, and confirm.
4. Relaunch SetCatcher.

This security override is expected for this private beta. Do not use it if the checksum does not match the invitation.

## Permissions to test

When prompted, grant only the access needed for testing:

- Recording folders through the app’s folder picker.
- Screen & System Audio Recording for app-audio capture tests.
- Microphone only when testing an explicitly enabled hardware or virtual-input route.

Verify that the original recording remains unchanged and that the protected copy appears in the configured SetCatcher archive.

## Upgrade test

If an older DJMemory build was used on the Mac, launch SetCatcher and verify that settings, bookmarks, archive records, and custom archive locations remain available. The migration moves only DJMemory-owned application data and archive data; it does not move source recordings. Keep the old folders until the result is confirmed.

## Report a problem

Include the screen or action, approximate time, DJ software and route, whether a WAV was created, and the visible error message. Do not send audio files or track titles unless separately requested. A diagnostics export should contain metadata only.

## Known limitations

- This build is ad-hoc signed and not notarized; Gatekeeper approval may be required.
- Traktor capture is not claimed in this beta.
- djay’s XDJ hardware path is not claimed until separately verified.
- Live audio success requires both a recorded WAV and human confirmation that the recording contains the expected program audio.

## Uninstall / rollback

Quit SetCatcher and replace the app with the previous retained build. Do not remove `~/Music/SetCatcher` or `~/Library/Application Support/SetCatcher` during testing; those contain the protected archive and app state.
