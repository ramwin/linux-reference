#!/bin/bash


export PGPASSFILE=/home/wangx/.pgpass
pg_dump schools \
    -f schools.sql

pg_dump schools \
    --no-owner \
    -f schools_noonwer.sql

pg_dump schools \
    --clean \
    --if-exists \
    --no-owner \
    -f schools_noonwer_if_exists.sql
