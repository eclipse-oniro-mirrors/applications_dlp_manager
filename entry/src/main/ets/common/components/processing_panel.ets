import Constants from'../constant'

@Component
struct ProcessingPanel {
  @Link processing : boolean
  build() {
    if (this.processing) {
      Column() {
        Column() {
          LoadingProgress().width('72vp')
            .height('72vp')
            .margin({ bottom: '16vp' })
            .color(Color.Gray)
          Text('正在处理...')
            .fontSize(18)
            .fontFamily('app.string.HarmonyHeiTi')
            .fontColor(Color.Gray)
        }
      }
      .position({ x: 0, y: 0})
      .width('100%')
      .height('100%')
      .padding({ top: '15vp' })
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#ccffffff')
      .zIndex(10)
    }
  }
}

export {ProcessingPanel}