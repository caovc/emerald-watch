# macOS Universal 2 打包

仓库中的 `.github/workflows/macos-universal.yml` 只支持手动运行。推送代码不会触发构建。

## 手动运行与下载

1. 打开仓库 **Actions → Build macOS Universal app → Run workflow**，选择 `main`。
2. 先在自己的 GitHub Billing/Usage 页面核实剩余 Actions 配额以及超额付费已被阻止，再勾选 `included_quota_confirmed`。
3. 运行成功后下载 `EmeraldWatch-macOS-universal-运行编号` artifact。
4. 解开 artifact，里面的 `EmeraldWatch-macOS-universal.zip` 才是应用包；再次解压得到 `EmeraldWatch.app`。同目录还包含 SHA-256 校验文件、构建信息和日志。

勾选项只是使用者的确认，不会查询或修改 GitHub 账单设置，也不能替代真正的预算/超额限制。工作流使用标准 `macos-15` runner，单次最多 30 分钟，artifact 保留 3 天。私有库的 macOS runner 会消耗账户适用的 Actions 配额；无配额时请勿运行。这里没有开启收费或申请额外资源。

## Intel 与 Apple Silicon

`export_presets.cfg` 中的 **macOS Universal** 使用 `binary_format/architecture="universal"`。同一个 `.app` 包含 **x86_64（Intel）和 arm64（Apple Silicon）**，不是仅适用于某一种芯片的包。

项目同时启用 S3TC/BPTC 与 ETC2/ASTC 纹理导入，这是 Godot 4.6.3 的 Universal 导出配置检查要求。导出保留现有 Compatibility 渲染器。

工作流检查实际 Mach-O 可执行文件，并用 `lipo -verify_arch x86_64 arm64` 强制要求两种架构；还检查 Info.plist、bundle ID、游戏 PCK、可执行权限及签名。打包后重新解压，再检查双架构与完整签名。只有这些步骤通过才会报告打包验证成功。这不代表已在两种实体 Mac 上完成图形/性能测试。

## 签名与系统安全

该预设采用 Godot 内置 **ad-hoc 签名**（`codesign/codesign=1`），并禁用 notarization。它不需要 Apple 账户、证书、密钥或付费开发者身份，但也没有受 Apple 信任的 Developer ID 身份，**未经过 Apple 公证**。

因此它适合自行测试，不等于可无提示分发的正式 Mac 应用。从 GitHub 下载的应用仍可能被 macOS Gatekeeper 阻止。此工作流不改变用户电脑的安全设置。若要面向其他用户正式分发，需要另行设计 Developer ID 签名与公证流程。

## 固定版本与供应链校验

使用官方 Godot **4.6.3-stable** 编辑器及完全匹配的标准导出模板。下载后检查固定 SHA-256，只提取模板里的 `macos.zip` 与 `version.txt`。

- 编辑器：`https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_macos.universal.zip`
- SHA-256：`30630f3e9b11e10b35c1f90ba8814185dcec43fae1a48345159be7552c64bfe8`
- 模板：`https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz`
- SHA-256：`3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`

Actions checkout 和 artifact 上传均固定到具体 commit；checkout 不保留 Git 凭据。无需仓库 secrets。

## 当前验证范围

已静态检查 YAML、所有 Bash 步骤、内嵌 Python、Godot 导出预设，以及双架构/手动触发约束。用户于 2026-10-15 手动启动的 [运行 #2](https://github.com/caovc/emerald-watch/actions/runs/38711466335) 已成功导出含 Intel 与 Apple Silicon 双架构的 `.app`，但在后续架构校验时失败，尚未生成应用 ZIP。

已修复该次失败的根因：Apple `lipo` 的 `-verify_arch` 会把其后的参数全部当成架构名，因此可执行文件路径必须放在该选项之前。两处 Mac 检查和同样写法的 iOS 检查都已修正，并加入 `tests/test_workflow_lipo.py` 回归检查。

修复后的工作流尚待真实云端构建验证，签名及 ZIP 后续步骤、实体 Mac 图形/性能也尚未验证。请在 **Actions → Build macOS Universal app → Run workflow** 中选择最新 `main` 发起新运行；旧运行的 Re-run 会沿用旧提交，无法测试此次修复。失败的运行可能仍上传诊断日志，不能把只有日志的 artifact 当作已成功生成应用。

## 官方依据

- Godot 4.6 macOS 导出与签名说明：https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html
- macOS 导出参数：https://docs.godotengine.org/en/4.6/classes/class_editorexportplatformmacos.html
- 固定版本导出器实现（Universal 架构、ad-hoc 枚举、纹理前置检查）：https://github.com/godotengine/godot/blob/4.6.3-stable/platform/macos/export/export_plugin.cpp
- 纹理导入判断：https://github.com/godotengine/godot/blob/4.6.3-stable/editor/import/resource_importer_texture_settings.cpp
- 固定版本官方发布：https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable
- Apple 关于签名与公证：https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
