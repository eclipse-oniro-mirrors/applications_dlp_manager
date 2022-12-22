import dlpPermission from '@ohos.dlpPermission'
import {DelUserAlertDialog} from '../components/del_user_alert'
import {DlpAlertDialog} from '../components/dlp_alert_dialog'
import Constants from'../constant'

var TAG = "DLPManager: "
@Component
struct PermissionPanel {
  scroller: Scroller = new Scroller()
  account : string = ''
  radioImg = [$r('app.media.radiodefault'), $r('app.media.radio_selected')]
  delUserDialogController: CustomDialogController
  dlpAlertDialog: CustomDialogController
  @Link authPerm: number
  @Link isChanged: boolean
  @Link dlpFile: dlpPermission.DlpFile
  @State authUserMap: { [key: string] : dlpPermission.AuthUser } = {}
  @State authUsers: Array<dlpPermission.AuthUser> = []
  @State showAuthUsers : boolean = true
  @Link processing : boolean

  updateAuthUsers() {
    this.authUsers = []
    this.dlpFile.dlpProperty.authUsers = []
    for (var item in this.authUserMap) {
      let authUser = this.authUserMap[item]
      this.authUsers.push(authUser)
      this.dlpFile.dlpProperty.authUsers.push(authUser)
    }
  }

  aboutToAppear() {
    this.authUsers = this.dlpFile.dlpProperty.authUsers
    for (var i = 0; i < this.authUsers.length; ++i) {
      var authUser = this.authUsers[i]
      this.authUserMap[authUser.authAccount] = authUser
    }
  }

  @Builder ListItemLayout(item: dlpPermission.AuthUser) {
    ListItem() {
      Column() {
        Row() {
          Text(item.authAccount)
            .maxLines(Constants.PP_TEXT_MAX_LINE)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontSize(Constants.PP_TEXT_FONT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontFamily($r('app.string.typeface'))
            .lineHeight(Constants.PP_TEXT_LINE_HEIGHT)
            .width(Constants.PP_TEXT_WIDTH)
            .padding({right: Constants.PP_TEXT_PAD_RIGHT})
          Image(this.radioImg[2 - item.authPerm])
            .enabled((!this.processing) && (this.authPerm == 2))
            .opacity(((!this.processing) && (this.authPerm == 2)) ?
            Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
            .width(Constants.PP_IMAGE_WIDTH)
            .height(Constants.PP_IMAGE_HEIGHT)
            .padding(Constants.PP_IMAGE_PAD)
            .onClick((event) => {
              var authUser = this.authUserMap[item.authAccount]
              authUser.authPerm = dlpPermission.AuthPermType.READ_ONLY
              authUser.permExpiryTime = Date.UTC(2023, 1, 1)
              this.updateAuthUsers()
            })
          Column() {
            Image(this.radioImg[item.authPerm - 1])
              .enabled((!this.processing) && (this.authPerm == 2))
              .opacity(((!this.processing) && (this.authPerm == 2)) ?
              Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
              .width(Constants.PP_IMAGE_WIDTH)
              .height(Constants.PP_IMAGE_HEIGHT)
              .padding(Constants.PP_IMAGE_PAD)
              .onClick((event) => {
                var authUser = this.authUserMap[item.authAccount]
                authUser.authPerm = dlpPermission.AuthPermType.FULL_CONTROL
                authUser.permExpiryTime = Date.UTC(2023, 1, 1)
                this.updateAuthUsers()
              })
          }
          .alignItems(HorizontalAlign.Center)
          .width(Constants.PP_COLUMN_WIDTH)
          .margin({ left: Constants.PP_COLUMN_MARGIN_LEFT, right: Constants.PP_COLUMN_MARGIN_RIGHT })
          Image($r('app.media.ic_public_delete'))
            .enabled((!this.processing) && (this.authPerm == 2))
            .opacity(((!this.processing) && (this.authPerm == 2)) ?
            Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
            .width(Constants.PP_IMAGE_WIDTH)
            .height(Constants.PP_IMAGE_HEIGHT)
            .padding(Constants.PP_IMAGE_PAD)
            .onClick((event) => {
              this.delUserDialogController = new CustomDialogController({
                builder: DelUserAlertDialog({ cancel: null, confirm: () => {
                  delete this.authUserMap[item.authAccount]
                  this.updateAuthUsers()
                  this.isChanged = true
                } }),
                autoCancel: true,
                customStyle: true
              })
              this.delUserDialogController.open()
            })
        }
        .height(Constants.PP_ROW_HEIGHT)
        Line()
          .width(Constants.PP_LINE_WIDTH)
          .height(Constants.PP_LINE_HEIGHT)
          .backgroundColor($r('app.color.pp_line_background_color'))
      }
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.toggle_tip'))
          .fontColor($r("app.color.text_color"))
          .fontWeight(FontWeight.Regular)
          .fontFamily($r('app.string.typeface'))
          .fontSize(Constants.PP_TEXT_FONT_SIZE)
          .lineHeight(Constants.PP_TEXT_LINE_HEIGHT)
          .align(Alignment.Start)
          .width(Constants.PP_TEXT_WIDTH_FULL)
      }
      .height(Constants.PP_TEXT_HEIGHT)
      .opacity(Constants.PP_TEXT_OPACITY)
      Row () {
        Text($r('app.string.perm_panel_title'))
          .fontColor($r("app.color.text_color"))
          .fontFamily($r('app.string.typeface'))
          .fontWeight(FontWeight.Regular)
          .width(Constants.PP_TEXT_WIDTH_FULL)
          .lineHeight(Constants.PP_TEXT_LINE_HEIGHT)
          .margin({top: Constants.PP_TEXT_MARGIN_TOP})
          .align(Alignment.Start)
          .fontSize(Constants.PP_TEXT_FONT_SIZE)
      }
      .margin({top: Constants.PP_ROW_MARGIN_TOP})
      .height(Constants.PP_ROW_HEIGHT2)
      .opacity(Constants.PP_TEXT_OPACITY)
      if (this.showAuthUsers) {
        if (this.authUsers.length > 0) {
          Row() {
            Text($r('app.string.perm_list_title_user_name'))
              .fontSize(Constants.PP_TEXT_FONT_SIZE2)
              .fontFamily($r('app.string.typeface'))
              .fontWeight(FontWeight.Medium)
              .lineHeight(Constants.PP_TEXT_LINE_HEIGHT2)
              .width(Constants.PP_TEXT_WIDTH)
            Text($r('app.string.perm_list_title_read_only'))
              .fontSize(Constants.PP_TEXT_FONT_SIZE2)
              .fontFamily($r('app.string.typeface'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.pp_text_fontcolor'))
              .lineHeight(Constants.PP_TEXT_LINE_HEIGHT2)
              .width(Constants.PP_IMAGE_WIDTH)
            Text($r('app.string.perm_list_title_full_control'))
              .fontSize(Constants.PP_TEXT_FONT_SIZE2)
              .fontFamily($r('app.string.typeface'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.pp_text_fontcolor'))
              .lineHeight(Constants.PP_TEXT_LINE_HEIGHT2)
              .width(Constants.PP_TEXT_WIDTH2)
              .margin({ left: Constants.PP_TEXT_MARGIN_LEFT, right: Constants.PP_TEXT_MARGIN_RIGHT })
            Text()
              .width(Constants.PP_TEXT_WIDTH3)
          }
          .height(Constants.PP_ROW_HEIGHT3)
        }
        Scroll(this.scroller) {
          List() {
            ForEach(this.authUsers, (item) => {
              this.ListItemLayout(item)
            })
          }
        }
        .width(Constants.PP_TEXT_WIDTH_FULL)
        .align(Alignment.Top)
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.On)
        .scrollBarWidth(Constants.PP_SCROLL_BAR_WIDTH)
        .constraintSize({maxHeight: Constants.PP_SCROLL_MAX_HEIGHT})
        Row() {
          Button($r('app.string.button_add_user'))
            .enabled((!this.processing) && (this.authPerm == 2))
            .opacity(((!this.processing) && (this.authPerm == 2)) ?
            Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
            .fontSize(Constants.PP_BUTTON_FONT_SIZE)
            .fontColor($r('app.color.button_color'))
            .fontFamily($r('app.string.typeface'))
            .fontWeight(FontWeight.Medium)
            .height(Constants.PP_BUTTON_HEIGHT)
            .padding(Constants.PP_BUTTON_PAD)
            .focusable(false)
            .backgroundColor($r('app.color.pp_button_background_color'))
            .onClick((event) => {
              this.showAuthUsers = false
            })
        }
        .align(Alignment.Start)
        .width(Constants.PP_TEXT_WIDTH_FULL)
        .height(Constants.PP_ROW_HEIGHT2)
      } else {
        Row() {
          TextInput()
            .height(Constants.PP_TEXT_INPUT)
            .padding({top: Constants.PP_ROW_PAD_TOP, bottom: Constants.PP_ROW_PAD_BOTTOM})
            .fontSize(Constants.PP_TEXT_FONT_SIZE)
            .fontFamily($r('app.string.typeface'))
            .fontWeight(FontWeight.Regular)
            .enabled(!this.processing)
            .borderRadius(Constants.PP_ROW_RADIUS)
            .backgroundColor($r('app.color.pp_row_background_color'))
            .onChange((value: string) => {
              this.account = value
            })
        }
        .padding({right: Constants.PP_ROW_PAD_RIGHT})
        Line()
          .width(Constants.PP_LINE_WIDTH)
          .height(Constants.PP_LINE_HEIGHT2)
          .backgroundColor($r('app.color.pp_text_fontcolor'))
        Row() {
          Button($r('app.string.add'))
            .fontSize(Constants.PP_BUTTON_FONT_SIZE)
            .fontColor($r('app.color.button_color'))
            .fontFamily($r('app.string.typeface'))
            .fontWeight(FontWeight.Medium)
            .enabled(!this.processing)
            .height(Constants.PP_BUTTON_HEIGHT)
            .padding(Constants.PP_BUTTON_PAD)
            .backgroundColor($r('app.color.pp_button_background_color'))
            .onClick((event) => {
              if (this.account.length > Constants.ACCOUNT_LENGTH_MAX ) {
                this.dlpAlertDialog = new CustomDialogController({
                  builder: DlpAlertDialog({
                    title:Constants.PP_TITLE,
                    message: Constants.PP_MESSAGE,
                  }),
                  autoCancel: false,
                  customStyle: true
                })
                this.dlpAlertDialog.open()
                return
              }
              if (this.account.length != 0 && this.authUserMap[this.account] == undefined) {
                this.authUserMap[this.account] = {
                  authAccount: this.account,
                  authPerm: dlpPermission.AuthPermType.READ_ONLY,
                  permExpiryTime: Date.UTC(2033, 1, 1),
                  authAccountType: dlpPermission.AccountType.CLOUD_ACCOUNT
                }
                this.updateAuthUsers()
                this.isChanged = true
              }
              this.account = ''
              this.showAuthUsers = true
            })
          Button($r('app.string.cancel'))
            .fontSize(Constants.PP_BUTTON_FONT_SIZE)
            .fontColor($r('app.color.button_color'))
            .fontFamily('app.string.HarmonyHeiTi')
            .fontWeight(FontWeight.Medium)
            .enabled(!this.processing)
            .height(Constants.PP_BUTTON_HEIGHT)
            .padding(Constants.PP_BUTTON_PAD)
            .margin({left: Constants.PP_BUTTON_MARGIN_LEFT})
            .focusable(false)
            .backgroundColor($r('app.color.pp_button_background_color'))
            .onClick((event) => {
              this.showAuthUsers = true
            })
        }
        .align(Alignment.Start)
        .width(Constants.PP_TEXT_WIDTH_FULL)
        .height(Constants.PP_ROW_HEIGHT2)
      }
    }
    .padding({left: Constants.PP_COLUMN_MARGIN_LEFT2, right: Constants.PP_COLUMN_MARGIN_RIGHT2})
    .alignItems(HorizontalAlign.Start)
  }
}

export {PermissionPanel}