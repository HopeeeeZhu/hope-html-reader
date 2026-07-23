# hope的html阅读器

一款极简的 macOS 本地 HTML 阅读器。

## 功能

- 左侧自动显示当前文件夹中的全部 `.html` 和 `.htm` 文件；
- 完整呈现原始 HTML，不裁剪、不改写页面；
- HTML 保存后约半秒自动刷新；
- 侧边栏可调整宽度，也可以一键收起；
- 支持 Intel 与 Apple 芯片，最低 macOS 13。

## 安装

从 GitHub Releases 下载 `hope-html-reader-1.1-macos.dmg`，打开后将“hope的html阅读器”拖到“Applications”。

当前版本采用本地签名，未经过 Apple 公证。首次打开如被系统拦截，请在访达中右键应用并选择“打开”。

## 使用

- 将 `.html` 或 `.htm` 文件拖入窗口；
- 点击文件夹按钮选择文件；
- 在访达中右键 HTML 文件，选择“打开方式 → hope的html阅读器”。

同目录下的 CSS、JavaScript、图片等资源会随页面正常载入。

## 本地构建

```zsh
chmod +x build.sh package.sh
./build.sh
./package.sh
```
