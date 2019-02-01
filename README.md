# awscloudformation
# Collection of Cloudformation Scripts for AWS

# To launch these scripts using the awscli

Install and configure aws cli using this page:

https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

Clone the script into a tmp directory

```
cd /tmp; git clone https://github.com/bignellrp/awscloudformation.git
```

and launch using the command:

```
aws cloudformation create-stack --stack-name stack-name --template-body file:///tmp/awscloudformation/choose-a-template.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="example-key"
```

# Fortigate Egress with TGW

https://github.com/bignellrp/awscloudformation/blob/master/fortigate-egress.yaml
https://github.com/bignellrp/awscloudformation/blob/master/fortigate-spoke.yaml

Fortigate Egress is configured to build a single Fortigate VM for use with AWS Transit Gateway.  Currently this script requires manual addition of static routes that point at the private ENI. A default route in a new VPC connected to the same TGW will allow private instances to nat outbound via a central shared firewall.

See wiki for details: https://github.com/bignellrp/awscloudformation/wiki

# Plain VPC with Private VPN

https://github.com/bignellrp/awscloudformation/blob/master/vpc-vpn-ec2.yaml

Just a plain vpc with a single route table.  This includes a vpn for private connectivity and an ec2 for testing.

Use "aws ec2 describe-vpn-connections" for grabbing the VPN connection info once built.

e.g. 

```
aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=vpn-091cf676fe9816bd7"
```

where "Values" is taken from the cloudformation output.

To get this information from the stack use one of these commands.

```
aws cloudformation describe-stacks --stack-name spoke-rbignell | grep Output
```

or

```
aws cloudformation describe-stacks --stack-name spoke-rbignell --query 'Stacks[0].Outputs[0].OutputValue'
```
