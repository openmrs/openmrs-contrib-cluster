#!/bin/bash

# Terrascan scan and save output to scan_results
scan_results="$(docker run -v `pwd`:`pwd` -w `pwd` accurics/terrascan scan --config-path terrascan/terrascan-config.yaml --iac-type terraform --use-colors t)"

# Get scan summary from scan_results
scan_summary=$(echo "$scan_results" | sed -n -e '/Scan Summary -/,$p' | sed -r "s/[[:cntrl:]]\[([0-9]{1,3};)*[0-9]{1,3}m//g")

#Extract values from scan_summary
low_level_violations=$(grep "Low" <<< "$scan_summary" | grep -o -E "[0-9]+")
medium_level_violations=$(grep "Medium" <<< "$scan_summary" | grep -o -E "[0-9]+")
high_level_violations=$(grep "High" <<< "$scan_summary" | grep -o -E "[0-9]+") 

#Show Scan Output
echo "$scan_results"

#Check for violations
if [[ $high_level_violations -gt 0 ]]
then
    echo "High Level Voilations Found"
    exit 1
fi
echo "No Violations found"
exit 0