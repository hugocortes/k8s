# k8s
personal bare-metal kubernetes setup. 

This setup is aimed at getting a cluster up and running with Spinnaker. Once Spinnaker is configured, additional applications should be installed by creating Spinnaker pipelines.

# install

1. install kubernetes using [kubespray](https://github.com/kubernetes-sigs/kubespray):
```sh
git clone git@github.com:kubernetes-sigs/kubespray.git
cd kubespray/
cp -r inventory/sample path/to/inventory

# add entries to `inventory.ini`
vim inventory/inventory.ini

# make changes for you cluster
vim path/to/inventory/group_vars/k8s-cluster/k8s-cluster.yml

# run
ansible-playbook -i path/to/inventory/inventory.ini cluster.yml -b

# k8s config location in master node
cat /etc/kubernetes/admin.conf
```
2. (optional) grouping k8s resources into spinnaker applications

Adding `moniker.spinnaker.io/application` annotation will group the resource into applications.
```sh
SPINNAKER_ANNOTATION=kubernetes-dns
kubectl patch daemonset nodelocaldns --namespace kube-system --patch "{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}},{\"spec\":{\"template\":{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}}}}" && \
  kubectl patch service coredns --namespace kube-system --patch "{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}}" && \
  kubectl patch deployment coredns --namespace kube-system --patch "{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }},\"spec\":{\"template\":{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}}}}" && \
  kubectl patch deployment dns-autoscaler --namespace kube-system --patch "{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }},\"spec\":{\"template\":{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}}}}"

SPINNAKER_ANNOTATION=kubernetes-network
kubectl patch daemonset kube-proxy --namespace kube-system --patch "{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }},\"spec\":{\"template\":{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}}}}" && \
  kubectl patch service kubernetes --namespace default --patch "{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}}"

# select correct cni
# flannel
kubectl patch daemonset kube-flannel --namespace kube-system --patch "{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }},\"spec\":{\"template\":{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}}}}"
# calico
kubectl patch daemonset calico-node --namespace kube-system --patch "{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }},\"spec\":{\"template\":{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}}}}" && \
  kubectl patch deployment calico-kube-controllers --namespace kube-system --patch "{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }},\"spec\":{\"template\":{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}}}}"

```
3. (optional) taint k8s nodes for dedicated use
```sh
# taint and label vpn node
kubectl taint node <WORKER NODE> ops/dedicated=vpn:NoSchedule
kubectl label node <WORKER NODE> ops/dedicated=vpn
# taint and label ram node
kubectl taint node <WORKER NODE> ops/dedicated=ram:NoSchedule
kubectl label node <WORKER NODE> ops/dedicated=ram
# label distro nodes
kubectl label node <WORKER NODE> ops/distro=ubuntu
```
3. install [istio](https://istio.io/latest/docs/setup/install/istioctl/)
```sh
kubectl create namespace istio-system

istioctl manifest apply \
  -f services/istio/operator.yaml \
  -f services/istio/cluster.yaml

NAMESPACE=""
kubectl create namespace $NAMESPACE && \
  kubectl label namespace $NAMESPACE istio-injection=enabled
```
4. install nfs provisioner (requires configured NFS server)
```sh
# requires nfs-common on all nodes!
sudo apt-get install -y nfs-common

helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

SPINNAKER_ANNOTATION=nfs-subdir-external-provisioner
NFS_HOST=
NFS_PATH=
helm install --namespace storage \
  -f services/nfs-subdir-external-provisioner/values.yaml \
  --set nfs.server=$NFS_HOST \
  --set nfs.path=$NFS_PATH \
  nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner

kubectl patch deployment nfs-subdir-external-provisioner \
  --namespace kube-system \
  --patch "{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }},\"spec\":{\"template\":{\"metadata\":{\"annotations\": {\"moniker.spinnaker.io/application\": \"$SPINNAKER_ANNOTATION\" }}}}}"
```
6. install spinnaker
```sh
https://cloud.google.com/storage/docs/reporting-changes

SPIN_NAME=spin && \
SPIN_NAMESPACE=spin-system && \
SPIN_GCP_ACCOUNT=spinnaker && \
SPIN_GCP_SECRET=spinnaker-gcp && \
SPIN_GCP_JSON_KEY=key.json && \
SPIN_GCP_JSON_FILE=$HOME/.gcloud/$SPIN_GCP_ACCOUNT.json && \
SPIN_PUBSUB_SUBSCRIPTION=$(cat ./.spin-pubsub-subscription) && \
SPIN_DOCKER_SECRET=spinnaker-docker && \
SPIN_DOCKER_USER_FILE=./.spin-docker-user && \
SPIN_DOCKER_PASS_FILE=./.spin-docker-pass && \
SPIN_KUBECONFIG_SECRET=spinnaker-kubeconfig && \
SPIN_KUBECONFIG_FILE=./.spin-kubeconfig && \
SPIN_GCP_PROJECT=$(gcloud info --format='value(config.project)')

# create service account
./scripts/create-service-account.sh $SPIN_GCP_ACCOUNT $HOME/.gcp/$SPIN_GCP_ACCOUNT.json

# create required secrets

kubectl create secret generic $SPIN_GCP_SECRET \
  --namespace $SPIN_NAMESPACE \
  --from-file=$SPIN_GCP_JSON_KEY=$SPIN_GCP_JSON_FILE

# kubectl create secret docker-registry $SPIN_DOCKER_SECRET \
#   --namespace $SPIN_NAMESPACE \
#   --docker-server=https://index.docker.io/v1/ \
#   --docker-username=$(cat $SPIN_DOCKER_USER_FILE) \
#   --docker-password=$(cat $SPIN_DOCKER_PASS_FILE)

kubectl create secret generic $SPIN_DOCKER_SECRET \
  --namespace $SPIN_NAMESPACE \
  --from-file=dockerhub=$SPIN_DOCKER_PASS_FILE

kubectl create secret generic $SPIN_KUBECONFIG_SECRET \
  --namespace $SPIN_NAMESPACE \
  --from-file=config=$SPIN_KUBECONFIG_FILE

kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: spinnaker-halyard-config
  namespace: $SPIN_NAMESPACE
data:
  config.sh: |
    echo "enabling google pubsub triggers"
    \$HAL_COMMAND config pubsub google enable
    \$HAL_COMMAND config pubsub google subscription add \
      --project $SPIN_GCP_PROJECT \
      --json-path /opt/gcs/key.json \
      --subscription-name $SPIN_PUBSUB_SUBSCRIPTION \
      --message-format GCS \
      gcs
EOF

helm install --namespace $SPIN_NAMESPACE \
  -f services/spinnaker/values.yaml \
  -f services/spinnaker/config.yaml \
  --set halyard.additionalSecrets.name=$SPIN_GCP_SECRET \
  --set dockerRegistryAccountSecret=$SPIN_DOCKER_SECRET \
  --set gcs.project=$SPIN_GCP_PROJECT \
  --set gcs.secretName=$SPIN_GCP_SECRET \
  --set kubeConfig.secretName=$SPIN_KUBECONFIG_SECRET \
  --timeout 15m \
  $SPIN_NAME \
  stable/spinnaker

# hal configuration
# https://www.spinnaker.io/reference/halyard/commands/
kubectl exec --namespace $SPIN_NAMESPACE -it spinnaker-spinnaker-halyard-0 bash
```

add prometheus annotations and ports to deployment:
```sh
# add metrics port to service (required for istio service discovery)
kubectl patch service $SPIN_NAME-clouddriver --namespace $SPIN_NAMESPACE --patch '{"spec":{"ports":[{"name":"app","port":7002,"protocol":"TCP","targetPort":7002},{"name":"metrics","port":8008,"protocol":"TCP","targetPort":8008}]}}' && \
kubectl patch service $SPIN_NAME-echo --namespace $SPIN_NAMESPACE --patch '{"spec":{"ports":[{"name":"app","port":8089,"protocol":"TCP","targetPort":8089},{"name":"metrics","port":8008,"protocol":"TCP","targetPort":8008}]}}' && \
kubectl patch service $SPIN_NAME-front50 --namespace $SPIN_NAMESPACE --patch '{"spec":{"ports":[{"name":"app","port":8080,"protocol":"TCP","targetPort":8080},{"name":"metrics","port":8008,"protocol":"TCP","targetPort":8008}]}}' && \
kubectl patch service $SPIN_NAME-gate --namespace $SPIN_NAMESPACE --patch '{"spec":{"ports":[{"name":"app","port":8084,"protocol":"TCP","targetPort":8084},{"name":"metrics","port":8008,"protocol":"TCP","targetPort":8008}]}}' && \
kubectl patch service $SPIN_NAME-igor --namespace $SPIN_NAMESPACE --patch '{"spec":{"ports":[{"name":"app","port":8088,"protocol":"TCP","targetPort":8088},{"name":"metrics","port":8008,"protocol":"TCP","targetPort":8008}]}}' && \
kubectl patch service $SPIN_NAME-orca --namespace $SPIN_NAMESPACE --patch '{"spec":{"ports":[{"name":"app","port":8083,"protocol":"TCP","targetPort":8083},{"name":"metrics","port":8008,"protocol":"TCP","targetPort":8008}]}}' && \
kubectl patch service $SPIN_NAME-rosco --namespace $SPIN_NAMESPACE --patch '{"spec":{"ports":[{"name":"app","port":8087,"protocol":"TCP","targetPort":8087},{"name":"metrics","port":8008,"protocol":"TCP","targetPort":8008}]}}' && \
kubectl patch service $SPIN_NAME-kayenta --namespace $SPIN_NAMESPACE --patch '{"spec":{"ports":[{"name":"app","port":8090,"protocol":"TCP","targetPort":8090},{"name":"metrics","port":8008,"protocol":"TCP","targetPort":8008}]}}'

# add prometheus annotations
kubectl patch service $SPIN_NAME-clouddriver --namespace $SPIN_NAMESPACE --patch '{"metadata":{"annotations": {"prometheus.io/scrape": "true","prometheus.io/port": "8008","prometheus.io/path": "/prometheus_metrics"}}}' && \
kubectl patch service $SPIN_NAME-echo --namespace $SPIN_NAMESPACE --patch '{"metadata":{"annotations": {"prometheus.io/scrape": "true","prometheus.io/port": "8008","prometheus.io/path": "/prometheus_metrics"}}}' && \
kubectl patch service $SPIN_NAME-front50 --namespace $SPIN_NAMESPACE --patch '{"metadata":{"annotations": {"prometheus.io/scrape": "true","prometheus.io/port": "8008","prometheus.io/path": "/prometheus_metrics"}}}' && \
kubectl patch service $SPIN_NAME-gate --namespace $SPIN_NAMESPACE --patch '{"metadata":{"annotations": {"prometheus.io/scrape": "true","prometheus.io/port": "8008","prometheus.io/path": "/prometheus_metrics"}}}' && \
kubectl patch service $SPIN_NAME-igor --namespace $SPIN_NAMESPACE --patch '{"metadata":{"annotations": {"prometheus.io/scrape": "true","prometheus.io/port": "8008","prometheus.io/path": "/prometheus_metrics"}}}' && \
kubectl patch service $SPIN_NAME-orca --namespace $SPIN_NAMESPACE --patch '{"metadata":{"annotations": {"prometheus.io/scrape": "true","prometheus.io/port": "8008","prometheus.io/path": "/prometheus_metrics"}}}' && \
kubectl patch service $SPIN_NAME-rosco --namespace $SPIN_NAMESPACE --patch '{"metadata":{"annotations": {"prometheus.io/scrape": "true","prometheus.io/port": "8008","prometheus.io/path": "/prometheus_metrics"}}}' && \
kubectl patch service $SPIN_NAME-kayenta --namespace $SPIN_NAMESPACE --patch '{"metadata":{"annotations": {"prometheus.io/scrape": "true","prometheus.io/port": "8008","prometheus.io/path": "/prometheus_metrics"}}}'
```

from here on, spinnaker can be used to deploy rest of services

for bare metal clusters, [metallb](https://metallb.universe.tf/installation/) is highly recommended in order to provided loadBalancer to cluster.
