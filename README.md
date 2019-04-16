# Employees RestAPI Deployment

Exercise deployment of a RestAPI using AWS CLI and AWS ElasticBeanstalk CLI with bash scripts.

## Requirements

* docker
* docker-compose
* python3
* python3-pip
* git
* jq
* bash


## Local Deployment

```bash
./run-local-deploy.sh
```

## AWS deployment

### Run setup

1. Run setup script
2. Install any dependencies missing
3. Input your AWS credentials (AWS_SECRET_KEY_ID, AWS_SECRET_ACCESS_KEY), default region
4. Set default output to 'json'

```bash
./scripts/setup-aws-tools.sh
```

### Run deployment script

```bash
export AWS_ACCOUNT_ID=<YOUR_ACCOUNT_ID>
# start with bash -x to debug issues
./run-aws-deploy.sh
```

Wait for the deployment script to complete and then

wait for AWS Cloudfront distribution to propagate checking the web console or altenatively using command:

```bash
aws cloudfront wait distribution-deployed --id ${AWS_CLOUDFRONT_ID}
```

and then run route53 script to create the DNS record set alias targeting the cloudfront distribution

```bash
./scripts/run-route53-dns.sh
```

### Infra overview

![infra-overview](docs/aws-blueprint.png)


