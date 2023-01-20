@description('Log Analytics Workspace ID')
param  logAnalyticsId string

@description('Log Analytics Workspace Name')
param logAnalyticsName string

@description('Location')
param location string

var updateManagementName = 'Updates(${logAnalyticsName})'

resource update 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: updateManagementName
  location: location
  properties: {
    workspaceResourceId: logAnalyticsId
  }
  plan: {
    name: updateManagementName
    publisher: 'Microsoft'
    product: 'OMSGallery/Updates'
    promotionCode: ''
  }
}
