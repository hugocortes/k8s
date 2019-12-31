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

# run kubernetes installation
ansible-playbook -i inventory/inventory.ini cluster.yml -b -v

# Retrieve k8s config
cat /etc/kubernetes/admin.conf
```
2. additional configuration
```sh
# taint vpn node
kubectl taint nodes <WORKER NODE> vpn=true:NoSchedule

# add non-cluster DNS lookups to coredns configmap
kubectl edit configmap --namespace kube-system coredns

# yaml:
Corefile: |
  .:53 {
    ...
    ...
  }
  internal.corteshq.net:53 {
      errors
      cache 30
      forward . 192.168.10.1
  }
```
3. install [istio](https://istio.io/docs/setup/kubernetes/install/helm/#installation-steps)
```sh
ISTIO_INGRESS_IP=

kubectl create namespace istio-system

# bug encountered: https://discuss.istio.io/t/upstream-connect-error-or-disconnect-reset-before-headers-reset-reason-connection-termination/4434/8
# helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.4.2/charts/
helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.3.5/charts/
helm repo add stable https://kubernetes-charts.storage.googleapis.com/

helm install --namespace istio-system \
  istio-init \
  istio.io/istio-init

helm install --namespace istio-system \
  -f services/istio.yaml \
  --set gateways.istio-ingressgateway.loadBalancerIP=$ISTIO_INGRESS_IP \
  istio \
  istio.io/istio

# add istio injection to namespaces
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: NAMESPACE
  labels:
    istio-injection: enabled
EOF
```
4. install nfs provisioner (requires configured NFS server)
```sh
NFS_HOST=
NFS_PATH=

# requires nfs-common on all nodes!
sudo apt-get install -y nfs-common

helm install --namespace storage \
  -f services/nfs-client.yaml \
  --set nfs.server=$NFS_HOST \
  --set nfs.path=$NFS_PATH \
  nfs-client \
  stable/nfs-client-provisioner
```
5. install redis
```sh
REDIS_NAMESPACE=storage
REDIS_AUTH_FILE=./.redis-pass
REDIS_AUTH_SECRET=redis-auth
REDIS_NFS_HOST=
REDIS_NFS_PATH=

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: redis
spec:
  storageClassName: standard
  persistentVolumeReclaimPolicy: Delete
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteMany
  mountOptions:
  - tcp
  - nfsvers=4
  nfs:
    server: $REDIS_NFS_HOST
    path: $REDIS_NFS_PATH
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis
  namespace: storage
spec:
  storageClassName: standard
  volumeName: redis
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
EOF

kubectl create secret generic $REDIS_AUTH_SECRET \
  --namespace $REDIS_NAMESPACE \
  --from-file redis-password=$REDIS_AUTH_FILE

helm install --namespace $REDIS_NAMESPACE \
  -f services/redis.yaml \
  --set existingSecret=$REDIS_AUTH_SECRET \
  --set persistence.existingClaim=redis \
  redis \
  stable/redis
```
6. install spinnaker
```sh
# create necessary files
REDIS_AUTH_FILE=./.redis-pass
SPIN_DOCKER_USER_FILE=./.spin-docker-user
SPIN_DOCKER_PASS_FILE=./.spin-docker-pass
SPIN_GCP_BUCKET=$(cat ./.spin-gcp-bucket)
SPIN_AUTH_URI=$(cat ./.spin-auth-uri)
SPIN_TOKEN_URI=$(cat ./.spin-token-uri)
SPIN_USER_URI=$(cat ./.spin-user-uri)
SPIN_CLIENT_ID=$(cat ./.spin-client-id)
SPIN_CLIENT_SECRET=$(cat ./.spin-client-secret)
SPIN_UI=$(cat ./.spin-ui)
SPIN_API=$(cat ./.spin-api)

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

kubectl create secret generic kubeconfig \
  --namespace $SPIN_NAMESPACE \
  --from-file=config=$HOME/.kube/config

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: halyard-config
  namespace: $SPIN_NAMESPACE
data:
  config.sh: |
    echo "enabling oauth2"
    \$HAL_COMMAND config security authn oauth2 edit \
      --client-id $SPIN_CLIENT_ID \
      --client-secret $SPIN_CLIENT_SECRET \
      --pre-established-redirect-uri $SPIN_API/login

    \$HAL_COMMAND config security ui edit \
      --override-base-url $SPIN_UI
    \$HAL_COMMAND config security api edit \
      --override-base-url $SPIN_API

    \$HAL_COMMAND config security authn oauth2 enable
EOF

# spinnaker
helm install spin stable/spinnaker \
  --namespace $SPIN_NAMESPACE \
  -f services/spinnaker.yaml \
  --set dockerRegistryAccountSecret=$SPIN_DOCKER_SECRET \
  --set gcs.project=$SPIN_GCP_PROJECT \
  --set gcs.bucket=$SPIN_GCP_BUCKET \
  --set gcs.secretName=$SPIN_GCP_SECRET \
  --set redis.external.password=$(cat $REDIS_AUTH_FILE) \
  --set halyard.additionalProfileConfigMaps.data."gate-local\.yml".security.oauth2.client.clientId=$SPIN_CLIENT_ID \
  --set halyard.additionalProfileConfigMaps.data."gate-local\.yml".security.oauth2.client.clientSecret=$SPIN_CLIENT_SECRET \
  --set halyard.additionalProfileConfigMaps.data."gate-local\.yml".security.oauth2.client.userAuthorizationUri=$SPIN_AUTH_URI \
  --set halyard.additionalProfileConfigMaps.data."gate-local\.yml".security.oauth2.client.accessTokenUri=$SPIN_TOKEN_URI \
  --set halyard.additionalProfileConfigMaps.data."gate-local\.yml".security.oauth2.resource.userInfoUri=$SPIN_USER_URI \
  --timeout 25m

# hal configuration
kubectl exec --namespace $SPIN_NAMESPACE -it spinnaker-spinnaker-halyard-0 bash

# adding extra kubernetes accounts
hal config provider kubernetes account add hestia \
  --provider-version v2 \
  --context <CONTEXT> \
  --kubeconfig-file /home/spinnaker/.kube/<CLUSTER>.conf
```

---

from here on, spinnaker can be used to deploy rest of services

---

7. install chart museum
```sh
# enter variables:
# CM_GCP_BUCKET=

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
helm install --namespace $CM_NAMESPACE \
  -f services/chart-museum.yaml \
  --set env.open.CHART_URL=http://chartmuseum-chartmuseum.$CM_NAMESPACE:8080 \
  --set env.open.STORAGE_GOOGLE_BUCKET=$CM_GCP_BUCKET \
  --set gcp.secret.name=$CM_GCP_SECRET \
  --set gcp.secret.key=$CM_GCP_JSON_KEY \
  chartmuseum \
  stable/chartmuseum

# upload chart museum ui helm chart
kubectl port-forward --namespace $CM_NAMESPACE svc/chartmuseum-chartmuseum 8080:8080
helm package services/chart-museum-ui
curl --data-binary "@chart-museum-ui-0.1.0.tgz" http://localhost:8080/api/charts

# chart museum ui
helm install --namespace $CM_NAMESPACE \
  --set chartMuseum=http://chartmuseum-chartmuseum:8080 \
  chart-museum-ui \
  services/chart-museum-ui
```
8. install [metallb](https://github.com/helm/charts/tree/master/stable/metallb)
```sh
helm install --namespace kube-system \
  -f services/metallb.yaml \
  metallb \
  stable/metallb

# requires config map renaming to metallb without spinnaker version
```
9. install [cert-manager](https://github.com/jetstack/cert-manager/tree/master/deploy/charts/cert-manager)
```sh
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml

helm repo add jetstack https://charts.jetstack.io

helm install --namespace istio-system \
  -f services/cert-manager.yaml \
  --version v0.12 \
  cert-manager \
  jetstack/cert-manager
```
10. install [openfaas](https://github.com/openfaas/faas-netes/tree/master/chart/openfaas#deploy-openfaas)
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
  --set basic_auth=true \
  --set istio.mtls=true \
  openfaas/openfaas

# if istio grafana was installed, add permissive policy on prometheus
kubectl create -f manifests/openfaas-system.istio.yaml
```
11. install postgres
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
12. install kubernetes dashboard
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

oAuth2:
* grafana

Open Source:
* https://github.com/helm/charts/pull/17271
* https://github.com/openfaas/faas-netes/pull/505
* https://github.com/solo-io/squash/pull/52
* https://github.com/jbutko/mongoose-find-and-filter/pull/1
* https://github.com/arobson/rabbot/pull/91