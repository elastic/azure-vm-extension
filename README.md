# Elastic Agent VM extensions

ElasticAgent.windows for Windows systems
ElasticAgent.linux for Linux systems

The ElasticAgent VM extensions are small applications that provide post-deployment configuration and automation on Azure VMs.
Once installed, the ElasticAgent VM extension will download the Elastic Agent artifacts, install the Elastic Agent on the virtual machine, enroll it to Fleet and then start the agent service.


## Platforms supported

| Platform | Version      |
|----------|--------------|
| Windows  | 2008r2 +     |
| Centos   | 6.10+         |
| Debian   | 9,10         |
| Oracle   | 6.8+         |
| RHEL     | 7+           |
| Ubuntu   | 16+          |

## Elastic Cloud dependency

To automate the installation and configuration of the Elastic Agent, the Azure VM extension code makes several API calls which requires specific Elastic stack version.

| VM extension version | Elastic Cloud dependency      |
|----------|--------------|
| 1.2.0.0 | 7.13.0 or later |
| 1.1.1.0 | 7.13.0 or later |
| 1.1.0.0 | 7.13.0 or later |
| 1.0.0.0 | 7.13.0 or later |

## Configuration

For a successful installation the following configuration settings are required:

Public settings:
 - username - a valid username that can have access to the elastic cloud cluster
 - cloudId - the elastic cloud ID (deployment ID)

Protected settings:
 - password - a valid password that can be used in combination with the username public setting to access the elastic cloud cluster


## Managing the Elastic Agent VM extensions

The Elastic Agent VM extensions can be managed using the Azure CLI, PowerShell, Resource Manager templates, and in the future the Azure portal.

For Windows Azure VM's users will need to install the ElasticAgent.windows VM extension.

Example installation from CLI:
```
 az vm extension set -n ElasticAgent.windows --publisher Elastic --version {version number} --vm-name "{resource name}" --resource-group "{resource group name}" --protected-settings '{\"password\":\"{elastic password}\"}' --settings '{\"username\":\"{elastic username}\",\"cloudId\":\"{elastic cloud ID}\"}'
```

For Linux based VM's users will need to install the ElasticAgent.linux VM extension.

Example installation from CLI:
```
 az vm extension set -n ElasticAgent.linux --publisher Elastic --version {version number} --vm-name "{resource name}" --resource-group "{resource group name}" --protected-settings '{\"password\":\"{elastic password}\"}' --settings '{\"username\":\"{elastic username}\",\"cloudId\":\"{elastic cloud ID}\"}'
```
