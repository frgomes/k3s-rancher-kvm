#!/bin/bash

export K3S_KUBECONFIG_MODE="644"
export INSTALL_K3S_EXEC=" --no-deploy servicelb --no-deploy traefik"

if [ -z "${RANCHER_DATASTORE_ENDPOINT}" ] ;then
    curl -sfL https://get.k3s.io | sh -s - server
else
    curl -sfL https://get.k3s.io | sh -s - server --datastore-endpoint="${RANCHER_DATASTORE_ENDPOINT}"
fi
