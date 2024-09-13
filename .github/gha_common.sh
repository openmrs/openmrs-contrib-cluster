#!/bin/bash

# Exit on error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset

GREEN_COLOR="\033[1;32m"
YELLOW_COLOR="\033[1;33m"
NO_COLOR="\033[0m"

terraform_init(){
    if [[ ${GITHUB_ACTIONS:-} ]]
    then
        terraform init -backend=false
    fi
}
