# Hope HTML Reader

[中文](README.md) · **English**

## In one sentence

Drop in one HTML file and browse the entire folder like a document library; the page refreshes automatically whenever you save a change.

## When it helps

- You made an HTML report, web demo, or knowledge card with AI and want to preview it immediately.
- A folder contains many HTML files and opening them one by one is tedious.
- You are editing a local page and want every save to appear automatically.
- You want to keep the files on your Mac instead of uploading them to a website.

## Features

- Shows every `.html` and `.htm` file in the current folder.
- Renders the original HTML without rewriting or cropping the page.
- Refreshes about half a second after the file is saved.
- Resizable and collapsible sidebar.
- Can associate each existing HTML file in the current folder with this app.
- Supports Intel and Apple Silicon Macs running macOS 13 or later.

## Install

Download `hope-html-reader-1.2-macos.dmg` from [GitHub Releases](https://github.com/HopeeeeZhu/hope-html-reader/releases), open it, and drag Hope HTML Reader into Applications.

The current build is locally signed but not Apple-notarized. If macOS blocks the first launch, right-click the app in Finder and choose **Open**.

## Use

- Drag an `.html` or `.htm` file into the window.
- Use the folder button to choose a file.
- In Finder, right-click an HTML file and choose **Open With → Hope HTML Reader**.

To make **Default app** in Codex or Finder open these files with Hope HTML Reader, open any HTML in the folder and choose **File → Set Current Folder HTML as Default**. This only affects existing `.html` and `.htm` files in that folder; web links and other file types are unchanged.

CSS, JavaScript, images, and other files in the same folder load normally.

## Build locally

```zsh
chmod +x build.sh package.sh
./build.sh
./package.sh
```
