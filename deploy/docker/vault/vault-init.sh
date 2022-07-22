#!/bin/sh

alias vault="docker exec -i $(docker ps|awk '/vault:latest/ {print $1}') vault"

while ! nc -z localhost 8200;
do
  echo sleeping;
  sleep 1;
done;
echo "Vault Connected"

sleep 20

vault operator init |awk -F: '/:/ {
    if ($1 ~ /Unseal Key 1/) print "UNSEAL_KEY_1="$2
    if ($1 ~ /Unseal Key 2/) print "UNSEAL_KEY_2="$2
    if ($1 ~ /Unseal Key 3/) print "UNSEAL_KEY_3="$2
    if ($1 ~ /Unseal Key 4/) print "UNSEAL_KEY_4="$2
    if ($1 ~ /Unseal Key 5/) print "UNSEAL_KEY_5="$2
    if ($1 ~ /Initial Root Token/) print "INITIAL_ROOT_TOKEN="$2
}' \
| sed 's/ //g' \
| tee -a deploy/docker/.env

source deploy/docker/.env

# unseal the vault using 3 of the keys
vault operator unseal $UNSEAL_KEY_1
vault operator unseal $UNSEAL_KEY_2
vault operator unseal $UNSEAL_KEY_3

echo $INITIAL_ROOT_TOKEN|vault login -

vault auth enable approle
vault secrets enable -path=secret/ kv

# enable file audit to the mounted logs volume
vault audit enable file file_path=/vault/logs/audit.log
vault audit list

# create the app-specific policy
vault policy write auth-service /policies/auth-service-policy.json
vault policy read auth-service

vault policy write product-service /policies/product-service-policy.json
vault policy read product-service

vault policy write review-service /policies/review-service-policy.json
vault policy read review-service

vault policy write apollo-gateway /policies/apollo-gateway-policy.json
vault policy read apollo-gateway

vault policy write app /policies/app-policy.json
vault policy read app

# create the app token
vault token create -policy=app | awk '/token/ {
if ($1 == "token") print "APP_TOKEN="$2
else if ($1 == "token_accessor") print "APP_TOKEN_ACCESSOR="$2
}' \
| tee -a deploy/docker/.env

vault write auth/approle/role/myapp \
secret_id_num_uses=0 \
secret_id_ttl=0 \
token_num_uses=0 \
token_ttl=10m \
token_max_ttl=10m \
policies=app

vault write auth/approle/role/auth \
secret_id_num_uses=0 \
secret_id_ttl=0 \
token_num_uses=0 \
token_ttl=10m \
token_max_ttl=10m \
policies=auth-service

vault write auth/approle/role/product \
secret_id_num_uses=0 \
secret_id_ttl=0 \
token_num_uses=0 \
token_ttl=10m \
token_max_ttl=10m \
policies=product-service

vault write auth/approle/role/review \
secret_id_num_uses=0 \
secret_id_ttl=0 \
token_num_uses=0 \
token_ttl=10m \
token_max_ttl=10m \
policies=review-service

vault write auth/approle/role/apollo-gateway \
secret_id_num_uses=0 \
secret_id_ttl=0 \
token_num_uses=0 \
token_ttl=10m \
token_max_ttl=10m \
policies=apollo-gateway

vault write auth/approle/role/app \
secret_id_num_uses=0 \
secret_id_ttl=0 \
token_num_uses=0 \
token_ttl=10m \
token_max_ttl=10m \
policies=app

vault read auth/approle/role/myapp/role-id | awk '/role_id/ {
print "MYAPP_APP_ROLE_ROLE_ID="$2
}' \
| tee -a deploy/docker/.env

vault write -f auth/approle/role/myapp/secret-id | awk '/secret_id/ {
if ($1 == "secret_id") print "MYAPP_APP_ROLE_SECRET_ID="$2
else if ($1 == "secret_id_accessor") print "MYAPP_APP_ROLE_SECRET_ID_ACCESSOR="$2
}' \
| tee -a deploy/docker/.env

vault read auth/approle/role/auth/role-id | awk '/role_id/ {
print "AUTH_APP_ROLE_ROLE_ID="$2
}' \
| tee -a deploy/docker/.env

vault write -f auth/approle/role/auth/secret-id | awk '/secret_id/ {
if ($1 == "secret_id") print "AUTH_APP_ROLE_SECRET_ID="$2
else if ($1 == "secret_id_accessor") print "AUTH_APP_ROLE_SECRET_ID_ACCESSOR="$2
}' \
| tee -a deploy/docker/.env

vault read auth/approle/role/product/role-id | awk '/role_id/ {
print "PRODUCT_APP_ROLE_ROLE_ID="$2
}' \
| tee -a deploy/docker/.env

vault write -f auth/approle/role/product/secret-id | awk '/secret_id/ {
if ($1 == "secret_id") print "PRODUCT_APP_ROLE_SECRET_ID="$2
else if ($1 == "secret_id_accessor") print "PRODUCT_APP_ROLE_SECRET_ID_ACCESSOR="$2
}' \
| tee -a deploy/docker/.env

vault read auth/approle/role/review/role-id | awk '/role_id/ {
print "REVIEW_APP_ROLE_ROLE_ID="$2
}' \
| tee -a deploy/docker/.env

vault write -f auth/approle/role/review/secret-id | awk '/secret_id/ {
if ($1 == "secret_id") print "REVIEW_APP_ROLE_SECRET_ID="$2
else if ($1 == "secret_id_accessor") print "REVIEW_APP_ROLE_SECRET_ID_ACCESSOR="$2
}' \
| tee -a deploy/docker/.env

vault read auth/approle/role/apollo-gateway/role-id | awk '/role_id/ {
print "APOLLO_GATEWAY_APP_ROLE_ROLE_ID="$2
}' \
| tee -a deploy/docker/.env

vault write -f auth/approle/role/apollo-gateway/secret-id | awk '/secret_id/ {
if ($1 == "secret_id") print "APOLLO_GATEWAY_APP_ROLE_SECRET_ID="$2
else if ($1 == "secret_id_accessor") print "APOLLO_GATEWAY_APP_ROLE_SECRET_ID_ACCESSOR="$2
}' \
| tee -a deploy/docker/.env

# source the env file to get the new key vars
source deploy/docker/.env

# create initial secrets
vault kv put secret/application/prod SPRING_SECURITY_OAUTH2_RESOURCE-SERVER_JWT_ISSUER-URI=http://auth-service:9000
vault kv put secret/auth-service/prod PORT=9000 AUTH-SERVER_PROVIDER_ISSUER=http://auth-service:9000 CORS_ALLOWED-ORIGINS='http://localhost:3000, http://127.0.0.1:3000, http://localhost, http://127.0.0.1' SPRING_DATA_MONGODB_URI=mongodb://auth-admin:iXCjXb7e2yjJbjRa@mongodb:27017/auth GOOGLE_CLIENT_ID=10959265505-a56ge3f9j1p4p0gf3brntbfu3r1sa58t.apps.googleusercontent.com GOOGLE_CLIENT_SECRET=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
vault kv put secret/product-service/prod PORT=8081 SPRING_DATA_MONGODB_URI=mongodb://product-admin:iXCjXb7e2yjJbjRp@mongodb:27017/product
vault kv put secret/review-service/prod PORT=8082 SPRING_DATA_MONGODB_URI=mongodb://review-admin:iXCjXb7e2yjJbjRr@mongodb:27017/review
vault kv put secret/apollo-gateway/production PORT=4000 CORS_ALLOWED_ORIGINS='http://localhost:3000, http://127.0.0.1:3000, https://studio.apollographql.com'