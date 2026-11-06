# App Store release checklist

Status for version 1.0.0. Items marked **you** need an action from the developer account holder.

## Done in the repository

- [x] App icon (1024 px, no transparency) in `OhMyTranslate/Assets.xcassets`
- [x] Privacy manifests (`PrivacyInfo.xcprivacy`) for the app and the translation extension, declaring no tracking, no collected data, and the UserDefaults API (reason CA92.1)
- [x] Export compliance: `ITSAppUsesNonExemptEncryption = false` (the app only uses standard HTTPS)
- [x] Consent before any text leaves the device (App Store guideline 5.1.2(i)): a sheet that cannot be dismissed by swiping, with "Use On this device" as the alternative
- [x] Privacy policy and terms linked in the app (Settings › About) and in the consent sheet
- [x] "Erase all data" in Settings: removes settings, actions and API keys from the device
- [x] Version 1.0.0, category Productivity, iPhone only (the iPad layout has not been tested)
- [x] Unit tests (Kit) and UI tests with screenshots, run on every push in GitHub Actions
- [x] Unsigned `.ipa` built in CI

## You need to do

- [ ] **Review and publish the legal text.** `docs/PRIVACY.md` and `docs/TERMS.md` are drafts. Complete the bracketed items in TERMS and have a lawyer review both before publishing.
- [ ] **Make the policy URLs live.** The app links to `github.com/jstdlee/mytranslate/blob/main/docs/…`, which works once the repository is public. Alternatively, publish the same text on a website and change `AppLinks` in `OhMyTranslate/Consent.swift`.
- [ ] **Test on a device with a signed build.** Set your team on both targets. Then check, in order: Settings › Apps › Default Apps › Translation › OhMyTranslate; the Translate item in another app's selection menu opens the sheet; Replace writes the text back; the App Group and Keychain share the key with the extension.
- [ ] **App Store Connect listing:** name, subtitle, description, keywords, support URL, privacy policy URL, age rating, and screenshots. The gallery PNGs are 1206 × 2622, which App Store Connect accepts for the 6.3-inch iPhone size.
- [ ] **App privacy labels:** declare *Data Not Collected*, after checking Apple's current guidance on third-party AI services.
- [ ] **Review risk:** Apple's review may question a translation extension whose main use is writing. The translate action is the default, and writing actions are secondary. Be ready to explain this in the review notes.
- [ ] **Decide the iPad question:** keep iPhone only for 1.0, or test and add iPad screenshots and a layout.

## Known limitations for 1.0

- The source menu opens upward, so "Detect language" appears at the bottom of the list.
- Opening search from inside the translation extension depends on the host app allowing it; this is not yet tested on a device.
- Read-aloud is tested only in the simulator.
- Text is in English. The language chips and translations are in their own languages.
