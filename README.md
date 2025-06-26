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
* A virtual floating IP (e.g. `192.168.1.250`) for VitalPBX services

| Node    | Hostname              | IP Address    |
| ------- | --------------------- | ------------- |
| Node 1  | vitalpbx-master.local | 192.168.1.10  |
| Node 2  | vitalpbx-slave.local  | 192.168.1.11  |
| Virtual | HA Cluster            | 192.168.1.250 |

---

## 🏗️ Installation Steps

### 1. Set Hostnames

```bash
hostnamectl set-hostname vitalpbx-master.local  # On Node 1
hostnamectl set-hostname vitalpbx-slave.local   # On Node 2
```

Edit `/etc/hosts` on both nodes:

```
192.168.1.10 vitalpbx-master.local
192.168.1.11 vitalpbx-slave.local
```

---

### 2. Install Required Packages

```bash
apt update && apt install -y drbd-utils pacemaker pcs corosync chrony rsync
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
