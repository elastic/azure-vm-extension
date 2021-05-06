# Terraform

This is the folder that contains the terraform definition to create a windows intance with the Elastic Agent VM extension.

## Requirements

1. Install `azure-cli` and `terraform`.
2. Run `az login` to login in Azure and enable the CLI tools.

## Create a Elastic Cloud cluster

1. Create the ECE cluster
1. Save the username, password and deployment ID.
1. Those will be used later one.

## How does it work?

1. Run `terraform init` in your terminal to configure the terraform environment.
1. Run `terraform plan` in your terminal to validate the terraform plan is valid.
1. Run the below script in your terminal to prepare the VM and enable the VM extension, you need to answer the prompt questions.
```bash
$ TF_VAR_username=**** \
  TF_VAR_password=*** \
  TF_VAR_cloudId=**** \
  terraform apply
```
4. If everything works as expected then the VM will be created in Azure and you can destory the plan with `terraform destroy`.

