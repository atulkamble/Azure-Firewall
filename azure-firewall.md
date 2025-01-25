https://learn.microsoft.com/en-us/azure/firewall/tutorial-firewall-deploy-portal-policy
https://learn.microsoft.com/en-us/azure/firewall/premium-deploy

Troubleshoot - ipconfig /flushdns

1. Create Resource Group

Test-FW-RG

2. Create a VNet

Test-FW-VN

3. Select Premium with Policy

4. Add Subnet Workload-SN

Workload-SN
10.0.2.0/24

5. Create a virtual machine

Windows Server 2019 Datacenter

Srv-Work

no ip, no inbound rules for Srv-Work

6. Deploy the firewall and policy

Test-FW-VN-firewall-policy

7. Create a default route 

All Services >> Networking >> Route Table

Route Table Name - fw-dg

Route-Table >> Setting >> Subnet >> Associate >> Workload-SN


8 . Routes 

Route Name: fw-dg
Destination - IP Addresses
Next Hop - Virtual Appliances
Enter Private IP of Firewall (noted previously) 10.0.1.4

9. Configure an application rule

Open Test-FW-VN-firewall-policy | Application rules

Rule Name - App-Coll01
Priority - 200
Allow-Google
Source - 10.0.2.0/24
http, https 
www.google.com

10. Configure a network rule

Rule Collection Type - Network
Net-Coll01
Name - Allow-DNS
DefaultNetworkRuleCollectionGroup
Source - 10.0.2.0/24
200
UDP - 53
IP Addresses
Destination - 209.244.0.3,209.244.0.4

11. Configure a DNAT rule

Test-FW-VN-firewall-policy | DNAT rules

Name - RDP

DefaultDnatRuleCollectionGroup

Source - *

TCP - 3389

Destination - firewall public IP address

172.191.106.95

For Translated type, select IP Address.
For Translated address, enter the Srv-work private IP address. - 10.0.0.4

For Translated port, enter 3389.


12. Change the primary and secondary DNS address for the Srv-Work network interface

srv-work457_z1 | DNS servers

Under Settings, select DNS servers.
Under DNS servers, select Custom.
Enter 209.244.0.3 in the Add DNS server text box, and 209.244.0.4 in the next text box.
Select Save.

13. Restart VM & note details for RDP through firewall public ip 


14. Test the firewall

Connect a remote desktop to firewall public IP address and sign in to the Srv-Work virtual machine.

open firewall public-ip 172.191.106.95
172.191.106.95

Enter Username, password

atul 
LEJ@5



Open Microsoft Edge and browse to https://www.google.com.

Select OK > Close on the Internet Explorer security alerts.

You should see the Google home page.

Browse to https://www.microsoft.com.

You should be blocked by the firewall.

So now you've verified that the firewall rules are working:

You can browse to the one allowed FQDN, but not to any others.
You can resolve DNS names using the configured external DNS server.
































