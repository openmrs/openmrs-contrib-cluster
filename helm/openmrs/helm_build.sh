[ "$1" = "update" ] && helm dependency update ../openmrs-backend
helm package ../openmrs-backend -d ../openmrs-backend/
[ "$1" = "update" ] && helm dependency update  ../openmrs-frontend
helm package ../openmrs-frontend -d ../openmrs-frontend/
helm dependency update
