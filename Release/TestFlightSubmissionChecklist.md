# Rush & Risk V1 TestFlight Submission Checklist

Local release candidate: version 1.0, build 1

Bundle identifier: `com.APLDEVO.Rush-or-Risk`

Game Center: deferred for V1

## Before upload

- [ ] On a physical iPhone, complete one owner-controlled low-volume audio test. Audio begins muted and must be explicitly enabled in Settings.
- [ ] Confirm menu music, gameplay music, pause/resume, interruption, backgrounding, and return-to-menu behavior without distortion or duplicate playback.
- [ ] Complete final owner gameplay checks in both iPhone landscape directions.
- [ ] If available, complete a physical iPad layout check. The current local evidence is simulator-only.
- [ ] Confirm the marketing version and build number have not already been used in App Store Connect. Increment the build number if necessary.
- [ ] In Xcode, sign in to the Apple Developer account for team `525SRF9A35` and allow automatic signing to resolve an App Store distribution profile during upload.

## Create the App Store Connect record

The owner performs these steps at App Store Connect; no record has been created by this project work.

1. Open **My Apps**, select **+**, then **New App**.
2. Select **iOS**, enter **Rush & Risk**, choose the primary language, and choose bundle ID `com.APLDEVO.Rush-or-Risk`.
3. Enter a unique internal SKU, select the appropriate user access, and create the record.
4. In **App Information**, choose the primary category **Games** and the most suitable secondary arcade category available.
5. Complete the age-rating questionnaire based on the shipped content.
6. In **App Privacy**, declare **Data Not Collected** only while the V1 build remains fully local and contains no analytics, accounts, advertising, or tracking SDKs.
7. Leave Game Center disabled for V1.
8. Confirm Agreements, Tax, and Banking contain no blocking agreement. TestFlight access may also depend on the owner's App Store Connect role.

## Upload the approved archive

Do this only after explicit owner authorization to upload.

1. Open Xcode **Window > Organizer > Archives**.
2. Select the Rush & Risk 1.0 archive and choose **Distribute App**.
3. Select **App Store Connect**, then **Upload**; keep automatic signing enabled unless Apple requires a manually managed distribution profile.
4. Review signing, entitlements, icon, bundle identifier, version, and build number in Xcode's distribution summary.
5. Upload and wait for App Store Connect processing to finish.
6. If asked about export compliance, confirm the app does not contain non-exempt encryption. `ITSAppUsesNonExemptEncryption` is already set to `NO` in the build.

## Configure TestFlight

1. In the app's **TestFlight** tab, select the processed build.
2. Complete **Test Information**: beta description, what to test, feedback email, contact details, and sign-in information if App Store Connect requests it. The game has no account requirement.
3. Add the build to an **Internal Testing** group first and select only intended internal testers.
4. Install from TestFlight and complete a short release-candidate check: launch, landscape left/right, rapid tap/drag input, scoring, life loss, game over, restart, pause/resume, background/foreground, settings persistence, and owner-controlled audio.
5. For external testers, create an external group, provide Beta App Review information, submit the build for Beta App Review, and invite testers only after approval.

## Stop conditions

- Do not upload if the bundle identifier differs from `com.APLDEVO.Rush-or-Risk`.
- Do not upload if audio is enabled by default, automated modes can produce sound, or distortion returns.
- Do not invite testers until the owner approves the exact processed build.
- Do not merge the release branch into `main` without separate approval.
