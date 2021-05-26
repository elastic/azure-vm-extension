
SHELL=/bin/bash -o pipefail
CURRENT_UID := $(shell id -u)
CURRENT_GID := $(shell id -g)

.PHONY: help
.DEFAULT_GOAL := help
help: ## Display this help text
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'


.PHONY: prepare-tool
prepare-tool:  ## Prepare the dependencies to run the tools
	@docker build --tag tools -f docker/tools/Dockerfile .

run-terraform:  ## Run the terraform
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
	@docker run --rm -t \
		--volume "$(PWD)":/app \
		--workdir /app \
		--env TF_VAR_username=$(TF_VAR_username) \
		--env TF_VAR_password=$(TF_VAR_password) \
		--env TF_VAR_cloudId=$(TF_VAR_cloudId) \
		--env CREATE=true \
		-u $(CURRENT_UID):$(CURRENT_GID) \
		tools

destroy-terraform:  ## Destroy the terraform
ifndef TF_VAR_username
	@echo "Please set TF_VAR_username in the environment to destroy"
	exit 1
endif
ifndef TF_VAR_password
	@echo "Please set TF_VAR_password in the environment to destroy"
	exit 1
endif
ifndef TF_VAR_cloudId
	@echo "Please set TF_VAR_cloudId in the environment to destroy"
	exit 1
endif
	@docker run --rm -t \
		--volume "$(PWD)":/app \
		--workdir /app \
		--env TF_VAR_username=$(TF_VAR_username) \
		--env TF_VAR_password=$(TF_VAR_password) \
		--env TF_VAR_cloudId=$(TF_VAR_cloudId) \
		--env DESTROY=true \
		-u $(CURRENT_UID):$(CURRENT_GID) \
		tools

validate:  ## Validate the VM extension
	echo 'TBD'

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
