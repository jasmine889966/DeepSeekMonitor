# 发布说明

仓库已准备好在 GitHub CLI 完成认证后发布。

## 首次登录

```sh
gh auth login
```

## 创建仓库并推送

在仓库根目录执行：

```sh
gh repo create DeepSeekMonitor --public --source=. --remote=origin --push
git push origin v1.0.0
```

## 创建 GitHub Release

```sh
gh release create v1.0.0 \
  dist/DeepSeekMonitor-macOS-1.0.0.zip \
  --title "DeepSeek Monitor 1.0.0" \
  --notes-file CHANGELOG.md
```

## 当前 Release 产物

```text
dist/DeepSeekMonitor-macOS-1.0.0.zip
```

这个产物应该作为 GitHub Release 附件上传，不要提交进仓库。
