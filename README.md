# k8s
simple kubernetes deployments

## Running Locally

Prereqs:
* Install [Minikube](https://kubernetes.io/docs/setup/minikube/).
* Install [Skaffold](https://github.com/GoogleContainerTools/skaffold#installation)
* Install [Kustomize](https://github.com/kubernetes-sigs/kustomize/blob/master/INSTALL.md)

1. `minikube start`
2. `skaffold dev --filename <desired service skaffold yaml>`
  - To track local changes updates `workspace` to local project directory
3. Navigate to `http://192.168.99.100:31000/status`
4. While `skaffold` is running, any changes made will rebuild

## Debugging Locally

### NodeJS minikube

Prereqs:
* Install [prereqs](#running-locally)
* Install [Squash](https://github.com/solo-io/squash/tree/master/docs/install)
* Install [VS Code Squash Plugin](https://marketplace.visualstudio.com/items?itemName=ilevine.squash)
1. `minikube start`
2. `kubectl proxy`
3. `skaffold dev --filename <desired service skaffold yaml>` (Must run with `NODE_ENV=local`)
4. Update `workspace` to local project directory
5. Add the following settings to VSCode
```json
"vs-squash.squash-server-url": "http://localhost:8001/api/v1/namespaces/squash/services/squash-server:http-squash-api/proxy/api/v2",
"vs-squash.process-name": "node",
"vs-squash.remotePath": "/app"
```
6. Run command in VSCode: `Squash Debug Container` > `Desired Pod` > `NodeJS8`
7. Debugger will breakpoint on connect by default
8. Ready to debug!

## Cluster Setup

1. Install [kubernetes](https://kubernetes.io/docs/setup/independent/install-kubeadm/)
2. Master node setup
```sh
kubeadm init --pod-network-cidr 10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
3. Install Flannel
```sh
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```
4. Join other nodes by using:
- `sudo kubeadm join --token=<TOKEN> <IP>`
5. Install [helm](https://docs.helm.sh/using_helm/#installing-helm)
6. Add Helm RBAC
```sh
# add service account
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
```
7. Install MetalLB
```sh
helm install --name metallb \
  --namespace metallb \
  -f services/metallb-values.yaml \
  stable/metallb
```
8. Install NFS provisioner
```sh
# Requires a configured nfs server
helm install --name nfs-client \
  --namespace kube-system \
  -f services/nfs-client-values.yaml \
  stable/nfs-client-provisioner
```
9. Install Consul
```sh
helm install --name consul \
  -f services/consul-values.yaml \
  stable/consul
```
10. Install Internal Traefik
```sh
# Internal Traefik
helm install --name traefik-internal \
  -f services/traefik-int-values.yaml \
  stable/traefik

# Dev Traefik
helm install --name traefik-dev \
  -f services/traefik-dev-values.yaml \
  stable/traefik

# External Traefik
helm install --name traefik-external \
  -f services/traefik-ext-values.yaml \
  stable/traefik
```
11. Install Kubernetes Dashboard
```sh
helm install --name k8s-dashboard \
  -f services/k8s-dashboard-values.yaml \
  stable/kubernetes-dashboard

# retrieving token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```
12. Install [Openfaas](https://github.com/openfaas/faas-netes/tree/master/chart/openfaas#deploy-openfaas)
```sh
# Create the namespaces
kubectl apply -f https://raw.githubusercontent.com/openfaas/faas-netes/master/namespaces.yml

# Generate secret
PASSWORD=$(head -c 12 /dev/urandom | shasum| cut -d' ' -f1)

kubectl -n openfaas create secret generic basic-auth \
--from-literal=basic-auth-user=admin \
--from-literal=basic-auth-password="$PASSWORD"

# add repo
helm repo add openfaas https://openfaas.github.io/faas-netes/

helm repo update \
&& helm upgrade openfaas \
  --install openfaas/openfaas \
  --namespace openfaas \
  -f services/openfaas-values.yaml
```
13. Install squash server and client:
```sh
kubectl create -f https://raw.githubusercontent.com/solo-io/squash/master/contrib/kubernetes/squash-server.yml
kubectl create -f https://raw.githubusercontent.com/solo-io/squash/master/contrib/kubernetes/squash-client.yml
```
14. Install Spinnaker
```sh
# install spinnaker
helm install --name spinnaker \
  --namespace spinnaker \
  -f services/spinnaker-values.yaml \
  stable/spinnaker

# adding GCS and GCR spinnaker access
# https://cloud.google.com/solutions/continuous-delivery-spinnaker-kubernetes-engine
# spinnaker customization (post-install)
kubectl exec --namespace spinnaker -it spinnaker-spinnaker-halyard-0 bash

# redeploy after changes
hal deploy apply
```

Misc:
- When deploying apps on local cluster, use: `kubectl port-forward svc/<serviceName> -n <namespace> <LOCAL_PORT>:<servicePort>`
- The following script will allow you to create Basic auth secrets (required for spinnaker ingress which needs spinnaker-auth named secret)
```sh
#!/bin/bash
if [[ $# -eq 0 ]] ; then
    echo "Run the script with the required auth user and namespace for the secret: ${0} [name] [user] [namespace]"
    exit 0
fi
printf "${2}:`openssl passwd -apr1`\n" >> ingress_auth.tmp
kubectl delete secret -n ${3} ${1}
kubectl create secret generic ${1} --from-file=ingress_auth.tmp -n ${3}
rm ingress_auth.tmp
```
