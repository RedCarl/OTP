# App Store Connect 填写记录（otp令牌）

App ID：**6835475936** · 套装 ID `cn.carljoy.otp` · SKU `otp-token-2026` · 版本 1.0
账号：lei sun（团队 BCRZR3P4AP） · 最后更新：2026-11-18

## 一、App 信息（可本地化信息）

| 字段 | 已填内容 | 剩余字符 |
|---|---|---|
| 名称 | `OTP令牌 - 两步验证 & iCloud 同步` | 6 / 30 |
| 副标题 | `本地生成验证码，扫码即添加` | 17 / 30 |
| 主要语言 | 简体中文 | — |
| 类别 | 工具（次要未填） | — |
| 内容版权 | 否，不包含第三方内容 | — |
| 许可协议 | Apple 标准许可协议 | — |

## 二、1.0 版本页

| 字段 | 已填内容 |
|---|---|
| 推广文本 | 把验证码交给 iCloud 钥匙串：本地生成、端到端加密同步，换手机自动回来。不联网、无账号、无广告。 |
| 描述 | 见 App Store 后端（约 660 字，按「生成 / 添加 / 同步备份 / 迁移 / 保护 / 隐私」六段写） |
| 关键词 | `验证码,两步验证,动态口令,OTP,TOTP,认证器,2FA,iCloud,令牌,扫码,备份,authenticator,密码管理`（65 字） |
| 技术支持网址 | `https://redcarl.github.io/OTP/support.html` |
| 营销网址 | `https://redcarl.github.io/OTP/` |
| 版本 | 1.0 |
| 版权 | `2026 孙磊` |

## 三、App 审核信息

| 字段 | 值 |
|---|---|
| 需要登录 | 否（已取消勾选，本应用无账号） |
| 联系信息 | 孙磊 / +86 17386691897 / carl030101@icloud.com |
| 备注 | 英文审核说明：本地 TOTP/HOTP 认证器、无账号无服务器、iCloud 钥匙串存令牌、相机与 Face ID 用途、四步测试步骤、界面支持简体中文 / English（跟随系统或设置内切换） |

## 四、隐私

| 项 | 值 |
|---|---|
| 隐私政策网址 | `https://redcarl.github.io/OTP/privacy.html` |
| 用户隐私选择网址 | 未填（可不填） |
| 数据收集 | 未收集数据（已发布，2026-11-18） |

## 五、价格与销售范围

| 项 | 值 |
|---|---|
| 价格 | $0.00（免费），175 个国家或地区 |
| 供应情况 | 所有 175 个国家或地区，App 发布时供应 |
| 税务类别 | App Store 软件 |
| 搭载 Apple 芯片的 Mac | 允许（自动 macOS 11.0） |

## 六、站点（本次新建）

仓库 <https://github.com/RedCarl/OTP>（公开），GitHub Pages：

| 页面 | URL |
|---|---|
| 介绍 | https://redcarl.github.io/OTP/ |
| 隐私政策 | https://redcarl.github.io/OTP/privacy.html |
| 支持 / FAQ | https://redcarl.github.io/OTP/support.html |

源文件在本项目 `site/` 目录，改完推到该仓库即生效。

## 七、还差的三步（必须你来做）

1. **上传构建版本**：Xcode → Product → Archive → Distribute App → App Store Connect，或 `xcrun altool`。当前 ASC 里 1.0 还没有任何构建版本，「添加以供审核」是灰的。
2. **上传截屏**：`docs/screen-*.png` 是 1206×2622（iPhone 16 Pro 尺寸）。版本页的截屏区按机型分槽，选中对应槽位再「上传」或直接把文件拖进虚线框。至少 3 张，6.9" 槽位要用 1320×2868。
3. **中国大陆区与备案**：你说本地工具不需要备案——工信部口径确实如此，但 **Apple 对在中国大陆区上架的 App 仍要求提供 ICP 备案号**。若不做备案，建议在「App 供应情况」里把「中国大陆」取消勾选，只上其他地区；要上大陆区就得补备案号。

## 八、构建与截屏（2026-11-18 执行）

| 步骤 | 状态 | 证据 |
|---|---|---|
| 归档 1.0 (9) | ✅ 成功 | `build/OTP.xcarchive`，`** ARCHIVE SUCCEEDED **` |
| 导出 + 上传 | ❌ 阻塞 | `exportArchive` 报 `No Accounts` / `No signing certificate "iOS Distribution" found` |
| 上传截屏 | ✅ 3 张 | 版本页显示 `3/10 张 App 截屏`（列表 / 备份 / 设置） |

### 为什么传不上去

Xcode → Settings → Accounts 里**没有任何 Apple ID**（`DVTDeveloperAccountManagerAppleIDLists` 为空）。archive 用的是本机 Apple Development 证书，所以能过；导出上架必须用分发证书，而分发证书现在是 Xcode 云托管、私钥不在本机钥匙串，命令行无法绕过。

### 还有一个会接着报的错

用 `security cms -D` 对比两份描述文件：

- 开发描述文件（f10d1b33）**有** iCloud entitlements
- 商店描述文件（c229f97a）**没有** iCloud entitlements

所以即使登录账号，第一次导出仍可能报
`Provisioning profile ... doesn't include the iCloud capability`。
用自动签名重新 archive 会重签一份描述文件；若仍报，去 Certificates, Identifiers & Profiles → Identifiers → `cn.carljoy.otp` → 勾上 iCloud，再 archive。

### 登录账号后一条命令收尾

```bash
bash ~/.dsh/skills/appstore-release/scripts/upload.sh /Users/redcarl/otp OTP BCRZR3P4AP /Users/redcarl/otp/build ios
```

API 密钥已验证可用（能列出 App），导出 ipa 后也可以直接传：

```bash
bash ~/.dsh/skills/appstore-release/scripts/altool-upload.sh build/export/OTP.ipa 6SYYHDN6SJ b271463c-6263-47e7-9d54-5323bb37e0f7
```

## 九、补记：构建已上传（2026-11-18 15:28）

上一节的阻塞已经绕过——**不需要在 Xcode 里登录 Apple ID**。

`xcodebuild -exportArchive` 支持用 ASC API 密钥认证，Xcode 会拿密钥自己申请分发证书、重签描述文件、签名并上传：

```bash
xcodebuild -exportArchive \
  -archivePath build/OTP.xcarchive \
  -exportOptionsPlist build/upload.plist \
  -exportPath build/upload -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_6SYYHDN6SJ.p8 \
  -authenticationKeyID 6SYYHDN6SJ \
  -authenticationKeyIssuerID b271463c-6263-47e7-9d54-5323bb37e0f7
```

实测输出：

```
Progress 100%: Uploading "OTP.ipa" is complete.
Progress 100%: Upload succeeded.
Uploaded OTP
** EXPORT SUCCEEDED **
```

构建 1.0 (9) 已进 App Store Connect，正在处理（通常 10–30 分钟）。处理完在版本页「构建版本 → 添加构建版本」里选它，就能点「添加以供审核」。

截屏当前 3 张（列表 / 备份 / 设置）。想补齐到 5 张的话，把 `docs/screen-add.png`、`screen-import.png` 也传上去即可。

## 十、双语与官网（2026-11-18 15:35）

- App 已支持简体中文 / English：默认跟随系统，设置 → 语言可手动切换。
- 官网已落到 `site/`（index / privacy / support，中英文），通过 `.github/workflows/pages.yml` 发布到 <https://redcarl.github.io/OTP/>；App Store 的三个 URL 保持使用该域名。
- **注意**：当前已上传的 build 9 归档时间为 15:16，可能早于语言切换/弹窗环境的最后修复（英文模式下「添加令牌」弹窗可能仍显示中文）。提交审核前请重新 archive 并上传新的 build（10+），在 TestFlight 里确认英文模式下列表、设置、添加弹窗、导入与备份均为英文。

## 十一、build 10 已上传并进 TestFlight（2026-11-18 16:12）

- 版本：**1.0 (10)**，CFBundleVersion = 10，已上传 App Store Connect。
- 本次归档已移除「设置 → 语言」下面的说明 tips；归档包内 OTP 二进制与 Localizable.strings 均无「跟随系统时…」字符串。
- 处理状态：VALID（16:12 完成），已在内测组，internalBuildState = IN_BETA_TESTING。
- 外测状态：externalBuildState = READY_FOR_BETA_SUBMISSION（还没提交外部 Beta 审核）。
- 归档在 build/OTP.xcarchive，build 9 留在 build/OTP-build9.xcarchive。

## 十二、build 11：语言选择交互修正（2026-11-18 17:31）

- 版本：**1.0 (11)**，CFBundleVersion = 11，已上传 App Store Connect，处理状态 **VALID**（17:32 上传完成）。
- 问题：设置 → 语言用 `Picker(.navigationLink)`，点一下语言就自动回退，而且根视图按语言 `.id(appLanguage)` 重建整棵 tab 树，导航栈被清空，于是「选完语言立刻被弹回设置页」，看不到切换效果。
- 现在：语言改成独立选择页（`Features/Settings/LanguagePickerView.swift`），点一行立刻生效但**留在本页**，勾选和标题当场更新；返回后设置页、标签栏、令牌列表文案一起换。根视图不再按语言重建，改用 `LanguageStore`（`@Observable`）+ `environment(\.locale)` 就地刷新。
- 新增 `OTPUITests/LanguageUITests.swift`：断言选中语言后仍停在语言页、标题即刻换语言；原有 `AddTokenUITests.testLanguageSwitchUpdatesInterface` 同步改成新交互。
- 全量测试：`OPTTests` 84 项 + `OTPUITests` 14 项全部通过。
- 归档在 build/OTP.xcarchive；build 10 留在 build/OTP-build10.xcarchive。


## 十三、build 12：添加令牌交互 + 左右滑动切页（2026-11-18 20:06）

- 版本：**1.0 (12)**，CFBundleVersion = 12，已上传 App Store Connect，处理状态 **VALID**（20:13 上传完成）。
- 添加令牌：「从文件导入 / 从相册识别」直接弹系统选择器，选完才进导入页；不再先弹一层「导入令牌」窗口。系统文件选择器首次冷启动约 1–2 秒才出现，属系统侧延迟。
- 粘贴链接：sheet 第一帧就是粘贴页（之前是 `.task` 里切 stage，会先闪来源列表）；来源 / 粘贴 / 确认 / 读取四态之间用滑入 + 淡入过渡。
- 设置 → 导入数据：改成先进导入来源页，文件选择器在页内弹，同样不再叠两层窗口。
- 令牌页 ↔ 设置页：支持左右滑动切换，松手后新页面从对应方向滑入（0.28s），保留系统原生标签栏；从屏幕左缘起手的手势不接管，留给系统返回。
- 测试：`OPTTests` 84 项 + `OTPUITests` 17 项全部通过；新增 `OTPUITests/UXPolishUITests.swift`（滑动切页、粘贴直进、文件导入无中间层）。
- 归档在 build/OTP.xcarchive；build 11 留在 build/OTP-build11.xcarchive。


## 十四、build 13：粘贴内联 + 标签栏平移过渡（2026-11-18 21:12）

- 版本：**1.0 (13)**，CFBundleVersion = 13，用新增的 `scripts/testflight.sh` 归档上传，处理状态 **VALID**（21:12 上传完成）。
- 粘贴链接：不再另开第二层 sheet，改为在「添加令牌」卡片里就地展开粘贴页（自动展开到全高、左上角「返回」）；解析成功才弹「确认导入」，失败就地红字提示。
- 标签栏切换：点标签栏换页时新页面从对应方向平移淡入（0.3s / 32% 屏宽 / 透明度 0.45→1），不再硬切；上一版的屏幕左右滑动手势已删除（那是理解错的方向）。
- 测试：`OPTTests` 84 项 + `OTPUITests` 17 项全过；`UXPolishUITests` 覆盖内联粘贴、文件导入无中间层、标签栏双向切换。
- 约定：以后每次改完、测试通过后，`project.yml` 构建号 +1 并执行 `scripts/testflight.sh` 自动上传。
- 归档在 build/OTP.xcarchive；build 12 留在 build/OTP-build12.xcarchive。


## 十五、build 14：标签栏改成整条平移 + 手动输入内联（2026-11-18 22:00）

- 版本：**1.0 (14)**，CFBundleVersion = 14，处理状态 **VALID**（22:01 上传完成）。
- 标签栏切页：不再用系统 `TabView`，改成自绘分页器——令牌和设置两页并排放在同一条「带子」里，点标签栏时整条带子左右平移（0.32s easeInOut），两页一起动，像翻页而不是淡入淡出。底部标签栏换成自绘胶囊（material 背景 + 选中胶囊高亮），保留原尺寸位置。
- 手动输入：和粘贴链接一样在「添加令牌」卡片里就地展开编辑表单（卡片自动提到全高，左上角「返回」、右上角「保存」），不再弹第二个 sheet。
- 测试：`OPTTests` 84 项 + `OTPUITests` 17 项全过；UI 测试里的标签栏查询从 `app.tabBars` 改成 `tab.tokens` / `tab.settings` 标识。
- 归档在 build/OTP.xcarchive；build 13 留在 build/OTP-build13.xcarchive。


## 十六、build 15：还原系统标签栏（2026-11-18 22:35）

- 版本：**1.0 (15)**，CFBundleVersion = 15，处理状态 **VALID**（22:53 上传完成）。
- build 14 为了「两页整条平移」把系统 `TabBar` 换成了自绘胶囊分页器，代价是丢掉系统标签栏；按反馈**还原**：恢复系统 `TabView` + 系统标签栏，切页回到原始的直接切换，不再做自定义过渡动画。
- 保留 build 13/14 里其它已确认的改动：粘贴链接 / 手动输入都在「添加令牌」卡片内联展开；语言切换、导入流程修复不变。
- 测试：UI 测试的标签栏查询恢复成 `app.tabBars.buttons[...]` 的本地化文案。


## 十七、1.0.1：设置新增评分 / 分享 / 邮件反馈（2026-11-19）

- 版本：**1.0.1 (16)**，`MARKETING_VERSION` 1.0 → 1.0.1，构建号 16；归档 `build/OTP.xcarchive`，build 15 保留为 `build/OTP-build15.xcarchive`。
- 新功能：设置页在「清空所有令牌」**上面**新增一组入口。
  - **去应用商店评分**：`itms-apps://itunes.apple.com/app/id6835475936?action=write-review` 直达写评价页；App Store 不接受时回退网页版 `https://apps.apple.com/app/id6835475936?action=write-review`。
  - **分享应用**：`ShareLink` 带 App Store 链接 + 一句介绍。
  - **意见反馈（邮件）**：`mailto:` 预填主题与正文（版本 / 构建号 / iOS 版本 / 机型），没有可用邮件 App 时提示手动发到 `carl030101@icloud.com`。
- 代码：新增 `OTP/Features/Settings/AppLinks.swift`（App Store ID、支持邮箱、mailto 组装、版本读取）；`SettingsView` 增加 Section 与失败提示 alert；`Localizable.xcstrings` 新增 14 条英文翻译。
- 测试：`OTPTests` 新增 `AppLinksTests`（4 项），全量通过；`OTPUITests` 17 项，其中 `testHoldToClearRemovesAllTokens` 因新分组把「清空所有令牌」推到首屏外失败，改成先滚动再长按，单独复跑 AddTokenUITests 全通过。
- 截图：`docs/screen-settings.png` 换成含新入口的设置页，另存 `docs/screen-settings-support.png`（滚动到支持分组）。
- 上传与提审：build 16 已上传，处理状态 **VALID**；已关联到版本页 1.0.1、填写「新功能」，并通过 Review Submission API 提交审核（2026-11-19 08:58，状态 **WAITING_FOR_REVIEW**，审核通过后自动上架）。
- 版本页「新功能」文案：`设置里新增三个入口：去 App Store 评分、把 OTP 分享给朋友、用邮件反馈问题（邮件会自动带上版本、系统与机型，方便定位问题）。`
- 版本页截屏沿用 1.0 的 3 张（列表 / 备份 / 设置）：1.0.1 版本页在创建时已带截屏，未改动。
- 工具：`scripts/testflight.sh` 改为从 `project.yml` 读取 `MARKETING_VERSION`，归档日志打印真实版本号。
