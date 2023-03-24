import { Header } from '../common/components/header'
import { PermissionPanel } from '../common/components/permission_panel'
import { AuthorizerPanel } from '../common/components/authorizer_panel'
import { ProcessingPanel } from '../common/components/processing_panel';
import { Footer } from '../common/components/footer'
import dlpPermission from '@ohos.dlpPermission'
import fileio from '@ohos.fileio';
import bundleManager from '@ohos.bundle.bundleManager'
import { getAuthPerm, getAlertMessage } from '../common/utils'
import { DlpAlertDialog } from '../common/components/dlp_alert_dialog'
import { KeyCode } from '@ohos.multimodalInput.keyCode'
import { getOsAccountInfo, terminateSelfWithResult } from '../common/utils'
import Constants from '../common/constant'

var TAG = "[DLPManager_index]"

var defaultDlpProperty: dlpPermission.DlpProperty = {
  ownerAccount: '',
  ownerAccountType: 1,
  authUsers: [],
  contractAccount: '',
  offlineAccess: true
}

var defaultDlpFile: dlpPermission.DlpFile = {
  dlpProperty: defaultDlpProperty,
  recoverDlpFile: null,
  closeDlpFile: null,
  addDlpLinkFile: null,
  stopDlpLinkFile: null,
  restartDlpLinkFile: null,
  replaceDlpLinkFile: null,
  deleteDlpLinkFile: null
}

@Component
struct DlpDialog {
  srcFd: number
  srcFileName: string
  isDlpFile: boolean = false
  requestIsFromSandBox: boolean = false
  isReadPermission: boolean = false
  linkFileName: string = ''
  dlpAlertDialog: CustomDialogController
  @State authPerm: number = 2
  @State isShow: boolean = false
  @State isChanged: boolean = false
  @State dlpFile: dlpPermission.DlpFile = defaultDlpFile
  @State needProtect: boolean = false
  @State processing: boolean = false

  showDlpAlertDialog(title, message) {
    this.dlpAlertDialog = new CustomDialogController({
      builder: DlpAlertDialog({
        title: title,
        message: message
      }),
      autoCancel: false,
      customStyle: true
    })
    this.dlpAlertDialog.open()
  }

  async checkAndOpenDlpFile(filename: string, fd: number, linkFileName: string): Promise<void> {
    console.info(TAG + "checkAndOpenDlpFile")
    this.dlpFile.dlpProperty.ownerAccount = globalThis.accountInfo.distributedInfo.name
    this.dlpFile.dlpProperty.contractAccount = globalThis.accountInfo.distributedInfo.name
    var isDlpSuffix: boolean = filename.endsWith(".dlp")
    if (this.requestIsFromSandBox) {
      console.info(TAG + "in sandbox")
      try {
        for (var key in globalThis.sandbox2linkFile) {
          if (globalThis.sandbox2linkFile[key][2] == linkFileName) {
            var linkFile = globalThis.sandbox2linkFile[key]
            for (var i = 0; i < linkFile[1].dlpProperty.authUsers.length; ++i) {
              var authUser = linkFile[1].dlpProperty.authUsers[i]
              if (authUser.authAccount == globalThis.accountInfo.distributedInfo.name) {
                this.authPerm = authUser.authPerm
                if (authUser.authPerm == dlpPermission.AuthPermType.READ_ONLY) {
                  console.info(TAG+" dlpPermission.AuthPermType.READ_ONLY")
                  this.isReadPermission = true
                }
              }
            }
            this.dlpFile = linkFile[1]
            this.srcFd = linkFile[3]
            this.isDlpFile = true
            this.needProtect = true
            this.isShow = true
            return
          }
        }
        console.error(TAG + "requestIsFromSandBox can not find dilFile by linkFileName " + linkFileName)
        return
      } catch (error) {
        console.error(TAG + "isInSandbox error:" + JSON.stringify(error))
        return
      }
    }
    if (!isDlpSuffix) {
      console.info(TAG + "input file is not a dlp file")
      var ownerAccount : dlpPermission.AuthUser = {
        authAccount: this.dlpFile.dlpProperty.ownerAccount,
        authPerm: dlpPermission.AuthPermType.FULL_CONTROL,
        permExpiryTime: Date.UTC(2024, 1, 1),
        authAccountType: dlpPermission.AccountType.CLOUD_ACCOUNT,
      }
      this.dlpFile.dlpProperty.authUsers.push(ownerAccount)
      this.isShow = true
      return
    }
    try {
      this.dlpFile = await dlpPermission.openDlpFile(fd)
    } catch (err) {
      console.error(TAG + "openDlpFile error: " + err.message + ", code: " + err.code)
      var errorInfo = getAlertMessage(err, Constants.TITLE_APP_DLP_ERROR,Constants.MESSAGE_APP_FILE_PARAM_ERROR)
      this.showDlpAlertDialog(errorInfo.title, errorInfo.msg)
      return
    }
    this.authPerm = getAuthPerm(globalThis.accountInfo.distributedInfo.name, this.dlpFile.dlpProperty)
    this.isDlpFile = true
    this.needProtect = true
    this.isShow = true
  }

  async aboutToAppear() {
    console.info(TAG + "aboutToAppear")
    try {
      globalThis.accountInfo = await getOsAccountInfo()
      if (globalThis.accountInfo.distributedInfo.name == "ohosAnonymousName" && globalThis.accountInfo.distributedInfo.id == "ohosAnonymousUid") {
        this.showDlpAlertDialog(Constants.TITLE_APP_ERROR, Constants.MESSAGE_APP_NO_ACCOUNT_ERROR)
        return
      }
    } catch (err) {
      console.info(TAG + "getOsAccountInfo error: " + JSON.stringify(err))
      terminateSelfWithResult(100, "get account info failed")
    }
    try {
      this.srcFileName = globalThis.abilityWant.parameters.fileName.name
      this.srcFd = globalThis.abilityWant.parameters.keyFd.value
      var callerToken = globalThis.abilityWant.parameters["ohos.aafwk.param.callerToken"]
      var callerBundleName = globalThis.abilityWant.parameters["ohos.aafwk.param.callerBundleName"]
      globalThis.applicationInfo = await bundleManager.getApplicationInfo(callerBundleName, bundleManager.ApplicationFlag.GET_APPLICATION_INFO_DEFAULT)
      if (callerToken == globalThis.applicationInfo.accessTokenId) {
        this.requestIsFromSandBox = false
      } else {
        this.requestIsFromSandBox = true
      }
      if (this.requestIsFromSandBox) {
        this.linkFileName = globalThis.abilityWant.parameters.linkFileName.name
      }
    } catch (err) {
      console.error(TAG + "get parameters error")
      terminateSelfWithResult(100, "get parameters failed, fileName and keyFd is required")
    }
    console.info(TAG + " linkFilename:" + this.linkFileName + " srcFilename:" + this.srcFileName + " srcFd:" + globalThis.srcFd)
    this.checkAndOpenDlpFile(this.srcFileName, this.srcFd, this.linkFileName)
  }

  build() {
    Flex({ alignItems: ItemAlign.Center, justifyContent: FlexAlign.Center}) {
      ProcessingPanel( {processing: $processing} )
      if (this.isShow) {
        Column() {
          Row() {
            Header({ authPerm: $authPerm, needProtect: $needProtect, processing: $processing })
          }

          if (this.needProtect) {
            Row() {
              PermissionPanel({ authPerm: $authPerm, dlpFile: $dlpFile, isChanged: $isChanged, processing: $processing })
            }

            Row() {
              AuthorizerPanel({ authPerm: $authPerm, dlpFile: $dlpFile, isChanged: $isChanged, processing: $processing })
            }
          }
          Row() {
            Footer({
              srcFilename: this.srcFileName,
              srcFd: this.srcFd,
              isDlpFile: this.isDlpFile,
              requestIsFromSandBox: this.requestIsFromSandBox,
              isReadPermission: this.isReadPermission,
              linkFileName: this.linkFileName,
              isChanged: $isChanged,
              dlpFile: $dlpFile,
              needProtect: $needProtect,
              processing: $processing
            })
          }
        }
        .width(Constants.INDEX_COLUMN_WIDTH)
        .backgroundColor($r('app.color.index_background_color'))
        .borderRadius(Constants.INDEX_BORDER_RADIUS)
      }
    }
    .width('100%')
    .height('100%')
  }
}

@Entry
@Component
struct Index {
  aboutToAppear() {
  }

  build() {
    Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center,
        direction: FlexDirection.Column }) {
      Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center,
          direction: FlexDirection.Row }) {
        DlpDialog()
      }
    }
  }
}
