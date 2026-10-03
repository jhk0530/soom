import SwiftUI
import AppKit

@main
struct SoomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

/// A single user preference domain. No shell interpolation or Automation access.
struct PreferenceStore {
    let domain: CFString

    func read(_ key: String) -> Bool? {
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return CFPreferencesCopyValue(key as CFString, domain,
                                      kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Bool
    }

    func write(_ key: String, _ value: Bool?) throws {
        CFPreferencesSetValue(key as CFString, value.map { $0 as CFBoolean }, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost),
              read(key) == value else {
            throw NSError(domain: "soom", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "설정을 저장하지 못했습니다. 다시 시도해 주세요."
            ])
        }
    }
}

struct MenuBarSettings {
    static let store = PreferenceStore(domain: kCFPreferencesAnyApplication)
    static var hidesOnDesktop: Bool { store.read("_HIHideMenuBar") ?? false }
    static var label: String {
        switch (hidesOnDesktop, store.read("AppleMenuBarVisibleInFullscreen") ?? false) {
        case (true, false): return "항상"
        case (false, false): return "전체 화면일 때만"
        case (true, true): return "데스크탑에서만"
        case (false, true): return "안 함"
        }
    }

    static func toggle() throws {
        try apply(hideOnDesktop: !hidesOnDesktop)
    }

    static func apply(hideOnDesktop: Bool) throws {
        let originalHide = store.read("_HIHideMenuBar")
        let originalFullscreen = store.read("AppleMenuBarVisibleInFullscreen")
        do {
            try store.write("_HIHideMenuBar", hideOnDesktop)
            // Both supported modes hide the menu bar in fullscreen.
            try store.write("AppleMenuBarVisibleInFullscreen", false)
        } catch {
            try? store.write("_HIHideMenuBar", originalHide)
            try? store.write("AppleMenuBarVisibleInFullscreen", originalFullscreen)
            reapply()
            throw error
        }
        reapply()
    }

    static func reapply() {
        let center = DistributedNotificationCenter.default()
        for name in ["AppleInterfaceMenuBarHidingChangedNotification",
                     "AppleInterfaceFullScreenMenuBarVisibilityChangedNotification"] {
            center.postNotificationName(NSNotification.Name(name), object: nil,
                                        userInfo: nil, deliverImmediately: true)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let desktopStore = PreferenceStore(domain: "com.apple.finder" as CFString)
    private var refreshTimer: Timer?
    private var desktopToggleItem: NSMenuItem!
    private var alwaysHideItem: NSMenuItem!
    private var fullscreenHideItem: NSMenuItem!
    private var menuBarStateItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        if let icon = NSImage(named: "AppIcon") { NSApp.applicationIconImage = icon }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "soom.main"
        configure(statusItem, action: #selector(statusItemClicked(_:)))
        configureMenu()
        refresh()
        MenuBarSettings.reapply()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private var desktopVisible: Bool { desktopStore.read("CreateDesktop") ?? true }

    private func configure(_ item: NSStatusItem, action: Selector) {
        item.button?.target = self
        item.button?.action = action
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func addItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    private func configureMenu() {
        menu.delegate = self
        desktopToggleItem = addItem("바탕화면 아이콘 표시", action: #selector(toggleDesktopIcons(_:)))
        menu.addItem(.separator())
        menuBarStateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(menuBarStateItem)
        alwaysHideItem = addItem("항상", action: #selector(selectAlwaysHide(_:)))
        fullscreenHideItem = addItem("전체 화면일 때만", action: #selector(selectFullscreenHide(_:)))
        _ = addItem("메뉴 막대 설정 다시 적용", action: #selector(reapplyMenuBar(_:)))
        menu.addItem(.separator())
        _ = addItem("soom 정보", action: #selector(showAboutPanel(_:)))
        _ = addItem("soom 종료", action: #selector(quitApp(_:)), key: "q")
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    private var isContextClick: Bool {
        NSApp.currentEvent?.type == .rightMouseUp ||
        NSApp.currentEvent?.modifierFlags.contains(.control) == true
    }

    private func showMenu() {
        refresh()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if isContextClick { showMenu() }
        else { toggleMenuBar(sender) }
    }

    @objc private func toggleDesktopIcons(_ sender: Any?) {
        let original = desktopStore.read("CreateDesktop")
        do {
            try desktopStore.write("CreateDesktop", !desktopVisible)
            // Finder applies CreateDesktop at launch. Restrict the restart to this user.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = ["-u", NSUserName(), "Finder"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            // A missing Finder process is harmless; launching it loads the saved preference.
            if process.terminationStatus != 0 {
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") else {
                    throw NSError(domain: "soom", code: 2, userInfo: [NSLocalizedDescriptionKey: "Finder를 다시 시작하지 못했습니다."])
                }
                let config = NSWorkspace.OpenConfiguration()
                config.activates = false
                NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, error in
                    if let error {
                        Task { @MainActor [weak self] in
                            try? self?.desktopStore.write("CreateDesktop", original)
                            self?.refresh()
                            self?.showError(error)
                        }
                    }
                }
            }
        } catch {
            try? desktopStore.write("CreateDesktop", original)
            showError(error)
        }
        refresh()
    }

    @objc private func toggleMenuBar(_ sender: Any?) {
        do { try MenuBarSettings.toggle() }
        catch { showError(error) }
        refresh()
    }

    @objc private func selectAlwaysHide(_ sender: Any?) {
        setMenuBarMode(hideOnDesktop: true)
    }

    @objc private func selectFullscreenHide(_ sender: Any?) {
        setMenuBarMode(hideOnDesktop: false)
    }

    private func setMenuBarMode(hideOnDesktop: Bool) {
        do { try MenuBarSettings.apply(hideOnDesktop: hideOnDesktop) }
        catch { showError(error) }
        refresh()
    }

    @objc private func reapplyMenuBar(_ sender: Any?) {
        MenuBarSettings.reapply()
        refresh()
    }

    private func refresh() {
        let visible = desktopVisible
        let hide = MenuBarSettings.hidesOnDesktop
        let fullscreenVisible = MenuBarSettings.store.read("AppleMenuBarVisibleInFullscreen") ?? false
        let menuAction = hide ? "전체 화면일 때만 자동 가리기" : "항상 자동 가리기"
        // One stable soom icon; the context menu carries the individual states.
        let image = NSImage(systemSymbolName: "eyeglasses", accessibilityDescription: "soom")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "soom · 메뉴 막대: \(MenuBarSettings.label)\n클릭: \(menuAction) · 오른쪽 클릭: 설정"
        statusItem.button?.setAccessibilityLabel("soom, 메뉴 막대 \(MenuBarSettings.label), 클릭하면 \(menuAction)")
        desktopToggleItem.state = visible ? .on : .off
        menuBarStateItem.title = "메뉴 막대 자동 가리기: \(MenuBarSettings.label)"
        alwaysHideItem.state = hide && !fullscreenVisible ? .on : .off
        fullscreenHideItem.state = !hide && !fullscreenVisible ? .on : .off
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "설정을 변경하지 못했습니다"
        alert.informativeText = error.localizedDescription
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func showAboutPanel(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel([
            NSApplication.AboutPanelOptionKey.applicationName: "soom",
            NSApplication.AboutPanelOptionKey.applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3",
            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(string: "클릭으로 메뉴 막대를 전환하고, 오른쪽 클릭으로 바탕화면과 메뉴 막대를 설정하세요.")
        ])
    }

    @objc private func quitApp(_ sender: Any?) { NSApp.terminate(nil) }
}
