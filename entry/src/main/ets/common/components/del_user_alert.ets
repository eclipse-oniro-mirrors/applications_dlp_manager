import Constants from'../constant'

@CustomDialog
struct DelUserAlertDialog {
  controller : CustomDialogController
  cancel: () => void
  confirm: () => void
  build() {
    Column() {
      Row() {
        Text($r('app.string.del_usr'))
          .lineHeight(Constants.DU_TEXT_LINE_HEIGHT)
          .width(Constants.DU_WIDTH_FULL)
          .fontFamily($r('app.string.typeface'))
          .fontSize(Constants.DU_TEXT_FONT_SIZE)
          .fontColor($r('app.color.pp_text_fontcolor'))
          .fontWeight(FontWeight.Medium)
      }
      .height(Constants.DU_ROW_HEIGHT)
      .width(Constants.DU_ROW_WIDTH)
      Row() {
        Scroll() {
          Text($r('app.string.del_text1'))
            .lineHeight(Constants.DU_SCROLL_LINE_HEIGHT)
            .width(Constants.DU_WIDTH_FULL)
            .fontFamily('app.string.HarmonyHeiTi')
            .fontSize(Constants.DU_SCROLL_FONT_SIZE)
            .fontColor($r('app.color.del_scroll_font_color'))
            .fontWeight(FontWeight.Regular)
        }
        .scrollBarColor(Color.Gray).scrollBarWidth(Constants.DU_SCROLL_BAR_WIDTH)
        .constraintSize({maxHeight: Constants.DU_CONS_MAX_HEIGHT})
      }
      .margin({top: Constants.DU_MARGIN_TOP})
      .width(Constants.DU_ROW_WIDTH)
      Row() {
        Button($r('app.string.cancel'))
          .width(Constants.DU_WIDTH_SPE)
          .height(Constants.DU_BUTTON_HEIGHT)
          .fontSize(Constants.DU_BUTTON_FONT_SIZE)
          .fontFamily($r('app.string.typeface'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r("app.color.button_color"))
          .backgroundColor($r('app.color.pp_button_background_color'))
          .onClick(() => {
            this.controller.close()
          })
        Line()
          .width(Constants.DU_LINE_WIDTH)
          .height(Constants.DU_LINE_HEIGHT)
          .margin({top: Constants.DU_LINE_MARGIN_TOP})
          .backgroundColor($r('app.color.pp_line_background_color'))
        Button($r('app.string.button_del'))
          .width(Constants.DU_BUTTON_WIDTH)
          .height(Constants.DU_BUTTON_HEIGHT)
          .fontSize(Constants.DU_BUTTON_FONT_SIZE)
          .fontFamily($r('app.string.typeface'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.del_button_font_color'))
          .backgroundColor($r('app.color.pp_button_background_color'))
          .onClick(() => {
            this.controller.close()
            this.confirm()
          })
      }
      .width(Constants.DU_ROW_WIDTH2)
      .alignItems(VerticalAlign.Top)
      .margin({ top: Constants.DU_LINE_MARGIN_TOP2 })
      .height(Constants.DU_ROW_HEIGHT)
    }
    .width(Constants.DU_ROW_WIDTH3)
    .backgroundColor($r('app.color.pp_row_background_color'))
    .borderRadius(Constants.DU_BORDER_RADIUS)
    .alignItems(HorizontalAlign.Center)
  }
}

export {DelUserAlertDialog}
