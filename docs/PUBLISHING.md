# Publishing

This repository is ready to publish after GitHub CLI authentication.

## One-Time Login

```sh
gh auth login
```

## Create Repository And Push

From the repository root:

```sh
gh repo create DeepSeekMonitor --public --source=. --remote=origin --push
git push origin v1.0.0
```

## Create The GitHub Release

```sh
gh release create v1.0.0 \
  dist/DeepSeekMonitor-macOS-1.0.0.zip \
  --title "DeepSeek Monitor 1.0.0" \
  --notes-file CHANGELOG.md
```

## Current Release Asset

```text
dist/DeepSeekMonitor-macOS-1.0.0.zip
```

The release asset is intentionally ignored by Git and should be uploaded as a GitHub Release asset, not committed to the repository.
