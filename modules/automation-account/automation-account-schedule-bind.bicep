param schedulingName string

resource symbolicname 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = {
  name: 'string'
  parent: resourceSymbolicName
  properties: {
    parameters: {}
    runbook: {
      name: 'string'
    }
    runOn: 'string'
    schedule: {
      name: 'string'
    }
  }
}
