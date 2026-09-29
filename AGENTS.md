# DLP 管理应用组件指引

## DLP 服务概述

数据防泄漏（DLP: Data Loss Prevention）管理应用是 OpenHarmony 应用子系统下的 DLP 文件管理入口应用，bundleName `com.ohos.dlpmanager`，为终端用户提供对文档的加密保护、权限修改、DLP 文件打开与查看、加密分享能力。本仓以 ArkTS 应用形态存在，通过 8 个 ExtensionAbility 暴露能力，无标准 UIAbility。底层 DLP 能力依赖 `@ohos.dlpPermission` SDK 与外部 `security_dlp_permission_service`（SA 3521）及 DLP 凭证服务（`dlp_credential_service`），本仓不自行实现证书签发、加解密算法，也不直接使用密钥；HUKS 操作通过 `HuksCipherUtil` 适配层调用。SA 3521 与凭证服务不在本仓职责范围内。

## 项目定位

本仓库对应 OpenHarmony `applications/standard/dlp_manager`。bundleName `com.ohos.dlpmanager`，vendor `ohos`，versionName `7.1.0.304`，minAPIVersion 12，targetAPIVersion 12，仅支持 `standard` 系统。部件名 `@ohos/dlp_manager`（subsystem `applications`）。优先按这些目录定位问题：

- `entry/src/main/ets/Application/`：应用生命周期入口。`AbilityStage.ets` 是 App 启动入口，扩展 `AbilityStage`，负责初始化全局资源、日志、HiSysEvent domain。
- `entry/src/main/ets/Ability/`：8 个 ExtensionAbility 声明与实现。`MainAbilityEx.ets`（sys/commonUI，exported=true，主入口）路由到加密保护/改密/权限状态页；`DlpFileProcessAbility.ets`（service，DLP 文件 RPC 服务，含 `DlpRpcServiceStub`）实现 `genDlpFile`/`openDlpFile`/`closeDlpFile`/`recoverDlpFile`/`stopFuseLink`/`resumeFuseLink`/`sandBoxLinkFile`；`ViewAbility.ets`（service，DLP 文件查看编排，调度 `OpenDlpFileProcessor`）；`EncryptedSharingAbility.ets`（action，exported=true，加密分享）；`DataAbility.ets`（service，历史监控）；`ClearDlpCacheAbility.ets`（service，缓存清理）；`DialogUIExtAbility.ets`/`OpeningDialogUIExtAbility.ets`/`PhoneDialogUIExtAbility.ets`（sys/commonUI 对话框）。`data/IIdlDlpRpcServiceTs/` 是 IDL 生成的 RPC 代码（`id_dlpRpc_service_proxy.ets`、`id_dlpRpc_service_stub.ets`），禁止手改生成产物。
- `entry/src/main/ets/OpenDlpFile/`：DLP 文件打开/解密引擎。`ViewProcessor/ViewProcessor.ets`（`OpenDlpFileProcessor` 编排）；`manager/`（11 个 manager：`OpenDlpFileManager` 单例 + AsyncLock 管理解密状态/内容映射、`DecryptManager`、`SandboxManager`、`AlertManager`、`ErrorManager`、`OpeningDialogManager`、`TerminateManager`、`DataManager`、`StartFileManager`、`ApplyEfficiencyManager`）；`handler/`（`AccountHandler`/`FileIdHandler`/`FileParseHandler` 工厂模式）；`data/`（`DecryptContent`/`OpenDlpFileData` 数据载体）；`common/`（`DlpFileOpenReport` 遥测、`OpenDlpFileError` 错误定义）。
- `entry/src/main/ets/pages/`：8 个页面，由 `entry/src/main/resources/base/profile/main_pages.json` 声明。`encryptionProtection.ets`（@Entry，主加密 UI，1000+ 行）；`changeEncryption.ets`（修改 DLP 文件权限）；`permissionStatus.ets`（权限状态展示）；`encryptionSuccess.ets`（加密成功页）；`alert.ets`（通用告警）；`encryptedSharing.ets`（加密分享页）；`OpeningDialog.ets`/`PhoneDialog.ets`（对话框页）。
- `entry/src/main/ets/component/`：UI 复用组件。`encryptionComponents/`（`AddStaff`、`dlp_alert_dialog`、`encrypting`、`permission_type_select`、`staff`）；`helper/`（`EncryptProtectionHelper`、`EncryptSharingHelper`）。
- `entry/src/main/ets/manager/`：顶层 manager。`AccountManager.ets`（账号查询，连接 DlpCredMgr RPC）；`AccountAssociationManager.ets`（账号关联管理）；`CommonEventManager.ets`（公共事件）；`PermStatusNotifyManager.ets`（权限状态通知）；`UIContextManager.ets`（UI 上下文管理）。
- `entry/src/main/ets/rpc/`：RPC 通信层。`CredConnectService.ets`/`CredConnectServiceDomain.ets`/`CredConnectServiceFileId.ets`（三路凭证服务连接）；`CredCallbackStub.ets`（凭证回调 stub）；`ClearDlpCache/ClearDlpCacheStub.ets`；`OpeningDialog/service/OpeningDialogService.ets` + `stub/OpeningDialogStub.ets`；`ViewAbility/service/ViewAbilityService.ets` + `stub/ViewAbilityStub.ets`；`DlpPermissionAbilityServiceStub.ets`。
- `entry/src/main/ets/common/`：共享基础设施。`base/`（`HiLog.ts` 域 0xf888 tag DLPManager、`GlobalContext.ts` 基于 globalThis、`CounterLock.ets`、`Result.ets`/`ResultMsg.ets`、`Singleton.ets` 泛型单例）；`bean/data/`（`dlpClass.ets` 含 `IDLDLPProperty` + `IAuthUser` 扩展 `rpc.MessageSequence` 用于 IPC 序列化、`FileMetaInfo`、`FileParseInfo`、`AuthorizedAccount`、`AccountAssociation`、`DlpFileCreateReportInfo`）；`bean/request/`、`bean/response/`（DTO）；`config/HuksProperties.ets`（HUKS 配置）；`constants/constant.ets`（中心常量类 400+ 行：UI 尺寸、错误码、RPC token、超时、文件限制、want 参数；`AppStorageConstant.ets` AppStorage key 常量）；`enum/`（`FileEnum`、`MaterialEnum`、`EncryptProtectionShowCodeEnum`、`EncryptSharingShowCodeEnum`）。
- `entry/src/main/ets/convertor/`：`AccountAssociationConvertor.ets` 账号关联转换器。
- `entry/src/main/ets/service/`：`AccountAssociationService.ets` 账号关联服务。
- `entry/src/main/ets/utils/`：13 个工具类。`HuksCipherUtil.ets`（HUKS 加解密）；`FileUtils.ets`（文件工具，匿名化、后缀解析）；`FsUtil.ets`（文件系统操作封装）；`DLPMaterialUtil.ets`（系统素材）；`ReportSecurityEventUtil.ets`/`ReportToBigDataUtil.ets`/`DlpFileCreateReport.ets`（上报）；`StorageUtil.ets`、`AppStorageUtil.ets`、`CommonUtil.ets`、`AccountAssociationUtil.ets`、`AccountTipsConfigUtil.ets`、`SupportTypesUtil.ets`、`systemUtils.ets`、`utils.ets`（`getOsAccountInfo`、`checkDomainAccountInfo` 等）。
- `entry/src/main/ets/validator/`：`UriValidator.ets`（职责链模式 URI 校验器，`BaseValidator` + `setNext`/`handle`）；`AccountAssociation/AssociationDecryptValidator.ets`、`AssociationEncryptValidator.ets`。
- `entry/src/main/ets/cleanDlpCache/`：`cleanDlpFileInCache.ets` 缓存清理工具。
- `entry/src/ohosTest/`：测试模块。基于 `@ohos/hypium` 1.0.19。入口 `ets/testability/TestAbility.ets` + `pages/Index.ets`；`test/List.test.ets` 聚合 36 个测试文件；按源码模块分组（`bean/`、`common/`、`component/`、`convertor/`、`manager/`、`openDlpFile/`、`rpc/`、`service/`、`validator/`）。
- `entry/src/main/module.json`：模块声明（构建时需重命名为 `module.json5`）。8 个 ExtensionAbility、10 个权限、deviceTypes（default/tablet/2in1）、metadata `ArkTSPartialUpdate: true`。
- `AppScope/app.json`：App 级配置（构建时需重命名为 `app.json5`）。bundleName、versionCode、icon、label、configuration。
- `entry/src/main/resources/`：23 个语言目录 + base + dark + rawfile。`base/profile/main_pages.json`（8 个页面路由）；`base/element/string.json`（120+ 字符串）；`rawfile/account_tips.json`（账号提示配置）。
- `bundle.json`：部件声明（`@ohos/dlp_manager` 3.1.0，subsystem `applications`，dest `applications/standard/dlp_manager`）。
- `build-profile.json5`：DevEco Studio 构建配置（compileSdkVersion 26.0.1，compatibleSdkVersion 26.0.0，runtimeOS OpenHarmony）。
- `oh-package.json5`：包清单（devDependency `@ohos/hypium` 1.0.19）。
- `BUILD.gn`：OpenHarmony 源码树构建（`ohos_app("dlp_manager")`，ets2abc=true，签名 `signature/dlpmanager.p7b`，安装目录 `app/com.ohos.dlpmanager`）。
- `coverage-filter.json5`：测试覆盖率过滤（排除 Ability/Application/cleanDlpCache/common/components/encryptionComponents/pages）。

### 按任务类型定位代码

| 任务类型　　　　　　　　　　　　　 | 先看　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 |
| ----------------------------------| -------------------------------------------------------------------------------------------------------------------------------- |
| 修改主入口/路由（加密保护/改密/权限状态） | `entry/src/main/ets/Ability/MainAbilityEx.ets`（按 want 参数路由到 `pages/encryptionProtection`/`changeEncryption`/`permissionStatus`） |
| 修改加密保护 UI　　　　　　　　　 | `entry/src/main/ets/pages/encryptionProtection.ets`（@Entry @Component，主加密 UI）+ `component/encryptionComponents/`（`AddStaff`、`encrypting`、`permission_type_select`、`staff`、`dlp_alert_dialog`）+ `component/helper/EncryptProtectionHelper.ets` |
| 修改改密 UI　　　　　　　　　　　 | `entry/src/main/ets/pages/changeEncryption.ets` + `component/helper/EncryptProtectionHelper.ets` |
| 修改权限状态 UI　　　　　　　　　 | `entry/src/main/ets/pages/permissionStatus.ets` |
| 修改加密分享　　　　　　　　　　　 | `entry/src/main/ets/Ability/EncryptedSharingAbility.ets`（ActionExtensionAbility）+ `pages/encryptedSharing.ets` + `component/helper/EncryptSharingHelper.ets` + `validator/UriValidator.ets`（职责链 URI 校验） |
| 修改 DLP 文件 RPC 服务（生成/打开/关闭/恢复/Fuse） | `entry/src/main/ets/Ability/DlpFileProcessAbility.ets`（含 `DlpRpcServiceStub`：`genDlpFile`/`openDlpFile`/`closeDlpFile`/`recoverDlpFile`/`stopFuseLink`/`resumeFuseLink`/`sandBoxLinkFile`）+ `Ability/data/IIdlDlpRpcServiceTs/`（IDL 生成 Proxy/Stub） |
| 修改 DLP 文件打开/解密引擎　　　 | `entry/src/main/ets/OpenDlpFile/`：`ViewProcessor/ViewProcessor.ets`（`OpenDlpFileProcessor` 编排）+ `manager/`（11 个 manager）+ `handler/`（`AccountHandler`/`FileIdHandler`/`FileParseHandler` 工厂）+ `data/`（`DecryptContent`/`OpenDlpFileData`）+ `common/`（`DlpFileOpenReport`/`OpenDlpFileError`） |
| 修改 DLP 文件查看 Ability　　　　 | `entry/src/main/ets/Ability/ViewAbility.ets`（ServiceExtensionAbility，调度 `OpenDlpFileProcessor`）+ `rpc/ViewAbility/service/ViewAbilityService.ets` + `rpc/ViewAbility/stub/ViewAbilityStub.ets` |
| 修改凭证服务连接　　　　　　　　　 | `entry/src/main/ets/rpc/CredConnectService.ets`、`CredConnectServiceDomain.ets`、`CredConnectServiceFileId.ets`（三路连接）+ `rpc/CredCallbackStub.ets` |
| 修改账号管理/查询　　　　　　　　 | `entry/src/main/ets/manager/AccountManager.ets`（连接 DlpCredMgr RPC）+ `manager/AccountAssociationManager.ets` + `service/AccountAssociationService.ets` + `convertor/AccountAssociationConvertor.ets` + `utils/AccountAssociationUtil.ets` + `validator/AccountAssociation/` |
| 修改对话框 UI（告警/打开中/手机） | `entry/src/main/ets/Ability/DialogUIExtAbility.ets`/`OpeningDialogUIExtAbility.ets`/`PhoneDialogUIExtAbility.ets` + `pages/alert.ets`/`OpeningDialog.ets`/`PhoneDialog.ets` + `OpenDlpFile/manager/AlertManager.ets`/`OpeningDialogManager.ets` |
| 修改缓存清理　　　　　　　　　　　 | `entry/src/main/ets/Ability/ClearDlpCacheAbility.ets` + `cleanDlpCache/cleanDlpFileInCache.ets` + `rpc/ClearDlpCache/ClearDlpCacheStub.ets` |
| 修改历史监控　　　　　　　　　　　 | `entry/src/main/ets/Ability/DataAbility.ets`（ServiceExtensionAbility） |
| 修改 HUKS 加解密适配　　　　　　 | `entry/src/main/ets/utils/HuksCipherUtil.ets` + `common/config/HuksProperties.ets` |
| 修改文件工具/文件系统操作　　　 | `entry/src/main/ets/utils/FileUtils.ets`（匿名化、后缀解析）、`FsUtil.ets`（文件系统封装）、`SupportTypesUtil.ets`（支持文件类型） |
| 修改公共常量/枚举/AppStorage key | `entry/src/main/ets/common/constants/constant.ets`（中心常量类）、`AppStorageConstant.ets`、`common/enum/`（`FileEnum`/`MaterialEnum`/`EncryptProtectionShowCodeEnum`/`EncryptSharingShowCodeEnum`） |
| 修改日志/全局上下文/单例基础设施 | `entry/src/main/ets/common/base/HiLog.ts`（hilog 域 0xf888 tag DLPManager）、`GlobalContext.ts`（globalThis store/load）、`Singleton.ets`、`CounterLock.ets`、`Result.ets`/`ResultMsg.ets` |
| 修改 IPC 数据模型/序列化　　　　 | `entry/src/main/ets/common/bean/data/dlpClass.ets`（`IDLDLPProperty` + `IAuthUser` 扩展 `rpc.MessageSequence`）+ `bean/data/`（`FileMetaInfo`/`FileParseInfo`/`AuthorizedAccount`/`AccountAssociation`/`DlpFileCreateReportInfo`）+ `bean/request/` + `bean/response/` |
| 修改上报/遥测　　　　　　　　　　 | `entry/src/main/ets/utils/ReportSecurityEventUtil.ets`、`ReportToBigDataUtil.ets`、`DlpFileCreateReport.ets` + `OpenDlpFile/common/DlpFileOpenReport.ets`/`DlpFileOpenReportUtils.ets` |
| 修改权限状态通知/公共事件　　　 | `entry/src/main/ets/manager/PermStatusNotifyManager.ets`、`CommonEventManager.ets`、`UIContextManager.ets` |
| 修改模块声明/权限/ExtensionAbility | `entry/src/main/module.json`（8 个 ExtensionAbility、10 个权限、deviceTypes、metadata） |
| 修改 App 级配置　　　　　　　　　 | `AppScope/app.json`（bundleName、versionCode、icon、label、configuration） + `AppScope/resources/`（app_name、app_icon、configuration） |
| 修改页面路由声明　　　　　　　　　 | `entry/src/main/resources/base/profile/main_pages.json`（8 个页面路由） |
| 修改字符串/媒体资源　　　　　　　 | `entry/src/main/resources/base/element/string.json`（120+ 字符串）、`base/media/`（15 个媒体）、`dark/element/`（暗色模式）、23 个语言目录 + `rawfile/account_tips.json` |
| 修改构建/部件声明　　　　　　　　 | `bundle.json`、`BUILD.gn`、`build-profile.json5`、`oh-package.json5`、`hvigorfile.js`、`entry/hvigorfile.js` |
| 修改测试覆盖率过滤　　　　　　　 | `coverage-filter.json5`（排除 Ability/Application/cleanDlpCache/common/components/encryptionComponents/pages） |
| 修改单元测试　　　　　　　　　　　 | `entry/src/ohosTest/test/`（按源码模块分组：`bean/`、`common/`、`component/`、`convertor/`、`manager/`、`openDlpFile/`、`rpc/`、`service/`、`validator/`）+ `test/List.test.ets`（聚合入口） |

### 嵌套指引

本仓库无目录级别的嵌套指引。所有任务级指导通过本文件和源码中的注释提供。

## 知识索引

### 词汇型路由

当任务描述、issue、日志、API 或文件中出现以下术语时，先读对应文件再动手。
源码路径以 `entry/src/main/ets/` 为根，省略前缀。

#### 加密保护主流程

共享链路：第三方应用 `startAbility`（bundleName `com.ohos.dlpmanager`，abilityName `MainAbilityEx`）→ `Ability/MainAbilityEx.ets`（按 want 参数路由）→ `pages/encryptionProtection.ets`（@Entry UI）→ `component/encryptionComponents/`（人员/权限/进度组件）→ `component/helper/EncryptProtectionHelper.ets` → RPC `Ability/DlpFileProcessAbility.ets`（`DlpRpcServiceStub.genDlpFile`）→ `@ohos.dlpPermission` SDK → SA 3521 `security_dlp_permission_service`

| 领域术语 | 实现位置 |
| --- | --- |
| MainAbilityEx / 主入口 | `Ability/MainAbilityEx.ets`（UIExtensionAbility，exported=true，metadata `ohos.extension.servicetype=share`） |
| 加密保护 / encryptionProtection | `pages/encryptionProtection.ets`（@Entry @Component，主加密 UI，1000+ 行） |
| 改密 / changeEncryption | `pages/changeEncryption.ets` |
| 权限状态 / permissionStatus | `pages/permissionStatus.ets` |
| 加密成功 / encryptionSuccess | `pages/encryptionSuccess.ets` |
| 加密组件 / AddStaff / staff / encrypting | `component/encryptionComponents/AddStaff.ets`、`staff.ets`、`encrypting.ets`、`permission_type_select.ets`、`dlp_alert_dialog.ets` |
| EncryptProtectionHelper | `component/helper/EncryptProtectionHelper.ets` |

#### DLP 文件打开/解密引擎

共享链路：系统拉起 `Ability/ViewAbility.ets`（ServiceExtensionAbility）→ `OpenDlpFile/ViewProcessor/ViewProcessor.ets`（`OpenDlpFileProcessor.process()`）→ `OpenDlpFile/handler/`（`FileParseHandler` 工厂 + `AccountHandler` + `FileIdHandler`）→ `OpenDlpFile/manager/DecryptManager.ets` → `@ohos.dlpPermission` SDK 解密 → `OpenDlpFile/manager/SandboxManager.ets` 沙箱 → `OpenDlpFile/manager/StartFileManager.ets` 拉起目标应用

| 领域术语 | 实现位置 |
| --- | --- |
| ViewAbility / 查看 Ability | `Ability/ViewAbility.ets` + `rpc/ViewAbility/service/ViewAbilityService.ets` + `rpc/ViewAbility/stub/ViewAbilityStub.ets` |
| OpenDlpFileProcessor / 打开编排 | `OpenDlpFile/ViewProcessor/ViewProcessor.ets` |
| OpenDlpFileManager / 打开管理器 | `OpenDlpFile/manager/OpenDlpFileManager.ets`（单例 + AsyncLock 管理解密状态/内容映射） |
| DecryptManager / 解密管理 | `OpenDlpFile/manager/DecryptManager.ets` |
| SandboxManager / 沙箱管理 | `OpenDlpFile/manager/SandboxManager.ets` |
| FileParseHandler / 文件解析 | `OpenDlpFile/handler/FileParseHandler.ets`（工厂模式）+ `OpenDlpFile/handler/AccountHandler.ets`、`FileIdHandler.ets` |
| DecryptContent / 解密内容 | `OpenDlpFile/data/DecryptContent.ets` |
| OpenDlpFileData / 打开数据 | `OpenDlpFile/data/OpenDlpFileData.ets` |
| 打开遥测 / DlpFileOpenReport | `OpenDlpFile/common/DlpFileOpenReport.ets`、`DlpFileOpenReportUtils.ets` |
| 打开错误 / OpenDlpFileError | `OpenDlpFile/common/OpenDlpFileError/OpenDlpFileError.ets` |
| 终止/清理 / TerminateManager | `OpenDlpFile/manager/TerminateManager.ets`、`DataManager.ets` |
| 打开对话框 / OpeningDialogManager | `OpenDlpFile/manager/OpeningDialogManager.ets` + `Ability/OpeningDialogUIExtAbility.ets` + `pages/OpeningDialog.ets` |
| 告警 / AlertManager | `OpenDlpFile/manager/AlertManager.ets` + `Ability/DialogUIExtAbility.ets` + `pages/alert.ets` |
| 效率应用 / ApplyEfficiencyManager | `OpenDlpFile/manager/ApplyEfficiencyManager.ets` |
| 启动文件 / StartFileManager | `OpenDlpFile/manager/StartFileManager.ets` |

#### DLP 文件 RPC 服务

共享链路：客户端 `Ability/data/IIdlDlpRpcServiceTs/id_dlpRpc_service_proxy.ets`（IDL 生成 Proxy）→ IPC → `Ability/DlpFileProcessAbility.ets`（`DlpRpcServiceStub` 实现）→ 调用 `@ohos.dlpPermission` SDK → SA 3521

| 领域术语 | 实现位置 |
| --- | --- |
| DlpFileProcessAbility / DLP 文件 RPC 服务 | `Ability/DlpFileProcessAbility.ets`（ServiceExtensionAbility） |
| DlpRpcServiceStub / RPC Stub | `Ability/DlpFileProcessAbility.ets` 内 `DlpRpcServiceStub` 类（实现 `genDlpFile`/`openDlpFile`/`closeDlpFile`/`recoverDlpFile`/`stopFuseLink`/`resumeFuseLink`/`sandBoxLinkFile`） |
| IDL Proxy / Stub 生成 | `Ability/data/IIdlDlpRpcServiceTs/id_dlpRpc_service_proxy.ets`、`id_dlpRpc_service_stub.ets`、`i_id_dlpRpc_service.ets`（IDL 生成，禁止手改） |
| genDlpFile / 生成 DLP 文件 | `DlpFileProcessAbility.ets` 中 `DlpRpcServiceStub.genDlpFile` |
| openDlpFile / 打开 DLP 文件 | `DlpFileProcessAbility.ets` 中 `DlpRpcServiceStub.openDlpFile` |
| closeDlpFile / 关闭 DLP 文件 | `DlpFileProcessAbility.ets` 中 `DlpRpcServiceStub.closeDlpFile` |
| recoverDlpFile / 恢复 DLP 文件 | `DlpFileProcessAbility.ets` 中 `DlpRpcServiceStub.recoverDlpFile` |
| stopFuseLink / resumeFuseLink | `DlpFileProcessAbility.ets` 中 `DlpRpcServiceStub` |
| sandBoxLinkFile / 沙箱链接文件 | `DlpFileProcessAbility.ets` 中 `DlpRpcServiceStub.sandBoxLinkFile` |

#### 凭证服务连接

共享链路：`rpc/CredConnectService.ets`（ConnectOptions）→ 远程 DlpCredMgr Service → `rpc/CredCallbackStub.ets` 回调

| 领域术语 | 实现位置 |
| --- | --- |
| CredConnectService / 凭证连接 | `rpc/CredConnectService.ets`（3 个 ConnectOptions） |
| 域账号凭证连接 | `rpc/CredConnectServiceDomain.ets` |
| FileId 凭证连接 | `rpc/CredConnectServiceFileId.ets` |
| CredCallbackStub / 凭证回调 | `rpc/CredCallbackStub.ets` |
| DlpPermissionAbilityServiceStub | `rpc/DlpPermissionAbilityServiceStub.ets` |

#### 账号管理与关联

共享链路：`manager/AccountManager.ets`（连接 DlpCredMgr RPC 查询账号）→ `service/AccountAssociationService.ets` → `convertor/AccountAssociationConvertor.ets` → `validator/AccountAssociation/AssociationEncryptValidator.ets`/`AssociationDecryptValidator.ets` → `utils/AccountAssociationUtil.ets`

| 领域术语 | 实现位置 |
| --- | --- |
| AccountManager / 账号管理 | `manager/AccountManager.ets` |
| AccountAssociationManager / 账号关联 | `manager/AccountAssociationManager.ets` |
| AccountAssociationService / 关联服务 | `service/AccountAssociationService.ets` |
| AccountAssociationConvertor / 关联转换 | `convertor/AccountAssociationConvertor.ets` |
| AssociationEncryptValidator / 加密校验 | `validator/AccountAssociation/AssociationEncryptValidator.ets` |
| AssociationDecryptValidator / 解密校验 | `validator/AccountAssociation/AssociationDecryptValidator.ets` |
| AccountAssociationUtil | `utils/AccountAssociationUtil.ets` |
| AccountTipsConfigUtil / 账号提示 | `utils/AccountTipsConfigUtil.ets` + `resources/base/rawfile/account_tips.json` |
| AuthorizedAccount / 授权账号 | `common/bean/data/AuthorizedAccount.ets` |
| AccountAssociation / 账号关联模型 | `common/bean/data/AccountAssociation.ets` |
| 域账号检查 / checkDomainAccountInfo | `utils/utils.ets`（`getOsAccountInfo`、`checkDomainAccountInfo`） |
| 系统账号 / getOsAccountInfo | `utils/utils.ets` |

#### 加密分享

共享链路：`Ability/EncryptedSharingAbility.ets`（ActionExtensionAbility，exported=true）→ `validator/UriValidator.ets`（职责链 URI 校验）→ `component/helper/EncryptSharingHelper.ets` → `pages/encryptedSharing.ets`

| 领域术语 | 实现位置 |
| --- | --- |
| EncryptedSharingAbility / 加密分享 | `Ability/EncryptedSharingAbility.ets`（ActionExtensionAbility） |
| encryptedSharing / 分享页 | `pages/encryptedSharing.ets` |
| EncryptSharingHelper / 分享助手 | `component/helper/EncryptSharingHelper.ets` |
| UriValidator / URI 校验链 | `validator/UriValidator.ets`（`BaseValidator` 抽象 + `setNext`/`handle` 职责链） |
| EncryptSharingShowCodeEnum | `common/enum/EncryptSharingShowCodeEnum.ets` |

#### IPC 数据模型

| 领域术语 | 实现位置 |
| --- | --- |
| dlpClass / IDLDLPProperty / IAuthUser | `common/bean/data/dlpClass.ets`（扩展 `rpc.MessageSequence` 用于 IPC 序列化） |
| FileMetaInfo / 文件元信息 | `common/bean/data/FileMetaInfo.ets` |
| FileParseInfo / 解析信息 | `common/bean/data/FileParseInfo.ets` |
| DlpFileCreateReportInfo / 上报信息 | `common/bean/data/DlpFileCreateReportInfo.ets` |
| 请求 DTO | `common/bean/request/` |
| 响应 DTO | `common/bean/response/` |

#### HUKS 与加解密

| 领域术语 | 实现位置 |
| --- | --- |
| HuksCipherUtil / HUKS 加解密 | `utils/HuksCipherUtil.ets`（本仓通过此层调用 HUKS，不直接使用密钥） |
| HuksProperties / HUKS 配置 | `common/config/HuksProperties.ets` |

#### 公共基础设施

| 领域术语 | 实现位置 |
| --- | --- |
| HiLog / 日志 | `common/base/HiLog.ts`（hilog 域 0xf888，tag DLPManager） |
| GlobalContext / 全局上下文 | `common/base/GlobalContext.ts`（基于 globalThis store/load） |
| Singleton / 单例 | `common/base/Singleton.ets`（泛型 `Singleton<T>` 工厂单例） |
| CounterLock / 计数锁 | `common/base/CounterLock.ets` |
| Result / 结果 | `common/base/Result.ets`（`{ errcode, errmsg?, result? }`）+ `ResultMsg.ets` |
| 常量 / Constants | `common/constants/constant.ets`（中心常量类 400+ 行） |
| AppStorageConstant / AppStorage key | `common/constants/AppStorageConstant.ets` |
| FileEnum / 文件枚举 | `common/enum/FileEnum.ets` |
| MaterialEnum / 素材枚举 | `common/enum/MaterialEnum.ets` |
| EncryptProtectionShowCodeEnum | `common/enum/EncryptProtectionShowCodeEnum.ets` |

#### 上报与遥测

| 领域术语 | 实现位置 |
| --- | --- |
| ReportSecurityEventUtil / 安全事件上报 | `utils/ReportSecurityEventUtil.ets` |
| ReportToBigDataUtil / 大数据上报 | `utils/ReportToBigDataUtil.ets` |
| DlpFileCreateReport / 创建上报 | `utils/DlpFileCreateReport.ets` |
| DlpFileOpenReport / 打开上报 | `OpenDlpFile/common/DlpFileOpenReport.ets`、`DlpFileOpenReportUtils.ets` |

#### 配置与模块声明

| 领域术语 | 实现位置 |
| --- | --- |
| bundleName / com.ohos.dlpmanager | `AppScope/app.json`（构建时重命名 `.json5`） |
| ExtensionAbility 声明 | `entry/src/main/module.json`（8 个 ExtensionAbility，构建时重命名 `.json5`） |
| 权限声明 | `entry/src/main/module.json`（10 个 ohos.permission.*） |
| 页面路由 | `entry/src/main/resources/base/profile/main_pages.json`（8 个页面） |
| 部件声明 / @ohos/dlp_manager | `bundle.json`（version 3.1.0，subsystem applications） |
| 构建配置 / build-profile | `build-profile.json5`（compileSdkVersion 26.0.1，runtimeOS OpenHarmony） |
| 签名 / dlpmanager.p7b | `signature/dlpmanager.p7b` + `signature/dlpm.gni` |
| 字符串资源 | `entry/src/main/resources/base/element/string.json`（120+ 字符串）+ 23 个语言目录 |
| 账号提示配置 | `entry/src/main/resources/base/rawfile/account_tips.json` |
| 测试覆盖率过滤 | `coverage-filter.json5`（排除 UI/Ability 层） |

### 任务型路由

当任务涉及多个"按任务类型定位代码"表中的类型时，按下表确定依次涉及的类型和顺序：

| 任务场景 | 依次涉及的任务类型 |
| --- | --- |
| 新增一个 DLP 文件 RPC 方法（含 UI 调用） | 修改 IDL（`Ability/data/IIdlDlpRpcServiceTs/`）→ 重新生成 Proxy/Stub → 修改 `DlpFileProcessAbility.ets` 的 `DlpRpcServiceStub` → 修改调用方 Helper/Page → 补单元测试 |
| 修改加密保护 UI 交互（人员/权限/进度） | 修改 `pages/encryptionProtection.ets` → 修改 `component/encryptionComponents/` → 修改 `component/helper/EncryptProtectionHelper.ets` → 修改 `common/constants/constant.ets`（如新增 UI 常量）→ 修改字符串资源 |
| 修改 DLP 文件打开流程（解密/沙箱/拉起） | 修改 `Ability/ViewAbility.ets` → 修改 `OpenDlpFile/ViewProcessor/ViewProcessor.ets` → 修改 `OpenDlpFile/manager/` → 修改 `OpenDlpFile/handler/` → 修改 `OpenDlpFile/data/` → 修改单元测试 `openDlpFile/` |
| 修改加密分享流程 | 修改 `Ability/EncryptedSharingAbility.ets` → 修改 `validator/UriValidator.ets` → 修改 `component/helper/EncryptSharingHelper.ets` → 修改 `pages/encryptedSharing.ets` |
| 修改账号关联/校验 | 修改 `manager/AccountManager.ets`/`AccountAssociationManager.ets` → 修改 `service/AccountAssociationService.ets` → 修改 `convertor/AccountAssociationConvertor.ets` → 修改 `validator/AccountAssociation/` → 修改 `utils/AccountAssociationUtil.ets` → 修改单元测试 |
| 修改凭证服务连接 | 修改 `rpc/CredConnectService*.ets` → 修改 `rpc/CredCallbackStub.ets` → 评估对 `manager/AccountManager.ets` 的影响 |
| 新增/修改 ExtensionAbility | 修改 `Ability/XxxAbility.ets` → 修改 `entry/src/main/module.json`（声明 ExtensionAbility）→ 修改权限声明（如需）→ 修改 `Ability/Application/AbilityStage.ets`（如需初始化） |
| 修改上报/遥测 | 修改 `utils/ReportSecurityEventUtil.ets`/`ReportToBigDataUtil.ets`/`DlpFileCreateReport.ets` → 修改 `OpenDlpFile/common/DlpFileOpenReport*.ets` → 评估 HiSysEvent 上报时机 |
| 修改 HUKS 加解密适配 | 修改 `utils/HuksCipherUtil.ets` → 修改 `common/config/HuksProperties.ets` → 评估对 `OpenDlpFile/manager/DecryptManager.ets` 的影响 |
| 修改公共常量/枚举 | 修改 `common/constants/constant.ets`/`AppStorageConstant.ets` → 修改 `common/enum/` → 评估所有引用点 |
| 修改国际化字符串 | 修改 `entry/src/main/resources/base/element/string.json` → 同步 23 个语言目录的 `element/string.json` → 评估 `$r()` 引用 |

通用规则：
- 修改 IDL：改 `Ability/data/IIdlDlpRpcServiceTs/` 中的 IDL 源 → 重新生成 Proxy/Stub → 客户端、Stub、服务侧成对修改并核对全部调用点 → 修改单元测试
- 修改公共 UI 组件：评估对所有 pages 和 component 的影响，做 ArkTS 兼容性评估
- 修改 ExtensionAbility 声明：`module.json` 与 `Ability/*.ets` 必须同步，权限声明必须匹配
- 修改 IPC 数据模型：`dlpClass.ets` 中 `rpc.MessageSequence` 序列化/反序列化必须成对，评估跨进程兼容性

### 开始编辑前

在修改代码前，按以下顺序确认：
1. 确认任务类别（主入口路由 / 加密保护 UI / 改密 UI / 权限状态 UI / DLP 文件 RPC 服务 / 打开引擎 / 查看 Ability / 凭证连接 / 账号管理 / 加密分享 / 对话框 / 缓存清理 / 历史监控 / HUKS 适配 / 文件工具 / 公共常量 / IPC 数据模型 / 上报遥测 / 模块声明 / 构建配置 / 测试）
2. 根据上表确定需要阅读的源码文件与配置
3. 根据"项目约束"确认不违反任何约束
4. 声明："将修改 X，已阅读 Y 文档，遵循 Z 约束"

## 构建和验证

### 构建方式 1 - 基于 OpenHarmony 项目构建
构建命令从 OpenHarmony 源码根目录执行，不在本子目录执行。

```sh
# 构建整个 DLP 管理应用 HAP
./build.sh --product-name rk3568 --build-target dlp_manager --ccache

# 构建并运行单元测试
./build.sh --product-name rk3568 --build-target dlp_manager_test
```

部件目标：`ohos_app("dlp_manager")`，ets2abc=true，签名 `signature/dlpmanager.p7b`，安装目录 `app/com.ohos.dlpmanager`。

### 构建方式 2 - DevEco Studio 构建

使用 DevEco Studio 打开本仓库目录，配置 SDK 版本为 compileSdkVersion 26.0.1、compatibleSdkVersion 26.0.0、runtimeOS OpenHarmony，执行 Build → Build Hap(s)/APP(s)。

注意：构建前需将 `AppScope/app.json` 重命名为 `app.json5`，将 `entry/src/main/module.json` 重命名为 `module.json5`。安装前需卸载预装的 DLP Manager。

### 静态检查
修改 ArkTS/TS 文件后，执行本地代码检查，确认无新增告警再提交。

检查命令从 OpenHarmony 源码根目录执行，不在本子目录执行。
```sh
# 方式 1 - 构建时 ets2abc 类型检查（CI 可脚本化）
./build.sh --product-name rk3568 --build-target dlp_manager --gn-args enable_ets_static_check=true

# 方式 2 - DevEco Studio Code Linter（GUI 交互式）
# 在 DevEco Studio 中右键工程 → Code Linter → Run
```
> ArkTS 类型检查由 ets2abc 编译器在构建时自动执行；`enable_ets_static_check=true` 会将类型错误提升为构建失败，适用于 CI 门禁。DevEco Studio Code Linter 提供更详细的风格规则检查，适用于本地开发。

### 关键测试目标（entry/src/ohosTest/test/）

| 测试目标 | 路径 | 覆盖 |
| --- | --- | --- |
| `BeanTest` | `test/bean/BeanTest.test.ets` | 数据模型 |
| `CommonUtilTest` | `test/common/CommonUtilTest.test.ets` | 通用工具 |
| `DlpClassTest` | `test/common/DlpClassTest.test.ets` | `dlpClass.ets` IPC 序列化 |
| `SystemUtilsTest` | `test/common/SystemUtilsTest.test.ets` | 系统工具 |
| `SupportedTypesCfgTest` | `test/common/SupportedTypesCfgTest.test.ets` | 支持文件类型配置 |
| `AccountAssociationUtilTest` | `test/common/AccountAssociationUtilTest.test.ets` | 账号关联工具 |
| `DLPMaterialUtilTest` | `test/common/DLPMaterialUtilTest.test.ets` | 素材工具 |
| `GetAlertMessageTest` | `test/common/AlertMessage/GetAlertMessageTest.test.ets` | 告警消息解析 |
| `FileUtilsTest` | `test/common/FileUtils/FileUtilsTest.test.ets` | 文件工具 |
| `UtilsTest` | `test/common/FileUtils/UtilsTest.test.ets` | 通用工具 |
| `FileUtilTest` | `test/common/external/FileUtilTest.test.ets` | 外部文件工具 |
| `HuksCipherUtilTest` | `test/common/huks/HuksCipherUtilTest.test.ets` | HUKS 加解密 |
| `ComponentTest` | `test/component/ComponentTest.test.ets` | UI 组件 |
| `AssocConvertorTest` | `test/convertor/AssocConvertorTest.test.ets` | 账号关联转换器 |
| `DomainAccountConvertorTest` | `test/convertor/DomainAccountConvertorTest.test.ets` | 域账号转换器 |
| `AccountManagerTest` | `test/manager/AccountManagerTest.test.ets` | 账号管理器 |
| `PermStatusNotifyManagerTest` | `test/manager/PermStatusNotifyManagerTest.test.ets` | 权限状态通知 |
| `DlpFileOpenReportTest` | `test/openDlpFile/DlpFileOpenReportTest.test.ets` | 打开上报 |
| `OpenDlpFileHandlerTest` | `test/openDlpFile/OpenDlpFileHandlerTest.test.ets` | 打开 handler |
| `OpenDlpFileManagerTest` | `test/openDlpFile/OpenDlpFileManagerTest.test.ets` | 打开管理器 |
| `TerminateViewTest` | `test/openDlpFile/TerminateViewTest.test.ets` | 终止/清理 |
| `ViewProcessorTest` | `test/openDlpFile/ViewProcessorTest.test.ets` | 打开编排 |
| `DecryptContentTest` | `test/openDlpFile/data/DecryptContentTest.test.ets` | 解密内容数据 |
| `OpenDlpFileDataTest` | `test/openDlpFile/data/OpenDlpFileDataTest.test.ets` | 打开数据载体 |
| `RawParseTest` | `test/openDlpFile/handler/RawParseTest.test.ets` | 文件解析 |
| `ServiceTest` | `test/rpc/ServiceTest.test.ets` | RPC 服务 |
| `StubTest` | `test/rpc/StubTest.test.ets` | RPC Stub |
| `AssocServiceTest` | `test/service/AssocServiceTest.test.ets` | 关联服务 |
| `AssocValidatorTest` | `test/validator/AssocValidatorTest.test.ets` | 关联校验器 |
| `UriValidatorTest` | `test/validator/UriValidatorTest.test.ets` | URI 校验链 |

测试聚合入口：`test/List.test.ets`（`export default function testsuite()` 导入并调用全部测试套件）。

### 测试覆盖率配置（coverage-filter.json5）

测试覆盖率统计排除以下目录（聚焦逻辑层）：
- `**/Ability/**`（Ability 声明层）
- `**/Application/**`（应用生命周期）
- `**/cleanDlpCache/**`（缓存清理）
- `**/common/components/**`、`**/encryptionComponents/**`（UI 组件）
- `**/pages/**`（页面 UI）

### 完成标准

任务被认为完成，当且仅当：

1. **代码改动已提交** - 使用 `git commit -s`，多代理协作时添加 `Co-Authored-By: Agent`
2. **本地构建通过** - 执行上述构建命令，至少 `dlp_manager` HAP 构建通过
3. **相关测试通过** - 按改动区域选择对应测试目标（改 RPC 跑 `ServiceTest` + `StubTest`；改打开引擎跑 `ViewProcessorTest` + `OpenDlpFileManagerTest` + `OpenDlpFileHandlerTest`；改 HUKS 跑 `HuksCipherUtilTest`；改账号管理跑 `AccountManagerTest` + `AssocConvertorTest` + `AssocValidatorTest`；改 URI 校验跑 `UriValidatorTest`；改 IPC 数据模型跑 `DlpClassTest`；改 UI 组件跑 `ComponentTest` + 全量回归）
4. **module.json 与 Ability 同步** - 新增/删除/修改 ExtensionAbility 必须同步 `entry/src/main/module.json` 声明
5. **资源同步** - 新增/修改字符串必须同步 `base/element/string.json` 与 23 个语言目录；新增页面必须同步 `main_pages.json`
6. **公共 API/IPC 兼容性确认（如适用）** - 见项目约束
7. **静态检查通过** - DevEco Studio Code Linter 无新增告警
8. **板侧/真机验证（如适用）** - 涉及加密保护、DLP 文件打开、加密分享、沙箱拉起的改动需提供板侧证据（日志、HiSysEvent 输出）

### 如果无法运行验证

明确说明无法运行的原因，列出推荐的验证步骤供人工执行，标记需要人工验证的部分。若本地无 OpenHarmony 源码树，至少保证改动文件可独立编译（DevEco Studio 单文件编译）。离线环境可使用 `entry/src/ohosTest/test/manager/mock/`、`test/openDlpFile/data/mock/`、`test/openDlpFile/mock/` 中的桩构建链路验证。

### 完成报告格式

报告应包含：改动摘要（文件列表、改动点）、验证结果（构建/测试输出）、影响评估（公共 API、IPC、ExtensionAbility 声明、权限声明、资源兼容性）、风险评估（安全边界、跨账号隔离、密钥材料处理、IPC 数据完整性、性能风险）、技能加载回执（实际调用了哪些 ohos-* 技能，或声明"未加载"及原因）、未完成事项。

## 项目约束

### 性能约束

- 加密保护 UI 是用户可感知路径，不要在 `pages/encryptionProtection.ets` 的 `build()` 或 `@State` 变更回调中增加重计算或同步 IO
- DLP 文件打开/解密是用户可感知路径，`OpenDlpFileProcessor` 与 `OpenDlpFileManager` 的解密状态/内容映射操作避免长锁；`AsyncLock` 路径避免长耗时操作阻塞并发访问
- RPC 调用（`DlpRpcServiceStub`、`CredConnectService*`）避免在回调中做重计算，及时释放 `MessageSequence`

### 架构约束

- 本仓不自行签发凭证：与外部 DLP 凭证服务的交互走 `rpc/CredConnectService*.ets` + `rpc/CredCallbackStub.ets`，单元测试使用 `test/manager/mock/`、`test/openDlpFile/data/mock/`、`test/openDlpFile/mock/` 桩；不要把 mock 当线上实现
- 本仓不直接使用密钥：所有 HUKS 操作走 `utils/HuksCipherUtil.ets` + `common/config/HuksProperties.ets`，不绕过此层直接调用 HUKS
- 本仓不直接实现加解密算法：DLP 文件加解密通过 `@ohos.dlpPermission` SDK 委托 SA 3521 完成，本仓只做编排与 UI
- DLP 文件操作必须通过 RPC 走 `DlpFileProcessAbility.ets` 的 `DlpRpcServiceStub`：不要在 UI 层或 Helper 层直接调用 `@ohos.dlpPermission` SDK 绕过 RPC 服务
- ExtensionAbility 类型边界保持显式：`sys/commonUI`（UI 扩展，4 个）、`service`（服务扩展，3 个）、`action`（动作扩展，1 个）。不要把 service 逻辑塞进 UIExtensionAbility，也不要把 UI 逻辑塞进 ServiceExtensionAbility
- 职责链校验器（`UriValidator`）的链顺序是 URI 校验语义的一部分，修改 `setNext` 链路必须评估对所有 URI 入口的影响
- 工厂模式（`FileParseFactory`、`AccountHandlerFactory`）的新增类型必须同步注册到工厂，不要在调用方硬编码类型判断
- `GlobalContext` 基于 `globalThis`，非类型安全，新增全局状态优先考虑 `AppStorage` 或 `LocalStorage`；只有跨 Ability 共享且 AppStorage 不适用的场景才用 `GlobalContext`

### 编码约定

- 本仓库以 ArkTS（`.ets`）为主，少量 TypeScript（`.ts`，如 `HiLog.ts`、`GlobalContext.ts`）。ArkTS 改动优先复用项目内已有的组件、Helper、Manager、Util，不要引入风格不一致的实现
- 状态管理优先级：`@State`（组件局部）→ `@Link`/`@Prop`（父子绑定）→ `LocalStorage`（页面级会话）→ `AppStorage`（全局）→ `GlobalContext`（跨 Ability，非类型安全）
- 日志使用 `common/base/HiLog.ts` 中的封装，hilog 域 `0xf888`，tag `DLPManager`，不要使用 `console.log` 或 `printf` 等日志打印方式（调试除外）
- 错误返回优先使用 `common/base/Result.ets` 的 `Result<T>` 结构（`{ errcode, errmsg?, result? }`）+ `ResultMsg.ets` 构建器，不要混用原生异常与项目封装
- 常量集中管理：UI 尺寸、错误码、RPC token、超时、文件限制、want 参数放 `common/constants/constant.ets`；AppStorage key 放 `AppStorageConstant.ets`；不要在页面/组件中硬编码魔法数字或字符串
- 单例使用 `common/base/Singleton.ets` 的泛型 `Singleton<T>`（工厂函数）或手动 `static getInstance()`，不要重复实现单例模式
- ArkTS 组件使用 `@Component struct`，页面使用 `@Entry() @Component struct`，复用 UI 片段使用 `@Builder`，复用样式使用 `@Extend`
- `@State`/`@Link`/`@Prop` 装饰器的数据流方向必须严格遵守：`@State` → `@Link`（双向）或 `@Prop`（单向），不要通过全局变量绕过状态管理
- 异步优先使用 Promise，RPC 回调使用 callback（与 OpenHarmony RPC API 一致），不要混用
- 文件命名：类文件 PascalCase（`AccountManager.ets`），页面文件 camelCase（`encryptionProtection.ets`），工具文件 camelCase（`utils.ets`）
- TAG 常量：每个文件顶部声明 `const TAG = 'Xxx'`，用于日志标识

### 公共 API 约束

**Do not（禁止）：**
- 修改 `Ability/data/IIdlDlpRpcServiceTs/` 中 IDL 生成的 Proxy/Stub 代码（`id_dlpRpc_service_proxy.ets`、`id_dlpRpc_service_stub.ets`、`i_id_dlpRpc_service.ets`）——改 IDL 源后重新生成
- 修改 `DlpRpcServiceStub` 已发布的 RPC 方法签名（`genDlpFile`/`openDlpFile`/`closeDlpFile`/`recoverDlpFile`/`stopFuseLink`/`resumeFuseLink`/`sandBoxLinkFile`）
- 修改 `common/bean/data/dlpClass.ets` 中 `IDLDLPProperty`/`IAuthUser` 的 `rpc.MessageSequence` 序列化/反序列化字段顺序
- 修改 `bundle.json` 中部件名 `@ohos/dlp_manager` 或 `AppScope/app.json` 中 bundleName `com.ohos.dlpmanager`
- 修改 `entry/src/main/module.json` 中已发布的 ExtensionAbility 的 name/type/srcEntry/exported
- 删除或重命名已发布的 ExtensionAbility
- 修改已声明权限的名称

**Ask before（修改前必须确认）：**
- 新增 ExtensionAbility：确认 type、exported、权限、metadata 是否匹配
- 新增 RPC 方法：确认 IDL 重新生成、Stub 实现、Proxy 调用、单元测试成对
- 新增公共常量：确认归属 `constant.ets` 还是 `AppStorageConstant.ets`
- 新增 IPC 数据模型字段：确认 `MessageSequence` 序列化兼容性
- 修改权限声明：确认对应 ExtensionAbility 真正使用该权限

### 安全与权限边界

**Do not（禁止）：**
- 绕过 `validator/UriValidator.ets` 的 URI 校验链直接处理外部传入的 URI
- 绕过 `validator/AccountAssociation/` 的账号关联校验直接进行加密/解密
- 绕过 `manager/AccountManager.ets` 的账号查询直接调用 DlpCredMgr RPC
- 关闭或弱化 ExtensionAbility 的 exported 限制（`MainAbilityEx` 和 `EncryptedSharingAbility` 为 exported=true，其余为 false）
- 在未校验的情况下直接使用跨进程传递的 URI、文件路径、Parcel 数据或字符串入参
- 将密钥明文、密钥材料、证书内容、口令等敏感信息写入非安全日志或 HiSysEvent
- 在 `pages/` 或 `component/` 中直接调用 HUKS 或 `@ohos.dlpPermission` SDK，必须通过 `utils/HuksCipherUtil.ets` 或 RPC 服务
- 修改 `entry/src/main/module.json` 中已声明的 10 个权限的授予方式（`ohos.permission.ACCESS_DLP_FILE`、`GET_LOCAL_ACCOUNTS`、`START_ABILITIES_FROM_BACKGROUND`、`GET_BUNDLE_INFO`、`GET_NETWORK_INFO`、`START_DLP_CRED`、`START_SYSTEM_DIALOG`、`EXEMPT_PRIVACY_SECURITY_CENTER`、`REPORT_SECURITY_EVENT`、`FILE_ACCESS_MANAGER`）

**Ask before（修改前必须确认）：**
- 涉及 `validator/UriValidator.ets` 校验链顺序改动
- 涉及 `validator/AccountAssociation/` 校验逻辑改动
- 涉及 `manager/AccountManager.ets` 账号查询逻辑改动
- 涉及 HUKS 适配层（`utils/HuksCipherUtil.ets`、`common/config/HuksProperties.ets`）改动
- 涉及密钥材料处理（加解密、证书解析）改动
- 涉及 `rpc/CredConnectService*.ets` 凭证服务连接逻辑改动
- 涉及 `DlpRpcServiceStub` RPC 方法实现改动
- 修改 `entry/src/main/module.json` 权限声明
- 修改 ExtensionAbility 的 exported 属性

### 协议与数据格式兼容性

**Do not（禁止）：**
- 修改 IDL 生成代码（`Ability/data/IIdlDlpRpcServiceTs/` 中的 Proxy/Stub）——改 IDL 源后重新生成
- 修改 `common/bean/data/dlpClass.ets` 中 `rpc.MessageSequence` 的读写顺序或字段布局
- 修改 `DlpRpcServiceStub` 已发布 RPC 方法的参数顺序或返回值结构
- 修改 `main_pages.json` 中已发布页面的路由名
- 修改 `entry/src/main/resources/base/element/string.json` 中已发布字符串的 key
- 修改 `AppScope/app.json` 中 bundleName/versionCode/versionName 不评估升级兼容性
- 修改 `entry/src/main/module.json` 中 ExtensionAbility 的 name/type/srcEntry

**Ask before（修改前必须确认）：**
- 修改 IPC 数据模型字段（`dlpClass.ets`、`FileMetaInfo`、`FileParseInfo` 等）
- 修改 RPC 方法参数或返回值结构
- 修改 `main_pages.json` 新增/删除页面
- 修改字符串 key（需同步 23 个语言目录）

### 生成代码边界

**Do not（禁止）：**
- 手动编辑 IDL 编译器生成的 RPC Proxy/Stub 代码（`Ability/data/IIdlDlpRpcServiceTs/` 中由 IDL 生成部分）

**正确做法：**
- 修改 IDL 源文件后重新运行 IDL 编译器生成 Proxy/Stub
- 客户端（Proxy 调用方）、Stub（`DlpFileProcessAbility.ets`）、服务侧成对修改并核对全部调用点
- 同步修改单元测试（`test/rpc/ServiceTest.test.ets`、`StubTest.test.ets`）

### 第三方依赖

**Do not（禁止）：**
- 新增第三方依赖——必须先经 `oh-package.json5` 声明与 License 审查

**Ask before（修改前必须确认）：**
- 修改 `oh-package.json5` 中 `devDependencies`
- 修改 `bundle.json` 中 `deps`

### 设备操作约束

**涉及真实设备时的注意事项：**
- 不执行可能影响沙箱目录、DLP 缓存、已安装 DLP 文件的破坏性操作（如批量清理缓存、卸载 DLP Manager）
- 涉及加密保护、DLP 文件打开、加密分享、沙箱拉起的改动必须提供板侧证据（日志、HiSysEvent 输出）
- 涉及 HUKS 集成的改动需在支持 HUKS 的设备上验证
- 安装新版 DLP Manager 前需卸载预装版本

## 关键风险总结

改动前自检是否触及以下高风险项之一，若触及则升级评审：

1. **IDL 生成代码 / RPC 方法签名 / `MessageSequence` 序列化顺序** → 跨进程兼容破坏
2. **ExtensionAbility 声明（`module.json` name/type/srcEntry/exported）** → 系统拉起失败或能力丢失
3. **bundleName / 部件名 / 权限声明** → 系统识别失败或越权
4. **`UriValidator` 校验链顺序** → 外部 URI 越权访问
5. **`AccountAssociation` 校验逻辑 / `AccountManager` 账号查询** → 账号越权或错乱
6. **HUKS 适配层（`HuksCipherUtil` / `HuksProperties`）** → 密钥泄露或密码学正确性问题
7. **`DlpRpcServiceStub` RPC 方法实现** → DLP 文件操作越权或数据损坏
8. **`OpenDlpFileManager` 解密状态/内容映射 / `AsyncLock` 一致性** → 解密错乱、并发竞态
9. **`GlobalContext`（globalThis）中存储敏感信息** → 信息泄露（非类型安全）
10. **`main_pages.json` 页面路由 / `string.json` 字符串 key** → UI 路由失败或显示异常
11. **`AppScope/app.json` bundleName/versionCode/versionName** → 升级兼容性破坏
12. **23 个语言目录字符串同步** → 国际化缺失
