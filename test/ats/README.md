# Ats

This is the folder that contains the Acceptance Tests to validate if the Elastic Agent VM extension.

## Requirements

1. Create a Elastic Cloud cluster
2. Run the terraform plan.

## How does it work?

1. Run the below script in your terminal to test the given VM in the given cloud environment.
```bash
$ validate.sh <ES_USERNAME> <ES_PASSWORD> <ES_URL> <VM_ID> <VM_NAME>
```
