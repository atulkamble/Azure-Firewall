## 🧩 Logical Architecture (Text Diagram)

```
                    Internet
                        |
                        |
                +----------------+
                |  Azure Firewall|
                |   (Test-FW01)  |
                | Public + Private IP
                +----------------+
                        |
          Default Route (0.0.0.0/0)
                        |
        --------------------------------
        |                              |
+------------------+        +--------------------+
| AzureFirewallSubnet |      |   Workload-SN     |
|  (10.0.0.0/26)      |      |  (10.0.2.0/24)    |
|  Firewall lives here|      |  Ubuntu VM        |
+------------------+        |  (Srv-Work)        |
                             |  No Public IP     |
                             +--------------------+
                                        |
                                        |
                              +------------------+
                              | Azure Bastion    |
                              | (10.0.4.0/26)    |
                              | Secure SSH/RDP   |
                              +------------------+
```

---

## 🔐 Traffic Flow Explanation

### 1️⃣ Outbound Traffic

```
Srv-Work VM
   ↓
User Defined Route (0.0.0.0/0)
   ↓
Azure Firewall
   ↓
Internet (Allowed FQDNs only)
```

✔ Allowed: `www.google.com`
❌ Blocked: `www.microsoft.com`

---

### 2️⃣ DNS Resolution

```
Srv-Work VM
   ↓
Azure Firewall
   ↓
External DNS (209.244.0.3 / 209.244.0.4)
```

✔ DNS works only via allowed network rules (UDP 53)

---

### 3️⃣ Secure VM Access

```
Admin
  ↓
Azure Portal
  ↓
Azure Bastion
  ↓
Srv-Work VM (SSH)
```

✔ No public IP on VM
✔ No inbound NSG exposure

---

## 🧱 Key Azure Components Used

| Component                     | Purpose                          |
| ----------------------------- | -------------------------------- |
| **Azure Firewall**            | Central outbound traffic control |
| **AzureFirewallSubnet (/26)** | Mandatory subnet for firewall    |
| **Workload-SN**               | Application / VM subnet          |
| **Route Table (UDR)**         | Forces traffic via firewall      |
| **Application Rules**         | FQDN-based filtering             |
| **Network Rules**             | IP/Port filtering (DNS)          |
| **Azure Bastion**             | Secure management access         |

---

## 🎯 Best Practice Note (For Production)

> **Recommended Model:**
> **Hub-and-Spoke Architecture**

* Firewall in **Hub VNet**
* Workloads in **Spoke VNets**
* Peering between Hub ↔ Spokes
* Centralized security & routing

---
