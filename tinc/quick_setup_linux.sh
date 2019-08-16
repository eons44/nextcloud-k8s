#!/bin/bash

#please run as root.

#vars
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NETWORK="my-network"
NETMASK="255.255.0.0"
PORT="665"
DEVICE="tun0"
CONNECT_TO="my-host"

IP=$1

if [ -z $IP ]; then
    echo "Please specify an IP"
    exit 1
fi

echo "Making sure tinc is installed"
apt install tinc

echo "Removing any conflicting files"
rm -rfv /etc/tinc/$NETWORK

echo "Populating hosts"
mkdir -p /etc/tinc/$NETWORK/hosts
cp -v $THIS_DIR/$NETWORK/hosts/* /etc/tinc/$NETWORK/hosts/

echo "Creating tinc.conf"
cat <<EOT >> /etc/tinc/$NETWORK/tinc.conf
Name = $HOSTNAME
AddressFamily = ipv4
Interface = $DEVICE
Port = $PORT
EOT

if [ -n "$CONNECT_TO" ]; then
    echo "ConnectTo = $CONNECT_TO" >> /etc/tinc/$NETWORK/tinc.conf
fi

echo "Creating host file for $HOSTNAME"
echo "" > /etc/tinc/$NETWORK/hosts/$HOSTNAME
#echo "Address = `dig TXT +short o-o.myaddr.l.google.com @ns1.google.com | awk -F'"' '{ print $2}'`" >> /etc/tinc/$NETWORK/hosts/$HOSTNAME
echo "Subnet = $IP/32" >> /etc/tinc/$NETWORK/hosts/$HOSTNAME
echo "Port = $PORT" >> /etc/tinc/$NETWORK/hosts/$HOSTNAME

echo "Generating keys"
tincd -n $NETWORK -K4096

echo "Creating tinc-up"
echo "" > /etc/tinc/$NETWORK/tinc-up
echo "#!/bin/sh" >> /etc/tinc/$NETWORK/tinc-up
echo "ifconfig \$INTERFACE $IP netmask $NETMASK" >> /etc/tinc/$NETWORK/tinc-up

echo "Creating tinc-down"
echo "" > /etc/tinc/$NETWORK/tinc-down
echo "#!/bin/sh" >> /etc/tinc/$NETWORK/tinc-down
echo "ifconfig \$INTERFACE down" >> /etc/tinc/$NETWORK/tinc-down

chmod 755 /etc/tinc/$NETWORK/tinc-*

#makes tinc start on boot.
#COMMENT THIS OUT IF YOU DON'T WANT TINC TO AUTOSTART
echo "Setting tinc to autostart"
echo $NETWORK > /etc/tinc/nets.boot
systemctl enable tinc@$NETWORK

echo "done."

echo "Here is our conf:"
cat /etc/tinc/$NETWORK/hosts/$HOSTNAME