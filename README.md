[![Deploy to Azure](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FDaniduWeerasinghe911%2FAzure-Runbook-Deployment-IAC-BICEP%2Fmain%2Fmain%2Fazuredeploy.json)

# Azure-Runbook-Deployment-Bicep

## Introduction

Automation is a key component in many organizations' cloud strategy. Azure Automation allows you to automate the creation, deployment, and management of resources in your Azure environment. In this post, we will walk through the process of deploying an Automation Account with a Runbook and Schedule using Bicep, a new domain-specific language for deploying Azure resources.

## Intention

My intention at the end is to run a PowerShell script to start and shutdown Azure VMs based on tag values. PowerShell script that I have used is from below link. And two of me collogues (Michael Turnley and Saudh Mohomad helped to modify the PowerShell script

<IMG  src="https://blogger.googleusercontent.com/img/a/AVvXsEjs5AySS29KFY3OSCcx6vvcHaRCAan2W4fBRCLxi5fOnq8V08Qm78h6gcgInz8_jbmeVGy02VTb9ovfJOMpuYh7i-bsOWUPpdaOyDvM3w9-ssVV1aT6LUstgy6rZEQm5pluXztCMaFX580-OI9KeQBPDiLq1MTuyrtebL85m-mqIVo1xtnsDmUoPkiKag=w501-h321"/>

## Prerequisites
Before we begin, you will need the following:

1. An Azure subscription
1. The Azure CLI installed on your machine.
1. The Azure Bicep extension for the Azure CLI

## Creating the Automation Account

The first step in deploying an Automation Account with a Runbook and Schedule is to create the Automation Account itself. We will use Bicep to create the Automation Account and define its properties, such as the name and location.


```
resource automationAccountModules 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = [for module in modules: {
  parent: automationAccount
  name: module.name
  properties: {
    contentLink: {
      uri: module.version == 'latest' ? '${module.uri}/${module.name}' : '${module.uri}/${module.name}/${module.version}'
      version: module.version == 'latest' ? null : module.version
    }
  }
}]
```


## Creating the Runbook

Once the Automation Account is created, we can use it to create a Runbook. A Runbook is a collection of PowerShell or Python scripts that can be run to perform various tasks, such as starting or stopping VMs. We will use Bicep to create a simple PowerShell script that will write "Hello, World!" to the console.


```
resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = [for runbook in runbooks: {
  parent: automationAccount
  name: runbook.runbookName
  location: location
  properties: {
    runbookType: runbook.runbookType
    logProgress: runbook.logProgress
    logVerbose: runbook.logVerbose
    publishContentLink: {
      uri: runbook.runbookUri
    }
  }
}]
```



In this example, we are creating a PowerShell Runbook named 'myRunbook' and linking it to a script hosted on Github. We also set the Automation Account as a dependency for the Runbook.

## Creating the Schedule

Finally, we can use the Automation Account to create a Schedule. A Schedule allows us to define when the Runbook should be executed. We will use Bicep to create a Schedule that runs the Runbook every day at 12:00 PM.


```
resource automationSchedules 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = [for runbook in runbooks: {
  name: runbook.scheduleName
  parent: automationAccount
  properties: {
    advancedSchedule: runbook.advancedSchedule
    description: runbook.description
    expiryTime: runbook.expiryTime
    frequency: runbook.frequency
    interval: runbook.interval
    startTime: runbook.startTime
    timeZone: runbook.timeZone
  }
}]
```



## Attaching schedule into the runbook

Next what we need to do is attaching the runbook into the schedule, for that we will use the below bicep resource for it


```
resource jobSchdules 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' =[for i in range(0, length(runbooks)): {
  name: guid(runbooks[i].runbookName)
  parent: automationAccount
  properties: {
    parameters: {}
    runbook: {
      name: runbooks[i].runbookName
    }
    runOn: null
    schedule: {
      name: runbooks[i].scheduleName
    }
  }
  dependsOn:[
    automationSchedules
    runbook
  ]
}]
```


If you have notice I'm running all the resource modules in a for loop, it's because for me to able to deploy multiple run books at the same time or update or add new once harming others.

But for my solution I needed few more modules, those are for permission delegations. So you can find those in Bicep main file.


```
targetScope = 'subscription'

@description('Target geographical location')
param location string = 'australiaeast'

@description('Target resource group')
param logRgName string

@description('Automation Account Name')
param automationAccountName string

@description('Subscription ID to enable start stop permission')
param subscriptionToEnable string

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
module automationAccountvmstartshutdown '../modules/automation-account.bicep' = {
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
```



## Conclusion

In conclusion, Bicep is a powerful tool that can simplify the process of deploying Azure resources, including Automation Accounts with Runbooks and Schedules. By using Bicep, you can create clean, readable, and reusable code that can be easily deployed and managed. 

The ability to automate tasks and processes using Automation Accounts and Runbooks can save time and increase efficiency and scheduling them ensures that they run at the desired time. By following the steps outlined in this blog post, you should now have a better understanding of how to use Bicep to deploy Automation Accounts with Runbooks and Schedules in Azure.

If you want to use my above example, feel free to visit my GitHub link to get the full code. Also, by using this template I was able to deploy multiple runbooks.

