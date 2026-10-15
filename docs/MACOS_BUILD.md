# macOS 独立架构打包

当前按用户要求，分别输出 **Apple Silicon（arm64）** 与 **Intel（x86_64）** 的应用包，不再输出 Universal 合包。`.github/workflows/macos-universal.yml` 保留原文件名以保持链接不变，Actions 显示名称已改为 **Build macOS apps (separate Apple Silicon and Intel)**。

## 手动运行与下载

1. 打开仓库 Actions，选择上述 Mac 工作流，然后 **Run workflow → main**。
2. `architecture` 可选 `both`（两个独立包，默认）、`arm64`、`x86_64`。
3. 先在 GitHub Billing/Usage 核实剩余 Actions 配额及超额付费限制，再勾选 `included_quota_confirmed`。
4. 成功后分别下载所需 artifact：
   - Apple Silicon：`EmeraldWatch-macOS-arm64-运行编号`，内含 `EmeraldWatch-macOS-arm64.zip`
   - Intel：`EmeraldWatch-macOS-x86_64-运行编号`，内含 `EmeraldWatch-macOS-x86_64.zip`
5. 从相应 ZIP 解压得到 `EmeraldWatch.app`。两个版本的应用名称相同，请选择适合自己 Mac 的版本，不要把两者解压到同一目录覆盖。

每个包附带 SHA-256、构建信息与日志。公共下载/导入日志单独放在 `EmeraldWatch-macOS-build-logs-运行编号`。失败的运行可能只有日志，不能把日志 artifact 当作成功的应用包。

只支持手动启动；推送代码不触发构建。两种架构共用一次 runner 和模板下载。确认选项不会查询或修改账单，不能替代真正的预算限制。使用标准 `macos-15` runner，最多 30 分钟，artifact 保留 3 天。私有库构建会消耗账户适用配额；无剩余配额时请勿运行。

## 真正的独立架构

`export_presets.cfg` 有两个不同的 Mac 预设：

- **macOS Apple Silicon**：`binary_format/architecture="arm64"`
- **macOS Intel**：`binary_format/architecture="x86_64"`

Godot 4.6.3 的官方 macOS 模板只提供命名为 `.universal` 的引擎文件，而导出器按预设寻找 `.arm64` 或 `.x86_64` 文件。因此工作流先校验官方模板的 SHA-256，再用 Apple `lipo -thin` 从原始二进制生成对应架构的模板条目，之后交给 Godot 组装应用并进行 ad-hoc 签名。裁切发生在最终应用签名之前，不会破坏已签名的输出包。

每个应用都要求 `lipo -archs` 的结果**精确等于**选定架构；不会把同一个 Universal 文件换名后伪装成两个版本。随后检查 Info.plist、bundle ID、实际可执行文件、游戏 PCK、可执行权限与签名。ZIP 在临时目录生成，解压后再次检查架构和签名，全部通过才移动到上传目录。

两种纹理导入格式均已启用，以支持一次导入后分别导出；保持现有 Compatibility 渲染器。

## 签名与安全限制

两个预设均使用 Godot 内置 **ad-hoc 签名**（`codesign/codesign=1`），禁用 notarization。无需 Apple 账户、证书、密钥或付费开发者身份，但没有受 Apple 信任的 Developer ID，**未经过 Apple 公证**。下载的应用可能被 Gatekeeper 阻止，不等于可无提示正式分发的 Mac 应用。此工作流不修改用户电脑安全设置。

## 已定位的失败与验证范围

用户手动启动的 [2026-10-15 运行 #2](https://github.com/caovc/emerald-watch/actions/runs/38711466335) 已成功导出旧版双架构 `.app`，随后在架构检查处失败。根因是我们写错了 Apple `lipo` 参数顺序：`-verify_arch` 会把其后的参数全部当作架构名，因此输入文件路径必须放在它前面。Mac 和 iOS 中相同的写法均已修复。

随后 [运行 #3](https://github.com/caovc/emerald-watch/actions/runs/38712779242) 使用了分架构更新之前的 `dfed986` 提交：导出、双架构、签名和解压校验均通过，但 Python 在 ZIP 内按中文可执行文件名查找时失败。已下载该真实 artifact 确认：ditto 写入 UTF-8 文件名字节，却未设置 ZIP 的 UTF-8 标志，Python 默认按 CP437 解码。现显式指定 `metadata_encoding="utf-8"`，保留完整文件校验；同样加固 iOS 的 ZIP 读取。原失败 ZIP 已在本地用新校验代码通过；后续 iOS 构建结果见 `IOS_BUILD.md`。

第三处失败来自模板重写复用 `ZipInfo`：`writestr` 修改其源 ZIP 偏移，后续读取报 `Bad magic number`。现对每个元数据条目使用 `copy.copy`，并检查输出 CRC 和四个架构条目。`tests/test_macos_templates.py` 复现旧错误，并对真实官方 4.6.3 macOS 模板完成重写、所有成员 CRC/权限与四个单架构 Mach-O 检查。Linux 测试用字节级 Mach-O 裁切模拟 `lipo`，真实 CI 仍使用 Apple `lipo`。

[运行 #5](https://github.com/caovc/emerald-watch/actions/runs/38716810225) 在提交 `a8958eafddf50ecc05ed1bdc0241ef12302d0a48` 上成功生成 Apple Silicon 包。真实 macOS runner 完成导出、thin arm64、严格 ad-hoc 签名及 ZIP 解压复检。下载后再次独立核实 ZIP CRC、校验和、可执行权限、macOS 平台、arm64 和 PCK。

- 包：`EmeraldWatch-macOS-arm64.zip`，40,760,204 字节
- SHA-256：`4fa423adb04d11619ba3449e71bda0dffe187da30d2978251ceb72ff3a32269e`
- 此次仅选择 arm64，Intel 导出未在真实 CI 中运行；Intel 模板切片的本地回归已通过
- 此成功包是当时六关版本，不包含后续十二关与移动布局更新；新源码需要重新构建
- 未在实体 Apple Silicon/Intel Mac 上启动或测试图形与性能；未公证

YAML、Bash、内嵌 Python、导出预设及 lipo/ZIP/template 回归均已检查。

测试新修复时，请通过 **Run workflow** 在最新 `main` 发起新运行。旧运行的 **Re-run** 沿用旧提交，不会带入新代码。

## 固定版本及官方依据

固定 Godot **4.6.3-stable** 编辑器与匹配模板，下载后验证 SHA-256；Actions 同样固定 commit，无需仓库 secrets。

- 编辑器：`https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_macos.universal.zip`
- SHA-256：`30630f3e9b11e10b35c1f90ba8814185dcec43fae1a48345159be7552c64bfe8`
- 模板：`https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz`
- SHA-256：`3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`
- Godot 4.6 macOS 导出：https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html
- 导出参数：https://docs.godotengine.org/en/4.6/classes/class_editorexportplatformmacos.html
- 固定版本导出器：https://github.com/godotengine/godot/blob/4.6.3-stable/platform/macos/export/export_plugin.cpp
- 官方模板独立架构问题：https://github.com/godotengine/godot/issues/121170
- Apple 公证说明：https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
