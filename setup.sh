
export NGC_API_TOKEN=dThxdGhpYTFmYXE4dGRsZHZzaW1pdmtkZTk6ZmEzNDJhYzktNWM3ZC00OGMyLThhMzMtN2M4NGJhZTYwYjlk

az aks get-credentials --format azure --resource-group rg-nvidia --name aks-nvidia

export KUBECONFIG=/home/${USER}/.kube/config

kubelogin convert-kubeconfig –l azurecli

kubectl get nodes

kubectl create namespace omni-streaming

kubectl create secret -n omni-streaming docker-registry regcred \
    --docker-server=nvcr.io \
    --docker-username='$oauthtoken' \
    --docker-password=$NGC_API_TOKEN \
    --dry-run=client -o json | \
    kubectl apply -f -

helm install --wait --generate-name \
    -n gpu-operator --create-namespace \
    --repo https://helm.ngc.nvidia.com/nvidia \
    gpu-operator \
    --set driver.version=535.104.05        

# helm upgrade oci://registry-1.docker.io/bitnamicharts/memcached --install \
#     -n omni-streaming --create-namespace \
#     -f helm/memcached/values.yml \
#     memcached-service-r3 memcached    

# helm upgrade --install -n omni-streaming --create-namespace -f helm/memcached/values.yml --repo https://charts.bitnami.com/bitnami  memcached-service-r3 memcached

helm upgrade --install memcached oci://registry-1.docker.io/bitnamicharts/memcached -n omni-streaming --create-namespace -f helm/memcached/values.yml

kubectl create namespace flux-operators

helm repo add fluxcd-community https://fluxcd-community.github.io/helm-charts
helm repo update


helm upgrade --install \
  --namespace flux-operators \
  -f helm/flux2/values.yaml \
fluxcd fluxcd-community/flux2

kubectl create secret -n omni-streaming generic ngc-omni-user \
            --from-literal=username='$oauthtoken' \
            --from-literal=password=$NGC_API_TOKEN \
            --dry-run=client -o json |
            kubectl apply -f -

helm repo add omniverse https://helm.ngc.nvidia.com/nvidia/omniverse/ --username='$oauthtoken' --password=$NGC_API_TOKEN

helm upgrade --install \
  --namespace omni-streaming \
  -f helm/kit-appstreaming-rmcp/values.yaml  \
  rmcp omniverse/kit-appstreaming-rmcp            


sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini -d "*.contoso-omniverse.com" --preferred-challenges dns-01

sudo cat /etc/letsencrypt/live/contoso-omniverse.com/fullchain.pem /etc/letsencrypt/live/contoso-omniverse.com/privkey.pem > contoso-omniverse.com.pem

sudo cat fullchain.pem privkey.pem > contoso-omniverse.com.pem

openssl pkcs12 -export -in contoso-omniverse.com.pem -out contoso-omniverse.com.pfx -password pass:wxdAao2JwpqV6dQiP2aW