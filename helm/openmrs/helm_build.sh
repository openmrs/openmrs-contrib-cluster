helm dependency update ../openmrs-backend
helm package ../openmrs-backend -d ../openmrs-backend/
helm dependency update ../openmrs-frontend
helm package ../openmrs-frontend -d ../openmrs-frontend/
helm dependency update ../openmrs-gateway
helm package ../openmrs-gateway -d ../openmrs-gateway/
helm dependency update
