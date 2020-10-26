#!/bin/bash

export K3S_KUBECONFIG_MODE="644"
export K3S_URL="https://192.168.50.10:6443"
curl -sfL https://get.k3s.io | sh -
