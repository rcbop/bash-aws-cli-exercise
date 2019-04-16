#!/usr/bin/env bash

if ! command -v pip3; then
    echo 'please install pip3'
    exit 1
fi

if ! command -v jq; then
    echo 'please install jq'
    exit 1
fi

if ! command -v aws; then
    echo 'installing awscli'
    pip3 install awscli
fi

if ! command -v awsebcli; then
    echo 'installing elastic beanstalk cli'
    pip3 install awsebcli
fi

aws configure --profile default