export K3S_KUBECONFIG_MODE="644"
#export INSTALL_K3S_VERSION=v1.17.11+k3s1
export INSTALL_K3S_EXEC=" --no-deploy servicelb --no-deploy traefik"
curl -sfL https://get.k3s.io | sh -s - server --datastore-endpoint="mysql://rancher:rancher@tcp(10.0.0.60:3306)/dbrancher"