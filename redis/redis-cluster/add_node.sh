#!/bin/bash

set -ex
echo $1
redis-cli --cluster add-node \
    $1 localhost:7000 \
    # 可以执行新节点是谁的child
    # --cluster-master-id 3c3a0c74aae0b56170ccb03a76b60cfe7dc1912e
# redis-cli --cluster add-node localhost:7007 localhost:7000 --cluster-slave
# redis-cli --cluster add-node localhost:7008 localhost:7000 --cluster-slave
