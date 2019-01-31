# awscloudformation
# Collection of Cloudformation Scripts for AWS

# To launch these scripts using the awscli

Install and configure aws cli using this page:

https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

Clone the script into a tmp directory

cd /tmp; git clone https://github.com/bignellrp/awscloudformation.git
      
and launch using the command:

aws cloudformation create-stack --stack-name stack-name --template-body file:///tmp/awscloudformation/choose-a-template.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="example-key"

# Fortigate Egress

Fortigate Egress is configured to build a single Fortigate VM for use with AWS Transit Gateway.  Currently this script requires manual addition of static routes that point at the private ENI. A default route in a new VPC connected to the same TGW will allow private instances to nat outbound via a central shared firewall.

This comes with two templates that currently need to be built hub first then spokes second.

The fortigate-spoke.yaml will create two spokes and attach them to the same TGW route table for use with the Fortigate Egress.

Currently the only thing that is not supported with CloudFormation is addition of the spoke routes to the tgw.

This must be done manually and can be done from the awscli once the stacks are complete.

aws ec2 create-route --route-table-id $route-table-id --destination-cidr-block 0.0.0.0/0 --gateway-id $tgw-id

The route-table-id and the gateway-id can be found using the following commands:

Two commands for the hub stack to output $route-table-id and $tgw-id

aws cloudformation describe-stacks --stack-name hub-stack --query 'Stacks[0].Outputs[1].OutputValue'
aws cloudformation describe-stacks --stack-name hub-stack --query 'Stacks[0].Outputs[2].OutputValue'

then two commands to output test1rtb and test2rtb

aws cloudformation describe-stacks --stack-name fortigate-spokes --query 'Stacks[0].Outputs[3].OutputValue'
aws cloudformation describe-stacks --stack-name fortigate-spokes --query 'Stacks[0].Outputs[0].OutputValue'


# Fortigate Egress Next steps

To add to the script building of the spoke VPC plus an additional firewall for AZ resiliency including BGP failover and dynamic routing.

# VPC - VPN - EC2

Just a plain vpc with a single route table.  Will build a vpn and an ec2 for testing.

Use "aws ec2 describe-vpn-connections" for grabbing the VPN connection info once built.

e.g. aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=vpn-091cf676fe9816bd7" where the Value is taken from the cloudformation output.

aws cloudformation describe-stacks --stack-name spoke-rbignell | grep Output
