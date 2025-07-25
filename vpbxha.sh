#!/bin/bash
# This code is the property of VitalPBX LLC Company
# License: Proprietary
# Date: 26-June-2025
# VitalPBX Hight Availability with DRBD, Corosync, PCS and Pacemaker.
#
set -e
function jumpto
{
    label=$start
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

echo -e "\n"
echo -e "************************************************************"
echo -e "*  Welcome to the VitalPBX high availability installation  *"
echo -e "*                All options are mandatory                 *"
echo -e "************************************************************"

filename="config.txt"
if [ -f $filename ]; then
	echo -e "config file"
	n=1
	while read line; do
		case $n in
			1)
				ip_master=$line
  			;;
			2)
				ip_standby=$line
  			;;
			3)
				ip_floating=$line
  			;;
			4)
				ip_floating_mask=$line
  			;;
			5)
				disk=$line
  			;;
			6)
				hapassword=$line
  			;;
		esac
		n=$((n+1))
	done < $filename
	echo -e "IP Node 1................ > $ip_master"	
	echo -e "IP Node 2................ > $ip_standby"
	echo -e "Floating IP.............. > $ip_floating "
	echo -e "Floating IP Mask (SIDR).. > $ip_floating_mask"
 	echo -e "Disk (sdax).............. > $disk"
	echo -e "hacluster password....... > $hapassword"
fi

while [[ $ip_master == '' ]]
do
    read -p "IP Node 1................ > " ip_master 
done 

while [[ $ip_standby == '' ]]
do
    read -p "IP Node 2................ > " ip_standby 
done

while [[ $ip_floating == '' ]]
do
    read -p "Floating IP.............. > " ip_floating 
done 

while [[ $ip_floating_mask == '' ]]
do
    read -p "Floating IP Mask (SIDR).. > " ip_floating_mask
done

while [[ $disk == '' ]]
do
    read -p "Disk (sdax).............. > " disk 
done 

while [[ $hapassword == '' ]]
do
    read -p "hacluster password....... > " hapassword 
done

echo -e "************************************************************"
echo -e "*                   Check Information                      *"
echo -e "*        Make sure you have internet on both servers       *"
echo -e "************************************************************"
while [[ $veryfy_info != yes && $veryfy_info != no ]]
do
    read -p "Are you sure to continue with this settings? (yes,no) > " veryfy_info 
done

if [ "$veryfy_info" = yes ] ;then
	echo -e "************************************************************"
	echo -e "*                Starting to run the scripts               *"
	echo -e "************************************************************"
else
    	exit;
fi

cat > config.txt << EOF
$ip_master
$ip_standby
$ip_floating
$ip_floating_mask
$disk
$hapassword
EOF

echo -e "************************************************************"
echo -e "*            Get the hostname in Master and Standby         *"
echo -e "************************************************************"
host_master=`hostname`
host_standby=`ssh root@$ip_standby 'hostname'`
echo -e "$host_master"
echo -e "$host_standby"
echo -e "*** Done ***"

stepFile=step.txt
if [ -f $stepFile ]; then
	step=`cat $stepFile`
else
	step=0
fi

echo -e "Start in step: " $step

start="format_partition"
case $step in
	1)
		start="format_partition"
  	;;
	2)
		start="create_hostname"
  	;;
	3)
		start="configuring_firewall"
  	;;
	4)
		start="loading_drbd"
  	;;
	5)
		start="configure_drbd"
  	;;
	6)
		start="formating_drbd"
  	;;
	7)
		start="create_hacluster_password"
  	;;
	8)
		start="starting_pcs"
  	;;
	9)
		start="auth_hacluster"
	;;
	10)
		start="creating_cluster"
  	;;
	11)
		start="starting_cluster"
  	;;
	12)
		start="creating_floating_ip"
  	;;
	13)
		start="create_drbd_resource"
  	;;
	14)
		start="create_filesystem_resource"
  	;;
	15)
		start="disable_services"
  	;;
	16)
		start="create_mariadb_service"
	;;
	17)
		start="copy_asterisk_files"
	;;
	18)
		start="create_asterisk_service"
	;;
	19)
		start="create_vitalpbx_service"
	;;
	20)
		start="create_fail2ban_service"
	;;
	21)
		start="vitalpbx_create_bascul"
	;;
	22)
		start="vitalpbx_create_role"
	;;
	23)
		start="ceate_welcome_message"
	;;
	24)
		start="vitalpbx_ceate_destroy_rebuild"
	;;
esac
jumpto $start
echo -e "*** Done Step 1 ***"
echo -e "1"	> step.txt

format_partition:
echo -e "************************************************************"
echo -e "*             Format new drive in Master/Slave             *"
echo -e "************************************************************"
mkdir /vpbx_data
ssh root@$ip_standby "mkdir /vpbx_data"
mke2fs -j /dev/$disk
dd if=/dev/zero bs=1M count=500 of=/dev/$disk; sync
ssh root@$ip_standby "mke2fs -j /dev/$disk"
ssh root@$ip_standby "dd if=/dev/zero bs=1M count=500 of=/dev/$disk; sync"
echo -e "*** Done Step 2 ***"
echo -e "2"	> step.txt

create_hostname:
echo -e "************************************************************"
echo -e "*          Creating hosts name in Master/Standby           *"
echo -e "************************************************************"
echo -e "$ip_master \t$host_master" >> /etc/hosts
echo -e "$ip_standby \t$host_standby" >> /etc/hosts
ssh root@$ip_standby "echo -e '$ip_master \t$host_master' >> /etc/hosts"
ssh root@$ip_standby "echo -e '$ip_standby \t$host_standby' >> /etc/hosts"
echo -e "*** Done Step 3 ***"
echo -e "3"	> step.txt

configuring_firewall:
echo -e "************************************************************"
echo -e "*             Configuring Temporal Firewall                *"
echo -e "************************************************************"
#Create temporal Firewall Rules in Server 1 and 2
firewall-cmd --permanent --add-service=high-availability
firewall-cmd --permanent --add-rich-rule="rule family="ipv4" port port="7789" protocol="tcp" accept"
firewall-cmd --reload
ssh root@$ip_standby "firewall-cmd --permanent --add-service=high-availability"
ssh root@$ip_standby "firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="7789" protocol="tcp" accept'"
ssh root@$ip_standby "firewall-cmd --reload"

echo -e "************************************************************"
echo -e "*             Configuring Permanent Firewall               *"
echo -e "*   Creating Firewall Services in VitalPBX in Server 1     *"
echo -e "************************************************************"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA2224', 'tcp', '2224')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA3121', 'tcp', '3121')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA5403', 'tcp', '5403')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA5404-5405', 'udp', '5404-5405')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA21064', 'tcp', '21064')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA9929', 'both', '9929')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('DRBD7789', 'tcp', '7789')"
echo -e "************************************************************"
echo -e "*             Configuring Permanent Firewall               *"
echo -e "*     Creating Firewall Rules in VitalPBX in Server 1      *"
echo -e "************************************************************"
last_index=$(mysql -uroot ombutel -e "SELECT MAX(\`index\`) AS Consecutive FROM ombu_firewall_rules"  | awk 'NR==2')
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA2224'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA3121'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA5403'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA5404-5405'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA21064'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA9929'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'DRBD7789'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_whitelist (host, description, \`default\`) VALUES ('$ip_master', 'Server 1 IP', 'no')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_whitelist (host, description, \`default\`) VALUES ('$ip_standby', 'Server 2 IP', 'no')"
echo -e "*** Done Step 4 ***"
echo -e "4"	> step.txt

loading_drbd:
echo -e "************************************************************"
echo -e "*               Loading drbd in Master/Slave               *"
echo -e "************************************************************"
modprobe drbd
ssh root@$ip_standby "modprobe drbd"
systemctl enable drbd.service
ssh root@$ip_standby "systemctl enable drbd.service"
echo -e "*** Done Step 5 ***"
echo -e "5"	> step.txt

configure_drbd:
echo -e "************************************************************"
echo -e "*       Configure drbr resources in Master/Slave           *"
echo -e "************************************************************"
mv /etc/drbd.d/global_common.conf /etc/drbd.d/global_common.conf.orig
ssh root@$ip_standby "mv /etc/drbd.d/global_common.conf /etc/drbd.d/global_common.conf.orig"
cat > /etc/drbd.d/global_common.conf << EOF
global {
  	usage-count no;
}
common {
	net {
  		protocol C;
  	}
}
EOF
scp /etc/drbd.d/global_common.conf root@$ip_standby:/etc/drbd.d/global_common.conf

cat > /etc/drbd.d/drbd0.res << EOF
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
on $host_master {
	device /dev/drbd0;
   	disk /dev/$disk;
   	address $ip_master:7789;
	meta-disk internal;
}
on $host_standby {
	device /dev/drbd0;
   	disk /dev/$disk;
   	address $ip_standby:7789;
	meta-disk internal;
   	}
}
EOF

scp /etc/drbd.d/drbd0.res root@$ip_standby:/etc/drbd.d/drbd0.res
drbdadm create-md drbd0
ssh root@$ip_standby "drbdadm create-md drbd0"
drbdadm up drbd0
drbdadm primary drbd0 --force
ssh root@$ip_standby "drbdadm up drbd0"
sleep 3
echo -e "*** Done Step 6 ***"
echo -e "6"	> step.txt

formating_drbd:
echo -e "************************************************************"
echo -e "*              Formating drbd disk in Master               *"
echo -e "*           Wait, this process may take a while            *"
echo -e "************************************************************"
mkfs.xfs /dev/drbd0
mount /dev/drbd0 /vpbx_data
sleep 3
echo -e "*** Done Step 7 ***"
echo -e "7"	> step.txt

create_hacluster_password:
echo -e "************************************************************"
echo -e "*     Create password for hacluster in Master/Standby      *"
echo -e "************************************************************"
echo hacluster:$hapassword | chpasswd
ssh root@$ip_standby "echo hacluster:$hapassword | chpasswd"
echo -e "*** Done Step 8 ***"
echo -e "8"	> step.txt

starting_pcs:
echo -e "************************************************************"
echo -e "*         Starting pcsd services in Master/Standby         *"
echo -e "************************************************************"
systemctl start pcsd
ssh root@$ip_standby "systemctl start pcsd"
systemctl enable pcsd.service 
systemctl enable corosync.service 
systemctl enable pacemaker.service
ssh root@$ip_standby "systemctl enable pcsd.service"
ssh root@$ip_standby "systemctl enable corosync.service"
ssh root@$ip_standby "systemctl enable pacemaker.service"
echo -e "*** Done Step 9 ***"
echo -e "9"	> step.txt

auth_hacluster:
echo -e "************************************************************"
echo -e "*            Server Authenticate in Master                 *"
echo -e "************************************************************"
pcs cluster destroy
pcs host auth $host_master $host_standby -u hacluster -p $hapassword
echo -e "*** Done Step 10 ***"
echo -e "10"	> step.txt

creating_cluster:
echo -e "************************************************************"
echo -e "*              Creating Cluster in Master                  *"
echo -e "************************************************************"
pcs cluster setup cluster_vitalpbx $host_master $host_standby --force
echo -e "*** Done Step 11 ***"
echo -e "11"	> step.txt

starting_cluster:
echo -e "************************************************************"
echo -e "*           Starting/Settings Cluster in Master            *"
echo -e "************************************************************"
pcs cluster start --all
pcs cluster enable --all
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore
echo -e "*** Done Step 12 ***"
echo -e "12"	> step.txt

creating_floating_ip:
echo -e "************************************************************"
echo -e "*            Creating Floating IP in Master                *"
echo -e "************************************************************"
pcs resource create ClusterIP ocf:heartbeat:IPaddr2 ip=$ip_floating cidr_netmask=$ip_floating_mask op monitor interval=30s on-fail=restart
pcs cluster cib drbd_cfg
pcs cluster cib-push drbd_cfg --config
#Prevent Resources from Moving after Recovery
pcs resource defaults update resource-stickiness=INFINITY
echo -e "*** Done Step 13 ***"
echo -e "13"	> step.txt

create_drbd_resource:
echo -e "************************************************************"
echo -e "*             Create drbd resource in Server 1             *"
echo -e "************************************************************"
pcs cluster cib drbd_cfg
pcs -f drbd_cfg resource create DrbdData ocf:linbit:drbd drbd_resource=drbd0 op monitor interval=60s
pcs -f drbd_cfg resource promotable DrbdData promoted-max=1 promoted-node-max=1 clone-max=2 clone-node-max=1 notify=true
pcs cluster cib fs_cfg
pcs cluster cib-push drbd_cfg --config
echo -e "*** Done Step 14 ***"
echo -e "14"	> step.txt

create_filesystem_resource:
echo -e "************************************************************"
echo -e "*         Create filesystem resource in Server 1           *"
echo -e "************************************************************"
pcs cluster cib fs_cfg
pcs -f fs_cfg resource create DrbdFS Filesystem device="/dev/drbd0" directory="/vpbx_data" fstype="xfs"
pcs -f fs_cfg constraint colocation add DrbdFS with DrbdData-clone INFINITY with-rsc-role=Master
pcs -f fs_cfg constraint order promote DrbdData-clone then start DrbdFS
pcs -f fs_cfg constraint colocation add DrbdFS with ClusterIP INFINITY
pcs -f fs_cfg constraint order ClusterIP then DrbdFS
pcs cluster cib-push fs_cfg --config
echo -e "*** Done Step 15 ***"
echo -e "15"	> step.txt

disable_services:
echo -e "************************************************************"
echo -e "*             Disable Services in Server 1 and 2           *"
echo -e "************************************************************"
systemctl stop mariadb
systemctl disable mariadb
systemctl stop fail2ban
systemctl disable fail2ban
systemctl disable asterisk
systemctl stop asterisk
systemctl stop vpbx-monitor
systemctl disable vpbx-monitor
ssh root@$ip_standby "systemctl disable mariadb"
ssh root@$ip_standby "systemctl stop mariadb"
ssh root@$ip_standby "systemctl disable fail2ban"
ssh root@$ip_standby "systemctl stop fail2ban"
ssh root@$ip_standby "systemctl disable asterisk"
ssh root@$ip_standby "systemctl stop asterisk"
ssh root@$ip_standby "systemctl disable vpbx-monitor"
ssh root@$ip_standby "systemctl stop vpbx-monitor"
echo -e "*** Done Step 16 ***"
echo -e "16"	> step.txt

create_mariadb_service:
echo -e "************************************************************"
echo -e "*          Create MariaDB Service in Server 1              *"
echo -e "************************************************************"
mkdir /vpbx_data/mysql
mkdir /vpbx_data/mysql/data
cp -aR /var/lib/mysql/* /vpbx_data/mysql/data
chown -R mysql:mysql /vpbx_data/mysql
sed -i 's|^#datadir[ \t]*=[ \t]*/var/lib/mysql|datadir                 = /vpbx_data/mysql/data|' /etc/mysql/mariadb.conf.d/50-server.cnf
ssh root@$ip_standby "sed -i 's|^#datadir[ \t]*=[ \t]*/var/lib/mysql|datadir                 = /vpbx_data/mysql/data|' /etc/mysql/mariadb.conf.d/50-server.cnf"
#pcs resource create mysql ocf:heartbeat:mysql binary="/usr/bin/mysqld_safe" config="/etc/mysql/mariadb.conf.d/50-server.cnf" datadir="/vpbx_data/mysql/data" pid="/run/mysqld/mysql.pid" socket="/run/mysqld/mysql.sock" additional_parameters="--bind-address=0.0.0.0" op start timeout=60s op stop timeout=60s op monitor interval=20s timeout=30s on-fail=standby
pcs resource create mariadb service:mariadb op monitor interval=30s
pcs cluster cib fs_cfg
pcs cluster cib-push fs_cfg --config
pcs -f fs_cfg constraint colocation add mariadb with ClusterIP INFINITY
pcs -f fs_cfg constraint order DrbdFS then mariadb
pcs cluster cib-push fs_cfg --config
echo -e "*** Done Step 17 ***"
echo -e "17"	> step.txt

copy_asterisk_files:
echo -e "************************************************************"
echo -e "*            Copy Asterisk File in DRBD Disk               *"
echo -e "************************************************************"
tar -zcvf /mnt/var-asterisk.tgz /var/log/asterisk 
tar -zcvf /mnt/var-lib-asterisk.tgz /var/lib/asterisk
tar -zcvf /mnt/var-lib-vitalpbx.tgz /var/lib/vitalpbx
tar -zcvf /mnt/etc-vitalpbx.tgz /etc/vitalpbx
tar -zcvf /mnt/usr-lib-asterisk.tgz /usr/lib/asterisk
tar -zcvf /mnt/var-spool-asterisk.tgz /var/spool/asterisk
tar -zcvf /mnt/etc-asterisk.tgz /etc/asterisk

tar xvfz /mnt/var-asterisk.tgz -C /vpbx_data
tar xvfz /mnt/var-lib-asterisk.tgz -C /vpbx_data
tar xvfz /mnt/var-lib-vitalpbx.tgz -C /vpbx_data
tar xvfz /mnt/etc-vitalpbx.tgz -C /vpbx_data
tar xvfz /mnt/usr-lib-asterisk.tgz -C /vpbx_data
tar xvfz /mnt/var-spool-asterisk.tgz -C /vpbx_data
tar xvfz /mnt/etc-asterisk.tgz -C /vpbx_data
chmod -R 775 /vpbx_data/var/log/asterisk

rm -rf /var/log/asterisk 
rm -rf /var/lib/asterisk
rm -rf /var/lib/vitalpbx
rm -rf /etc/vitalpbx 
rm -rf /usr/lib/asterisk
rm -rf /var/spool/asterisk
rm -rf /etc/asterisk 

ln -s /vpbx_data/var/log/asterisk /var/log/asterisk 
ln -s /vpbx_data/var/lib/asterisk /var/lib/asterisk
ln -s /vpbx_data/var/lib/vitalpbx /var/lib/vitalpbx
ln -s /vpbx_data/etc/vitalpbx /etc/vitalpbx 
ln -s /vpbx_data/usr/lib/asterisk /usr/lib/asterisk 
ln -s /vpbx_data/var/spool/asterisk /var/spool/asterisk 
ln -s /vpbx_data/etc/asterisk /etc/asterisk

ssh root@$ip_standby 'rm -rf /var/log/asterisk'
ssh root@$ip_standby 'rm -rf /var/lib/asterisk'
ssh root@$ip_standby 'rm -rf /var/lib/vitalpbx'
ssh root@$ip_standby 'rm -rf /etc/vitalpbx'
ssh root@$ip_standby 'rm -rf /usr/lib/asterisk'
ssh root@$ip_standby 'rm -rf /var/spool/asterisk'
ssh root@$ip_standby 'rm -rf /etc/asterisk'

ssh root@$ip_standby 'ln -s /vpbx_data/var/log/asterisk /var/log/asterisk'
ssh root@$ip_standby 'ln -s /vpbx_data/var/lib/asterisk /var/lib/asterisk'
ssh root@$ip_standby 'ln -s /vpbx_data/var/lib/vitalpbx /var/lib/vitalpbx'
ssh root@$ip_standby 'ln -s /vpbx_data/etc/vitalpbx /etc/vitalpbx'
ssh root@$ip_standby 'ln -s /vpbx_data/usr/lib/asterisk /usr/lib/asterisk'
ssh root@$ip_standby 'ln -s /vpbx_data/var/spool/asterisk /var/spool/asterisk' 
ssh root@$ip_standby 'ln -s /vpbx_data/etc/asterisk /etc/asterisk'

rm -f /mnt/var-asterisk.tgz 
rm -f /mnt/var-lib-asterisk.tgz
rm -f /mnt/var-lib-vitalpbx.tgz
rm -f /mnt/etc-vitalpbx.tgz
rm -f /mnt/usr-lib-asterisk.tgz 
rm -f /mnt/var-spool-asterisk.tgz 
rm -f /mnt/etc-asterisk.tgz

echo -e "*** Done Step 18 ***"
echo -e "18"	> step.txt

create_asterisk_service:
echo -e "************************************************************"
echo -e "*          Create Asterisk Service in Server 1             *"
echo -e "************************************************************"
sed -i 's/RestartSec=10/RestartSec=1/g'  /usr/lib/systemd/system/asterisk.service
sed -i 's/Wants=mariadb.service/#Wants=mariadb.service/g'  /usr/lib/systemd/system/asterisk.service
sed -i 's/After=mariadb.service/#After=mariadb.service/g'  /usr/lib/systemd/system/asterisk.service
pcs resource create asterisk service:asterisk op monitor interval=30s
pcs cluster cib fs_cfg 
pcs cluster cib-push fs_cfg --config 
pcs -f fs_cfg constraint colocation add asterisk with ClusterIP INFINITY
pcs -f fs_cfg constraint order mariadb then asterisk
pcs cluster cib-push fs_cfg --config 
#Changing these values from 15s (default) to 120s is very important 
#since depending on the server and the number of extensions 
#the Asterisk can take more than 15s to start
pcs resource update asterisk op stop timeout=120s
pcs resource update asterisk op start timeout=120s
pcs resource update asterisk op restart timeout=120s
echo -e "*** Done Step 19 ***"
echo -e "19"	> step.txt

create_vitalpbx_service:
echo -e "************************************************************"
echo -e "*                 Create VitalPBX Service                  *"
echo -e "************************************************************"
pcs resource create vpbx-monitor service:vpbx-monitor op monitor interval=30s
pcs cluster cib fs_cfg 
pcs cluster cib-push fs_cfg --config 
pcs -f fs_cfg constraint colocation add vpbx-monitor with ClusterIP INFINITY
pcs -f fs_cfg constraint order asterisk then vpbx-monitor
pcs cluster cib-push fs_cfg --config 
echo -e "*** Done Step 20 ***"
echo -e "20"	> step.txt

create_fail2ban_service:
echo -e "************************************************************"
echo -e "*                 Create fail2ban Service                  *"
echo -e "************************************************************"
pcs resource create fail2ban service:fail2ban op monitor interval=30s
pcs cluster cib fs_cfg 
pcs cluster cib-push fs_cfg --config
pcs -f fs_cfg constraint colocation add fail2ban with ClusterIP INFINITY
pcs -f fs_cfg constraint order asterisk then fail2ban
pcs cluster cib-push fs_cfg --config
echo -e "*** Done Step 21 ***"
echo -e "21"	> step.txt

vitalpbx_create_bascul:
echo -e "************************************************************"
echo -e "*         Creating VitalPBX Cluster bascul Command         *"
echo -e "************************************************************"
wget https://raw.githubusercontent.com/VitalPBX/vitalpbx45_drbd_ha/main/bascul
yes | cp -fr bascul /usr/local/bin/bascul
chmod +x /usr/local/bin/bascul
scp /usr/local/bin/bascul root@$ip_standby:/usr/local/bin/bascul
ssh root@$ip_standby 'chmod +x /usr/local/bin/bascul'
echo -e "*** Done Step 22 ***"
echo -e "22"	> step.txt

vitalpbx_create_role:
echo -e "************************************************************"
echo -e "*         Creating VitalPBX Cluster role Command           *"
echo -e "************************************************************"
wget https://raw.githubusercontent.com/VitalPBX/vitalpbx45_drbd_ha/main/role
yes | cp -fr role /usr/local/bin/role
chmod +x /usr/local/bin/role
scp /usr/local/bin/role root@$ip_standby:/usr/local/bin/role
ssh root@$ip_standby 'chmod +x /usr/local/bin/role'
echo -e "*** Done Step 23 ***"
echo -e "23"	> step.txt

ceate_welcome_message:
echo -e "************************************************************"
echo -e "*              Creating Welcome message                    *"
echo -e "************************************************************"
/bin/cp -rf /usr/local/bin/role /etc/update-motd.d/20-vitalpbx
chmod 755 /etc/update-motd.d/20-vitalpbx
echo -e "*** Done ***"
scp /etc/update-motd.d/20-vitalpbx root@$ip_standby:/etc/update-motd.d/20-vitalpbx
ssh root@$ip_standby "chmod 755 /etc/update-motd.d/20-vitalpbx"
echo -e "*** Done Step 24 ***"
echo -e "24"	> step.txt

vitalpbx_ceate_destroy_rebuild:
echo -e "************************************************************"
echo -e "*    Creating VitalPBX destroy.sh and rebuild.sh Command    *"
echo -e "************************************************************"
wget https://raw.githubusercontent.com/VitalPBX/vitalpbx45_drbd_ha/main/destroy.sh
chmod +x destroy.sh
wget https://raw.githubusercontent.com/VitalPBX/vitalpbx45_drbd_ha/main/rebuild.sh
chmod +x rebuild.sh
echo -e "*** Done Step 25 END***"
echo -e "25"	> step.txt
ssh root@$ip_standby "mkdir -p /usr/share/vitalpbx/ha"
scp vpbxha.sh root@$ip_standby:/usr/share/vitalpbx/ha/vpbxha.sh
ssh root@$ip_standby "chmod 755 /usr/share/vitalpbx/ha/vpbxha.sh"
scp destroy.sh root@$ip_standby:/usr/share/vitalpbx/ha/destroy.sh
ssh root@$ip_standby "chmod 755 /usr/share/vitalpbx/ha/destroy.sh"
scp rebuild.sh root@$ip_standby:/usr/share/vitalpbx/ha/rebuild.sh
ssh root@$ip_standby "chmod 755 /usr/share/vitalpbx/ha/rebuild.sh"
scp step.txt root@$ip_standby:/usr/share/vitalpbx/ha/step.txt
ssh root@$ip_standby "chmod 755 /usr/share/vitalpbx/ha/step.txt"
scp config.txt root@$ip_standby:/usr/share/vitalpbx/ha/config.txt
ssh root@$ip_standby "chmod 755 /usr/share/vitalpbx/ha/config.txt"

vitalpbx_cluster_ok:
echo -e "************************************************************"
echo -e "*                VitalPBX Cluster OK                       *"
echo -e "*    Don't worry if you still see the status in Stop       *"
echo -e "*  sometimes you have to wait about 30 seconds for it to   *"
echo -e "*                 restart completely                       *"
echo -e "*         after 30 seconds run the command: role           *"
echo -e "************************************************************"
sleep 20
role
