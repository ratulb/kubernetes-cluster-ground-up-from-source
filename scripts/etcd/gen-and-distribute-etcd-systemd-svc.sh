#!/usr/bin/env bash
#Generate the etcd system file for each etcd node and copy it to the node
ETCD1_IP=$(lxc list | grep etcd-1 | awk '{print $6}')
ETCD2_IP=$(lxc list | grep etcd-2 | awk '{print $6}')
ETCD3_IP=$(lxc list | grep etcd-3 | awk '{print $6}')
INITIAL_CLUSTER=etcd-1=https://${ETCD1_IP}:2380,etcd-2=https://${ETCD2_IP}:2380,etcd-3=https://${ETCD3_IP}:2380
INTIAL_CLUSTER_TOKEN=etcd-cluster-0

ETCD_SERVERS=
if [ $# -eq 0 ];
  then
    ETCD_SERVERS="etcd-1 etcd-2 etcd-3"
    echo "No arguments supplied - copying certs for $ETCD_SERVERS"
  else
    ETCD_SERVERS=$@
    echo "Copying certs for $ETCD_SERVERS"
fi

GENERATED_DIR=./generated/etc/systemd/system
mkdir -p ${GENERATED_DIR} 

for instance in $ETCD_SERVERS; do
 ETCD_NAME=$(lxc exec ${instance} -- hostname -s)
 INTERNAL_IP=$(lxc list | grep ${instance} | awk '{print $6}')
 

cat <<EOF | tee ${GENERATED_DIR}/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos
[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name=${ETCD_NAME} \\
  --cert-file=/etc/etcd/${instance}.pem \\
  --key-file=/etc/etcd/${instance}-key.pem \\
  --peer-cert-file=/etc/etcd/${instance}.pem \\
  --peer-key-file=/etc/etcd/${instance}-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token ${INTIAL_CLUSTER_TOKEN} \\
  --initial-cluster ${INITIAL_CLUSTER} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd

Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
cp ${GENERATED_DIR}/etcd.service ${GENERATED_DIR}/${instance}-etcd.service
 lxc file push ${GENERATED_DIR}/etcd.service ${instance}/etc/systemd/system/
 echo "Copied etcd systemd file to host ${instance}"
done

