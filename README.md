# Introduction

Cloudformation is a great tool but can be tricky to remember the specific commands or quirks if you don't use it everyday.

Same as anything, use it or lose it.  Hopefully this set of commented scripts used along with the readme and wiki will either provide the starting block for someone new to cloudformation or a refresher for someone that doesnt use it all the time.

# Project 1:  Fortigate Egress using AWS Transit GW

At Re:Invent 2018 AWS announced a replacement to the Transit VPC solution called Transit GW.  Its premise is to solve the issue where a customer has a requirement to "transit" traffic through a VPC to create a hub and spoke environment.  Transit routing is not natively supported by AWS so the original solution was to create an overlay network that allows this type of routing.  This was redesigned in 2018 to become TGW where this routing can be managed by AWS instead of managing your own routing devices.

This project is to use TGW along with a virtual Fortigate firewall to enable a single egress to the internet from multiple spoke VPCs.

The fortigate egress cf script is configured to build a single Fortigate VM for use with AWS Transit Gateway.


![Fortigate Egress Diagram](https://user-images.githubusercontent.com/3774222/52119268-77a2c900-2610-11e9-92b3-25e86c7971c8.png)

```
aws cloudformation create-stack --stack-name fortigate-egress --template-body file:///tmp/awscloudformation/fortigate-egress.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="example-key"
```

Currently this script requires manual addition of static routes that point at the private ENI. A default route in a new VPC connected to the same TGW will allow private instances to nat outbound via a central shared firewall.

This comes with two templates that currently need to be built hub first then spokes second.

```
aws cloudformation create-stack --stack-name fortigate-spokes --template-body file:///tmp/awscloudformation/fortigate-spoke.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="example-key"
```

The fortigate-spoke.yaml will create two spokes and attach them to the same TGW route table for use with the Fortigate Egress.

Currently the only thing that is not supported with CloudFormation is addition of the spoke routes to the tgw.

This must be done manually and can be done from the awscli once the stacks are complete.



The route-table-id and the gateway-id can be found using the following commands:

3 commands for the hub stack to output $route-table-id and $tgw-id

***NOTE*** The query outputs the value with quotation marks which the create-route command doesnt like.  So i stripped them off with sed. It will be much easier when AWS build this into cloudformation directly.

```
routetableid=`aws cloudformation describe-stacks --stack-name fortigate-egress --query 'Stacks[0].Outputs[0].OutputValue'`; routetableid=`sed "s/\"//g" <<<"$routetableid"`
eniid=`aws cloudformation describe-stacks --stack-name fortigate-egress --query 'Stacks[0].Outputs[2].OutputValue'`; eniid=`sed "s/\"//g" <<<"$eniid"`
tgwid=`aws cloudformation describe-stacks --stack-name fortigate-egress --query 'Stacks[0].Outputs[4].OutputValue'`; tgwid=`sed "s/\"//g" <<<"$tgwid"`
```

Apply to Hub with

```
aws ec2 create-route --route-table-id $routetableid --destination-cidr-block 192.168.0.0/16 --gateway-id $tgwid
aws ec2 create-route --route-table-id $routetableid --destination-cidr-block 0.0.0.0/0 --network-interface-id $eniid
```

then two commands to output test1rtb and test2rtb

```
spoke1rtbid=`aws cloudformation describe-stacks --stack-name fortigate-spokes --query 'Stacks[0].Outputs[3].OutputValue'`; spoke1rtbid=`sed "s/\"//g" <<<"$spoke1rtbid"`
spoke2rtbid=`aws cloudformation describe-stacks --stack-name fortigate-spokes --query 'Stacks[0].Outputs[0].OutputValue'`; spoke2rtbid=`sed "s/\"//g" <<<"$spoke2rtbid"`
```

Apply to Spokes with

```
aws ec2 create-route --route-table-id $spoke1rtbid --destination-cidr-block 0.0.0.0/0 --gateway-id $tgwid
aws ec2 create-route --route-table-id $spoke2rtbid --destination-cidr-block 0.0.0.0/0 --gateway-id $tgwid
```

# Fortigate Egress Next steps

The script fortigate-egress currently only builds a single firewall with static routing via a vpc attachment (eni).  This does not provide AZ resiliency.  To add a second firewall VPNs would be required that connect back to the TGW direclty which would bypasss the vpc attachment. Traffic would be distributed between them using ECMP and all the routes would be advertised over the tunnels using BGP.

Unfortunately there is no native support for VPN creation so additional scripting would be required to facilitate this.

There is a similar github project may have solved this issue using Lambda but i've not had a chance to test/review it yet.

https://github.com/MattTunny/AWS-Transit-Gateway-Demo-MultiAccount

# Project 2: Plain VPC with Private VPN

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
vpnid=`aws cloudformation describe-stacks --stack-name spoke-rbignell --query 'Stacks[0].Outputs[0].OutputValue'`
aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid"
```
