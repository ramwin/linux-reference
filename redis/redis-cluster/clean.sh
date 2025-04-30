#!/bin/bash

find . -name 'nodes.conf' | xargs rm
find . -name 'dump.rdb' | xargs rm
find . -name 'appendonly.aof' | xargs rm
