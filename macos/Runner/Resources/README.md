# Bundled binaries for macOS

Place **ffmpeg** and **libgifski.dylib** here. The Xcode build phase copies them
into the app bundle so end users don't need to install anything.

## Preferred: download from CI

The GitHub Actions workflow (`.github/workflows/build-binaries.yml`) builds both
from pinned source. Download the `binaries-macos-arm64` artifact and copy
`ffmpeg` and `libgifski.dylib` here.

Verify with:

```bash
../../scripts/verify_binaries.sh .
```

## Alternative: local fetch script (dev only)

```bash
./fetch_macos_binaries.sh
```

This fetches from Evermeet (ffmpeg) and builds libgifski from source via cargo.
Not recommended for production — use CI-built binaries instead.

See the project root `BINARIES.md` for full documentation on versioning,
licensing, trust tiers, and verification.
