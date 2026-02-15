# EchoForge

Universal SwiftUI app (iOS + macOS) that streams multi-episode, two-host podcast transcripts generated from a single topic using the Google Gemini API.

## Requirements

- Xcode (latest stable)
- Swift 6
- Homebrew

## Tooling

This repo uses:

- **Mint** to pin CLI tools (`Mintfile`)
- **XcodeGen** to generate the Xcode project from `project.yml`
- **SwiftLint** for linting (`.swiftlint.yml`)

Install Mint:

```sh
brew install mint
```

Bootstrap pinned tools:

```sh
mint bootstrap
```

## Generate The Xcode Project

This repo does not commit the generated `.xcodeproj`.

```sh
mint run xcodegen xcodegen generate --spec project.yml
```

Open the workspace:

- `EchoForge.xcworkspace`

(Workspace is committed; it expects `EchoForge.xcodeproj` to exist after you run XcodeGen.)

## Configure Gemini

No API keys are hardcoded.

On first launch, open **Settings** and paste your Gemini API key.

- The API key is stored in **UserDefaults** on this device.
- The selected models are stored in **UserDefaults**.
- Text generation uses a streaming-capable model (for incremental transcript rendering).
- Speech generation uses a TTS model (for multi-speaker audio).

## Run

From Xcode:

- Scheme: `EchoForge-iOS` (Simulator)
- Scheme: `EchoForge-macOS`

On launch:

1. Enter a Topic
2. Choose number of Episodes
3. Tap **Generate Podcast**
4. Watch episodes and dialogue lines stream in as NDJSON is parsed incrementally
5. Export everything via **Export ZIP**
6. Generate and play multi-speaker audio for complete episodes

## Export Format

The ZIP contains:

- `project.json` (full `PodcastProject`)
- `episodes/episode-###.json` (one `Episode` per file)
- `episodes/episode-###.txt` (plain transcript)

## Architecture

Modular local Swift Packages (SPM):

- `Packages/EchoForgeCore`
  - Core models: `PodcastProject`, `Episode`, `DialogueLine`
  - JSON helpers and prompt template (`PodcastPromptTemplate`)
- `Packages/EchoForgeGemini`
  - `GeminiClient` protocol (streaming)
  - `GoogleGeminiClient` implementation (SSE + incremental NDJSON decoding)
- `Packages/EchoForgePersistence`
  - `ProjectStore` (simple JSON file storage under Application Support)
  - `GeminiConfigurationStore` (UserDefaults-backed API key + model selections)
  - `EpisodeAudioStore` (stores WAV files under Application Support)
- `Packages/EchoForgeExport`
  - `PodcastZipExporter` (ZIP export via ZIPFoundation)
- `Packages/EchoForgeFeatures`
  - SwiftUI UI and feature logic
  - `PodcastGenerationService` actor turns streamed events into a streamed `PodcastProject`

## Prompt Template (NDJSON Streaming)

The prompt is designed to force **one JSON object per line** (NDJSON) so the UI can render incrementally.

See:

- `Packages/EchoForgeCore/Sources/EchoForgeCore/PodcastPromptTemplate.swift`

## Lint

```sh
mint run swiftlint swiftlint lint --strict
```

## Tests

Run SwiftPM tests for local packages:

```sh
swift test --package-path Packages/EchoForgeCore
swift test --package-path Packages/EchoForgeGemini
swift test --package-path Packages/EchoForgePersistence
swift test --package-path Packages/EchoForgeExport
swift test --package-path Packages/EchoForgeFeatures
```

## CI

GitHub Actions workflow:

- Generates the project with XcodeGen
- Runs SwiftLint
- Runs SwiftPM tests
- Builds iOS + macOS targets

See: `.github/workflows/ci.yml`
