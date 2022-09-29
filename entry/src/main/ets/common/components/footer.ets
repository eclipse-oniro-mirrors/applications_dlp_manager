import dlpPermission from '@ohos.dlpPermission'
import fileio from "@ohos.fileio";
import dataShare from '@ohos.data.dataShare';
import datafile from '@ohos.data.fileAccess';
import Constants from '../constant'

var TAG: string = "DLPManager: "

var filePickerWant = {
  bundleName: "com.ohos.filepicker",
  abilityName: "MainAbility",
  parameters: {
    'startMode': 'save',
    'saveFile': '',
  }
}

var filePickerOptions = {
  windowMode: 102
}
var suffix_length = 4;
@Component
struct Footer {
  srcFilename: string
  srcFd: number
  isDlpFile: boolean
  @Link isChanged: boolean
  @Link dlpFile: dlpPermission.DlpFile
  @Link needProtect: boolean

  async postProcessForSetting() {
    var filename = this.srcFilename.substr(0, this.srcFilename.length - suffix_length)
    if (this.needProtect) {
      try {
        var filePath = globalThis.context.filesDir + "/" + filename + (new Date().getTime())
        var tempFd = fileio.openSync(filePath, 0o102, 0o666)
        await this.dlpFile.recoverDlpFile(tempFd)
        console.info(TAG + "filePath" + filePath + ", DlpProperty: " + JSON.stringify(this.dlpFile.dlpProperty))
        await this.dlpFile.closeDlpFile()
        this.dlpFile = await dlpPermission.generateDlpFile(tempFd, this.srcFd, this.dlpFile.dlpProperty)
        fileio.closeSync(tempFd)
        fileio.unlinkSync(filePath)
        await this.dlpFile.closeDlpFile()
        globalThis.context.terminateSelf()
      } catch (err) {
        console.error(TAG + "error: " + JSON.stringify(err))
      }
    } else {
      filePickerWant.parameters.saveFile = filename
      globalThis.context.startAbilityForResult(filePickerWant, filePickerOptions, async (error, data) => {
        console.log(TAG + JSON.stringify(error) + ", data: " + JSON.stringify(data))
        var uri = data.want.parameters.result
        try {
          var dsHelper = await datafile.createFileAccessHelper(globalThis.context)
        } catch (err) {
          console.error(TAG + "createFileAccessHelper error: " + JSON.stringify(err))
        }
        try {
          var dstFd = await dsHelper.openFile(uri, 0o2)
        } catch (err) {
          console.error(TAG + "openFile error: " + JSON.stringify(err))
        }
        try {
          await this.dlpFile.recoverDlpFile(dstFd)
        } catch (err) {
          console.error(TAG + "recoverDlpFile error: " + JSON.stringify(err))
        }
        try {
          await this.dlpFile.closeDlpFile()
          globalThis.context.terminateSelf()
        } catch (err) {
          console.error(TAG + "closeDlpFile error: " + JSON.stringify(err))
        }
      })
    }
  }

  postProcessForEncrypting() {
    if (!this.needProtect || this.srcFilename == undefined || this.srcFilename.length == 0) {
      console.log("DlpManager no need to be protected")
      globalThis.context.terminateSelf()
      return
    }
    filePickerWant.parameters.saveFile = this.srcFilename + '.dlp'
    globalThis.context.startAbilityForResult(filePickerWant, filePickerOptions, async (error, data) => {
      console.log(TAG + JSON.stringify(error) + ", data: " + JSON.stringify(data))
      var uri: string = data.want.parameters.result
      if (uri.length == 0) {
        return
      }
      try {
        var dsHelper = await datafile.createFileAccessHelper(globalThis.context)
      } catch (err) {
        console.error(TAG + "createFileAccessHelper error: " + JSON.stringify(err))
        return
      }
      try {
        var dstFd = await dsHelper.openFile(uri, 0o2)
      } catch (err) {
        console.error(TAG + "openFile error: " + JSON.stringify(err))
        return
      }
      try {
        this.dlpFile = await dlpPermission.generateDlpFile(this.srcFd, dstFd, this.dlpFile.dlpProperty)
      } catch (err) {
        console.error(TAG + "generateDlpFile error: " + JSON.stringify(err))
        return
      }
      try {
        await this.dlpFile.closeDlpFile()
        globalThis.context.terminateSelf()
      } catch (err) {
        console.error(TAG + "closeDlpFile error: " + JSON.stringify(err))
      }
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
        .height(Constants.FOOTER_HEIGHT)
        .onClick(async (event) => {
          if (this.isDlpFile) {
            try {
              await this.dlpFile.closeDlpFile()
            } catch (err) {
              console.error(TAG + "error: " + JSON.stringify(err))
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
        .enabled((this.needProtect || this.isDlpFile))
        .opacity((this.needProtect || this.isDlpFile) ?
            Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
        .height(Constants.FOOTER_BUTTON_HEIGHT)
        .onClick((event) => {
          if (this.dlpFile.dlpProperty.contractAccount.length == 0) {
            this.dlpFile.dlpProperty.contractAccount = globalThis.accountInfo.distributedInfo.name
          }
          if (this.isDlpFile) {
            this.postProcessForSetting()
          } else {
            this.postProcessForEncrypting()
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