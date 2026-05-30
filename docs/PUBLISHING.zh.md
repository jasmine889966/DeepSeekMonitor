# 发布说明

仓库已准备好在 GitHub CLI 完成认证后发布。

## 首次登录

```sh
gh auth login
```

## 构建 Release 产物

```sh
./script/build_and_run.sh package
ditto -c -k --keepParent dist/DeepSeekMonitor.app dist/DeepSeekMonitor-macOS-1.2.1.zip
```

## 推送提交和标签

在仓库根目录执行：

```sh
git push origin main
git push origin v1.2.1
```

## 创建 GitHub Release

```sh
gh release create v1.2.1 \
  dist/DeepSeekMonitor-macOS-1.2.1.zip \
  --title "DeepSeek Monitor 1.2.1" \
  --notes-file CHANGELOG.md
```

## 当前 Release 产物

```text
dist/DeepSeekMonitor-macOS-1.2.1.zip
```

这个产物应该作为 GitHub Release 附件上传，不要提交进仓库。
