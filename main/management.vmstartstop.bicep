targetScope = 'subscription'

@description('Target geographical location')
param location string = 'australiaeast'

@description('Target resource group')
param logRgName string = 'rg-automation-aue'

@description('Automation Account Name')
param automationAccountName string = 'aa-vmstartstop-aue'

@description('Subscription ID to enable start stop permission')
param subscriptionToEnable string = subscription().subscriptionId

@description('Automation Account SKU')
param automationAccountSKU string = 'Basic'

@description('Automation Account Tags')
param automationAccountTags object = {

}
@description('Runbooks to import into automation account')
@metadata({
  runbookName: 'Runbook name'
  runbookUri: 'Runbook URI'
  runbookType: 'Runbook type: Graph, Graph PowerShell, Graph PowerShellWorkflow, PowerShell, PowerShell Workflow, Script'
  logProgress: 'Enable progress logs'
  logVerbose: 'Enable verbose logs'
})
param runbooks array = [
  {
    runbookName: 'dev-vm-start-shutdown'
    runbookUri: 'https://dckloudsadscmgmtaue001.blob.core.windows.net/aar-vmstartstop/aar-vmAutoStartStop.ps1'
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    scheduleName: 'Start-VM-Schdule'
    advancedSchedule:null
    description: 'Start VM Schdule'
    expiryTime: '9999-12-31T23:59:59.9999999+00:00'
    frequency: 'Hour'
    interval: 1
    startTime: dateTimeAdd(utcNow(), 'PT1H')
    timeZone: 'Australia/Sydney'
  }
]


//LAW Resource Group
resource rgLog 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: logRgName
  location: location
}


//VM Start Shutdown Automation Account
module automationAccountvmstartshutdown '../modules/automation-account/automation-account.bicep' = {
  scope: resourceGroup(rgLog.name)
  name: replace(automationAccountName,'replace','dev-vmmgmt')
  params: {
    autoAccountName: replace(automationAccountName,'replace','dev-vmmgmt')
    sku: automationAccountSKU
    location: location
    tags: automationAccountTags
    runbooks:runbooks

  }
}

//Custom Permission for the automation managed service account
module customRole '../modules/role-assignment/custom-role-subscription.bicep' = {
  name: 'Start-Stop-Custom-Role'
  scope:subscription(subscriptionToEnable)
  params:{
    roleName:'VM Maintanance'
    roleDescription:'VM Start Stop Permission Role'
    actions:[
      'Microsoft.Compute/*/read'
      'Microsoft.Compute/virtualMachines/start/action'
      'Microsoft.Compute/virtualMachines/restart/action'
      'Microsoft.Compute/virtualMachines/deallocate/action'
    ]
    subscriptionId:'/subscriptions/${subscriptionToEnable}'
  }
}

module customRoleAssignment '../modules/role-assignment/role-assignment-resource.bicep' = {
  name: 'Assign-Custom-Role'
  scope:subscription(subscriptionToEnable)
  params: {
    builtinRole: 'Custom'
    name: 'Vm-Start-Stop'
    principalId: automationAccountvmstartshutdown.outputs.systemIdentityPrincipalId
    roleDefinitionId:customRole.outputs.roleDefId
  }
}
