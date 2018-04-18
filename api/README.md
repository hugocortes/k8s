# Steps to deploy
1. Commit the configmap `kubectl create -f api-config.yaml`
  * View the config with `kubectl get configmaps api-config -o yaml`
2. Encode secret values, i.e. `echo -n "VALUE" | base64`
3. Commit the secrets (after entering values as Base64 encoded) `kubectl create -f api-secret.yaml`
  * View the secrets with `kubectl get secret api-secret -o yaml`
4. Deploy `kubectl create -f api.yaml`
