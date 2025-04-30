#!/bin/bash


set -ex
echo $1
redis-cli --cluster del-node localhost:7000 $1
