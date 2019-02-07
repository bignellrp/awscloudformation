#!/bin/bash


# Fill the variables from CF output
output01=`echo $HOME/fortigate-vpn_output`
vpnid=`aws cloudformation describe-stacks --stack-name vpc-vpn --query 'Stacks[0].Outputs[0].OutputValue' | sed "s/\"//g"`
lgw=`aws cloudformation describe-stacks --stack-name fortigate-vpn --query 'Stacks[0].Outputs[2].OutputValue' | sed "s/\"//g"`
remip01=`aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==4'`
remip02=`aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==8'`
locip01=`aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==2'`
locip02=`aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==6'`
remgw01=`aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==3'`
remgw02=`aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid" | grep -oPm1 "(?<=<ip_address>)[^<]+" | awk 'NR==7'`
secret01=`aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid" | grep -oPm1 "(?<=<pre_shared_key>)[^<]+" | awk 'NR==1'`
secret02=`aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid" | grep -oPm1 "(?<=<pre_shared_key>)[^<]+" | awk 'NR==2'`
localasn=`aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid" | grep -oPm1 "(?<=<asn>)[^<]+" | awk 'NR==1'`
remoteasn=`aws ec2 describe-vpn-connections --filters "Name=vpn-connection-id,Values=$vpnid" | grep -oPm1 "(?<=<asn>)[^<]+" | awk 'NR==2'`
host=`aws cloudformation describe-stacks --stack-name fortigate-vpn --query 'Stacks[0].Outputs[1].OutputValue' | sed "s/\"//g"`


# Echo the fortigate commands into a file

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
config router bgp
  set as $localasn
  set router-id $lgw
    config neighbor
        edit "$remip01"
            set description "vpn_0"
            set remote-as $remoteasn
        next
        edit "$remip02"
            set description "vpn_1"
            set remote-as $remoteasn
        next
    end
end
config firewall policy
    edit 0
        set srcintf "VPN"
        set dstintf "port2"
        set srcaddr all
        set dstaddr all
        set action accept
        set schedule always
        set service ALL
    next
    edit 0
        set srcintf "port2"
        set dstintf "VPN"
        set srcaddr all
        set dstaddr all
        set action accept
        set schedule always
        set service ALL
    next
end
" > $output01

# Echo filename and apply commands using ssh. Make sure key matches the one used in CF

echo "
The following files were created:

1. $output01

Now applying the commands...


"
ssh -T -i ~/.ssh/networks-test.pem admin@$host < $output01
echo "

VPN Config added. Check output above in case of errors.


"
