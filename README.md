# OZO AI

A native **SwiftUI** iPhone app for **fourteen frontier models** across **three providers**:

- **OpenCode Zen** — ten free models, the default provider, and **GLM-5.3-Flash Free** as the default model.
- **Anthropic Claude** — four Claude models through the native Anthropic Messages API, with your own Anthropic key.
- **OpenRouter** — optional, with free and credit-based models.

Each provider has its own API key and an **editable API base URL**. The app streams replies, renders Markdown and code, keeps a local chat history, supports photo analysis and voice dictation, and stores API keys and account sessions in the iOS Keychain.

An **optional Supabase account** adds email/password sign-in plus Google and Apple/iCloud buttons. You can keep chatting with an API key without ever signing in. Account sign-in is never required for the chat flow.

The included GitHub Actions workflow builds an **unsigned IPA** on a macOS runner, so you do not need a Mac to produce the app. On Windows you can sign and install that IPA with **Sideloadly** and your Apple ID.

> **Account status in the included Supabase project:** email/password is enabled. Google and Apple are **not enabled yet**; they must be turned on in the Supabase dashboard with your own Google and Apple provider credentials. The buttons are real Supabase OAuth buttons, not placeholders, but they will report a provider-disabled message until that setup is complete.

---

## Included models

The app always lists all fourteen models. Models that are unavailable on the selected provider are marked and disabled in the model picker.

### OpenCode Zen + OpenRouter

| | Model | OpenCode Zen ID | OpenRouter ID | Best for |
|---|---|---|---|---|
| ● | **GLM-5.3-Flash Free** | `glm-5.3-flash-free` | `z-ai/glm-5.3-flash` (credits) | Fast everyday chat — **default model** |
| | Big Pickle | `big-pickle` | — *OpenCode only* | Creative, out-of-the-box thinking |
| | DeepSeek V4.1 Flash Free | `deepseek-v4.1-flash-free` | `deepseek/deepseek-v4.1-flash` (credits) | Reasoning and coding |
| | MiniMax M3.1 Flash Free | `minimax-m3.1-flash-free` | `minimax/minimax-m3.1-flash:free` | Quick, expressive answers |
| | Nemotron 3.5 Super VL Free | `nemotron-3.5-super-vl-free` | `nvidia/nemotron-3.5-super-vl:free` | **Vision** — analyze photos |
| | Beam Free | `beam-free` | `reflection/beam-1.0-501b-a23b` (credits) | Very fast, short replies |
| | LongCat 2.5 Preview Free | `longcat-2.5-preview-free` | — *OpenCode only* | Long documents and pasted text |
| | MiMo-V2.6-Flash Free | `mimo-v2.6-flash-free` | `xiaomi/mimo-v2.6-flash` (credits) | Efficient mobile-scale answers |
| | Nemotron 3.5 Lightning Free | `nemotron-3.5-lightning-free` | `nvidia/nemotron-3.5-lightning:free` | Low-latency back-and-forth |
| | Nemotron 3 Ultra Free | `nemotron-3-ultra-free` | `nvidia/nemotron-3-ultra-550b-a55b:free` | Hard reasoning and large code |

### Anthropic Claude

| Model | Anthropic model ID | Best for |
|---|---|---|
| **Claude Fable 5.1** | `claude-fable-5-1` | Frontier reasoning for ambitious, long-running work |
| **Claude Opus 5.5** | `claude-opus-5-5` | Deep intelligence for coding, research and hard problems |
| **Claude Sonnet 5.5** | `claude-sonnet-5-5` | Best balance of speed and intelligence |
| **Claude Haiku 5.5** | `claude-haiku-5-5` | Fastest Claude for quick, high-volume tasks |

Claude models use the **native Anthropic Messages API**, not OpenRouter. Claude usage is billed through your Anthropic account.

On OpenCode Zen, the ten model IDs and free pricing follow the [OpenCode Zen documentation](https://opencode.ai/docs/zen). Free access is time-limited and controlled by OpenCode, so a model can be changed or retired later.

On OpenRouter, **four models are free** (MiniMax, Nemotron Super VL, Nemotron Lightning, Nemotron Ultra) and **four use credits** (DeepSeek, GLM, Beam, MiMo). **Big Pickle and LongCat 2.5 Preview are OpenCode-only**. Claude is Anthropic-only. OpenRouter model IDs and availability were checked against the [OpenRouter models API](https://openrouter.ai/api/v1/models).

---

## Features

- **Fourteen models, three providers** with provider badges, availability states, and a clear unavailable-model banner.
- **Claude direct** through `POST /v1/messages`, with Anthropic SSE streaming, system prompts, temperature, and vision blocks.
- **Editable API base URLs** per provider under **Settings → API endpoint**. Paste a full endpoint or a root URL; the app resolves the correct path. Reset to the default at any time.
- **Optional OZO account** via Supabase: email/password, Google, and Apple/iCloud OAuth.
- **Account labels** in Settings, profile initials, and a signed-in state. Signing out never deletes chats or API keys.
- **API keys in Keychain**, stored separately per provider and never in the project or in `UserDefaults`.
- **Account session in Keychain**, with automatic token refresh and PKCE OAuth.
- **ChatGPT-like chat UI** with a model switcher in the header, a welcome screen, suggestion cards, and a compact composer.
- **Real streaming responses** over Server-Sent Events (SSE), with a stop button, typing indicator, and streaming cursor.
- **Markdown rendering** for headings, lists, quotes, tables, inline code, fenced code blocks, dividers, and links.
- **Code blocks** with a language label and one-tap copy. Whole replies can also be copied.
- **Conversation history**: grouped by date, searchable, renameable, deletable, and automatically titled from the first message.
- **Regenerate** the latest response, clear a conversation, or start a new chat.
- **Photo attachments** for vision models, with automatic resizing and JPEG compression. If you attach a photo while a text-only model is selected, the app offers to switch to a vision model.
- **Voice dictation** using Apple's Speech framework, with microphone/speech permission handling.
- **Custom instructions**, temperature control, haptic feedback, and System/Light/Dark appearance.
- **Local persistence** of conversations in Application Support as JSON.
- **No analytics, no tracking, no bundled AI-provider key.**

---

## Requirements

- An iPhone on **iOS 17 or later**.
- An **OpenCode Console API key** for the default provider.
- Optional: an **OpenRouter API key** for the third provider.
- Optional: an **Anthropic API key** for Claude models. Anthropic usage is credit-based.
- Optional: a **Supabase project** for accounts. The app includes a default project URL and publishable key, but you can override them in Settings or clear them.
- **For the cloud build:** a GitHub account. No Mac required.
- **For installing on Windows:** [Sideloadly](https://sideloadly.io/) and an Apple ID.

---

## 1. Get an API key

### OpenCode Zen (default)

1. Open [opencode.ai/console](https://opencode.ai/console) and sign in.
2. Create/copy an API key from the Console.
3. Keep the key private. The app sends it only to your selected OpenCode endpoint and stores it in the iPhone Keychain.

> OpenCode may ask you to add billing details before creating a key. The ten models above are listed at **$0 per token**, and the key itself is free, but free availability is promotional and can change. Review current pricing in the [Zen docs](https://opencode.ai/docs/zen).

### Anthropic Claude (optional)

1. Open [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) and sign in.
2. Create/copy an Anthropic API key.
3. In OZO AI, open **Settings → AI provider**, choose **Anthropic Claude**, paste the key, and tap **Save key**.
4. Pick one of the four Claude models in the model picker. Claude usage is billed through your Anthropic account.

### OpenRouter (optional)

1. Open [openrouter.ai/keys](https://openrouter.ai/keys) and sign in.
2. Create/copy an OpenRouter API key.
3. In OZO AI, open **Settings → AI provider**, choose **OpenRouter**, paste the key, and save it.
4. Use one of the four free OpenRouter models to chat without credits, or add credits for the paid models.

The app ships **without an AI-provider key**. On first launch you will see a connect screen; you can choose a provider there or later in **Settings**. Keys are stored separately, so adding a Claude or OpenRouter key does not replace your OpenCode key.

---

## 2. Optional account setup (Supabase)

The app already includes this Supabase project configuration:

- **Project URL:** `https://hwefrhiyxflnosqfsylp.supabase.co`
- **Publishable key:** bundled at build time through `SUPABASE_ANON_KEY` in `project.yml`

A Supabase **publishable/anon key is designed to be public** in client apps. It is not an AI key and it does not bypass Row Level Security.

### Current provider status

| Provider | Status in the included project | What is required |
|---|---|---|
| Email + password | **Enabled** | Nothing extra |
| Google | **Disabled** | Google Cloud OAuth client ID/secret, then enable Google in Supabase |
| Apple / iCloud | **Disabled** | Apple Developer account, Services ID, key, then enable Apple in Supabase |

The Google and Apple buttons call real Supabase OAuth. They will show a provider-disabled message until the providers are enabled. There are no fake local sign-in buttons.

### Supabase dashboard steps

1. Open [supabase.com/dashboard](https://supabase.com/dashboard) and select the project.
2. Go to **Authentication → URL Configuration**.
3. Set the **Site URL** to a real page you control (for example your project URL).
4. Add this redirect URL exactly:

   ```
   ozoai://auth-callback
   ```

5. For email confirmation, the app sends `redirect_to=ozoai://auth-callback` and uses PKCE. On iOS, the confirmation link can open OZO AI and finish the session automatically. If the custom scheme is not allowlisted, the account may still be confirmed but the browser will land on the Site URL; sign in manually afterward.
6. Go to **Authentication → Providers**:
   - **Email:** enabled. The project currently requires email confirmation (`mailer_autoconfirm = false`). To allow instant sign-up during testing, turn off **Confirm email**.
   - **Google:** add a Google Cloud OAuth client. Use the Supabase callback URL shown in the dashboard as the authorized redirect URI, then enable Google.
   - **Apple:** add your Apple Developer **Services ID**, team ID, key ID, and private key, then enable Apple.
7. If you change the Supabase URL or key, open **Settings → Account → Account server** in the app and enter the new values. The app tests `/auth/v1/settings` before saving.

### Service-role key warning

Use only the **publishable/anon key** in the app. The Supabase `service_role` key bypasses Row Level Security and must **never** be placed in the app, the repository, GitHub Actions, or a screenshot. If a service-role key has been shared, rotate it in the Supabase dashboard.

The account is optional. If you clear the account server in Settings, the app remembers that choice and continues to work with API-key chat.

---

## 3. Build the IPA with GitHub Actions

The repository is prepared as a standalone Git repo. It contains:

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

The workflow also prints the IPA size and SHA-256 in its run summary. If the build fails, download the **`xcodebuild-log`** artifact and check the first `error:` line.

### Optional: attach the IPA to a GitHub Release

Push a version tag:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

The workflow builds the IPA and attaches it (plus the checksum) to a GitHub Release named after the tag.

---

## 4. Install on your iPhone from Windows with Sideloadly

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
6. Open **OZO AI**, choose a provider, paste the matching API key, and tap **Start chatting**. Signing in is optional.

### Free vs. paid Apple ID

| Apple ID | Signing lifetime | Notes |
|---|---|---|
| Free Apple ID | **~7 days** | Reinstall with Sideloadly to renew; up to 3 sideloaded apps at a time. |
| Apple Developer Program | **~1 year** | Requires the paid developer program; can also use ad-hoc/development provisioning. |

If Sideloadly reports a bundle-ID conflict, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` (for example to `com.yourname.ozoai`), commit, push, download a new IPA, and sideload that.

> Your Apple ID password is handled by Sideloadly/Apple during signing. Do not commit it, paste it into this repository, or share it with anyone.

---

## 5. Local Mac build (optional)

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

**Google/Apple note:** a local Mac build does not make OAuth work by itself. The Supabase project still needs the redirect URL and provider credentials enabled.

---

## 6. How the provider integrations work

### OpenCode Zen (default)

- **Default base URL:** `https://opencode.ai/inference/openai/v1`
- **Endpoint:** `POST https://opencode.ai/inference/openai/v1/chat/completions`
- **Auth:** `Authorization: Bearer <your OpenCode API key>`
- **Models:** the ten OpenCode IDs above. All ten are free on OpenCode Zen.

### Anthropic Claude (optional)

- **Default base URL:** `https://api.anthropic.com`
- **Endpoint:** `POST https://api.anthropic.com/v1/messages`
- **Auth headers:** `x-api-key: <your Anthropic API key>` and `anthropic-version: 2023-06-01`
- **Streaming:** Anthropic SSE. Text arrives in `content_block_delta` events with `delta.type == "text_delta"`.
- **System prompt:** the custom instructions are sent in the top-level `system` field.
- **Vision:** JPEG data URLs are converted to Anthropic `image` blocks with base64 sources.
- **Models:** the four Claude IDs above. Claude is not routed through OpenRouter.

### OpenRouter (optional)

- **Default base URL:** `https://openrouter.ai/api/v1`
- **Endpoint:** `POST https://openrouter.ai/api/v1/chat/completions`
- **Auth:** `Authorization: Bearer <your OpenRouter API key>`
- **Attribution headers:** `HTTP-Referer: https://github.com/Heng-zm/OZOAI` and `X-Title: OZO AI`
- **Models:** the OpenRouter IDs above. Four are free and four use credits; two OpenCode-only models and all four Claude models are disabled in the picker.
- **Key test:** Settings validates an OpenRouter key with the free `nvidia/nemotron-3.5-lightning:free` model, so no credits are needed just to test the key.

### Editable API base URLs

Open **Settings → API endpoint** to edit the base URL for the selected provider. The app accepts:

- a root URL such as `https://api.anthropic.com`
- a versioned base such as `https://api.anthropic.com/v1`
- a complete endpoint such as `https://api.anthropic.com/v1/messages`

For OpenCode and OpenRouter, the app appends `/chat/completions` unless the URL already ends with that path. For Anthropic, it appends `/v1/messages` unless the URL already ends with `/v1/messages`; a base ending in `/v1` gets `/messages` appended.

Use **Reset** to return to the built-in default. A custom URL applies to new requests and to the **Test** button. The app only accepts HTTP/HTTPS URLs with a host.

### Shared behavior

- **Streaming:** OpenAI-compatible SSE (`data: {...}`, terminated by `data: [DONE]`) and Anthropic SSE (`message_stop`).
- **Request:** the selected provider's model ID, full conversation context (last 24 messages), custom system prompt, and temperature.
- **Vision:** photos are converted to JPEG data URLs. OpenAI-compatible providers receive `image_url` parts; Anthropic receives base64 image blocks. OpenCode and OpenRouter mark **Nemotron 3.5 Super VL Free** as vision-capable; all four Claude models support vision.
- **History:** the last 100 conversations are kept in `Application Support/OZOAI/chat-history.json`; the last 24 messages of a conversation are sent to the model.

The model metadata and provider mapping live in `OZOAI/Models/AIModel.swift` and `OZOAI/Models/AIProvider.swift`. If a provider changes or retires a model, update its ID there and rebuild.

---

## 7. Security and privacy

- **AI API keys** are stored in the **iOS Keychain** using `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`:
  - `opencode-api-key`
  - `openrouter-api-key`
  - `anthropic-api-key`
- **Account sessions** are stored separately in the Keychain under `supabase-session`. Access tokens refresh automatically; the refresh token is never written to `UserDefaults`.
- **Supabase project URL and publishable/anon key** are bundled through build settings. A publishable key is intended to be public. The **service_role** key is never bundled and must never be committed.
- A key is sent only to the provider you selected. There is no analytics SDK, proxy server, or third-party tracking.
- Chats are stored in the app's sandbox on the iPhone and are not synced by OZO AI. They are not encrypted by the app beyond iOS's normal data protection.
- The app has no AI-provider key bundled. Account login is optional and does not gate API-key chat.
- Deleting a conversation or clearing all chats removes the local copy. Removing a key deletes only that provider's key from Keychain. Signing out does not delete chats or API keys.
- Prompts and photos are sent to the selected provider and the model's upstream provider. Free-model data policies vary. Notably, some NVIDIA free endpoints are trial endpoints and should not receive personal or confidential data; Beam Free has regional restrictions. Read the [OpenCode Zen privacy notes](https://opencode.ai/docs/zen), [Anthropic's privacy policy](https://www.anthropic.com/legal/privacy), or [OpenRouter's data policies](https://openrouter.ai/docs) before sending sensitive information.

---

## 8. Troubleshooting

| Problem | Fix |
|---|---|
| GitHub Actions build fails | Download the `xcodebuild-log` artifact, find the first `error:` line, and fix the Swift file. The project was generated and syntax-checked locally, but a full Xcode compile can only run on macOS. |
| `401` / “API key wasn't accepted” | Re-copy the key from the provider you selected (OpenCode Console, Anthropic Console, or OpenRouter Keys); remove accidental spaces; save it again in Settings. |
| `403` access denied | The key may be invalid for that model, the model may be unavailable in your region, or the free promotion may have ended. Try another model. |
| `402` credits required | On OpenRouter or Anthropic, the model is paid. Pick a free OpenRouter model, add credits, or switch providers. |
| `429` too many requests | Wait a few seconds and retry. Free endpoints and auth emails are rate-limited. |
| `404` model not found | The model may have been retired. Check the provider's model list and update `AIModel.swift` or `AIProvider.swift`. |
| Claude request returns `invalid x-api-key` | Make sure you saved an **Anthropic** key while the Anthropic provider is selected, not an OpenRouter key. |
| Empty response | The service may be busy or the model may only have produced reasoning tokens. Retry, stop and regenerate, or switch models. |
| “Account server not configured” | Open **Settings → Account → Account server** and enter the Supabase project URL and publishable key. |
| “Email not confirmed” | Open the confirmation email, then sign in. For faster testing, turn off **Confirm email** in Supabase → Authentication → Providers → Email. |
| Google/Apple says the provider isn't enabled | Enable the provider in Supabase → Authentication → Providers and add the required Google/Apple credentials. The included project has both disabled by default. |
| OAuth redirect error | Add `ozoai://auth-callback` to Supabase → Authentication → URL Configuration → Redirect URLs. |
| “Untrusted Developer” | Settings → General → VPN & Device Management → Developer App → your Apple ID → Trust. |
| App will not launch on iOS 16+ | Enable **Developer Mode** in Settings → Privacy & Security, then restart the iPhone. |
| Sideloadly does not see the iPhone | Install iTunes/Apple Devices, use a data cable, unlock the phone, and tap Trust. |
| App expires after a few days | Free Apple ID signatures last about 7 days. Re-sideload the same IPA. |
| “Maximum number of apps” error | A free Apple ID can have only 3 sideloaded apps. Remove one, or use a paid developer account. |

---

## 9. Project layout

```
OZOAI/
├── .github/workflows/build-ipa.yml   # macOS runner → unsigned IPA
├── project.yml                       # XcodeGen project + scheme + Supabase build settings
├── OZOAI/
│   ├── App/                          # App entry point and RootView
│   ├── Models/                       # AIModel catalog, AIProvider mapping, chat models
│   ├── Services/                     # AIClient, AuthService, Keychain, storage, speech
│   ├── Theme/                        # Palette, logo, haptics, shared styles
│   ├── ViewModels/                   # ChatStore and AppSettings
│   ├── Views/
│   │   ├── Chat/                     # Chat, composer, message rows, markdown
│   │   ├── Components/               # Reusable indicators and error card
│   │   ├── Models/                   # Model picker
│   │   ├── Settings/                 # Settings, onboarding, account, account server
│   │   └── Sidebar/                  # Conversation drawer
│   ├── Resources/Assets.xcassets     # App icon and colors
│   └── Support/Info.plist            # Permissions, URL scheme, Supabase config keys
└── tools/                            # Icon generator and syntax checker
```

---

## 10. Notes and limitations

- OZO AI is an independent client, not an official OpenCode, OpenRouter, Anthropic, Google, Apple, or Supabase app.
- Model names and trademarks belong to their respective owners.
- It requires internet access and an API key for the selected provider. There is no offline model.
- Claude usage is billed by Anthropic. OpenCode's free models are promotional and can change. OpenRouter paid models require credits on your OpenRouter account.
- Google and Apple sign-in require provider credentials that only the Supabase project owner can configure. The app cannot create those credentials for you.
- The app is iPhone-only, portrait, and built for iOS 17+.
- The unsigned IPA is for personal sideloading. It is not an App Store build.
- The app comes with no warranty. Verify important information independently.

If you want to extend it, start with `OZOAI/Models/AIModel.swift` (model catalog), `OZOAI/Models/AIProvider.swift` (provider mapping and endpoint resolution), `OZOAI/Services/AIClient.swift` (OpenAI/Anthropic clients), `OZOAI/Services/AuthService.swift` (Supabase auth), and `OZOAI/ViewModels/ChatStore.swift` (chat state).
