#!/usr/bin/env bash
set -eo pipefail

## Run ITs in python
if [ "${TYPE}" == "test" ] ; then
    cd test/ats
    python -m xmlrunner validate.py || exit 1
    exit 0
fi

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
	TF_VAR_vmName="${TF_VAR_vmName}" \
	TF_VAR_isWindows="${TF_VAR_isWindows}" \
	TF_VAR_sku="${TF_VAR_sku}" \
	TF_VAR_publisher="${TF_VAR_publisher}" \
	TF_VAR_offer="${TF_VAR_offer}" \
	terraform apply -auto-approve
fi

if [ "${TYPE}" == "debug" ] ; then
	echo "debug"
	TF_VAR_prefix="${TF_VAR_prefix}" \
	TF_VAR_vmName="${TF_VAR_vmName}" \
	TF_VAR_isWindows="${TF_VAR_isWindows}" \
	TF_VAR_sku="${TF_VAR_sku}" \
	TF_VAR_publisher="${TF_VAR_publisher}" \
	TF_VAR_offer="${TF_VAR_offer}" \
	terraform output -auto-approve
	RESOURCE_GROUP=$(jq -r '.outputs.resource_group_name.value' terraform.tfstate)

	if [ "${TF_VAR_isWindows}" == "false" ] ; then
		az vm run-command invoke \
			-g $RESOURCE_GROUP \
			-n "${TF_VAR_vmName}" \
			--command-id RunShellScript \
			--scripts 'echo $1 $2' \
			--parameters hello world
	else
		echo 'TBD'
	fi
fi

if [ "${TYPE}" == "destroy" ] ; then
	echo "Destroy"
	TF_VAR_username="${TF_VAR_username}" \
	TF_VAR_password="${TF_VAR_password}" \
	TF_VAR_cloudId="${TF_VAR_cloudId}" \
	TF_VAR_prefix="${TF_VAR_prefix}" \
	TF_VAR_vmName="${TF_VAR_vmName}" \
	TF_VAR_isWindows="${TF_VAR_isWindows}" \
	TF_VAR_sku="${TF_VAR_sku}" \
	TF_VAR_publisher="${TF_VAR_publisher}" \
	TF_VAR_offer="${TF_VAR_offer}" \
	terraform destroy -auto-approve
fi
