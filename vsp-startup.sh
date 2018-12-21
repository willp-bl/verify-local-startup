#!/usr/bin/env bash

source lib/services.sh
source config/env.sh

pushd ../verify-service-provider >/dev/null
  ./gradlew -Dorg.gradle.daemon=false clean build installDist -x test
popd >/dev/null

BASE64="base64 -w0" # Linux
if [ "$(uname)" = "Darwin" ]; then
    BASE64="base64 -b0" # macOS
fi

export SAML_SIGNING_KEY="$($BASE64 data/pki/sample_rp_signing_primary.pk8)"
export SAML_PRIMARY_ENCRYPTION_KEY="$($BASE64 data/pki/sample_rp_encryption_primary.pk8)"
export SERVICE_ENTITY_IDS='["http://localhost:50400/metadata"]'
export METADATA_TRUST_STORE="$($BASE64 data/pki/metadata.ts)"
export TEST_RP_MSA_PORT=3300
export IDA_TESTRP_MSA_ENTITYID="http://localhost:3300/matching-service/SAML2/metadata"
export SAML_PRIMARY_SIGNING_CERT="$($BASE64 data/pki/sample_rp_signing_primary.crt)"
export SAML_PRIMARY_ENCRYPTION_CERT="$($BASE64 data/pki/sample_rp_encryption_primary.crt)"
export RP_TRUSTSTORE_ENCODED="$($BASE64 data/pki/relying_parties.ts)"
export RP_TRUSTSTORE_PASSWORD=marshmallow

lsof -ti:$VSP_PORT | xargs kill

./../verify-service-provider/build/install/verify-service-provider/bin/verify-service-provider server ../verify-service-provider/local-running/local-config.yml > logs/verify-service-provider_console.log &

pid=$!

start_service_checker "verify-service-provider" $VSP_PORT $pid "logs/verify-service-provider.log" "localhost:$VSP_PORT" >/dev/tty
