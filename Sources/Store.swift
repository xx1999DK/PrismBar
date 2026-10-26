import AppKit
import SwiftUI
import ServiceManagement

final class BarStore: ObservableObject {
  @Published var preferences: Preferences {
    didSet {
      if !preview { defaults.set(try? JSONEncoder().encode(preferences), forKey: "preferences.v1") }
      onPreferencesChanged?()
    }
  }
  @Published var items: [ItemDescriptor] = []
  @Published var trusted = MenuAccessibility.trusted
  @Published var scanning = false
  @Published var collapsed = false
  @Published var query = ""
  @Published var favoritesOnly = false
  @Published var message: String?
  @Published var loginEnabled = false
  @Published var shortcutMessage: String?
  @Published var lastScan: Date?
  var handles: [String: MenuItemHandle] = [:]
  var onPreferencesChanged: (() -> Void)?
  var onToggle: (() -> Void)?
  var onSettings: (() -> Void)?
  var onOrganize: (() -> Void)?
  var onActivate: ((String) -> Void)?
  var onClose: (() -> Void)?
  private let defaults: UserDefaults
  let preview: Bool
  private let queue = DispatchQueue(label: "PrismBar.menu-access", qos: .userInitiated)

  init(defaults: UserDefaults = .standard, preview: Bool = false) {
    self.defaults = defaults
    self.preview = preview
    preferences = Preferences.decode(defaults.data(forKey: "preferences.v1"))
    if !preview { refreshPermission() }
  }
  var filteredItems: [ItemDescriptor] {
    ItemSearch.filter(items, query: query, favorites: preferences.favorites, onlyFavorites: favoritesOnly)
  }
  func refreshPermission() {
    trusted = MenuAccessibility.trusted
    loginEnabled = SMAppService.mainApp.status == .enabled
  }
  func requestPermission() {
    MenuAccessibility.requestPermission()
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
  }
  func toggleFavorite(_ id: String) {
    if preferences.favorites.contains(id) { preferences.favorites.remove(id) }
    else { preferences.favorites.insert(id) }
  }
  func scan() {
    refreshPermission()
    guard trusted, !scanning, !preview else { return }
    scanning = true
    let apps = NSWorkspace.shared.runningApplications
    let ownPID = ProcessInfo.processInfo.processIdentifier
    queue.async { [weak self] in
      let values = MenuAccessibility.scan(apps: apps, ownPID: ownPID)
      DispatchQueue.main.async {
        guard let self else { return }
        self.handles = Dictionary(values.map { ($0.descriptor.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.items = values.map(\.descriptor)
        self.scanning = false
        self.lastScan = Date()
      }
    }
  }
  func activate(_ id: String) { onActivate?(id) }
  func setLogin(_ enabled: Bool) {
    do {
      if enabled { try SMAppService.mainApp.register() }
      else { try SMAppService.mainApp.unregister() }
      refreshPermission()
      if SMAppService.mainApp.status == .requiresApproval { message = "请在系统设置 → 通用 → 登录项中允许 PrismBar。" }
    } catch {
      message = "无法更新登录项：\(error.localizedDescription)"
      refreshPermission()
    }
  }
}

extension Color {
  init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }
}
extension NSColor {
  convenience init(hex: UInt32) {
    self.init(name: nil) { appearance in
      let base = NSColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
      return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? (base.blended(withFraction: 0.38, of: .white) ?? base) : base
    }
  }
}
