#!/usr/bin/env bash
set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ -d .obs ] ; then
    rm -rf .obs
fi
git clone git@github.com:elastic/observability-test-environments.git .obs

cd .obs
git checkout -b kuisathaverat-fix_kibana_1 master
git pull git@github.com:kuisathaverat/observability-test-environments.git fix_kibana_1

if [ $1 == "destroy" ] ; then
    CLUSTER_CONFIG_FILE=$SCRIPT_DIR/elastic_cloud.yml \
    make -C ansible destroy-cluster
else
    CLUSTER_CONFIG_FILE=$SCRIPT_DIR/elastic_cloud.yml \
    make -C ansible create-cluster
fi
