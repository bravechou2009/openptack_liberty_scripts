#!/bin/bash
source com-config.cfg
source ~/admin-openrc.sh

echo "########## INSTALL CINDER ##########"
apt-get -y install lvm2 cinder-volume python-mysqldb

is_disk=$(fdisk -l /dev/$CINDER_VOLUME | egrep -c '(Disk)')
if [ "$is_disk" -gt 0 ]; then
echo "########## VOLUME CREATE FOR CINDER ##########"
#dd if=/dev/zero of=/dev/$CINDER_VOLUME bs=512 count=1
#partprobe
#pvcreate /dev/sdb1
#vgcreate vm-volumes /dev/sdb1

##fdisk /dev/sdb
##Command (m for help):n
##Select "p": enter
##Partition number (1-4, select 1): enter
##First cylinder (1-243188, default 1): enter
##Last cylinder, +cylinders or +size{K,M,G} (1-243188, default 243188): enter
##Command (m for help): w
##
##sfdisk -l /dev/sdb
##mkfs -t ext4 /dev/sdb1
##
##ls -l /dev/disk/by-uuid  or  blkid
##==> partion
##vi /etc/fstab
##UUID=80c1c321-af45-4c06-ae1a-a5032b8a6b36 /var/lib/nova ext4 defaults 0 0
##
##mount -a

vgremove cinder-volumes | awk '{print $1}' 1>&2 
pvremove /dev/$CINDER_VOLUME | awk '{print $1}' 1>&2 

pvcreate /dev/$CINDER_VOLUME
vgcreate cinder-volumes /dev/$CINDER_VOLUME

sed_str="s#(filter = )(\[ \\\"a/\.\*/\\\" \])#\1[\\\"a\/$CINDER_VOLUME\/\\\", \\\"r/\.\*\/\\\"]#g"
#echo $sed_str
sed -r -i "$sed_str" /etc/lvm/lvm.conf

fi


filename=/etc/cinder/cinder.conf
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[DEFAULT]
rootwrap_config = /etc/cinder/rootwrap.conf
api_paste_confg = /etc/cinder/api-paste.ini

rpc_backend = rabbit
auth_strategy = keystone
my_ip = $MGMT_IP
enabled_backends = lvm
glance_host = controller
verbose = True
lock_path = /var/lock/cinder

[oslo_messaging_rabbit]
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = $DEFAULT_PASS
 
[database]
connection = mysql+pymysql://cinder:$DEFAULT_PASS@controller/cinder
 
[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = cinder
password = $DEFAULT_PASS

[lvm]
volume_name_template = volume-%s
volumes_dir = /var/lib/cinder/volumes
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm
EOF

chown cinder:cinder $filename

rm -f /var/lib/cinder/cinder.sqlite

service tgt restart
service cinder-volume restart

exit 0