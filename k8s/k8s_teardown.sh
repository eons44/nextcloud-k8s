#!/bin/bash

#DO NOT USE THIS IF YOU HAVE FIREWALL RULES BESIDES WHAT KUBERNETES CREATES!

kubeadm reset -f
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
rm -rfv /var/lib/rook
rm -rfv /var/lib/etcd