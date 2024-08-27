# openmrs-contrib-cluster
Contains terraform and helm charts to deploy OpenMRS distro in a cluster


How to try it out?

```helm install openmrs ./helm/openmrs```

What's been implemented so far?

1. Deploy mariadb cluster from bitnami/mariadb helm chart
2. Deploy openmrs backend

What's remaining for proof of concept?

1. Deploy gateway and front-end
2. Store credentials in secrets
3. Expose all config options via configMap
4. Publish helm chart
5. Develop terraform to deploy to AWS with RDS or mariadb cluster using helm chart