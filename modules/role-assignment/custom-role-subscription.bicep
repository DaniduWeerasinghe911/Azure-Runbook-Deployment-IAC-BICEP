targetScope = 'subscription'

@description('Array of actions for the roleDefinition')
param actions array = [
  'Microsoft.Resources/subscriptions/resourceGroups/read'
]

@description('Array of notActions for the roleDefinition')
param notActions array = []

@description('Friendly name of the role definition')
param roleName string = 'Custom Role - RG Reader'

@description('Subscription Id to Assign')
param subscriptionId string

@description('Detailed description of the role definition')
param roleDescription string = 'Subscription Level Deployment of a Role Definition'

var roleDefName = guid(subscription().id, string(actions), string(notActions))

resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: roleDefName
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'customRole'
    permissions: [
      {
        actions: actions
        notActions: notActions
      }
    ]
    assignableScopes: [
      subscriptionId
    ]
  }
}


output roleDefId string = roleDef.id
