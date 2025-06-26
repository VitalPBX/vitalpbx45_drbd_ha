# VitalPBX 4.5 High Availability Setup on Debian 12

This guide explains how to configure a **High Availability (HA)** cluster for **VitalPBX 4.5** on **Debian 12**, using **DRBD**, **Corosync**, **Pacemaker**, and **OCF Resource Agents**.

## 🧰 Requirements

* 2 servers with Debian 12 (clean installation)
* Static IPs
* Same disk size on both nodes
* Public key SSH access between both nodes
* Time synchronization (e.g., with `chrony`)

## 🌐 Network Configuration

Each server must have:

* A dedicated IP for DRBD replication (via a secondary interface or VLAN)
* A static IP on the main interface for cluster management
* A virtual floating IP (e.g. `192.168.10.30`) for VitalPBX services

| Node    | Hostname              | IP Address    |
| ------- | --------------------- | ------------- |
| Node 1  | vitalpbx-master.local | 192.168.10.31  |
| Node 2  | vitalpbx-slave.local  | 192.168.10.32  |
| Virtual | HA Cluster            | 192.168.10.30 |

---

## Install Debian 12 Minimal
We are going to start by installing Debian 12 minimal on two servers

a.- When you get to the partitions part you must select “Guide - use entire disk”:<br>
![image](https://github.com/user-attachments/assets/915b2adb-0699-4f40-9270-615d6ec3279b)<br>
![image](https://github.com/user-attachments/assets/4b08f2e1-1f76-46c6-8b1d-24cd48ff3c5e)<br>
b.- Select:
“All files in one partition (recommended for new user)”<br>
 ![image](https://github.com/user-attachments/assets/ca06e527-a493-4848-97a9-7795c164f307)<br>
c.- Select primary:<br>
“#1 primary”<br>
 ![image](https://github.com/user-attachments/assets/03f0d156-92b6-4375-8ad6-b64fb2aa842c)<br>
d.- Delete partition<br>
 ![image](https://github.com/user-attachments/assets/2ff33faa-3381-4e73-8bf6-53f54a82c1f9)<br>
e.- Select pri/log<br>
 ![image](https://github.com/user-attachments/assets/0ee75c69-0b44-40b6-abf6-66c92e78d471)<br>
f.- Create New Partition<br>
 ![image](https://github.com/user-attachments/assets/0ac1e964-3571-4c76-a39b-bb24eb355434)<br>
g.- Change the capacity to:<br>
New partition size: 20GB<br>
We need enough space for the operating system and its applications in the future; then <continue><br>
 ![image](https://github.com/user-attachments/assets/ecd41e91-bba9-4869-96ea-d1d4b06cc381)<br>
Select Primary<br>
 ![image](https://github.com/user-attachments/assets/d33ffa80-ccdf-402d-9d19-b9991999653b)<br>
Select Beginning<br>
 ![image](https://github.com/user-attachments/assets/87c900bc-dfbf-4ce4-89f7-9cd267591ebe)<br>
Select Done setting up the partition<br>
 ![image](https://github.com/user-attachments/assets/71038ee4-8c66-4390-b8a3-acf27cbaa7dd)<br>
h.- Finish<br>
 ![image](https://github.com/user-attachments/assets/e6fdfb56-f12b-431d-bebb-95d3438d6872)<br>
Pres Yes to confirm<br>
 ![image](https://github.com/user-attachments/assets/0be38fad-cd8d-43c2-bc5d-8b6feed62cc1)<br>
And continue with the installation.<br>

### 1.- Remote access with the root user.
As a security measure, the root user is not allowed to remote access the server. If you wish to unblock it, remember to set a complex password, and perform the following steps.

Enter the Command Line Console with the root user directly on your server with the password you set up earlier.
Edit the following file using nano, /etc/ssh/sshd_config in **Node 1 and Node 2**.
```
nano /etc/ssh/sshd_config
```

Change the following line
```
#PermitRootLogin prohibit-password
```
With
```
PermitRootLogIn yes
```

Save, Exit and restart the sshd service (Master-Slave).
```
systemctl restart sshd
```

### 2.- Changing your IP Address to a static address.
By default, our system’s IP address in Debian is obtained through DHCP, however, you can modify it and assign it a static IP address using the following steps:

Edit the following file with nano, /etc/network/interfaces **Node 1**.
```
nano /etc/network/interfaces
```
Change
```
#The primary network interface
allow-hotplug eth0
iface eth0 inet dchp
```

With the following. Sever Master.
```
#The primary network interface
allow-hotplug eth0
iface eth0 inet static
address 192.168.10.31
netmask 255.255.254.0
gateway 192.168.10.1
```
Lastly, reboot both servers and you can now log in via ssh.

Edit the following file with nano, /etc/network/interfaces **Node 2**.
```
nano /etc/network/interfaces
```
Change
```
#The primary network interface
allow-hotplug eth0
iface eth0 inet dchp
```

With the following. Sever Master.
```
#The primary network interface
allow-hotplug eth0
iface eth0 inet static
address 192.168.10.32
netmask 255.255.254.0
gateway 192.168.10.1
```
Lastly, reboot both servers and you can now log in via ssh.

### 3.- Set Hostnames

**Node 1**
```bash
hostnamectl set-hostname vitalpbx-master.local
```
**Node 2**
```bash
hostnamectl set-hostname vitalpbx-slave.local
```

Edit `/etc/hosts` on **Node 1**:

```
nano /etc/hosts
```
```
192.168.10.31 vitalpbx-master.local
192.168.10.32 vitalpbx-slave.local
```

Edit `/etc/hosts` on **Node 2**:

```
nano /etc/hosts
```
```
192.168.10.31 vitalpbx-master.local
192.168.10.32 vitalpbx-slave.local
```
---

## Install VitalPBX 4.5
Install VitalPBX 4.5 on **Node 1 and Node 2**. Let's connect via SSH to each of them and run the following commands.
```
apt install sudo
wget https://repo.vitalpbx.com/vitalpbx/v4.5/pbx_installer.sh
chmod +x pbx_installer.sh
./pbx_installer.sh
```
Go to the web interface to: 
ADMIN>Network>Network Settings

First, change the Hostname in both servers, and remember to press the Save button.
 
**Node 1**<br>
 ![image](https://github.com/user-attachments/assets/549b0b5d-bbca-4356-b43f-60a9881e1ff3)<br>

**Node 2**<br>
 ![image](https://github.com/user-attachments/assets/e884d26e-adaa-4e08-bca3-0d4abde35586)<br>

---

## 🏗️ HA Installation Steps

### 1.- Install Required Packages
Install dependencies on **Node 1 and Node 2**.
```bash
apt update && apt install -y drbd-utils pacemaker pcs corosync chrony rsync xfsprogs
```
Enable pcsd service:
```bash
systemctl enable --now pcsd
```
---

### 3. Setup Passwords & Auth

Create a password for `hacluster` user and sync between nodes:

```bash
passwd hacluster
pcs host auth vitalpbx-master.local vitalpbx-slave.local
```

---

### 4. Corosync Configuration

Generate config using `corosync.conf.example.udpu`.

Use `uidgid` model and unicast UDP between nodes.

Ensure `/etc/corosync/corosync.conf` is the same on both nodes.

---

### 5. Cluster Initialization

```bash
pcs cluster setup --name cluster_vitalpbx vitalpbx-master.local vitalpbx-slave.local
pcs cluster enable --all
pcs cluster start --all
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore
```

---

### 6. Setup DRBD

#### 6.1 Configure DRBD Resource

Example: `/etc/drbd.d/vpbx.res`

```bash
resource DrbdData {
    on vitalpbx-master.local {
        device    /dev/drbd0;
        disk      /dev/sdb1;
        address   192.168.100.1:7789;
        meta-disk internal;
    }
    on vitalpbx-slave.local {
        device    /dev/drbd0;
        disk      /dev/sdb1;
        address   192.168.100.2:7789;
        meta-disk internal;
    }
}
```

Create and bring up DRBD:

```bash
drbdadm create-md DrbdData
drbdadm up DrbdData
```

Initial sync (only on master):

```bash
drbdadm primary --force DrbdData
mkfs.ext4 /dev/drbd0
```

---

### 7. Pacemaker Resources

```bash
pcs resource create DrbdData ocf:linbit:drbd drbd_resource=DrbdData op monitor interval=20s role=Master op monitor interval=30s role=Slave
pcs resource master DrbdData-clone DrbdData master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true
```

---

### 8. Mount Filesystem

```bash
pcs resource create DrbdFS Filesystem device="/dev/drbd0" directory="/vpbx" fstype="ext4"
```

---

### 9. Setup Floating IP

```bash
pcs resource create ClusterIP ocf:heartbeat:IPaddr2 ip=192.168.1.250 cidr_netmask=24 nic=eth0 op monitor interval=30s
```

---

### 10. Add Application Services

```bash
pcs resource create mysql systemd:mariadb
pcs resource create asterisk systemd:asterisk
pcs resource create vpbx-monitor systemd:vpbx-monitor
pcs resource create fail2ban systemd:fail2ban
```

---

### 11. Resource Order & Colocation

```bash
pcs constraint colocation add DrbdFS with DrbdData-clone INFINITY with-rsc-role=Master
pcs constraint order promote DrbdData-clone then start DrbdFS
pcs constraint colocation add mysql with DrbdFS
pcs constraint order start DrbdFS then mysql
pcs constraint colocation add asterisk with mysql
pcs constraint order start mysql then asterisk
pcs constraint colocation add vpbx-monitor with asterisk
pcs constraint colocation add fail2ban with asterisk
pcs constraint colocation add ClusterIP with fail2ban
pcs constraint order start asterisk then vpbx-monitor
pcs constraint order start vpbx-monitor then fail2ban
pcs constraint order start fail2ban then ClusterIP
```

---

## 🔁 Manual Failover Example

To switch roles manually:

```bash
pcs node standby vitalpbx-master.local
sleep 5
pcs node unstandby vitalpbx-slave.local
```

To revert:

```bash
pcs node unstandby vitalpbx-master.local
pcs node standby vitalpbx-slave.local
```

Clear move constraints:

```bash
pcs resource clear DrbdData-clone
```

---

## 🔪 Verification

```bash
pcs status
```

Ensure the correct node has:

* DRBD promoted
* All services started
* Virtual IP bound

---

## 📝 Notes

* DRBD must be healthy before starting the cluster.
* Virtual IP will migrate automatically during failover.
* Always use `pcs` commands to interact with resources.
