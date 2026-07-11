# 🔥 Azure Firewall – Complete Practice & Architecture Guide

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

## ⚙️ 3. Deployment Steps (Portal)

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

### Subnets:

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

### Create Route Table 
```
name: FW-table 
Settings >> Subnets >> Associate >> Select FirewallSubnet
```
---

## 🔁 4. Routing (IMPORTANT)

### Default Route Configuration

```
Destination: 0.0.0.0/0
Next Hop: Virtual Appliance
Next Hop IP: Firewall Private IP
```

👉 Ensures all traffic goes via firewall

📖 Only one default route is required 

---

## 🔐 5. Firewall Rules

### 🔹 Application Rule (FQDN Based)

```
Allow → www.google.com
Source: 10.0.2.0/24
Protocol: HTTP, HTTPS
```

✔ Use case: Website filtering

---

### 🔹 Network Rule (IP Based)

```
Allow DNS
Destination: 209.244.0.3, 209.244.0.4
Port: 53
Protocol: UDP
```

✔ Use case: DNS / backend services

---

### 🔹 Rule Processing Order

1. NAT Rules
2. Network Rules
3. Application Rules

---

## 🔍 6. Testing

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
