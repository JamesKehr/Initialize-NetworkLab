# How to setup an Ubuntu gateway guide for Windows admins

These instructions are designed for running Ubuntu as a Hyper-V VM.

Download the Ubuntu 20.04 server, manual server installation, from: https://ubuntu.com/download/server

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

	nano /etc/netplan/<YAML file>

Example:

	nano /etc/netplan/00-installer-config.yaml

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


## [OPTIONAL] DHCPv4 + DHCPv6 + NAT66

These steps walk through the basics of setting up DHCP and NAT66.

[Install ISC KEA](https://documentation.ubuntu.com/server/how-to/networking/install-isc-kea/index.html) for DHCPv4 and DHCPv6. The Ubuntu install adds everything you need.

```sh
sudo apt install kea
```

Use the "configure with a random password" option during setup.

Rename the kea-dhcp4.conf file.

```mv /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.original```

Edit the kea-dhcp4.conf contents below to match your environment. 
- This file is only for a single interface, but can be expanded to handle both interfaces.
- Change `"interfaces": [ "eth1" ]` to `"interfaces": [ "eth1", "eth2" ]` to add both interfaces.
- Add `"interface": "ethX",` entries to the subnet matching eth1 and eth2, after the "id" line. Changing the X in ethX to the appropriate interface number or name.

```
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

```nano /etc/kea/kea-dhcp4.conf```

Paste the modified conf data from above into the file, then Ctrl+X -> Y -> Enter to save the file.

Run this command to reload the configuration.
- The console will pause with no output.
- Press Ctrl+D.
- The output should contain "Configuration successful."

```kea-shell --host 127.0.0.1 --port 8000 --auth-user kea-api --auth-password $(cat /etc/kea/kea-api-password) --service dhcp4 config-reload```


Use the text below to build kea-dhcp6.conf file content.
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

kea-dhcp6.conf content:

```
{
# DHCPv6 configuration starts on the next line
"Dhcp6": {

# First we set up global values
    "valid-lifetime": 4000,
    "renew-timer": 1000,
    "rebind-timer": 2000,
    "preferred-lifetime": 3000,

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


Edit/Create the kea-dhcp6.conf file.

```nano /etc/kea/kea-dhcp6.conf```

Copy/paste the kea-dhcp6.conf content, then  Ctrl+X -> Y -> Enter to save the file.

Try this command to reload the DHCPv6 server.
- Press Ctrl+D to perform the reload.

```kea-shell --host 127.0.0.1 --port 8000 --auth-user kea-api --auth-password $(cat /etc/kea/kea-api-password) --service dhcp6 config-reload```

- The command might throw an error and I don't know why.
- If the command outputs something like "unable to forward command to the dhcp6 service: No such file or directory. The server is likely to be offline" the run this command to restart the service.

```systemctl restart kea-dhcp6-server.service```

- Then make sure the service started using this command. Press Q to exit the status output.

```systemctl status kea-dhcp6-server.service```

Enable IPv6 forwarding.

```
sysctl -w net.ipv6.conf.all.forwarding=1
sysctl -w net.ipv6.conf.default.forwarding = 1
sed -i '/net.ipv6.conf.all.forwarding/s/^#//' /etc/sysctl.conf
sed -i '/ net.ipv6.conf.default.forwarding/s/^#//' /etc/sysctl.conf
sysctl -p
```

Enable IPv6 MASQUERADE 

```p6tables -t nat -A POSTROUTING -j MASQUERADE```

Install radvd. This enables router advertisements, needed to send the IPv6 gateway to clients.

```apt install radvd radvdump```

Edit the radvd.conf file.

```nano /etc/radvd.conf```

Add this content to the file.
- This does not advertise an IPv6 prefix, only the M-bit (Managed flag) to check DHCPv6.
- Adding other config (DNS servers) is not in this example, but can be added by updating the DHCPv6 config.
- Add one entry per interface.
- Leave the WAN (eth0) interface off.

```
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

```
systemctl restart radvd
systemctl status radvd
```

Run this command to make sure the configuration is working. The command may take a minute or so to run.

```
systemctl restart radvd
```

Radvd is working if router advertisements are coming from eth1 (and optionally eth2), but not eth0.

Press Ctrl+C to stop testing.

Boot up a lab client on the BLUE network.

The client should have IPv4 and IPv6 addresses from the gateway's DHCP servers. And internet connectivity should work.

```
ping -4 example.com
ping -6 example.com
```

# IPv6-mostly configuration

## Setup BIND9 for DNS and DNS64

This configuration causes bind9 to act like a cache server with no domains of its own. Feel free to add zones if you want.

References:

https://documentation.ubuntu.com/server/how-to/networking/install-dns/#set-up-a-primary-server
https://www.isc.org/blogs/doh-talkdns/

Install bind9 and dnsutils.

```
apt install bind9 dnsutils
```

Enable the bind9 named service to auto-start.

```
systemctl enable named
```

Edit /etc/bind/named.conf.options

```
nano /etc/bind/named.conf.options
```

Uncomment the forwarders section and add some forwarders. This example will use Cloudflare DNS (1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001).

```
        forwarders {
             1.1.1.1;
             1.0.0.1;
             2606:4700:4700::1111;
             2606:4700:4700::1001;
        };
```

Add the following lines under `listen-on-v6 { any; };`

```
        listen-on { any; };

        recursion yes;
        allow-recursion { any; };
```

The final file should look like this, at a minimum.

```
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

```
named-checkconf /etc/bind/named.conf.options
```

Restart the named (bind9) service and make sure there are no errors.

```
systemctl restart named
systemctl status named
```

Test the bind9 DNS server locally and on a VM in the lab.

On the gateway server:

```
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
jammrock.com                                   AAAA   300   Answer     fd1a:7148:e9a0:186a:17:63fa:4c00:0
jammrock.com                                   A      3600  Answer     23.99.250.76
```


### [OPTIONAL] Setup certbot to generate certificates needed for DoH.

This step requires public facing DNS or HTTP[S] site for Let's Encrypt to challenge or it will not hand out a certificate.

FUTURE



## Setup tayga64 for NAT64

