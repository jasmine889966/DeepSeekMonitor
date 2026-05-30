# Publishing

This repository is ready to publish after GitHub CLI authentication.

## One-Time Login

```sh
gh auth login
```

## Build The Release Asset

```sh
./script/build_and_run.sh package
ditto -c -k --keepParent dist/DeepSeekMonitor.app dist/DeepSeekMonitor-macOS-1.2.1.zip
```

## Push Commit And Tag

From the repository root:

```sh
git push origin main
git push origin v1.2.1
```

## Create The GitHub Release

```sh
gh release create v1.2.1 \
  dist/DeepSeekMonitor-macOS-1.2.1.zip \
  --title "DeepSeek Monitor 1.2.1" \
  --notes-file CHANGELOG.md
```

## Current Release Asset

```text
dist/DeepSeekMonitor-macOS-1.2.1.zip
```

The release asset is intentionally ignored by Git and should be uploaded as a GitHub Release asset, not committed to the repository.
