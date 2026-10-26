import Foundation

enum BarMode: String, Codable, CaseIterable {
  case drawer, fold
  var title: String { self == .drawer ? "聚合抽屉" : "直接折叠" }
}

enum BarTheme: String, Codable, CaseIterable, Identifiable {
  case aurora, segments, minimal, terminal, pixel, neko, ribbon, mecha, lunar, forest
  var id: String { rawValue }
  var name: String {
    switch self {
    case .aurora: return "极光玻璃"
    case .segments: return "分段能量"
    case .minimal: return "极简线框"
    case .terminal: return "极客终端"
    case .pixel: return "像素电玩"
    case .neko: return "猫耳动漫"
    case .ribbon: return "樱粉丝带"
    case .mecha: return "机甲核心"
    case .lunar: return "月光星轨"
    case .forest: return "森系叶片"
    }
  }
  var subtitle: String {
    switch self {
    case .aurora: return "青蓝与紫 · 通透柔和"
    case .segments: return "节奏刻度 · 清晰有序"
    case .minimal: return "黑白之间 · 跟随系统"
    case .terminal: return "荧光绿 · 等宽字形"
    case .pixel: return "复古电玩 · 明快像素"
    case .neko: return "暖橘猫耳 · 轻松可爱"
    case .ribbon: return "柔粉丝带 · 细腻温柔"
    case .mecha: return "橙色装甲 · 利落边界"
    case .lunar: return "深蓝新月 · 安静夜色"
    case .forest: return "嫩绿叶片 · 自然呼吸"
    }
  }
  var symbol: String {
    switch self {
    case .aurora: return "square.stack.3d.up.fill"
    case .segments: return "chart.bar.xaxis"
    case .minimal: return "rectangle.compress.vertical"
    case .terminal: return "terminal.fill"
    case .pixel: return "gamecontroller.fill"
    case .neko: return "pawprint.fill"
    case .ribbon: return "gift.fill"
    case .mecha: return "hexagon.fill"
    case .lunar: return "moon.stars.fill"
    case .forest: return "leaf.fill"
    }
  }
  var tint: UInt32 {
    switch self {
    case .aurora: return 0x397DCE
    case .segments: return 0x008577
    case .minimal: return 0x575C68
    case .terminal: return 0x187D45
    case .pixel: return 0xA86604
    case .neko: return 0xB45F26
    case .ribbon: return 0xBA3B79
    case .mecha: return 0xC25A20
    case .lunar: return 0x6266BD
    case .forest: return 0x4A7839
    }
  }
  var secondaryTint: UInt32 {
    switch self {
    case .aurora: return 0x8669DB
    case .segments: return 0x53AFBD
    case .minimal: return 0x818692
    case .terminal: return 0x57AF71
    case .pixel: return 0xDF9854
    case .neko: return 0xD49356
    case .ribbon: return 0xCD8BC2
    case .mecha: return 0xE0A33E
    case .lunar: return 0x8697C8
    case .forest: return 0x89AD51
    }
  }
  var corner: Double { [.pixel, .terminal].contains(self) ? 5 : (self == .mecha ? 9 : 16) }
}

struct Preferences: Codable, Equatable {
  var theme: BarTheme = .aurora
  var mode: BarMode = .drawer
  var autoCollapseSeconds: Int = 15
  var shortcutEnabled = true
  var favorites: Set<String> = []
  var completedSetup = false

  static func decode(_ data: Data?) -> Preferences {
    guard let data, var value = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
    if ![0, 5, 15, 30, 60].contains(value.autoCollapseSeconds) { value.autoCollapseSeconds = 15 }
    return value
  }
}

struct ItemDescriptor: Identifiable, Equatable {
  let id: String
  let appName: String
  let title: String
  let bundleID: String
}

enum ItemSearch {
  static func filter(_ items: [ItemDescriptor], query: String, favorites: Set<String>, onlyFavorites: Bool) -> [ItemDescriptor] {
    let terms = normalize(query).split(whereSeparator: \.isWhitespace)
    return items.filter { item in
      (!onlyFavorites || favorites.contains(item.id)) && terms.allSatisfy {
        normalize(item.appName + " " + item.title + " " + item.bundleID).contains($0)
      }
    }.sorted {
      let a = favorites.contains($0.id), b = favorites.contains($1.id)
      if a != b { return a }
      let order = $0.appName.localizedStandardCompare($1.appName)
      return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
    }
  }
  private static func normalize(_ value: String) -> String {
    value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
  }
}

enum CollapsePolicy {
  static func shouldCollapse(now: Date, deadline: Date?, menuOpen: Bool, pointerAtMenuBar: Bool, panelOpen: Bool) -> Bool {
    guard let deadline else { return false }
    return now >= deadline && !menuOpen && !pointerAtMenuBar && !panelOpen
  }
}

enum PanelPlacement {
  static func origin(anchorX: Double, screenX: Double, screenWidth: Double, panelWidth: Double) -> Double {
    max(screenX + 12, min(anchorX - panelWidth + 20, screenX + screenWidth - panelWidth - 12))
  }
}
