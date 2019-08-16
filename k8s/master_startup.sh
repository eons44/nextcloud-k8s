#!/bin/bash

error()
{
  echo "[$(date)] ERROR: $1"
  exit 1
}

check_port()
{
  if [ ! -z "$(netstat -tulpn | grep -w $1)" ]; then 
    error "Port $1 is already bound"    
  fi
}

#our own pre-flight checks
check_port 80
check_port 443
check_port 8089

# check if kubeconfig exists
KUBECONFIG=/etc/kubernetes/admin.conf
if [ -f $KUBECONFIG ]; then
  error "$KUBECONFIG exists. Is a cluster running?"
fi

kubeadm config images pull -v3
JOIN=$(kubeadm init --token-ttl=0 \
--apiserver-advertise-address=$(ip addr show tun0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}') \
--pod-network-cidr=10.10.0.0/16 \
--service-cidr 10.100.0.0/16 \
--service-dns-domain tamriel.internal | tail -2)

#newline is stripped above, to make this valid, we must also strip '\ '
JOIN=${JOIN/\\ /}

mkdir -p $HOME/.kube
cp -v $KUBECONFIG $HOME/.kube/config
#TODO: make sure mankar always exists
chown mankar:mankar $HOME/.kube/config

echo "KUBELET_KUBEADM_ARGS=\"--cgroup-driver=cgroupfs --network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.1 --node-ip=`ip addr show tun0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'` --resolv-conf=/run/systemd/resolve/resolv.conf\"" > /var/lib/kubelet/kubeadm-flags.env
systemctl restart kubelet

kubectl taint nodes $(hostname) node-role.kubernetes.io/master:NoSchedule-

#for port forwarding later
setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/kubectl

cat << 'EOF' > /etc/init.d/k8s-port-forwarding
#!/bin/bash
### BEGIN INIT INFO
# Provides:          k8sportforwarding
# Required-Start:    $all
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:
# Short-Description: Forwards kubernetes ports
### END INIT INFO

LOG=/var/log/k8s/port-forwarding.log
KUBECONFIG=/etc/kubernetes/admin.conf
LIMIT=3600 # 1 hour time limit 
error()
{
  ERR="[$(date)] ERROR: $1"
  echo $ERR
  >&2 echo $ERR
  echo $ERR >> $LOG
  exit 1
}
# check if kubeconfig exists
if [ ! -f $KUBECONFIG ]; then
  error "$KUBECONFIG does not exist"
fi
# kubectl get svc/traefic-ingress-service
for i in $(seq 1 $LIMIT); do
  if kubectl --kubeconfig $KUBECONFIG get svc/traefik-ingress-service -n kube-system; then
    kubectl --kubeconfig $KUBECONFIG port-forward service/traefik-ingress-service 80:80 443:443 8089:8089 -n kube-system --address 0.0.0.0  &
    return 0
  fi
  sleep 1
done
# passed hour time limit 
error "unable to find svc/traefik-ingress-service after waiting $(date -d@$LIMIT +\"%T\")"
EOF
chmod +x /etc/init.d/k8s-port-forwarding
update-rc.d k8s-port-forwarding defaults

echo $JOIN > ./k8s-worker-startup.sh
cat << 'EOF' >> ./k8s-worker-startup.sh
echo "KUBELET_KUBEADM_ARGS=\"--cgroup-driver=cgroupfs --network-plugin=cni --pod-infra-container-image=k8s.gcr.io/pause:3.1 --node-ip=`ip addr show tun0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}'` --resolv-conf=/run/systemd/resolve/resolv.conf\"" > /var/lib/kubelet/kubeadm-flags.env
systemctl restart kubelet
EOF
echo "use k8s-worker-startup.sh to join the cluster!"

systemctl start k8s-port-forwarding