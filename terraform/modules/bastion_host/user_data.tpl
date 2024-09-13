#!/bin/bash -xe

sleep 10

yum update -y
yum groupinstall -y 'Development Tools'
yum install -y mysql git
