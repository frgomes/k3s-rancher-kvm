vagrant destroy -f
[! -e kubernetes-setup/access_token_command] || rm kubernetes-setup/access_token_command



DBNAME="dbrancher"
echo "Enter mysql password"
DBEXISTS=$(mysql -u root -p  --batch --skip-column-names -e "SHOW DATABASES LIKE '"$DBNAME"';" | grep "$DBNAME" > /dev/null; echo "$?")
if [ $DBEXISTS -eq 0 ];then
    echo "Enter mysql password"
    echo "A database with the name $DBNAME already exists. removing..."
    mysql -u root -p -D dbrancher -e "DROP DATABASE $DBNAME"
fi

vagrant up

sleep 10

sed -i 's/127.0.0.1/192.168.50.10/g' kubernetes-setup/kube_config

more kubernetes-setup/kube_config

[! -e ~/.kube/config] || mv ~/.kube/config ~/.kube/config.bkup

mv kubernetes-setup/kube_config ~/.kube/config

kubectl get pods --all-namespaces

helm repo add stable https://kubernetes-charts.storage.googleapis.com

helm repo update

helm install metallb stable/metallb --namespace kube-system \
  --set configInline.address-pools[0].name=default \
  --set configInline.address-pools[0].protocol=layer2 \
  --set configInline.address-pools[0].addresses[0]=192.168.50.20-192.168.50.250

sleep 10

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

helm repo update

helm install nginx-ingress stable/nginx-ingress --set controller.publishService.enabled=true

sleep 5

kubectl  get service nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

sleep 10

kubectl create namespace cert-manager
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.16.0/cert-manager.yaml

sleep 10

kubectl get pods --namespace cert-manager

sleep 20

kubectl apply -f issuer-nginx.yaml

kubectl apply -f ingress-nginx.yaml

kubectl create namespace cattle-system

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.vindpro.com \
  --set tls=external

kubectl -n cattle-system rollout status deploy/rancher