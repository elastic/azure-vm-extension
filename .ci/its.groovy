#!/usr/bin/env groovy
// Licensed to Elasticsearch B.V. under one or more contributor
// license agreements. See the NOTICE file distributed with
// this work for additional information regarding copyright
// ownership. Elasticsearch B.V. licenses this file to you under
// the Apache License, Version 2.0 (the "License"); you may
// not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
@Library('apm@current') _

import groovy.transform.Field

// VM names created to run later on the terraform plan
// key is the cluster name and value is the VM name
@Field def vms = [:]

pipeline {
  agent none
  environment {
    REPO = "azure-vm-extension"
    NOTIFY_TO = credentials('notify-to')
    PIPELINE_LOG_LEVEL = 'INFO'
    LANG = "C.UTF-8"
    LC_ALL = "C.UTF-8"
  }
  options {
    buildDiscarder(logRotator(numToKeepStr: '5', artifactNumToKeepStr: '5', daysToKeepStr: '7'))
    timestamps()
    ansiColor('xterm')
    disableResume()
    durabilityHint('PERFORMANCE_OPTIMIZED')
    timeout(time: 2, unit: 'HOURS')
    disableConcurrentBuilds()
  }
  triggers {
    cron("${(env.BRANCH_NAME.trim() == 'master') 'H H(5-6) * * 1-5' ? ''}")
  }
  parameters {
    booleanParam(name: 'skipDestroy', defaultValue: "false", description: "Whether to skip the destroy of the cluster and terraform.")
  }
  stages {
    stage('ITs') {
      options { skipDefaultCheckout() }
      failFast false
      matrix {
        agent { label 'ubuntu-20' }
        axes {
          axis {
            name 'STACK_VERSION'
            // The below line is part of the bump release automation
            // if you change anything please modifies the file
            // .ci/bump-stack-release-version.sh
            values '8.0.0-SNAPSHOT', '7.x', '7.13.2'
          }
        }
        environment {
          HOME = "${env.WORKSPACE}"
          PATH = "${env.HOME}/bin:${env.PATH}"
        }
        stages {
          stage('Checkout'){
            steps {
              deleteDir()
              checkout scm
            }
          }
          stage('Create cluster'){
            options { skipDefaultCheckout() }
            steps {
              withGithubNotify(context: "Create Cluster ${ELASTIC_STACK_VERSION}") {
                withVaultEnv(){
                  sh(label: 'Deploy Cluster', script: 'make -C .ci create-cluster')
                }
              }
            }
            post {
              failure {
                destroyCluster()
              }
            }
          }
          stage('Prepare tools') {
            options { skipDefaultCheckout() }
            steps {
              withCloudEnv() {
                sh(label: 'Prepare tools', script: 'make -C .ci prepare')
              }
            }
            post {
              failure {
                destroyCluster()
              }
            }
          }
          stage('Terraform') {
            options { skipDefaultCheckout() }
            steps {
              withGithubNotify(context: "Terraform ${ELASTIC_STACK_VERSION}") {
                withCloudEnv() {
                  withAzEnv() {
                    sh(label: 'Run terraform plan', script: 'make -C .ci terraform-run')
                  }
                }
              }
            }
            post {
              failure {
                destroyTerraform()
                destroyCluster()
              }
            }
          }
          stage('Validate') {
            options { skipDefaultCheckout() }
            steps {
              withGithubNotify(context: "Validate ${ELASTIC_STACK_VERSION}") {
                withValidationEnv() {
                  sh(label: 'Validate', script: 'make -C .ci validate')
                }
              }
            }
            post {
              always {
                destroyTerraform()
                destroyCluster()
              }
            }
          }
        }
      }
    }
  }
  post {
    cleanup {
      notifyBuildResult(prComment: true)
    }
  }
}

def destroyCluster( ) {
  if (params.skipDestroy) {
    echo 'Skipped the destroy cluster step'
    return
  }
  withVaultEnv(){
    sh(label: 'Destroy Cluster', script: 'make -C .ci destroy-cluster')
  }
}

def destroyTerraform( ) {
  if (params.skipDestroy) {
    echo 'Skipped the destroy terraform step'
    return
  }
  withCloudEnv() {
    withAzEnv() {
      sh(label: 'Destroy terraform plan', script: 'make -C .ci terraform-destroy')
    }
  }
}

def withVaultEnv(Closure body){
  getVaultSecret.readSecretWrapper {
    withMatrixEnv() {
      withEnvMask(vars: [
        [var: 'VAULT_ADDR', password: env.VAULT_ADDR],
        [var: 'VAULT_ROLE_ID', password: env.VAULT_ROLE_ID],
        [var: 'VAULT_SECRET_ID', password: env.VAULT_SECRET_ID],
        [var: 'VAULT_AUTH_METHOD', password: 'approle'],
        [var: 'VAULT_AUTHTYPE', password: 'approle']
      ]){
        body()
      }
    }
  }
}

def withValidationEnv(Closure body) {
  withMatrixEnv() {
    withClusterEnv(cluster: env.CLUSTER_NAME) {
      body()
    }
  }
}

def withCloudEnv(Closure body) {
  withMatrixEnv() {
    withCloudEnv(cluster: env.CLUSTER_NAME) {
      // withCloudEnv creates different env variables, let's create the
      // ones needed for the terraform runs
      withEnvMask(vars: [
        [var: 'TF_VAR_username', password: env.CLOUD_USERNAME],
        [var: 'TF_VAR_password', password: env.CLOUD_PASSWORD],
        [var: 'TF_VAR_cloudId', password: env.CLOUD_ID]
      ]){
        body()
      }
    }
  }
}

def withAzEnv(Closure body) {
  withMatrixEnv() {
    withAzureEnv(secret: 'secret/observability-team/ci/service-account/azure-vm-extension') {
      body()
    }
  }
}

def withMatrixEnv(Closure body) {
  def vmName = getCachedVmNameOrAssignVmName(clusterName)
  def stackVersion = (env.STACK_VERSION == '7.x') ? artifactsApi(action: '7.x-version') : env.STACK_VERSION
  def clusterName = "tst-az-${BUILD_ID}-${BRANCH_NAME}-${stackVersion}"
  withEnv([
    "CLUSTER_NAME=${clusterName}",
    'TF_VAR_prefix=tst-' + vmName.take(6),
    "TF_VAR_vmName=${vmName}",
    "VM_NAME=${vmName}",
    "ELASTIC_STACK_VERSION=${stackVersion}"
  ]) {
    echo "CLUSTER_NAME=${CLUSTER_NAME} - VM_NAME=${VM_NAME} - TF_VAR_prefix=${TF_VAR_prefix}"
    body()
  }
}

def getCachedVmNameOrAssignVmName(String key) {
  if (vms.containsKey(key)) {
    return vms.get(key)
  } else {
    def vmName = randomString(size: 15)
    vms[key] = vmName
    return vmName
  }
}
