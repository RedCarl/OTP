# SwiftUI 性能审计 · OTP (iOS 18, Swift 6)

日期：2026-11-19 · 范围：`otp` 工作区当前状态（含未提交改动）· 方法：代码审查（未采信运行期证据）

## 摘要

这个 app 已经做过一轮有针对性的优化（`@ObservationIgnored` 记账、搜索 haystack 预计算、每行独立 `TimelineView`、
`phaseAnimator` 替代 30 Hz 跑马灯、Keychain 走 actor）。代码里**没有剩下结构性的性能黑洞**：没有 `LazyVStack` 误用、
没有 `body` 内的 formatter 构造、没有 `id: \.self` 导致的行身份抖动、没有主线程 I/O。

剩下的成本集中在三处，按影响排序：

1. 每行 2 Hz 的 `TimelineView` 驱动的是 1 Hz 就会变化的数值 —— 一半的工作纯属浪费，而且让倒计时环看起来是卡顿的；
2. `MarqueeText` 在列表行里做两趟测量（`GeometryReader` + preference + `onAppear` 写 state），这是滚动掉帧最可能的来源；
3. 锁屏遮罩下，每行的时钟和环形动画仍在运行，而代码自己的注释认为「遮罩起来就不需要时钟」。

结论均为代码推断（code-backed），尚无 Instruments 证据。

## 发现

### 1. 每行 2 Hz 时钟驱动 1 Hz 数值，并在 tick 里重建验证码字符串

- 现象：令牌列表静止时持续有后台工作；倒计时环不是平滑走而是「动 0.5 秒、停 0.5 秒」。
- 原因：`TimelineView(.periodic(from: .now, by: 0.5))` 每 0.5 秒执行一次 `trailing(at:)`，
  但 `TOTP.remaining` 返回 `Int`（见 `TOTP.swift` 的 `ceil`），所以 `remaining` / `progress` 每秒才变一次 —
  两次 tick 中必有一次得到完全相同的值。`progress` 变化时 `.animation(.linear(duration: 0.5), value: progress)`
  在 0.5 秒内把 trim 动画完，随后 0.5 秒静止 → 视觉上每秒一次小顿挫。
- 证据：`TokenRowView.swift:31`、`TokenRowView.swift:47-71`、`CountdownRing.swift:30`、`TOTP.swift:22-33`。
  另外每次 tick 都会执行 `OTPCodeFormatter.grouped(code)`（`TokenRowView.swift:54`），
  而 `grouped()` 会 `Array(code)` + 拼 3 个 String —— 验证码 30 秒才变一次，这个字符串却每秒被重建 2 次 × 可见行数。
- 影响：可见 12 行时约 24 次 body 求值/秒、约 150 次字符串分配/秒，其中一半产出与上次完全相同。
- 修复：
  1. 把周期改成 `by: 1`，动画时长改成 `1`，环变成连续平滑（代价相同的帧数，但不再有空转的一半求值）；
  2. 更彻底：让 `progress` 用连续时间而不是 `ceil` 后的整数（`1 - offset/period`），1 Hz 采样也能平滑；
  3. 把 `grouped(code)` 提到 tick 闭包外（列表传给行一个已格式化好的 `formattedCode`，或存在行的存储属性里）。
- 验证：Instruments SwiftUI 模板，View Body 泳道里静止 10 秒的求值次数（改前 vs 改后），以及 CPU 占用。

### 2. `MarqueeText` 在列表行里做两趟测量

- 现象：快速滑动令牌列表时掉帧（推断，未实测）。
- 原因：每行都套一层 `GeometryReader`，用 `onAppear` 把宽度写回 `@State`，再用 `PreferenceKey` 测文本宽度。
  新 cell 落地时会先布局一次 → 写 state → 失效 → 再布局一次；preference 那一趟还会再触发一次。
  滚动时每个新出现的 cell 都要付这个代价。
- 证据：`MarqueeText.swift:28-55`（`onAppear` 写 `containerWidth`、`onPreferenceChange` 写 `textWidth`）。
- 修复：部署目标是 iOS 18，可以直接用 `.onGeometryChange(for: CGSize.self)` 替掉
  `GeometryReader` + preference 的双层结构（一次回调，不引入额外子视图）；
  更彻底的做法是按 (文本, 字体) 缓存一次测量结果（`TextRenderer` / Core Text 测宽），行内完全不测量。
- 验证：Instruments SwiftUI 泳道，fling 滚动时的 View Body 次数与掉帧数；改前改后各录一次。

### 3. 锁屏遮罩下每行时钟仍在跑

- 现象：Face ID 提示出现的那几秒（以及任何锁屏停留期间），app 仍在渲染遮罩背后的 N 个倒计时环。
- 原因：`RootView` 在 `lock.isLocked` 时只调用了 `model.stopTicker()`，但 `TabView` 仍挂在
  `LockScreenView`（`zIndex(5)`）下面，行的 `TimelineView` 与环形动画和 model 的 ticker 是两套机制，不会被停掉。
  冷启动时 `isLocked` 一开始就是 true，`.task` 里又先 `await model.start()` 起了 ticker，所以启动后立刻就是「遮罩 + 背后在跑」。
- 证据：`RootView.swift:67-73`、`RootView.swift:133-145`（注释写着「Nothing on screen needs a clock while the cover is up」）、
  `RootView.swift:85-110`（`.task` 里先 `model.start()` 再 `lock.prepareForLaunch`）。
- 修复：用一个环境值（如 `EnvironmentValues.isCovered`）把「被遮住」传下去，行在被遮住时渲染静态 `CountdownRing`、不建 `TimelineView`；
  或在锁定/非 active 时不给 `TabView` 挂时钟。注意不要用 `opacity(0)`，那仍然会渲染。
- 验证：锁屏停留 10 秒的 Instruments 时间线 / 能耗日志，改前改后对比。

### 4. Root 与列表的 body 比它们真正需要观察的状态更宽

- 现象：每次复制验证码（这是 TOTP app 里最高频的操作）都会重建整个列表 body；每次 toast 出现/消失都会重建 `RootView`（含两个 tab）。
- 原因：`RootView` body 读了 `model.toastMessage`，并且在 ZStack 根上挂了
  `.animation(.snappy(duration: 0.25), value: model.toastMessage)` —— 这条隐式动画会作用于当次事务里整棵子树的全部可动画属性。
  `TokenListView` body 读 `model.copySignal`（给 `.sensoryFeedback` 用）和 `model.errorMessage`，
  于是复制一次 → 整个列表 body 重算（含 `filteredTokens` 的 O(n) 过滤）。
- 证据：`RootView.swift:44-57`、`RootView.swift:82-84`、`TokenListView.swift:52`、`TokenListView.swift:44-51`、`TokenListView.swift:77`。
- 修复：把 toast 抽成只观察 `toastMessage` 的小视图，`.animation(value:)` 挂到它自己身上；
  震动反馈交给一个只读 `copySignal` 的叶子视图（或由 `deliver()` 直接触发），别让列表 body 依赖它。
- 验证：Instruments 里连续点 10 次复制的 View Body 次数与主线程占用。

### 5. 每次回到前台都无条件重新发布 `tokens`

- 现象：从后台切回来时整张列表重建一次（即使数据没变）。
- 原因：`refresh()` 无条件执行 `tokens = Self.sorted(result.tokens)`；而同一函数里 `codes` 已经有
  `if refreshed != codes` 的保护。前台切换路径见 `RootView.swift:149-157`。
- 证据：`TokenListModel.swift:84-97`（`tokens` 无条件赋值）、`TokenListModel.swift:134-136`（`codes` 有保护）。
- 修复：`if newTokens != tokens { tokens = newTokens }`（`OTPToken` 是 `Hashable`），或比较 id + `updatedAt` 集合。
  顺带：`isLoading` 只写不读，列表并不消费它。
- 验证：切前后台一次，看 SwiftUI 泳道是否还有列表重建。

### 6. 两处图片 / Core Image 工作在 main actor 上

- 现象：选完自定义图标后、打开令牌二维码 sheet 时各有一帧卡顿（推断）。
- 原因：
  - `TokenEditorView` 在 `onChange` 里 `Task { ... IconImageProcessor.squareJPEG(from: data) }`。
    这个 `Task` 继承视图的 MainActor 隔离，而 `IconImageProcessor` 是无隔离的普通 enum，
    于是**全尺寸照片的解码 + 96×96 渲染 + JPEG 编码全在主线程**。
  - `QRCodeView` 的 `.task` 里每次都新建 `CIContext()` 并 `createCGImage`，同样在主线程。
- 证据：`TokenEditorView.swift:209-218`、`IconImageProcessor.swift:6-27`、`QRCodeView.swift:62-64`、`QRCodeRenderer.swift:5-14`。
- 修复：`IconImageProcessor` 标成 `nonisolated`（入参出参都是 `Data`，天然 `Sendable`），调用处改
  `Task.detached(priority: .userInitiated)`，只在赋值 `iconData` 时回主 actor；
  `QRCodeRenderer` 复用同一个静态 `CIContext`，渲染放后台。
- 验证：Time Profiler 里检查这两次交互的主线程样本，确认解码栈不在主线程。

### 7. 品牌与图标解析按 body 求值重算，而不是按令牌解析一次

- 现象：低频，但在长列表 / 编辑页输入时会累积。
- 原因：`BrandCatalog.brand(for:)` 是 40 个品牌的线性扫描，且每次都重新 `words(issuer)` / `words(account)`
  （`lowercased` + `components` + `filter` 多次分配）。它在 `TokenIconView` 的 body 里（每次验证码滚动都会跑一次/行），
  在编辑页更是每次按键跑两遍（`iconHint` 一次、`IconPreviewView` → `TokenIconView` 一次）。
  `IconImageCache` 的 key 里带了 `data.hashValue`，每次调用都要哈希整个 icon blob。
- 证据：`TokenIconView.swift:16-40`、`TokenIconView.swift:57-59`、`BrandCatalog.swift:84-119`、`TokenEditorView.swift:60-66`。
- 修复：列表加载时把每个令牌的展示信息（品牌、`UIImage`、马赛克色）解析一次，存成 `[UUID: ResolvedAppearance]`
  交给行使用；编辑页把 `iconHint` 的结果按输入节流或用 `onChange` 收敛，而不是在 body 里算。
- 验证：编辑页连续输入时的 Time Profiler 主线程样本。

### 8. 次要项

- `RootView.swift:82-84`：三条 `.animation(value:)` 挂在 ZStack 根上，隐式动画会作用到整棵子树的可动画属性；
  应挂到各自要动画的那个子视图上。
- `TokenRowView.swift:73-85`：`accessibilityLabel` 在 body 里读 `Date()`，VoiceOver 读到的「剩余 N 秒」可能是渲染时那一刻的值而非朗读时；
  另外每次 body 求值都会拼一次格式化字符串。
- `HoldToClearButton.swift:23-27`、`:96-98`：长按 1.5 秒期间动画 `GeometryReader` 内的 `frame(width:)`，
  每帧都会触发布局。改成固定尺寸 + `scaleEffect(x:)`（`anchor: .leading`）只需要动绘制。
- `OTPCodeFormatter.grouped` 每次调用 `Array(code)` + 拼 3 个 String；除了第 1 条的 tick 路径外，toast 里也在用。

## 指标

无运行期数据，未采信任何数值。建议采集下表后再填：

| 指标 | 改前 | 改后 | 说明 |
| --- | --- | --- | --- |
| CPU（列表静止 10 s） | 待测 | 待测 | 主要看第 1、3 条 |
| 掉帧（fling 滚动 10 s） | 待测 | 待测 | 主要看第 2 条 |
| 复制一次的主线程占用 | 待测 | 待测 | 主要看第 4 条 |
| 内存峰值（打开二维码 sheet） | 待测 | 待测 | 主要看第 6 条 |

## 下一步

1. 先按下面这份采集单抓一次基线（Release 构建、真机），用来确认第 1/2/3 条是不是主因；
2. 最容易落且收益最确定的是第 1 条与第 3 条（改动都很小，且第 1 条同时修掉一个视觉缺陷）；
3. 第 2 条是滚动体验的关键，但需要先有 fling 滚动的 trace 才能确认它比第 1 条更重要。

### 采集单（用户侧操作）

- Release 构建，真机（ProMotion 设备更能暴露第 1/2 条）。
- Instruments 选 SwiftUI 模板，同时开 Time Profiler。
- 三段独立录制，一段只做一件事：① 列表静止 10 秒；② 快速上下 fling 10 秒；③ 连续点行复制 10 次。
- 导出 trace（或 SwiftUI 泳道 + Time Profiler 调用树的截图），附上设备型号 / iOS 版本 / 构建配置。
