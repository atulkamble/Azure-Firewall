# Azure Firewall Project

## Overview
Azure Firewall is a cloud-native network security service that protects Azure Virtual Network resources. This guide provides a comprehensive walkthrough for setting up Azure Firewall using the Azure Portal and deploying a secure network architecture. The implementation includes:

1. Setting up an Azure Virtual Network.
2. Creating Azure Firewall.
3. Configuring routes and rules.
4. Testing the configuration.
5. Automating deployment using Infrastructure as Code (IaC).

---

## Step 1: Prerequisites
1. **Azure Subscription**: Ensure you have an active Azure subscription.
2. **Resource Group**: Create a resource group to organize your resources.
   ```bash
   az group create --name FirewallResourceGroup --location eastus
   ```
3. **Azure CLI**: Install and configure the Azure CLI on your system.

---

## Step 2: Create a Virtual Network
1. **Create a Virtual Network** with three subnets:
   - **FrontendSubnet**: For public-facing resources.
   - **BackendSubnet**: For internal resources.
   - **AzureFirewallSubnet**: Dedicated subnet for Azure Firewall (mandatory naming).

// Create Resource Group named as FirewallResourceGroup
   ```bash
   az network vnet create \
       --resource-group FirewallResourceGroup \
       --name MyVNet \
       --address-prefix 10.0.0.0/16 \
       --subnet-name AzureFirewallSubnet \
       --subnet-prefix 10.0.1.0/24

   az network vnet subnet create \
       --resource-group FirewallResourceGroup \
       --vnet-name MyVNet \
       --name FrontendSubnet \
       --address-prefix 10.0.2.0/24

   az network vnet subnet create \
       --resource-group FirewallResourceGroup \
       --vnet-name MyVNet \
       --name BackendSubnet \
       --address-prefix 10.0.3.0/24
   ```

---

## Step 3: Deploy Azure Firewall
1. **Create a Public IP Address**:
   ```bash
   az network public-ip create \
       --resource-group FirewallResourceGroup \
       --name FirewallPublicIP \
       --sku Standard
   ```

2. **Deploy Azure Firewall**:
   ```bash
   az network firewall create \
       --resource-group FirewallResourceGroup \
       --name MyFirewall \
       --location eastus

   az network firewall ip-config create \
       --firewall-name MyFirewall \
       --resource-group FirewallResourceGroup \
       --name FWConfig \
       --public-ip-address FirewallPublicIP \
       --vnet-name MyVNet
   ```

---

## Step 4: Configure Firewall Rules
1. **Application Rule**: Allow HTTP/HTTPS traffic.
   ```bash
   az network firewall policy rule-collection-group rule-collection add-filter-collection \
       --policy-name MyFirewallPolicy \
       --resource-group FirewallResourceGroup \
       --rule-collection-group-name DefaultRuleCollectionGroup \
       --name AllowWebTraffic \
       --action Allow \
       --priority 100 \
       --rule-name AllowHTTPandHTTPS \
       --rule-type Application \
       --protocols Http=80 Https=443 \
       --source-addresses "*" \
       --target-fqdns "www.google.com" "www.microsoft.com"
   ```

2. **Network Rule**: Allow communication between subnets.
   ```bash
   az network firewall policy rule-collection-group rule-collection add-network-collection \
       --policy-name MyFirewallPolicy \
       --resource-group FirewallResourceGroup \
       --rule-collection-group-name DefaultRuleCollectionGroup \
       --name AllowSubnetTraffic \
       --action Allow \
       --priority 200 \
       --rule-name SubnetToSubnet \
       --rule-type Network \
       --protocols Any \
       --source-addresses 10.0.2.0/24 \
       --destination-addresses 10.0.3.0/24 \
       --destination-ports "*"
   ```

---

## Step 5: Route Traffic through Azure Firewall
1. **Create a Route Table** and associate it with subnets.
   ```bash
   az network route-table create \
       --resource-group FirewallResourceGroup \
       --name MyRouteTable

   az network route-table route create \
       --resource-group FirewallResourceGroup \
       --route-table-name MyRouteTable \
       --name RouteToFirewall \
       --address-prefix 0.0.0.0/0 \
       --next-hop-type VirtualAppliance \
       --next-hop-ip-address <FirewallPrivateIP>

   az network vnet subnet update \
       --resource-group FirewallResourceGroup \
       --vnet-name MyVNet \
       --name FrontendSubnet \
       --route-table MyRouteTable
   ```

---

## Step 6: Test Configuration
1. Deploy a Virtual Machine in the FrontendSubnet.
2. Deploy another Virtual Machine in the BackendSubnet.
3. Test connectivity through Azure Firewall by:
   - Accessing external websites from the Frontend VM.
   - Pinging the Backend VM from the Frontend VM.

---

## Step 7: Automate Deployment with Bicep
1. **Create a Bicep File** (azure-firewall.bicep):
   ```bicep
   resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
     name: 'FirewallResourceGroup'
     location: 'eastus'
   }

   resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
     name: 'MyVNet'
     location: rg.location
     properties: {
       addressSpace: {
         addressPrefixes: [
           '10.0.0.0/16'
         ]
       }
       subnets: [
         {
           name: 'AzureFirewallSubnet'
           properties: {
             addressPrefix: '10.0.1.0/24'
           }
         }
       ]
     }
   }

   resource firewall 'Microsoft.Network/azureFirewalls@2021-02-01' = {
     name: 'MyFirewall'
     location: rg.location
     properties: {
       sku: {
         name: 'AZFW_VNet'
         tier: 'Standard'
       }
     }
   }
   ```

2. **Deploy Using Azure CLI**:
   ```bash
   az deployment group create \
       --resource-group FirewallResourceGroup \
       --template-file azure-firewall.bicep
   ```

---

## Conclusion
You have successfully deployed and configured Azure Firewall. This secure architecture ensures controlled and monitored traffic between Azure resources. Extend this setup further by integrating with Azure Monitor for logging and diagnostics.

