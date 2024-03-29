
SHELL=/bin/bash -o pipefail
CURRENT_UID := $(shell id -u)
CURRENT_GID := $(shell id -g)
DOCKER_IMAGE=docker.elastic.co/observability-ci/azure-vm-tools

.PHONY: help
.DEFAULT_GOAL := help
help: ## Display this help text
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: prepare
prepare:  ## Prepare the dependencies to run the tools
	@docker build --tag $(DOCKER_IMAGE) -f docker/azure-vm-tools/Dockerfile .

terraform-%:  ## Run the terraform action
ifndef TF_VAR_username
	@echo "Please set TF_VAR_username in the environment to generate the extension"
	exit 1
endif
ifndef TF_VAR_password
	@echo "Please set TF_VAR_password in the environment to generate the extension"
	exit 1
endif
ifndef TF_VAR_cloudId
	@echo "Please set TF_VAR_cloudId in the environment to generate the extension"
	exit 1
endif
ifndef TF_VAR_prefix
	@echo "Please set TF_VAR_prefix in the environment to generate the extension"
	exit 1
endif
ifndef TF_VAR_sku
	@echo "Please set TF_VAR_sku in the environment to generate the VM"
	exit 1
endif
ifndef TF_VAR_publisher
	@echo "Please set TF_VAR_publisher in the environment to generate the VM"
	exit 1
endif
ifndef TF_VAR_offer
	@echo "Please set TF_VAR_offer in the environment to generate the VM"
	exit 1
endif
ifndef TF_VAR_vmName
	@echo "Please set TF_VAR_vmName in the environment to generate the extension"
	exit 1
endif
ifndef TF_VAR_isWindows
	@echo "Please set TF_VAR_isWindows in the environment to generate the extension"
	exit 1
endif
ifndef AZ_USERNAME
	@echo "Please set AZ_USERNAME in the environment to generate the extension"
	exit 1
endif
ifndef AZ_PASSWORD
	@echo "Please set AZ_PASSWORD in the environment to generate the extension"
	exit 1
endif
ifndef AZ_TENANT
	@echo "Please set AZ_TENANT in the environment to generate the extension"
	exit 1
endif
ifndef AZ_SUBSCRIPTION
	@echo "Please set AZ_SUBSCRIPTION in the environment to generate the extension"
	exit 1
endif
	@docker run --rm -t \
		--volume "$(PWD)":/app \
		--workdir /app \
		--env TF_VAR_username="$(TF_VAR_username)" \
		--env TF_VAR_password="$(TF_VAR_password)" \
		--env TF_VAR_cloudId="$(TF_VAR_cloudId)" \
		--env TF_VAR_prefix="$(TF_VAR_prefix)" \
		--env TF_VAR_vmName="$(TF_VAR_vmName)" \
		--env TF_VAR_isWindows="$(TF_VAR_isWindows)" \
		--env TF_VAR_sku="$(TF_VAR_sku)" \
		--env TF_VAR_publisher="$(TF_VAR_publisher)" \
		--env TF_VAR_offer="$(TF_VAR_offer)" \
		--env AZ_USERNAME="$(AZ_USERNAME)" \
		--env AZ_PASSWORD="$(AZ_PASSWORD)" \
		--env AZ_TENANT="$(AZ_TENANT)" \
		--env AZ_SUBSCRIPTION="$(AZ_SUBSCRIPTION)" \
		--env TYPE=$* \
		--env HOME=/app \
		-u $(CURRENT_UID):$(CURRENT_GID) \
		$(DOCKER_IMAGE)


terraform-debug:  ## Debug the terraform plan

terraform-destroy:  ## Destroy the terraform plan

terraform-run:  ## Run the terraform plan

validate:  ## Validate the VM extension
ifndef ES_USERNAME
	@echo "Please set ES_USERNAME in the environment to test the extension"
	exit 1
endif
ifndef ES_PASSWORD
	@echo "Please set ES_PASSWORD in the environment to test the extension"
	exit 1
endif
ifndef ES_URL
	@echo "Please set ES_URL in the environment to test the extension"
	exit 1
endif
ifndef VM_NAME
	@echo "Please set VM_NAME in the environment to test the extension"
	exit 1
endif
ifndef TF_VAR_isWindows
	@echo "Please set TF_VAR_isWindows in the environment to test the extension"
	exit 1
endif
	@docker run --rm -t \
		--volume "$(PWD)":/app \
		--workdir /app \
		--env ES_USERNAME="$(ES_USERNAME)" \
		--env ES_PASSWORD="$(ES_PASSWORD)" \
		--env ES_URL="$(ES_URL)" \
		--env VM_NAME="$(VM_NAME)" \
		--env TF_VAR_isWindows="$(TF_VAR_isWindows)" \
		--env TYPE=test \
		--env HOME=/app \
		-u $(CURRENT_UID):$(CURRENT_GID) \
		$(DOCKER_IMAGE)

create-cluster:  ## Create a cluster in the cloud
ifndef CLUSTER_NAME
	@echo "Please set CLUSTER_NAME in the environment to create the cluster"
	exit 1
endif
	CLUSTER_NAME=$(CLUSTER_NAME) ../test/deployment/deployment.sh 'create'

destroy-cluster:  ## Destroy the cluster in the cloud
ifndef CLUSTER_NAME
	@echo "Please set CLUSTER_NAME in the environment to destroy the cluster"
	exit 1
endif
	CLUSTER_NAME=$(CLUSTER_NAME) ../test/deployment/deployment.sh 'destroy'
