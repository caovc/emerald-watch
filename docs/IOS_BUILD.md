# iOS 无签名 IPA 构建

本项目使用 GitHub Actions 的标准 macOS runner 编译真正的 iOS arm64 应用，再将 `.app` 放入 `Payload/` 打包为 `.ipa`。不需要在本地安装 Xcode，也不需要把 Apple ID、证书、私钥或描述文件交给 GitHub。

**无签名 IPA 不能直接安装到普通 iPhone。** 下载后仍需由你使用可信的签名工具、自己的签名身份和有效的设备描述文件完成签名与安装。这个工作流不上传 App Store / TestFlight，也不替你登录 Apple 账户。[Apple 的代码签名说明](https://support.apple.com/guide/security/app-code-signing-process-sec7c917bf14/web)

## 当前验证范围

- 已核对 Godot 4.6.3 官方源代码中的导出选项、模板名称与路径
- 已对工作流 YAML 结构、全部 Bash 步骤语法、导出配置结构和图标 XML 做本地检查
- 尚未在 GitHub macOS runner 上执行；这些检查不能代替真实 Xcode 编译或 iPhone 实机验证
- 成功标准：Actions 运行成功，下载的 artifact 内存在 `EmeraldWatch-unsigned.ipa` 和对应 SHA-256 文件；不能只看有无 artifact，因为失败运行也会保留诊断日志

## 第一次运行

1. 将完整项目上传到你自己的 GitHub 私有仓库。保留 `project.godot`、`main.tscn`、`scripts/`、`assets/`、`export_presets.cfg` 和 `.github/workflows/ios-unsigned.yml`。不要上传 `.godot/` 缓存、账户凭据、签名材料或生成的构建文件。
2. 先检查 GitHub 账户 Billing 中的 Actions 已包含用量、剩余额度和付费超额保护。私有仓库的标准 macOS runner 会消耗已包含的额度，artifact 存储也计入用量；不要因“标准 runner”就假定免费。仅在额度足够且已阻止付费超额时运行。不要开启付费额度或升级到 larger runner。
3. 打开仓库 **Actions → Build unsigned iOS IPA → Run workflow**，选定包含完整项目的分支；确认上一步后勾选 `included_quota_confirmed` 并运行。
4. 等待全部构建步骤成功。进入该次运行的 **Artifacts**，下载 `EmeraldWatch-iOS-unsigned-<运行编号>`。
5. 解开 GitHub 外层 artifact ZIP，得到 `EmeraldWatch-unsigned.ipa`、`EmeraldWatch-unsigned.ipa.sha256`、`build-info.txt` 和 `logs/`。不要把外层 ZIP 改名成 IPA。

工作流只有手动触发，没有 push、pull request 或定时触发。单次作业超时 30 分钟，产物保留 3 天；这些设置只是限制意外消耗，**不是账户计费的硬性零费用保证**。手动确认框也不会查询或修改 GitHub 账单设置。需要重新运行前再次检查额度。[GitHub 手动运行说明](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)、[runner 规格](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job)、[预算与超额控制](https://docs.github.com/en/billing/concepts/budgets-and-alerts)

## 构建做了什么

1. 下载固定版本 Godot **4.6.3 stable** macOS universal editor 和同版本标准 export templates，校验已固定的官方 SHA-256。只解出 `templates/ios.zip` 和 `templates/version.txt`，装入 `~/Library/Application Support/Godot/export_templates/4.6.3.stable/`。
2. 通过 `--headless --import` 导入资源，再使用 `--export-release "iOS Unsigned"`。导出目标名固定为 `EmeraldWatch`，不会将带空格或中文的显示名称用作 Xcode 项目文件名。
3. `application/export_project_only=true` 让 Godot 生成 Xcode 工程和游戏 PCK，不走 Godot 内置签名归档流程。
4. 运行 Xcode 的 Release / `iphoneos` / `arm64` 编译。显式关闭 `CODE_SIGNING_ALLOWED`、`CODE_SIGNING_REQUIRED`，清空 team、identity、entitlements 和 provisioning 设置，并使用 `CODE_SIGN_STYLE=Manual`。不传 `-allowProvisioningUpdates`，不调用 `-exportArchive`。
5. 检查真实的 `.app`、Mach-O 可执行文件、arm64 架构、iOS 平台标识、bundle ID、PCK 和横屏方向。确认应用没有代码签名或 embedded provisioning profile，然后以 `Payload/EmeraldWatch.app/` 结构打包并再次检查 ZIP 完整性和可执行权限。
6. 上传 IPA、校验文件、源码 commit、Xcode/SDK 版本及日志。所有构建中间文件都在 runner 的临时目录，避免被打进游戏资源包。

[Godot 4.6 命令行导出](https://docs.godotengine.org/en/4.6/tutorials/editor/command_line_tutorial.html)、[Apple build settings](https://developer.apple.com/documentation/xcode/build-settings-reference)、[命令行 build setting 优先级](https://developer.apple.com/documentation/xcode/configuring-the-build-settings-of-a-target/)

## 导出配置中的特殊项

- Bundle ID：`dev.emeraldwatch.game`。这是此项目的构建标识，不代表已经在 Apple 注册或验证其唯一性。最终签名工具可能需要换成你可用的标识。
- 最低 iOS：14.0；设备族 `2` 在 Godot 中表示 iPhone 与 iPad，映射到 Xcode 的 `1,2`。
- Team ID：`0000000000` 是公开占位符，不是真实团队、账户或凭据。Godot 4.6.3 即使只导出工程仍拒绝空 Team ID。官方源码只检查它非空，因此此流程填入 10 位占位符，并在实际 Xcode 构建时用空 `DEVELOPMENT_TEAM` 覆盖。这里依据源码设计了无签名流程；它不是用于签名发布的有效团队设置。
- `icons/icon_1024x1024` 与 `icons/app_store_1024x1024` 使用单独的 `assets/icon-ios.svg`，背景完全不透明。原来的桌面图标不变。
- 游戏使用 Compatibility renderer；shader baker 关闭。方向来自 `project.godot` 的 `display/window/handheld/orientation`，工作流会拒绝包含竖屏方向的成品。
- Game Center、push notifications、increased-memory entitlement 和额外 entitlements 均关闭；没有 iOS 原生插件。未来添加 GDExtension、动态库、原生插件或额外 capability 时必须重新审查构建与签名流程。Godot 的“仅导出工程”仍可能预签动态库，不能把当前流程无条件套用到带这些插件的项目。

选项依据：[Godot iOS 导出指南](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_ios.html)、[EditorExportPlatformIOS 选项](https://docs.godotengine.org/en/4.6/classes/class_editorexportplatformios.html)、[固定 4.6.3 exporter 源码](https://github.com/godotengine/godot/blob/4.6.3-stable/editor/export/editor_export_platform_apple_embedded.cpp)、[固定 Xcode 模板](https://github.com/godotengine/godot/blob/4.6.3-stable/misc/dist/apple_embedded_xcode/godot_apple_embedded.xcodeproj/project.pbxproj)

## 固定下载源与校验值

官方发布：[Godot 4.6.3 stable](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable)，[发布资源清单与 SHA-256](https://github.com/godotengine/godot-builds/releases/expanded_assets/4.6.3-stable)

macOS editor：

https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_macos.universal.zip

SHA-256：`30630f3e9b11e10b35c1f90ba8814185dcec43fae1a48345159be7552c64bfe8`

Export templates：

https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz

SHA-256：`3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`

工作流还把官方 [actions/checkout v4.2.2](https://github.com/actions/checkout/releases/tag/v4.2.2) 与 [actions/upload-artifact v4.6.2](https://github.com/actions/upload-artifact/releases/tag/v4.6.2) 固定到了对应 commit。仓库 token 仅有 `contents: read`，checkout 不保留 Git 凭据。

## 排错

- 找不到 Run workflow：确认该工作流文件已经在仓库默认分支上，并且当前账户有写入权限。
- 构建作业被跳过：确认勾选框是否仍为 false；必须先完成额度核对，再手动运行。
- checksum 错误：停止使用下载文件，核对官方版本与文件。不要为了“跑通”删除校验。
- Godot 提示脚本错误：查看 `logs/godot-import.log` 与 `logs/godot-export.log`，修复项目后重新运行。
- Xcode 编译错误：查看 `logs/xcodebuild.log`，同时保留 `build-info.txt` 中的 Xcode/SDK 版本。runner 镜像会更新，Godot 版本和模板固定并不意味着 Xcode 永久不变。
- 下载包里只有日志：运行没有完成 IPA 打包。先查失败步骤，不要将日志 ZIP 或 Godot 工程 ZIP 当作 IPA。
- iPhone 拒绝安装：无签名文件本身不可安装；需要你在可信环境中签名。不要把 Apple 密码、私钥或描述文件提交到仓库。


## ZIP 文件名兼容性检查（2026-10-15）

Mac 构建的真实日志暴露了 ZIP UTF-8 标志缺失导致 Python 错误解码中文文件名的问题。iOS 构建当前使用 ASCII 产品路径 `Payload/EmeraldWatch.app`，并从 Info.plist 读取实际可执行文件名，不假设游戏显示名称就是文件名。为兼容未来非 ASCII 文件名，IPA 检查现也显式使用 UTF-8 元数据解码。`lipo` 的输入文件已放在 `-verify_arch` 前面。仍保留 iphoneos/arm64、真实 Mach-O、PCK、可执行权限、unsigned/无 provisioning profile 等检查。用户启动的 [iOS 运行 #2](https://github.com/caovc/emerald-watch/actions/runs/38714338466) 已在 `b7172ae942334bac0ff3f97a3e1b24e9076c5f6f` 成功完成真实 Xcode/iphoneos 编译和 IPA 打包。下载后独立核实 CRC、SHA-256、可执行权限、thin arm64、iOS Mach-O 平台、PCK、无代码签名和无 provisioning profile。

- IPA：`EmeraldWatch-unsigned.ipa`，37,251,085 字节
- SHA-256：`d28327c263d924d3d1cc98213c98675ce939b1c29dc03d1466b4e8d8f175e49b`
- 此成功包是当时六关版本，不包含后续十二关、响应式布局与双向横屏更新；新源码需要重新构建
- 未做实体 iPhone 安装/运行验证；无签名 IPA 仍需用户自行在可信环境签名

当前源码方向 `orientation=4` 为 sensor landscape；Godot 将两个横屏方向写入 iPhone/iPad 配置，导出预设没有覆盖该设置。此新布局的设备显示与触控仍需实际手机验证。
