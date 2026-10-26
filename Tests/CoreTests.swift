import Foundation

@main struct CoreTests {
  static func main() throws {
    var checks = 0
    func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
      precondition(condition(), "FAILED: \(name)"); checks += 1
    }
    let now = Date(timeIntervalSince1970: 1000)
    let past = now.addingTimeInterval(-1)
    let future = now.addingTimeInterval(1)
    expect(!CollapsePolicy.shouldCollapse(now: now, deadline: nil, menuOpen: false, pointerAtMenuBar: false, panelOpen: false), "auto collapse disabled")
    expect(!CollapsePolicy.shouldCollapse(now: now, deadline: future, menuOpen: false, pointerAtMenuBar: false, panelOpen: false), "respect delay")
    expect(CollapsePolicy.shouldCollapse(now: now, deadline: past, menuOpen: false, pointerAtMenuBar: false, panelOpen: false), "collapse when idle")
    expect(!CollapsePolicy.shouldCollapse(now: now, deadline: past, menuOpen: true, pointerAtMenuBar: false, panelOpen: false), "never interrupt open menu")
    expect(!CollapsePolicy.shouldCollapse(now: now, deadline: past, menuOpen: false, pointerAtMenuBar: true, panelOpen: false), "never collapse under pointer")
    expect(!CollapsePolicy.shouldCollapse(now: now, deadline: past, menuOpen: false, pointerAtMenuBar: false, panelOpen: true), "never collapse during panel use")
    let items = [ItemDescriptor(id: "a", appName: "Café", title: "播放 音乐", bundleID: "app.music"), ItemDescriptor(id: "b", appName: "CodexVolt", title: "周额度", bundleID: "app.volt")]
    expect(ItemSearch.filter(items, query: "CAFÉ 音乐", favorites: [], onlyFavorites: false).map(\.id) == ["a"], "case and Chinese token search")
    expect(ItemSearch.filter(items, query: "cafe", favorites: [], onlyFavorites: false).map(\.id) == ["a"], "diacritic search")
    expect(ItemSearch.filter(items, query: "Ｃｏｄｅｘ", favorites: [], onlyFavorites: false).map(\.id) == ["b"], "fullwidth search")
    expect(ItemSearch.filter(items, query: "absent", favorites: [], onlyFavorites: false).isEmpty, "empty search results")
    expect(ItemSearch.filter(items, query: "", favorites: ["b"], onlyFavorites: false).first?.id == "b", "favorites sort first")
    expect(ItemSearch.filter(items, query: "", favorites: ["missing"], onlyFavorites: true).isEmpty, "stale favorites are safe")
    expect(ItemSearch.filter(items, query: "app.volt", favorites: ["b"], onlyFavorites: true).count == 1, "bundle search and favorite filter")
    expect(Preferences.decode(nil) == Preferences(), "first run defaults")
    expect(Preferences.decode(Data("not-json".utf8)) == Preferences(), "corrupt preferences recover")
    var prefs = Preferences(); prefs.theme = .lunar; prefs.favorites = ["a", "b"]; prefs.completedSetup = true
    let saved = try JSONEncoder().encode(prefs)
    expect(Preferences.decode(saved) == prefs, "preferences round trip")
    prefs.autoCollapseSeconds = -100
    let invalid = try JSONEncoder().encode(prefs)
    expect(Preferences.decode(invalid).autoCollapseSeconds == 15, "invalid timeout sanitized")
    expect(Set(BarTheme.allCases.map(\.rawValue)).count == 10, "ten distinct persisted themes")
    expect(PanelPlacement.origin(anchorX: 1950, screenX: 0, screenWidth: 1920, panelWidth: 440) == 1468, "right edge clamp")
    expect(PanelPlacement.origin(anchorX: -1900, screenX: -1920, screenWidth: 1920, panelWidth: 440) == -1908, "left display coordinates")
    expect(PanelPlacement.origin(anchorX: 500, screenX: 0, screenWidth: 1920, panelWidth: 440) == 80, "normal anchor placement")
    print("Passed \(checks) behavior checks")
  }
}
