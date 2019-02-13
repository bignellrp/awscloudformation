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

Creating customer gateways.  This must be done first as other commands rely on this info.

"
outputvars=`echo $HOME/fortigate-egress_outputvars`
echo "" > $outputvars
fw1=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/FW1Public/ {print $3}'`
echo "fw1: $fw1" >> $outputvars
fw2=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/FW2Public/ {print $3}'`
echo "fw2: $fw2" >> $outputvars
aws ec2 create-customer-gateway --type ipsec.1 --public-ip $fw1 --bgp-asn 65000 2>&1 | tee -a $outputvars
aws ec2 create-customer-gateway --type ipsec.1 --public-ip $fw2 --bgp-asn 65000 2>&1 | tee -a $outputvars

echo " 

Collecting information, this can take a few seconds... 

"

echo " Collecting information, this can take a few seconds... " >> $outputvars

# Fill the variables from CF output
key=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/myKeyPair/ {print $3}'`
output01=`echo $HOME/fortigate-egress_output1`
output02=`echo $HOME/fortigate-egress_output2`
cgwid=`aws ec2 describe-customer-gateways --filters "Name=ip-address,Values=$fw1" --output text | awk '{print $3}' | awk 'NR==1'`
echo "cgwid: $cgwid" >> $outputvars
cgwid1=`aws ec2 describe-customer-gateways --filters "Name=ip-address,Values=$fw2" --output text | awk '{print $3}' | awk 'NR==1'`
echo "cgwid1: $cgwid1" >> $outputvars
tgwid=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/TransitGatewayOutput/ {print $4}'`
echo "tgwid: $tgwid" >> $outputvars
test1=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test1InstancesPublicIp/ {print $3}'`
echo "test1: $test1" >> $outputvars
test2=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test2InstancesPublicIp/ {print $3}'`
echo "test2: $test2" >> $outputvars
lgw=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/MyInstanceOutsideIp/ {print $3}'`
echo "lgw: $lgw" >> $outputvars
lgw1=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/MyInstance2OutsideIp/ {print $3}'`
echo "lgw1: $lgw1" >> $outputvars
routetableid=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/RouteTableID/ {print $3}'`
echo "routetableid: $routetableid" >> $outputvars
spoke1rtbid=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test1RouteTableID/ {print $3}'`
echo "spoke1rtbid: $spoke1rtbid" >> $outputvars
spoke2rtbid=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test2RouteTableID/ {print $3}'`
echo "spoke2rtbid: $spoke2rtbid" >> $outputvars
vpc1instanceprivate=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test1InstancesPrivateIp/ {print $3}'`
echo "vpc1instanceprivate: $vpc1instanceprivate" >> $outputvars
vpc1instancepublic=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test1InstancesPublicIp/ {print $3}'`
echo "vpc1instancepublic: $vpc1instancepublic" >> $outputvars
vpc2instanceprivate=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test2InstancesPrivateIp/ {print $3}'`
echo "vpc2instanceprivate: $vpc2instanceprivate" >> $outputvars
vpc2instancepublic=`aws cloudformation describe-stacks --stack-name fortigate-spokes --output text | awk '/Test2InstancesPublicIp/ {print $3}'`
echo "vpc2instancepublic: $vpc2instancepublic" >> $outputvars
tgwrtbid=`aws cloudformation describe-stacks --stack-name fortigate-egress --output text | awk '/TransitGatewayRTBOutput/ {print $4}'`
echo "tgwrtbid: $tgwrtbid" >> $outputvars

# Applying the routes and adding the tgw vpns
echo " 

Creating the VPNs. Check the output for errors.

"
# Output to screen and into the debug file for reference

aws ec2 create-vpn-connection --type ipsec.1 --customer-gateway-id $cgwid --transit-gateway-id $tgwid 2>&1 | tee -a $outputvars
aws ec2 create-vpn-connection --type ipsec.1 --customer-gateway-id $cgwid1 --transit-gateway-id $tgwid 2>&1 | tee -a $outputvars

echo "

Collecting more information, this can also take a few seconds...

"
remip01=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==4'`
echo "remip01: $remip01" >> $outputvars
remip02=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==8'`
echo "remip02: $remip02" >> $outputvars
remip03=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid1" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==4'`
echo "remip03: $remip03" >> $outputvars
remip04=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid1" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==8'`
echo "remip04: $remip04" >> $outputvars
locip01=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==2'`
echo "locip01: $locip01" >> $outputvars
locip02=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==6'`
echo "locip02: $locip02" >> $outputvars
locip03=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid1" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==2'`
echo "locip03: $locip03" >> $outputvars
locip04=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid1" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==6'`
echo "locip04: $locip04" >> $outputvars
remgw01=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==3'`
echo "remgw01: $remgw01" >> $outputvars
remgw02=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==7'`
echo "remgw02: $remgw02" >> $outputvars
remgw03=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid1" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==3'`
echo "remgw03: $remgw03" >> $outputvars
remgw04=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid1" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==7'`
echo "remgw04: $remgw04" >> $outputvars
secret01=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid" | grep -oPm1 "(?<=<pre_shared_key>)[^<]+" | awk 'NR==1'`
echo "secret01: $secret01" >> $outputvars
secret02=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid" | grep -oPm1 "(?<=<pre_shared_key>)[^<]+" | awk 'NR==2'`
echo "secret02: $secret02" >> $outputvars
secret03=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid1" | grep -oPm1 "(?<=<pre_shared_key>)[^<]+" | awk 'NR==1'`
echo "secret03: $secret03" >> $outputvars
secret04=`aws ec2 describe-vpn-connections --filters "Name=customer-gateway-id,Values=$cgwid1" | grep -oPm1 "(?<=<pre_shared_key>)[^<]+" | awk 'NR==2'`
echo "secret04: $secret04" >> $outputvars
localasn=`aws ec2 describe-vpn-connections --filters "Name=transit-gateway-id,Values=$tgwid" | grep -oPm1 "(?<=<asn>)[^<]+" | awk 'NR==1'`
echo "localasn: $localasn" >> $outputvars
remoteasn=`aws ec2 describe-vpn-connections --filters "Name=transit-gateway-id,Values=$tgwid" | grep -oPm1 "(?<=<asn>)[^<]+" | awk 'NR==2'`
echo "remoteasn: $remoteasn" >> $outputvars
vpn1=`aws ec2 describe-vpn-connections --output text --filters "Name=customer-gateway-id,Values=$cgwid" | awk '/available/' | awk 'NR==1' | awk '{print $6}'`
echo "vpn1: $vpn1" >> $outputvars
vpn2=`aws ec2 describe-vpn-connections --output text --filters "Name=customer-gateway-id,Values=$cgwid1" | awk '/available/' | awk 'NR==1' | awk '{print $6}'`
echo "vpn2: $vpn2" >> $outputvars

echo " 

Creating the routes. Check the output for errors.

"
aws ec2 create-route --route-table-id $spoke1rtbid --destination-cidr-block 0.0.0.0/0 --gateway-id $tgwid
aws ec2 create-route --route-table-id $spoke2rtbid --destination-cidr-block 0.0.0.0/0 --gateway-id $tgwid

# Need to wait for vpn to be available to avoid this error: An error occurred (IncorrectState)

state=`aws ec2 describe-vpn-connections --output text --filters "Name=vpn-connection-id,Values=$vpn1" | awk '/available/ {print $3}'`
while [ "$state" != "available" ]
    do
    echo ...Waiting another 30 seconds...
    sleep 30
done

echo "VPN is now $state, now they can be attached to the TGW...."

tgwatt1=`aws ec2 describe-transit-gateway-attachments --output text --filters "Name=resource-id,Values=$vpn1" | awk '{print $7}'`
echo "tgwatt1: $tgwatt1" >> $outputvars
tgwatt2=`aws ec2 describe-transit-gateway-attachments --output text --filters "Name=resource-id,Values=$vpn2" | awk '{print $7}'`
echo "tgwatt2: $tgwatt2" >> $outputvars

aws ec2 associate-transit-gateway-route-table --transit-gateway-route-table-id $tgwrtbid --transit-gateway-attachment-id $tgwatt1 2>&1 | tee -a $outputvars
aws ec2 associate-transit-gateway-route-table --transit-gateway-route-table-id $tgwrtbid --transit-gateway-attachment-id $tgwatt2 2>&1 | tee -a $outputvars
aws ec2 enable-transit-gateway-route-table-propagation --transit-gateway-route-table-id $tgwrtbid --transit-gateway-attachment-id $tgwatt1 2>&1 | tee -a $outputvars
aws ec2 enable-transit-gateway-route-table-propagation --transit-gateway-route-table-id $tgwrtbid --transit-gateway-attachment-id $tgwatt2 2>&1 | tee -a $outputvars

echo "

Creating vpn configs...

"

echo "Creating vpn configs..." >> $outputvars

# Adding the FW commands

# Echo FW1 commands into a file

echo "
config vpn ipsec phase1-interface
    edit "vpn-0"
        set interface "port1"
        set local-gw $lgw
        set keylife 28800
        set peertype any
        set proposal aes128-sha1
        set dpd on-idle
        set dhgrp 2
        set remote-gw $remgw01
        set psksecret $secret01
        set dpd-retryinterval 10
    next
    edit "vpn-1"
        set interface "port1"
        set local-gw $lgw
        set keylife 28800
        set peertype any
        set proposal aes128-sha1
        set dpd on-idle
        set dhgrp 2
        set remote-gw $remgw02
        set psksecret $secret02
        set dpd-retryinterval 10
    next
end
config vpn ipsec phase2-interface
    edit "vpn-0"
        set phase1name "vpn-0"
        set proposal aes128-sha1
        set dhgrp 2
        set keylifeseconds 3600
    next
    edit "vpn-1"
        set phase1name "vpn-1"
        set proposal aes128-sha1
        set dhgrp 2
        set keylifeseconds 3600
    next
end
config system interface
    edit "vpn-0"
        set vdom "root"
        set ip $locip01 255.255.255.255
        set allowaccess ping
        set type tunnel
        set tcp-mss 1379
        set remote-ip $remip01 255.255.255.255
        set interface "port1"
    next
    edit "vpn-1"
        set vdom "root"
        set ip $locip02 255.255.255.255
        set allowaccess ping
        set type tunnel
        set tcp-mss 1379
        set remote-ip $remip02 255.255.255.255
        set interface "port1"
    next
end
config system zone
    edit "VPN"
        set interface "vpn-0" "vpn-1"
    next
end
config router prefix-list
    edit "Default"
        config rule
            edit 10
                set prefix 0.0.0.0/0
                unset ge
                unset le
            next
        end
    next
end
config router route-map
    edit "RM_OUT"
        config rule
            edit 10
                set match-ip-address "Default"
            next
        end
    next
    edit "RM_OUT_BACKUP"
        config rule
            edit 10
                set match-ip-address "Default"
                set set-aspath "$localasn $localasn"
            next
        end
    next
end
config router bgp
    set as $localasn
    set router-id $lgw
    config neighbor
        edit "$remip01"
            set capability-default-originate enable
            set description "vpn_0"
            set remote-as $remoteasn
            set route-map-out "RM_OUT"
            set weight 200
        next
        edit "$remip02"
            set capability-default-originate enable
            set description "vpn_1"
            set remote-as $remoteasn
            set route-map-out "RM_OUT_BACKUP"
            set weight 100
        next
    end
end
config firewall policy
    edit 0
        set name "outgoing"
        set srcintf "VPN"
        set dstintf "port1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set utm-status enable
        set logtraffic all
        set fsso disable
        set av-profile "default"
        set webfilter-profile "default"
        set dnsfilter-profile "default"
        set ips-sensor "all_default"
        set application-list "block-high-risk"
        set ssl-ssh-profile "certificate-inspection"
        set nat enable
    next
end
" > $output01

# Echo FW2 commands into a file

echo "
config vpn ipsec phase1-interface
    edit "vpn-0"
        set interface "port1"
        set local-gw $lgw1
        set keylife 28800
        set peertype any
        set proposal aes128-sha1
        set dpd on-idle
        set dhgrp 2
        set remote-gw $remgw03
        set psksecret $secret03
        set dpd-retryinterval 10
    next
    edit "vpn-1"
        set interface "port1"
        set local-gw $lgw1
        set keylife 28800
        set peertype any
        set proposal aes128-sha1
        set dpd on-idle
        set dhgrp 2
        set remote-gw $remgw04
        set psksecret $secret04
        set dpd-retryinterval 10
    next
end
config vpn ipsec phase2-interface
    edit "vpn-0"
        set phase1name "vpn-0"
        set proposal aes128-sha1
        set dhgrp 2
        set keylifeseconds 3600
    next
    edit "vpn-1"
        set phase1name "vpn-1"
        set proposal aes128-sha1
        set dhgrp 2
        set keylifeseconds 3600
    next
end
config system interface
    edit "vpn-0"
        set vdom "root"
        set ip $locip03 255.255.255.255
        set allowaccess ping
        set type tunnel
        set tcp-mss 1379
        set remote-ip $remip03 255.255.255.255
        set interface "port1"
    next
    edit "vpn-1"
        set vdom "root"
        set ip $locip04 255.255.255.255
        set allowaccess ping
        set type tunnel
        set tcp-mss 1379
        set remote-ip $remip04 255.255.255.255
        set interface "port1"
    next
end
config system zone
    edit "VPN"
        set interface "vpn-0" "vpn-1"
    next
end
config router prefix-list
    edit "Default"
        config rule
            edit 10
                set prefix 0.0.0.0/0
                unset ge
                unset le
            next
        end
    next
end
config router route-map
    edit "RM_OUT"
        config rule
            edit 10
                set match-ip-address "Default"
                set set-aspath "$localasn $localasn $localasn"
            next
        end
    next
    edit "RM_OUT_BACKUP"
        config rule
            edit 10
                set match-ip-address "Default"
                set set-aspath "$localasn $localasn $localasn $localasn"
            next
        end
    next
end
config router bgp
    set as $localasn
    set router-id $lgw
    config neighbor
        edit "$remip03"
            set capability-default-originate enable
            set description "vpn_0"
            set remote-as $remoteasn
            set route-map-out "RM_OUT"
            set weight 200
        next
        edit "$remip04"
            set capability-default-originate enable
            set description "vpn_1"
            set remote-as $remoteasn
            set route-map-out "RM_OUT_BACKUP"
            set weight 100
        next
    end
end
config firewall policy
    edit 0
        set name "outgoing"
        set srcintf "VPN"
        set dstintf "port1"
        set srcaddr "all"
        set dstaddr "all"
        set action accept
        set schedule "always"
        set service "ALL"
        set utm-status enable
        set logtraffic all
        set fsso disable
        set av-profile "default"
        set webfilter-profile "default"
        set dnsfilter-profile "default"
        set ips-sensor "all_default"
        set application-list "block-high-risk"
        set ssl-ssh-profile "certificate-inspection"
        set nat enable
    next
end
" > $output02

# Echo filename and apply commands using ssh. Make sure key matches the one used in CF

echo "
The following files were created:

1. $output01
2. $output02

Now applying the config to the firewalls...


"

echo " The following files were created: 1. $output01 2. $output02 Now applying the config to the firewalls... " >> $outputvars

ssh -oStrictHostKeyChecking=no -T -i ~/.ssh/$key.pem admin@$fw1 < $output01 2>&1 | tee -a $outputvars
ssh -oStrictHostKeyChecking=no -T -i ~/.ssh/$key.pem admin@$fw2 < $output02 2>&1 | tee -a $outputvars


echo "

VPN Config added. Check output above in case of errors.

"

# Testing

echo "

Now login to test instance in VPC 1 and confirm you can ping the instance in VPC2. 
Also test that both VPC1 and VPC2 can get to 8.8.8.8 through the FW.

ssh -oStrictHostKeyChecking=no -i ~/.ssh/$key.pem ec2-user@$vpc1instancepublic ping -c 4 $vpc2instanceprivate
ssh -oStrictHostKeyChecking=no -i ~/.ssh/$key.pem ec2-user@$vpc1instancepublic ping -c 4 8.8.8.8
ssh -oStrictHostKeyChecking=no -i ~/.ssh/$key.pem ec2-user@$vpc2instancepublic ping -c 4 8.8.8.8


"
