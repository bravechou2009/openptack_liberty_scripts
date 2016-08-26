#!/bin/bash
source net-config.cfg
source ~/admin-openrc.sh

install_path=`pwd`

echo "##### INSTALL GLANCE ##### "
apt-get -y install glance python-glanceclient

filename=/etc/glance/glance-api.conf
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[DEFAULT]
notification_driver = noop
verbose = True

[database]
connection = mysql+pymysql://glance:$DEFAULT_PASS@controller/glance
backend = sqlalchemy

[glance_store]
default_store = file
filesystem_store_datadir = /var/lib/glance/images/

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = glance
password = $DEFAULT_PASS

[paste_deploy]
flavor = keystone
EOF

chown glance:glance $filename

filename=/etc/glance/glance-registry.conf
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[DEFAULT]
notification_driver = noop
verbose = True

[database]
connection = mysql+pymysql://glance:$DEFAULT_PASS@controller/glance
backend = sqlalchemy

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = glance
password = $DEFAULT_PASS

[paste_deploy]
flavor = keystone
EOF

chown glance:glance $filename

echo "##### DB SYNC #####"
glance-manage db_sync

service glance-registry restart
service glance-api restart

apt-get -y install qemu-utils

mkdir -p ~/images
cd ~/images

echo "############ CREATE CIRROS IMAGE ##############"
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
glance image-create --name "cirros-0.3.4-x86_64" --file cirros-0.3.4-x86_64-disk.img \
--disk-format qcow2 --container-format bare --visibility public --progress

##echo "############ CREATE UBUNTU (UBUNTU/UBUNTU) ##############"
##wget http://uec-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
##
##qemu-img convert -c -O qcow2 trusty-server-cloudimg-amd64-disk1.img trusty-server-cloudimg-amd64-disk1_8GB.qcow2
##qemu-img resize trusty-server-cloudimg-amd64-disk1_8GB.qcow2 +8G
##modprobe nbd
##qemu-nbd -c /dev/nbd0 `pwd`/trusty-server-cloudimg-amd64-disk1_8GB.qcow2
##ls image || mkdir image
##mount /dev/nbd0p1 image
##
##sed -ri 's|(/boot/vmlinuz-.*-generic\s*root=LABEL=cloudimg-rootfs.*)$|\1 ds=nocloud|' image/boot/grub/grub.cfg
##sed -ri 's|^(GRUB_CMDLINE_LINUX_DEFAULT=).*$|\1" ds=nocloud"|' image/etc/default/grub
##sed -ri 's|^#(GRUB_TERMINAL=console)$|\1|' image/etc/default/grub
##
##mkdir -p image/var/lib/cloud/seed/nocloud
##
##tee image/var/lib/cloud/seed/nocloud/meta-data <<EOF
##instance-id: ubuntu
##local-hostname: ubuntu
##EOF
##
##tee image/var/lib/cloud/seed/nocloud/user-data <<EOF
###cloud-config
##password: ubuntu
##chpasswd: { expire: False }
##ssh_pwauth: True
##EOF
##
##sed -ri "s|^(127.0.0.1\s*localhost)$|\1\n127.0.0.1 `cat image/etc/hostname`|" image/etc/hosts
##
##sync
##umount image
##qemu-nbd -d /dev/nbd0
##modprobe -r nbd > /dev/null 2>&1
##
##glance image-create --name "ubuntu-server-14.04" \
## --file trusty-server-cloudimg-amd64-disk1_8GB.qcow2 \
## --disk-format qcow2 --container-format bare --visibility public --progress
##
##glance image-list

## android download
## http://sourceforge.net/projects/androidx86-openstack/?source=typ_redirect
#glance image-create --name "androidx86-4.4" \
# --file androidx86-4.4.qcow2 \
# --disk-format qcow2 --container-format bare --visibility public --progress

rm -rf ~/images

cd $install_path

exit 0
