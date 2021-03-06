#!/usr/bin/env bash

#Generate and copy the bridge and loopback onfiguration to worker nodes
{
WORKERS=
if [ $# -eq 0 ];
#!/usr/bin/env bash
  then
    WORKERS="worker-1 worker-2 worker-3"
  else
    WORKERS=$@
fi
echo "Setting up for $WORKERS"
GENERATED_DIR=./generated/etc/cni/net.d/
mkdir -p ${GENERATED_DIR}

#The loopback conf
cat <<EOF | tee ${GENERATED_DIR}/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF

SEED_CIDR=10.200
COUNTER=1
for instance in $WORKERS; do
 POD_CIDR=${SEED_CIDR}.${COUNTER}.0/24
 cat <<EOF | tee ${GENERATED_DIR}/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

((COUNTER++))

cp ${GENERATED_DIR}/10-bridge.conf ${GENERATED_DIR}/10-bridge.conf.${instance}
#Push the generated file to the current worker node
lxc exec ${instance} -- mkdir -p /etc/cni/net.d/
lxc file push ${GENERATED_DIR}/10-bridge.conf ${instance}/etc/cni/net.d/
lxc file push ${GENERATED_DIR}/99-loopback.conf ${instance}/etc/cni/net.d/
echo "Bridge network/loopback configurations copied to ${instance}"
done
}

