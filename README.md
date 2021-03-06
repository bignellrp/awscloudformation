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

The fortigate egress cf script is configured to build a single Fortigate VM for use with AWS Transit Gateway. A default route in a new VPC connected to the same TGW will allow private instances to nat outbound via a central shared firewall.


![Fortigate Egress Diagram](https://github.com/bignellrp/awscloudformation/blob/master/Fortigate-Egress.png)


First build the fortigate egress vpc.  We can refer to this as the hub.

```
aws cloudformation create-stack --stack-name fortigate-egress --template-body file:///$HOME/awscloudformation/fortigate-egress.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="my-key"
```

Once the hub is built then build the spokes with this command (you can edit wanip manually if required):

```
wanip=`curl -s ifconfig.me`
aws cloudformation create-stack --stack-name fortigate-spokes --template-body file:///$HOME/awscloudformation/fortigate-spoke.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="my-key" ParameterKey=WanIP,ParameterValue="$wanip"
```

Currently the only thing that is not supported with CloudFormation is addition of the spoke routes to the tgw. This can be done using bash by running the following:

```
chmod 755 $HOME/awscloudformation/applyroutes.sh
$HOME/awscloudformation/applyroutes.sh
```

Now login to test instance in VPC 1 and confirm you can ping the instance in VPC2. 
Also test that both VPC1 and VPC2 can get to 8.8.8.8 through the FW.

```
~/awscloudformation] $ ssh -oStrictHostKeyChecking=no -i ~/.ssh/my-key.pem ec2-user@34.255.117.127 ping -c 4 192.168.2.69
PING 192.168.2.69 (192.168.2.69) 56(84) bytes of data.
64 bytes from 192.168.2.69: icmp_seq=1 ttl=254 time=1.01 ms
64 bytes from 192.168.2.69: icmp_seq=2 ttl=254 time=0.682 ms
64 bytes from 192.168.2.69: icmp_seq=3 ttl=254 time=0.692 ms
64 bytes from 192.168.2.69: icmp_seq=4 ttl=254 time=0.665 ms

--- 192.168.2.69 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3041ms
rtt min/avg/max/mdev = 0.665/0.762/1.011/0.146 ms

~/awscloudformation] $ ssh -oStrictHostKeyChecking=no -i ~/.ssh/my-key.pem ec2-user@34.255.117.127 ping -c 4 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=112 time=1.71 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=112 time=1.24 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=112 time=1.32 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=112 time=1.28 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 1.249/1.393/1.715/0.187 ms

~/awscloudformation] $ ssh -oStrictHostKeyChecking=no -i ~/.ssh/my-key.pem ec2-user@34.247.55.51 ping -c 4 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=112 time=1.80 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=112 time=1.26 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=112 time=1.23 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=112 time=1.22 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 1.228/1.382/1.801/0.242 ms

```

# Project 2: Fortigate Egress using AWS Transit GW with 2 FWs

The script fortigate-egress currently only builds a single firewall with static routing via a vpc attachment (eni).  This does not provide AZ resiliency.  To add a second firewall VPNs would be required that connect back to the TGW directly which would bypass the vpc attachment. Traffic would be distributed between them using ECMP and all the routes would be advertised over the tunnels using BGP.

Unfortunately there is no native support for VPN creation so additional scripting would be required to facilitate this.

![Fortigate Egress Diagram 2](https://github.com/bignellrp/awscloudformation/blob/master/Fortigate-Egress2.png)

From this point the commands are very similar to project 1 just calling different scripts.

First build the fortigate egress vpc.  We can refer to this as the hub.

```
aws cloudformation create-stack --stack-name fortigate-egress --template-body file:///$HOME/awscloudformation/fortigate-egress2.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="my-key"
```

Once the hub is built then build the spokes with this command (you can edit wanip manually if required):

```
wanip=`curl -s ifconfig.me`
aws cloudformation create-stack --stack-name fortigate-spokes --template-body file:///$HOME/awscloudformation/fortigate-spoke2.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="my-key" ParameterKey=WanIP,ParameterValue="$wanip"
```

Currently the only thing that is not supported with CloudFormation is addition of the spoke routes to the tgw. This can be done using bash by running the following:

```
chmod 755 $HOME/awscloudformation/applyroutes2.sh
$HOME/awscloudformation/applyroutes2.sh
```

Now login to test instance in VPC 1 and confirm you can ping the instance in VPC2. 
Also test that both VPC1 and VPC2 can get to 8.8.8.8 through the FW.

```
~/awscloudformation] $ ssh -oStrictHostKeyChecking=no -i ~/.ssh/my-key.pem ec2-user@34.255.117.127 ping -c 4 192.168.2.69
PING 192.168.2.69 (192.168.2.69) 56(84) bytes of data.
64 bytes from 192.168.2.69: icmp_seq=1 ttl=254 time=1.01 ms
64 bytes from 192.168.2.69: icmp_seq=2 ttl=254 time=0.682 ms
64 bytes from 192.168.2.69: icmp_seq=3 ttl=254 time=0.692 ms
64 bytes from 192.168.2.69: icmp_seq=4 ttl=254 time=0.665 ms

--- 192.168.2.69 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3041ms
rtt min/avg/max/mdev = 0.665/0.762/1.011/0.146 ms

~/awscloudformation] $ ssh -oStrictHostKeyChecking=no -i ~/.ssh/my-key.pem ec2-user@34.255.117.127 ping -c 4 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=112 time=1.71 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=112 time=1.24 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=112 time=1.32 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=112 time=1.28 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 1.249/1.393/1.715/0.187 ms

~/awscloudformation] $ ssh -oStrictHostKeyChecking=no -i ~/.ssh/my-key.pem ec2-user@34.247.55.51 ping -c 4 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=112 time=1.80 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=112 time=1.26 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=112 time=1.23 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=112 time=1.22 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 1.228/1.382/1.801/0.242 ms

```

When you have finished testing you can delete the stacks but as commands were run separately there is some tidyup to be done.

You can use the delete-routes2.sh to tidy up. These should be run in order below waiting for each to complete before stating the next.  This could all be automated within the script if required.

```
chmod 755 $HOME/awscloudformation/deleteroutes2.sh
$HOME/awscloudformation/deleteroutes2.sh

aws cloudformation delete-stack --stack-name fortigate-spokes

aws cloudformation delete-stack --stack-name fortigate-egress
```



# Project 3: VPC with VPN connecting to single Fortigate

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

ssh -oStrictHostKeyChecking=no -i ~/.ssh/my-key.pem ec2-user@54.194.37.33 ping 192.168.2.140

Warning: Permanently added '54.194.37.33' (ECDSA) to the list of known hosts.
PING 192.168.2.140 (192.168.2.140) 56(84) bytes of data.
64 bytes from 192.168.2.140: icmp_seq=1 ttl=254 time=1.25 ms
64 bytes from 192.168.2.140: icmp_seq=2 ttl=254 time=1.11 ms
64 bytes from 192.168.2.140: icmp_seq=3 ttl=254 time=1.11 ms
64 bytes from 192.168.2.140: icmp_seq=4 ttl=254 time=1.30 ms
64 bytes from 192.168.2.140: icmp_seq=5 ttl=254 time=1.19 ms
64 bytes from 192.168.2.140: icmp_seq=6 ttl=254 time=1.05 ms
64 bytes from 192.168.2.140: icmp_seq=7 ttl=254 time=1.15 ms

```

# Project 4: VPC with VPN

Just a plain VPC with a VPN. Use vpn describe commands to grab VPN info. See applyvpn.sh for examples.

```
aws cloudformation create-stack --stack-name vpc-vpn --template-body file:///$HOME/awscloudformation/vpc-vpn.yaml  --parameters ParameterKey=myKeyPair,ParameterValue="my-key"
```

# Project 5: VPCs connected with TGW adding routes via Lambda

Inspired by a similar github project that has solved the automation of the tgw routes with lambda, this project is all about extending CF to use Lambda where commands may be unsupported.  In this case adding routes pointing at the TGW.  Hopefully this will lead on to creation of TGW VPNs with Lambda too.

https://github.com/MattTunny/AWS-Transit-Gateway-Demo-MultiAccount


![VPC-Lambda](https://github.com/bignellrp/awscloudformation/blob/master/VPC-Lambda.png)


First you need to package up the lambda and upload to S3.  There is a handy command that does all this for you.

```
aws cloudformation package --template-file $HOME/awscloudformation/vpc-tgw-lambda.yaml --s3-bucket networktest-cloudformation --output-template-file $HOME/packaged-template.yaml

Successfully packaged artifacts and wrote output template to file /home/myuser/packaged-template.yaml.
```

Now you can build the stack.

```
aws cloudformation deploy --template-file $HOME/packaged-template.yaml --stack-name vpc-tgw-lambda --capabilities CAPABILITY_IAM

Waiting for changeset to be created..
Waiting for stack create/update to complete
Successfully created/updated stack - vpc-tgw-lambda
```

Finally you can test that spoke 1 and ping spoke 2.

```
vpc1instancepublic=`aws cloudformation describe-stacks --stack-name vpc-tgw-lambda --output text | awk '/Test1InstancesPublicIp/ {print $3}'`
vpc2instanceprivate=`aws cloudformation describe-stacks --stack-name vpc-tgw-lambda --output text | awk '/Test2InstancesPrivateIp/ {print $3}'`
ssh -oStrictHostKeyChecking=no -i ~/.ssh/my-key.pem ec2-user@$vpc1instancepublic ping -c 4 $vpc2instanceprivate
```

Note: The uploaded lambda package remains in s3 after the stack is deleted.  You will need to tidy this up to avoid unwanted s3 costs.
Note: The CloudWatch logs also remain after the stack is deleted. You will need to tidy this up to avoid unwanted CloudWatch costs.

# Next Steps

Using the Fortinet scripts build the VPNs for two spokes that connect directly to TGW.

https://github.com/fortinetsolutions/AWS-CloudFormationTemplates/tree/master/Templates/TransitVPC/5.6

```
aws s3 cp s3://fortibucket-eu-west-1/main_functionv3.zip .
aws s3 cp s3://fortibucket-eu-west-1/56_worker_functionv3.zip .
```
