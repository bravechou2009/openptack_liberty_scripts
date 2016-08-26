#!/bin/bash
source net-config.cfg

#echo "########## INSTALL OPENSTACK PACKAGES(liberty) ##########"
#apt-get install software-properties-common -y
#add-apt-repository cloud-archive:liberty -y

filename=/etc/hosts
test -f $filename.org || cp $filename $filename.org
rm -f $filename

echo "########## SET HOSTNAME ##########"
hostname $HOSTNAME
echo "$HOSTNAME" > /etc/hostname

cat << EOF > $filename
127.0.0.1 localhost
$NET_IP $NET_NAME
$COM_IP $COM_NAME
EOF

filename=/etc/sysctl.conf
test -f $filename.org || cp $filename $filename.org
rm -f $filename

# Enable IP forwarding
cat << EOF > /etc/sysctl.conf
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
EOF

sysctl -p

#echo "########## UPDATE PACKAGE FOR LIBERTY ##########"
#apt-get -y update && apt-get -y dist-upgrade

echo "########## INSTALL NTP ##########"
apt-get -y install ntp

## Config NTP
sed -i 's/^server /#server /g' /etc/ntp.conf
sed -i 's/#server ntp.ubuntu.com/server controller iburst/g' /etc/ntp.conf

sed -i 's/restrict -4 default kod notrap nomodify nopeer noquery/ \
#restrict -4 default kod notrap nomodify nopeer noquery/g' /etc/ntp.conf

sed -i 's/restrict -6 default kod notrap nomodify nopeer noquery/ \
restrict -4 default kod notrap nomodify \
restrict -6 default kod notrap nomodify/g' /etc/ntp.conf

service ntp restart

echo "########## SET RABBITMQ ##########"
curl -O https://www.rabbitmq.com/rabbitmq-signing-key-public.asc
apt-key add rabbitmq-signing-key-public.asc

echo "deb http://www.rabbitmq.com/debian/ testing main" > /etc/apt/sources.list.d/rabbitmq.list
apt-get update 

apt-get -y --purge remove rabbitmq-server
apt-get -y install rabbitmq-server

rabbitmqctl delete_user openstack
rabbitmqctl add_user openstack $DEFAULT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

service rabbitmq-server restart

exit 0
