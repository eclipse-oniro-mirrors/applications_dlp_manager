import Constants from'../constant'

@CustomDialog
struct DlpAlertDialog {
  controller : CustomDialogController
  title: string
  message: string
  action: () => void = null
  build() {
    Column() {
      Row() {
        Text(this.title)
          .lineHeight(Constants.DA_TEXT_LINE_HEIGHT)
          .width(Constants.DU_WIDTH_FULL)
          .fontFamily($r('app.string.typeface'))
          .fontSize(Constants.DA_FONT_SIZE)
          .fontColor($r('app.color.da_font_color'))
          .fontWeight(FontWeight.Medium)
      }
      .height(Constants.DA_ROW_HEIGHT)
      .width(Constants.DA_ROW_WIDTH)
      Row() {
        Scroll() {
          Text(this.message)
            .lineHeight(Constants.DA_SCROLL_LINE_HEIGHT)
            .width(Constants.DU_WIDTH_FULL)
            .fontFamily($r('app.string.typeface'))
            .fontSize(Constants.DA_SCROLL_FONT_SIZE)
            .fontColor($r('app.color.da_scroll_font_color'))
            .fontWeight(FontWeight.Regular)
        }
        .scrollBarColor(Color.Gray).scrollBarWidth(Constants.DA_SCROLL_BAR_WIDTH)
        .constraintSize({maxHeight: Constants.DA_STRAIN_SIZE_MA_HEIGHT})
      }
      .margin({top: Constants.DA_MARGIN_TOP})
      .width(Constants.DA_SCROLL_WIDTH);
      Row() {
        Button($r('app.string.da_buttion'))
          .width(Constants.ROW_BUTTON_WIDTH)
          .height(Constants.ROW_BUTTON_HEIGHT)
          .fontSize(Constants.ROW_FONT_SIZE)
          .fontFamily($r('app.string.typeface'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r("app.color.button_color"))
          .backgroundColor($r('app.color.da_button_color'))
          .onClick(() => {
            this.controller.close()
            if (this.action != null) {
              this.action()
            } else {
              globalThis.context.terminateSelf()
            }
          })
      }
      .alignItems(VerticalAlign.Top)
      .margin({ top: Constants.ROW_MARGIN_TOP })
      .height(Constants.DA_ROW_HEIGHT)
    }
    .width(Constants.DA_COLOUM_WIDTH)
    .borderRadius(Constants.DA_COLOUM_RADIUS)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.da_background_color'))
  }
}

export {DlpAlertDialog}