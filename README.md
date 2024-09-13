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

## Helm Development Setup

We recommend https://kind.sigs.k8s.io/ for local development.

How to try it out?

``` helm install openmrs oci://registry-1.docker.io/openmrs/openmrs```

Once installed you will see instructions on how to configure port-forwarding and access the instance. If you deploy to a cloud provider you will need to configure a load balancer / gateway to point to openmrs-gateway service on port 80.

## Terraform Development Setup

### Setting up terraform and AWS

1. Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
2. Install [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

   `aws configure`

### Setting up pre-commit hooks

This is a one-time setup that needs to be run only when the repo is cloned.
1. Install [pre-commit](https://pre-commit.com/#install)

    `brew install pre-commit` or `pip install pre-commit`

2. Install pre-commit dependencies

    - [terrascan](https://github.com/accurics/terrascan)
   
      `brew install terrascan`
    - [tfsec](https://github.com/aquasecurity/tfsec#installation) 
      
      `brew install tfsec`
    - [tflint](https://github.com/terraform-linters/tflint#installation)
   
      `brew install tflint`

3. Initialise pre-commit hooks

   `pre-commit install --install-hooks`

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
