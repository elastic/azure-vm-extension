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
| 1.3.1.0 | 7.13.0 or later |
| 1.3.0.0 | 7.13.0 or later |
| 1.2.0.0 | 7.13.0 or later |
| 1.1.1.0 | 7.13.0 or later |
| 1.1.0.0 | 7.13.0 or later |
| 1.0.0.0 | 7.13.0 or later |

## Configuration

For a successful installation the following configuration settings are required:

Public settings:
 - cloudId - the elastic cloud ID (deployment ID)
 - username - a valid username that can access the elastic cloud cluster (only required for username/password authentication)

Protected settings:
 - apiKey - the encoded value returned by the Elasticsearch create API key API
 - password - a valid password used with the username public setting
 - base64Auth - base64-encoded `username:password` credentials

The extension prefers `apiKey` when present and falls back to the existing
username/password or `base64Auth` Basic authentication settings. The API key
requires the Elasticsearch `monitor` cluster privilege and Kibana Fleet `All`
privilege.

## Managing the Elastic Agent VM extensions

The Elastic Agent VM extensions can be managed using the Azure CLI, PowerShell, Resource Manager templates, and in the future the Azure portal.

For Windows Azure VM's users will need to install the ElasticAgent.windows VM extension.

Example installation from CLI:
```
 az vm extension set -n ElasticAgent.windows --publisher Elastic --version {version number} --vm-name "{resource name}" --resource-group "{resource group name}" --protected-settings '{\"password\":\"{elastic password}\"}' --settings '{\"username\":\"{elastic username}\",\"cloudId\":\"{elastic cloud ID}\"}'
```

API key authentication:

Store `{"apiKey":"<encoded API key>"}` in a permission-restricted
`protected-settings.json` file rather than placing the secret in shell history.

```
 az vm extension set -n ElasticAgent.windows --publisher Elastic --version {version number} --vm-name "{resource name}" --resource-group "{resource group name}" --protected-settings @protected-settings.json --settings '{\"cloudId\":\"{elastic cloud ID}\"}'
```

For Linux based VM's users will need to install the ElasticAgent.linux VM extension.

### Linux extension upgrades

The Linux handler allows Azure to continue after an older handler's uninstall
fails, then retries local cleanup using the new handler before installing
dependencies. This handles the 1.2 failure caused by a missing
`/etc/elastic-agent/fleet.yml` without modifying the old handler or creating a
replacement configuration file. A failed disable or failed cleanup still stops
the upgrade.

Recovery removes the previous agent installation. The enable step then installs
and enrolls the agent, so the upgrade request must include valid configuration
and credentials. Collection is interrupted during this process, and the old
Fleet record may remain because local cleanup does not unenroll it.

This behavior requires a newly published extension containing the fix; upgrading
to the existing 1.4 package does not provide it. Before release, validate an
upgrade from 1.2 with Agent 8.19.24 on Ubuntu 22.04, including Azure status, Fleet
connectivity and fresh logs and metrics. The Portal's version selection and
**Sending** label are separate from this handler recovery.

### Linux installation examples

Example installation from CLI:
```
 az vm extension set -n ElasticAgent.linux --publisher Elastic --version {version number} --vm-name "{resource name}" --resource-group "{resource group name}" --protected-settings '{\"password\":\"{elastic password}\"}' --settings '{\"username\":\"{elastic username}\",\"cloudId\":\"{elastic cloud ID}\"}'
```

API key authentication:
```
 az vm extension set -n ElasticAgent.linux --publisher Elastic --version {version number} --vm-name "{resource name}" --resource-group "{resource group name}" --protected-settings @protected-settings.json --settings '{\"cloudId\":\"{elastic cloud ID}\"}'
```
