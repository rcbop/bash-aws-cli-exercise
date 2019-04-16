#!/usr/bin/env bash
export CNAME_ALIAS='example-rest-api-deployment.rogerpeixoto.net'
export DOCKER_IMAGE_NAME='employees-api'
export APP_NAME=${DOCKER_IMAGE_NAME}
export GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
export EB_ENVIRONMENT_NAME=${APP_NAME}-${GIT_BRANCH}
export AWS_CF_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='${EB_ENVIRONMENT_NAME}'].Id" | jq '.[]' -r)
export GROUP_TAG_KEY='resource-group'
export GROUP_TAG_VALUE=${EB_ENVIRONMENT_NAME}

source ./scripts/utils.sh

######### ROUTE 53 DNS SERVICE
cd aws/route53

sep
separator "Route53 dns creation\033[0m"

HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Config.Comment=='${EB_ENVIRONMENT_NAME}'].Id" | jq '.[]' -r | xargs basename)
if [ -z $HOSTED_ZONE_ID ]; then
    aws route53 create-hosted-zone --name ${HOSTED_ZONE_NAME} --caller-reference $(date "+%Y%m%d-%H%M%S") --hosted-zone-config Comment="${EB_ENVIRONMENT_NAME}"
fi
export HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Config.Comment=='${EB_ENVIRONMENT_NAME}'].Id" | jq '.[]' -r | xargs basename)
aws route53 change-tags-for-resource --resource-type 'hostedzone' --resource-id $HOSTED_ZONE_ID --add-tags "Key=${GROUP_TAG_KEY},Value=${GROUP_TAG_VALUE}"

export AWS_CF_DOMAIN_NAME=$(aws cloudfront list-distributions --query "DistributionList.Items[?Id=='${AWS_CF_ID}'].DomainName" | jq '.[]' -r)

eval "echo \"$(<record-set.config.json.tmpl)\"" 2> /dev/null > record-set.json
cat record-set.json | jq
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE_ID} --change-batch file://record-set.json
