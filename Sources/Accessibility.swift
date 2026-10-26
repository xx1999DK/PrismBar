import AppKit
import ApplicationServices

struct MenuItemHandle {
  let descriptor: ItemDescriptor
  let element: AXUIElement
  let pid: pid_t
  let image: NSImage?
  let frame: CGRect
}

enum MenuAccessibility {
  static var trusted: Bool { AXIsProcessTrusted() }

  static func requestPermission() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  static func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
    return result
  }
  static func element(_ parent: AXUIElement, _ name: String) -> AXUIElement? {
    guard let result = value(parent, name), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
    return unsafeBitCast(result, to: AXUIElement.self)
  }
  static func children(_ element: AXUIElement) -> [AXUIElement] {
    (value(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
  }
  static func string(_ element: AXUIElement, _ name: String) -> String {
    (value(element, name) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }
  static func frame(_ element: AXUIElement) -> CGRect {
    var point = CGPoint.zero, size = CGSize.zero
    if let v = value(element, kAXPositionAttribute), CFGetTypeID(v) == AXValueGetTypeID() {
      _ = AXValueGetValue(unsafeBitCast(v, to: AXValue.self), .cgPoint, &point)
    }
    if let v = value(element, kAXSizeAttribute), CFGetTypeID(v) == AXValueGetTypeID() {
      _ = AXValueGetValue(unsafeBitCast(v, to: AXValue.self), .cgSize, &size)
    }
    return CGRect(origin: point, size: size)
  }

  // Only status menus are inspected. App document windows and their contents are never traversed.
  static func scan(apps: [NSRunningApplication], ownPID: pid_t) -> [MenuItemHandle] {
    guard trusted else { return [] }
    var result: [MenuItemHandle] = []
    for app in apps where app.processIdentifier != ownPID && !app.isTerminated {
      let root = AXUIElementCreateApplication(app.processIdentifier)
      AXUIElementSetMessagingTimeout(root, 0.2)
      let bundle = app.bundleIdentifier ?? "pid.\(app.processIdentifier)"
      var bars: [AXUIElement] = []
      if let extras = element(root, "AXExtrasMenuBar") { bars.append(extras) }
      // Apple status-item hosts use AXMenuBar instead of AXExtrasMenuBar on some releases.
      if ["com.apple.systemuiserver", "com.apple.controlcenter"].contains(bundle),
         let bar = element(root, kAXMenuBarAttribute) { bars.append(bar) }
      var seen: Set<String> = []
      var occurrences: [String: Int] = [:]
      for bar in bars {
        for item in children(bar) {
          let role = string(item, kAXRoleAttribute)
          guard [kAXMenuBarItemRole, kAXButtonRole, "AXMenuExtra"].contains(role) else { continue }
          let rect = frame(item)
          let identity = string(item, kAXIdentifierAttribute)
          let title = [string(item, kAXTitleAttribute), string(item, kAXDescriptionAttribute), string(item, kAXHelpAttribute)]
            .first { !$0.isEmpty } ?? app.localizedName ?? "菜单栏项目"
          let fingerprint = "\(title)|\(rect.origin.x)|\(rect.origin.y)"
          guard seen.insert(fingerprint).inserted else { continue }
          let base = identity.isEmpty ? "status-item" : identity
          let occurrence = occurrences[base, default: 0]
          occurrences[base] = occurrence + 1
          let descriptor = ItemDescriptor(id: "\(bundle)|\(base)|\(occurrence)", appName: app.localizedName ?? bundle,
            title: title, bundleID: bundle)
          result.append(MenuItemHandle(descriptor: descriptor, element: item, pid: app.processIdentifier, image: app.icon, frame: rect))
        }
      }
    }
    return result
  }

  static func press(_ item: MenuItemHandle) -> AXError {
    AXUIElementSetMessagingTimeout(item.element, 0.7)
    var actions: CFArray?
    _ = AXUIElementCopyActionNames(item.element, &actions)
    let names = (actions as? [String]) ?? []
    // Never synthesize pointer motion or fall back to launching the parent app.
    if names.contains(kAXPressAction) {
      let result = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
      if result == .success { return result }
    }
    if names.contains(kAXShowMenuAction) {
      return AXUIElementPerformAction(item.element, kAXShowMenuAction as CFString)
    }
    return .actionUnsupported
  }

  static func menuIsOpen(_ item: MenuItemHandle?) -> Bool {
    // Without permission we cannot prove another app's menu is closed. Fail open.
    guard trusted else { return true }
    let system = AXUIElementCreateSystemWide()
    AXUIElementSetMessagingTimeout(system, 0.15)
    var focused = element(system, kAXFocusedUIElementAttribute)
    for _ in 0..<4 {
      guard let current = focused else { break }
      if [kAXMenuRole, kAXMenuItemRole].contains(string(current, kAXRoleAttribute)) { return true }
      focused = element(current, kAXParentAttribute)
    }
    guard let item else { return false }
    // A menu can contain a whole hierarchy; only inspect the immediate menu role.
    if children(item.element).contains(where: { string($0, kAXRoleAttribute) == kAXMenuRole }) { return true }
    let app = AXUIElementCreateApplication(item.pid)
    AXUIElementSetMessagingTimeout(app, 0.15)
    if let focused = element(app, kAXFocusedUIElementAttribute) {
      return [kAXMenuRole, kAXMenuItemRole].contains(string(focused, kAXRoleAttribute))
    }
    return false
  }
}
