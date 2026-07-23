import AppKit
import UniformTypeIdentifiers
import WebKit

final class ReaderWebView: WKWebView {
    var onFileDrop: ((URL) -> Void)?

    override init(frame: NSRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        htmlURL(from: sender) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = htmlURL(from: sender) else { return false }
        onFileDrop?(url)
        return true
    }

    private func htmlURL(from sender: NSDraggingInfo) -> URL? {
        guard
            let item = sender.draggingPasteboard.pasteboardItems?.first,
            let value = item.string(forType: .fileURL),
            let url = URL(string: value),
            ["html", "htm"].contains(url.pathExtension.lowercased())
        else {
            return nil
        }
        return url
    }
}

private struct FileStamp: Equatable {
    let modifiedAt: Date
    let size: UInt64
}

final class ReaderWindowController: NSWindowController, WKNavigationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuItemValidation {
    private let webView: ReaderWebView
    private let titleLabel = NSTextField(labelWithString: "hope的html阅读器")
    private let backButton = NSButton()
    private let forwardButton = NSButton()
    private let sidebarButton = NSButton()
    private let tableView = NSTableView()
    private weak var splitView: NSSplitView?
    private var sidebarMinimumWidthConstraint: NSLayoutConstraint?
    private var lastSidebarWidth: CGFloat = 160
    private var htmlFiles: [URL] = []
    private var currentFileURL: URL?
    private var currentFileStamp: FileStamp?
    private var syncTimer: Timer?
    private var pendingScrollPosition: (x: Double, y: Double)?

    init() {
        let configuration = WKWebViewConfiguration()
        webView = ReaderWebView(frame: .zero, configuration: configuration)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "hope的html阅读器"
        window.minSize = NSSize(width: 640, height: 420)
        window.center()

        super.init(window: window)
        webView.navigationDelegate = self
        webView.onFileDrop = { [weak self] url in self?.open(url) }
        window.contentView = makeContentView()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.splitView?.setPosition(self.lastSidebarWidth, ofDividerAt: 0)
        }
        showWelcome()
        startAutoSync()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeContentView() -> NSView {
        let root = NSView()
        let toolbar = NSVisualEffectView()
        toolbar.material = .headerView
        toolbar.blendingMode = .withinWindow

        configureButton(backButton, symbol: "chevron.left", tooltip: "后退", action: #selector(goBack))
        configureButton(forwardButton, symbol: "chevron.right", tooltip: "前进", action: #selector(goForward))

        let openButton = NSButton()
        configureButton(openButton, symbol: "folder", tooltip: "打开 HTML", action: #selector(chooseFile))

        let reloadButton = NSButton()
        configureButton(reloadButton, symbol: "arrow.clockwise", tooltip: "刷新", action: #selector(reload))
        configureButton(sidebarButton, symbol: "sidebar.left", tooltip: "收起/展开侧边栏", action: #selector(toggleSidebar))

        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle

        let stack = NSStackView(views: [backButton, forwardButton, openButton, reloadButton, sidebarButton, titleLabel])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(stack)

        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addArrangedSubview(makeSidebar())
        splitView.addArrangedSubview(webView)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 0)
        self.splitView = splitView

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        splitView.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(toolbar)
        root.addSubview(splitView)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: root.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 34),
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            splitView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        splitView.setPosition(lastSidebarWidth, ofDividerAt: 0)
        return root
    }

    private func makeSidebar() -> NSView {
        let sidebar = NSVisualEffectView()
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow

        let heading = NSTextField(labelWithString: "同文件夹 HTML")
        heading.font = .systemFont(ofSize: 12, weight: .semibold)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("FileColumn"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.rowHeight = 25
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.style = .sourceList
        tableView.dataSource = self
        tableView.delegate = self

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        heading.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(heading)
        sidebar.addSubview(scrollView)

        let minimumWidth = sidebar.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        sidebarMinimumWidthConstraint = minimumWidth
        NSLayoutConstraint.activate([
            minimumWidth,
            sidebar.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
            heading.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 12),
            heading.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            heading.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -10),
            scrollView.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -6),
            scrollView.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -6)
        ])
        return sidebar
    }

    private func configureButton(_ button: NSButton, symbol: String, tooltip: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.bezelStyle = .texturedRounded
        button.isBordered = false
        button.toolTip = tooltip
        button.target = self
        button.action = action
    }

    func open(_ url: URL) {
        guard ["html", "htm"].contains(url.pathExtension.lowercased()) else {
            showError("请选择 .html 或 .htm 文件。")
            return
        }
        currentFileURL = url.standardizedFileURL
        currentFileStamp = fileStamp(for: currentFileURL!)
        refreshFileList()
        loadCurrentFile()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func loadCurrentFile() {
        guard let url = currentFileURL else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        selectCurrentFile()
    }

    private func refreshFileList() {
        guard let folder = currentFileURL?.deletingLastPathComponent() else {
            htmlFiles = []
            tableView.reloadData()
            return
        }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let updatedFiles = files
            .filter { ["html", "htm"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        if updatedFiles != htmlFiles {
            htmlFiles = updatedFiles
            tableView.reloadData()
        }
        selectCurrentFile()
    }

    private func selectCurrentFile() {
        guard let currentFileURL, let index = htmlFiles.firstIndex(of: currentFileURL) else {
            tableView.deselectAll(nil)
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    @objc func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            open(url)
        }
    }

    @objc func goBack() {
        webView.goBack()
    }

    @objc func goForward() {
        webView.goForward()
    }

    @objc func reload() {
        webView.reload()
    }

    @objc func setAsDefaultHTMLReader() {
        NSWorkspace.shared.setDefaultApplication(
            at: Bundle.main.bundleURL,
            toOpen: .html
        ) { error in
            DispatchQueue.main.async {
                let alert = NSAlert()
                if let error {
                    alert.messageText = "无法设为默认阅读器"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                } else {
                    alert.messageText = "已设为默认 HTML 阅读器"
                    alert.informativeText = "以后在访达中双击 .html 或 .htm 文件，将使用 hope的html阅读器 打开。网页链接和其他文件的默认应用不会改变。"
                    alert.alertStyle = .informational
                }
                alert.runModal()
            }
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(setAsDefaultHTMLReader) else { return true }
        let isDefault = NSWorkspace.shared
            .urlForApplication(toOpen: .html)
            .flatMap(Bundle.init(url:))?
            .bundleIdentifier == Bundle.main.bundleIdentifier
        menuItem.title = isDefault ? "已是默认 HTML 阅读器" : "设为默认 HTML 阅读器"
        menuItem.state = isDefault ? .on : .off
        return !isDefault
    }

    @objc func toggleSidebar() {
        guard let splitView, !splitView.subviews.isEmpty else { return }
        let sidebar = splitView.subviews[0]
        if sidebar.isHidden {
            sidebar.isHidden = false
            sidebarMinimumWidthConstraint?.isActive = true
            splitView.adjustSubviews()
            splitView.setPosition(max(lastSidebarWidth, 140), ofDividerAt: 0)
        } else {
            lastSidebarWidth = sidebar.frame.width
            sidebarMinimumWidthConstraint?.isActive = false
            sidebar.isHidden = true
            splitView.adjustSubviews()
        }
    }

    private func showWelcome() {
        let html = """
        <!doctype html>
        <meta charset="utf-8">
        <style>
          :root { color-scheme: light dark; }
          body { margin: 0; min-height: 100vh; display: grid; place-items: center;
                 font: 16px -apple-system, BlinkMacSystemFont, sans-serif; color: #67676d;
                 background: #f7f7f5; }
          main { text-align: center; padding: 48px; }
          .icon { font-size: 52px; margin-bottom: 18px; }
          h1 { color: #252529; font-size: 24px; margin: 0 0 10px; }
          p { margin: 6px 0; line-height: 1.7; }
          kbd { background: #e8e8e5; border-radius: 6px; padding: 3px 7px; }
          @media (prefers-color-scheme: dark) {
            body { background: #1e1e1e; color: #aaa; }
            h1 { color: #f1f1f1; }
            kbd { background: #343434; }
          }
        </style>
        <main>
          <div class="icon">📄</div>
          <h1>hope的html阅读器</h1>
          <p>打开一个 HTML，左侧会显示同文件夹内的全部 HTML</p>
          <p>也可以按 <kbd>⌘ O</kbd> 选择文件</p>
        </main>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "无法打开文件"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let title = currentFileURL?.lastPathComponent ?? "hope的html阅读器"
        titleLabel.stringValue = title
        window?.title = title
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
        if let position = pendingScrollPosition {
            pendingScrollPosition = nil
            webView.evaluateJavaScript("window.scrollTo(\(position.x), \(position.y))")
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        max(htmlFiles.count, 1)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: htmlFiles.isEmpty ? "此文件夹没有 HTML" : htmlFiles[row].lastPathComponent)
        label.font = .systemFont(ofSize: 12)
        label.textColor = htmlFiles.isEmpty ? .tertiaryLabelColor : .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard htmlFiles.indices.contains(row), htmlFiles[row] != currentFileURL else { return }
        open(htmlFiles[row])
    }

    private func startAutoSync() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    private func checkForChanges() {
        guard let url = currentFileURL else { return }
        refreshFileList()
        guard let newStamp = fileStamp(for: url), newStamp != currentFileStamp else { return }
        currentFileStamp = newStamp
        reloadPreservingScrollPosition()
    }

    private func fileStamp(for url: URL) -> FileStamp? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let modifiedAt = attributes[.modificationDate] as? Date,
            let size = attributes[.size] as? NSNumber
        else {
            return nil
        }
        return FileStamp(modifiedAt: modifiedAt, size: size.uint64Value)
    }

    private func reloadPreservingScrollPosition() {
        webView.evaluateJavaScript("[window.scrollX, window.scrollY]") { [weak self] result, _ in
            guard let self else { return }
            if let values = result as? [NSNumber], values.count == 2 {
                self.pendingScrollPosition = (values[0].doubleValue, values[1].doubleValue)
            }
            self.webView.reloadFromOrigin()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var reader: ReaderWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if reader == nil {
            reader = ReaderWindowController()
        }
        reader?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if reader == nil {
            reader = ReaderWindowController()
        }
        if let url = urls.first {
            reader?.open(url)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private func makeMainMenu() -> NSMenu {
    let main = NSMenu()

    let appItem = NSMenuItem()
    main.addItem(appItem)
    let appMenu = NSMenu()
    appItem.submenu = appMenu
    let defaultItem = appMenu.addItem(
        withTitle: "设为默认 HTML 阅读器",
        action: #selector(ReaderWindowController.setAsDefaultHTMLReader),
        keyEquivalent: ""
    )
    defaultItem.target = nil
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "退出hope的html阅读器", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    let fileItem = NSMenuItem()
    main.addItem(fileItem)
    let fileMenu = NSMenu(title: "文件")
    fileItem.submenu = fileMenu
    let openItem = fileMenu.addItem(withTitle: "打开…", action: #selector(ReaderWindowController.chooseFile), keyEquivalent: "o")
    openItem.target = nil
    fileMenu.addItem(.separator())
    fileMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

    let viewItem = NSMenuItem()
    main.addItem(viewItem)
    let viewMenu = NSMenu(title: "显示")
    viewItem.submenu = viewMenu
    viewMenu.addItem(withTitle: "刷新", action: #selector(ReaderWindowController.reload), keyEquivalent: "r")
    viewMenu.addItem(.separator())
    viewMenu.addItem(withTitle: "进入全屏幕", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
    return main
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.mainMenu = makeMainMenu()
app.setActivationPolicy(.regular)
app.run()
