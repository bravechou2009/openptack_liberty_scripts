#!/bin/bash
source aio-config.cfg
source ~/admin-openrc.sh

## ceilometer
if [ "$IS_TELEMETRY" -eq 1 ]; then
NOTI_TELEMETRY="notification_driver = messagingv2"
fi

echo "########## INSTALL CINDER ##########"
apt-get -y install cinder-api cinder-scheduler python-cinderclient lvm2 cinder-volume

##filename=/usr/lib/python2.7/dist-packages/oslo_messaging/_drivers/base.py
##sed -i 's/oslo.config/oslo_config/g' $filename
##
##filename=/usr/lib/python2.7/dist-packages/cinder/openstack/common/service.py
##sed -i 's/oslo.config/oslo_config/g' $filename
##
##filename=/usr/lib/python2.7/dist-packages/cinder/openstack/common/eventlet_backdoor.py
##sed -i 's/oslo.config/oslo_config/g' $filename

is_disk=$(fdisk -l /dev/$CINDER_VOLUME 2>&1 | fgrep -c 'Disk')
if [ "$is_disk" -gt 0 ]; then
echo "########## VOLUME CREATE FOR CINDER ##########"
##dd if=/dev/zero of=/dev/$CINDER_VOLUME bs=512 count=1
##partprobe
##pvcreate /dev/sdb1
##vgcreate vm-volumes /dev/sdb1

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

#vgremove cinder-volumes | awk '{print $1}' 1>&2 
#pvremove /dev/$CINDER_VOLUME | awk '{print $1}' 1>&2 

vgremove cinder-volumes
pvremove /dev/$CINDER_VOLUME

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
## refer
## http://docs.openstack.org/liberty/config-reference/content/section_cinder.conf.html
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

## ceilometer
$NOTI_TELEMETRY

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
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_name_template = volume-%s
volumes_dir = /var/lib/cinder/volumes
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm
EOF

chown cinder:cinder $filename

echo "##### DB SYNC #####"
cinder-manage db sync

rm -f /var/lib/cinder/cinder.sqlite

service cinder-scheduler restart
service cinder-api restart
service tgt restart
service cinder-volume restart

if [ "$IS_MLNX" -gt 0 ]; then
service tgt stop
update-rc.d -f tgt remove
fi

exit 0