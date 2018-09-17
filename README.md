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

## Multi-Arch Master Cluster Setup

1. Install kubernetes
2. Master node setup
```sh
kubeadm init --pod-network-cidr 10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
3. If running a multi-arch cluster, install `kube-proxy` for architectures that do not match the master node. See [this](https://raw.githubusercontent.com/hugocortes/k8s/devel/services/arm-master/kube-proxy/kube-proxy-amd64-slave.yaml) manifest for an example amd64 slave running on an ARM master cluster.
4. Install Flannel with multi-arch support
```sh
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```
5. Join other nodes by using:
- `sudo kubeadm join --token=<TOKEN> <IP>`
6. Install Metal-LB
```sh
# manifest
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
# configmap, change ip range to your router config
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/metal-lb/configMap.yaml
```
7. Install Traefik internal ingress controller
```sh
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/traefik/rbac.yaml
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/traefik/internal-manifest.yaml
```
8. Install the k8s dashboard
```sh
# arm only
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard-arm.yaml
# amd64 only
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
# service account
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/dashboard/rbac.yaml
# retrieving token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
# dashboard ingress
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/dashboard/ingress.yaml
```
9. Add the following to `/etc/hosts` (replacing the domain and IP with your setup)
```sh
192.168.0.100 traefik-int.internal.hugocortes.me
192.168.0.100 k8s.internal.hugocortes.me
```
- http://traefik-int.internal.hugocortes.me and https://k8s.internal.hugocortes.me will now be up although HTTPS certificates will be invalid as internal configuration does not validate https

### full amd64 cluster additional steps

**The following steps are not guaranteed to work on clusters with arm nodes**

10. Install squash server and client:
```
kubectl create -f https://raw.githubusercontent.com/solo-io/squash/master/contrib/kubernetes/squash-server.yml
kubectl create -f https://raw.githubusercontent.com/solo-io/squash/master/contrib/kubernetes/squash-client.yml
```

11. Install external ingress controller
```sh
# If HTTPs passthrough will be used
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/traefik/external-manifest.yaml
# If HTTPs offloading will be done
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/traefik/external-manifest-http.yaml
```

12. Install nfs based on this [guide](
https://github.com/kubernetes-incubator/external-storage/blob/master/nfs/docs/deployment.md#in-kubernetes---statefulset-of-1-replica)
```sh
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/nfs/manifest.yaml
# install nfs-commons to all nodes
apt-get install -y nfs-common
```

13. Install [helm](https://docs.helm.sh/using_helm/#installing-helm)

14. Install Helm services
```sh
# add service account
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

# install consul
helm install --name consul stable/consul --timeout 600 --namespace consul
# consul ingress
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/consul/ingress.yaml

# install spinnaker
helm install --name spinnaker stable/spinnaker --timeout 600 --namespace spinnaker
# adding GCS and GCR spinnaker access
# https://cloud.google.com/solutions/continuous-delivery-spinnaker-kubernetes-engine
# spinnaker customization (post-install)
kubectl exec --namespace spinnaker -it spinnaker-spinnaker-halyard-0 bash
# spinnaker ingress (spinnaker.internal.hugocortes.me)
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/spinnaker/ingress.yaml
```

15. Follow Helm Openfaas [here](https://github.com/openfaas/faas-netes/tree/master/chart/openfaas#deploy-openfaas)
```sh
# add openfaas ingress
kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/openfaas/ingress.yaml
```

Misc:
- When deploying apps on local cluster, use: `kubectl port-forward svc/<serviceName> -n hugocortes <externalPort>:<servicePort>`
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
