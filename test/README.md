# Test

## terraform folder

How to test this particular extension using terraform.

## ats folder

Run the Acceptance Tests for this particular extension.

## Linux upgrade regression tests

Run `python3 -B -m unittest discover -s test/upgrade -v` from the repository root.
The tests require Bash and the local Git tag `1.2.0.0`. They replay the old
disable/uninstall scripts, the current update/install cleanup and the enable
path with host operations and Fleet requests mocked. They do not use credentials
or modify an installed agent.

The lifecycle follows the Azure Linux Agent's
[`_update_extension_handler_and_return_if_failed`](https://github.com/Azure/WALinuxAgent/blob/master/azurelinuxagent/ga/exthandlers.py):
disable old, update new, uninstall old, install new, then enable new. The new
manifest's `continueOnUpdateFailure` flag permits recovery after the old
uninstall fails; `AZURE_GUEST_AGENT_UNINSTALL_CMD_EXIT_CODE` identifies that
failure to the install command. A real Azure upgrade remains a release check.
