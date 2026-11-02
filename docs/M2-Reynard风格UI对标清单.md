# M2：Reynard 风格 UI 对标清单

> 前置：M1 验证通过（Gecko 能开页）。M2 起界面按这份清单逐屏补齐，引擎侧只依赖 `BrowserEngine` 协议。
> 参考对象是 Reynard 的目录结构与界面分工（`browser/Reynard/Client/Interface/`），**实现自己写**，不复制它的 GPL 源码。

---

## 1. 优先级与排期

| 优先级 | 屏 | 为什么先做 | 预估 |
|---|---|---|---|
| P0 | 主界面（地址栏 + 内容区） | 已在 M1 打通，只需打磨 | 0.5 天 |
| P0 | 标签栏 + 标签总览 | 决定"像个浏览器"的观感 | 2 天 |
| P1 | 首页（收藏网格 + 搜索框） | 首屏第一眼 | 1.5 天 |
| P1 | 长按菜单 + 工具菜单 | 日常操作入口 | 1 天 |
| P2 | 设置页 | 默认搜索引擎、外观、清除数据 | 1.5 天 |
| P2 | 侧栏 | iPad 与单手操作 | 1 天 |
| P3 | 库（书签/历史/下载） | 数据层做完了才有内容 | 2 天 |
| P3 | 阅读器 / 打印 | 低频 | 1 天 |
| P3 | 附加组件入口 | 只留入口，不做商店 | 0.5 天 |

总计约 11 天，可按周切两段交付。

---

## 2. 逐屏要素

### 2.1 主界面

- 顶栏：地址栏（圆角胶囊、左侧站点图标、右侧刷新/停止内嵌）、进度条贴顶 2pt。
- 底部：返回 / 前进 / 标签数（显示数字） / 菜单。
- 滚动时顶栏收缩为细条（`UIScrollView` delegate 里按偏移插值，iOS 14 可用）。

### 2.2 标签栏 + 标签总览

- 底部标签按钮显示当前标签数，点击弹出总览。
- 总览用 `UICollectionView` 网格，每个 cell 是标题 + 域名 + 关闭按钮；长按进入抖动删除模式。
- 新建标签走"首页"而不是空白页。
- 标签上限：内存里建议 12 个，超出按 LRU 释放 GeckoSession（`close()`），恢复时重建并 `load`。

### 2.3 首页

- 顶部大搜索框（复用地址栏组件）。
- 下方收藏网格 4 列，图标取 favicon（本地缓存，失败退回首字母色块）。
- 底部"最近关闭"横向列表。

### 2.4 长按菜单

- 链接：新标签打开 / 新标签后台打开 / 复制链接 / 分享 / 下载链接。
- 图片：存储图像 / 复制图片 / 在新标签打开。
- 选中文本：复制 / 查询 / 分享。
- 用 `UIContextMenuInteraction`（iOS 13+），菜单项走 `UIAction`。

### 2.5 设置

- 搜索引擎（Bing / Google / DuckDuckGo / 自定义）。
- 外观：跟随系统 / 浅色 / 深色（`overrideUserInterfaceStyle`）。
- 隐私：清除历史、清除缓存、禁止第三方 Cookie（Gecko pref）。
- 关于：版本、内核版本（`GeckoRuntime.version`）、开源许可。

### 2.6 侧栏

- 右侧滑出，宽 280pt，内容为标签列表 + 书签入口。
- 手势：屏幕右缘 `UIScreenEdgePanGestureRecognizer`。

### 2.7 库

- 三段：书签 / 历史 / 下载。
- 数据层：`SQLite`（`GRDB` 或手写 `sqlite3`，避免引入不必要依赖），三张表 + 索引。
- 搜索：标题与 URL 前缀匹配。

### 2.8 阅读器 / 打印

- 阅读器：注入 Readability 风格脚本提取正文，`evaluateJS` 拿回 HTML 后用原生视图渲染。
- 打印：`UIPrintInteractionController` + `viewPrintFormatter`。

### 2.9 附加组件

- 只做入口页：列出内置的 3 个（广告拦截规则、暗色模式注入、User-Agent 切换），开关状态存 `UserDefaults`。
- 不做在线商店，也不加载第三方 JS。

---

## 3. 与 Reynard 的观感差异（有意为之）

| 项 | Reynard | 我们 |
|---|---|---|
| 引擎 | Gecko（fork） | Gecko（同一套 GeckoView 封装） |
| 标签切换动画 | 自定义弹簧 | 系统 `UIViewPropertyAnimator`，观感接近即可 |
| 首页 | 收藏 + 最近 | 同上，图标改用本地缓存 |
| 菜单 | 自定义浮层 | `UIContextMenu` + `UIMenu` |
| 设置项 | 完整 | 先做 4 组，后续补 |

不追求像素级一致，追求"同一类浏览器的肌肉记忆"。

---

## 4. iOS 14 约束（写代码前先看）

| 想用的 | 状态 | 替代 |
|---|---|---|
| `async/await` | iOS 15+ | `DispatchQueue` + completion |
| `UIButton.Configuration` | iOS 15+ | `setImage` / `setTitle` |
| `UICollectionView.CellRegistration` | iOS 14+ 可用 | 可用 |
| `swipeActions`（列表） | iOS 15+ | 自定义滑动手势 |
| `WKDownload` | 不适用（非 WebKit） | Gecko 的 `downloads` 委托 |
| `UISheetPresentationController` 自定义 detent | iOS 15+ | 固定 medium 样式的手写面板 |
| `AttributedString` | iOS 15+ | `NSAttributedString` |

---

## 5. 验收

- 冷启动到可输入 ≤ 2 秒（A12 及以上）。
- 打开 5 个标签，切换不重建页面。
- 深色模式下所有界面无白底闪烁。
- 断网时首页正常显示收藏，地址栏报错可读。
- 卸载重装后书签与历史保留在 App 容器内（TrollStore 覆盖升级不丢数据）。
