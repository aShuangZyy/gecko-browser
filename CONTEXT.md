# CONTEXT — 接手这份项目前先读我

> 给「第一次进入这个仓库的 agent / 人」的简报。读完这一页就知道：项目是什么、约束是什么、做到哪了、下一步做什么。

## 1. 这是什么

一个 **iOS 14 上能跑的、不用 WKWebView 的浏览器**。

- 目标设备：iPhone，iOS 14.0–14.8.1
- 引擎：**Gecko**（Firefox 的引擎），基于 [minh-ton/reynard-browser](https://github.com/minh-ton/reynard-browser) fork
- 安装方式：**TrollStore**（设备已装，iOS 14 在支持范围内）
- 外壳：自写 Swift UI，位于 `browser/Reynard/Shell/`

## 2. 硬约束（不要违背）

| 约束 | 说明 |
|---|---|
| 不用 WKWebView | 用户明确要求。iOS 上第三方引擎只有两条路：Gecko（本项目）或 iOS 17.4+ 欧盟 BrowserEngineKit |
| 部署目标 iOS 13.0/14.0 | `browser/Configuration/Reynard.xcconfig` 里 `IPHONEOS_DEPLOYMENT_TARGET` |
| 签名 | 未签名构建 + `ldid -S` 私有 entitlements，TrollStore 侧加载 |
| 许可证 | 上游 GPL-3.0（engine/patches）；UI 自写，不复制上游 Client 代码 |
| 不能商用分发 | 依赖的私有 API / JIT 方案决定了它只能自用 |

## 3. 仓库结构

```
browser/                 iOS 工程
  Reynard.xcodeproj      app target + GeckoView framework target + 2 个 extension
  Reynard/               应用壳（含 Shell/ 自写界面）
  GeckoView/             Gecko 的 Swift 绑定（framework target，**要 import GeckoView**）
  Helper/                JIT helper extension
  Extensions/            OpenIn / Share 扩展
  Configuration/         Reynard.xcconfig（版本、部署目标、GECKO_DIST）
engine/                  Gecko 源码（`update-gecko.sh` 拉取）
patches/                 对 Gecko 的补丁（`apply-patches.sh` 应用）
tools/development/       update-gecko.sh / apply-patches.sh / build-idevice.sh / build-gecko.sh
tools/release/           build-app.sh / create-ipa.sh
```

## 4. 构建

```bash
./tools/development/update-gecko.sh
./tools/development/apply-patches.sh
./tools/development/build-idevice.sh
./tools/development/build-gecko.sh --use-sccache --auto-clobber
./tools/release/build-app.sh --no-signing
./tools/release/create-ipa.sh --trollstore
# → dist/Reynard-TrollStore.tipa
```

时间参考：M1 冷构建 25–40 分钟；只改 UI 时后两步约 2 分钟。

## 5. GeckoView API 速记（踩过的坑）

```swift
// 正确顺序，错一步白屏
let session = GeckoSession(settings: .default, isPrivateMode: false)
session.open(windowId: uuid)          // 创建原生容器
geckoView.session = session           // 一个 session 只能配一个 GeckoView，重复赋值 fatalError
session.setActive(true)
session.load("https://example.com", flags: GeckoSessionLoadFlags.none)

// 外部协议
func onLoadRequest(session:request:) async -> AllowOrDeny
// 返回 .deny = 应用自己处理了，Gecko 停止加载
```

`GeckoView` 是**独立 framework target**，必须 `import GeckoView`。

## 6. 当前状态

- ✅ CI（GitHub Actions）全链路通，出过 107.5MB 可安装 tipa
- ✅ 自写外壳能编、能装、能开网页（地址栏 / 进度条 / 前进后退刷新）
- ✅ `x-safari-https:` 外部协议已拦截修复
- ⬜ 验证修好的包在 x.com 上的表现
- ⬜ M2：九屏 UI 对标 Reynard（首页、标签栏、标签总览、侧栏、菜单、设置、库、阅读器、附加组件）

## 7. 下一步该做什么

1. 装最新 `dist/*.tipa`，开 x.com、开一个视频站，确认导航与音视频
2. 按 `docs/M2-Reynard风格UI对标清单.md` 逐屏实现，每完成一屏出一次包验证
3. 补：多标签（一个 session 一个 tab，内存要压）、书签、历史、设置页

## 8. 注意事项

- GitHub token 曾在聊天里暴露，需撤销重建；本地构建不需要 token
- 改 `browser/**` 会触发 Actions（fork 上已配 `paths` 过滤）
- 想跑云端构建得等 macos-26 runner，本地编更快
