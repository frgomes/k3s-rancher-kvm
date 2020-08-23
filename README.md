Rancher advise to use K3S rather RKE, because it is lightweight and use the same for rancher k8s management plane.

The documentation is really very poor and if you have followed the same recently its not going to work as it is, specially multinodes HA scenario or using mysql as backend.

And almost none of the available script made for KVM, I call it poor man'e virtualization solution.

Thhings should relatively simple to setup a HA rancher server over K3S K8S cluster, but I had to spent a day to make it work with KVM and wish noone else need to do the same.


# k3s-rancher setup on KVM
Run k3s-rancher-setup.sh which will do the following

- Check if any existing files needs to be removed or not like token to join the k3s nodes
- checks and remove existing rancher mysql db name "dbrancher", but you can change the db name
- launch vagrant up 
    - to deploy a 3 nodes k8s cluster using vagrant & ansible 
    - and use mysql as backend storage
- update the ip of the generated kube config file to point to the master node
- create a backup of your existing kube config and replace the same with the k3s cluster just been created.
- install and configure MetalB layer 2 load balancer, please change the ip range accordingly or keep it as it is, if you are using the default range.
- install nginx (make changes to both issuer-nginx.yaml & ingress-nginx.yaml)
    - issuer-nginx.yaml you have to change the email address
    - ingress-nginx.yaml you have to change the domain name
- install cert manager and configure let's encrypt
    - you need to change the custom domain name (replace rancher.vindpro.com) with the one you want
    - make changes to your /etc/hosts so that your host recognize custom domain name, it should point to the ip address (provisioned after ingress controller gets installed) MetalB load balancer will resolve
- Finally it installs rancher server (you have to change the hostname accordingly)

# k3s-rancher prequisites 
Setup expects you have setup and configured following on host
- KVM
- Vagrant and Vagrant libvirt provider (to use KVM)
- helm
- kubctl client
