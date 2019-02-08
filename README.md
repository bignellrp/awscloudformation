# Introduction

Cloudformation is a great tool but can be tricky to remember the specific commands or quirks if you don't use it everyday.

Same as anything, use it or lose it.  Hopefully this set of commented scripts used along with the readme and wiki will either provide the starting block for someone new to cloudformation or a refresher for someone that doesnt use it all the time.

To start if you're not familiar with github you'll need to clone this repo to your machine. Assuming you're using linux just run the following commands to clone to your home dir:

```
cd
git clone https://github.com/bignellrp/awscloudformation.git
```

# Project 1:  Fortigate Egress using AWS Transit GW

At Re:Invent 2018 AWS announced a replacement to the Transit VPC solution called Transit GW.  Its premise is to solve the issue where a customer has a requirement to "transit" traffic through a VPC to create a hub and spoke environment.  Transit routing is not natively supported by AWS so the original solution was to create an overlay network that allows this type of routing.  This was redesigned in 2018 to become TGW where this routing can be managed by AWS instead of managing your own routing devices.

This project is to use TGW along with a virtual Fortigate firewall to enable a single egress to the internet from multiple spoke VPCs.

The fortigate egress cf script is configured to build a single Fortigate VM for use with AWS Transit Gateway.


![Fortigate Egress Diagram](https://user-images.githubusercontent.com/3774222/52119268-77a2c900-2610-11e9-92b3-25e86c7971c8.png)


```
aws cloudformation create-stack --stack-name fortigate-egress --template-body file:///$HOME/awscloudformation/fortigate-egress.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="my-key"
```

Currently this script requires manual addition of static routes that point at the private ENI. A default route in a new VPC connected to the same TGW will allow private instances to nat outbound via a central shared firewall.

This comes with two templates that currently need to be built hub first then spokes second.

```
aws cloudformation create-stack --stack-name fortigate-spokes --template-body file:///$HOME/awscloudformation/fortigate-spoke.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="my-key"
```

The fortigate-spoke.yaml will create two spokes and attach them to the same TGW route table for use with the Fortigate Egress.

Currently the only thing that is not supported with CloudFormation is addition of the spoke routes to the tgw.

This must be done manually and can be done from the awscli once the stacks are complete.



The route-table-id and the gateway-id can be found using the following commands:

3 commands for the hub stack to output $route-table-id and $tgw-id

***NOTE*** The query outputs the value with quotation marks which the create-route command doesnt like.  So i stripped them off with sed. It will be much easier when AWS build this into cloudformation directly.

```
routetableid=`aws cloudformation describe-stacks --stack-name fortigate-egress --query 'Stacks[0].Outputs[0].OutputValue' | sed "s/\"//g"`
eniid=`aws cloudformation describe-stacks --stack-name fortigate-egress --query 'Stacks[0].Outputs[2].OutputValue' | sed "s/\"//g"`
tgwid=`aws cloudformation describe-stacks --stack-name fortigate-egress --query 'Stacks[0].Outputs[4].OutputValue' | sed "s/\"//g"`
```

Apply to Hub with

```
aws ec2 create-route --route-table-id $routetableid --destination-cidr-block 192.168.0.0/16 --gateway-id $tgwid
aws ec2 create-route --route-table-id $routetableid --destination-cidr-block 0.0.0.0/0 --network-interface-id $eniid
```

then two commands to output test1rtb and test2rtb

```
spoke1rtbid=`aws cloudformation describe-stacks --stack-name fortigate-spokes --query 'Stacks[0].Outputs[3].OutputValue' | sed "s/\"//g"`
spoke2rtbid=`aws cloudformation describe-stacks --stack-name fortigate-spokes --query 'Stacks[0].Outputs[0].OutputValue' | sed "s/\"//g"`
```

Apply to Spokes with

```
aws ec2 create-route --route-table-id $spoke1rtbid --destination-cidr-block 0.0.0.0/0 --gateway-id $tgwid
aws ec2 create-route --route-table-id $spoke2rtbid --destination-cidr-block 0.0.0.0/0 --gateway-id $tgwid
```

# Fortigate Egress Next steps

The script fortigate-egress currently only builds a single firewall with static routing via a vpc attachment (eni).  This does not provide AZ resiliency.  To add a second firewall VPNs would be required that connect back to the TGW direclty which would bypasss the vpc attachment. Traffic would be distributed between them using ECMP and all the routes would be advertised over the tunnels using BGP.

Unfortunately there is no native support for VPN creation so additional scripting would be required to facilitate this.

There is a similar github project that has solved the automation of the tgw routes with lambda.  For now the manual steps for adding the routes is fine considering its hopefully on the AWS roadmap to fix.

https://github.com/MattTunny/AWS-Transit-Gateway-Demo-MultiAccount

A minor fix would also be to find a more elegant way of outputting a specific value rather than messing with the array.  Currently its pot luck getting the right number within the array at its not always in the order you expect.

e.g.

aws cloudformation describe-stacks --stack-name fortigate-egress --query 'Stacks[0].Outputs[4].OutputValue

doesnt always output the 5th value (0 being the first output in the list)

aws cloudformation describe-stacks --stack-name fortigate-egress | grep eni | sed s/OutputValue//g | sed "s/\"//g" | sed "s/\://g"

This could do it but what if there were multiple references to eni?

This link has some interesting options but not sure which one is suitable:

https://theserverlessway.com/aws/cli/query/


# Project 2: VPC with VPN connecting to single Fortigate

This project is to create a VPC with a VPN and use a bash script to build the VPN onto a Fortigate in a separate VPC.

![Fortigate VPN Diagram](https://github.com/bignellrp/awscloudformation/blob/master/Fortigate-VPN.png)

The bash script uses "aws ec2 describe-vpn-connections" for grabbing the VPN connection info once built and along with output commands "aws cloudformation describe-stacks" from the CF template it can build and apply the config.

First create the Fortigate stack:

```
aws cloudformation create-stack --stack-name fortigate-vpn --template-body file:///$HOME/awscloudformation/fortigate-vpn.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="my-key"
```

Once built create the VPC stack:

```
aws cloudformation create-stack --stack-name vpc-vpn --template-body file:///$HOME/awscloudformation/vpc-vpn.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="my-key"
```

Finally run the bash script to apply the vpn config:

```
chmod 755 $HOME/awscloudformation/applyvpn.sh
$HOME/awscloudformation/applyvpn.sh
```

Now login to test instance and confirm you can ping the inside IP of the firewall

```

ssh -i ~/.ssh/my-key.pem ec2-user@63.32.104.62
ping 192.168.2.150

[ec2-user@ip-192-168-1-151 ~]$ ping 192.168.2.150
PING 192.168.2.150 (192.168.2.150) 56(84) bytes of data.
64 bytes from 192.168.2.150: icmp_seq=1 ttl=254 time=1.40 ms
64 bytes from 192.168.2.150: icmp_seq=2 ttl=254 time=1.24 ms
64 bytes from 192.168.2.150: icmp_seq=3 ttl=254 time=1.05 ms
64 bytes from 192.168.2.150: icmp_seq=4 ttl=254 time=1.04 ms
64 bytes from 192.168.2.150: icmp_seq=5 ttl=254 time=1.00 ms
^C
--- 192.168.2.150 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4005ms
rtt min/avg/max/mdev = 1.000/1.150/1.406/0.156 ms

```
