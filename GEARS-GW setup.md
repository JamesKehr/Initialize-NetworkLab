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

Logon to the server.

Run these commands to update the server. Remember that everything in Linux/Unix is case sensitive.

	sudo apt update
	sudo apt upgrade -y
	reboot
	
Logon to the server and get the IP address of the server. The IP will be listed under eth0.

	ip addr

Open Windows Terminal/PowerShell.

SSH to the server.

	ssh gw@<IP>
	
	- Yes when asked about the fingerprint.
	- Enter the password.
	
Install required components for the lab. You can copy/paste the commands when using the SSH session in PowerShell/Windows Terminal.

	sudo apt install iproute2 python3-flask bridge-utils net-tools iptables-persistent git -y


Create a VM snapshot at this point in case something breaks when setting up the network routing.


Create a new NIC on the VM for the RED network. This should appear as eth1 when you run "ip addr" or "ip link". We will leave eth0 on DHCP connected to the public network.

Add a new NIC to the GEARS-GW VM for the BLUE network. This should appear as eth2.

Run this command to get the name of the netplan config file.

	ls /etc/netplan/

In my installation the file name is 00-installer-config.yaml.
	- A YAML file is a type of config file that uses white space (space, tab, etc.) to separate elements.
	- Be careful with whitespaces when editing a YAML file.
	- Remember that everything is case sensitive.

Edit the YAMl file found above.

	sudo nano /etc/netplan/<YAML file>

Example:

	sudo nano /etc/netplan/00-installer-config.yaml

Use the arrow, home, and end keys, to position the cursor inside nano. Press enter to create a new line.

Edit the file so it looks like this (spacing MUST be exact!):



# This is the network config written by 'subiquity'
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




	- Change the name server (DNS) addresses to match your network configuration.

Run this command to apply the change, then press Enter to accept the new config. The last output line should read "Configuration accepted." when it works.

	sudo netplan try

Enable IP forwarding.

	sudo sed -i '/net.ipv4.ip_forward/s/^#//' /etc/sysctl.conf
	sudo sysctl -p

The sysctl command should return "net.ipv4.ip_forward = 1"



Ping 10.1.0.1 from GEARS-RX to confirm the IP is reachable.

Ping 10.2.0.1 from GEARS-TX when complete to confirm reachability.

Ping 10.2.0.2 from GEARS-RX to confirm routing/forwarding is working.

Ping 10.1.0.2 from GEARS-TX to confirm routing/forwarding is working.

[optional]Enable NATing on the GW to allow Internet access.

	sudo iptables -t nat -A POSTROUTING -j MASQUERADE -o eth0
	sudo iptables -t nat -A POSTROUTING -j MASQUERADE -o eth1
	sudo iptables -t nat -A POSTROUTING -j MASQUERADE -o eth2
	sudo iptables-save > /etc/iptables/rules.v4


	- You should now be able to access Internet sites through the gateway.


Perform network tuning on the gateway.

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


Download the tcgui.

	git clone https://github.com/tum-lkn/tcgui.git


Use ls (the Linux equal of dir) to make sure the file main.py is listed.

Type "reboot" and press Enter to restart the GEARS-GW VM.

Logon to GEARS-GW via VM connect (Hyper-V Manager) and not SSH.

Test network connectivity on the GEARS VMs.

Execute this script to start tcgui.

	cd tcgui
	sudo python3 main.py --ip 10.1.0.1 --port 80

Logon to GEARS-RX.

Open Edge and navigate to http://10.1.0.1

Test by changing settings for eth1 or eth2, but not both.

Remove all rules.

Stop the script by pressing Ctrl+C.

Move the tcgui files.

	mv ./tcgui /usr/local/bin/tcgui

Create and edit a systemd service file.

	sudo nano /etc/systemd/system/tcgui.service

File contents:

[Unit]
After=network.service

[Service]
ExecStart=/usr/local/bin/tcgui.sh

[Install]
WantedBy=default.target


Ctrl+x to exit, type y when prompted to save.

Create and edit the script file.

	nano /usr/local/bin/tcgui.sh

 
File contents:
 
!/bin/bash
 
python3 /usr/local/bin/tcgui/main.py --ip 10.1.0.1 --port 80


Ctrl+x to exit, type y when prompted to save.

Update file permissions and enable the service.

	sudo chmod 744 /usr/local/bin/tcgui.sh
	sudo chmod 664 /etc/systemd/system/tcgui.service
	sudo systemctl daemon-reload
	sudo systemctl enable tcgui.service
	

Reboot.

Make sure you can access http://10.1.0.1 works after the reboot.
![image](https://user-images.githubusercontent.com/40303902/151424165-0392390e-2ea1-4077-a164-28d7653bc291.png)
