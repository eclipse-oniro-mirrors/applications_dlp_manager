import dlpPermission from '@ohos.dlpPermission'
import fileio from '@ohos.fileio';
import Constants from '../constant'
import hiTraceMeter from '@ohos.hiTraceMeter';
import { DlpAlertDialog } from '../components/dlp_alert_dialog'
import hiSysEvent from '@ohos.hiSysEvent'
import mediaLibrary from '@ohos.multimedia.mediaLibrary'
import { getAlertMessage, getAuthPerm, getOsAccountInfo, getUserId, startAlertAbility } from '../utils'

var TAG: string = "DLPManager: "

var filePickerWant = {
  bundleName: "com.ohos.filepicker",
  abilityName: "MainAbility",
  parameters: {
    'startMode': 'save',
    'saveFile': '',
  }
}

var abilityResult = {
  "resultCode": 0,
  "want": {}
}

var filePickerOptions = {
  windowMode: 102
}
var suffix_length = 4;

@Component
struct Footer {
  @Link processing : boolean
  srcFilename: string
  srcFd: number
  isDlpFile: boolean
  dlpAlertDialog: CustomDialogController
  @Link isChanged: boolean
  @Link dlpFile: dlpPermission.DlpFile
  @Link needProtect: boolean

  async getFileAssetFromUri(uri) {
    let fileAssetUriFetchOp = {
      selections: "",
      selectionArgs: [],
      uri: uri.toString(),
    };
    let context: any = getContext(this)
    let media = mediaLibrary.getMediaLibrary(context);
    let uriFetchResult = await media.getFileAssets(fileAssetUriFetchOp);
    let uriFileAsset = await uriFetchResult.getFirstObject();
    return uriFileAsset;
  }

  dlpErrorDialog(title: string, message: string) {
    this.dlpAlertDialog = new CustomDialogController({
      builder: DlpAlertDialog({
        title: title,
        message: message,
        action: () => {
        }
      }),
      autoCancel: false,
      customStyle: true,
    })
    this.dlpAlertDialog.open()
  }

  async postProcessForSetting() {
    var filename = this.srcFilename.substr(0, this.srcFilename.length - suffix_length)
    if (this.needProtect) {
      this.processing = true
      var filePath = globalThis.context.filesDir + "/" + filename + (new Date().getTime())
      try {
        var tempFd = fileio.openSync(filePath, 0o102, 0o666)
      } catch (err) {
        console.error(TAG + "openSync error: " + JSON.stringify(err))
        this.dlpErrorDialog(Constants.TITLE_APP_ERROR, Constants.MESSAGE_APP_INSIDE_ERROR)
        this.processing = false
        return
      }
      try {
        await this.dlpFile.recoverDlpFile(tempFd)
      } catch (err) {
        console.error(TAG + "recoverDlpFile error: " + err.message + ", code: " + err.code)
        fileio.closeSync(tempFd)
        fileio.unlinkSync(filePath)
        var errorInfo = getAlertMessage(err, Constants.TITLE_SERVICE_ERROR, Constants.MESSAGE_RECOVER_DLP_ERROR)
        this.dlpErrorDialog(errorInfo.title, errorInfo.msg)
        this.processing = false
        return
      }
      console.info(TAG + "filePath" + filePath + ", DlpProperty: " + JSON.stringify(this.dlpFile.dlpProperty))
      try {
        await this.dlpFile.closeDlpFile()
      } catch (err) {
        console.error(TAG + "closeDlpFile error: " + err.message + ", code: " + err.code)
      }
      try {
        var accountInfo = await getOsAccountInfo();
      } catch (err) {
        console.error(TAG + "getOsAccountInfo error: " + JSON.stringify(err))
        fileio.closeSync(tempFd)
        fileio.unlinkSync(filePath)
        this.dlpErrorDialog(Constants.TITLE_APP_ERROR, Constants.MESSAGE_APP_GET_ACCOUNT_ERROR)
        this.processing = false
        return
      }
      this.dlpFile.dlpProperty.ownerAccount = accountInfo.distributedInfo.name
      try {
        this.dlpFile = await dlpPermission.generateDlpFile(tempFd, this.srcFd, this.dlpFile.dlpProperty)
      } catch (err) {
        console.error(TAG + "generateDlpFile error: " + err.message + ", code: " + err.code)
        fileio.closeSync(tempFd)
        fileio.unlinkSync(filePath)
        try {
          await this.dlpFile.closeDlpFile()
        } catch (err) {
          console.error(TAG + "closeDlpFile error: " + err.message + ", code: " + err.code)
        }
        var errorInfo = getAlertMessage(err, Constants.TITLE_SERVICE_ERROR, Constants.MESSAGE_GENERATE_DLP_ERROR)
        this.dlpErrorDialog(errorInfo.title, errorInfo.msg)
        this.processing = false
        return
      }
      try {
        await this.dlpFile.closeDlpFile()
      } catch (err) {
        console.error(TAG + "closeDlpFile error: " + err.message + ", code: " + err.code)
      }
      fileio.closeSync(tempFd)
      fileio.unlinkSync(filePath)
      abilityResult.resultCode = 0
      this.processing = false
      globalThis.context.terminateSelfWithResult(abilityResult)
      return
    } else {
      filePickerWant.parameters.saveFile = filename
      globalThis.context.startAbilityForResult(filePickerWant, filePickerOptions, async (error, data) => {
        this.processing = true
        console.log(TAG + JSON.stringify(error) + ", data: " + JSON.stringify(data))
        var uri = data.want.parameters.result
        if (uri == undefined || uri.length == 0) {
          console.error(TAG + "fail to get uri")
          this.processing = false
          return;
        }
        try {
          var uriFileAsset = await this.getFileAssetFromUri(uri);
          var dstFd = await uriFileAsset.open('w');
        } catch (err) {
          console.error(TAG + "openFile error: " + err.message + ", code: " + err.code)
          await globalThis.dsHelper.delete(uri)
          this.dlpErrorDialog(Constants.TITLE_APP_ERROR, Constants.MESSAGE_APP_INSIDE_ERROR)
          this.processing = false
          return;
        }
        try {
          await this.dlpFile.recoverDlpFile(dstFd)
        } catch (err) {
          console.error(TAG + "recoverDlpFile error: " + err.message + ", code: " + err.code)
          await uriFileAsset.close(dstFd)
          await globalThis.dsHelper.delete(uri)
          var errorInfo = getAlertMessage(err, Constants.TITLE_SERVICE_ERROR, Constants.MESSAGE_RECOVER_DLP_ERROR)
          this.dlpErrorDialog(errorInfo.title, errorInfo.msg)
          this.processing = false
          return;
        }
        try {
          await uriFileAsset.close(dstFd);
          await this.dlpFile.closeDlpFile()
        } catch (err) {
          console.error(TAG + "closeDlpFile error: " + err.message + ", code: " + err.code)
        }
        abilityResult.resultCode = 0
        this.processing = false
        globalThis.context.terminateSelfWithResult(abilityResult)
        return;
      })
    }
  }

  async sendDlpFileCreateFault(code: number, reason: string) {
    var event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_CREATE',
      eventType: hiSysEvent.EventType.FAULT,
      params: {
        'CODE': code,
        'REASON': reason
      }
    };

    try {
      var userId = await getUserId();
      event.params['USER_ID'] = userId;
      await hiSysEvent.write(event);
    } catch (err) {
      console.log(TAG + "sendDlpFileOpenEvent failed")
    }
  }

  async sendDlpFileCreateEvent(code: number) {
    var event: hiSysEvent.SysEventInfo = {
      domain: 'DLP',
      name: 'DLP_FILE_CREATE_EVENT',
      eventType: hiSysEvent.EventType.BEHAVIOR,
      params: {
        'CODE': code,
      }
    };
    try {
      var userId = await getUserId();
      event.params['USER_ID'] = userId;
      await hiSysEvent.write(event);
    } catch (err) {
      console.log(TAG + "sendDlpFileOpenEvent failed")
    }
  }

  postProcessForEncrypting() {
    if (!this.needProtect || this.srcFilename == undefined || this.srcFilename.length == 0) {
      console.log(TAG + "no need to be protected")
      this.processing = false
      globalThis.context.terminateSelf()
      return
    }
    filePickerWant.parameters.saveFile = this.srcFilename + '.dlp'
    globalThis.context.startAbilityForResult(filePickerWant, filePickerOptions, async (error, data) => {
      this.processing = true
      console.log(TAG + JSON.stringify(error) + ", data: " + JSON.stringify(data))
      var uri: string = data.want.parameters.result
      if (uri == undefined || uri.length == 0) {
        console.error(TAG + "fail to get uri")
        this.processing = false
        return;
      }
      try {
        var uriFileAsset = await this.getFileAssetFromUri(uri);
        var dstFd = await uriFileAsset.open('w');
      } catch (err) {
        console.error(TAG + "openFile error: " + JSON.stringify(err))
        await globalThis.dsHelper.delete(uri)
        this.dlpErrorDialog(Constants.TITLE_APP_ERROR, Constants.MESSAGE_APP_INSIDE_ERROR)
        this.processing = false
        return;
      }
      hiTraceMeter.startTrace("DlpGenerateDlpFileJs", this.srcFd);
      try {
        this.dlpFile = await dlpPermission.generateDlpFile(this.srcFd, dstFd, this.dlpFile.dlpProperty)
      } catch (err) {
        await this.sendDlpFileCreateFault(102, err.data); // 102: DLP_FILE_CREATE_ERORR
        hiTraceMeter.finishTrace("DlpGenerateDlpFileJs", this.srcFd);
        console.error(TAG + "generateDlpFile error: " + err.message + ", code: " + err.code)
        await uriFileAsset.close(dstFd)
        await globalThis.dsHelper.delete(uri)
        var errorInfo = getAlertMessage(err, Constants.TITLE_SERVICE_ERROR, Constants.MESSAGE_GENERATE_DLP_ERROR)
        this.dlpErrorDialog(errorInfo.title, errorInfo.msg)
        this.processing = false
        return;
      }
      await this.sendDlpFileCreateEvent(201); // 201: DLP_FILE_CREATE_SUCCESS
      hiTraceMeter.finishTrace("DlpGenerateDlpFileJs", this.srcFd);
      try {
        await this.dlpFile.closeDlpFile()
        await uriFileAsset.close(dstFd);
      } catch (err) {
        console.error(TAG + "closeDlpFile error: " + err.message + ", code: " + err.code)
      }
      abilityResult.resultCode = 0
      this.processing = false
      globalThis.context.terminateSelfWithResult(abilityResult)
    })
  }

  build() {
    Row() {
      Button($r('app.string.ban'), { type: ButtonType.Normal })
        .fontColor($r('app.color.button_color'))
        .fontFamily($r('app.string.typeface'))
        .backgroundColor($r("app.color.button_background_color"))
        .width(Constants.FOOTER_WIDTH)
        .focusable(false)
        .enabled(!this.processing)
        .opacity(!this.processing ?
        Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
        .height(Constants.FOOTER_HEIGHT)
        .onClick(async (event) => {
          if (this.isDlpFile) {
            try {
              await this.dlpFile.closeDlpFile()
            } catch (err) {
              console.error(TAG + "closeDlpFile error: " + err.message + ", code: " + err.code)
            }
          }
          globalThis.context.terminateSelf()
        })
      Line()
        .width(Constants.FOOTER_LINE_WIDTH)
        .height(Constants.FOOTER_LINE_HEIGHT)
        .backgroundColor($r('app.color.footer_line_background_color'))
      Button(this.needProtect ? $r('app.string.save') : $r('app.string.sure'), { type: ButtonType.Normal })
        .fontColor($r('app.color.button_color'))
        .fontFamily($r('app.string.typeface'))
        .backgroundColor($r("app.color.button_background_color"))
        .width(Constants.FOOTER_BUTTON_WIDTH)
        .focusable(false)
        .enabled(!this.processing && (this.needProtect || this.isDlpFile))
        .opacity((!this.processing && (this.needProtect || this.isDlpFile)) ?
        Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
        .height(Constants.FOOTER_BUTTON_HEIGHT)
        .onClick(async (event) => {
          if (this.dlpFile.dlpProperty.contractAccount.length == 0) {
            this.dlpFile.dlpProperty.contractAccount = globalThis.accountInfo.distributedInfo.name
          }
          if (this.isDlpFile) {
            await this.postProcessForSetting()
          } else {
            await this.postProcessForEncrypting()
          }
        })
    }
    .width(Constants.FOOTER_ROW_WIDTH)
    .height(Constants.FOOTER_ROW_HEIGHT)
    .margin({ top: Constants.FOOTER_ROW_MARGIN })
    .padding({
      bottom: Constants.FOOTER_ROW_PAD_BOTTOM,
      left: Constants.FOOTER_ROW_PAD_LEFT,
      right: Constants.FOOTER_ROW_PAD_RIGHT
    })
  }
}

export { Footer }