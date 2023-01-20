# Automation Account
This module will create an automation account with a system assigned managed identity and import modules and runbooks.

## Usage

### Example 1 - Automation account with no modules or runbooks imported
``` bicep
param deploymentName string = 'automationAccount${utcNow()}'

module automationAccount './automation-account.bicep' = {
  name: deploymentName  
  params: {
    autoAccountName: 'MyAutomationAccount'
  }
}
```

### Example 2 - Automation account with modules imported
``` bicep
param deploymentName string = 'automationAccount${utcNow()}'

module automationAccount './automation-account.bicep' = {
  deploymentName: deploymentName  
  params: {
    autoAccountName: 'MyAutomationAccount'
    modules: [
      {
        name: 'Az.Accounts'
        version: 'latest'
        uri: 'https://www.powershellgallery.com/api/v2/package'
      }
    ]    
  }
}
```

### Example 3 - Automation account with modules and runbook imported
``` bicep
param deploymentName string = 'automationAccount${utcNow()}'

module automationAccount './automation-account.bicep' = {
  name: deploymentName  
  params: {
    autoAccountName: 'MyAutomationAccount'
    modules: [
      {
        name: 'Az.Accounts'
        version: 'latest'
        uri: 'https://www.powershellgallery.com/api/v2/package'
      }
    ]
    runbooks: [
      {
        runbookName: 'MyRunbook'
        runbookUri: 'https://raw.githubusercontent.com/azure/azure-quickstart-templates/master/<some-repo>/scripts/<some-script>.ps1'
        runbookType: 'PowerShell'
        logProgress: true
        logVerbose: false
      }
    ]        
  }
}
```

### Example 4 - Automation account with diagnostic logs and delete lock enabled
``` bicep
param deploymentName string = 'automationAccount${utcNow()}'

var tags = {
  Purpose: 'Sample Bicep Template'
  Environment: 'Development'
  Owner: 'sample.user@arinco.com.au'
}

var diagnostics = {
  name: 'diag-log'
  workspaceId: '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/example-dev-rg/providers/microsoft.operationalinsights/workspaces/example-dev-log'
  storageAccountId: '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/example-dev-rg/providers/microsoft.storage/storageAccounts/exampledevst'
  eventHubAuthorizationRuleId: 'Endpoint=sb://example-dev-ehns.servicebus.windows.net/;SharedAccessKeyName=DiagnosticsLogging;SharedAccessKey=xxxxxxxxx;EntityPath=example-hub-namespace'
  eventHubName: 'StorageDiagnotics'
  enableLogs: true
  enableMetrics: false
  retentionPolicy: {
    days: 0
    enabled: false
  }
}

module automationAccount './automation-account.bicep' = {
  name: deploymentName  
  params: {
    tags: tags
    autoAccountName: 'MyAutomationAccount'
    enableResourceLock: true
    diagsettings: diagnostics 
  }
}
```