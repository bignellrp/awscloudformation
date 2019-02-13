#!/bin/bash

#Checking the account is the network test account
ACCOUNT=`aws sts get-caller-identity | grep Account | awk '{print $2}' | sed 's/"//g' | sed 's/,//g'`
re='^[0-9]+$'
if ! [[ $ACCOUNT =~ $re ]] ; then
   exit 1
fi
echo
echo
echo "###############################################################################################"
echo " Using sts key for account $ACCOUNT "
echo "###############################################################################################"
echo
if [ $ACCOUNT != "855882134798" ]; then
  echo "###############################################################################################"
  echo "WARNING: You are not in the network test account 855882134798."
  echo "###############################################################################################"
  read -p "Continue (y/n)?" choice
  case "$choice" in
    y|Y ) echo;;
    n|N ) exit 1;;
    * ) exit 1;;
  esac
else
  echo
fi

echo " 

Collecting information....

"
outputvars=`echo $HOME/fortigate-egress_outputvars`
cgwid=`cat $outputvars | awk '/cgwid/ {print $2}' | awk 'NR==1'`
cgwid1=`cat $outputvars | awk '/cgwid1/ {print $2}'`
tgwid=`cat $outputvars | awk '/tgwid/ {print $2}'`
tgwrtbid=`cat $outputvars | awk '/tgwrtbid/ {print $2}'`
tgwatt1=`cat $outputvars | awk '/tgwatt1/ {print $2}'`
tgwatt2=`cat $outputvars | awk '/tgwatt2/ {print $2}'`
vpn1=`cat $outputvars | awk '/vpn1/ {print $2}'`
vpn2=`cat $outputvars | awk '/vpn2/ {print $2}'`

read -p "Deleting tgw attachments and VPNs, Are you sure? (y/n)?" choice
case "$choice" in
  y|Y ) echo;;
  n|N ) exit 1;;
  * ) exit 1;;
esac

aws ec2 disable-transit-gateway-route-table-propagation --transit-gateway-route-table-id $tgwrtbid --transit-gateway-attachment-id $tgwatt1
aws ec2 disassociate-transit-gateway-route-table --transit-gateway-route-table-id $tgwrtbid --transit-gateway-attachment-id $tgwatt1
aws ec2 disable-transit-gateway-route-table-propagation --transit-gateway-route-table-id $tgwrtbid --transit-gateway-attachment-id $tgwatt2
aws ec2 disassociate-transit-gateway-route-table --transit-gateway-route-table-id $tgwrtbid --transit-gateway-attachment-id $tgwatt2
aws ec2 delete-vpn-connection --vpn-connection-id $vpn1
aws ec2 delete-vpn-connection --vpn-connection-id $vpn2
aws ec2 delete-customer-gateway --customer-gateway-id $cgwid
aws ec2 delete-customer-gateway --customer-gateway-id $cgwid1

# Commented as the vpn delete should also delete the attachment
#aws ec2 delete-transit-gateway-vpc-attachment --transit-gateway-attachment-id $tgwatt1
#aws ec2 delete-transit-gateway-vpc-attachment --transit-gateway-attachment-id $tgwatt2

echo "

Delete complete. Check above output for errors.

If all went well you should be able to delete the CF stacks:

aws cloudformation delete-stack --stack-name fortigate-spokes

Wait for the above to complete.

aws cloudformation delete-stack --stack-name fortigate-egress

"

# Could automate using
#state=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/does not exist/'`
#while [ "$state" != *.exist ]
#    do
#    echo ...Waiting another 30 seconds...
#    sleep 30
#done
