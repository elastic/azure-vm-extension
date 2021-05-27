#!/usr/bin/env bash
set -eo pipefail

echo "What azure version?"
az version

az login \
	--service-principal \
	--username "${AZ_USERNAME}" \
	--password "${AZ_PASSWORD}" \
	--tenant "${AZ_TENANT}" > /dev/null

echo "Prepare the terraform env variables"
# See https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret
export ARM_CLIENT_ID="${AZ_USERNAME}"
export ARM_CLIENT_SECRET="${AZ_PASSWORD}"
export ARM_SUBSCRIPTION_ID="${AZ_SUBSCRIPTION}"
export ARM_TENANT_ID="${AZ_TENANT}"

echo "Go to the terraform folder"
cd test/terraform
if [ "${TYPE}" == "run" ] ; then
	echo "Configure the terraform environment"
	terraform init

	echo "Validate the terraform plan"
	terraform plan

	echo "Prepare the VM and enable the VM extension"
	TF_VAR_username="${TF_VAR_username}" \
	TF_VAR_password="${TF_VAR_password}" \
	TF_VAR_cloudId="${TF_VAR_cloudId}" \
	TF_VAR_prefix="${TF_VAR_prefix}" \
	terraform apply -auto-approve
fi

if [ "${TYPE}" == "destroy" ] ; then
	echo "Destroy"
	TF_VAR_username="${TF_VAR_username}" \
	TF_VAR_password="${TF_VAR_password}" \
	TF_VAR_cloudId="${TF_VAR_cloudId}" \
	TF_VAR_prefix="${TF_VAR_prefix}" \
	terraform destroy -auto-approve
fi
