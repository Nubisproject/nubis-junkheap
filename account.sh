#!/bin/bash
#
# Crappy script to create VPCs and such in an aws account
#
# To create a new domain in inventory
# https://inventory.mozilla.org/en-US/mozdns/record/create/DOMAIN/
#     Soa: SOA for allizom.org
#     Name: ACCOUNT_NAME.nubis.allizom.org
# https://inventory.mozilla.org/en-US/mozdns/record/create/DOMAIN/
#     Soa: SOA for allizom.org
#     Name: REGION.ACCOUNT_NAME.nubis.allizom.org
# https://inventory.mozilla.org/en-US/mozdns/record/create/NS/
#     Domain: REGION.ACCOUNT_NAME.nubis.allizom.org
#     Server: 1 of 4 AWS NameServers for the HostedZones
#     Views:
#         check private
#         check public
#
# https://app.datadoghq.com/account/settings#integrations/amazon_web_services
#

#PROFILE='mozilla-sandbox'
PROFILE='nubis-lab'
#PROFILE='nubis-market'
#PROFILE='plan-b-ldap-master'
#PROFILE='plan-b-okta-ldap-gateway'
#PROFILE='plan-b-bugzilla'
#PROFILE='plan-b-akamai-edns-slave'
REGION='us-east-1'
#REGION='us-west-2'
NUBIS_PATH="/home/jason/projects/mozilla/projects/nubis"
VPC_TEMPLATE='vpc-account.template'

create_stack () {
    aws cloudformation create-stack --template-body file://${NUBIS_PATH}/nubis-vpc/$VPC_TEMPLATE --parameters file://${NUBIS_PATH}/nubis-vpc/parameters/parameters-${REGION}-${PROFILE}.json --capabilities CAPABILITY_IAM --profile $PROFILE --region $REGION --stack-name ${REGION}-vpc

    watch -n 1 "echo 'Container Stack'; aws cloudformation describe-stacks --region $REGION --profile $PROFILE --query 'Stacks[*].[StackName, StackStatus]' --output text --stack-name ${REGION}-vpc; echo \"\nStack Resources\"; aws cloudformation describe-stack-resources --region $REGION --profile $PROFILE --stack-name ${REGION}-vpc --query 'StackResources[*].[LogicalResourceId, ResourceStatus]' --output text"


    VPC_META_STACK=$(aws cloudformation describe-stack-resources --region $REGION --profile $PROFILE --stack-name "$REGION-vpc" --query 'StackResources[?LogicalResourceId==`VPCMetaStack`].PhysicalResourceId' --output text)
    echo -e "\nVPC Meta Stack Id:\n$VPC_META_STACK"

    LAMBDA_ROLL_ARN=$(aws cloudformation describe-stacks --region $REGION --profile $PROFILE --stack-name $VPC_META_STACK --query 'Stacks[*].Outputs[?OutputKey == `IamRollArn`].OutputValue' --output text)
    echo -e "\nLambda ARN:\n$LAMBDA_ROLL_ARN"

    ZONE_ID=$(aws cloudformation describe-stack-resources --region $REGION --profile $PROFILE --stack-name $VPC_META_STACK --query 'StackResources[?LogicalResourceId == `HostedZone`].PhysicalResourceId' --output text)
    echo -e "\nZone Id:\n$ZONE_ID"

    echo -e "\nUploading LookupStackOutputs Function"
    aws lambda upload-function --region $REGION --profile $PROFILE --function-name LookupStackOutputs --function-zip ${NUBIS_PATH}/nubis-stacks/lambda/LookupStackOutputs/LookupStackOutputs.zip --runtime nodejs --role ${LAMBDA_ROLL_ARN} --handler index.handler --mode event --timeout 10 --memory-size 128 --description 'Gather outputs from Cloudformation stacks to be used in other Cloudformation stacks'

    echo -e "\nUploading LookupNestedStackOutputs Function"
    aws lambda upload-function --region $REGION --profile $PROFILE --function-name LookupNestedStackOutputs --function-zip ${NUBIS_PATH}/nubis-stacks/lambda/LookupNestedStackOutputs/LookupNestedStackOutputs.zip --runtime nodejs --role ${LAMBDA_ROLL_ARN} --handler index.handler --mode event --timeout 10 --memory-size 128 --description 'Gather outputs from Cloudformation enviroment specific nested stacks to be used in other Cloudformation stacks'

    DATADOGACCESSKEY=$(aws cloudformation describe-stacks --region $REGION --profile $PROFILE --stack-name $VPC_META_STACK --query 'Stacks[*].Outputs[?OutputKey == `DatadogAccessKey`].OutputValue' --output text)
    DATADOGSECRETKEY=$(aws cloudformation describe-stacks --region $REGION --profile $PROFILE --stack-name $VPC_META_STACK --query 'Stacks[*].Outputs[?OutputKey == `DatadogSecretKey`].OutputValue' --output text)
    echo -e "\nDataDog Access Key: $DATADOGACCESSKEY\nDataDog SecretKey: $DATADOGSECRETKEY\n"

    aws route53 get-hosted-zone --region $REGION --profile $PROFILE  --id $ZONE_ID --query DelegationSet.NameServers --output table
}

update_stack () {
    aws cloudformation update-stack --template-body file://${NUBIS_PATH}/nubis-vpc/$VPC_TEMPLATE --parameters file://${NUBIS_PATH}/nubis-vpc/parameters/parameters-${REGION}-${PROFILE}.json --capabilities CAPABILITY_IAM --profile $PROFILE --region $REGION --stack-name ${REGION}-vpc

    watch -n 1 "echo 'Container Stack'; aws cloudformation describe-stacks --region $REGION --profile $PROFILE --query 'Stacks[*].[StackName, StackStatus]' --output text --stack-name ${REGION}-vpc; echo \"\nStack Resources\"; aws cloudformation describe-stack-resources --region $REGION --profile $PROFILE --stack-name ${REGION}-vpc --query 'StackResources[*].[LogicalResourceId, ResourceStatus]' --output text"
}

# http://aws.amazon.com/articles/5458758371599914
# http://docs.aws.amazon.com/cli/latest/reference/ec2/create-tags.html
create_dummy_connections () {
    if [ ${DUMMY_COUNT:-0} == 0 ]; then
        echo "ERROR: You must pass a number of connections to create"
        exit 1
    fi

    COUNT=0
    until [ $COUNT == $DUMMY_COUNT ]; do
        let COUNT=${COUNT}+1
        echo -n "Creating Dummy Customer Gateway $COUNT of $DUMMY_COUNT "
        CUSTOMER_GATEWAY_ID=$(aws ec2 create-customer-gateway --region $REGION --profile $PROFILE --type ipsec.1 --public-ip 192.2.1.$COUNT --bgp-asn 65000 --query '*.CustomerGatewayId' --output text)
        echo "(${CUSTOMER_GATEWAY_ID})"

#        echo -n "Creating Dummy Virtual Private (VPN) Gateway $COUNT of $DUMMY_COUNT "
#        VPN_GATEWAY_ID=$(aws ec2 create-vpn-gateway --region $REGION --profile $PROFILE --type ipsec.1 --query '*.VpnGatewayId' --output text)
#        echo "(${VPN_GATEWAY_ID})"

#        echo -n "Creating Dummy VPN-VPC Gateway Attachment $COUNT of $DUMMY_COUNT to "
#        DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --region $REGION --profile $PROFILE --query 'Vpcs[?IsDefault == `true`].VpcId' --output text)
#        VPN_VPC_ID=$(aws ec2 attach-vpn-gateway --vpn-gateway-id $VPN_GATEWAY_ID --vpc-id $DEFAULT_VPC_ID --query '*.VpcId' --output text)
#        echo "(${VPN_VPC_ID})"

#        echo -n "Ataching "
#        ATTACH_STATE=$(aws ec2 describe-vpn-gateways --region $REGION --profile $PROFILE --query "VpnGateways[?VpnGatewayId == \`$VPN_GATEWAY_ID\`].VpcAttachments[*].State" --output text)
#        while [ ${ATTACH_STATE:-NULL} != 'attached' ]; do
#            echo -n '.'
#            ATTACH_STATE=$(aws ec2 describe-vpn-gateways --region $REGION --profile $PROFILE --query "VpnGateways[?VpnGatewayId == \`$VPN_GATEWAY_ID\`].VpcAttachments[*].State" --output text)
#        done
#        echo -ne "\n"

lookup VPN_CONNECTION_ID from existing VPC

        echo -n "Creating Dummy VPN Connection $COUNT of $DUMMY_COUNT "
        VPN_CONNECTION_ID=$(aws ec2 create-vpn-connection --type ipsec.1 --customer-gateway-id $CUSTOMER_GATEWAY_ID --vpn-gateway-id $VPN_GATEWAY_ID --query '*.VpnConnectionId'  --output text)
        echo "(${VPN_CONNECTION_ID})"

        VPN_GATEWAY_STATE=$(aws ec2 describe-vpn-connections --region $REGION --profile $PROFILE --query "VpnConnections[?VpnConnectionId == \`$VPN_CONNECTION_ID\`].State"  --output text)
        echo -n "Pending "
        while [ ${VPN_GATEWAY_STATE:-NULL} != 'available' ]; do
            echo -n '.'
        VPN_GATEWAY_STATE=$(aws ec2 describe-vpn-connections --region $REGION --profile $PROFILE --query "VpnConnections[?VpnConnectionId == \`$VPN_CONNECTION_ID\`].State"  --output text)
        done
        echo -ne "\n"

    done
}

testing () {
VPN_CONNECTION_ID='vpn-60302f72'

aws ec2 describe-vpn-connections --region $REGION --profile $PROFILE --query "VpnConnections[?VpnConnectionId == \`$VPN_CONNECTION_ID\`].State"  --output text
}

# Grab and setup called options
while [ "$1" != "" ]; do
    case $1 in
        -v | --verbose )
            # For this simple script this will basicaly set -x
            set -x
        ;;
        -p | --path )
            # The path to where the nubis repositories are checked out
            NUBIS_PATH=$2
            shift
        ;;
        -P | --profile )
            # The profile to use to upload the files
            PROFILE=$2
            shift
        ;;
        -r | --region )
            # The region we are deploying to
            REGION=$2
            shift
        ;;
        -s | --sandbox )
            # We are working in the special sandbox account
            VPC_TEMPLATE='vpc-sandbox.template'
        ;;
         -h | -H | --help )
            echo -en "$0\n\n"
            echo -en "Usage: $0 [options] command [file]\n\n"
            echo -en "Commands:\n"
            echo -en "  create            Create account resources\n"
            echo -en "                      At a minimum creates a VPC stack\n"
            echo -en "                      You must have a parameters file set up already\n"
            echo -en "  update            Update account resources\n"
            echo -en "  create-dummies N  Create dummy VPN Connections\n"
            echo -en "                      Pass the number of dummy connections to create\n"
            echo -en "Options:\n"
            echo -en "  --help      -h    Print this help information and exit\n"
            echo -en "  --path      -p    Specify a path where your nubis repositories are checked out\n"
            echo -en "                      Defaults to '$NUBIS_PATH'\n"
            echo -en "  --profile   -P    Specify a profile to use when uploading the files\n"
            echo -en "                      Defaults to '$PROFILE'\n"
            echo -en "  --region    -r    Specify a region to deploy to\n"
            echo -en "                      Defaults to '$REGION'\n"
            echo -en "  --sandbox   -s    Only set if deploying to the stage account\n"
            echo -en "  --verbose   -v    Turn on verbosity, this should be set as the first argument\n"
            echo -en "                      Basically set -x\n\n"
            exit 0
        ;;
        create )
            create_stack
            GOT_COMMAND=1
        ;;
        update )
            update_stack
            GOT_COMMAND=1
        ;;
        create-dummies )
            DUMMY_COUNT=$2
            shift
            create_dummy_connections
            GOT_COMMAND=1
        ;;
        testing )
            testing
            GOT_COMMAND=1
        ;;
    esac
    shift
done

# If we did not get a valid command print the help message
if [ ${GOT_COMMAND:-0} == 0 ]; then
    $0 --help
fi

# fin
