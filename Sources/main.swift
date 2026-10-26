import AppKit
import SwiftUI

let app = NSApplication.shared
if CommandLine.arguments.contains("--diagnostics") {
  let trusted = MenuAccessibility.trusted
  print("PrismBar 0.1.0 | macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
  print("accessibility=\(trusted ? "granted" : "not-granted")")
  if trusted {
    let values = MenuAccessibility.scan(apps: NSWorkspace.shared.runningApplications, ownPID: getpid())
    print("accessible-menu-items=\(values.count)")
  }
  print("screen-recording=not-requested; network=none")
  exit(0)
}

if let index = CommandLine.arguments.firstIndex(of: "--render-previews"), CommandLine.arguments.count > index + 1 {
  try MainActor.assumeIsolated {
  let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let store = BarStore(defaults: UserDefaults(suiteName: "io.github.xx1999DK.PrismBar.preview")!, preview: true)
  store.preferences = Preferences()
  store.trusted = true
  store.items = [
    ItemDescriptor(id: "wifi", appName: "系统设置", title: "Wi-Fi", bundleID: "com.apple.controlcenter"),
    ItemDescriptor(id: "music", appName: "音乐", title: "音乐", bundleID: "com.apple.Music"),
    ItemDescriptor(id: "volt", appName: "CodexVolt", title: "CodexVolt", bundleID: "io.github.xx1999DK.CodexVolt"),
    ItemDescriptor(id: "sound", appName: "系统设置", title: "声音", bundleID: "com.apple.controlcenter"),
    ItemDescriptor(id: "focus", appName: "系统设置", title: "专注模式", bundleID: "com.apple.controlcenter"),
    ItemDescriptor(id: "battery", appName: "系统设置", title: "电池", bundleID: "com.apple.controlcenter"),
  ]
  store.preferences.favorites = ["volt", "music"]
  let symbols = ["wifi": "wifi", "music": "music.note", "volt": "battery.75", "sound": "speaker.wave.2.fill", "focus": "moon.fill", "battery": "battery.100"]
  for item in store.items {
    store.handles[item.id] = MenuItemHandle(descriptor: item, element: AXUIElementCreateApplication(getpid()), pid: getpid(),
      image: NSImage(systemSymbolName: symbols[item.id]!, accessibilityDescription: item.title), frame: .zero)
  }
  @MainActor func save<V: View>(_ view: V, _ name: String) throws {
    // NSHostingView includes native AppKit controls and ScrollView contents, unlike ImageRenderer.
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 620), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let host = NSHostingView(rootView: view)
    window.contentView = host
    let size = host.fittingSize
    window.setContentSize(size)
    window.orderFront(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.12))
    host.layoutSubtreeIfNeeded()
    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("Cannot cache \(name)") }
    host.cacheDisplay(in: host.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot render \(name)") }
    try png.write(to: directory.appendingPathComponent(name))
    window.orderOut(nil)
  }
  NSApp.appearance = NSAppearance(named: .aqua)
  try save(SettingsView(store: store, initialTab: 1), "themes.png")
  try save(SettingsView(store: store), "onboarding.png")
  try save(SettingsView(store: store, initialTab: 2), "settings.png")
  for theme in BarTheme.allCases {
    store.preferences.theme = theme
    NSApp.appearance = NSAppearance(named: .aqua)
    try save(DrawerView(store: store).background(Color(nsColor: .windowBackgroundColor)), "drawer-\(theme.rawValue).png")
    NSApp.appearance = NSAppearance(named: .darkAqua)
    try save(DrawerView(store: store).environment(\.colorScheme, .dark).background(Color(nsColor: .windowBackgroundColor)), "drawer-\(theme.rawValue)-dark.png")
  }
  print("Rendered 23 native UI previews; sample menu items are illustrative.")
  }
  exit(0)
}

let delegate = PrismApp(smokeTest: CommandLine.arguments.contains("--smoke-test"))
app.delegate = delegate
app.run()
