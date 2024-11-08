# openmrs-contrib-cluster
Contains terraform and helm charts to deploy OpenMRS distro in a cluster.

Terraform setup is borrowed from Bahmni https://github.com/Bahmni/bahmni-infra (please see the terraform directory). It has been further adjusted for general use in other OpenMRS distributions.

## Overview

What's been implemented so far?

1. Deploy mariadb primary and replica from bitnami/mariadb helm chart
2. Deploy openmrs backend
3. Deploy openmrs frontend and gateway

What's coming next?

1. Develop terraform to deploy to AWS with RDS or mariadb cluster using helm chart
2. Provide mariadb-galera cluster as an option to deploy. Make changes in the openmrs-core to support mariadb-galera cluster and mariadb read-only replicas.
3. ...

See https://openmrs.atlassian.net/wiki/x/tgBLCw for more details.

## Usage

### Helm

We recommend https://kind.sigs.k8s.io/ for local testing.

Make sure that Docker is running and issue the following command:


      brew install kind
      kind create cluster


How to try it out?


      helm install openmrs oci://registry-1.docker.io/openmrs/openmrs


Once installed you will see instructions on how to configure port-forwarding and access the instance. If you deploy to a cloud provider you will need to configure a load balancer / gateway to point to openmrs-gateway service on port 80.

#### Parameters

##### Global parameters

| Name                      | Description                                                                             | Value   |
| ------------------------- |-----------------------------------------------------------------------------------------|---------|
| `defaultStorageClass`     | Global default StorageClass for Persistent Volume(s)                                    | `"gp2"` |

#### Common parameters

Prepend with the name of the service: `openmrs-backend`, `openmrs-frontend`, `openrms-gateway`, `mariadb`.

| Name                | Description                  | Default Value                                            |
|---------------------|------------------------------|----------------------------------------------------------|
| `.image.repository` | Image to use for the service | `e.g. "openmrs/openmrs-reference-application-3-backend"` |
| `.image.tag`        | Tag to use for the service   | `e.g. "3.0.0"`                                           |


#### OpenMRS-backend parameters

| Name                                        | Description                                                              | Default Value       |
|---------------------------------------------|--------------------------------------------------------------------------|---------------------|
| `openmrs-backend.db.hostname`               | Hostname for OpenMRS DB                                                  | `"mariadb-primary"` |
| `openmrs-backend.persistance.size`          | Size of persistent volume to claim (for search index, attachments, etc.) | `"8Gi"`             |
| `openmrs-backend.mariadb.enabled`           | Create MariaDB with read-only replica                                    | `"true"`            |
| `openmrs-backend.mariadb.auth.rootPassword` | Password for the `root` user. Ignored if existing secret is provided.    | `"true"`            |
| `openmrs-backend.mariadb.auth.database`     | Name for an OpenMRS database                                             | `"openmrs"`         |
| `openmrs-backend.mariadb.auth.username`     | Name for a DB user                                                       | `"openmrs"`         |
| `openmrs-backend.mariadb.auth.password`     | Name for a DB user's password                                            | `"OpenMRS123"`      |

See [MariaDB](https://github.com/bitnami/charts/blob/main/bitnami/mariadb/README.md) helm chart for other MariaDB parameters.

### Terraform and AWS

#### Setting up terraform and AWS

1. Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)


      brew install tfenv 
      tfenv install 1.9.5


2. Install [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)


      brew install awscli
      aws configure


#### Initialize Terraform backend (one time operation)

To Initialize terraform backend run:


      cd terraform-backend
      terraform init
      terraform apply
      cd ..

#### Running Terraform (AWS only)


1. Deploy the cluster and supporting services


      cd terraform/
      terraform init
      terraform apply -var-file=nonprod.tfvars


2. Run helm


      aws eks update-kubeconfig --name openmrs-cluster-nonprod
      helm install openmrs oci://registry-1.docker.io/openmrs/openmrs


## Development Setup

### Setting up pre-commit hooks

This is a one-time setup that needs to be run only when the repo is cloned.
1. Install [pre-commit](https://pre-commit.com/#install)


      brew install pre-commit


2. Install pre-commit dependencies

    - [terrascan](https://github.com/accurics/terrascan)
    - [tfsec](https://github.com/aquasecurity/tfsec#installation)
    - [tflint](https://github.com/terraform-linters/tflint#installation)
   

      brew install terrascan tfsec tflint


3. Initialise pre-commit hooks


      pre-commit install --install-hooks


Now before every commit, the hooks will be executed.

## Directory Structure
```
helm                              # helm charts
terraform                         # terraform setup
├── ...
├── aws
├── ├── policies                  # aws custom policies
├── ├── roles                     # aws custom roles
├── terraform
|   |── modules                   # contains reusable resources across environemts
│       ├── vpc
│       ├── eks
│       ├── ....
│   ├── main.tf                   # File where provider and modules are initialized
│   ├── variables.tf
│   ├── nonprod.tfvars            # values for nonprod environment
│   ├── outputs.tf
│   ├── config.s3.tfbackend       # backend config values for s3 backend
└── ...
```
