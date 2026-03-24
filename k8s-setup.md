## Recreate the ConfigMap with the correct filename mapping:
kubectl create configmap kong-declarative-config --from-file=kong.yml=kong.yaml -o yaml --dry-run=client | kubectl apply -f -
