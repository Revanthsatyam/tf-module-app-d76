#!/bin/bash

set-hostname ${component}
yum install ansible python3.12-pip.noarch -y &>>/opt/userdata.log
pip3.12 install botocore boto3
ansible-pull -i localhost, -U https://github.com/Revanthsatyam/roboshop-ansible-d76.git -e component=${component} -e env=${env} main.yml &>>/opt/userdata.log