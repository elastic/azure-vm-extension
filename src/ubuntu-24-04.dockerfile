FROM jrei/systemd-ubuntu:24.04 AS vm_extension_ubuntu

RUN apt-get update && apt-get -y install sudo wget
WORKDIR /sln

COPY ./handler ./handler
COPY settings ./tests

