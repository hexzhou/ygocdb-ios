---
name: xcode-unsigned-ipa
description: Archive an iOS Xcode project and package an unsigned IPA by manually zipping the archived .app into Payload. Use when Codex needs to build the current project, create a distributable unsigned .ipa for sideloading or inspection, or repeat this packaging flow for this repository's `ygocdb.xcodeproj` / `ygocdb` scheme.
---

# Xcode Unsigned IPA

Archive the app without code signing, then package the archived `.app` into an unsigned `.ipa`.

## Workflow

1. Run from the repository root unless the user explicitly wants a different project path.
2. Prefer the bundled script:

```bash
bash .codex/skills/xcode-unsigned-ipa/scripts/archive_unsigned_ipa.sh
```

3. Read the script output and report:
   - archive path
   - ipa path
   - whether verification passed

## Defaults

The bundled script defaults to this repository:

- `PROJECT_PATH=ygocdb.xcodeproj`
- `SCHEME=ygocdb`
- `CONFIGURATION=Release`
- output under `dist/`

## Optional Overrides

Override only when needed:

```bash
PROJECT_PATH="SomeApp.xcodeproj" \
SCHEME="SomeApp" \
CONFIGURATION="Debug" \
ARCHIVE_BASENAME="someapp-debug" \
OUTPUT_DIR="$PWD/dist/custom" \
DERIVED_DATA_PATH="/tmp/someapp-dd" \
bash .codex/skills/xcode-unsigned-ipa/scripts/archive_unsigned_ipa.sh
```

Reuse an existing archive without rebuilding:

```bash
ARCHIVE_PATH="$PWD/dist/archives/ygocdb-20260422-091538.xcarchive" \
IPA_PATH="$PWD/dist/ygocdb-repacked-unsigned.ipa" \
SKIP_ARCHIVE=1 \
bash .codex/skills/xcode-unsigned-ipa/scripts/archive_unsigned_ipa.sh
```

## Notes

- Keep signing disabled during archive.
- Do not use `xcodebuild -exportArchive` for unsigned output; package the archived `.app` manually.
- Remove `_CodeSignature` and `embedded.mobileprovision` from the copied app before zipping.
- Verify the final `.ipa` contains `Payload/<AppName>.app`.
- When archive runs inside a restricted sandbox and `actool` reports missing simulator runtimes, rerun the same script with elevated local execution so Xcode can access its installed runtime services.
