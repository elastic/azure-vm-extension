# Ats

This is the folder that contains the Acceptance Tests to validate the Elastic Agent VM extension.

## Requirements

1. Create a Elastic Cloud cluster
2. Run the terraform plan.
3. Install the requirements.txt dependencies defined in .ci/docker/azure-vm-tools/requirements.txt

## How does it work?

1. Run the below script in your terminal to test the install for the given VM in the given cloud environment.

```bash
$ ES_USERNAME=<ES_USERNAME> \
  ES_PASSWORD=<ES_PASSWORD> \
  ES_URL=<ES_URL> \
  VM_NAME=<VM_NAME> \
  TF_VAR_isWindows=<TF_VAR_isWindows> \
  python -m xmlrunner validate.py
```

2. Run the below script in your terminal to test the uninstall for the given VM in the given cloud environment.

```bash
$ ES_USERNAME=<ES_USERNAME> \
  ES_PASSWORD=<ES_PASSWORD> \
  ES_URL=<ES_URL> \
  VM_NAME=<VM_NAME> \
  TF_VAR_isWindows=<TF_VAR_isWindows> \
  python -m xmlrunner validate-uninstall.py
```
