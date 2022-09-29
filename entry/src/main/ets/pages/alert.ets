import {DlpAlertDialog} from '../common/components/dlp_alert_dialog'

@Entry
@Component
struct Index {
  alertDialogController: CustomDialogController = new CustomDialogController({
    builder: DlpAlertDialog({
      title: globalThis.abilityWant.parameters.title,
      message: globalThis.abilityWant.parameters.message
    }),
    autoCancel: false,
    cancel: () => {
      globalThis.context.terminateSelf()
    },
    alignment: DialogAlignment.Center,
    customStyle: true
  })

  aboutToAppear() {
     this.alertDialogController.open()
  }

  build() {}
}