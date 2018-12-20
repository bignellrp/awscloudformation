# awscloudformation
Collection of Cloudformation Scripts for AWS

I prefer to launch these scripts using the awscli

Install and configure aws cli using this page:

https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

Clone the script into a tmp directory

cd /tmp; git clone https://github.com/bignellrp/awscloudformation.git

and launch using the command:

aws cloudformation create-stack --stack-name stack-name --template-body file:///templates/fortigate-egress.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="example-key"
