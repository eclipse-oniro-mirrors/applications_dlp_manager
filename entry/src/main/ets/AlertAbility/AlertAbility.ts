import UIAbility from '@ohos.app.ability.UIAbility';

export default class AlertAbility extends UIAbility {
  onCreate(want, launchParam): void {
    console.info('[Demo] MainAbility onCreate');
    globalThis.abilityWant = want;
    globalThis.context = this.context;
  }

  onDestroy(): void {
    console.info('[Demo] MainAbility onDestroy');
  }

  onWindowStageCreate(windowStage): void {
    // Main window is created, set main page for this ability
    console.info('[Demo] MainAbility onWindowStageCreate');

    windowStage.setUIContent(this.context, 'pages/alert', null);
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    console.info('[Demo] MainAbility onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    console.info('[Demo] MainAbility onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    console.info('[Demo] MainAbility onBackground');
  }
};
