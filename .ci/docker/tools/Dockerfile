FROM python:3.9.5-slim

RUN pip3 install azure-cli

RUN apt-get update && \
	apt-get install -y gnupg software-properties-common curl && \
	curl -fsSL https://apt.releases.hashicorp.com/gpg |  apt-key add - && \
	apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

RUN apt-get update && \
	apt-get install terraform

WORKDIR /app

ENTRYPOINT [ "/app/.ci/docker/tools/entrypoint.sh" ]
