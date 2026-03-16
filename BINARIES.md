# Bundled Binaries: ffmpeg & libgifski

The app bundles **ffmpeg** (video decoding / frame extraction) and **libgifski** (high-quality GIF encoding via FFI) so end users don't need to install anything.

> **Preferred approach:** Build from source via the CI workflow (see below).
> Pre-built binaries are documented as a fallback only.

---

## Pinned versions

| Binary     | Version   | Source                                            | License |
|------------|-----------|---------------------------------------------------|---------|
| ffmpeg     | **7.1.1** | https://ffmpeg.org/releases/ffmpeg-7.1.1.tar.xz  | LGPL 2.1+ (our build) |
| libgifski  | **1.34.0**| https://github.com/ImageOptim/gifski (tag `1.34.0`) | MIT |

### Archive checksums

| File                      | SHA256                                                             |
|---------------------------|--------------------------------------------------------------------|
| `ffmpeg-7.1.1.tar.xz`    | `733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1` |

> gifski is built from the pinned Git tag via `cargo build --release` (produces shared library via cdylib crate type).

---

## Licensing

**ffmpeg** is built as **LGPL 2.1+** (no `--enable-gpl`, no GPL-only libraries
like x264/x265). This avoids copyleft obligations on the app itself. We only
need the core codecs and video filters (`scale`, `fps`) for frame extraction.

**gifski** library is **MIT** licensed. The macOS GUI app wrapper uses AGPL, but
the library/CLI is MIT. No source distribution requirements.

---

## Where to place binaries

| Platform    | ffmpeg                              | libgifski                                     |
|-------------|-------------------------------------|-----------------------------------------------|
| **macOS**   | `macos/Runner/Resources/ffmpeg`     | `macos/Runner/Resources/libgifski.dylib`      |
| **Windows** | next to `.exe`: `data/ffmpeg.exe`   | next to `.exe`: `data/gifski.dll`             |
| **Linux**   | next to executable: `lib/ffmpeg`    | next to executable: `lib/libgifski.so`        |

ffmpeg is resolved via `BinaryResolver` (CLI subprocess).
libgifski is loaded via `GifskiLibrary` (Dart FFI / `DynamicLibrary.open()`).

---

## Building from source (recommended)

A GitHub Actions workflow at `.github/workflows/build-binaries.yml` builds both
tools from source **and** builds the full Flutter app for all three platforms.

### What the workflow does

For each platform:

1. Downloads ffmpeg source tarball, verifies SHA256
2. Clones gifski at the pinned Git tag
3. Configures ffmpeg as a **minimal LGPL static build** (only the codecs,
   muxers, demuxers, and filters needed for frame extraction)
4. Installs Rust toolchain and builds gifski shared library (`cargo build --release` → cdylib)
5. Records `ffmpeg -version` and verifies `libgifski` with `file` command
6. Computes SHA256 of every output binary
7. Uploads standalone binary artifacts (binaries + checksums)
8. **Builds the Flutter app** (`flutter build <platform> --release`)
9. **Injects the freshly-built binaries** into the app bundle
10. **Uploads a ready-to-distribute app artifact** (`.zip` / `.tar.gz`)

### Platforms & artifacts

| Runner             | Arch            | Binary artifact             | App artifact |
|--------------------|-----------------|-----------------------------|-------------|
| `macos-14`         | arm64 (Apple Silicon) | `binaries-macos-arm64` | `app-macos-arm64` (.zip containing .app) |
| `ubuntu-22.04`     | x86_64          | `binaries-linux-x86_64`     | `app-linux-x86_64` (.tar.gz bundle) |
| `windows-latest`   | x86_64          | `binaries-windows-x86_64`   | `app-windows-x86_64` (.zip) |

### Running the workflow

Push to the repo (or trigger manually via `workflow_dispatch`), then download
the app artifacts from the Actions tab. They are ready to distribute.

---

## Verification checklist (per platform)

When placing binaries — whether from CI or a fallback source — always:

1. **Verify archive SHA256** against the pinned value (for ffmpeg source tarball)
2. **Verify extracted binary SHA256** against the CI-produced `checksums.sha256`
3. **Check version/type output** matches expectations:
   ```
   ./ffmpeg -version            # should show "ffmpeg version 7.1.1"
   file libgifski.dylib         # should show "Mach-O 64-bit dynamically linked shared library"
   ```
4. **Record in CI logs** — the workflow does this automatically
5. **Quarantine removal (macOS):** `xattr -cr ./ffmpeg ./libgifski.dylib`

---

## Fallback: pre-built binaries (with hash pinning)

Use these **only** if you cannot build from source. Always verify SHA256.

### Trust tiers

| Tier       | Source | Notes |
|------------|--------|-------|
| Preferred  | [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds/releases) | Linux + Windows, publishes `checksums.sha256` |
| Preferred  | [John Van Sickle](https://johnvansickle.com/ffmpeg/) | Linux static builds, multiple arches |
| Preferred  | Build from source: `cargo build --release` in gifski repo | Produces cdylib |
| Fallback   | [Evermeet](https://evermeet.cx/ffmpeg/) | macOS Intel only, verify GPG sig |
| Fallback   | [Gyan.dev](https://www.gyan.dev/ffmpeg/builds/) | Windows ffmpeg, verify hash |
| **Avoid**  | FFbinaries | Not suitable for shipped/bundled binaries |

---

## Quick local setup (macOS, for development)

For local dev/testing you can use the helper script:

```bash
cd macos/Runner/Resources
./fetch_macos_binaries.sh
```

This fetches from Evermeet (ffmpeg) and builds libgifski from source via cargo.
For production builds, use the CI workflow instead.
