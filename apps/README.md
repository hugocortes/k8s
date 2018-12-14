## Apps

To package an app as .tgz:

`helm package /dir/to/app`

Deploying an app using helm
```sh
helm install --name APP \
--namespace hugocortes \
-f APP/values-dev.yaml \
APP
```
