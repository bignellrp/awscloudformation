#!/bin/bash


# Fill the variables from CF output

key=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/myKeyPair/ {print $3}'`
routetableid=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/RouteTableID/ {print $3}'`
eniid=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/InsideENI/ {print $3}'`
tgwid=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/TransitGatewayOutput/ {print $4}'`
spoke1rtbid=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test1RouteTableID/ {print $3}'`
spoke2rtbid=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test2RouteTableID/ {print $3}'`
vpc1instanceprivate=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test1InstancesPrivateIp/ {print $3}'`
vpc1instancepublic=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test1InstancesPublicIp/ {print $3}'`
vpc2instanceprivate=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test2InstancesPrivateIp/ {print $3}'`
vpc2instancepublic=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test2InstancesPublicIp/ {print $3}'`

# Applying the routes
echo " 

Applying the routes. Check the output for errors. Successful output is 4x True.

"

aws ec2 create-route --route-table-id $routetableid --destination-cidr-block 192.168.0.0/16 --gateway-id $tgwid
aws ec2 create-route --route-table-id $routetableid --destination-cidr-block 0.0.0.0/0 --network-interface-id $eniid
aws ec2 create-route --route-table-id $spoke1rtbid --destination-cidr-block 0.0.0.0/0 --gateway-id $tgwid
aws ec2 create-route --route-table-id $spoke2rtbid --destination-cidr-block 0.0.0.0/0 --gateway-id $tgwid


# Testing

echo "

Now login to test instance in VPC 1 and confirm you can ping the instance in VPC2. 
Also test that both VPC1 and VPC2 can get to 8.8.8.8 through the FW.

ssh -oStrictHostKeyChecking=no -i ~/.ssh/$key.pem ec2-user@$vpc1instancepublic ping -c 4 $vpc2instanceprivate
ssh -oStrictHostKeyChecking=no -i ~/.ssh/$key.pem ec2-user@$vpc1instancepublic ping -c 4 8.8.8.8
ssh -oStrictHostKeyChecking=no -i ~/.ssh/$key.pem ec2-user@$vpc2instancepublic ping -c 4 8.8.8.8


"
