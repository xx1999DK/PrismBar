import AppKit
import SwiftUI
import Combine
import Carbon

final class DrawerPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

final class PrismApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
  let store: BarStore
  private var toggle: NSStatusItem!
  private var divider: NSStatusItem!
  private var panel: DrawerPanel?
  private var settingsWindow: NSWindow?
  private var timer: Timer?
  private var deadline: Date?
  private var activeItem: MenuItemHandle?
  private var hotkey: EventHotKeyRef?
  private var hotkeyHandler: EventHandlerRef?
  private var observers: [NSObjectProtocol] = []
  private var subscriptions: Set<AnyCancellable> = []
  private var isTerminating = false
  private var lastShortcutEnabled: Bool?
  let smokeTest: Bool

  init(smokeTest: Bool = false) {
    self.smokeTest = smokeTest
    let defaults = smokeTest ? UserDefaults(suiteName: "io.github.xx1999DK.PrismBar.smoke")! : .standard
    if smokeTest { defaults.removePersistentDomain(forName: "io.github.xx1999DK.PrismBar.smoke") }
    store = BarStore(defaults: defaults, preview: smokeTest)
    super.init()
  }
  func applicationDidFinishLaunching(_ notification: Notification) {
    if !smokeTest {
      let peers = NSRunningApplication.runningApplications(withBundleIdentifier: "io.github.xx1999DK.PrismBar")
      if peers.contains(where: { $0.processIdentifier != getpid() }) { NSApp.terminate(nil); return }
    }
    NSApp.setActivationPolicy(.accessory)
    toggle = NSStatusBar.system.statusItem(withLength: 30)
    toggle.autosaveName = smokeTest ? "PrismBar.Test.Toggle" : "PrismBar.Toggle"
    toggle.isVisible = true
    toggle.button?.target = self
    toggle.button?.action = #selector(clicked)
    toggle.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    toggle.button?.setAccessibilityLabel("PrismBar 菜单栏管理")
    divider = NSStatusBar.system.statusItem(withLength: 16)
    divider.autosaveName = smokeTest ? "PrismBar.Test.Divider" : "PrismBar.Divider"
    divider.button?.image = NSImage(systemSymbolName: "line.diagonal", accessibilityDescription: "收纳分隔线")
    divider.button?.toolTip = "按住 Command，将不常用图标拖到这条分隔线左侧。"
    divider.button?.target = self
    divider.button?.action = #selector(toggleFold)
    store.onPreferencesChanged = { [weak self] in self?.preferencesChanged() }
    store.onToggle = { [weak self] in self?.toggleFold() }
    store.onSettings = { [weak self] in self?.showSettings() }
    store.onOrganize = { [weak self] in self?.organize() }
    store.onActivate = { [weak self] id in self?.activate(id) }
    store.onClose = { [weak self] in self?.closePanel() }
    preferencesChanged()
    installObservers()
    store.$items.receive(on: RunLoop.main).sink { [weak self] _ in self?.resizePanelSoon() }.store(in: &subscriptions)
    store.$message.receive(on: RunLoop.main).sink { [weak self] _ in self?.resizePanelSoon() }.store(in: &subscriptions)
    if smokeTest { runSmokeTest(); return }
    if store.preferences.completedSetup { setCollapsed(true) }
    if !store.preferences.completedSetup || CommandLine.arguments.contains("--settings") { showSettings() }
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    showSettings(); return true
  }
  func applicationWillTerminate(_ notification: Notification) {
    isTerminating = true
    timer?.invalidate()
    if let hotkey { UnregisterEventHotKey(hotkey) }
    if let hotkeyHandler { RemoveEventHandler(hotkeyHandler) }
    observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0); NotificationCenter.default.removeObserver($0) }
    // Removing the spacer restores the system's menu-bar layout, including on normal Quit.
    if let divider { divider.length = 16; NSStatusBar.system.removeStatusItem(divider) }
    if let toggle { NSStatusBar.system.removeStatusItem(toggle) }
  }
  private func installObservers() {
    let center = NSWorkspace.shared.notificationCenter
    observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
      self?.timer?.invalidate(); self?.closePanel()
    })
    observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
      self?.store.refreshPermission(); self?.scheduleCollapse()
    })
    observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
      self?.closePanel()
      // A display change can reorder status items. Expand rather than trapping icons offscreen.
      self?.organize()
    })
    observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
      self?.store.refreshPermission()
    })
  }
  private func preferencesChanged() {
    let theme = store.preferences.theme
    let symbol = NSImage(systemSymbolName: theme.symbol, accessibilityDescription: "PrismBar")
    let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
      .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(hex: theme.tint), NSColor(hex: theme.secondaryTint)]))
    toggle?.button?.image = symbol?.withSymbolConfiguration(configuration)
    toggle?.button?.image?.isTemplate = theme == .minimal
    toggle?.button?.toolTip = "PrismBar · \(theme.name)\n点按：\(store.preferences.mode.title) · Option 点按：折叠 · 右键：设置"
    if lastShortcutEnabled != store.preferences.shortcutEnabled {
      lastShortcutEnabled = store.preferences.shortcutEnabled
      registerHotkey()
    }
    scheduleCollapse()
  }
  @objc private func clicked() {
    if NSApp.currentEvent?.type == .rightMouseUp { showMenu(); return }
    if NSApp.currentEvent?.modifierFlags.contains(.option) == true { toggleFold(); return }
    primaryAction()
  }
  func primaryAction() {
    if store.preferences.mode == .fold { toggleFold() }
    else if panel?.isVisible == true { closePanel() }
    else { showDrawer() }
  }
  @objc func toggleFold() {
    closePanel()
    setCollapsed(!store.collapsed)
  }
  private func setCollapsed(_ collapsed: Bool) {
    // Public NSStatusItem spacing technique; no private WindowServer or injection APIs.
    divider.length = collapsed ? 10000 : 16
    store.collapsed = collapsed
    toggle.button?.setAccessibilityValue(collapsed ? "菜单栏已收起" : "菜单栏已展开")
    if collapsed { timer?.invalidate(); deadline = nil; activeItem = nil }
    else { scheduleCollapse() }
  }
  private func organize() {
    setCollapsed(false)
    timer?.invalidate(); deadline = nil
    store.message = "整理期间保持展开。按住 Command 拖动图标，完成后点击“已放好，开始使用”。"
  }
  private func scheduleCollapse() {
    timer?.invalidate()
    guard !store.collapsed, store.preferences.autoCollapseSeconds > 0, store.trusted, !smokeTest else { deadline = nil; return }
    deadline = Date().addingTimeInterval(Double(store.preferences.autoCollapseSeconds))
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.collapseIfIdle() }
    timer?.tolerance = 0.25
  }
  private func collapseIfIdle() {
    let point = NSEvent.mouseLocation
    let atMenu = NSScreen.screens.contains { $0.frame.contains(point) && point.y >= $0.frame.maxY - 35 }
    let menuOpen = MenuAccessibility.menuIsOpen(activeItem)
    if atMenu || menuOpen { deadline = Date().addingTimeInterval(Double(store.preferences.autoCollapseSeconds)) }
    if CollapsePolicy.shouldCollapse(now: Date(), deadline: deadline, menuOpen: menuOpen, pointerAtMenuBar: atMenu, panelOpen: panel?.isVisible == true || settingsWindow?.isVisible == true) {
      setCollapsed(true)
    }
  }
  private func registerHotkey() {
    guard !smokeTest else { return }
    if let hotkey { UnregisterEventHotKey(hotkey); self.hotkey = nil }
    store.shortcutMessage = nil
    guard store.preferences.shortcutEnabled else { return }
    if hotkeyHandler == nil {
      var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
      InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        DispatchQueue.main.async { (NSApplication.shared.delegate as? PrismApp)?.primaryAction() }
        return noErr
      }, 1, &type, nil, &hotkeyHandler)
    }
    let id = EventHotKeyID(signature: 0x5052534D, id: 1)
    let result = RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(cmdKey | optionKey), id, GetApplicationEventTarget(), 0, &hotkey)
    if result != noErr { store.shortcutMessage = "⌥⌘B 已被占用；请使用菜单栏图标，或关闭冲突软件的同名快捷键。" }
  }
  @objc func showSettings() {
    closePanel()
    store.refreshPermission()
    if settingsWindow == nil {
      let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 620), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
      window.title = "PrismBar"
      window.isReleasedWhenClosed = false
      window.contentView = NSHostingView(rootView: SettingsView(store: store))
      window.center()
      settingsWindow = window
    }
    NSApp.activate(ignoringOtherApps: true)
    settingsWindow?.makeKeyAndOrderFront(nil)
  }
  @objc func showDrawer() {
    store.query = ""
    store.refreshPermission()
    if panel == nil {
      let panel = DrawerPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 440), styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless], backing: .buffered, defer: false)
      panel.isFloatingPanel = true
      panel.level = .statusBar
      panel.hasShadow = true
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hidesOnDeactivate = false
      panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      panel.delegate = self
      let effect = NSVisualEffectView()
      effect.material = .popover
      effect.state = .active
      effect.blendingMode = .behindWindow
      effect.wantsLayer = true
      effect.layer?.cornerRadius = 18
      effect.layer?.masksToBounds = true
      let host = NSHostingView(rootView: DrawerView(store: store))
      host.translatesAutoresizingMaskIntoConstraints = false
      effect.addSubview(host)
      NSLayoutConstraint.activate([host.leadingAnchor.constraint(equalTo: effect.leadingAnchor), host.trailingAnchor.constraint(equalTo: effect.trailingAnchor), host.topAnchor.constraint(equalTo: effect.topAnchor), host.bottomAnchor.constraint(equalTo: effect.bottomAnchor)])
      panel.contentView = effect
      self.panel = panel
    }
    positionPanel()
    panel?.makeKeyAndOrderFront(nil)
    store.scan()
  }
  private func resizePanelSoon() {
    DispatchQueue.main.async { [weak self] in if self?.panel?.isVisible == true { self?.positionPanel() } }
  }
  private func positionPanel() {
    guard let panel, let button = toggle.button, let window = button.window else { return }
    let screen = window.screen ?? NSScreen.main!
    let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
    let desired = panel.contentView?.subviews.first?.fittingSize.height ?? 440
    let height = min(max(desired, 300), screen.visibleFrame.height - 24)
    let x = PanelPlacement.origin(anchorX: anchor.midX, screenX: screen.visibleFrame.minX, screenWidth: screen.visibleFrame.width, panelWidth: 440)
    let y = max(screen.visibleFrame.minY + 12, min(anchor.minY - height - 8, screen.visibleFrame.maxY - height - 8))
    panel.setFrame(NSRect(x: x, y: y, width: 440, height: height), display: true)
  }
  private func closePanel() { panel?.orderOut(nil) }
  func windowDidResignKey(_ notification: Notification) {
    if (notification.object as? NSWindow) === panel { closePanel() }
  }
  private func activate(_ id: String) {
    guard store.trusted, let handle = store.handles[id] else { store.message = "项目已变化，请刷新后重试。"; return }
    closePanel()
    setCollapsed(false)
    // Let the system finish laying out the original menu bar before opening its menu.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      guard let self, !self.isTerminating else { return }
      let result = MenuAccessibility.press(handle)
      if result == .success {
        self.activeItem = handle
        self.scheduleCollapse()
      } else {
        self.timer?.invalidate(); self.deadline = nil
        self.store.message = "“\(handle.descriptor.title)”不支持辅助功能点击，或项目已失效。菜单栏已展开，请直接点击原图标；也可刷新列表重试。"
        self.showDrawer()
      }
    }
  }
  private func showMenu() {
    let menu = NSMenu()
    func add(_ title: String, _ selector: Selector) {
      let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
      item.target = self; menu.addItem(item)
    }
    add("打开聚合抽屉", #selector(showDrawer))
    add(store.collapsed ? "展开菜单栏" : "收起菜单栏", #selector(toggleFold))
    menu.addItem(.separator())
    add("设置与十款外观…", #selector(showSettings))
    menu.addItem(.separator())
    add("退出 PrismBar", #selector(quit))
    toggle.menu = menu
    toggle.button?.performClick(nil)
    toggle.menu = nil
  }
  @objc private func quit() { NSApp.terminate(nil) }

  private func runSmokeTest() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
      precondition(toggle.isVisible && divider.length == 16)
      setCollapsed(true)
      precondition(divider.length == 10000 && store.collapsed)
      setCollapsed(false)
      precondition(divider.length == 16 && !store.collapsed)
      for theme in BarTheme.allCases {
        store.preferences.theme = theme
        precondition(toggle.button?.image != nil, "Missing SF Symbol for \(theme)")
      }
      showSettings()
      precondition(settingsWindow?.contentView?.fittingSize.width == 780)
      settingsWindow?.close()
      print("PASS: status items, expand/collapse, 10 theme symbols, native settings view, clean quit")
      NSApp.terminate(nil)
    }
  }
}
