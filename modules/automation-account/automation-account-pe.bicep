// Private Endpoint for a AutomationAccount
@description('Name of the Resource for which to create the Private Endpoint')
param resourceName string

@description('Resource Id of the Resource for which to create the Private Endpoint')
param id string

@description('AutomationAccount Private Endpoint types')
param type string

@description('Location of the resource.')
param location string = resourceGroup().location

@description('Resource ID of the subnet that will host Private Endpoint.')
param subnetId string

@description('Resource Group of the Private DNS Zone Group to host Private Endpoint entry')
param dnsZoneResourceGroup string

@description('SubscriptionId of the Private DNS Zone Group to host Private Endpoint entry')
param dnsZoneSubscriptionId string

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: '${resourceName}-${type}-pe'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${resourceName}-${type}-plink'
        properties: {
          privateLinkServiceId: id
          groupIds: [
            type
          ]
        }
      }
    ]
  }
}

resource privateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${privateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.${type}.core.windows.net'
        properties: {
          privateDnsZoneId: resourceId(dnsZoneSubscriptionId,dnsZoneResourceGroup,'Microsoft.Network/privateDnsZones','privatelink.${type}.core.windows.net')
        }
      }
    ]
  }
}

// Output Resource Name and Resource Id as a standard to allow module referencing.
output name string = privateEndpoint.name
output id string = privateEndpoint.id
