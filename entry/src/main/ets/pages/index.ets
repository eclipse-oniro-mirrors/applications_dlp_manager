import { Header } from '../common/components/header'
import { PermissionPanel } from '../common/components/permission_panel'
import { AuthorizerPanel } from '../common/components/authorizer_panel'
import { ProcessingPanel } from '../common/components/processing_panel';
import { Footer } from '../common/components/footer'
import dlpPermission from '@ohos.dlpPermission'
import { getAuthPerm, getAlertMessage } from '../common/utils'
import { DlpAlertDialog } from '../common/components/dlp_alert_dialog'
import { KeyCode } from '@ohos.multimodalInput.keyCode'
import { getOsAccountInfo, terminateSelfWithResult } from '../common/utils'
import Constants from '../common/constant'

var TAG = "[DLPManager]"

var defaultDlpProperty: dlpPermission.DlpProperty = {
  ownerAccount: '',
  ownerAccountType: 1,
  authUsers: [],
  contractAccount: ''
}

var defaultDlpFile: dlpPermission.DlpFile = {
  dlpProperty: defaultDlpProperty,
  recoverDlpFile: null,
  closeDlpFile: null,
  addDlpLinkFile: null,
  deleteDlpLinkFile: null
}

@Component
struct DlpDialog {
  isDlpFile: boolean = false
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

  async checkAndOpenDlpFile(filename: string, fd: number): Promise<void> {
    console.info(TAG + "checkAndOpenDlpFile")
    this.dlpFile.dlpProperty.ownerAccount = globalThis.accountInfo.distributedInfo.name
    this.dlpFile.dlpProperty.contractAccount = globalThis.accountInfo.distributedInfo.name
    var isDlpSuffix: boolean = filename.endsWith(".dlp")
    if (!isDlpSuffix) {
      console.info(TAG + "input file is not a dlp file")
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
      globalThis.srcFilename = globalThis.abilityWant.parameters.fileName.name
      globalThis.srcFd = globalThis.abilityWant.parameters.keyFd.value
      console.log(TAG + "srcFilename: " + globalThis.srcFilename + ", srcFd: " + globalThis.srcFd)
    } catch (err) {
      console.error(TAG + "get parameters error")
      terminateSelfWithResult(100, "get parameters failed, fileName and keyFd is required")
    }
    this.checkAndOpenDlpFile(globalThis.srcFilename, globalThis.srcFd)
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
              srcFilename: globalThis.srcFilename,
              srcFd: globalThis.srcFd,
              isDlpFile: this.isDlpFile,
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