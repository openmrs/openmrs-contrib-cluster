helm package ../openmrs-backend -d ../openmrs-backend/
helm package ../openmrs-frontend -d ../openmrs-frontend/
helm package ../openmrs-gateway -d ../openmrs-gateway/
helm dependency update
