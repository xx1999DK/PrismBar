import SwiftUI
import AppKit

struct ThemeMark: View {
  let theme: BarTheme
  var size: CGFloat = 28
  var body: some View {
    Image(systemName: theme.symbol)
      .font(.system(size: size * 0.53, weight: .semibold))
      .foregroundStyle(LinearGradient(colors: [Color(hex: theme.tint), Color(hex: theme.secondaryTint)], startPoint: .topLeading, endPoint: .bottomTrailing))
      .frame(width: size, height: size)
      .padding(size * 0.18)
      .background(Color(hex: theme.tint).opacity(0.10), in: RoundedRectangle(cornerRadius: theme.corner * 0.65))
      .accessibilityHidden(true)
  }
}

struct DrawerView: View {
  @ObservedObject var store: BarStore
  @FocusState private var searchFocused: Bool
  private var theme: BarTheme { store.preferences.theme }
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 10) {
        ThemeMark(theme: theme, size: 23)
        VStack(alignment: .leading, spacing: 2) {
          Text("PrismBar").font(.system(size: 15, weight: .semibold, design: theme == .terminal ? .monospaced : .default))
          Text("你的菜单栏，井然有序").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        Spacer()
        Button { store.onSettings?() } label: { Image(systemName: "slider.horizontal.3") }
          .buttonStyle(.plain).help("设置与外观").accessibilityLabel("设置与外观")
        Button { store.onClose?() } label: { Image(systemName: "xmark") }
          .buttonStyle(.plain).padding(.leading, 8).help("关闭抽屉").accessibilityLabel("关闭抽屉")
      }
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        TextField("搜索应用或菜单栏项目", text: $store.query)
          .textFieldStyle(.plain).focused($searchFocused)
          .onSubmit { if let first = store.filteredItems.first { store.activate(first.id) } }
        if !store.query.isEmpty {
          Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            .buttonStyle(.plain).accessibilityLabel("清除搜索")
        }
      }.padding(10).background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: theme.corner * 0.65))
      HStack {
        Picker("筛选", selection: $store.favoritesOnly) {
          Text("全部 \(store.items.count)").tag(false)
          Text("常用").tag(true)
        }.pickerStyle(.segmented).frame(width: 180)
        Spacer()
        if store.scanning { ProgressView().controlSize(.small) }
        Button { store.scan() } label: { Image(systemName: "arrow.clockwise") }
          .disabled(store.scanning || !store.trusted).buttonStyle(.plain)
          .help("重新读取菜单栏项目").accessibilityLabel("刷新菜单栏项目")
      }
      if !store.trusted {
        VStack(spacing: 10) {
          Image(systemName: "hand.raised").font(.system(size: 26)).foregroundStyle(Color(hex: theme.tint))
          Text("让常用图标，触手可及").font(.headline)
          Text("允许辅助功能后，可在这里搜索并打开菜单栏项目。\n只访问状态菜单，无需屏幕录制。").font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
          Button("设置辅助功能权限") { store.requestPermission() }.buttonStyle(.borderedProminent)
          Button("已授权，重新检测") { store.scan() }.buttonStyle(.link)
        }.frame(maxWidth: .infinity).padding(.vertical, 20)
      } else if store.filteredItems.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: store.query.isEmpty ? "tray" : "magnifyingglass").font(.system(size: 28)).foregroundStyle(.secondary)
          Text(store.scanning ? "正在读取菜单栏…" : (store.query.isEmpty ? (store.favoritesOnly ? "还没有常用项目" : "暂未发现可访问的菜单栏项目") : "没有找到匹配项目"))
          Text(store.favoritesOnly ? "右键点击项目，可将它加入常用。" : "可刷新列表，或展开原菜单栏使用。").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 150)
      } else {
        ScrollView {
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(store.filteredItems) { item in
              Button { store.activate(item.id) } label: {
                VStack(spacing: 6) {
                  ZStack(alignment: .bottomTrailing) {
                    if let icon = store.handles[item.id]?.image {
                      Image(nsImage: icon).resizable().interpolation(.high).scaledToFit().frame(width: 30, height: 30)
                    } else {
                      Image(systemName: "menubar.rectangle").font(.system(size: 25)).frame(width: 30, height: 30).foregroundStyle(Color(hex: theme.tint))
                    }
                    if store.preferences.favorites.contains(item.id) {
                      Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(Color(hex: theme.tint)).background(.background, in: Circle()).offset(x: 5, y: 3)
                    }
                  }
                  Text(item.title).font(.system(size: 11)).lineLimit(1)
                  if item.title != item.appName { Text(item.appName).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1) }
                }.frame(maxWidth: .infinity, minHeight: 79).padding(.horizontal, 5)
                  .background(Color(hex: theme.tint).opacity(0.045), in: RoundedRectangle(cornerRadius: theme.corner * 0.7))
                  .contentShape(Rectangle())
              }.buttonStyle(.plain).help("\(item.appName) · \(item.title)\n点击打开菜单；右键收藏")
                .accessibilityLabel("打开 \(item.appName) 的 \(item.title) 菜单")
                .contextMenu {
                  Button(store.preferences.favorites.contains(item.id) ? "从常用移除" : "加入常用") { store.toggleFavorite(item.id) }
                }
            }
          }
        }.frame(height: min(260, CGFloat((store.filteredItems.count + 2) / 3) * 87))
      }
      if let message = store.message {
        HStack(alignment: .top) {
          Image(systemName: "info.circle")
          Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
          Button { store.message = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("关闭提示")
        }.foregroundStyle(.secondary).padding(10).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
      }
      Divider()
      HStack {
        Button(store.collapsed ? "展开菜单栏" : "收起菜单栏") { store.onToggle?() }.buttonStyle(.link)
        Spacer()
        Text(store.preferences.shortcutEnabled ? "⌥ ⌘ B" : "右键图标打开设置").font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
      }
    }.padding(18).frame(width: 440).tint(Color(hex: theme.tint))
      .background(LinearGradient(colors: [Color(hex: theme.tint).opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
      .onAppear { searchFocused = true }
      .onExitCommand { store.onClose?() }
  }
}

struct SettingsView: View {
  @ObservedObject var store: BarStore
  @State private var selection = 0
  init(store: BarStore, initialTab: Int = 0) { self.store = store; _selection = State(initialValue: initialTab) }
  private var theme: BarTheme { store.preferences.theme }
  var body: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 7) {
        HStack(spacing: 8) {
          ThemeMark(theme: theme, size: 24)
          VStack(alignment: .leading, spacing: 3) {
            Text("PrismBar").font(.system(size: 17, weight: .bold))
            Text("少一点，刚刚好。").font(.system(size: 10)).foregroundStyle(.secondary)
          }
        }.padding(.bottom, 26).padding(.top, 8)
        nav("概览", symbol: "square.grid.2x2", index: 0)
        nav("十款外观", symbol: "paintpalette", index: 1)
        nav("偏好设置", symbol: "slider.horizontal.3", index: 2)
        Spacer()
        HStack(spacing: 6) {
          Circle().fill(store.collapsed ? Color(hex: theme.tint) : Color.secondary).frame(width: 6, height: 6)
          Text(store.collapsed ? "菜单栏已收起" : "菜单栏已展开").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        Text("原生 · 本地 · 轻量\nv0.1.0").font(.system(size: 10)).foregroundStyle(.tertiary).lineSpacing(3).padding(.top, 10)
      }.padding(20).frame(width: 190).background(Color(hex: theme.tint).opacity(0.045))
      Divider()
      VStack(alignment: .leading, spacing: 0) {
        if selection == 0 { overview }
        else if selection == 1 { appearance }
        else { preferences }
      }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }.frame(width: 780, height: 620).background(Color(nsColor: .windowBackgroundColor)).tint(Color(hex: theme.tint))
  }
  private func nav(_ title: String, symbol: String, index: Int) -> some View {
    Button { selection = index } label: {
      Label(title, systemImage: symbol).font(.system(size: 13, weight: selection == index ? .semibold : .regular))
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 11)
        .foregroundStyle(selection == index ? Color(hex: theme.tint) : Color.primary)
        .background(selection == index ? Color(hex: theme.tint).opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 9))
    }.buttonStyle(.plain)
  }
  private func heading(_ title: String, _ subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title).font(.system(size: 25, weight: .bold))
      Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
    }.padding(.bottom, 24)
  }
  private var overview: some View {
    VStack(alignment: .leading, spacing: 18) {
      heading("把空间，还给菜单栏。", "收起不常用的图标，需要时再轻轻展开。")
      VStack(alignment: .leading, spacing: 13) {
        Label("第一次使用，先整理位置", systemImage: "cursorarrow.and.square.on.square.dashed").font(.headline)
        Text("按住 ⌘ Command，将不常用的图标拖到分隔线左侧；常用图标保留在右侧。PrismBar 图标也应放在分隔线右侧。").font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
        HStack(spacing: 12) {
          Label("待收纳", systemImage: "ellipsis")
          Divider().frame(height: 24)
          Label("常用图标", systemImage: "wifi")
          Spacer()
          ThemeMark(theme: theme, size: 18)
        }.font(.system(size: 12)).padding(14).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        HStack {
          Button("展开并整理图标") { store.onOrganize?() }
          Button("已放好，开始使用") { store.preferences.completedSetup = true; if !store.collapsed { store.onToggle?() } }
            .buttonStyle(.borderedProminent)
        }
      }.padding(20).background(Color(hex: theme.tint).opacity(0.055), in: RoundedRectangle(cornerRadius: theme.corner))
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: store.trusted ? "checkmark.shield" : "hand.raised").font(.system(size: 23)).foregroundStyle(Color(hex: theme.tint))
        VStack(alignment: .leading, spacing: 7) {
          Text(store.trusted ? "聚合抽屉已就绪" : "为聚合抽屉启用辅助功能").font(.system(size: 14, weight: .semibold))
          Text("只访问菜单栏项目，用于查找和打开原菜单。不申请屏幕录制，不读取窗口内容。").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
          HStack {
            if !store.trusted { Button("打开权限设置") { store.requestPermission() } }
            Button("重新检测") { store.scan() }
          }
        }
      }.padding(.vertical, 8)
      Divider()
      Button("打开聚合抽屉") { store.onDrawer?() }.buttonStyle(.borderedProminent)
      Text("点按菜单栏图标打开抽屉 · 右键显示快捷操作\nOption 点按可直接展开或收起菜单栏").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
    }
  }
  private var appearance: some View {
    VStack(alignment: .leading, spacing: 0) {
      heading("十种心情，同样顺手。", "外观即时生效，菜单栏图标与抽屉同步切换。")
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
        ForEach(BarTheme.allCases) { value in
          Button { store.preferences.theme = value } label: {
            HStack(spacing: 10) {
              ThemeMark(theme: value, size: 26)
              VStack(alignment: .leading, spacing: 6) {
                Text(value.name).font(.system(size: 12, weight: .semibold, design: value == .terminal ? .monospaced : .default))
                Text(value.subtitle).font(.system(size: 9)).foregroundStyle(.secondary)
              }
              Spacer(minLength: 0)
              if theme == value { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: value.tint)).font(.system(size: 13)) }
            }.padding(12).frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
              .background(theme == value ? Color(hex: value.tint).opacity(0.09) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: value.corner))
              .overlay(RoundedRectangle(cornerRadius: value.corner).stroke(theme == value ? Color(hex: value.tint).opacity(0.6) : .primary.opacity(0.06), lineWidth: 1))
          }.buttonStyle(.plain).accessibilityLabel("\(value.name)\(theme == value ? "，已选择" : "")")
        }
      }
      Text("跟随系统深浅色 · 无循环动画 · 设置自动保存").font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 21)
    }
  }
  private var preferences: some View {
    VStack(alignment: .leading, spacing: 20) {
      heading("简单设置，恰到好处。", "保留必要的选择，其余交给系统。")
      VStack(alignment: .leading, spacing: 10) {
        Text("点击菜单栏图标时").font(.headline)
        Picker("使用模式", selection: $store.preferences.mode) {
          ForEach(BarMode.allCases, id: \.self) { Text($0.title).tag($0) }
        }.pickerStyle(.segmented)
        Text(store.preferences.mode == .drawer ? "打开可搜索的菜单栏项目抽屉，需要辅助功能权限。" : "在原菜单栏直接展开或收起，无需额外权限。").font(.caption).foregroundStyle(.secondary)
      }
      Divider()
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text("自动收回").font(.headline)
          Text(store.trusted ? "指针离开菜单栏、菜单关闭后才收回。" : "需要辅助功能，以免打断正在使用的菜单。").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Picker("延迟", selection: $store.preferences.autoCollapseSeconds) {
          Text("关闭").tag(0)
          ForEach([5, 15, 30, 60], id: \.self) { Text("\($0) 秒").tag($0) }
        }.labelsHidden().frame(width: 94)
      }
      Divider()
      Toggle(isOn: $store.preferences.shortcutEnabled) {
        VStack(alignment: .leading, spacing: 5) {
          Text("全局快捷键").font(.headline)
          Text("⌥ ⌘ B · 与点击菜单栏图标相同").font(.caption).foregroundStyle(.secondary)
        }
      }.toggleStyle(.switch)
      if let text = store.shortcutMessage { Text(text).font(.caption).foregroundStyle(.orange) }
      Divider()
      Toggle(isOn: Binding(get: { store.loginEnabled }, set: { store.setLogin($0) })) {
        VStack(alignment: .leading, spacing: 5) {
          Text("登录时启动").font(.headline)
          Text("由 macOS 管理，可以随时关闭。").font(.caption).foregroundStyle(.secondary)
        }
      }.toggleStyle(.switch)
      if let text = store.message { Text(text).font(.caption).foregroundStyle(.secondary) }
      Spacer(minLength: 0)
      Text("不联网 · 无遥测 · 不保存图标截图\n退出应用后，折叠的图标会回到原菜单栏。").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(4)
    }
  }
}
