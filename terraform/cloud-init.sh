#!/bin/bash
PATH_VARIABLE=${PATH_VARIABLE}
sudo apt update -y
sudo apt install -y postgresql postgresql-contrib etcd python3-pip haproxy

pip install patroni

# Fetch private IPs from file
PRIVATE_IPS=($(cat ${PATH_VARIABLE}/private_ips.txt))

cat <<EOF | sudo tee /etc/patroni.yml
scope: postgresql-cluster
namespace: /db/
name: $(hostname)

restapi:
  listen: 0.0.0.0:8008
  connect_address: $(hostname -I | awk '{print $1}'):8008

etcd:
  hosts: ${PRIVATE_IPS[0]}:2379,${PRIVATE_IPS[1]}:2379,${PRIVATE_IPS[2]}:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    postgresql:
      use_pg_rewind: true
      parameters:
        wal_level: replica
        hot_standby: on
  initdb:
  - encoding: UTF8
  - data-checksums
  pg_hba:
  - host replication all 0.0.0.0/0 md5
  - host all all 0.0.0.0/0 md5

postgresql:
  listen: 0.0.0.0:5432
  connect_address: $(hostname -I | awk '{print $1}'):5432
  data_dir: /var/lib/postgresql/15/main
  bin_dir: /usr/lib/postgresql/15/bin
  authentication:
    replication:
      username: replica
      password: replica_pass
    superuser:
      username: postgres
      password: strongpassword
  parameters:
    max_connections: 100
    shared_buffers: 512MB
EOF

# Start Patroni
nohup patroni /etc/patroni.yml &

# Configure HAProxy
cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
frontend postgresql
    bind *:5432
    default_backend postgresql_servers

backend postgresql_servers
    mode tcp
    balance roundrobin
    server pg-node-1 ${PRIVATE_IPS[0]}:5432 check
    server pg-node-2 ${PRIVATE_IPS[1]}:5432 check
    server pg-node-3 ${PRIVATE_IPS[2]}:5432 check
EOF

sudo systemctl restart haproxy
