#/bin/bash

minikube delete
minikube start 

#Get node IPaddress
node_ip=$(kubectl get node -o=custom-columns='DATA:status.addresses[0].address' | sed -n 2p)

build_image()
{
  docker build srcs/$1 -t oel-ahma/$1 || build_image $1
}

# Deploy Metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
sed -e 's/node_ip/'$node_ip'/g' srcs/metallb/metallb.yaml | kubectl create -f -

eval $(minikube docker-env)

kubectl create -f srcs/dashboard.yaml >> /dev/null
kubectl create -f srcs/volumes.yaml >> /dev/null
kubectl create -f srcs/secrets.yaml >> /dev/null

# Build Images
build_image alpine_base
build_image mysql
build_image influxdb
build_image grafana
build_image phpmyadmin
build_image ftps
build_image nginx
build_image wordpress

# Deploy Services
kubectl create -f srcs/mysql.yaml
kubectl create -f srcs/influxdb.yaml
while [ $(kubectl get pods -l app=mysql -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]; do echo "Kuma is Waiting For SideCar App" && sleep 1; done
kubectl create -f srcs/grafana.yaml
kubectl create -f srcs/phpmyadmin.yaml
kubectl create -f srcs/ftps.yaml
kubectl create -f srcs/nginx.yaml
kubectl create -f srcs/wordpress.yaml

eval $(minikube docker-env -u)

clear

printf "K8s Dashboard Token :\n"

kubectl get secret -n kubernetes-dashboard $(kubectl get serviceaccount admin-user -n kubernetes-dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}" | base64 --decode

printf "\nIP :  "
echo https://$node_ip
