# iBar Pro 调研与 PrismBar 设计取舍

调研日期：2026-10-26。研究对象为 Better365 的 iBar / iBar Pro 菜单栏管理工具，不是同名浏览器历史启动器。资料是官方介绍、App Store 描述及官方示意图；没有购买、修改或运行 iBar Pro，也不声称完成其实际体验评测。浏览器工具本轮超时，官方图片通过其公开文件地址读取并人工检查。

## 核心观察

iBar 的初衷清晰：腾出菜单栏空间，同时保留低频图标的访问入口。普通模式在原菜单栏折叠和展开；聚合模式在菜单栏下方显示隐藏图标，缓解刘海遮挡。官方示意图是一条横向紧凑工具条，原图标保留原有识别方式。Pro 的介绍还包括临时显示后再次隐藏、延迟、触发方式和入口图标等设置。官方权限说明把辅助功能用于移动和操作图标、屏幕录制用于获取图标图像。App Store 中关于权限解释及点击触发的反馈是个别用户样本，不能据此断言普遍故障。

## 优化判断

| 观察或问题 | 证据与置信度 | PrismBar 的处理 | 代价 |
| --- | --- | --- | --- |
| 小图标多时仅靠形状识别困难 | 官方横向长条截图；设计推断，中等 | 可搜索名称与应用，常用项目置顶 | 面板比一行工具条更高 |
| 悬停触发可能误开 | 商店版本说明加入仅点击选项；较高 | 默认且仅使用显式点击 / 快捷键 | 不提供悬停模式 |
| 权限用途不够直观 | 官方需要辅助功能与屏幕录制；高 | 折叠免授权；抽屉单独解释辅助功能 | 使用应用图标，不显示实时徽标 |
| 自动隐藏可能干扰正在用的菜单 | 交互风险推断，待真实场景验证 | 打开菜单、指针位于菜单栏、面板可见时延迟收回 | 无辅助功能时暂停自动收回 |
| 个性化与操作一致性 | 用户明确要求 CodexVolt 十种风格 | 十主题统一交互与层级，颜色、符号、字体及圆角变化 | 不增加动画和图片主题包 |
| 排布越自动越容易与其他工具冲突 | 系统行为风险推断，中等 | Command 拖拽确定分隔边界，不主动移动其他应用图标 | 首次需用户整理一次 |

## 功能边界

这是独立实现，不是 iBar 补丁、破解或二次打包。无需网络、模型、账号、付费和屏幕录制。原菜单栏折叠使用公开 NSStatusItem 空间机制，其他应用图标由系统布局；抽屉只读取辅助功能的状态菜单，并调用菜单项目提供的操作。

首版抽屉显示系统允许访问的全部菜单栏项目；常用筛选由用户维护。它不等同于 iBar 的隐藏图标截图镜像，不提供永久隐藏分组、逐项自动移动、图标间距全局修改或私有 WindowServer API。输入法、系统控制中心、某些第三方 App 是否提供 AX 操作由系统和 App 决定；不支持时展开原菜单栏并解释原因，不能声称全面替代 iBar Pro。

## 视觉方向

沿用 CodexVolt 的十方向：极光、分段、极简、终端、像素、猫耳、樱粉、机甲、月光、森林。使用原生 SF Symbols 和 SwiftUI，不复制 iBar 商标或素材。设置窗口以三页组织：概览（首次排布和权限）、十款外观、偏好设置；抽屉保留标题、搜索、全部/常用、项目网格和一个展开入口。

## 来源

- [iBar 官方介绍及模式示意图](https://www.better365.com/ibar.html)
- [iBar Pro 官方 App Store 页面](https://apps.apple.com/us/app/ibar-pro-menubar-control-tool/id6737150304?mt=12)
- [官方辅助功能及屏幕录制用途](https://www.better365.cn/ibar/authority.html)
- [官方聚合模式示意图](https://13315641.s21i.faiusr.com/2/1/ABUIABACGAAg-sqZmwYohLuYhwcwyhE4xgo.jpg)
- [官方普通模式示意图](https://13315641.s21i.faiusr.com/2/1/ABUIABACGAAggcuZmwYogPaN4AYwyhE4xgo.jpg)
- [CodexVolt 外观参考](https://github.com/xx1999DK/CodexVolt)
- [Apple NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem)
- [Apple SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)

后续研究重点：有刘海的 Apple Silicon 真机、多显示器切换，以及不同 App 的辅助功能兼容性。未取得实际测试结果前，不把推断写成已验证效果。
