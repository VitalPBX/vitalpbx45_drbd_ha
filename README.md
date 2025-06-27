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
---

### Create authorization key for the Access between the two servers without credentials.

Create key in **Node 1**.
```
ssh-keygen -f /root/.ssh/id_rsa -t rsa -N '' >/dev/null
ssh-copy-id root@192.168.10.32
```
<pre>
Are you sure you want to continue connecting (yes/no/[fingerprint])? <strong>yes</strong>
root@192.168.10.62's password: <strong>(remote server root’s password)</strong>

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.10.32'"
and check to make sure that only the key(s) you wanted were added. 

root@vitalpbx-master:~#
</pre>

Create key in **Node 2**.
```
ssh-keygen -f /root/.ssh/id_rsa -t rsa -N '' >/dev/null
ssh-copy-id root@192.168.10.31
```
<pre>
Are you sure you want to continue connecting (yes/no/[fingerprint])? <strong>yes</strong>
root@192.168.10.61's password: <strong>(remote server root’s password)</strong>

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.10.31'"
and check to make sure that only the key(s) you wanted were added. 

root@vitalpbx-slave:~#
</pre>

### Create partition in **Node 1 and Node 2**
```
fdisk /dev/sda
```

<pre>
Welcome to fdisk (util-linux 2.38.1).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

This disk is currently in use - repartitioning is probably a bad idea.
It's recommended to umount all file systems, and swapoff all swap
partitions on this disk.


Command (m for help): <strong>n</strong>
Partition type
   p   primary (1 primary, 1 extended, 2 free)
   l   logical (numbered from 5)
Select (default p): <strong>p</strong>
Partition number (3,4, default 3): <strong>3</strong>
First sector (39061504-266338303, default 39061504): <strong>[Enter]</strong>
Last sector, +/-sectors or +/-size{K,M,G,T,P} (39061504-264337407, default 264337407): <strong>[Enter]</strong>

Created a new partition 3 of type 'Linux' and of size 107.4 GiB.

Command (m for help): <strong>t</strong>
Partition number (1-3,5, default 5): <strong>3</strong>
Hex code or alias (type L to list all): <strong>8e</strong>

Changed type of partition 'Linux' to 'Linux LVM'.

Command (m for help): <strong>w</strong>
The partition table has been altered.
Syncing disks.
</pre>

Now restart both servers, **Node 1 and Node 2**
```
reboot
```

## Install VitalPBX 4.5
Install VitalPBX 4.5 on **Node 1 and Node 2**. Let's connect via SSH to each of them and run the following commands.
```
apt install sudo
wget https://repo.vitalpbx.com/vitalpbx/v4.5/pbx_installer.sh
chmod +x pbx_installer.sh
./pbx_installer.sh
```
---

## 🏗️ HA Installation Steps

### 1.- Install Required Packages
Install dependencies on **Node 1 and Node 2**.
```bash
apt update && apt install -y drbd-utils pacemaker pcs corosync chrony rsync xfsprogs
```
---

### 2.- Using Script
We have two ways to configure the Cluster. Using the following Script or following this manual step by step. If you decide to use the following Script, the next step you should follow in this manual is 3 if you consider it necessary. Otherwise continue with step 4.<br>

Now copy and run the following script in **Node 1**.
```
mkdir /usr/share/vitalpbx/ha
cd /usr/share/vitalpbx/ha
wget https://raw.githubusercontent.com/VitalPBX/vitalpbx45_drbd_ha/main/vpbxha.sh
chmod +x vpbxha.sh
./vpbxha.sh
```

Now we enter all the information requested.
<pre>
************************************************************
*  Welcome to the VitalPBX high availability installation  *
*                All options are mandatory                 *
************************************************************
IP Server1............... > <strong>192.168.10.31</strong>
IP Server2............... > <strong>192.168.10.32</strong>
Floating IP.............. > <strong>192.168.10.30</strong>
Floating IP Mask (SIDR).. > <strong>24</strong>
Disk (sdax).............. > <strong>sda3</strong>
hacluster password....... > <strong>MyPassword</strong>
************************************************************
*                   Check Information                      *
*        Make sure you have internet on both servers       *
************************************************************
Are you sure to continue with this settings? (yes,no) > <strong>yes</strong>
</pre>
Note:<br>
Before doing any high availability testing, make sure that the data has finished syncing. To do this, use the cat /proc/drbd command.<br>
CONGRATULATIONS, you have installed high availability in VitalPBX 4

### 3.- Add Hostnames to /etc/hots

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

### 4.- Format partition
Now, we will proceed to format the new partition in **Node 1 and Node 2**.
```
mkdir /vpbx_data
mke2fs -j /dev/sda3
dd if=/dev/zero bs=1M count=500 of=/dev/sda3; sync
```

### 5.- Firewall
Configure the Firewall (Both Servers - **Node 1 and Node 2**)

#### Required Ports

| Port           | Description |
|----------------|-------------|
| **TCP 2224**   | Required on all nodes (needed by the `pcsd` Web UI and for node-to-node communication).<br>It is **crucial** to open port 2224 in such a way that `pcs` from any node can talk to all nodes in the cluster, including itself.<br><br>When using the **Booth cluster ticket manager** or a **quorum device**, you must open port 2224 on **all related hosts**, such as Booth arbiters or the quorum device host. |
| **TCP 3121**   | Required on all nodes if the cluster has any **Pacemaker Remote** nodes.<br><br>`crmd` (on full cluster nodes) will contact `pacemaker_remoted` (on remote nodes) at port 3121.<br><br>If a separate interface is used for cluster communication, the port only needs to be open on that interface.<br><br>At a minimum, open the port on **Pacemaker Remote nodes** to **full cluster nodes**. However, it can be useful to open the port to **all nodes** to allow flexibility in node roles (e.g., full ↔ remote, or containers using host network).<br><br>It is **not necessary** to open this port to non-cluster hosts. |
| **TCP 5403**   | Required on the **quorum device host** when using a quorum device with `corosync-qnetd`.<br>The default port (5403) can be changed with the `-p` option of the `corosync-qnetd` command. |
| **UDP 5404**   | Required on **corosync nodes** if `corosync` is configured for **multicast UDP**. |
| **UDP 5405**   | Required on **all corosync nodes** (used by `corosync`). |
| **TCP 21064**  | Required on **all nodes** if the cluster contains resources using **DLM** (e.g., `clvm`, `GFS2`). |
| **TCP & UDP 9929** | Required on **all cluster nodes** and **Booth arbitrator nodes** to communicate when the **Booth ticket manager** is used for multi-site clustering. |
| **TCP 7789**   | Required by **DRBD** to synchronize data between nodes. |

---

#### Firewall Service Setup

On **both servers**, perform the following steps:

1. Go to:  
   `ADMIN → Firewall → Services → Add Service`
2. Add a new service including all the required ports listed above.
  ![image](https://github.com/user-attachments/assets/f5a0dc29-3637-4acb-9618-200fbb20f399)

3. Create a **Firewall Rule** allowing this service.
![image](https://github.com/user-attachments/assets/23b16984-2806-43c3-9667-f04d7e70fc07)

### 6.- Configuring DRBD
Load the module and enable the service in **Node 1 and Node 2**.
```
modprobe drbd
systemctl enable drbd.service
```

Create a new global_common.conf file in **Node 1 and Node 2**.
```
mv /etc/drbd.d/global_common.conf /etc/drbd.d/global_common.conf.orig
nano /etc/drbd.d/global_common.conf
```

```
global {
  usage-count no;
}
  common {
net {
  protocol C;
  }
}
```

Next, we will need to create a new configuration file /etc/drbd.d/drbd0.res for the new resource named drbd0 in **Node 1 and Node 2**.
```
nano /etc/drbd.d/drbd0.res
```
```
resource drbd0 {
startup {
        wfc-timeout  5;
	outdated-wfc-timeout 3;
        degr-wfc-timeout 3;
	outdated-wfc-timeout 2;
}
syncer {
	rate 10M;
 	verify-alg md5;
}
net {
    after-sb-0pri discard-older-primary;
    after-sb-1pri discard-secondary;
    after-sb-2pri call-pri-lost-after-sb;
}
handlers {
    pri-lost-after-sb "/sbin/reboot";
}
on vitalpbx-master.local {
	device /dev/drbd0;
   	disk /dev/sda3;
   	address 192.168.10.31:7789;
	meta-disk internal;
}
on vitalpbx-slave.local {
	device /dev/drbd0;
   	disk /dev/sda3;
   	address 192.168.10.32:7789;
	meta-disk internal;
   	}
}
```
Note:
Although the access interfaces can be used, which in this case is ETH0. It is recommended to use an interface (ETH1) for synchronization, this interface must be directly connected between both servers.<br>

Initialize the meta data storage on each nodes by executing the following command in **Node 1 and Node 2**.
```
drbdadm create-md drbd0
```
<pre>
 Writing meta data...
New drbd meta data block successfully created.
</pre>

Let’s define the DRBD Primary node as first node “vitalpbx-master” (**Node 1**).
```
drbdadm up drbd0
drbdadm primary drbd0 --force
```

On the Secondary node “vitalpbx-slave” run the following command to start the drbd0 (**Node 2**).
```
drbdadm up drbd0
```
You can check the current status of the synchronization while it’s being performed. The cat /proc/drbd command displays the creation and synchronization progress of the resource. <br>


#### Formatting and Test DRBD Disk
In order to test the DRBD functionality we need to Create a file system, mount the volume and write some data on primary node “vitalpbx-master” and finally switch the primary node to “vitalpbx-slave”

Run the following command on the primary node to create an xfs filesystem on /dev/drbd0 and mount it to the mnt directory, using the following commands (**Node 1**).
```
mkfs.xfs /dev/drbd0
mount /dev/drbd0 /vpbx_data
```

Create some data using the following command: (**Node 1**).
```
touch /vpbx_data/file{1..5}
ls -l /vpbx_data
```
<pre>
-rw-r--r-- 1 root root 0 Nov 17 11:28 file1
-rw-r--r-- 1 root root 0 Nov 17 11:28 file2
-rw-r--r-- 1 root root 0 Nov 17 11:28 file3
-rw-r--r-- 1 root root 0 Nov 17 11:28 file4
-rw-r--r-- 1 root root 0 Nov 17 11:28 file5
</pre>

Let’s now switch primary mode “vitalpbx-server” to second node “vitalpbx-slave” to check the data replication works or not.<br>
First, we have to unmount the volume drbd0 on the first drbd cluster node “vitalpbx-master” and change the primary node to secondary node on the first drbd cluster node “vitalpbx-master” (**Node 1**).<br>
```
umount /vpbx_data
drbdadm secondary drbd0
```
Change the secondary node to primary node on the second drbd cluster node “vitalpbx-slave” (**Node 2**).
```
drbdadm up drbd0
drbdadm primary drbd0 --force
```

Mount the volume and check the data available or not (**Node 2**).
```
mount /dev/drbd0 /vpbx_data
ls -l  /vpbx_data
```
<pre>
-rw-r--r-- 1 root root 0 Nov 17 11:28 file1
-rw-r--r-- 1 root root 0 Nov 17 11:28 file2
-rw-r--r-- 1 root root 0 Nov 17 11:28 file3
-rw-r--r-- 1 root root 0 Nov 17 11:28 file4
-rw-r--r-- 1 root root 0 Nov 17 11:28 file5
</pre>

Normalize Server-Slave (**Node 2**).
```
umount /vpbx_data
drbdadm secondary drbd0
```

Normalize Server-Master (**Node 1**).
```
drbdadm primary drbd0
mount /dev/drbd0 /vpbx_data
```

### 7. Configure Cluster

Create the password of the hacluster user in **Node 1 and Node 2**.

```
echo hacluster:Mypassword | chpasswd
```

Start PCS in **Node 1 and Node 2**.
```
systemctl start pcsd 
```

Configure the start of services in **Node 1 and Node 2**.
```
systemctl enable pcsd.service 
systemctl enable corosync.service 
systemctl enable pacemaker.service
```

Server Authenticate in Master
On vitalpbx-master, use pcs cluster auth to authenticate as the hacluster user (**Node 1**).
```
pcs cluster destroy
pcs host auth vitalpbx-master.local vitalpbx-slave.local -u hacluster -p Mypassword
```
<pre>
 vitalpbx-master.local: Authorized
vitalpbx-slave.local: Authorized
</pre>

Next, use pcs cluster setup on the vitalpbx-master to generate and synchronize the corosync configuration  (**Node 1**).
```
pcs cluster setup cluster_vitalpbx vitalpbx-master.local vitalpbx-slave.local --force
```

Starting Cluster in Master (**Node 1**).
```
pcs cluster start --all
pcs cluster enable --all
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore
```

Prevent Resources from Moving after Recovery<br>
In most circumstances, it is highly desirable to prevent healthy resources from being moved around the cluster. Moving resources almost always requires a period of downtime. For complex services such as databases, this period can be quite long (**Node 1**).
```
pcs resource defaults update resource-stickiness=INFINITY
```


Create resource for the use of Floating IP (**Node 1**).
```
pcs resource create ClusterIP ocf:heartbeat:IPaddr2 ip=192.168.10.30 cidr_netmask=24 op monitor interval=30s on-fail=restart
pcs cluster cib drbd_cfg
pcs cluster cib-push drbd_cfg --config
```

Create resource for the use of DRBD (**Node 1**).
```
pcs cluster cib drbd_cfg
pcs -f drbd_cfg resource create DrbdData ocf:linbit:drbd drbd_resource=drbd0 op monitor interval=60s
pcs -f drbd_cfg resource promotable DrbdData promoted-max=1 promoted-node-max=1 clone-max=2 clone-node-max=1 notify=true
pcs cluster cib fs_cfg
pcs cluster cib-push drbd_cfg --config
```

Create FILESYSTEM resource for the automated mount point (**Node 1**).
```
pcs cluster cib fs_cfg
pcs -f fs_cfg resource create DrbdFS Filesystem device="/dev/drbd0" directory="/vpbx_data" fstype="xfs" 
pcs -f fs_cfg constraint colocation add DrbdFS with DrbdData-clone INFINITY with-rsc-role=Master 
pcs -f fs_cfg constraint order promote DrbdData-clone then start DrbdFS
pcs -f fs_cfg constraint colocation add DrbdFS with ClusterIP INFINITY
pcs -f fs_cfg constraint order DrbdData-clone then DrbdFS
pcs cluster cib-push fs_cfg --config
```

Stop and disable all services in both servers (**Node 1 and Node 2**).
```
systemctl stop mariadb
systemctl disable mariadb
systemctl stop fail2ban
systemctl disable fail2ban
systemctl stop asterisk
systemctl disable asterisk
systemctl stop vpbx-monitor
systemctl disable vpbx-monitor
```

Create resource for the use of MariaDB in Master (**Node 1**).
```
mkdir /vpbx_data/mysql 
mkdir /vpbx_data/mysql/data 
cp -aR /var/lib/mysql/* /vpbx_data/mysql/data
chown -R mysql:mysql /vpbx_data/mysql
sed -i 's/var\/lib\/mysql/vpbx_data\/mysql\/data/g' /etc/mysql/mariadb.conf.d/50-server.cnf
pcs resource create mysql service:mariadb op monitor interval=30s
pcs cluster cib fs_cfg
pcs cluster cib-push fs_cfg --config
pcs -f fs_cfg constraint colocation add mysql with ClusterIP INFINITY
pcs -f fs_cfg constraint order DrbdFS then mysql
pcs cluster cib-push fs_cfg --config
```

Change 50-server.cnf in Slave (**Node 2**).
```
sed -i 's/var\/lib\/mysql/vpbx_data\/mysql\/data/g' /etc/mysql/mariadb.conf.d/50-server.cnf
```

Path Asterisk service in both servers (**Node 1 nad Node 2**).
```
sed -i 's/RestartSec=10/RestartSec=1/g'  /usr/lib/systemd/system/asterisk.service
sed -i 's/Wants=mariadb.service/#Wants=mariadb.service/g'  /usr/lib/systemd/system/asterisk.service
sed -i 's/After=mariadb.service/#After=mariadb.service/g'  /usr/lib/systemd/system/asterisk.service
```

Create resource for Asterisk (**Node 1**).
```
pcs resource create asterisk service:asterisk op monitor interval=30s
pcs cluster cib fs_cfg
pcs cluster cib-push fs_cfg --config
pcs -f fs_cfg constraint colocation add asterisk with ClusterIP INFINITY
pcs -f fs_cfg constraint order mysql then asterisk
pcs cluster cib-push fs_cfg --config
pcs resource update asterisk op stop timeout=120s
pcs resource update asterisk op start timeout=120s
pcs resource update asterisk op restart timeout=120s
```

Copy folders and files the DRBD partition on the Master (**Node 1**).
```
tar -zcvf var-asterisk.tgz /var/log/asterisk 
tar -zcvf var-lib-asterisk.tgz /var/lib/asterisk
tar -zcvf var-lib-vitalpbx.tgz /var/lib/vitalpbx
tar -zcvf etc-vitalpbx.tgz /etc/vitalpbx
tar -zcvf usr-lib-asterisk.tgz /usr/lib/asterisk
tar -zcvf var-spool-asterisk.tgz /var/spool/asterisk
tar -zcvf etc-asterisk.tgz /etc/asterisk
 ```
```
tar xvfz var-asterisk.tgz -C /vpbx_data
tar xvfz var-lib-asterisk.tgz -C /vpbx_data
tar xvfz var-lib-vitalpbx.tgz -C /vpbx_data
tar xvfz etc-vitalpbx.tgz -C /vpbx_data
tar xvfz usr-lib-asterisk.tgz -C /vpbx_data
tar xvfz var-spool-asterisk.tgz -C /vpbx_data
tar xvfz etc-asterisk.tgz -C /vpbx_data
chmod -R 775 /vpbx_data/var/log/asterisk
```
```
rm -rf /var/log/asterisk
rm -rf /var/lib/asterisk
rm -rf /var/lib/vitalpbx
rm -rf /etc/vitalpbx
rm -rf /usr/lib/asterisk
rm -rf /var/spool/asterisk
rm -rf /etc/asterisk 
```
```
ln -s /vpbx_data/var/log/asterisk /var/log/asterisk 
ln -s /vpbx_data/var/lib/asterisk /var/lib/asterisk
ln -s /vpbx_data/var/lib/vitalpbx /var/lib/vitalpbx
ln -s /vpbx_data/etc/vitalpbx /etc/vitalpbx
ln -s /vpbx_data/usr/lib/asterisk /usr/lib/asterisk 
ln -s /vpbx_data/var/spool/asterisk /var/spool/asterisk 
ln -s /vpbx_data/etc/asterisk /etc/asterisk
```
```
rm -rf var-asterisk.tgz
rm -rf var-lib-asterisk.tgz
rm -rf var-lib-vitalpbx.tgz
rm -rf etc-vitalpbx.tgz
rm -rf usr-lib-asterisk.tgz
rm -rf var-spool-asterisk.tgz
rm -rf etc-asterisk.tgz
```

Configure symbolic links on the Slave (**Node 2**).
```
rm -rf /var/log/asterisk 
rm -rf /var/lib/asterisk
rm -rf /var/lib/vitalpbx
rm -rf /etc/vitalpbx 
rm -rf /usr/lib/asterisk
rm -rf /var/spool/asterisk
rm -rf /etc/asterisk
```
```
ln -s /vpbx_data/var/log/asterisk /var/log/asterisk 
ln -s /vpbx_data/var/lib/asterisk /var/lib/asterisk
ln -s /vpbx_data/var/lib/vitalpbx /var/lib/vitalpbx
ln -s /vpbx_data/etc/vitalpbx /etc/vitalpbx
ln -s /vpbx_data/usr/lib/asterisk /usr/lib/asterisk 
ln -s /vpbx_data/var/spool/asterisk /var/spool/asterisk 
ln -s /vpbx_data/etc/asterisk /etc/asterisk
```

Create VitalPBX Service (**Node 1**).
```
pcs resource create vpbx-monitor service:vpbx-monitor op monitor interval=30s
pcs cluster cib fs_cfg 
pcs cluster cib-push fs_cfg --config
pcs -f fs_cfg constraint colocation add vpbx-monitor with ClusterIP INFINITY 
pcs -f fs_cfg constraint order asterisk then vpbx-monitor 
pcs cluster cib-push fs_cfg --config
```

Create fail2ban Service (**Node 1**).
```
pcs resource create fail2ban service:fail2ban op monitor interval=30s
pcs cluster cib fs_cfg 
pcs cluster cib-push fs_cfg --config
pcs -f fs_cfg constraint colocation add fail2ban with ClusterIP INFINITY 
pcs -f fs_cfg constraint order asterisk then fail2ban 
pcs cluster cib-push fs_cfg --config
```
Note:
All configuration is stored in the file: /var/lib/pacemaker/cib/cib.xml<br>

Show the Cluster Status (**Node 1**).
```
pcs status resources
```
<pre>
  * ClusterIP  (ocf::heartbeat:IPaddr2):        Started vitalpbx-master.local
  * Clone Set: DrbdData-clone [DrbdData] (promotable):
    * Masters: [ vitalpbx-master.local ]
    * Slaves: [ vitalpbx-slave.local ]
  * DrbdFS      (ocf::heartbeat:Filesystem):     Started vitalpbx-master.local
  * mysql       (ocf::heartbeat:mysql):  Started vitalpbx-master.local
  * asterisk    (service:asterisk):      Started vitalpbx-master.local
  * vpbx-monitor        (service:vpbx-monitor):  Started vitalpbx-master.local
  * fail2ban    (service:fail2ban):      Started vitalpbx-master.local
</pre>

Note:<br>
Before doing any high availability testing, make sure that the data has finished syncing. To do this, use the cat /proc/drbd command.
```
cat /proc/drbd
```
<pre>
version: 8.4.11 (api:1/proto:86-101)
srcversion: 96ED19D4C144624490A9AB1 
 0: cs:Connected ro:Primary/Secondary ds:UpToDate/UpToDate C r-----
    ns:12909588 nr:2060 dw:112959664 dr:12655881 al:453 bm:0 lo:0 pe:0 ua:0 ap:0 ep:1 wo:f oos:0
</pre>


#### Bind Address
Managing the bind address also is critical if you use multple IP addresses on the same NIC [as, for example, when using a floating IP address in an HA cluster]. In that circumstance, asterisk has a rather nasty habit of listening for SIP/IAX on the virtual IP address but replying on the base address of the NIC causing phones/trunks to fail to register.<br>
In the Master server go to SETTINGS/PJSIP Settings and configure the Floating IP that we are going to use in "Bind" and "TLS Bind". Also do it in SETTINGS/SIP Settings Tab NETWORK fields "TCP Bind Address" and "TLS Bind Address".<br>
![image](https://github.com/user-attachments/assets/fd80e887-7bf3-4129-abb8-f9319ca30103)<br>

#### Create “bascul” command in both servers
The bascul command permanently moves services from one server to another. If you want to return the services to the main server you must execute the command again. (**Node 1 and Node 2**).<br>
Download file
```
wget https://raw.githubusercontent.com/VitalPBX/vitalpbx45_drbd_ha/main/bascul
```

Or create file<br>
```
nano /usr/local/bin/bascul
```

Paste
```
#!/bin/bash
# VitalPBX LLC - HA Role Switch Script
# Date: 2025-06-25
# License: Proprietary

set -e

progress_bar() {
    local duration=$1
    for ((elapsed = 1; elapsed <= duration; elapsed++)); do
        printf "\r["
        for ((i = 0; i < elapsed; i++)); do printf "#"; done
        for ((i = elapsed; i < duration; i++)); do printf " "; done
        printf "] %d%%" $((elapsed * 100 / duration))
        sleep 1
    done
    printf "\n"
}

# Extract promoted and stopped node from pcs status
host_master=$(pcs status | grep "Promoted:" | awk -F'[][]' '{print $2}' | xargs)
host_standby=$(pcs status | grep "Unpromoted:" | awk -F'[][]' '{print $2}' | xargs)

# Validate
if [[ -z "$host_master" || -z "$host_standby" ]]; then
    echo -e "\e[41m Error: Could not detect cluster nodes from DRBD status. \e[0m"
    exit 1
fi

# Confirm switch
echo -e "************************************************************"
echo -e "*     Change the roles of servers in high availability     *"
echo -e "* \e[41m WARNING: All current calls will be dropped!         \e[0m *"
echo -e "************************************************************"
read -p "Are you sure to switch from $host_master to $host_standby? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Aborted by user. No changes applied."
    exit 0
fi

# Ensure both nodes are not in standby
pcs node unstandby "$host_master" || true
pcs node unstandby "$host_standby" || true

# Clear previous constraints if exist
pcs resource clear DrbdData-clone || true
pcs resource clear ClusterIP || true

# Put current master into standby
echo "Putting $host_master into standby..."
pcs node standby "$host_master"

# Wait for switchover
echo "Waiting for cluster to promote $host_standby..."
progress_bar 10

# Sets the one that remains in Standby to Unpromoted to prevent it from remaining in the Stopped state
echo "Putting $host_master into unstandby..."
pcs node unstandby "$host_master"

# Display final status
echo -e "\n\033[1;32mSwitch complete. Current cluster status:\033[0m"
sleep  5
role 

exit 0
```

Add permissions and move to folder /usr/local/bin
```
chmod +x /usr/local/bin/bascul
```

#### Create “role” command in both servers
Download file<br>
```
wget https://raw.githubusercontent.com/VitalPBX/vitalpbx45_drbd_ha/main/role
```

Or create file
```
nano /usr/local/bin/role
```

Paste
```
#!/bin/bash
# This code is the property of VitalPBX LLC Company
# License: Proprietary
# Date: 8-Agu-2023
# Show the Role of Server.
#Bash Colour Codes
green="\033[00;32m"
yellow="\033[00;33m"
txtrst="\033[00;0m"
linux_ver=`cat /etc/os-release | grep -e PRETTY_NAME | awk -F '=' '{print $2}' | xargs`
vpbx_version=`aptitude versions vitalpbx | awk '{ print $2 }'`
server_master=`pcs status resources | awk 'NR==1 {print $5}'`
host=`hostname`
if [[ "${server_master}" = "${host}" ]]; then
        server_mode="Master"
else
        server_mode="Standby"
fi
logo='
 _    _ _           _ ______ ______ _    _
| |  | (_)_        | (_____ (____  \ \  / /
| |  | |_| |_  ____| |_____) )___)  ) \/ /
 \ \/ /| |  _)/ _  | |  ____/  __  ( )  (
  \  / | | |_( ( | | | |    | |__)  ) /\ \\
   \/  |_|\___)_||_|_|_|    |______/_/  \_\\
'
echo -e "
${green}
${logo}
${txtrst}
 Role           : $server_mode
 Version        : ${vpbx_version//[[:space:]]}
 Asterisk       : `asterisk -rx "core show version" 2>/dev/null| grep -ohe 'Asterisk [0-9.]*'`
 Linux Version  : ${linux_ver}
 Welcome to     : `hostname`
 Uptime         : `uptime | grep -ohe 'up .*' | sed 's/up //g' | awk -F "," '{print $1}'`
 Load           : `uptime | grep -ohe 'load average[s:][: ].*' | awk '{ print "Last Minute: " $3" Last 5 Minutes: "$4" Last 15 Minutes "$5 }'`
 Users          : `uptime | grep -ohe '[0-9.*] user[s,]'`
 IP Address     : ${green}`ip addr | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | xargs `${txtrst}
 Clock          :`timedatectl | sed -n '/Local time/ s/^[ \t]*Local time:\(.*$\)/\1/p'`
 NTP Sync.      :`timedatectl |awk -F: '/NTP service/ {print $2}'`
"
echo -e ""
echo -e "************************************************************"
if [[ "${server_mode}" = "Master" ]]; then
echo -e "*                Server Status: ${green}$server_mode${txtrst}                     *"
else
echo -e "*                Server Status: ${yellow}$server_mode${txtrst}                     *"
fi
echo -e "************************************************************"
pcs status resources
echo -e "************************************************************"
echo -e ""
echo -e "Servers Status"
pcs status pcsd
```

Add permissions and copy to folder /etc/profile.d/
```
cp -rf role /etc/profile.d/vitalwelcome.sh
chmod 755 /etc/profile.d/vitalwelcome.sh
```

Now add permissions and move to folder /usr/local/bin
```
chmod +x /usr/local/bin/role
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
