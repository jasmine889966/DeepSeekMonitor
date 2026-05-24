# DeepSeek Monitor

[English](README.md) | 中文

DeepSeek Monitor 是一款原生 macOS 菜单栏与桌面应用，用于查看 DeepSeek 平台余额、Token 用量、模型统计、成本和本地告警阈值。

应用只会把登录凭据保存在用户自己的 Mac 上，不会内置任何 token、cookie 或 API key。

## 截图

![登录界面](assets/screenshots/login.png)
![总览界面](assets/screenshots/overview.png)
![用量统计](assets/screenshots/usage.png)
![模型统计](assets/screenshots/models.png)
![菜单栏摘要](assets/screenshots/menu-bar.png)

## 功能

- 原生 SwiftUI 仪表板，可查看余额、用量、成本、模型汇总和日趋势
- 菜单栏摘要，方便快速查看
- 通过内嵌 WebView 捕获 DeepSeek 登录会话
- 本地告警：低余额、成本阈值、每月 Token 阈值
- 中英文界面文案
- 针对 API 解析、格式化、凭据存储和告警行为的单元测试

## 环境要求

- macOS 15 或更高版本
- Xcode 26，或支持 Swift 6.2 的 Swift 工具链

## 构建

```sh
swift build
```

## 测试

```sh
swift test
```

## 运行与打包

辅助脚本会把 macOS `.app` 打包到 `dist/`。

```sh
./script/build_and_run.sh run
```

不启动应用，直接生成发布包：

```sh
./script/build_and_run.sh package
```

打包后的应用路径：

```text
dist/DeepSeekMonitor.app
```

## Release 压缩包

打包完成后，可以生成适合上传到 GitHub Releases 的 zip：

```sh
ditto -c -k --keepParent dist/DeepSeekMonitor.app dist/DeepSeekMonitor-macOS.zip
```

## 隐私与凭据

DeepSeek Monitor 会把抓取到的 DeepSeek 会话 token 和 cookie header 保存到用户的 Application Support 目录：

```text
~/Library/Application Support/DeepSeekMonitor/credentials.json
```

这些凭据不在源码仓库里。`.har`、本地日志、`.env` 文件、构建产物和打包后的应用都会被 Git 忽略。

发布 fork 或 Release 前，建议执行：

```sh
git status --ignored
rg -n --hidden -S "token|cookie|authorization|bearer|api[_-]?key|secret|password|ghp_|github_pat_" .
```

请手动确认命中的内容。这个项目里大多数命中只是源码中对 token 处理的引用，不是真实密钥。

## 说明

DeepSeek 平台网页界面可能会变化。如果登录捕获或 API 调用失效，请连同应用版本、macOS 版本和具体报错一起提 issue。不要附带包含 cookie、token 或账户信息的 HAR 文件或截图。
