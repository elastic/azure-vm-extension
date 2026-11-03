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

Automatic upgrade recovery supports **DEB and RPM installations**. If an old
handler's uninstall fails, Azure can continue to the new handler, which retries
local cleanup before installing dependencies. Recovery applies to any reported
old-uninstaller failure, including the 1.2 failure caused by a missing
`/etc/elastic-agent/fleet.yml`. It does not modify the old handler or create a
replacement configuration file. A failed disable or failed cleanup stops the
upgrade.

On other package types, recovery returns an error before attempting cleanup.
It does not invoke the archive installation's interactive uninstall command.
Fresh installations and the existing ordinary-uninstall path are outside this
recovery restriction.

The Azure Linux Agent must support `continueOnUpdateFailure` and provide
`AZURE_GUEST_AGENT_DISABLE_CMD_EXIT_CODE` and
`AZURE_GUEST_AGENT_UNINSTALL_CMD_EXIT_CODE`. Recovery was validated with agent
**2.16.0.2**; this is a tested version, not a claim about the earliest compatible
release. Agents exposing only the older `AZURE_GUEST_AGENT_*_FAILED` variables
are not supported by this recovery flow. In the tested agent, a skipped
uninstall is passed to install as `NOT_RUN`; a skipped disable can be `None`.
The handler also accepts `None` defensively for a skipped uninstall. This does
not bypass cleanup already required by a pending recovery marker.

DEB/RPM cleanup stops the service before package removal and tolerates an agent
or inactive service that is already absent. Genuine service, package-manager,
or filesystem errors still fail cleanup after retries, including during
ordinary extension deletion. A marker in the new handler's directory preserves
required recovery across install attempts and is cleared after cleanup succeeds.
On Ubuntu 22.04.5, direct `dpkg -r` and `dpkg -P` calls for a uniquely named,
never-installed package both returned 0 with warnings; `dpkg-query` confirmed
that the package was unknown before and after these calls.
Recovery uses the ordinary local uninstaller, so its failure propagation and
retry-safe DEB/RPM cleanup are part of the recovery change.

Recovery removes the previous agent installation. The enable step then installs
and enrolls the agent, so the upgrade request must include valid configuration
and credentials. Collection is interrupted during this process, and the old
Fleet record may remain because local cleanup does not unenroll it. Recovery
does not preflight re-enrollment or provide rollback if the subsequent enable
operation fails.

Release validation requires a newly published candidate containing these
changes. Check fresh installation, upgrade from healthy 1.2, recovery from a
failed 1.2 upgrade, and extension deletion, including Azure status, Fleet
connectivity, fresh telemetry, and package/service removal. Direct handler tests
on Ubuntu 22.04.5 and RHEL 9.6 with Agent 8.19.24 cover missing-agent cleanup,
real package removal, recovery retries, and an injected partial DEB purge
failure. They do not replace the published-candidate lifecycle check. The
Portal's version selection and **Sending** label are separate investigations.

### Linux installation examples

Example installation from CLI:
```
 az vm extension set -n ElasticAgent.linux --publisher Elastic --version {version number} --vm-name "{resource name}" --resource-group "{resource group name}" --protected-settings '{\"password\":\"{elastic password}\"}' --settings '{\"username\":\"{elastic username}\",\"cloudId\":\"{elastic cloud ID}\"}'
```

API key authentication:
```
 az vm extension set -n ElasticAgent.linux --publisher Elastic --version {version number} --vm-name "{resource name}" --resource-group "{resource group name}" --protected-settings @protected-settings.json --settings '{\"cloudId\":\"{elastic cloud ID}\"}'
```
