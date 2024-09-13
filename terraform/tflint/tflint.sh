#!/bin/bash
export TFLINT_LOG=debug
set -e
REL_SCRIPT_DIR="`dirname \"$0\"`"
SCRIPT_DIR="`( cd \"$REL_SCRIPT_DIR\" && pwd)`"
# sourcing git hub actions common script
source $SCRIPT_DIR/../../.github/gha_common.sh
run_scan(){
    folder=$1

    #cd $folder
    terraform_init

    echo -e "${GREEN_COLOR}TFLint Scanning $folder....$NO_COLOR"
    tflint --config=$SCRIPT_DIR/.tflint.hcl --init
    tflint --config=$SCRIPT_DIR/.tflint.hcl

    if [[ $? -eq 0 ]]
    then
        echo -e "${YELLOW_COLOR}No issues found in $folder.$NO_COLOR"
    fi

    #cd - > /dev/null
    echo -e "\n"
}

run_scan teraform
for folder in terraform/node_groups/*
do
    run_scan $folder
done;
