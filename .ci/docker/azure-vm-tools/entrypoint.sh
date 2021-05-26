#!/usr/bin/env bash
set -eo pipefail

echo "What azure version?"
az version

az login \
	--service-principal \
	--username "${AZ_USERNAME}" \
	--password "${AZ_PASSWORD}" \
	--tenant "${AZ_TENANT}" --only-show-errors

echo "Go to the terraform folder"
cd test/terraform
if [ "${CREATE}" == "true" ] ; then
	echo "Configure the terraform environment"
	terraform init

	echo "Validate the terraform plan"
	terraform plan

	echo "Prepare the VM and enable the VM extension"
	TF_VAR_username="${TF_VAR_username}" \
	TF_VAR_password="${TF_VAR_password}" \
	TF_VAR_cloudId="${TF_VAR_cloudId}" \
	terraform apply
fi

if [ "${DESTROY}" == "true" ] ; then
	echo "Destroy"
	TF_VAR_username="${TF_VAR_username}" \
	TF_VAR_password="${TF_VAR_password}" \
	TF_VAR_cloudId="${TF_VAR_cloudId}" \
	terraform destroy
fi
