targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Virtual network name')
param vnetName string = 'MyVNet'

@description('Address space for the virtual network')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('CIDR for Azure Firewall subnet (must be named AzureFirewallSubnet)')
param firewallSubnetPrefix string = '10.0.1.0/24'

@description('CIDR for frontend subnet')
param frontendSubnetPrefix string = '10.0.2.0/24'

@description('CIDR for backend subnet')
param backendSubnetPrefix string = '10.0.3.0/24'

@description('Name of the Azure Firewall')
param firewallName string = 'MyFirewall'

@description('Azure Firewall SKU tier')
@allowed([
  'Standard'
  'Premium'
])
param firewallSkuTier string = 'Standard'

@description('Name for the public IP assigned to the firewall')
param firewallPublicIpName string = 'FirewallPublicIP'

@description('Firewall policy name')
param firewallPolicyName string = 'MyFirewallPolicy'

@description('Application rule collection priority (100-65000)')
@minValue(100)
@maxValue(65000)
param applicationRulePriority int = 100

@description('Network rule collection priority (100-65000)')
@minValue(100)
@maxValue(65000)
param networkRulePriority int = 200

@description('Fully qualified domain names allowed for outbound web traffic')
param allowedFqdns array = [
  'www.google.com'
  'www.microsoft.com'
]

@description('CIDRs allowed as sources for firewall rules')
param workloadSourceCidrs array = [
  frontendSubnetPrefix
  backendSubnetPrefix
]

@description('CIDRs allowed as network rule destinations (typically backend subnet)')
param backendDestinationCidrs array = [
  backendSubnetPrefix
]

@description('Route table name for directing traffic through the firewall')
param routeTableName string = 'MyRouteTable'

@description('Name of the default route to the firewall')
param defaultRouteName string = 'RouteToFirewall'

var firewallSubnetName = 'AzureFirewallSubnet'
var frontendSubnetName = 'FrontendSubnet'
var backendSubnetName = 'BackendSubnet'

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

resource azureFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: firewallSubnetName
  parent: vnet
  properties: {
    addressPrefix: firewallSubnetPrefix
  }
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: firewallPublicIpName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-11-01' = {
  name: firewallPolicyName
  location: location
  properties: {
    sku: {
      tier: firewallSkuTier
    }
  }
}

resource appRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  name: 'ApplicationRules'
  parent: firewallPolicy
  properties: {
    priority: applicationRulePriority
    ruleCollections: [
      {
        name: 'AllowWebTraffic'
        priority: applicationRulePriority
        action: {
          type: 'Allow'
        }
        ruleCollectionType: 'ApplicationRuleCollection'
        rules: [
          {
            name: 'AllowHTTPandHTTPS'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: workloadSourceCidrs
            targetFqdns: allowedFqdns
          }
        ]
      }
    ]
  }
}

resource networkRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  name: 'NetworkRules'
  parent: firewallPolicy
  properties: {
    priority: networkRulePriority
    ruleCollections: [
      {
        name: 'AllowSubnetTraffic'
        priority: networkRulePriority
        action: {
          type: 'Allow'
        }
        ruleCollectionType: 'NetworkRuleCollection'
        rules: [
          {
            name: 'SubnetToSubnet'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: workloadSourceCidrs
            destinationAddresses: backendDestinationCidrs
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-11-01' = {
  name: firewallName
  location: location
  sku: {
    name: 'AZFW_VNet'
    tier: firewallSkuTier
  }
  properties: {
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'azureFirewallIpConfiguration'
        properties: {
          publicIPAddress: {
            id: firewallPublicIp.id
          }
          subnet: {
            id: azureFirewallSubnet.id
          }
        }
      }
    ]
  }
  dependsOn: [
    appRules
    networkRules
  ]
}

resource routeTable 'Microsoft.Network/routeTables@2023-11-01' = {
  name: routeTableName
  location: location
  properties: {
    routes: [
      {
        name: defaultRouteName
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
  dependsOn: [
    firewall
  ]
}

resource frontendSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: frontendSubnetName
  parent: vnet
  properties: {
    addressPrefix: frontendSubnetPrefix
    routeTable: {
      id: routeTable.id
    }
  }
}

resource backendSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: backendSubnetName
  parent: vnet
  properties: {
    addressPrefix: backendSubnetPrefix
    routeTable: {
      id: routeTable.id
    }
  }
}

output firewallPublicIpAddress string = firewallPublicIp.properties.ipAddress
output firewallPrivateIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPolicyId string = firewallPolicy.id
output routeTableId string = routeTable.id
output vnetId string = vnet.id
