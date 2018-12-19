# awscloudformation
Collection of Cloudformation Scripts for AWS

I prefer to launch these scripts using the awscli

Install and configure aws cli using this page:

https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

Clone the script into a tmp directory

git clone https://github.com/libgit2/libgit2

and launch using the command:

aws cloudformation create-stack --stack-name mynewfirewallstack --capabilities CAPABILITY_IAM --template-body file:///tmp/fortigate-egress.yaml

To upload a config to s3 use the following:

aws s3 cp fortigate.conf s3://example-bucket/fortigate.conf
