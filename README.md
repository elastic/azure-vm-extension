# Elastic Agent VM extension

The ElasticAgent VM extension is a small application that provides post-deployment configuration and automation on Azure VMs.
Once installed, it will download the elastic agent artifacts, install the elastic agent on the virtual machine, enroll it to Fleet and then start the agent service.


## Platforms supported

| Platform | Version      |
|----------|--------------|
| Windows  | 2008r2 +     |
| Centos   | 6.10+         |
| Debian   | 9,10         |
| Oracle   | 6.8+         |
| RHEL     | 6+           |
| Ubuntu   | 16+          |



The Elastic Agent VM extension can be managed using the Azure CLI, PowerShell, Resource Manager templates, and in the future the Azure portal.

## Configuration

For a successful installation the following configuration settings are required:

Public settings:
 - username - a valid username that can have access to the elastic cloud cluster
 - cloudId - the elastic cloud ID (deployment ID)

Protected settings:
 - password - a valid password that can be used in combination with the username public setting to access the elastic cloud cluster


## Managing the Elastic Agent VM extension

The Elastic Agent VM extension can be managed using the Azure CLI, PowerShell, Resource Manager templates, and in the future the Azure portal.

Example installation from CLI:
```
 az vm extension set -n ElasticAgent.windows --publisher Elastic --version 1.0.0.0 --vm-name "{resource name}" --resource-group "{resource group name}" --protected-settings '{\"password\":\"{elastic password}\"}' --settings '{\"username\":\"{elastic username}\",\"cloudId\":\"{elastic cloud ID}\"}'
```
