import account_distributedAccount from '@ohos.account.distributedAccount';
import account_osAccount from '@ohos.account.osAccount';
import dlpPermission from '@ohos.dlpPermission';

var TAG = "[DLPManager]"
async function getDistributedAccountInfo() : Promise<account_distributedAccount.DistributedInfo> {
  var distAbility = account_distributedAccount.getDistributedAccountAbility()
  return distAbility.queryOsAccountDistributedInfo()
}

async function getOsAccountInfo() : Promise<account_osAccount.OsAccountInfo> {
  var accountMgr = account_osAccount.getAccountManager()
  return accountMgr.queryCurrentOsAccount()
}

async function getUserId() : Promise<number> {
  var accountMgr = account_osAccount.getAccountManager()
  return accountMgr.getOsAccountLocalIdFromProcess()
}

async function getDomainId() : Promise<account_osAccount.OsAccountInfo> {
  var accountMgr = account_osAccount.getAccountManager()
  return accountMgr.queryCurrentOsAccount()
}

function getAuthPerm(accountName, dlpProperty) : number {
  if (accountName == dlpProperty.ownerAccount) {
    return dlpPermission.AuthPermType.FULL_CONTROL
  }
  for (var i = 0; i < dlpProperty.authUsers.length; ++i) {
    var authUser = dlpProperty.authUsers[i]
    if (authUser.authAccount == accountName) {
      return authUser.authPerm
    }
  }
  return -1
}

function terminateSelfWithResult(resultCode: number, result: string) : void {
  var abilityResult = {
    resultCode: resultCode,
    want: {
      parameters: {
        result: result
      }
    }
  }
  globalThis.context.terminateSelfWithResult(abilityResult)
}

function startAlertAbility(title, message) {
  globalThis.context.startAbility({
    bundleName: "com.ohos.dlpmanager",
    abilityName: "AlertAbility",
    parameters: {
      title: title,
      message: message,
    }
  }, async (err, data) => {
    console.log(TAG + "start AlertAbility err: " + JSON.stringify(err))
    globalThis.context.terminateSelf()
  })
}

export {getDistributedAccountInfo, getOsAccountInfo, getUserId, getAuthPerm, terminateSelfWithResult, startAlertAbility}