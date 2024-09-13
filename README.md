# openmrs-contrib-cluster
Contains terraform and helm charts to deploy OpenMRS distro in a cluster.

We recommend https://kind.sigs.k8s.io/ for local development.

How to try it out?

``` helm install openmrs oci://registry-1.docker.io/openmrs/openmrs```

Once installed you will see instructions on how to configure port-forwarding and access the instance. If you deploy to a cloud provider you will need to configure a load balancer / gateway to point to openmrs-gateway service on port 80.

What's been implemented so far?

1. Deploy mariadb primary and replica from bitnami/mariadb helm chart
2. Deploy openmrs backend
3. Deploy openmrs frontend and gateway

What's coming next?

1. Develop terraform to deploy to AWS with RDS or mariadb cluster using helm chart
2. Provide mariadb-galera cluster as an option to deploy. Make changes in the openmrs-core to support mariadb-galera cluster and mariadb read-only replicas.
3. ...

See https://openmrs.atlassian.net/wiki/x/tgBLCw for more details.