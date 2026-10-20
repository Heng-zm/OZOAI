# OZO AI

A native **SwiftUI** iPhone app with a ChatGPT-style interface for **ten free OpenCode Zen models**. It streams replies, renders Markdown and code, keeps a local chat history, supports photo analysis and voice dictation, and stores your OpenCode API key in the iOS Keychain.

The included GitHub Actions workflow builds an **unsigned IPA** on a macOS runner, so you do not need a Mac to produce the app. On Windows you can sign and install that IPA with **Sideloadly** and your Apple ID.

---

## Included models

| | Model | OpenCode model ID | Best for |
|---|---|---|---|
| ● | **GLM-5.3-Flash Free** | `glm-5.3-flash-free` | Fast everyday chat — **default model** |
| | Big Pickle | `big-pickle` | Creative and out-of-the-box thinking |
| | DeepSeek V4.1 Flash Free | `deepseek-v4.1-flash-free` | Reasoning and coding |
| | MiniMax M3.1 Flash Free | `minimax-m3.1-flash-free` | Quick, expressive answers |
| | Nemotron 3.5 Super VL Free | `nemotron-3.5-super-vl-free` | **Vision** — analyze photos |
| | Beam Free | `beam-free` | Very fast, short replies |
| | LongCat 2.5 Preview Free | `longcat-2.5-preview-free` | Long documents and pasted text |
| | MiMo-V2.6-Flash Free | `mimo-v2.6-flash-free` | Efficient mobile-scale answers |
| | Nemotron 3.5 Lightning Free | `nemotron-3.5-lightning-free` | Low-latency back-and-forth |
| | Nemotron 3 Ultra Free | `nemotron-3-ultra-free` | Hard reasoning and large code |

GLM-5.3-Flash Free is preselected. In the model picker, the model currently in use is marked with a **filled bullet** and a highlighted card; the picker footer explains the bullet.

All ten model IDs and their free pricing were checked against the [OpenCode Zen documentation](https://opencode.ai/docs/zen). Free access is time-limited and controlled by OpenCode, so a model can be changed or retired later.

---

## Features

- **ChatGPT-like chat UI** with a model switcher in the header, a welcome screen, suggestion cards, and a compact composer.
- **Real streaming responses** over Server-Sent Events (SSE), with a stop button, typing indicator, and streaming cursor.
- **Markdown rendering** for headings, lists, quotes, tables, inline code, fenced code blocks, dividers, and links.
- **Code blocks** with a language label and one-tap copy. Whole replies can also be copied.
- **Conversation history**: grouped by date, searchable, renameable, deletable, and automatically titled from the first message.
- **Regenerate** the latest response, clear a conversation, or start a new chat.
- **Photo attachments** for the vision model, with automatic resizing and JPEG compression. If you attach a photo while a text-only model is selected, the app offers to switch and will automatically use the vision model when you send.
- **Voice dictation** using Apple's Speech framework, with microphone/speech permission handling.
- **API key in Keychain**, never in the project or in `UserDefaults`.
- **Custom instructions**, temperature control, haptic feedback, and System/Light/Dark appearance.
- **Local persistence** of conversations in Application Support as JSON.
- **No analytics, no tracking, no bundled API key.**

---

## Requirements

- An iPhone on **iOS 17 or later**.
- An **OpenCode Console API key** (the ten models are free, but access requires a key).
- **For the cloud build:** a GitHub account. No Mac required.
- **For installing on Windows:** [Sideloadly](https://sideloadly.io/) and an Apple ID. `SideloadlySetup64.exe` is already in your Downloads folder.
- Optional: a Mac with Xcode 15+ if you want to build and run locally.

---

## 1. Get your OpenCode API key

1. Open [opencode.ai/console](https://opencode.ai/console) and sign in.
2. Create/copy an API key from the Console.
3. Keep the key private. The app sends it only to `opencode.ai` and stores it in the iPhone Keychain.

> OpenCode may ask you to add billing details before creating a key. The ten models above are listed at **$0 per token**, and the key itself is free, but free availability is promotional and can change. You can review current pricing and availability in the [Zen docs](https://opencode.ai/docs/zen).

The app intentionally ships **without** a key. On first launch you will see a connect screen; you can paste the key there or later in **Settings → OpenCode Zen connection**.

---

## 2. Build the IPA with GitHub Actions

The repository is already prepared as a standalone Git repo with an initial commit. It contains:

```
.github/workflows/build-ipa.yml   # macOS build → unsigned IPA artifact
project.yml                       # XcodeGen project definition
OZOAI/                            # SwiftUI source, assets, Info.plist
```

### Create the GitHub repo and push

1. Create a new GitHub repository named `OZOAI`. A **private** repo is recommended. Do **not** initialize it with a README, `.gitignore`, or license.
2. In PowerShell, from this folder:

   ```powershell
   cd C:\Users\Ozo\Downloads\OZOAI
   git remote add origin https://github.com/YOUR-USERNAME/OZOAI.git
   git push -u origin main
   ```

   Replace `YOUR-USERNAME`. If Git asks you to sign in, use GitHub's browser login or a personal access token. Never put a token in this README or in a tracked file.

3. Pushing to `main` automatically starts **Build OZO AI IPA** under the repository's **Actions** tab. You can also click **Run workflow** manually.

### Download the IPA

1. Open **Actions → Build OZO AI IPA → the latest successful run**.
2. Under **Artifacts**, download **`OZOAI-unsigned-ipa`** (GitHub downloads it as a ZIP).
3. Unzip it. You get:
   - `OZOAI-unsigned.ipa`
   - `OZOAI-unsigned.ipa.sha256`
4. Keep the IPA. It is unsigned, which is normal for this install path; Sideloadly will sign it with your Apple ID.

The workflow also prints the IPA size and SHA-256 in its run summary. If the build fails, download the **`xcodebuild-log`** artifact and check the reported Swift error.

### Optional: attach the IPA to a GitHub Release

Push a version tag:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

The workflow builds the IPA and attaches it (plus the checksum) to a GitHub Release named after the tag.

---

## 3. Install on your iPhone from Windows with Sideloadly

### Prepare the iPhone

1. Install iTunes (or Apple Devices) on Windows so the Apple mobile device drivers are available.
2. Connect the iPhone with a data-capable USB cable, unlock it, and tap **Trust** on the iPhone.
3. Make sure the iPhone is on **iOS 17+** and connected to the internet.

### Sign and install

1. Run `SideloadlySetup64.exe` if Sideloadly is not installed yet, then open Sideloadly.
2. Drag **`OZOAI-unsigned.ipa`** into Sideloadly, or choose it with the IPA selector.
3. Enter your **Apple ID** in Sideloadly. Sideloadly uses it locally to request a signing certificate from Apple.
4. Click **Start** and wait for the install to finish.
5. On the iPhone, trust the developer certificate:
   - **iOS 16 and later:** open **Settings → Privacy & Security → Developer Mode**, turn it on, and restart the iPhone.
   - If the app says **Untrusted Developer**, open **Settings → General → VPN & Device Management → Developer App → your Apple ID → Trust**.
6. Open **OZO AI**, paste your OpenCode API key, and tap **Start chatting**.

### Free vs. paid Apple ID

| Apple ID | Signing lifetime | Notes |
|---|---|---|
| Free Apple ID | **~7 days** | Reinstall with Sideloadly to renew; up to 3 sideloaded apps at a time. |
| Apple Developer Program | **~1 year** | Requires the paid developer program; can also use ad-hoc/development provisioning. |

If Sideloadly reports a bundle-ID conflict, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` (for example to `com.yourname.ozoai`), commit, push, download a new IPA, and sideload that.

> Your Apple ID password is handled by Sideloadly/Apple during signing. Do not commit it, paste it into this repository, or share it with anyone.

---

## 4. Local Mac build (optional)

Requirements: macOS, Xcode 15 or newer, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd OZOAI
xcodegen generate
open OZOAI.xcodeproj
```

In Xcode:

1. Select the **OZOAI** target → **Signing & Capabilities**.
2. Choose your development team and, if needed, a unique bundle identifier.
3. Select your connected iPhone as the run destination and press **Run**.

Command-line build for a connected device:

```bash
xcodebuild \
  -project OZOAI.xcodeproj \
  -scheme OZOAI \
  -configuration Debug \
  -destination 'platform=iOS,name=Your iPhone' \
  build
```

The generated `OZOAI.xcodeproj` is intentionally ignored by Git. Regenerate it with `xcodegen generate` after changing `project.yml`.

---

## 5. How the OpenCode integration works

- **Endpoint:** `POST https://opencode.ai/inference/openai/v1/chat/completions`
- **Auth:** `Authorization: Bearer <your OpenCode API key>`
- **Streaming:** OpenAI-compatible SSE (`data: {...}`, terminated by `data: [DONE]`).
- **Default request:** the selected model ID, full conversation context (last 24 messages), custom system prompt, and temperature.
- **Vision:** photos are converted to JPEG data URLs and sent as OpenAI `image_url` content parts. Only **Nemotron 3.5 Super VL Free** is marked as vision-capable. If a photo is attached while another model is selected, the app offers to switch and automatically uses the vision model if you send anyway. Historical photos are omitted from requests to text-only models.
- **Key test:** Settings uses a tiny non-streaming completion to verify that the key can reach the model service.
- **History:** the last 100 conversations are kept in `Application Support/OZOAI/chat-history.json`; the last 24 messages of a conversation are sent to the model.

The model metadata lives in `OZOAI/Models/AIModel.swift`. If OpenCode changes or retires a model, update its name/ID there and rebuild.

---

## 6. Security and privacy

- The API key is stored in the **iOS Keychain** using `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- It is sent only to the OpenCode endpoint. There is no analytics SDK, proxy server, or third-party tracking.
- Chats are stored in the app's sandbox on the iPhone and are not synced by OZO AI. They are not encrypted by the app beyond iOS's normal data protection.
- The app has no server component and no bundled credentials.
- Deleting a conversation or clearing all chats removes the local copy. Removing the key deletes it from Keychain.
- Prompts and photos are sent to OpenCode and the model's upstream provider. Free-model data policies vary. Notably, some NVIDIA free endpoints are trial endpoints and should not receive personal or confidential data; Beam Free has regional restrictions. Read the [OpenCode Zen privacy notes](https://opencode.ai/docs/zen) before sending sensitive information.

---

## 7. Troubleshooting

| Problem | Fix |
|---|---|
| GitHub Actions build fails | Download the `xcodebuild-log` artifact, find the first `error:` line, and fix the Swift file. The project was generated and syntax-checked locally, but a full Xcode compile can only run on macOS. |
| `401` / “API key wasn't accepted” | Re-copy the key from OpenCode Console; remove accidental spaces; save it again in Settings. |
| `403` access denied | The key may be invalid for that model, the model may be unavailable in your region, or the free promotion may have ended. This is especially relevant for **Beam Free**, which is not available in certain regions (check the Zen docs). Try another model. |
| `402` credits required | Free models should not charge, but billing/account restrictions can still apply. Check your Console account and try another free model. |
| `429` too many requests | Wait a few seconds and retry. Free endpoints can be rate-limited. |
| `404` model not found | The model may have been retired. Check the Zen docs and update `AIModel.swift`. |
| Empty response | The service may be busy or the model may only have produced reasoning tokens. Retry, stop and regenerate, or switch models. |
| “Untrusted Developer” | Settings → General → VPN & Device Management → Developer App → your Apple ID → Trust. |
| App will not launch on iOS 16+ | Enable **Developer Mode** in Settings → Privacy & Security, then restart the iPhone. |
| Sideloadly does not see the iPhone | Install iTunes/Apple Devices, use a data cable, unlock the phone, and tap Trust. |
| App expires after a few days | Free Apple ID signatures last about 7 days. Re-sideload the same IPA. |
| “Maximum number of apps” error | A free Apple ID can have only 3 sideloaded apps. Remove one, or use a paid developer account. |

---

## 8. Project layout

```
OZOAI/
├── .github/workflows/build-ipa.yml   # macOS runner → unsigned IPA
├── project.yml                       # XcodeGen project + scheme
├── OZOAI/
│   ├── App/                          # App entry point and RootView
│   ├── Models/                       # AIModel catalog and wire/chat models
│   ├── Services/                     # OpenCode SSE client, Keychain, storage, speech
│   ├── Theme/                        # Palette, logo, haptics, shared styles
│   ├── ViewModels/                   # ChatStore and AppSettings
│   ├── Views/
│   │   ├── Chat/                     # Chat, composer, message rows, markdown
│   │   ├── Components/               # Reusable indicators and error card
│   │   ├── Models/                   # Model picker
│   │   ├── Settings/                 # Settings and onboarding
│   │   └── Sidebar/                  # Conversation drawer
│   ├── Resources/Assets.xcassets     # App icon and colors
│   └── Support/Info.plist            # Permissions and launch configuration
└── tools/                            # Icon generator and syntax checker
```

---

## 9. Notes and limitations

- OZO AI is an independent client, not an official OpenCode or model-provider app.
- Model names and trademarks belong to their respective owners.
- It requires internet access and an OpenCode API key. There is no offline model.
- The app is iPhone-only, portrait, and built for iOS 17+.
- The unsigned IPA is for personal sideloading. It is not an App Store build.
- Free model availability, rate limits, and data policies are controlled by OpenCode and can change at any time.
- The app comes with no warranty. Verify important information independently.

If you want to extend it, start with `OZOAI/Models/AIModel.swift` (model catalog), `OZOAI/Services/OpenCodeService.swift` (API client), and `OZOAI/ViewModels/ChatStore.swift` (chat state).
