@description('Location of the automation account')
param location string = resourceGroup().location

@description('Automation account name')
param autoAccountName string

@description('Automation account sku')
@allowed([
  'Free'
  'Basic'
])
param sku string = 'Basic'

@description('Modules to import into automation account')
@metadata({
  name: 'Module name'
  version: 'Module version or specify latest to get the latest version'
  uri: 'Module package uri, e.g. https://www.powershellgallery.com/api/v2/package'
})
param modules array = []

@description('Runbooks to import into automation account')
@metadata({
  runbookName: 'Runbook name'
  runbookUri: 'Runbook URI'
  runbookType: 'Runbook type: Graph, Graph PowerShell, Graph PowerShellWorkflow, PowerShell, PowerShell Workflow, Script'
  logProgress: 'Enable progress logs'
  logVerbose: 'Enable verbose logs'
  scheduleName: 'Runbook name'
  advancedSchedule: {}
  description: 'Runbook type: Graph, Graph PowerShell, Graph PowerShellWorkflow, PowerShell, PowerShell Workflow, Script'
  expiryTime: '9999-12-31T23:59:59.9999999+00:00'
  frequency: 'Enable verbose logs'
  interval: 1
  startTime: 'string'
  timeZone: 'Australia/Sydney'
})
param runbooks array = []

@description('Object containing resource tags.')
param tags object = {}

@description('Enable a Can Not Delete Resource Lock.  Useful for production workloads.')
param enableResourceLock bool = false

@description('Object containing diagnostics settings. If not provided diagnostics will not be set.')
@metadata({
  name: 'Diagnostic settings name'
  workspaceId: 'Log analytics resource id'
  storageAccountId: 'Storage account resource id'
  eventHubAuthorizationRuleId: 'EventHub authorization rule id'
  eventHubName: 'EventHub name'
  enableLogs: 'Enable logs'
  enableMetrics: 'Enable metrics'
  retentionPolicy: {
    days: 'Number of days to keep data'
    enabled: 'Enable retention policy'
  }
})
param diagSettings object = {}

resource automationAccount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: autoAccountName
  location: location
  tags: !empty(tags) ? tags : json('null')
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: sku
    }
  }
}

@batchSize(1) //processes modules in order to ensure no dependencies are missed
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

// Diagnostics
resource diagnostics 'Microsoft.insights/diagnosticsettings@2017-05-01-preview' = if (!empty(diagSettings)) {
  name: empty(diagSettings) ? 'dummy-value' : diagSettings.name
  scope: automationAccount
  properties: {
    workspaceId: empty(diagSettings.workspaceId) ? json('null') : diagSettings.workspaceId
    storageAccountId: empty(diagSettings.storageAccountId) ? json('null') : diagSettings.storageAccountId
    eventHubAuthorizationRuleId: empty(diagSettings.eventHubAuthorizationRuleId) ? json('null') : diagSettings.eventHubAuthorizationRuleId
    eventHubName: empty(diagSettings.eventHubName) ? json('null') : diagSettings.eventHubName

    logs: [
      {
        category: 'JobLogs'
        enabled: diagSettings.enableLogs
        retentionPolicy: empty(diagSettings.retentionPolicy) ? json('null') : diagSettings.retentionPolicy
      }
      {
        category: 'JobStreams'
        enabled: diagSettings.enableLogs
        retentionPolicy: empty(diagSettings.retentionPolicy) ? json('null') : diagSettings.retentionPolicy
      }
      {
        category: 'DscNodeStatus'
        enabled: diagSettings.enableLogs
        retentionPolicy: empty(diagSettings.retentionPolicy) ? json('null') : diagSettings.retentionPolicy
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: diagSettings.enableMetrics
        retentionPolicy: empty(diagSettings.retentionPolicy) ? json('null') : diagSettings.retentionPolicy
      }
    ]
  }
}

// Resource Lock
resource deleteLock 'Microsoft.Authorization/locks@2016-09-01' = if (enableResourceLock) {
  name: '${autoAccountName}-delete-lock'
  scope: automationAccount
  properties: {
    level: 'CanNotDelete'
    notes: 'Enabled as part of IaC Deployment'
  }
}

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

// Output Resource Name and Resource Id as a standard to allow module referencing.
output name string = automationAccount.name
output id string = automationAccount.id
output systemIdentityPrincipalId string = automationAccount.identity.principalId
