import dlpPermission from '@ohos.dlpPermission'
import Constants from '../constant'

@Component
struct Header {
  @Link authPerm : number
  @Link needProtect : boolean
  build() {
    Column() {
      Column({}) {
        Text($r('app.string.header_title'))
          .fontWeight(FontWeight.Bold)
          .fontFamily($r('app.string.typeface'))
          .fontColor($r('app.color.text_color'))
          .fontSize(Constants.HEADER_TEXT_FRONT_SIZE)
          .lineHeight(Constants.HEADER_TEXT_LINE_HEIGHT)
          .margin({top: Constants.HEADER_TEXT_MARGIN_TOP})
          .width(Constants.HEADER_TEXT_WIDTH)
          .align(Alignment.Start)
      }
      .width(Constants.HEADER_COLUMN_WIDTH)
      .height(Constants.HEADER_COLUMN_HEIGHT)
      .padding({left: Constants.HEADER_COLUMN_PAD_LEFT, right: Constants.HEADER_COLUMN_PAD_RIGHT})
      Row() {
        Flex({justifyContent: FlexAlign.SpaceBetween}) {
          Row() {
            Text($r('app.string.toggle_title'))
              .fontFamily($r('app.string.typeface'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_color'))
              .fontSize(Constants.HEADER_ROW_FONT_SIZE)
              .lineHeight(Constants.HEADER_ROW_LINE_HEIGHT)
          }
          .alignItems(VerticalAlign.Center)
          Toggle({ type: ToggleType.Switch, isOn: this.needProtect})
            .enabled(this.authPerm == 2 ? true : false)
            .selectedColor($r("app.color.toggle_color"))
            .width(Constants.HEADER_TOGGLE_WIDTH)
            .height(Constants.HEADER_TOGGLE_HEIGHT)
            .focusable(false)
            .onChange((isOn) => {
              this.needProtect = isOn ? true : false
            })
        }
      }
      .height(Constants.HEADER_ROW_HEIGHT)
      .margin({top: Constants.HEADER_ROW_MARGIN_TOP})
      .padding({left: Constants.HEADER_ROW_PAD_LEFT, right: Constants. HEADER_ROW_PAD_RIGHT})
    }
  }
}

export {Header}