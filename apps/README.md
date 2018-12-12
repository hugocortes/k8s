## Apps

To package an app as .tgz:

`helm package /dir/to/app`

Deploying an app using helm
```sh
helm install --name APP \
--namespace hugocortes \
-f blue-green/values-dev.yaml \
blue-green
```
