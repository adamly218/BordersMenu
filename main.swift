// BordersMenu: a menu bar settings menu for JankyBorders.
// Reads and writes ~/.config/borders/bordersrc and applies changes live
// by calling `borders key=value ...`, which updates the running instance.

import AppKit
import ServiceManagement

let brew = "/opt/homebrew/bin/brew"
let bordersBin = "/opt/homebrew/bin/borders"
let configURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/borders/bordersrc")

let colorPresets: [(String, String)] = [
    ("Violet", "0xff8a7cff"), ("Blue", "0xff3d8bff"), ("Cyan", "0xff2ad4e0"),
    ("Green", "0xff34d07b"), ("Yellow", "0xffffd23f"), ("Orange", "0xffff8a3d"),
    ("Pink", "0xffff5fa2"), ("Red", "0xffff4d4d"), ("White", "0xffe2e2e3"),
]
let inactivePresets: [(String, String)] = [
    ("No Border", "0x00000000"), ("Faint White", "0x33ffffff"), ("Dim Gray", "0xff414550"),
]
let widthPresets: [Double] = [2, 3, 5, 8, 12]

// MARK: - Config file

struct Config {
    // Keys in file order; values kept raw (quotes included) so unknown keys survive.
    var keys: [String] = []
    var values: [String: String] = [:]

    subscript(key: String) -> String? {
        get { values[key] }
        set {
            if values[key] == nil { keys.append(key) }
            values[key] = newValue
        }
    }

    static let defaults: [(String, String)] = [
        ("style", "round"), ("width", "5.0"), ("hidpi", "on"),
        ("active_color", "0xff8a7cff"), ("inactive_color", "0x00000000"),
    ]

    static func load() -> Config {
        var config = Config()
        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        var inOptions = false
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.components(separatedBy: "#")[0].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("options=(") { inOptions = true; continue }
            if inOptions && line.hasPrefix(")") { inOptions = false; continue }
            guard inOptions, let eq = line.firstIndex(of: "=") else { continue }
            config[String(line[..<eq])] = String(line[line.index(after: eq)...])
        }
        for (key, value) in defaults where config[key] == nil { config[key] = value }
        return config
    }

    func save() {
        var lines = [
            "#!/bin/bash",
            "# JankyBorders config, written by BordersMenu (menu bar).",
            "# Colors are 0xAARRGGBB (AA = opacity: ff solid, 00 invisible).",
            "",
            "options=(",
        ]
        lines += keys.compactMap { key in values[key].map { "\t\(key)=\($0)" } }
        lines += [")", "", "borders \"${options[@]}\"", ""]
        try? FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? lines.joined(separator: "\n").write(to: configURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: configURL.path)
    }

    /// Arguments for `borders`, with shell quotes removed.
    var arguments: [String] {
        keys.compactMap { key in
            values[key].map { "\(key)=\($0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")))" }
        }
    }
}

// MARK: - Helpers

@discardableResult
func run(_ path: String, _ args: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return -1 }
    process.waitUntilExit()
    return process.terminationStatus
}

func bordersRunning() -> Bool {
    run("/usr/bin/pgrep", ["-x", "borders"]) == 0
}

func color(fromHex hex: String) -> NSColor? {
    guard let value = UInt32(hex.replacingOccurrences(of: "0x", with: ""), radix: 16) else { return nil }
    return NSColor(
        srgbRed: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255,
        blue: CGFloat(value & 0xff) / 255, alpha: CGFloat((value >> 24) & 0xff) / 255)
}

func hex(from color: NSColor) -> String {
    let c = color.usingColorSpace(.sRGB) ?? color
    let r = Int(round(c.redComponent * 255)), g = Int(round(c.greenComponent * 255)),
        b = Int(round(c.blueComponent * 255))
    return String(format: "0xff%02x%02x%02x", r, g, b)
}

/// Menu title with a colored dot in front. macOS 27 doesn't show images on these
/// menu items, so the swatch lives in the text instead.
func swatchTitle(_ title: String, _ hex: String) -> NSAttributedString {
    let font = NSFont.menuFont(ofSize: 0)
    let text = NSMutableAttributedString(
        string: "●  ", attributes: [.foregroundColor: color(fromHex: hex) ?? .clear, .font: font])
    text.append(NSAttributedString(string: title, attributes: [.font: font]))
    return text
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var config = Config.load()
    var pendingColor: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let index = CommandLine.arguments.firstIndex(of: "--demo"),
           index + 1 < CommandLine.arguments.count {
            demo(CommandLine.arguments[index + 1])
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "square.dashed", accessibilityDescription: "Borders")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // Screenshot mode (`BordersMenu --demo menu|colors|window`): shows the menu or a sample
    // window on a plain backdrop for a few seconds, without adding a menu bar icon.
    func demo(_ mode: String) {
        let menu = NSMenu()
        menuNeedsUpdate(menu)
        if mode == "colors" {
            menu.removeAllItems()
            let colors = colorMenu()
            for entry in colors.items {
                colors.removeItem(entry)
                menu.addItem(entry)
            }
        }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let center = NSPoint(x: screen.midX, y: screen.midY)

        let backdrop = plainWindow(
            NSRect(x: center.x - 450, y: center.y - 300, width: 900, height: 600),
            color: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1), titled: false)
        // borders skips windows of menu-bar-only apps, so act like a normal app here.
        if mode == "window" { NSApp.setActivationPolicy(.regular) }
        backdrop.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        // A popped-up menu runs its own event loop, so the quit timer must run in common modes.
        let quit = Timer(timeInterval: 10, repeats: false) { _ in
            menu.cancelTrackingWithoutAnimation()
            NSApp.terminate(nil)
        }
        RunLoop.main.add(quit, forMode: .common)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch mode {
            case "window":
                let front = self.plainWindow(
                    NSRect(x: center.x - 260, y: center.y - 150, width: 520, height: 300),
                    color: NSColor(srgbRed: 0.18, green: 0.18, blue: 0.21, alpha: 1), titled: true)
                front.title = "Focused window"
                backdrop.orderFrontRegardless()
                front.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            default:
                menu.popUp(positioning: nil, at: NSPoint(x: center.x - 110, y: center.y + 180), in: nil)
            }
        }
    }

    // The backdrop is a titled window with its title bar hidden: a borderless one
    // doesn't stay on screen once the app switches to a regular app.
    private func plainWindow(_ frame: NSRect, color: NSColor, titled: Bool) -> NSWindow {
        let window = NSWindow(
            contentRect: frame,
            styleMask: titled ? [.titled, .closable] : [.titled, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.backgroundColor = color
        window.isReleasedWhenClosed = false
        if !titled {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(button)?.isHidden = true
            }
        }
        return window
    }

    // Rebuild each time so it reflects the file and the service state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        config = Config.load()
        menu.removeAllItems()
        let running = bordersRunning()

        let toggle = item(running ? "Borders On" : "Borders Off", #selector(toggleBorders))
        toggle.state = running ? .on : .off
        menu.addItem(toggle)
        menu.addItem(.separator())

        let colorItem = submenu("Color", colorMenu())
        colorItem.attributedTitle = swatchTitle("Color", config["active_color"] ?? "")
        menu.addItem(colorItem)

        let widthMenu = NSMenu()
        let width = Double(config["width"] ?? "") ?? 0
        for value in widthPresets {
            let entry = item("\(Int(value)) pt", #selector(pickWidth(_:)), String(format: "%.1f", value))
            entry.state = width == value ? .on : .off
            widthMenu.addItem(entry)
        }
        menu.addItem(submenu("Width", widthMenu))

        let styleMenu = NSMenu()
        for style in ["round", "square"] {
            let entry = item(style.capitalized, #selector(pickOption(_:)), "style=\(style)")
            entry.state = config["style"] == style ? .on : .off
            styleMenu.addItem(entry)
        }
        menu.addItem(submenu("Corners", styleMenu))

        let inactiveMenu = NSMenu()
        let inactive = config["inactive_color"]?.lowercased() ?? ""
        for (name, value) in inactivePresets {
            let entry = item(name, #selector(pickOption(_:)), "inactive_color=\(value)")
            entry.state = inactive == value ? .on : .off
            inactiveMenu.addItem(entry)
        }
        menu.addItem(submenu("Other Windows", inactiveMenu))

        menu.addItem(.separator())
        menu.addItem(item("Restart Borders", #selector(restartBorders)))
        menu.addItem(item("Open Config File", #selector(openConfig)))
        let login = item("Open Menu at Login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(item("Quit Menu", #selector(NSApplication.terminate(_:)), target: NSApp))
    }

    private func colorMenu() -> NSMenu {
        let active = config["active_color"]?.lowercased() ?? ""
        let menu = NSMenu()
        for (name, value) in colorPresets {
            let entry = item(name, #selector(pickColor(_:)), value)
            entry.attributedTitle = swatchTitle(name, value)
            entry.state = active == value ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(item("Custom…", #selector(customColor)))
        return menu
    }

    private func item(_ title: String, _ action: Selector, _ value: String? = nil,
                      target: AnyObject? = nil) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = target ?? self
        entry.representedObject = value
        return entry
    }

    private func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        entry.submenu = menu
        return entry
    }

    // MARK: Actions

    /// Save the file, then push the settings to the running borders process.
    func apply() {
        config.save()
        let args = config.arguments
        DispatchQueue.global().async {
            if bordersRunning() { run(bordersBin, args) }
        }
    }

    @objc func toggleBorders() {
        let command = bordersRunning() ? "stop" : "start"
        DispatchQueue.global().async { run(brew, ["services", command, "borders"]) }
    }

    // On macOS 27, borders can vanish after a window leaves full screen
    // (FelixKratz/JankyBorders#201). A restart brings them back.
    @objc func restartBorders() {
        DispatchQueue.global().async { run(brew, ["services", "restart", "borders"]) }
    }

    @objc func pickColor(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        config["active_color"] = value
        apply()
    }

    @objc func pickWidth(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        config["width"] = value
        apply()
    }

    @objc func pickOption(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? String, let eq = pair.firstIndex(of: "=") else { return }
        config[String(pair[..<eq])] = String(pair[pair.index(after: eq)...])
        apply()
    }

    @objc func customColor() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.isContinuous = true
        panel.color = color(fromHex: config["active_color"] ?? "") ?? .systemPurple
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    // Dragging in the color wheel fires constantly, so wait for a short pause.
    @objc func colorPanelChanged(_ panel: NSColorPanel) {
        pendingColor?.cancel()
        let value = hex(from: panel.color)
        let work = DispatchWorkItem { [weak self] in
            self?.config["active_color"] = value
            self?.apply()
        }
        pendingColor = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    @objc func openConfig() {
        if !FileManager.default.fileExists(atPath: configURL.path) { config.save() }
        NSWorkspace.shared.open(
            [configURL], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
            configuration: NSWorkspace.OpenConfiguration())
    }

    @objc func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Open at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
