# OZO AI

A native **SwiftUI** iPhone app with a ChatGPT-style interface for **ten OpenCode Zen models**, with **OpenRouter as an optional second provider**. It streams replies, renders Markdown and code, keeps a local chat history, supports photo analysis and voice dictation, and stores provider API keys in the iOS Keychain.

OpenCode Zen remains the default provider, and the ten-model catalog is unchanged. If you prefer OpenRouter, switch providers in **Settings → AI provider** and add a separate OpenRouter key.

The included GitHub Actions workflow builds an **unsigned IPA** on a macOS runner, so you do not need a Mac to produce the app. On Windows you can sign and install that IPA with **Sideloadly** and your Apple ID.

---

## Included models

The same ten models are always listed. OpenCode Zen is the default; OpenRouter availability and pricing are shown separately.

| | Model | OpenCode Zen ID | OpenRouter ID | Best for |
|---|---|---|---|---|
| ● | **GLM-5.3-Flash Free** | `glm-5.3-flash-free` | `z-ai/glm-5.3-flash` (credits) | Fast everyday chat — **default model** |
| | Big Pickle | `big-pickle` | — *OpenCode only* | Creative and out-of-the-box thinking |
| | DeepSeek V4.1 Flash Free | `deepseek-v4.1-flash-free` | `deepseek/deepseek-v4.1-flash` (credits) | Reasoning and coding |
| | MiniMax M3.1 Flash Free | `minimax-m3.1-flash-free` | `minimax/minimax-m3.1-flash:free` | Quick, expressive answers |
| | Nemotron 3.5 Super VL Free | `nemotron-3.5-super-vl-free` | `nvidia/nemotron-3.5-super-vl:free` | **Vision** — analyze photos |
| | Beam Free | `beam-free` | `reflection/beam-1.0-501b-a23b` (credits) | Very fast, short replies |
| | LongCat 2.5 Preview Free | `longcat-2.5-preview-free` | — *OpenCode only* | Long documents and pasted text |
| | MiMo-V2.6-Flash Free | `mimo-v2.6-flash-free` | `xiaomi/mimo-v2.6-flash` (credits) | Efficient mobile-scale answers |
| | Nemotron 3.5 Lightning Free | `nemotron-3.5-lightning-free` | `nvidia/nemotron-3.5-lightning:free` | Low-latency back-and-forth |
| | Nemotron 3 Ultra Free | `nemotron-3-ultra-free` | `nvidia/nemotron-3-ultra-550b-a55b:free` | Hard reasoning and large code |

GLM-5.3-Flash Free is preselected. In the model picker, the model currently in use is marked with a **filled bullet** and a highlighted card; the picker footer explains the bullet.

On OpenCode Zen, all ten model IDs and their free pricing were checked against the [OpenCode Zen documentation](https://opencode.ai/docs/zen). Free access is time-limited and controlled by OpenCode, so a model can be changed or retired later.

On OpenRouter, **four models are free** (MiniMax, Nemotron Super VL, Nemotron Lightning, Nemotron Ultra) and **four use OpenRouter credits** (DeepSeek, GLM, Beam, MiMo). **Big Pickle and LongCat 2.5 Preview are OpenCode-only**; they are shown but disabled when OpenRouter is selected. OpenRouter model IDs and availability were checked against the [OpenRouter models API](https://openrouter.ai/api/v1/models).

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
- **Two optional providers**: OpenCode Zen is the default; OpenRouter can be enabled in Settings with its own key and model availability badges.
- **API keys in Keychain**, stored separately per provider and never in the project or in `UserDefaults`.
- **Custom instructions**, temperature control, haptic feedback, and System/Light/Dark appearance.
- **Local persistence** of conversations in Application Support as JSON.
- **No analytics, no tracking, no bundled API key.**

---

## Requirements

- An iPhone on **iOS 17 or later**.
- An **OpenCode Console API key** for the default provider (the ten models are free, but access requires a key).
- Optional: an **OpenRouter API key** if you want to use the second provider. OpenRouter's free models do not need credits; its paid models do.
- **For the cloud build:** a GitHub account. No Mac required.
- **For installing on Windows:** [Sideloadly](https://sideloadly.io/) and an Apple ID. `SideloadlySetup64.exe` is already in your Downloads folder.
- Optional: a Mac with Xcode 15+ if you want to build and run locally.

---

## 1. Get an API key

### OpenCode Zen (default)

1. Open [opencode.ai/console](https://opencode.ai/console) and sign in.
2. Create/copy an API key from the Console.
3. Keep the key private. The app sends it only to `opencode.ai` and stores it in the iPhone Keychain.

> OpenCode may ask you to add billing details before creating a key. The ten models above are listed at **$0 per token**, and the key itself is free, but free availability is promotional and can change. You can review current pricing and availability in the [Zen docs](https://opencode.ai/docs/zen).

### OpenRouter (optional)

1. Open [openrouter.ai/keys](https://openrouter.ai/keys) and sign in.
2. Create/copy an OpenRouter API key.
3. In OZO AI, open **Settings → AI provider**, choose **OpenRouter**, then paste the key in **OpenRouter connection**.
4. Use one of the four free OpenRouter models to chat without credits, or add credits to your OpenRouter account for the paid models.

The app intentionally ships **without** a key. On first launch you will see a connect screen; you can choose either provider there or later in **Settings**. Keys are stored separately, so adding OpenRouter does not replace your OpenCode key.

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
6. Open **OZO AI**, choose OpenCode Zen or OpenRouter, paste the matching API key, and tap **Start chatting**.

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

## 5. How the provider integrations work

### OpenCode Zen (default)

- **Endpoint:** `POST https://opencode.ai/inference/openai/v1/chat/completions`
- **Auth:** `Authorization: Bearer <your OpenCode API key>`
- **Models:** the ten OpenCode IDs listed above. All ten are free on OpenCode Zen.

### OpenRouter (optional)

- **Endpoint:** `POST https://openrouter.ai/api/v1/chat/completions`
- **Auth:** `Authorization: Bearer <your OpenRouter API key>`
- **Attribution headers:** `HTTP-Referer: https://github.com/Heng-zm/OZOAI` and `X-Title: OZO AI`
- **Models:** the OpenRouter IDs listed above. Four are free and four use credits; two OpenCode-only models are disabled in the picker.
- **Key test:** Settings validates an OpenRouter key with the free `nvidia/nemotron-3.5-lightning:free` model, so no credits are needed just to test the key.

### Shared behavior

- **Streaming:** OpenAI-compatible SSE (`data: {...}`, terminated by `data: [DONE]`).
- **Request:** the selected provider's model ID, full conversation context (last 24 messages), custom system prompt, and temperature.
- **Vision:** photos are converted to JPEG data URLs and sent as OpenAI `image_url` content parts. Only **Nemotron 3.5 Super VL Free** is marked as vision-capable. If a photo is attached while another model is selected, the app offers to switch and automatically uses the vision model if you send anyway. Historical photos are omitted from requests to text-only models.
- **History:** the last 100 conversations are kept in `Application Support/OZOAI/chat-history.json`; the last 24 messages of a conversation are sent to the model.

The model metadata and provider mapping live in `OZOAI/Models/AIModel.swift` and `OZOAI/Models/AIProvider.swift`. If a provider changes or retires a model, update its ID there and rebuild.

---

## 6. Security and privacy

- API keys are stored separately in the **iOS Keychain** using `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (`opencode-api-key` and `openrouter-api-key`).
- A key is sent only to the provider you selected. There is no analytics SDK, proxy server, or third-party tracking.
- Chats are stored in the app's sandbox on the iPhone and are not synced by OZO AI. They are not encrypted by the app beyond iOS's normal data protection.
- The app has no server component and no bundled credentials.
- Deleting a conversation or clearing all chats removes the local copy. Removing a key deletes only that provider's key from Keychain.
- Prompts and photos are sent to the selected provider and the model's upstream provider. Free-model data policies vary. Notably, some NVIDIA free endpoints are trial endpoints and should not receive personal or confidential data; Beam Free has regional restrictions. Read the [OpenCode Zen privacy notes](https://opencode.ai/docs/zen) or [OpenRouter's data policies](https://openrouter.ai/docs) before sending sensitive information.

---

## 7. Troubleshooting

| Problem | Fix |
|---|---|
| GitHub Actions build fails | Download the `xcodebuild-log` artifact, find the first `error:` line, and fix the Swift file. The project was generated and syntax-checked locally, but a full Xcode compile can only run on macOS. |
| `401` / “API key wasn't accepted” | Re-copy the key from the provider you selected (OpenCode Console or OpenRouter Keys); remove accidental spaces; save it again in Settings. |
| `403` access denied | The key may be invalid for that model, the model may be unavailable in your region, or the free promotion may have ended. This is especially relevant for **Beam Free**, which is not available in certain regions (check the provider docs). Try another model. |
| `402` credits required | On OpenRouter, the model is paid. Pick one of the four free OpenRouter models (MiniMax, Nemotron Super VL, Nemotron Lightning, Nemotron Ultra) or add credits. On OpenCode, billing/account restrictions can still apply. |
| `429` too many requests | Wait a few seconds and retry. Both providers rate-limit free endpoints; OpenRouter's free-model limits can be stricter. |
| `404` model not found | The model may have been retired. Check the provider's model list and update `AIModel.swift` or `AIProvider.swift`. |
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
│   ├── Services/                     # Provider SSE client, Keychain, storage, speech
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

- OZO AI is an independent client, not an official OpenCode, OpenRouter, or model-provider app.
- Model names and trademarks belong to their respective owners.
- It requires internet access and an API key for the selected provider. There is no offline model.
- The app is iPhone-only, portrait, and built for iOS 17+.
- The unsigned IPA is for personal sideloading. It is not an App Store build.
- Free model availability, rate limits, and data policies are controlled by OpenCode and OpenRouter and can change at any time. OpenRouter paid models require credits on your OpenRouter account.
- The app comes with no warranty. Verify important information independently.

If you want to extend it, start with `OZOAI/Models/AIModel.swift` (model catalog), `OZOAI/Models/AIProvider.swift` (provider and OpenRouter mapping), `OZOAI/Services/AIClient.swift` (API client), and `OZOAI/ViewModels/ChatStore.swift` (chat state).
