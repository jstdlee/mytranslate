# OhMyTranslate

Translate and rewrite selected text from the iOS text-selection menu.

Select text in any app → **Translate** → a sheet with your languages and writing actions
(Translate, Polish, Fix grammar, Formal, Shorter, Reply, Explain, or a one-off instruction).
The result streams in; **Replace** writes it back into the text field.

It works by becoming the iPhone's default translation app (iOS 18.4+,
Settings › Apps › Default Apps › Translation). See [docs/DESIGN.md](docs/DESIGN.md).

## Engines

- **Claude** (Anthropic API key, kept in the Keychain) — default `claude-opus-5-5`
- **OpenAI-compatible** server (OpenRouter, DeepSeek, Ollama, LM Studio…)
- **On this device** — Apple's on-device model (iOS 26, Apple Intelligence)
- **Demo** — fixed answers, nothing is sent

## Layout

| Path | What |
|---|---|
| `OhMyTranslate/` | The app: Try it, Actions, Languages, Engine, Set up |
| `TranslateExtension/` | `TranslationUIProviderExtension` that the Translate menu opens |
| `Packages/OhMyTranslateKit` | Models, prompts, providers, settings, sheet state (`OhMyTranslateKit`) and the sheet UI (`OhMyTranslateUI`) |
| `OhMyTranslateUITests/` | UI tests on the Try it sheet with the demo engine |

## Build and test

Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
swift test --package-path Packages/OhMyTranslateKit   # unit tests
scripts/ci-test.sh                                     # generate project, build app + extension, UI tests
scripts/build-ipa.sh                                   # unsigned device .ipa
```

GitHub Actions (`.github/workflows/ios.yml`) runs both on every push and uploads
screenshots and an unsigned IPA.

To run on a device, open the generated project, set your team on both targets, and add the
**Translation**, **App Groups** (`group.com.jstdlee.ohmytranslate`) and **Keychain Sharing**
capabilities if Xcode asks.
