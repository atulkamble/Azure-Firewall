# 🔥 Azure Firewall – Complete Practice & Architecture Guide

## ⚙️ Deployment Steps (Portal)

### Step 1: Create Resource Group

```
Name: Test-FW-RG
Region: West US
```

---

### Step 2: Create VNet + Subnets

```
VNet: Test-FW-VN
Address Space: 10.0.0.0/16
```

### Step 3: Subnets:

```
AzureFirewallSubnet → /26 (MANDATORY)
AzureFirewallManagementSubnet
Workload-SN → 10.0.2.0/24
```
---


### Step 4: Create VM

```
VM Name: Srv-Work
OS: Ubuntu 22.04
Subnet: Workload-SN
Public IP: None
```

---

### Step 5. Deploy Azure Firewall
```
Name: FW
Firewall SKU Tier: Standard
Firewall policy: policy
Choose a virtual network: Use existing
Public IP address: FW-pip
Management public IP address: FW-MG-pip
```
---

### Step 6: Create Route Table 
```
name: FW-table 
Settings >> Subnets >> Associate >> Select FirewallSubnet
```
---

### Step 7: Routing: Default Route Configuration (IMPORTANT)

```
Route name: route
Destination type: 0.0.0.0/0
Next hop type: Virtual Appliance
Next hop address: Firewall Private IP (example: 10.0.1.4)
```

👉 Ensures all traffic goes via firewall

📖 Only one default route is required 

---

## 🔐 Step 8: Firewall Rules

### 🔹 Application Rule (FQDN Based)

```
Azure Firewall policies >> policy >> Application Rule
name:  app-rule
Rule collection type: Application
Priority: 200
Rule collection action: Allow
Rule collection group: DefaultApplicationRuleCollectionGroup
name: allow-google
Source type: IP Address
Source: 10.0.2.0/24
Protocol: http, https
Destination Type: FQDN
Destination: www.google.com
```

✔ Use case: Website filtering

---

### 🔹 Step 9: Network Rule (IP Based)

```
Azure Firewall policies >> policy >> Network Rule
name:  net-rule
Rule collection type: Network
Priority: 200
Rule collection action: Allow
Rule collection group: DefaultNetworkRuleCollectionGroup
name: allow-DNS
Source type: IP Address
Source: 10.0.2.0/24
Protocol: UDP
Destination Ports: 53
Destination Type: IP address
Destination: 209.244.0.3, 209.244.0.4
```

✔ Use case: DNS / backend services

---

### 🔹 Rule Processing Order

1. NAT Rules
2. Network Rules
3. Application Rules

---

### Check Bastion 
```
VM >> Connect >> Connect Via Bastion 
username: azureuser 
password: your-vm-password
```
## VM Stop 
```
VM >> Network Settings >> Click on Network Inerface >> DNS Servers >> Custom
Primary	209.244.0.3
Secondary	209.244.0.4
```
>> Save

### Start VM 

## 🔍 Step 10: Testing

### DNS Test

```
nslookup www.google.com
```

---

### Application Test

```
curl https://www.google.com    → SUCCESS  
curl https://www.microsoft.com → FAIL  
```

✔ Confirms firewall working

---

## 🔐 7. Azure Bastion

* Secure VM access
* No public IP required

```
Subnet: AzureBastionSubnet (/26)
```

---

## 📚 Reference

👉 [https://learn.microsoft.com/en-us/azure/firewall/tutorial-firewall-deploy-portal](https://learn.microsoft.com/en-us/azure/firewall/tutorial-firewall-deploy-portal)

---

## 📌 1. What is Azure Firewall?

**Azure Firewall** is a **managed, cloud-based network security service** that protects Azure Virtual Networks.

👉 It provides:

* Application-level filtering (FQDN based)
* Network-level filtering (IP/Port/Protocol)
* Centralized security management

📖 Key concept:

> All traffic must be routed through the firewall to apply rules 

---

## 🏗️ 2. Architecture (Basic + Production)

### 🔹 Basic Architecture (Lab Setup)

![Image](https://learn.microsoft.com/en-us/azure/firewall/media/overview/firewall-basic-diagram.png)

![Image](https://techcommunity.microsoft.com/t5/s/gxcuf89792/images/bS00NDA0MDIxLUJXdWFQbw?revision=1)

![Image](https://learn.microsoft.com/en-us/azure/firewall/media/firewall-multi-hub-spoke/multi-hub-spoke-overall.png)

![Image](https://learn.microsoft.com/en-us/azure/route-server/media/route-injection-in-spokes/route-injection.png)

* 1 Virtual Network
* 2 Subnets:

  * **AzureFirewallSubnet** → Firewall deployed
  * **Workload-SN** → VM

✔ Traffic Flow:

```
VM → Route Table → Firewall → Internet
```

---

### 🔹 Production Architecture (Hub-Spoke)

![Image](https://learn.microsoft.com/en-us/azure/architecture/networking/architecture/_images/hub-spoke.png)

![Image](https://learn.microsoft.com/en-us/azure/firewall-manager/media/secure-cloud-network/secure-cloud-network.png)

![Image](https://miro.medium.com/1%2AZ0jG69He7OoEY230PFKOgw.jpeg)

![Image](https://learn.microsoft.com/en-us/azure/firewall/media/firewall-multi-hub-spoke/multi-hub-spoke-sd-wan-1.png)

* Firewall in **Hub VNet**
* Workloads in **Spoke VNets**
* Centralized security

---


## 📊 8. Azure Firewall Plans (Exam-Oriented)

| Feature             | Basic    | Standard | Premium    |
| ------------------- | -------- | -------- | ---------- |
| Use Case            | Dev/Test | Prod     | Enterprise |
| Application Rules   | ❌        | ✅        | ✅          |
| Network Rules       | ✅        | ✅        | ✅          |
| Threat Intelligence | ❌        | ✅        | ✅          |
| TLS Inspection      | ❌        | ❌        | ✅          |
| IDPS                | ❌        | ❌        | ✅          |

---

## 🚀 9. Key Features

* Application Filtering (FQDN)
* Network Filtering (IP/Port)
* DNAT (Inbound)
* SNAT (Outbound)

---

## ⚠️ 10. Points to Remember

✔ AzureFirewallSubnet must be **/26 minimum**
✔ Always configure **0.0.0.0/0 route**
✔ Firewall requires **dedicated subnet**
✔ Use **Hub-Spoke for production**
✔ Rules apply only if traffic routed via firewall
✔ Use NAT Gateway for **high SNAT scaling** 

---

## 🧠 11. Significance

* Centralized control
* Zero Trust ready
* Secure outbound/inbound filtering
* Enterprise-grade security


---

## 📌 Final Summary

Azure Firewall =
✔ Managed Security
✔ Layer 3–7 Filtering
✔ Central Traffic Control
✔ Scalable & Enterprise Ready
