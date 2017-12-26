#!/usr/bin/env bash

source lib/services.sh
source config/env.sh

pushd ../verify-service-provider >/dev/null
  ./gradlew clean build installDist -x test
popd >/dev/null

export SAML_SIGNING_KEY="$(base64 -w0 data/pki/sample_rp_signing_primary.pk8)"
export SAML_PRIMARY_ENCRYPTION_KEY="$(base64 -w0 data/pki/sample_rp_encryption_primary.pk8)"
export SERVICE_ENTITY_IDS='["http://dev-rp.local/SAML2/MD"]'
export METADATA_TRUST_STORE="$(base64 -w0 data/pki/metadata.ts)"

lsof -ti:$VSP_PORT | xargs kill

./../verify-service-provider/build/install/verify-service-provider/bin/verify-service-provider server ../verify-service-provider/local-running/local-config.yml > logs/verify-service-provider_console.log &

pid=$!

start_service_checker "verify-service-provider" $VSP_PORT $pid "logs/verify-service-provider.log" "localhost:$VSP_PORT" >/dev/tty
