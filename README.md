# hope的html阅读器

**中文** · [English](README_EN.md)

## 一句话看懂

把一个 HTML 文件拖进去，就能像翻文件夹一样查看整套本地网页；保存修改后，页面会自动刷新。

## 适合这些时候

- 用 AI 做了 HTML 汇报、网页 Demo 或知识卡片，想马上预览。
- 一个文件夹里有很多 HTML，不想每次都回访达逐个打开。
- 一边改代码一边看效果，希望保存后自动刷新。
- 只想在本机查看文件，不想上传到网站。

## 功能

- 左侧自动显示当前文件夹中的全部 `.html` 和 `.htm` 文件；
- 完整呈现原始 HTML，不裁剪、不改写页面；
- HTML 保存后约半秒自动刷新；
- 侧边栏可调整宽度，也可以一键收起；
- 可将当前文件夹中的 HTML 分别设为由本应用默认打开；
- 支持 Intel 与 Apple 芯片，最低 macOS 13。

## 安装

从 GitHub Releases 下载 `hope-html-reader-1.2-macos.dmg`，打开后将“hope的html阅读器”拖到“Applications”。

当前版本采用本地签名，未经过 Apple 公证。首次打开如被系统拦截，请在访达中右键应用并选择“打开”。

## 使用

- 将 `.html` 或 `.htm` 文件拖入窗口；
- 点击文件夹按钮选择文件；
- 在访达中右键 HTML 文件，选择“打开方式 → hope的html阅读器”。

如需让 Codex 或访达中的“Default app”直接使用本应用，请先打开该文件夹中的任意 HTML，再从“文件”菜单选择“将当前文件夹 HTML 设为默认打开方式”。该操作只影响当前文件夹中现有的 `.html` 和 `.htm` 文件，不改变网页链接及其他文件的默认应用。

同目录下的 CSS、JavaScript、图片等资源会随页面正常载入。

## 本地构建

```zsh
chmod +x build.sh package.sh
./build.sh
./package.sh
```
