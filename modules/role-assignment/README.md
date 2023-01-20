# Role Assignment
This module will create a role assignment using built-in roles or by providing your own role definition id.

**NOTE**: Deployments default to a subscription scope and can be updated as required. 

## Usage

### Example 1 - Role assignment using built-in roles
``` bicep
targetScope = 'subscription'

param deploymentName string = 'roleAssignment${utcNow()}'

module roleAssignment './role-assignment.bicep' = {
  name: deploymentName
  params: {
    name: guid('myroleassignment')
    principalId: '5a7cbf33-2f52-42b4-9e51-a1e65b3207a6'
    builtinRole: 'Contributor'
  }
}
```

### Example 2 - Role assignment using your own role definition id
``` bicep
targetScope = 'subscription'

param deploymentName string = 'roleAssignment${utcNow()}'

module roleAssignment './role-assignment.bicep' = {
  name: deploymentName
  params: {
    name: guid('myroleassignment')
    principalId: '5bd020c8-048b-4eb7-b917-e446528dd9b4'
    builtinRole: 'Custom'
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/d1e64988-9f2a-451c-adbe-2cc256ceff7c'
  }
}
```