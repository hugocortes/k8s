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

1. Install kubernetes
2. `kubeadm init --pod-network-cidr 10.244.0.0/16`
3. Master node only:
```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
4. Master node, add `export KUBECONFIG=$HOME/.kube/config` to `~/.bashrc`
5. If running a multi-arch cluster, install `kube-proxy` for architectures that do not match the master node. See [this](https://raw.githubusercontent.com/hugocortes/k8s/devel/services/kube-proxy/kube-proxy-amd64-slave.yaml) manifest for an example amd64 slave running on an ARM master cluster.
6. Add Flannel with multi-arch support
- `kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml`
7. Join other nodes by using:
- `sudo kubeadm join --token=<TOKEN> <IP>`
8. Allow `type: LoadBalancer` by using Metal-LB
- `kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml`
9. Add the IP range to be used by load balancer  (Change IP range 192.168.0.100-192.168.0.110 to reflect your router setup)
- `kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/metal-lb/configMap.yaml`
10. Install the k8s dashboard
- ARM: `kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard-arm.yaml`
- AMD64: `kubectl apply -f https://github.com/kubernetes/dashboard/blob/master/src/deploy/recommended/kubernetes-dashboard.yaml`
11. Create a service account for k8s dashbaord:
- `kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/dashboard/rbac.yaml`
12. Get token to be used in dashboard:
- `kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')`
13. Create internal ingress controller Traefik (Change `loadBalancerIP` in Service to reflect your allocated load balancer IP range)
- `kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/traefik/internal/manifest.yaml`
14. Create k8s dashboard ingress: (Currently pointing to `k8s.internal.hugocortes.me`, change to a domain of your choice)
- `kubectl create -f https://raw.githubusercontent.com/hugocortes/k8s/devel/services/dashboard/ingress.yaml`
15. Add the following to `/etc/hosts` (replacing the domain and IP with your setup)
```
192.168.0.100 traefik-int.internal.hugocortes.me
192.168.0.100 k8s.internal.hugocortes.me
```
16. http://traefik-int.internal.hugocortes.me and https://k8s.internal.hugocortes.me will now be up although HTTPS certificates will be invalid as internal configuration does not validate https
