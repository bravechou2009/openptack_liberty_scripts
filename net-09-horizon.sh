#!/bin/bash
source net-config.cfg

echo "########## INSTALL DASHBOARD ##########"
apt-get -y install openstack-dashboard
#apt-get -y install openstack-dashboard && dpkg --purge openstack-dashboard-ubuntu-theme

filename=/var/www/html/index.html
test -f $filename.org || cp $filename $filename.org
rm -f $filename

#touch $filename
#
#cat << EOF >> $filename
#<html>
#<head>
#<META HTTP-EQUIV="Refresh" Content="0.5; URL=http://$MASTER/horizon">
#</head>
#<body>
#<center> <h1>Forwarding to Dashboard of OpenStack</h1> </center>
#</body>
#</html>
#EOF

##sed -i "s/'can_set_password': False/'can_set_password': True/g" /etc/openstack-dashboard/local_settings.py

service apache2 reload

echo "########## HORIZON INFORMANTION ##########"
echo "URL: http://$MGMT_IP/horizon"
echo "User: admin"
echo "Password:" $DEFAULT_PASS
