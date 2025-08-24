Awesome—here’s an end-to-end **Azure CLI practice script** that stands up a **Premium (policy-based) Azure Firewall** in a single VNet, deploys a Windows VM **without a public IP**, wires up **UDR**, and configures **App/Network/DNAT** rules to exactly match your lab (allow `www.google.com`, DNS to `209.244.0.3/4`, DNAT RDP to the VM). It’s safe to paste in a `bash` shell (Cloud Shell works great).

> **What you get**
>
> * RG, VNet (`AzureFirewallSubnet` + `Workload-SN`)
> * Public IP + Premium Azure Firewall
> * Firewall Policy with **App**, **Network**, **DNAT** rules
> * Route table sending `0.0.0.0/0` to firewall private IP
> * Windows Server 2019 VM (no public IP)
> * NSG to allow inbound RDP **only via DNAT** (allow VM NIC RDP)
> * Optional: set VM NIC DNS servers to `209.244.0.3, 209.244.0.4`
> * Handy outputs + clean-up script

---

### 0) Prereqs

* Azure CLI logged in: `az login`
* Sub set: `az account set --subscription "<SUB_ID>"`
* Recommended CLI ≥ 2.50

---

### 1) Variables (edit as needed)

```bash
# ====== BASIC VARS ======
LOCATION="eastus"
RG="Test-FW-RG"

VNET_NAME="Test-FW-VN"
VNET_CIDR="10.0.0.0/16"
FW_SUBNET_NAME="AzureFirewallSubnet"
FW_SUBNET_CIDR="10.0.1.0/26"
WK_SUBNET_NAME="Workload-SN"
WK_SUBNET_CIDR="10.0.2.0/24"

FW_NAME="test-fw-premium"
FW_PIP_NAME="test-fw-pip"
FW_SKU_TIER="Premium"         # Premium | Standard
FW_POLICY_NAME="Test-FW-VN-firewall-policy"

# ====== VM VARS ======
VM_NAME="Srv-Work"
VM_ADMIN="atul"
VM_PASS='LutaElbmakJ@555'     # For labs only; use a secure secret in real use
VM_SIZE="Standard_DS1_v2"
VM_IMAGE="MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest"
NIC_NAME="${VM_NAME}-nic"
NSG_NAME="${VM_NAME}-nsg"

# ====== ROUTING ======
RT_NAME="fw-dg"
ROUTE_NAME="fw-dg"
# Route all to firewall (we'll fill firewall private IP later)

# ====== DNS OPTION (external resolvers) ======
USE_CUSTOM_DNS="true"         # set to "false" to skip
DNS1="209.244.0.3"
DNS2="209.244.0.4"

# ====== RULES ======
APP_RC_GRP="DefaultApplicationRuleCollectionGroup"
APP_RC_NAME="App-Coll01"
APP_RC_PRIORITY=200

NET_RC_GRP="DefaultNetworkRuleCollectionGroup"
NET_RC_NAME="Net-Coll01"
NET_RC_PRIORITY=200

DNAT_RC_GRP="DefaultDnatRuleCollectionGroup"
DNAT_RC_NAME="RDP-DNAT"
DNAT_RC_PRIORITY=200

ALLOW_FQDN="www.google.com"
ALLOW_PROTOCOLS="http=https"  # CLI expects proto mapping for app rules; http=https enables both

# Will be set dynamically:
FW_PRIVATE_IP=""
FW_PUBLIC_IP=""
```

---

### 2) Create RG, VNet, subnets

```bash
set -euo pipefail

echo "[1/9] Create RG..."
az group create -n "$RG" -l "$LOCATION" -o none

echo "[2/9] Create VNet & subnets..."
az network vnet create \
  -g "$RG" -n "$VNET_NAME" \
  --address-prefixes "$VNET_CIDR" \
  --subnet-name "$WK_SUBNET_NAME" \
  --subnet-prefixes "$WK_SUBNET_CIDR" -o none

az network vnet subnet create \
  -g "$RG" --vnet-name "$VNET_NAME" \
  -n "$FW_SUBNET_NAME" --address-prefixes "$FW_SUBNET_CIDR" -o none
```

---

### 3) Create a **Standard, Static** Public IP and **Premium** Firewall

```bash
echo "[3/9] Create public IP for firewall..."
az network public-ip create -g "$RG" -n "$FW_PIP_NAME" \
  --sku Standard --allocation-method Static -o none

echo "[4/9] Create Premium Azure Firewall (empty, policy will be attached)..."
az network firewall create \
  -g "$RG" -n "$FW_NAME" \
  --sku AZFW_VNet \
  --tier "$FW_SKU_TIER" \
  -o none

echo "[5/9] Attach IP config to firewall..."
az network firewall ip-config create \
  -g "$RG" -f "$FW_NAME" \
  -n "fw-ipconfig" \
  --public-ip-address "$FW_PIP_NAME" \
  --vnet-name "$VNET_NAME" -o none

echo "[6/9] Fetch firewall IPs..."
FW_PRIVATE_IP=$(az network firewall show -g "$RG" -n "$FW_NAME" --query "ipConfigurations[0].privateIpAddress" -o tsv)
FW_PUBLIC_IP=$(az network public-ip show -g "$RG" -n "$FW_PIP_NAME" --query "ipAddress" -o tsv)
echo "    Firewall private IP: $FW_PRIVATE_IP"
echo "    Firewall public  IP: $FW_PUBLIC_IP"
```

---

### 4) Create **Firewall Policy** and rule collection groups (App, Network, DNAT)

```bash
echo "[7/9] Create firewall policy (Premium-compatible)..."
az network firewall policy create -g "$RG" -n "$FW_POLICY_NAME" -o none

echo "Attach policy to the firewall..."
az network firewall update -g "$RG" -n "$FW_NAME" --firewall-policy "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG/providers/Microsoft.Network/firewallPolicies/$FW_POLICY_NAME" -o none

# ---- Application rules: allow only www.google.com (HTTP/HTTPS) from 10.0.2.0/24
echo "Create App rule collection group (if not exists) and add collection..."
az network firewall policy rule-collection-group create \
  -g "$RG" --policy-name "$FW_POLICY_NAME" \
  -n "$APP_RC_GRP" --priority "$APP_RC_PRIORITY" >/dev/null 2>&1 || true

az network firewall policy rule-collection-group collection add-application-collection \
  -g "$RG" --policy-name "$FW_POLICY_NAME" --rcg-name "$APP_RC_GRP" \
  --name "$APP_RC_NAME" --collection-priority "$APP_RC_PRIORITY" --action Allow \
  --source-addresses "$WK_SUBNET_CIDR" \
  --protocols $ALLOW_PROTOCOLS \
  --target-fqdns "$ALLOW_FQDN" -o none

# ---- Network rules: allow UDP/53 to 209.244.0.3, 209.244.0.4
echo "Create Network rule collection group (if not exists) and add collection..."
az network firewall policy rule-collection-group create \
  -g "$RG" --policy-name "$FW_POLICY_NAME" \
  -n "$NET_RC_GRP" --priority "$NET_RC_PRIORITY" >/dev/null 2>&1 || true

az network firewall policy rule-collection-group collection add-network-collection \
  -g "$RG" --policy-name "$FW_POLICY_NAME" --rcg-name "$NET_RC_GRP" \
  --name "$NET_RC_NAME" --collection-priority "$NET_RC_PRIORITY" --action Allow \
  --rule-name "Allow-DNS" \
  --source-addresses "$WK_SUBNET_CIDR" \
  --destination-addresses "$DNS1" "$DNS2" \
  --destination-ports 53 --ip-protocols UDP -o none
```

> 💡 If you prefer **DNS Proxy** on Firewall: enable it on the policy and point the VM to the firewall’s private IP as DNS. For this lab we stick to public resolvers to mirror your steps.

---

### 5) Create **Windows VM** (no public IP) + NSG (allow RDP)

```bash
echo "[8/9] Create NSG allowing inbound RDP to VM NIC..."
az network nsg create -g "$RG" -n "$NSG_NAME" -o none
az network nsg rule create -g "$RG" --nsg-name "$NSG_NAME" -n "Allow-RDP" \
  --priority 1000 --access Allow --direction Inbound \
  --protocol Tcp --destination-port-ranges 3389 --source-address-prefixes "*" -o none
# For production, replace "*" with your client public IP or office IP.

echo "Create NIC for VM in Workload-SN (no public IP) and attach NSG..."
SUBNET_ID=$(az network vnet subnet show -g "$RG" --vnet-name "$VNET_NAME" -n "$WK_SUBNET_NAME" --query id -o tsv)
az network nic create -g "$RG" -n "$NIC_NAME" \
  --subnet "$SUBNET_ID" --network-security-group "$NSG_NAME" -o none

if [ "$USE_CUSTOM_DNS" = "true" ]; then
  echo "Set NIC custom DNS servers to $DNS1, $DNS2 ..."
  az network nic update -g "$RG" -n "$NIC_NAME" --dns-servers "$DNS1" "$DNS2" -o none
fi

echo "Create Windows Server 2019 VM (no public IP)..."
az vm create -g "$RG" -n "$VM_NAME" \
  --image "$VM_IMAGE" \
  --size "$VM_SIZE" \
  --admin-username "$VM_ADMIN" \
  --admin-password "$VM_PASS" \
  --nics "$NIC_NAME" \
  --public-ip-address "" -o none
```

---

### 6) **UDR**: route all outbound to firewall private IP

```bash
echo "[9/9] Create route table and route 0.0.0.0/0 via $FW_PRIVATE_IP ..."
az network route-table create -g "$RG" -n "$RT_NAME" -o none
az network route-table route create -g "$RG" --route-table-name "$RT_NAME" -n "$ROUTE_NAME" \
  --address-prefix "0.0.0.0/0" --next-hop-type VirtualAppliance --next-hop-ip-address "$FW_PRIVATE_IP" -o none

echo "Associate route table to Workload-SN..."
az network vnet subnet update -g "$RG" --vnet-name "$VNET_NAME" -n "$WK_SUBNET_NAME" \
  --route-table "$RT_NAME" -o none
```

---

### 7) **DNAT**: RDP to VM via firewall public IP

```bash
# Get VM private IP to use as translated address
VM_PRIV_IP=$(az network nic show -g "$RG" -n "$NIC_NAME" --query "ipConfigurations[0].privateIpAddress" -o tsv)
echo "VM private IP: $VM_PRIV_IP"

# Create DNAT rule collection group (if not exists) and add DNAT rule
az network firewall policy rule-collection-group create \
  -g "$RG" --policy-name "$FW_POLICY_NAME" \
  -n "$DNAT_RC_GRP" --priority "$DNAT_RC_PRIORITY" >/dev/null 2>&1 || true

az network firewall policy rule-collection-group collection add-nat-collection \
  -g "$RG" --policy-name "$FW_POLICY_NAME" --rcg-name "$DNAT_RC_GRP" \
  --name "$DNAT_RC_NAME" --collection-priority "$DNAT_RC_PRIORITY" --action Dnat \
  --rule-name "RDP" \
  --destination-addresses "$FW_PUBLIC_IP" \
  --destination-ports 3389 \
  --ip-protocols TCP \
  --translated-port 3389 \
  --translated-address "$VM_PRIV_IP" -o none
```

---

### 8) Outputs & test hints

```bash
echo "===================================================="
echo " Firewall Public IP (use this in RDP):  $FW_PUBLIC_IP"
echo " Firewall Private IP (UDR next-hop):    $FW_PRIVATE_IP"
echo " Workload Subnet:                       $WK_SUBNET_CIDR"
echo " VM Private IP:                         $VM_PRIV_IP"
echo "===================================================="
echo "RDP test: Connect to $FW_PUBLIC_IP and log into $VM_NAME"
echo "After login: open Edge -> https://www.google.com (allowed)"
echo "            open https://www.microsoft.com (blocked)"
echo "If DNS changed on NIC: run 'ipconfig /flushdns' inside VM."
```

---

## Clean-up script (optional)

```bash
#!/usr/bin/env bash
set -e
RG="Test-FW-RG"
echo "Deleting resource group $RG ..."
az group delete -n "$RG" --yes --no-wait
```

---

## Notes & tips

* **Subnets**: Firewall must live in `AzureFirewallSubnet` (we used `/26` per best practice).
* **NSGs**: Don’t attach NSGs to `AzureFirewallSubnet`. We attached one to the VM NIC to allow RDP post-DNAT.
* **Policy order**: We used the default rule collection groups to keep it simple. Priorities are set to `200` across types (they’re independent groups).
* **Troubleshooting**:

  * If RDP fails: confirm DNAT points to the **VM private IP**, NSG allows `3389`, and your client can reach the firewall public IP.
  * If browsing is blocked entirely: verify the **UDR** is associated and points to the firewall private IP.
  * If DNS fails: confirm the **Network rule** (UDP/53) and that the NIC uses the expected DNS servers; then `ipconfig /flushdns`.

Want a **Bicep/ARM** or **PowerShell** variant too? I can drop those in the same structure.
