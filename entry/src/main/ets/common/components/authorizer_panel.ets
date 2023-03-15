import dlpPermission from '@ohos.dlpPermission'
import {DlpAlertDialog} from '../components/dlp_alert_dialog'
import Constants from'../constant'

var TAG = "[DLPManager_authorize]"
@Component
struct AuthorizerPanel {
  scroller: Scroller = new Scroller()
  contactToAdd : string = ''
  dlpAlertDialog : CustomDialogController
  @Link authPerm : number
  @Link isChanged : boolean
  @State showContacts : boolean = true
  @State contacts: { [key: string]: string} = {}
  @Link dlpFile : dlpPermission.DlpFile
  @State contactList: string[] = []
  @Link processing : boolean

  updateContactList () {
    this.contactList = []
    for (var item in this.contacts) {
      this.contactList.push(item)
    }
    this.dlpFile.dlpProperty.contractAccount = this.contactList.join(";")
  }

  aboutToAppear() {
    if (this.dlpFile.dlpProperty.contractAccount.length == 0) {
      return
    }
    this.contactList = this.dlpFile.dlpProperty.contractAccount.split(';')
    for (var i = 0; i < this.contactList.length; ++i) {
      this.contacts[this.contactList[i]] = ''
    }
  }

  @Builder ListItemLayout(item: string) {
    ListItem() {
      Column() {
        Row() {
          Text(item)
            .maxLines(Constants.AP_TEXT_MAX_LINE)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontSize(Constants.AP_TEXT_FONT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontFamily($r('app.string.typeface'))
            .lineHeight(Constants.AP_TEXT_LINE_HEIGHT)
            .width(Constants.AP_TEXT_WIDTH)
            .padding({right: Constants.AP_TEXT_PAD_RIGHT})
            .align(Alignment.Start)
          Image($r('app.media.ic_public_delete'))
            .enabled((!this.processing) && (this.authPerm == 2))
            .opacity(((!this.processing) && (this.authPerm == 2)) ?
            Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
            .width(Constants.PP_IMAGE_WIDTH)
            .height(Constants.PP_IMAGE_HEIGHT)
            .padding(Constants.PP_IMAGE_PAD)
            .onClick((event) => {
              delete this.contacts[item]
              this.updateContactList()
              this.isChanged = true
            })
        }
        .height(Constants.PP_ROW_HEIGHT)
        Line()
          .width(Constants.PP_LINE_WIDTH)
          .height(Constants.PP_LINE_HEIGHT)
          .backgroundColor($r('app.color.pp_line_background_color'))
      }
      .height(Constants.AP_COLUMN_HEIGHT)
      .alignItems(HorizontalAlign.Start)
    }
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.authorizer_panel_title'))
          .fontColor($r("app.color.text_color"))
          .fontFamily($r('app.string.typeface'))
          .fontWeight(FontWeight.Regular)
          .fontSize(Constants.AP_TEXT_FONT_SIZE)
          .lineHeight(Constants.AP_TEXT_LINE_HEIGHT)
          .margin({top: Constants.AP_MARGIN_TOP})
          .width(Constants.PP_TEXT_WIDTH_FULL)
          .align(Alignment.Start)
      }
      .height(Constants.AP_COLUMN_HEIGHT)
      .opacity(Constants.AP_COLUMN_OPACITY)
      if (this.showContacts) {
        if (this.contactList.length > 0) {
          Scroll(this.scroller) {
            List() {
              ForEach(this.contactList, (item) => {
                this.ListItemLayout(item)
              })
            }
          }
          .height(Constants.AP_LIST_HEIGHT)
          .width(Constants.PP_TEXT_WIDTH_FULL)
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.On)
          .scrollBarWidth(Constants.AP_LIST_BAR_WIDTH)
        }
        Row() {
          Button($r('app.string.button_add_user'))
            .enabled((!this.processing) && (this.authPerm == 2))
            .opacity(((!this.processing) && (this.authPerm == 2)) ?
            Constants.FOOTER_OPACITY_ONE : Constants.FOOTER_OPACITY_SEPC)
            .fontSize(Constants.AP_TEXT_FONT_SIZE)
            .fontColor($r('app.color.button_color'))
            .fontFamily($r('app.string.typeface'))
            .fontWeight(FontWeight.Medium)
            .focusable(false)
            .height(Constants.AP_BUTTON_HEIGHT)
            .backgroundColor($r('app.color.pp_button_background_color'))
            .padding(Constants.AP_BUTTON_PAD)
            .onClick((event) => {
              this.showContacts = false
            })
        }
        .align(Alignment.Start)
        .width(Constants.PP_TEXT_WIDTH_FULL)
        .height(Constants.AP_ROW_HEIGHT)
      } else {
        Row() {
          TextInput()
            .height(Constants.AP_TEXT_INPUT_HEIGHT)
            .padding({top: Constants.AP_TEXT_PAD_TOP, bottom: Constants.AP_TEXT_PAD_BOTTOM})
            .fontSize(Constants.AP_TEXT_FONT_SIZE)
            .borderRadius(Constants.AP_ROW_RADIUS)
            .backgroundColor($r('app.color.pp_row_background_color'))
            .enabled(!this.processing)
            .fontFamily($r('app.string.typeface'))
            .fontWeight(FontWeight.Regular)
            .onChange((value: string) => {
              this.contactToAdd = value
            })
        }
        .padding({right: Constants.AP_ROW_PAD_RIGHT})
        Line()
          .width(Constants.AP_LINE_WIDTH)
          .height(Constants.AP_LINE_HEIGHT)
          .backgroundColor($r('app.color.pp_line_background_color'))
        Row() {
          Button($r('app.string.add'))
            .fontSize(Constants.AP_TEXT_FONT_SIZE)
            .fontColor($r('app.color.button_color'))
            .fontFamily('app.string.HarmonyHeiTi')
            .fontWeight(FontWeight.Medium)
            .enabled(!this.processing)
            .height(Constants.AP_BUTTON_HEIGHT)
            .padding(Constants.AP_BUTTON_PAD)
            .backgroundColor($r('app.color.button_background_color'))
            .onClick((event) => {
              if (this.contactToAdd.length > 1024) {
                this.dlpAlertDialog = new CustomDialogController({
                  builder: DlpAlertDialog({
                    title: Constants.PP_TITLE,
                    message: Constants.PP_MESSAGE,
                  }),
                  autoCancel: false,
                  customStyle: true
                })
                this.dlpAlertDialog.open()
                return
              }
              if (this.contactToAdd.length != 0) {
                this.contacts[this.contactToAdd] = ""
                this.updateContactList()
              }
              this.contactToAdd = ''
              this.showContacts = true
              this.isChanged = true
            })
          Button($r('app.string.cancel'))
            .fontSize(Constants.AP_BUTTON_FONT_SIZE)
            .fontColor($r('app.color.button_color'))
            .fontFamily('app.string.HarmonyHeiTi')
            .fontWeight(FontWeight.Medium)
            .enabled(!this.processing)
            .height(Constants.AP_BUTTON_HEIGHT)
            .padding(Constants.AP_BUTTON_PAD)
            .margin({left: Constants.AP_BUTTON_MARGIN_LEFT})
            .focusable(false)
            .backgroundColor($r('app.color.pp_button_background_color'))
            .onClick((event) => {
              this.showContacts = true
            })
        }
        .width(Constants.PP_TEXT_WIDTH_FULL)
        .height(Constants.AP_ROW_HEIGHT)
        .align(Alignment.Start)
      }
    }
    .padding({left: Constants.AP_COLUMN_PAD_LEFT, right:Constants.AP_COLUMN_PAD_RIGHT})
    .alignItems(HorizontalAlign.Start)
  }
}

export {AuthorizerPanel}