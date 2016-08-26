#!/bin/bash
source com-config.cfg

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
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
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

exit 0