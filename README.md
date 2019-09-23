# k8s
personal bare-metal kubernetes setup

# install

1. install kubernetes using [kubespray](https://github.com/kubernetes-sigs/kubespray):
```sh
# clone kubespray
git clone https://github.com/kubernetes-sigs/kubespray.git # or ssh
cd kubespray/
cp inventory/sample/* inventory

# add entries to `inventory.ini`
vim inventory/inventory.ini

# change network plugin to flannel
vim inventory/group_vars/k8s-cluster/k8s-cluster.yml

-kube_network_plugin: calico
+kube_network_plugin: flannel

# install helm
vim inventory/group_vars/k8s-cluster/addons.yml

-helm_enabled: false
+helm_enabled: true

# run kubernetes installation
ansible-playbook -i inventory/inventory.cfg cluster.yml -b -v

# Retrieve k8s config
cat /etc/kubernetes/admin.conf
```
2. install [istio](https://istio.io/docs/setup/kubernetes/install/helm/#installation-steps)
```sh
helm install --name istio-init \
  --namespace istio-system \
  istio.io/istio-init

kubectl label namespace istio-system certmanager.k8s.io/disable-validation=true
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml

helm install --name istio \
  --namespace istio-system \
  -f services/istio.yaml \
  istio.io/istio

# add istio injection to namespaces
kubectl apply -f manifests/istio-injection.yaml
```
3. install nfs provisioner (requires configured NFS server)
```sh
# requires nfs-common on all nodes!
sudo apt-get install -y nfs-common

helm install --name nfs-client \
  --namespace storage \
  -f services/nfs-client.yaml \
  stable/nfs-client-provisioner
```
4. install redis
```sh
REDIS_NAMESPACE=storage
REDIS_AUTH_FILE=./.redis-pass
REDIS_AUTH_SECRET=redis-auth

kubectl create secret generic $REDIS_AUTH_SECRET \
  --namespace $REDIS_NAMESPACE \
  --from-file redis-password=$REDIS_AUTH_FILE

helm install --name redis \
  --namespace $REDIS_NAMESPACE \
  -f services/redis.yaml \
  --set existingSecret=$REDIS_AUTH_SECRET \
  stable/redis
```
5. install spinnaker
```sh
# create necessary files
SPIN_DOCKER_USER_FILE=./.spin-docker-user
SPIN_DOCKER_PASS_FILE=./.spin-docker-pass
SPIN_GCP_BUCKET_FILE=./.spin-gcp-bucket

SPIN_NAMESPACE=spin-system
SPIN_DOCKER_SECRET=regcred
SPIN_GCP_ACCOUNT=spinnaker-gcp-account
SPIN_GCP_SECRET=spinnaker-gcp
SPIN_GCP_JSON_KEY=key.json
SPIN_GCP_JSON_FILE=$HOME/.gcp/$SPIN_GCP_ACCOUNT.json
SPIN_GCP_PROJECT=$(gcloud info --format='value(config.project)')

# create service account
./scripts/create-service-account.sh $SPIN_GCP_ACCOUNT $HOME/.gcp/$SPIN_GCP_ACCOUNT.json

# create required secrets
kubectl create secret docker-registry $SPIN_DOCKER_SECRET \
  --namespace $SPIN_NAMESPACE \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=$(cat $SPIN_DOCKER_USER_FILE) \
  --docker-password=$(cat $SPIN_DOCKER_PASS_FILE)

kubectl create secret generic $SPIN_GCP_SECRET \
  --namespace $SPIN_NAMESPACE \
  --from-file=$SPIN_GCP_JSON_KEY=$SPIN_GCP_JSON_FILE

# spinnaker
helm install --name spin \
  --namespace $SPIN_NAMESPACE \
  -f services/spinnaker.yaml \
  --set dockerRegistryAccountSecret=$SPIN_DOCKER_SECRET \
  --set gcs.project=$SPIN_GCP_PROJECT \
  --set gcs.bucket=$SPIN_GCP_BUCKET \
  --set gcs.secretName=$SPIN_GCP_SECRET \
  --set redis.external.password=$(cat $REDIS_AUTH_FILE) \
  --timeout 1200 \
  stable/spinnaker

# hal configuration
kubectl exec --namespace $SPIN_NAMESPACE -it spinnaker-spinnaker-halyard-0 bash
# see scripts/spininitialhalconfig.sh
```

---

from here on, spinnaker can be used to deploy rest of services

---

6. install [metallb](https://github.com/helm/charts/tree/master/stable/metallb) (TODO prometheus support)
```sh
helm install --name metallb \
  --namespace network-system \
  -f services/metallb.yaml \
  stable/metallb
```
7. install [nginx](https://github.com/helm/charts/tree/master/stable/nginx-ingress)
```sh
# nginx is only used as workaround to auto renew certificates as istio does not
# do so with SDS and mTLS enabled
helm install --name nginx \
  --namespace network-system \
  --set rbac.create=true \
  stable/nginx-ingress

# configure certificates handled by nginx
kubectl apply -f manifests/echo.yaml
kubectl apply -f manifests/homelabprojects-dev.ing.yaml
kubectl apply -f manifests/hugocortes-dev.ing.yaml
# configure istio gateways
kubectl apply -f manifests/homelabprojects-dev.gw.yaml
kubectl apply -f manifests/hugocortes-dev.gw.yaml
```
8. install [openfaas](https://github.com/openfaas/faas-netes/tree/master/chart/openfaas#deploy-openfaas)
```sh
# create necessary files
OPENFAAS_USER_FILE=./.openfaas-user
OPENFAAS_PASS_FILE=./.openfaas-pass
OPENFAAS_NAMESPACE=openfaas-system

# add repo
helm repo add openfaas https://openfaas.github.io/faas-netes/
helm repo update

# create ns
kubectl create -f manifests/openfaas-system.ns.yaml 

# generate secret
kubectl create secret generic basic-auth \
  --namespace $OPENFAAS_NAMESPACE \
  --from-file=basic-auth-user=$OPENFAAS_USER_FILE \
  --from-file=basic-auth-password=$OPENFAAS_PASS_FILE

# openfaas
helm install --name openfaas \
  --namespace $OPENFAAS_NAMESPACE \
  --set functionNamespace=openfaas-system-fn \
  --set basic_auth=true \
  --set istio.mtls=true \
  openfaas/openfaas

# if istio grafana was installed, add permissive policy on prometheus
kubectl create -f manifests/openfaas-system.istio.yaml
```
9. install chart museum
```sh
# enter variables:
# CM_USER=
# CM_PASS=
# CM_GCP_BUCKET=

# CM_BASIC_JSON=$(echo -n \[\{\"username\":\"$CM_USER\"\\,\"password\":\"$CM_PASS\"\}\] | sed "s/^/'/;s/$/'/")
# --set env.secret.BASIC_AUTH_USER=$CM_USER \
# --set env.secret.BASIC_AUTH_PASS=$CM_PASS \

CM_NAMESPACE=storage
CM_GCP_ACCOUNT=chart-museum-gcp-account
CM_GCP_SECRET=chart-museum-gcp
CM_GCP_JSON_KEY=key.json
CM_GCP_JSON_FILE=$HOME/.gcp/$CM_GCP_ACCOUNT.json

# create service account
./scripts/create-service-account.sh $CM_GCP_ACCOUNT $HOME/.gcp/$CM_GCP_ACCOUNT.json

# create required secrets
kubectl create secret generic $CM_GCP_SECRET \
  --namespace $CM_NAMESPACE \
  --from-file=$CM_GCP_JSON_KEY=$CM_GCP_JSON_FILE

# chart museum
helm install --name chartmuseum \
  --namespace $CM_NAMESPACE \
  -f services/chart-museum.yaml \
  --set env.open.CHART_URL=http://chartmuseum-chartmuseum.$CM_NAMESPACE:8080 \
  --set env.open.STORAGE_GOOGLE_BUCKET=$CM_GCP_BUCKET \
  --set gcp.secret.name=$CM_GCP_SECRET \
  --set gcp.secret.key=$CM_GCP_JSON_KEY \
  stable/chartmuseum

# upload chart museum ui helm chart
kubectl port-forward --namespace $CM_NAMESPACE svc/chartmuseum-chartmuseum 8080:8080
helm package services/chart-museum-ui
curl --data-binary "@chart-museum-ui-0.1.0.tgz" http://localhost:8080/api/charts

# chart museum ui
helm install --name chart-museum-ui \
  --namespace $CM_NAMESPACE \
  --set chartMuseum=http://chartmuseum-chartmuseum:8080 \
  services/chart-museum-ui
```
10. install postgres
```sh
# create necessary files
POSTGRES_REPL_USER_FILE=./.postgres-repl-user
POSTGRES_REPL_PASS_FILE=./.postgres-repl-pass
POSTGRES_PASS_FILE=./.postgres-pass

POSTGRES_NAMESPACE=storage
POSTGRES_AUTH_SECRET=postgres-auth

kubectl create secret generic $POSTGRES_AUTH_SECRET \
  --namespace $POSTGRES_NAMESPACE \
  --from-file=postgresql-replication-password=$POSTGRES_REPL_PASS_FILE \
  --from-file=postgresql-password=$POSTGRES_PASS_FILE

helm install --name postgres \
  --namespace $POSTGRES_NAMESPACE \
  -f services/postgresql.yaml \
  --set global.postgresql.existingSecret=$POSTGRES_AUTH_SECRET \
  --set replication.user=$(cat $POSTGRES_REPL_USER_FILE) \
  stable/postgresql
```
11. install kubernetes dashboard
```sh
helm install --name dashboard \
  -f services/dashboard.yaml \
  stable/kubernetes-dashboard

# retrieving token
kubectl get secret kubernetes-dashboard-token-<UNIQUE> -o jsonpath='{.data.token}' | base64 --decode
```

# misc
grafana dashboards used:
* [openfaas](https://grafana.com/grafana/dashboards/3434)
* [redis](https://grafana.com/grafana/dashboards/763)
* [postgresql](https://grafana.com/grafana/dashboards/9628)
