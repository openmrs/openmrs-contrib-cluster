# openmrs-contrib-cluster
Contains terraform and helm charts to deploy OpenMRS distro in a cluster.

Terraform setup is borrowed from Bahmni https://github.com/Bahmni/bahmni-infra (please see the terraform directory). It has been further adjusted for general use in other OpenMRS distributions.

## Overview

What's been implemented so far?

1. Deploy mariadb primary and replica from bitnami/mariadb helm chart
2. Deploy openmrs backend
3. Deploy openmrs frontend and gateway
4. Deploy to AWS with RDS or mariadb cluster using helm chart
5. Use mariadb-galera cluster as an option to deploy.
6. Deploy ALB with terraform

What's coming next?

1. Make changes in the openmrs-core to support mariadb-galera cluster and mariadb read-only replicas.
2. Deploy Grafana for logging
3. ...

See https://openmrs.atlassian.net/wiki/x/tgBLCw for more details.

## Other options

### AWS

If you intend to deploy on AWS and you are intersted in a solution that runs natively on AWS and is not easily movable to on-prem or any other cloud provider you may want to have a look at https://github.com/openmrs/openmrs-contrib-cluster-aws-ecs It showcases the usage of AWS CDK instead of Terraform for setting up an ECS cluster instead of Kubernetes. It also utilizes AWS Fargate and AWS Aurora managed services for high availability and scalability. 

At this point we did not add support for AWS Fargate and AWS Aurora for Kubernetes deployment as part of our general solution in this repo, but we may do that in the future if there is enough interest or a contribution.

## Usage

### Helm

We recommend https://kind.sigs.k8s.io/ for local testing.

Make sure that Docker is running and issue the following command:


      brew install kind
      cd helm
      kind create cluster --config=kind-config.yaml

      # Set kubectl context to your local kind cluster
      kubectl cluster-info --context kind-kind


How to try it out?

From local source:

      helm install --set global.defaultStorageClass=standard openmrs .

or from registry:

      helm install --set global.defaultStorageClass=standard openmrs oci://registry-1.docker.io/openmrs/openmrs

or if you want to use mariadb-galera cluster instead of mariadb with basic primary-secondary replication:

      helm install --set global.defaultStorageClass=standard --set openmrs-backend.mariadb.enabled=false --set openmrs-backend.galera.enabled=true openmrs oci://registry-1.docker.io/openmrs/openmrs


Once installed you will see instructions on how to configure port-forwarding and access the instance. If you deploy to a cloud provider you will need to configure a load balancer / gateway to point to openmrs-gateway service on port 80.

#### Parameters

##### Global parameters

| Name                      | Description                                                                             | Value   |
| ------------------------- |-----------------------------------------------------------------------------------------|---------|
| `defaultStorageClass`     | Global default StorageClass for Persistent Volume(s)                                    | `"gp2"` |

#### Common parameters

Prepend with the name of the service: `openmrs-backend`, `openmrs-frontend`, `openrms-gateway`, `openmrs-backend.mariadb`, `openmrs-backend.galera`.

| Name                | Description                  | Default Value                                            |
|---------------------|------------------------------|----------------------------------------------------------|
| `.image.repository` | Image to use for the service | `e.g. "openmrs/openmrs-reference-application-3-backend"` |
| `.image.tag`        | Tag to use for the service   | `e.g. "3.0.0"`                                           |


#### OpenMRS-backend parameters

| Name                                                         | Description                                                              | Default Value                                             |
|--------------------------------------------------------------|--------------------------------------------------------------------------|-----------------------------------------------------------|
| `openmrs-backend.db.hostname`                                | Hostname for OpenMRS DB                                                  | `""` or defaults to galera or mariadb hostname if enabled |
| `openmrs-backend.persistance.size`                           | Size of persistent volume to claim (for search index, attachments, etc.) | `"8Gi"`                                                   |
| `openmrs-backend.mariadb.enabled`                            | Create MariaDB with read-only replica                                    | `"true"`                                                  |
| `openmrs-backend.mariadb.primary.persistence.storageClass`   | MariaDB primary persistent volume storage Class                          | `global.defaultStorageClass`                              |
| `openmrs-backend.mariadb.secondary.persistence.storageClass` | MariaDB secondary persistent volume storage Class                        | `global.defaultStorageClass`                              |
| `openmrs-backend.mariadb.auth.rootPassword`                  | Password for the `root` user. Ignored if existing secret is provided.    | `"true"`                                                  |
| `openmrs-backend.mariadb.auth.database`                      | Name for an OpenMRS database                                             | `"openmrs"`                                               |
| `openmrs-backend.mariadb.auth.username`                      | Name for a DB user                                                       | `"openmrs"`                                               |
| `openmrs-backend.mariadb.auth.password`                      | Name for a DB user's password                                            | `"OpenMRS123"`                                            |
| `openmrs-backend.galera.enabled`                             | Create MariaDB Galera cluster with 3 nodes (default)                     | `"true"`                                                  |
| `openmrs-backend.galera.rootUser.password`                   | Password for the `root` user. Ignored if existing secret is provided.    | `"true"`                                                  |
| `openmrs-backend.galera.db.name`                             | Name for an OpenMRS database                                             | `"openmrs"`                                               |
| `openmrs-backend.galera.db.user`                             | Name for a DB user                                                       | `"openmrs"`                                               |
| `openmrs-backend.galera.db.password`                         | Name for a DB user's password                                            | `"OpenMRS123"`                                            |

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

#### Running Terraform


1. Deploy the cluster and supporting services


      cd terraform/
      terraform init
      terraform apply -var-file=nonprod.tfvars


2. Run helm to deploy ALB controller and OpenMRS


      cd terraform-helm/
      terraform init
      terraform apply -var-file=nonprod.tfvars


3. Configure kubectl client to monitor your cluster (optionally)

      
      aws eks update-kubeconfig --name openmrs-cluster-nonprod


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

### Developing Helm Charts

Once you have local or AWS cluster setup (see above) and kubectl is pointing to your cluster you can run helm install 
directly from source. To verify you kubectl is connected to the correct cluster run:


      kubectl cluster-info


If you need to change your kubectl cluster run:


      # For AWS
      aws eks update-kubeconfig --name openmrs-cluster-nonprod
      
      # For local Kind cluster
      kubectl cluster-info --context kind-kind


To install Helm Charts from source run (see above for possible settings):


      cd helm/openmrs
      helm install openmrs .


If you made any changes in helm/openmrs-backend or helm/openmrs-frontend or helm/openmrs-gateway you need to update 
dependencies and run helm upgrade.


      # form helm/openmrs dir
      helm dependency update
      helm upgrade openmrs .

## Directory Structure
```
helm                              # helm charts
terraform-backend                 # terraform AWS backend setup
terraform                         # terraform AWS setup
├── ...
├── aws
├── ├── policies                  # aws custom policies
├── ├── roles                     # aws custom roles
|── modules                       # contains reusable resources across environemts
│   ├── vpc
│   ├── eks
│   ├── ....
│   ├── main.tf                   # File where provider and modules are initialized
│   ├── variables.tf
│   ├── nonprod.tfvars            # values for nonprod environment
│   ├── outputs.tf
│   ├── config.s3.tfbackend       # backend config values for s3 backend
└── ...
terraform-helm                    # terraform Helm installer
```
