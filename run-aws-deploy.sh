#!/usr/bin/env bash
#
#  One script to rule them all,
#  one script to find them,
#  One script to bring them all
#  And in the darkness bind them.
#
set -x
set -e
#AWS_SECRET_KEY_ID=${AWS_SECRET_ACCESS_KEY:?'Must provide access key id'}
#AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:?'Must provide secret access key id'}
export AWS_DEFAULT_REGION='us-east-2'
export AWS_DEFAULT_OUTPUT='json'
export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:?'Must provide account id'}
export ECR_REGISTRY_ADDRESS=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
export GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
export DOCKER_IMAGE_NAME='employees-api'
export DOCKER_IMAGE_TAG=${GIT_BRANCH}

source ./scripts/setup-backend-envvars.sh
source ./scripts/utils.sh

export AWS_PROFILE='default'
export APP_NAME=${DOCKER_IMAGE_NAME}
export EB_ENVIRONMENT_NAME=${APP_NAME}-${GIT_BRANCH}
export BACKEND_INSTANCE_TYPE='t2.micro'
export FRONTEND_BUCKET="rcbop-test-service-${GIT_BRANCH}"

export GROUP_TAG_KEY='resource-group'
export GROUP_TAG_VALUE=${EB_ENVIRONMENT_NAME}

CWD=$(pwd)

cleanup(){
    #echo 'Cleaning up credentials'
    #aws configure set aws_access_key_id '' --profile "$AWS_PROFILE"
    #aws configure set aws_secret_access_key '' --profile "$AWS_PROFILE"
    cd "$CWD"
    echo 'Cleaning rendered templates'
    rm -vf aws/*.json
    rm -vf aws/elasticbeanstalk/deploy/.ebextensions/eb-efs-config.yaml
    rm -vf aws/elasticbeanstalk/deploy/*
    rm -rf aws/elasticbeanstalk/deploy/.*
    rm -rf aws/elasticbeanstalk/deploy/.gitignore
    rm -rf aws/cloudfront/*.json
    rm -rf aws/route53/*.json
}

trap cleanup EXIT

#echo 'configure aws cli'
#aws configure set region "$AWS_DEFAULT_REGION" --profile "$AWS_PROFILE"
#aws configure set output 'json' --profile "$AWS_PROFILE"

#set +x
#aws configure set aws_access_key_id "$AWS_SECRET_KEY_ID" --profile "$AWS_PROFILE"
#aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile "$AWS_PROFILE"
#set -x

sep
separator "##### AWS DEPLOYMENT SCRIPT #####"
sep
echo
echo
separator "Building docker images"
docker-compose build

#############################
######### RESOURCE GROUP
sep
separator "Creating resource group"

cd aws

RES_GROUPS=$(aws resource-groups list-groups --profile ${AWS_PROFILE})
if [[ $RES_GROUPS != *$EB_ENVIRONMENT_NAME* ]]; then
    aws resource-groups create-group --name ${EB_ENVIRONMENT_NAME} \
        --tags "Key=resource-group,Value=${GROUP_TAG_VALUE}" \
        --resource-query '{"Type":"TAG_FILTERS_1_0","Query":"{\"ResourceTypeFilters\":[\"AWS::AllSupported\"],\"TagFilters\":[{\"Key\":\"resource-group\",\"Values\":[\"employees-api-master\"]}]}"}' \
        --profile ${AWS_PROFILE}
fi

#############################
######### FRONTEND
sep
separator "S3 frontend deployment"
echo
S3_BUCKETS=$(aws s3api list-buckets --profile $AWS_PROFILE)
if [[ "${S3_BUCKETS}" != *${FRONTEND_BUCKET}* ]]; then
    echo 'Creating static page s3 bucket'
    aws s3 mb s3://${FRONTEND_BUCKET} --region ${AWS_DEFAULT_REGION} --profile "${AWS_PROFILE}"
    aws s3api put-bucket-tagging --bucket ${FRONTEND_BUCKET} --tagging "TagSet=[{Key=${GROUP_TAG_KEY},Value=${GROUP_TAG_VALUE}}]" --profile "${AWS_PROFILE}"
    echo 'ok'
fi

echo 'Copying data'
aws s3 cp ../frontend/testeget.html s3://${FRONTEND_BUCKET}/index.html --acl public-read --profile "${AWS_PROFILE}"
echo 'ok'

echo 'Enabling web configuration for s3 bucket'
aws s3 website s3://${FRONTEND_BUCKET} --index-document index.html --profile "${AWS_PROFILE}"
echo 'ok'
echo

#############################
######### BACKEND
sep
separator "Elastic Beanstalk backend deployment"
echo
REPO_LIST=$(aws ecr describe-repositories --profile ${AWS_PROFILE})

if [[ "${REPO_LIST}" != *${DOCKER_IMAGE_NAME}* ]]; then
    echo 'Creating ECR repos'
    aws ecr create-repository --repository-name "${DOCKER_IMAGE_NAME}" --profile "${AWS_PROFILE}"
    aws ecr tag-resource --resource-arn arn:aws:ecr:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT_ID}:repository/${DOCKER_IMAGE_NAME} \
        --tags "Key=${GROUP_TAG_KEY},Value=${GROUP_TAG_VALUE}" --profile "${AWS_PROFILE}"
    echo 'ok'
fi

separator "Authenticating to ECR"
echo
$(aws ecr get-login --no-include-email --profile ${AWS_PROFILE})

echo 'Tagging new docker image'
docker tag ${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG} ${ECR_REGISTRY_ADDRESS}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
echo 'Pushing new docker image to ECR'
docker push ${ECR_REGISTRY_ADDRESS}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
echo 'ok'

AWSCWD=$(pwd)

sep
separator "Grant ECR read/pull rights to eb ec2 role"
echo
aws iam attach-role-policy --role-name "aws-elasticbeanstalk-ec2-role" --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
echo 'ok'

APP_LIST=$(aws elasticbeanstalk describe-applications --profile ${AWS_PROFILE})
if [[ "$APP_LIST" != *${EB_ENVIRONMENT_NAME}* ]]; then
    echo 'Creting ElasticBeanstalk Application'
    aws elasticbeanstalk create-application --application-name ${EB_ENVIRONMENT_NAME} --profile ${AWS_PROFILE}
    aws elasticbeanstalk update-tags-for-resource \
        --resource-arn "arn:aws:elasticbeanstalk:${AWS_DEFAULT_REGION}:${AWS_ACCOUNT_ID}:application/${EB_ENVIRONMENT_NAME}" \
        --tags-to-add "Key=${GROUP_TAG_KEY},Value=${GROUP_TAG_VALUE}" \
        --profile "${AWS_PROFILE}"
    echo 'ok'
fi

sep
separator "Starting elastic beanstalk setup"
echo
cd elasticbeanstalk
mkdir -p deploy/.ebextensions
echo 'Rendering dockerun eb template'
eval "echo \"$(<Dockerrun.aws.single.json.tmpl)\"" 2> /dev/null > deploy/Dockerrun.aws.json

echo 'Rendering ebextensions envvars options.config'
eval "echo \"$(<options.config.tmpl)\"" 2> /dev/null > deploy/.ebextensions/options.config

cd deploy
echo 'Initialize elasticbeanstalk cli'
eb init ${EB_ENVIRONMENT_NAME} --region ${AWS_DEFAULT_REGION} -p "docker" --profile ${AWS_PROFILE}
ENV_CHECK=$(eb list --profile ${AWS_PROFILE} | grep $EB_ENVIRONMENT_NAME || echo 'NOT_CREATED')

if [[ "$ENV_CHECK" == 'NOT_CREATED' ]]; then
    echo "Creating beanstalk environment :: ${EB_ENVIRONMENT_NAME}"
    eb create ${EB_ENVIRONMENT_NAME} -i ${BACKEND_INSTANCE_TYPE} --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE}
else
    echo "Deploying on beanstalk environment :: ${EB_ENVIRONMENT_NAME}"
    eb use ${EB_ENVIRONMENT_NAME} --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE}
    eb deploy ${EB_ENVIRONMENT_NAME} -l "$(date "+%Y%m%d-%H%M%S")-$(uuidgen)" --staged --region ${AWS_DEFAULT_REGION} --profile ${AWS_PROFILE}
fi

cd $CWD

source ./scripts/run-cdn-deploy.sh