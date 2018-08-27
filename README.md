# k8s
simple kubernetes deployments

# Kubernetes

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
