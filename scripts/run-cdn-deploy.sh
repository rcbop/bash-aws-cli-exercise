#!/usr/bin/env bash

######### CLOUDFRONT (CDN and reverse proxy)

cloudfront_deploy() {
    sep
    separator "Cloudfront deployment"
    export APP_NAME=${DOCKER_IMAGE_NAME}
    export EB_ENVIRONMENT_NAME=${APP_NAME}-${GIT_BRANCH}
    export S3_ORIGIN_ID="S3-${FRONTEND_BUCKET}"
    export S3_BUCKET_DOMAIN="${FRONTEND_BUCKET}.s3.amazonaws.com"
    export ELB_ORIGIN_ID="ELB-${EB_ENVIRONMENT_NAME}"
    export CDN_COMMENT=${EB_ENVIRONMENT_NAME}
    export CALLER_REF=$(date "+%Y%m%d-%H%M%S")
    export DEFAULT_ROOT_OBJ='index.html'
    export ACM_CERTIFICATE_ID='daa792a7-9fe4-4d55-b095-ca56a282c4b0'
    export CERTIFICATE_ARN="arn:aws:acm:us-east-1:${AWS_ACCOUNT_ID}:certificate/${ACM_CERTIFICATE_ID}"
    export ELB_DOMAIN_NAME=$(aws elasticbeanstalk describe-environments --environment-names ${EB_ENVIRONMENT_NAME} --query "Environments[?Status=='Ready'].EndpointURL" | jq '.[]' -r)
    export HOSTED_ZONE_NAME='rogerpeixoto.net'
    export CNAME_ALIAS='example-rest-api-deployment.rogerpeixoto.net'


    cd aws/cloudfront

    echo 'Rendering cloudfront configurations'
    eval "echo \"$(<cloudfront.config.skeleton.json.tmpl)\"" 2> /dev/null > cloudfront.json

    cat cloudfront.json | jq

    AWS_CF_LIST=$(aws cloudfront list-distributions --profile "${AWS_PROFILE}")
    if [[ -z ${AWS_CF_LIST} ]]; then
        aws cloudfront create-distribution --distribution-config file://cloudfront.json
        AWS_CF_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='${EB_ENVIRONMENT_NAME}'].Id" | jq '.[]' -r)
        aws cloudfront tag-resource --resource "arn:aws:cloudfront::${AWS_ACCOUNT_ID}:distribution/${AWS_CF_ID}" --tags "Items=[{Key=${GROUP_TAG_KEY},Value=${GROUP_TAG_VALUE}}]"
        aws cloudfront wait distribution-deployed --id ${AWS_CF_ID}
    fi
}

cloudfront_deploy