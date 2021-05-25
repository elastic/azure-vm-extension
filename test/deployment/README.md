# Deployment

This will help to spin up a elastic cloud deployment

```bash
$ VAULT_TOKEN=$(cat "${HOME}/.vault-token") \
    ELASTIC_STACK_VERSION=7.12.0 \
    CLUSTER_NAME=ec-test-azure \
    ./deployment.sh "create"
```

```bash
$ VAULT_TOKEN=$(cat "${HOME}/.vault-token") \
    ELASTIC_STACK_VERSION=7.12.0 \
    CLUSTER_NAME=ec-test-azure \
    ./deployment.sh "destroy"
```


## Credentials

Those credentials details can be found in vault:

```bash
$ id=ec-test-azure
$ vault read secret/observability-team/ci/test-clusters/$id/ec-deployment
```
