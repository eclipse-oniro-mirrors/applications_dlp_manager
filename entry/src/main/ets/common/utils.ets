import account_distributedAccount from '@ohos.account.distributedAccount';
import account_osAccount from '@ohos.account.osAccount';
import Constants from '../common/constant'
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

function getAlertMessage(err, defaultTitle, defaultMessage) {
  switch (err.code) {
    case Constants.ERR_JS_CREDENTIAL_TIMEOUT:
      return { 'title': Constants.TITLE_SERVICE_ERROR, 'msg': Constants.MESSAGE_DLP_CREDENTIAL_TIMEOUT_ERROR }
    case Constants.ERR_JS_CREDENTIAL_SERVER_ERROR:
      return { 'title': Constants.TITLE_SERVICE_ERROR, 'msg': Constants.MESSAGE_DLP_CREDENTIAL_SERVER_ERROR }
      break
    case Constants.ERR_JS_NOT_DLP_FILE:
      return { 'title': Constants.TITLE_APP_DLP_ERROR, 'msg': Constants.MESSAGE_APP_FILE_PARAM_ERROR }
      break
    case Constants.ERR_JS_CREDENTIAL_TIMEOUT:
      return { 'title': Constants.TITLE_APP_ERROR, 'msg': Constants.MESSAGE_APP_NO_ACCOUNT_ERROR }
      break
    case Constants.ERR_JS_DLP_FILE_READ_ONLY:
      return { 'title': Constants.TITLE_OPERATE_DENY, 'msg': Constants.MESSAGE_DLP_READ_ONLY }
      break
    default:
      if (err.extra != undefined) {
        return {
          'title': Constants.TITLE_APP_VISIT_FILE_ERROR,
          'msg': Constants.MESSAGE_APP_NOT_HAVE_PERM_VISIT + err.extra
        }
      } else {
        return { 'title': defaultTitle, 'msg': defaultMessage }
      }
  }
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

export {getDistributedAccountInfo, getOsAccountInfo, getUserId, getAuthPerm, terminateSelfWithResult, startAlertAbility, getAlertMessage}