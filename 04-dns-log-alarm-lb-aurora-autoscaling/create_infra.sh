#!/bin/bash


if [ -z "$1" ]
then
    echo "Please specify the name for service"
    echo "    Usage. ${0} [NAME_OF_SERVICE]"
    exit
fi

set -x
SERVICE_NAME=$1
echo "Creating infrastructure on AWS for Wordpress: ${SERVICE_NAME}"
terraform init -reconfigure -backend-config=backend.config -backend-config=key=ex04/terraform-state/$SERVICE_NAME
terraform apply -var service-name=$SERVICE_NAME -var aws-region=us-east-1
set +x
