#!/bin/bash -x


function __global_vars {
  export DBNAME=${DBNAME:-"dbrancher"}
  export CERT_MANAGER_VERSION=${CERT_MANAGER_VERSION:-0.16.0}
  export RANCHER_MASTER_FQDN=${RANCHER_MASTER_FQDN:-rancher.example.com}
}


function __bash_path_preppend() {
  [[ ! -z "$1" ]] && (echo "$PATH" | tr ':' '\n' | fgrep "$1" > /dev/null) || export PATH="$1:${PATH}"
}


# see: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/sect-Troubleshooting-Common_libvirt_errors_and_troubleshooting#sect-The_URI_failed_to_connect_to_the_hypervisor
function __install_libvirt_fix_configuration {
  [ -f /etc/default/libvirtd.ORIGINAL ]      || sudo cp -p /etc/default/libvirtd /etc/default/libvirtd.ORIGINAL
  sudo sed 's/#libvirtd_opts=""/libvirtd_opts="--listen"/' -i /etc/default/libvirtd
    
  [ -f /etc/libvirt/libvirtd.conf.ORIGINAL ] || sudo cp -p /etc/libvirt/libvirtd.conf /etc/libvirt/libvirtd.conf.ORIGINAL
  local myip=$(fgrep $(hostname) /etc/hosts | cut -d' ' -f1)
  sudo sed "s/#listen_tls = 0/listen_tls = 1/" -i /etc/libvirt/libvirtd.conf
  sudo sed "s/#listen_tcp = 1/listen_tcp = 1/" -i /etc/libvirt/libvirtd.conf
  sudo sed -E "s/#listen_addr = \"[0-9.]+\"/listen_addr = \"0.0.0.0\"/" -i /etc/libvirt/libvirtd.conf

  which certtool > /dev/null 2>&1 || sudo apt install gnutls-bin -qqy

  if [ ! -f /etc/pki/CA/cacert.pem ] ;then
    [[ -d /etc/pki/CA/ ]] || sudo mkdir -p /etc/pki/CA
    certtool --generate-privkey | sudo tee /etc/pki/CA/cakey.pem > /dev/null

cat <<EOF | sudo tee /etc/pki/CA/ca.info > /dev/null
cn ACME Organization, Inc.
ca
cert_signing_key
EOF

    sudo certtool --generate-self-signed --load-privkey /etc/pki/CA/cakey.pem --template /etc/pki/CA/ca.info --outfile /etc/pki/CA/cacert.pem
  fi

  [[ -d /etc/pki/libvirt/ ]] || sudo mkdir -p /etc/pki/libvirt/private
    
cat <<EOF | sudo tee /etc/pki/libvirt/server.info > /dev/null
organization = Name of your organization
cn = $(hostname).libvirt.org
dns_name = compute1
dns_name = compute1.libvirt.org
ip_address = ${myip}
tls_www_server
encryption_key
signing_key
EOF

  certtool --generate-privkey | sudo tee /etc/pki/libvirt/private/serverkey.pem > /dev/null

  certtool --generate-certificate --load-privkey /etc/pki/libvirt/private/serverkey.pem \
           --load-ca-certificate /etc/pki/CA/cacert.pem --load-ca-privkey /etc/pki/CA/cakey.pem \
           --template /etc/pki/libvirt/server.info | sudo tee /etc/pki/libvirt/servercert.pem > /dev/null

  ##FIXME sudo chown -R libvirt:libvirt /etc/pki/libvirt
  ##FIXME sudo chmod -R 400 /etc/pki/libvirt

  sudo service libvirtd restart
}


function install_libvirt {
  sudo apt update
  sudo apt upgrade -qqy
  sudo apt install qemu qemu-kvm qemu-system qemu-utils -qqy
  sudo apt install libvirt-clients libvirt-daemon-system virtinst virt-manager
  sudo virsh net-start default
  sudo virsh net-autostart default
  sudo service libvirtd stop
  __install_libvirt_fix_configuration
  sudo service libvirtd restart
  sudo usermod --append --groups libvirt $(whoami)
  sudo usermod --append --groups libvirt-qemu $(whoami)
}


function install_python3 {
  which python3 >/dev/null 2>&1 || sudo apt install python3-minimal -y
}


function install_pip3 {
  if [[ ! -z $(which python3) ]] ;then
    if [[ ! -e "${HOME}/.local/bin/pip3" ]] ;then
      [[ ! -d ~/Downloads ]] && mkdir -p ~/Downloads
      [[ ! -f ~/Downloads/get-pip.py ]] && wget https://bootstrap.pypa.io/get-pip.py -O ~/Downloads/get-pip.py
      if [ -e $(which python3) ] ;then
        python3 "~/Downloads/get-pip.py" --user
      fi
    fi
  fi
}


function install_vagrant {
    sudo apt update
    sudo apt upgrade -qqy
    sudo apt install vagrant vagrant-libvirt -qqy
}


function install_helm {
  which wget > /dev/null 2>&1 || sudo apt install wget -qqy
  
  local latest=https://github.com/helm/helm/releases/latest
  local version=$(wget -q -SO- -T 5 -t 1 "${latest}" 2>/dev/null | fgrep location: | cut -d' ' -f2 | sed -E 's|.*\/v(.*)|\1|')
  local version=${version:-"3.3.4"}
  local version=${1:-"${version}"}

  if [ ! -d /opt/helm-${version} ] ;then
    local osarch=$(uname -s | tr [:upper:] [:lower:])
    local hwarch=$(uname -m)
    case "${hwarch}" in
      armv7l) hwarch=arm ;;
      x86_64) hwarch=amd64 ;;
      i386)   hwarch=386 ;;
      *)      echo "ERROR: Could not install Helm on platform ${osarch}-${hwarch}" ; return 1 ;;
    esac

    local arch=${osarch}-${hwarch}
    local file=helm-v${version}-${arch}.tar.gz
    local url=https://get.helm.sh/${file}
  
    [[ -d ~/Downloads ]] || mkdir -p ~/Downloads
  
    [[ -f ~/Downloads/${file} ]] || wget -q -O ~/Downloads/${file} "${url}"
  
    [[ -d /opt/helm-${version} ]] || sudo mkdir -p /opt/helm-${version}
    [[ -d /opt/helm-${version}/${arch} ]] || sudo tar -C /opt/helm-${version} -xpzf ~/Downloads/${file}

    [[ -d ~/bin ]] || mkdir -p ~/bin/
    [[ -L ~/bin/helm ]] && rm ~/bin/helm
    ln -s /opt/helm-${version}/${arch}/helm ~/bin/helm
  fi
}


function install_kubectl {
  which wget > /dev/null 2>&1 || sudo apt install wget -qqy
  
  local version=${version:-$(wget -q -O - https://storage.googleapis.com/kubernetes-release/release/stable.tx | cut -c2-)}
  local version=${version:-"1.18.6"}
  local version=${1:-"${version}"}

  if [ ! -d ~/bin/kubectl ] ;then
    local osarch=$(uname -s | tr [:upper:] [:lower:])
    local hwarch=$(uname -m)
    case "${hwarch}" in
      armv7l) hwarch=arm ;;
      x86_64) hwarch=amd64 ;;
      i386)   hwarch=386 ;;
      *)      echo "ERROR: Could not install Helm on platform ${osarch}-${hwarch}" ; return 1 ;;
    esac

    local file=kubectl
    local url=https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/${osarch}/${hwarch}/${file}

    [[ -d ~/bin ]] || mkdir -p ~/bin/
    [[ -f ~/bin/${file} ]] || wget -q -O ~/bin/${file} "${url}"
    chmod 755 ~/bin/${file}
    hash -r
  fi
}


function install_ansible {
  __bash_path_preppend /opt/helm
  __bash_path_preppend ~/.local/bin
  __bash_path_preppend ~/bin

  pip3 install ansible
}


function __vagrant_restart {
  vagrant destroy -f && \
  ([ ! -e ${dir}/kubernetes-setup/access_token_command ] || rm ${dir}/kubernetes-setup/access_token_command) && \
  vagrant up && \
  sleep 10
}


function deploy_cluster {
  __bash_path_preppend /opt/helm
  __bash_path_preppend ~/.local/bin
  __bash_path_preppend ~/bin

  (which python3 > /dev/null 2>&1 || install_python3) && \
  (which pip3    > /dev/null 2>&1 || install_pip3   ) && \
  (which ansible > /dev/null 2>&1 || install_ansible) && \
  (which virsh   > /dev/null 2>&1 || install_libvirt) && \
  (which vagrant > /dev/null 2>&1 || install_vagrant) && \
  ([[ -x /opt/heml/bin/helm ]]    || install_helm   ) && \
  ([[ -x ~/bin/kubectl ]]         || install_kubectl) && \
  ([[ -f ~/.ssh/id_rsa ]] || ssh-keygen -t rsa -b 4096) && \
  cp ${dir}/Vagrantfile.kvm Vagrantfile && \
  __vagrant_restart && \
  ([ ! -e ~/.kube/config ] || cp ~/.kube/config ~/.kube/config.$(date +%Y%m%d_%H%M%S)) && \
  (cat ${dir}/kubernetes-setup/kube_config | sed 's/127.0.0.1/192.168.50.10/g' > ~/.kube/config) && \
  kubectl get nodes
}


function deploy_metallb {
  __bash_path_preppend /opt/helm
  __bash_path_preppend ~/.local/bin
  __bash_path_preppend ~/bin

  helm repo add stable https://kubernetes-charts.storage.googleapis.com
  helm repo update

  helm install metallb stable/metallb --namespace kube-system \
    --set configInline.address-pools[0].name=default \
    --set configInline.address-pools[0].protocol=layer2 \
    --set configInline.address-pools[0].addresses[0]=192.168.50.20-192.168.50.250

  sleep 10
}


function deploy_ingress_controller {
  __bash_path_preppend /opt/helm
  __bash_path_preppend ~/.local/bin
  __bash_path_preppend ~/bin

  helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
  helm repo update
  helm install nginx-ingress stable/nginx-ingress --set controller.publishService.enabled=true
  sleep 5
  kubectl  get service nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
  sleep 10
}


function deploy_certmanager {
  __bash_path_preppend /opt/helm
  __bash_path_preppend ~/.local/bin
  __bash_path_preppend ~/bin

  __global_vars

  kubectl create namespace cert-manager && \
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v${CERT_MANAGER_VERSION}/cert-manager.yaml && \
  sleep 10 && \
  kubectl get pods --namespace cert-manager && \
  sleep 20 && \
  kubectl apply -f issuer-nginx.yaml
  kubectl apply -f ingress-nginx.yaml
}


function deploy_rancher {
  __bash_path_preppend /opt/helm
  __bash_path_preppend ~/.local/bin
  __bash_path_preppend ~/bin

  kubectl create namespace cattle-system && \
  helm install rancher rancher-latest/rancher \
    --namespace cattle-system \
    --set hostname=${RANCHER_MASTER_FQDN} \
    --set tls=external && \
  kubectl -n cattle-system rollout status deploy/rancher
}


function deploy_and_configure_k3s_cluster {
  deploy_cluster && \
  deploy_metallb && \
  deploy_ingress_controller && \
  deploy_certmanager # && \
  # deploy_rancher
}


if [ $_ != $0 ] ;then
  # echo "Script is being sourced: list all functions"
  self=$(readlink -f "${BASH_SOURCE[0]}"); dir=$(dirname $self)
  grep -E "^function " $self | fgrep -v "function __" | cut -d' ' -f2 | head -n -1
else
  # echo "Script is a subshell: execute last function"
  self=$(readlink -f "${BASH_SOURCE[0]}"); dir=$(dirname $self)
  cmd=$(grep -E "^function " $self | cut -d' ' -f2 | tail -1)
  ${cmd} $*
fi
