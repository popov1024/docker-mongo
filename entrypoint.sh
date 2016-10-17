#!bin/bash

set -m

cmd=""

# MONGOS
if [ "$config_servers" != "" ]; then 
  cmd="mongos --port 27017 --configdb"

  concat_servers=""
  for config_server in $config_servers; do
      if [ "$concat_servers" == "" ]; then
          concat_servers="$config_server"
      else
          concat_servers="$concat_servers,$config_server"
      fi
  done
  cmd="$cmd $concat_servers"

  if [ "$auth" == "y" ]; then
    mkdir -p /data/db/config
    touch /data/db/config/key
    echo $admin_pwd > /data/db/config/key
    chmod 600 /data/db/config/key
    cmd="$cmd --keyFile /data/db/config/key"
  fi

# MONGOD
else
  cmd="mongod --storageEngine $storage_engine --port 27017"

  if [ "$shardsvr" == "y" ]; then
    cmd="$cmd --shardsvr"
  fi

  if [ "$rs_name" != "" ]; then
    cmd="$cmd --replSet $rs_name"
  fi

  if [ "$dbpath" != "" ]; then
    mkdir -p "$dbpath"
    cmd="$cmd --dbpath $dbpath"
  fi

  if [ "$oplog_size" != "" ]; then
    cmd="$cmd --oplogSize $oplog_size"
  fi

  if [ "$configsvr" == "y" ]; then
    cmd="$cmd --configsvr"
  fi

  if [ "$auth" == "y" ] && [ -f "$dbpath"/.mongodb_password_set ]; then
    cmd="$cmd --keyFile /data/db/config/key"
  fi
fi

echo $cmd
$cmd &

# WAINTING FOR STARTUP
RET=1
while [[ RET -ne 0 ]]; do
    echo "=> Waiting for confirmation of MongoDB service startup"
    sleep 5
    mongo admin --eval "help" >/dev/null 2>&1
    RET=$?
done

# CONFIGURE REPLICA SET
if [ ! -f "$dbpath"/.mongodb_replSet_set ] && [ "$rs_name" != "" ]; then
  sleep 5
  /configure_rs.sh
fi 

# PERF TRICKS
if [ ! -f "$dbpath"/.perf_tricks_set ] && [ "$config_servers" == "" ]; then
  sleep 5
  mongo --eval "db.getSiblingDB('admin').runCommand({setParameter: 1, internalQueryExecYieldPeriodMS: 1000});"
  mongo --eval "db.getSiblingDB('admin').runCommand({setParameter: 1, internalQueryExecYieldIterations: 100000});"
  touch "$dbpath"/.perf_tricks_set
fi

# CONFIGURE AUTHENTICATION
if [ "$auth" == "y" ] && [ ! -f "$dbpath"/.mongodb_password_set ] && [ "$config_servers" == "" ]; then
  /set_auth.sh
  mongod --shutdown
  sleep 5
  cmd="$cmd --keyFile /data/db/config/key"
  echo $cmd
  $cmd &
fi

# CONFIGURE SHARDED CLUSTER
if [ ! -f "$dbpath"/.mongodb_cluster_set ] && [ "$config_servers" != "" ]; then
  /configure_cluster.sh
fi

# LOG STATUS
if [ "$rs_name" != "" ]; then
  sleep 5
  mongo --quiet --eval "rs.status()"
fi

if [ "$config_servers" != "" ]; then
  sleep 5
  mongo --quiet --eval "sh.status()"
fi

fg   