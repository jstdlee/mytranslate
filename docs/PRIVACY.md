# Privacy Policy

_Last updated: 6 November 2026. This policy describes the OhMyTranslate iPhone app and its translation extension._

**The short version:** OhMyTranslate has no accounts, no analytics and no tracking. It has no server of its own. The text you select is sent only to the engine you choose, and only when you tap an action. You can choose an engine that never sends anything off your iPhone.

## What the app stores on your iPhone

- **Settings:** your language choices, action list, search engine, chosen engine and model, and whether you allowed text to be sent. Stored in the app's App Group container on your device.
- **API keys:** your Claude or OpenAI-compatible key is stored in the iOS Keychain on your device. It is never written to a file or sent to us.
- **Nothing else.** The app does not keep a history of what you translated, and it does not keep copies of your text.

You can remove all of this at any time: **Settings › Your data › Erase all data**, or by deleting the app.

## When text leaves your iPhone

Text leaves your iPhone only when you tap an action on the sheet (Translate, Polish, a quick prompt, and so on), and only to the engine you selected:

| Engine | Where the text goes | Governed by |
|---|---|---|
| **Claude** | Anthropic's API (`api.anthropic.com`) | [Anthropic's privacy policy](https://www.anthropic.com/legal/privacy) |
| **OpenAI-compatible** | The server address you entered | That server operator's policy |
| **On this device** | Nothing leaves your iPhone | Apple's on-device model |
| **Demo** | Nothing leaves your iPhone | — |

Before any text is sent to Claude or an OpenAI-compatible server, the app asks for your permission. You can change your mind at any time by choosing **On this device** in Engine.

The search buttons open DuckDuckGo or Google in your browser. Your search goes to that site, under its policy. Nothing is sent to us.

Speech (the speaker buttons) is generated on your iPhone.

## What we do not do

- We do not collect personal information, identifiers, usage data or diagnostics.
- We do not track you across apps or websites, and we do not use advertising identifiers.
- We do not sell or share data for advertising.
- We do not have accounts, so there is nothing to sign in to or delete on a server.

## Children

OhMyTranslate is not directed at children under 13, and it does not knowingly collect information from them.

## Your choices

- Choose **On this device** or **Demo** and no text ever leaves your iPhone.
- Remove a key or erase all data from the app at any time.
- Revoke the Translation default in **Settings › Apps › Default Apps › Translation**.

## Changes to this policy

If this policy changes, the new version is published at the same address, with a new date at the top. Material changes are also mentioned in the release notes.

## Contact

Questions or concerns: open an issue at https://github.com/jstdlee/mytranslate/issues.
