# How to setup an Ubuntu gateway for Windows network admins

> [!WARNING]
> These are NOT production-grade instructions. These steps are meant only to be used in a lab-like environment!

Items covered in this doc:
- Basic Ubuntu (Linux) multi-homed network.
- NAT4 (MASQUERADE).
- Linux network tuning in Hyper-V.

Optional components:

- tcgui for WAN emulation.
- KEA DHCP[v4].
- IPv6-mostly
  - KEA DHCPv6
  - BIND9 DNS server with DNS64 (NAT64 ready)
  - radvd for Router Advertisements to obtain the IPv6 gateway
  - jool NAT64

Future:
- BIND9 DNS over HTTPS server
- certbot for certificate creation

These instructions are designed for running Ubuntu as a Hyper-V VM.

Download the Ubuntu 24.04 server, manual server installation, from: https://ubuntu.com/download/server

Create a gen 2 VM using the ISO.

Open VM settings.

- Security
- Change the Secure Boot template to "Microsoft UEFI Certificate Authority"
- Enable all Integration Services
- Checkpoints: uncheck "Use automatic checkpoints"
- Adjust resources as needed

Start the VM and go through the Ubuntu server setup. 

- Username: gw
- Password: P@ssw0rd
- Install the OpenSSH server when prompted
- Install PowerShell when given a list of optional components

SSH to the server.

	ssh gw@<IP>
	
- Yes when asked about the fingerprint.
- Enter the gw password.
- You can get the IP address from Hyper-V Manager, or by logging into the Ubuntu VM. The IP will appear in the logon text.


Elevate to super user, enter password when prompted. The instructions assume you are always su.

	sudo su

Run these commands to update the server. Remember that everything in Linux/Unix is case sensitive.

	apt update && apt upgrade -y
		
Install required components for the lab. You can copy/paste the commands when using the SSH session in PowerShell/Windows Terminal.

	apt install iproute2 python3-flask bridge-utils net-tools iptables-persistent git -y

[Optional] Install mDNS. 
- This will allow you to ssh using <hostname>.local rather than hunting for the IP address of the gateway.
- mDNS will not work if the gateway is behind a Default Switch, it wil only work if the gateway is attached to an external vmSwitch.

```bash
snap install mdns
```

[Optional] Example ssh command with mDNS where the username is `gw` and the hostname is `gateway`.

```
ssh gw@gateway.local
```


Create a VM snapshot at this point in case something breaks when setting up the network routing.

Create a new NIC on the VM for the RED network. This should appear as eth1 when you run "ip addr" or "ip link". We will leave eth0 on DHCP connected to the public network.

Add a new NIC to the GW VM for the BLUE network. This should appear as eth2.

Run this command to get the name of the netplan config file.

	ls /etc/netplan/

In my installation the file name is 00-installer-config.yaml.

- A YAML file is a type of config file that uses white space (space, tab, etc.) to separate elements.
- Be careful with whitespaces when editing a YAML file.
- Remember that everything is case sensitive.

Edit the YAMl file found above.

```bash
nano /etc/netplan/<YAML file>
```

Example:

```bash
nano /etc/netplan/50-cloud-init.yaml
```

Use the arrow, home, and end keys, to position the cursor inside nano. Press enter to create a new line.

Edit the file so it looks something like this (spacing MUST be exact!):

- Change the name server (DNS) addresses to match your network configuration.
- The addresses may look differnt if you setup the IPs during the Ubuntu install, and that's fine.
- The order NICs may be different in your setup if you created all three NICs prior to Ubuntu setup. Adjust the config file accordingly.

```yaml
network:
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
    eth1:
      addresses: [10.1.0.1/24]
      nameservers:
        addresses: [192.168.1.1, 1.1.1.1]
    eth2:
      addresses: [10.2.0.1/24]
      nameservers:
        addresses: [192.168.1.1, 1.1.1.1]
  version: 2
```

Run this command to apply the change, then press Enter to accept the new config. The last output line should read "Configuration accepted." when it works.

	netplan try

Enable IP forwarding.

	sysctl -w net.ipv4.ip_forward=1
	sed -i '/net.ipv4.ip_forward/s/^#//' /etc/sysctl.conf
	sysctl -p

The sysctl command should return "net.ipv4.ip_forward = 1"

Ping 10.1.0.1 from GEARS-RX to confirm the IP is reachable.

```ping 10.1.0.1```

Ping 10.2.0.1 from GEARS-TX when complete to confirm reachability.

```ping 10.2.0.1```

Ping 10.2.0.2 from GEARS-RX to confirm routing/forwarding is working.

```ping 10.2.0.2```

Ping 10.1.0.2 from GEARS-TX to confirm routing/forwarding is working.

```ping 10.1.0.2```

Enable NATing on the GW to allow Internet access.

	iptables -t nat -A POSTROUTING -j MASQUERADE -o eth0
	iptables -t nat -A POSTROUTING -j MASQUERADE -o eth1
	iptables -t nat -A POSTROUTING -j MASQUERADE -o eth2
	iptables-save > /etc/iptables/rules.v4

- You should now be able to access Internet sites through the gateway.

Perform Hyper-V network tuning using these commands.

	touch /etc/sysctl.d/local.conf
	echo 'net.core.netdev_max_backlog=30000' >> /etc/sysctl.d/local.conf
	echo 'net.core.rmem_max=67108864' >> /etc/sysctl.d/local.conf
	echo 'net.core.wmem_max=67108864' >> /etc/sysctl.d/local.conf
	echo 'net.ipv4.tcp_wmem="4096 12582912 33554432"' >> /etc/sysctl.d/local.conf
	echo 'net.ipv4.tcp_rmem="4096 12582912 33554432"' >> /etc/sysctl.d/local.conf
	echo 'net.ipv4.tcp_max_syn_backlog=80960' >> /etc/sysctl.d/local.conf
	echo 'net.ipv4.tcp_slow_start_after_idle=0' >> /etc/sysctl.d/local.conf
	echo 'net.ipv4.tcp_tw_reuse=1' >> /etc/sysctl.d/local.conf
	echo 'net.ipv4.ip_local_port_range="10240 65535"' >> /etc/sysctl.d/local.conf
	echo 'net.ipv4.tcp_abort_on_overflow=1' >> /etc/sysctl.d/local.conf

Download and setup tcgui.

	git clone https://github.com/tum-lkn/tcgui.git
	mv ./tcgui /usr/local/bin/tcgui

Create and edit a systemd service file.

	nano /etc/systemd/system/tcgui.service

File contents:

```
[Unit]
After=network.service

[Service]
ExecStart=/usr/local/bin/tcgui.sh

[Install]
WantedBy=default.target
```


Ctrl+x to exit, type y when prompted to save.

Create and edit the script file.

	nano /usr/local/bin/tcgui.sh
 
File contents:

```sh
#!/bin/bash
 
python3 /usr/local/bin/tcgui/main.py --ip 10.1.0.1 --port 80
```

Ctrl+x to exit, type y when prompted to save.

Update file permissions and enable the service.

	chmod 744 /usr/local/bin/tcgui.sh
	chmod 664 /etc/systemd/system/tcgui.service
	systemctl daemon-reload
	systemctl enable tcgui.service
	

Reboot.

Make sure you can access tcgui via http://10.1.0.1 from a web browser on a lab VM after the reboot.


## [OPTIONAL] DHCPv4

These steps walk through the basics of setting up DHCP and NAT66.

[Install ISC KEA](https://documentation.ubuntu.com/server/how-to/networking/install-isc-kea/index.html) for DHCPv4 and DHCPv6. The Ubuntu install adds everything you need.

```sh
sudo apt install kea
```

Use the "configure with a random password" option during setup.

Rename the kea-dhcp4.conf file.

```sh
mv /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.original
```

Edit the kea-dhcp4.conf contents below to match your environment. 
- This file is only for a single interface, but can be expanded to handle both interfaces.
- Change `"interfaces": [ "eth1" ]` to `"interfaces": [ "eth1", "eth2" ]` to add both interfaces.
- Add `"interface": "ethX",` entries to the subnet matching eth1 and eth2, after the "id" line. Changing the X in ethX to the appropriate interface number or name.

```javascript
{
  "Dhcp4": {
        "interfaces-config": {
        "interfaces": [ "eth1" ]
        },
        "control-socket": {
        "socket-type": "unix",
        "socket-name": "/run/kea/kea4-ctrl-socket"
        },
        "lease-database": {
        "type": "memfile",
        "lfc-interval": 3600
        },
        "valid-lifetime": 600,
        "max-valid-lifetime": 7200,
        "subnet4": [
        {
          "id": 1,
          "subnet": "10.1.0.0/24",
          "pools": [
          {
                "pool": "10.1.0.150 - 10.1.0.200"
          }
        ],
        "option-data": [
        {
                "name": "routers",
                "data": "10.1.0.1"
        },
        {
                "name": "domain-name-servers",
                "data": "192.168.1.1, 1.1.1.1"
        },
        {
                "name": "domain-name",
                "data": "contoso.com"
        }
        ]
        }
        ]
  }
}
```

Create/Edit kea-dhcp4.conf.

```sh
nano /etc/kea/kea-dhcp4.conf
```

Paste the modified conf data from above into the file, then Ctrl+X -> Y -> Enter to save the file.

Run this command to reload the configuration.
- The console will pause with no output.
- Press Ctrl+D.
- The output should contain "Configuration successful."

```sh
kea-shell --host 127.0.0.1 --port 8000 --auth-user kea-api --auth-password $(cat /etc/kea/kea-api-password) --service dhcp4 config-reload
```


## [OPTIONAL] IPv6-mostly (DHCPv6 + DNS64 + NAT64)

### Use KEA DHCPv6 for ULA address assignment

Use a tool to generate a ULA IPv6 prefix.
- I have [built a tool](https://github.com/JamesKehr/Azure) for creating ULA address spaces.
- Run this command in PowerShell to generate an IPv6 address space. This works in PowerShell for Linux, too.
  
```powershell
$ipv6 = iwr https://raw.githubusercontent.com/JamesKehr/Azure/main/Get-AzPrivateIPv6Subnet.ps1 | iex
```

- The use this command to get the subnet CIDR syntax that can be used in the config below.

```powershell
$ipv6.GetAzSubnet(0)
```

- Like the DHCP4 conf file, additional interfaces and subnets can be generated.
- Use the commands below to generate a second subnet for eth2. Additional subnets can be generated using the same principle.

```powershell
$ipv6.AddSubnetID()
$ipv6.GetAzSubnet(1)
```

Use the text below to build kea-dhcp6.conf file content.

kea-dhcp6.conf content:

```javascript
{
# DHCPv6 configuration starts on the next line
"Dhcp6": {

# First we set up global values
    # Address expiration.
    # default: 4000; Lab: 600 (10 minutes)
    "valid-lifetime": 600,
    # This is the T1 time.
    # Default: 1000; Lab: 300 (5 minutes)
    "renew-timer": 300,
    # This is the T2 time.
    # Default: 2000; Lab: 480 (8 minutes)
    "rebind-timer": 2000,
    # Determines when the address becomes deprecated.
    # Default: 3000; Lab: 540 (9 minutes)
    "preferred-lifetime": 540,

# Next we set up the interfaces to be used by the server.
    "interfaces-config": {
        "interfaces": [ "eth1" ],
        "service-sockets-require-all": true,
        "service-sockets-max-retries": 5,
        "service-sockets-retry-wait-time": 5000
    },

# And we specify the type of lease database
    "lease-database": {
        "type": "memfile",
        "lfc-interval": 3600
    },

# Finally, we list the subnets from which we will be leasing addresses.
    "subnet6": [
        {
            # update the interface name here
            "interface": "eth1",
            # change the subnet here
            "subnet": "fd::/64",
            "option-data": [
               {
                   "name": "dns-servers",
                   "data": "<eth1 IPv6 address>"
               }
            ],
            "pools": [
                {
                    # update the pool here
                    # if the generate subnet was fda4:6d59:9bbb:fc9d::/64, then the pool would be fda4:6d59:9bbb:fc9d:1::/80
                    "pool": "fd::1::/80"
                }
             ]
        }
    ]
# DHCPv6 configuration ends with the next line
}

}
```

Backup any example kea-dhcp6.conf file.

```sh
mv /etc/kea/kea-dhcp6.conf /etc/kea/kea-dhcp6.conf.original
```

Edit/Create the kea-dhcp6.conf file.

```sh
nano /etc/kea/kea-dhcp6.conf
```

Copy/paste the kea-dhcp6.conf content, then  Ctrl+X -> Y -> Enter to save the file.

Try this command to reload the DHCPv6 server.
- Press Ctrl+D to perform the reload.

```sh
kea-shell --host 127.0.0.1 --port 8000 --auth-user kea-api --auth-password $(cat /etc/kea/kea-api-password) --service dhcp6 config-reload
```

- The command might throw an error and I don't know why.
- If the command outputs something like "unable to forward command to the dhcp6 service: No such file or directory. The server is likely to be offline" then run this command to restart the service.

```sh
systemctl restart kea-dhcp6-server.service
```

- Make sure the service started using this command. Press Q to exit the status output.

```
systemctl status kea-dhcp6-server.service
```


Enable IPv6 forwarding.

```sh
sysctl -w net.ipv6.conf.all.forwarding=1
sysctl -w net.ipv6.conf.default.forwarding=1
sed -i '/net.ipv6.conf.all.forwarding/s/^#//' /etc/sysctl.conf
sed -i '/net.ipv6.conf.default.forwarding/s/^#//' /etc/sysctl.conf
sysctl -p
```

Enable IPv6 MASQUERADE 

```sh
ip6tables -t nat -A POSTROUTING -j MASQUERADE -o eth0
ip6tables -t nat -A POSTROUTING -j MASQUERADE -o eth1
```

### Use radvd to advertise the IPv6 gateway

Install radvd. This enables router advertisements, needed to send the IPv6 gateway to clients.

```sh
apt install radvd radvdump
```

Edit the radvd.conf file.

```sh
nano /etc/radvd.conf
```

Add this content to the file.
- This does not advertise an IPv6 prefix, only the M-bit (Managed flag) to use DHCPv6.
- Adding other config (DNS servers) is not in this example, but can be added by updating the DHCPv6 config.
- Add one entry per interface.
- Leave the WAN (eth0) interface off.

```sh
interface eth0 {
        AdvSendAdvert off;
        AdvOtherConfigFlag off;
        AdvManagedFlag off;
};

interface eth1 {
        AdvSendAdvert on;
        MinRtrAdvInterval 3;
        MaxRtrAdvInterval 10;
        AdvOtherConfigFlag off;
        AdvManagedFlag on;
};
```

Restart radvd to reload the changes and get the status to make sure it restarted successfully.

```sh
systemctl restart radvd
systemctl status radvd
```

Run this command to make sure the configuration is working. It may take a minute or so for results to appear.

```sh
radvdump
```

Radvd is working if router advertisements are coming from eth1 (and optionally eth2), but not eth0.

Press Ctrl+C to stop testing.

Edit the netplan yaml file where the IPv4 gateway address was added (example: `/etc/netplan/50-cloud-init.yaml`)
- Add `dhcp6: true` on eth0.
- Add a static IPv6 address from the ULA address space to eth1 and other internal adapters.
- Use a well known IPv6 address, such as <ULA>::1/64.

Example:

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: true
    eth1:
      addresses: [10.1.0.1/24, <ULA subnet>::1/64]
      nameservers:
        addresses: [192.168.1.1, 1.1.1.1, 2606:4700:4700::1111, 2620:fe::fe]
```

Save and close: Ctrl+x, y, Enter

Run:

```sh
netplan try
```

Use `ip addr` to confirm eth1 (and/or other interfaces) have a static ULA address.

Boot up a lab client on the BLUE network.

The client should have IPv4 and IPv6 addresses from the gateway's DHCP servers. And internet connectivity should work.

```sh
ping -4 example.com
ping -6 example.com
```

### Setup BIND9 for DNS and DNS64

This configuration causes bind9 to act like a cache server with no domains of its own. Feel free to add zones if you want.

References:

https://documentation.ubuntu.com/server/how-to/networking/install-dns/#set-up-a-primary-server
https://www.isc.org/blogs/doh-talkdns/

Install bind9 and dnsutils.

```sh
apt install bind9 dnsutils
```

Enable the bind9 named service to auto-start.

```sh
systemctl enable named
```

Edit /etc/bind/named.conf.options

```sh
nano /etc/bind/named.conf.options
```

Uncomment the forwarders section and add some forwarders. This example will use Cloudflare DNS (1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001).

```sh
        forwarders {
             1.1.1.1;
             1.0.0.1;
             2606:4700:4700::1111;
             2606:4700:4700::1001;
        };
```

Add the following lines under `listen-on-v6 { any; };`

```sh
        listen-on { any; };

        recursion yes;
        allow-recursion { any; };
```

The final file should look like this, at a minimum.

```sh
options {
        directory "/var/cache/bind";

        // If there is a firewall between you and nameservers you want
        // to talk to, you may need to fix the firewall to allow multiple
        // ports to talk.  See http://www.kb.cert.org/vuls/id/800113

        // If your ISP provided one or more IP addresses for stable
        // nameservers, you probably want to use them as forwarders.
        // Uncomment the following block, and insert the addresses replacing
        // the all-0's placeholder.

        forwarders {
             1.1.1.1;
             1.0.0.1;
             2606:4700:4700::1111;
             2606:4700:4700::1001;
        };

        //========================================================================
        // If BIND logs error messages about the root key being expired,
        // you will need to update your keys.  See https://www.isc.org/bind-keys
        //========================================================================
        dnssec-validation auto;

        listen-on-v6 { any; };
        listen-on { any; };

        recursion yes;
        allow-recursion { any; };
};
```

Save and close: Ctrl-X, Y, Enter

Validate the configuration. No output is good output.

```sh
named-checkconf /etc/bind/named.conf.options
```

Restart the named (bind9) service and make sure there are no errors.

```sh
systemctl restart named
systemctl status named
```

Test the bind9 DNS server locally and on a VM in the lab.

On the gateway server:

```sh
dig example.com AAAA
dig example.com A
```

On the Windows client:

```powershell
$query = "example.com"
$gtwys = Get-NetIPConfiguration | ForEach-Object {@($_.IPv6DefaultGateway.NextHop, $_.IPv4DefaultGateway.NextHop)}
$gtwys | ForEach-Object {Write-Host -fore Green "Gateway: $_"; Resolve-DnsName $query -Server $_}
```

Continue if everything is working this far.

Get your ULA IPv6 prefix.
- This is the fd::/64 address space generated earlier in the instructions.
- You can use the command `ip addr` to get the IPv6 address details from the console; however, this needs to be in prefix format, not IPv6 address format.
- An address of `fd1a:7148:e9a0:186a::1/64` in the `ip addr` output would be `fd1a:7148:e9a0:186a::/64` in prefix format.

Edit /etc/bind/named.conf.options to enable dns64.

```
nano /etc/bind/named.conf.options
```

Add the following to the config file:

### OPTION 1: Configure for NAT64 (Recommended)

This prepares BIND9 DNS64 to work with tayga NAT64.

```
        dns64 64:ff9b::/96 {
            clients { any; }; // Affect all clients
            mapped { any; };  // Map all IPv4 addresses
        };
```

### OPTION 2: Configure for ULA

This option 

Template:
```
dns64 <your_ULA_prefix>/<prefix_length> {};
```

Example:
```
 dns64 fd1a:7148:e9a0:186a::/64 {};
```


Save and close the file: Ctrl+X, Y, Enter

Verfiy the file and restart the service.

```
named-checkconf /etc/bind/named.conf.options
systemctl restart named
systemctl status named
```

Now perform a DNS lookup for a website with only an IPv4 address.

```
Resolve-DnsName jammrock.com -Server 10.1.0.1
```

This should return the IPv4 address and the a DNS64 translated address using the lab's ULA address space.

```
Name                                           Type   TTL   Section    IPAddress
----                                           ----   ---   -------    ---------
jammrock.com                                   AAAA   300   Answer     64:ff9b::1763:fa4c
jammrock.com                                   A      3600  Answer     23.99.250.76
```


## Setup jool for NAT64

Based on: https://cooperlees.com/2020/12/nat64-using-jool-on-ubuntu-20-04/

Please make sure DNS64 is configured with Option 1, using the `64:ff9b::/96` well-known IPv6 prefix before proceeding.

Install jool.

```sh
apt install jool-dkms jool-tools
```

You will be prompted to create a boot password if Secure Boot is enabled. Enter a password or jool will not install.

### Secure Boot ONLY

Reboot the gateway.

A boot time menu will appear.

Select Enroll MOK.

Follow the prompts until you are prompted for the password.

Enter the password from the jool install.

Reboot.

### Continue with jool setup...

Run:

```bash
sudo modprobe jool
jool instance add --netfilter --pool6 64:ff9b::/96
```

Create a oneshot systemd server by editing/creating a service file with this command.

```bash
nano /etc/systemd/system/jool-oneshot.service
```

Add these contents:

```conf
[Unit]
Description=Add NAT64 netfilter pool6 to jool

[Service]
Type=oneshot
ExecStart=/usr/bin/jool instance add --netfilter --pool6 64:ff9b::/96

[Install]
WantedBy=multi-user.target
```

Close and save: Ctrl+x, y, Enter

Enable the jool-oneshot service.

```bash
systemctl enable jool-oneshot
```

Add jool to the module load list.

```bash
nano /etc/modules-load.d/jool.conf
```

Add the word jool to the file content.

```
jool
```

Close and save: Ctrl+x, y, Enter

Reboot to ensure that jool loads correctly on boot.

```bash
lsmod | grep jool
```

## Create an internal IPv6 NCSI responder

Based on: https://ubuntu.com/tutorials/install-and-configure-nginx#1-overview

Install nginx.

```bash
apt install nginx
```

Create the connecttest.txt file in /var/www/msftconnecttest

```bash
mkdir /var/www/msftconnecttest
echo "Microsoft Connect Test" > /var/www/msftconnecttest/connecttest.txt
```

Setup the nginx virtual host

```bash
cd /etc/nginx/sites-enabled
nano msftconnecttest
```

Add the following contents to the file.
- Replace the servername with the appropriate URLs that will serve the connection test file.

```sh
server {
       listen 80;
       listen [::]:80;

       server_name ipv4.contoso.com;

       root /var/www/msftconnecttest;
       index connecttest.txt;

       location / {
               try_files $uri $uri/ =404;
       }
}

server {
       listen 80;
       listen [::]:80;

       server_name ipv6.contoso.com;

       root /var/www/msftconnecttest;
       index connecttest.txt;

       location / {
               try_files $uri $uri/ =404;
       }
}
```

Close and save: Ctrl+x, y, Enter

Restart nginx.

```bash
service nginx restart
```



Add A and AAAA records to the DNS server for the domains used above.
- These steps will cover adding ipv4.contoso.com and ipv6.contoso.com to BIND9 on the gateway.
- There are BIND9 front ends you can install and service with nginx if you want to try one of those instead.
- Or if you have a Windows DNS server for an AD environment you can use that.
- It doesn't matter where the DNS server is so long as the internal network clients can resolve the records from the local IPv6 ULA network.

Edit named.conf.local.

```bash
nano /etc/bind/named.conf.local
```

This is an basic example of contoso.com in named.conf.local.

```sh
zone "contoso.com" {
        type master;
        file "/var/lib/bind/db.contoso.com";
};
```

Close and save: Ctrl+x, y, Enter

Create the zone file, which is the file from the zone definition in named.conf.local.
- Replace the file if different.

```bash
nano /var/lib/bind/db.contoso.com
```

Create the zone file based on the output below, the RFC standards, and the BIND9 documentation.

https://bind9.readthedocs.io/en/v9.18.14/chapter3.html#soa-rr
https://wiki.debian.org/Bind9#File_.2Fetc.2Fbind.2Fnamed.conf.local

Example file (replace IP addresses and records as apprpriate):

```
; base zone file for example.com
$TTL 2d    ; default TTL for zone
$ORIGIN contoso.com. ; base domain-name
; Start of Authority RR defining the key characteristics of the zone (domain)
@         IN      SOA   ns1.contoso.com. hostmaster.contoso.com. (
                                2003080800 ; serial number
                                12h        ; refresh
                                15m        ; update retry
                                3w         ; expiry
                                2h         ; minimum
                                )
; name server RR for the domain
           IN      NS      ns1.contoso.com.
; domain hosts includes NS and MX records defined above
; plus any others required
; for instance a user query for the A RR of joe.example.com will
; return the IPv4 address 192.168.254.6 from this zone file
ns1        IN      A       10.1.0.1
ns1        IN      AAAA    fd29:d3fc:a205:9511::1
ipv4       IN      A       10.1.0.1
ipv6       IN      AAAA    fd29:d3fc:a205:9511::1
```

Reload the named to reload BIND9 configuration.

```bash
systemctl restart named
systemctl status named
```



Make sure the internal URLs are being served by DNS.

From the gateway:

```bash
dig ipv4.contoso.com A
dig ipv6.contoso.com AAAA
```

From Windows client:

```powershell
Resolve-DnsName ipv4.contoso.com -Type A
Resolve-DnsName ipv6.contoso.com -Type AAAA
```

Use curl to confirm the file is being served.
- The output of each command must be: `Microsoft Connect Test`


From gateway:

```bash
curl http://ipv4.contoso.com/connecttest.txt
curl http://ipv6.contoso.com/connecttest.txt
```

From internal Windows client:

```powershell
curl.exe http://ipv4.contoso.com/connecttest.txt
curl.exe http://ipv6.contoso.com/connecttest.txt
```

Setup and test the internal probe on a test system.
- Open regedit.
- Go to: `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet`
- Change `ActiveWebProbeHost` to the internal IPv4 probe URL (`ipv4.contoso.com` in this example).
- Change `ActiveWebProbeHostV6` to the internal IPv6 probe URL (`ipv6.contoso.com` in this example).
- Close regedit.
- Restart the computer.


## Enable IPv6-only

Disable the KEA DHCPv4 service.

```bash
systemctl disable --now kea-dhcp4-server.service
systemctl mask kea-dhcp4-server.service
```

Remove the IPv4 address on the internal interface (example: eth1).

Open the netplan file.

```bash
nano /etc/netplan/<YAML file>
```

Example:

```bash
nano /etc/netplan/50-cloud-init.yaml
```

Remove the IPv4 addresses from the internal interface in netplan file. 
TIP  : Comment the line and create a modified copy of the line without the IPv4 addresses.
TIP2 : Create a second copy of the dual-stack lines to and remove the IPv6 addresses to create an IPv4-only version of the addresses lines.

Example:

```bash
network:
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: true
    eth1:
#     Dual-stack
#      addresses: [10.1.0.1/24, fd85:8b47:e1fe:1b45::1/64]
#     IP4-only stack
#      addresses: [10.1.0.1/24]
#     IPv6-only stack
      addresses: [fd85:8b47:e1fe:1b45::1/64]
      nameservers:
#     Dual-stack
#        addresses: [192.168.1.60, 192.168.3.61, 2600:1700:5aa0:30cf::60, 2600:1700:5aa0:30ce::61]
#     IP4-only stack
#        addresses: [192.168.1.60, 192.168.3.61]
#     IPv6-only stack
        addresses: [2600:1700:5aa0:30cf::60, 2600:1700:5aa0:30ce::61]
  version: 2
```

Reboot the lab clients to reset the network configuration.


## Re-enable IPv4

Enable the KEA DHCPv4 service.

```bash
systemctl unmask kea-dhcp4-server.service
systemctl enable --now kea-dhcp4-server.service
```

Open the netplan file

```bash
nano /etc/netplan/<YAML file>
```

Example:

```bash
nano /etc/netplan/50-cloud-init.yaml
```

Open the netplan file and add the IPv4 address back to the Internal interface (example: eth1). Or, comment/uncomment the approritate lines to enable dual-stack again.

Reboot the lab clients to reset the network configuration.

Reboot the gateway if the DHCP server is not handing out IPv4 addresses.


### [OPTIONAL] Setup certbot to generate certificates needed for DoH.

This step requires public facing DNS or HTTP[S] site for Let's Encrypt to challenge or it will not hand out a certificate.

FUTURE
