#!/bin/bash

set-hostname ${component}
yum install ansible -y &>>/opt/userdata.log
ansible-pull -i localhost, -U https://github.com/Revanthsatyam/roboshop-ansible-d76.git -e component=${component} -e env=${env} main.yml &>>/opt/userdata.log