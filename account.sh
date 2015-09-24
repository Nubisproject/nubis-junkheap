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
#PROFILE='nubis-lab'
#PROFILE='nubis-market'
#PROFILE='plan-b-ldap-master'
#PROFILE='plan-b-okta-ldap-gateway'
#PROFILE='plan-b-bugzilla'
#PROFILE='plan-b-akamai-edns-slave'
#REGION='us-east-1'
#REGION='us-west-2'
NUBIS_PATH="/home/jason/projects/mozilla/projects/nubis"

#declare -a PROFILES_ARRAY=( mozilla-sandbox nubis-lab nubis-market plan-b-ldap-master plan-b-okta-ldap-gateway plan-b-bugzilla plan-b-akamai-edns-slave )
declare -a PROFILES_ARRAY=( nubis-lab )
declare -a REGIONS_ARRAY=( us-east-1 us-west-2 )
declare -a ENVIRONMENTS_ARRAY=( admin stage prod )

create_stack () {
    # Detect if we are working in the sandbox and select the appropriate template
    if [ ${PROFILE} == 'mozilla-sandbox' ]; then
        VPC_TEMPLATE='vpc-sandbox.template'
    else
        VPC_TEMPLATE='vpc-account.template'
    fi
    STACK_NAME="${REGION}-vpc"

    aws cloudformation create-stack --template-body file://${NUBIS_PATH}/nubis-vpc/${VPC_TEMPLATE} --parameters file://${NUBIS_PATH}/nubis-vpc/parameters/parameters-${REGION}-${PROFILE}.json --capabilities CAPABILITY_IAM --profile ${PROFILE} --region ${REGION} --stack-name ${STACK_NAME}

    watch -n 1 "echo 'Container Stack'; aws cloudformation describe-stacks --region ${REGION} --profile ${PROFILE} --query 'Stacks[*].[StackName, StackStatus]' --output text --stack-name ${STACK_NAME}; echo \"\nStack Resources\"; aws cloudformation describe-stack-resources --region ${REGION} --profile ${PROFILE} --stack-name ${STACK_NAME} --query 'StackResources[*].[LogicalResourceId, ResourceStatus]' --output text"


    VPC_META_STACK=$(aws cloudformation describe-stack-resources --region ${REGION} --profile ${PROFILE} --stack-name ${STACK_NAME} --query 'StackResources[?LogicalResourceId==`VPCMetaStack`].PhysicalResourceId' --output text)
    echo -e "\nVPC Meta Stack Id:\n$VPC_META_STACK"

    LAMBDA_ROLL_ARN=$(aws cloudformation describe-stacks --region ${REGION} --profile ${PROFILE} --stack-name $VPC_META_STACK --query 'Stacks[*].Outputs[?OutputKey == `IamRollArn`].OutputValue' --output text)
    echo -e "\nLambda ARN:\n$LAMBDA_ROLL_ARN"

    ZONE_ID=$(aws cloudformation describe-stack-resources --region ${REGION} --profile ${PROFILE} --stack-name $VPC_META_STACK --query 'StackResources[?LogicalResourceId == `HostedZone`].PhysicalResourceId' --output text)
    echo -e "\nZone Id:\n$ZONE_ID"

    echo -e "\nUploading LookupStackOutputs Function"
    aws lambda upload-function --region ${REGION} --profile ${PROFILE} --function-name LookupStackOutputs --function-zip ${NUBIS_PATH}/nubis-stacks/lambda/LookupStackOutputs/LookupStackOutputs.zip --runtime nodejs --role ${LAMBDA_ROLL_ARN} --handler index.handler --mode event --timeout 10 --memory-size 128 --description 'Gather outputs from Cloudformation stacks to be used in other Cloudformation stacks'

    echo -e "\nUploading LookupNestedStackOutputs Function"
    aws lambda upload-function --region ${REGION} --profile ${PROFILE} --function-name LookupNestedStackOutputs --function-zip ${NUBIS_PATH}/nubis-stacks/lambda/LookupNestedStackOutputs/LookupNestedStackOutputs.zip --runtime nodejs --role ${LAMBDA_ROLL_ARN} --handler index.handler --mode event --timeout 10 --memory-size 128 --description 'Gather outputs from Cloudformation enviroment specific nested stacks to be used in other Cloudformation stacks'

    DATADOGACCESSKEY=$(aws cloudformation describe-stacks --region ${REGION} --profile ${PROFILE} --stack-name $VPC_META_STACK --query 'Stacks[*].Outputs[?OutputKey == `DatadogAccessKey`].OutputValue' --output text)
    DATADOGSECRETKEY=$(aws cloudformation describe-stacks --region ${REGION} --profile ${PROFILE} --stack-name $VPC_META_STACK --query 'Stacks[*].Outputs[?OutputKey == `DatadogSecretKey`].OutputValue' --output text)
    echo -e "\nDataDog Access Key: $DATADOGACCESSKEY\nDataDog SecretKey: $DATADOGSECRETKEY\n"

    aws route53 get-hosted-zone --region ${REGION} --profile ${PROFILE}  --id $ZONE_ID --query DelegationSet.NameServers --output table
}

update_stack () {
    # Detect if we are working in the sandbox and select the appropriate template
    if [ ${PROFILE} == 'mozilla-sandbox' ]; then
        VPC_TEMPLATE='vpc-sandbox.template'
    else
        VPC_TEMPLATE='vpc-account.template'
    fi
    STACK_NAME="${REGION}-vpc"

    echo -n " Updating \"${STACK_NAME}\" in \"${PROFILE}\" "
    $(aws cloudformation update-stack --template-body file://${NUBIS_PATH}/nubis-vpc/${VPC_TEMPLATE} --parameters file://${NUBIS_PATH}/nubis-vpc/parameters/parameters-${REGION}-${PROFILE}.json --capabilities CAPABILITY_IAM --profile ${PROFILE} --region ${REGION} --stack-name ${STACK_NAME} 2>&1) 2> /dev/null
    # Pause to let the status update before we start to check
    sleep 5
    # Wait here till the stack update is complete
    until [ ${STACK_STATE:-NULL} == 'CREATE_COMPLETE' ] || [ ${STACK_STATE:-NULL} == 'UPDATE_COMPLETE' ]; do
        echo -n '.'
        STACK_STATE=$(aws cloudformation describe-stacks --region ${REGION} --profile ${PROFILE} --query 'Stacks[*].[StackStatus]' --output text --stack-name ${STACK_NAME})
        sleep 2
    done
    echo -ne "\n"
    unset STACK_STATE
}

replace_jumphost () {
    STACK_NAME="jumphost-${ENVIRONMENT}"

    # Remove the known_hosts fingerprint for the jumphost
    JUMPHOST_NAME="jumphost.${ENVIRONMENT}.${REGION}.${PROFILE}.nubis.allizom.org"
    JUMPHOST_IP=$(dig +short ${JUMPHOST_NAME})
    if [ $(dig +short ${JUMPHOST_NAME} | grep -c ^) != 0 ]; then
        if [ $(ssh-keygen -F ${JUMPHOST_IP} | grep -c ^) != 0 ]; then
            $(ssh-keygen -qR ${JUMPHOST_IP} 2>&1) 2> /dev/null
        fi
    fi
    if [ $(ssh-keygen -F ${JUMPHOST_NAME} | grep -c ^) != 0 ]; then
        $(ssh-keygen -qR ${JUMPHOST_NAME} 2>&1) 2> /dev/null
    fi

    echo -n " Deleting \"${STACK_NAME}\" from \"${REGION}\" in \"${PROFILE}\" "
    $(aws cloudformation delete-stack --profile ${PROFILE} --region ${REGION} --stack-name ${STACK_NAME} 2>&1) 2> /dev/null
    # Pause to let the status update before we start to check
    sleep 5
    # Wait here till the stack delete is complete
    until [ ${RV:-NULL} == '255' ]; do
        echo -n '.'
        STACK_STATE=$(aws cloudformation describe-stacks --region ${REGION} --profile ${PROFILE} --query 'Stacks[*].[StackStatus]' --output text --stack-name ${STACK_NAME} 2>&1) 2> /dev/null
        RV=$?
        sleep 2
    done
    echo -ne "\n"
    unset STACK_STATE RV

    echo -n " Creating \"${STACK_NAME}\" for \"${REGION}\" in \"${PROFILE}\" "
    $(aws cloudformation create-stack --template-body "file://${NUBIS_PATH}/nubis-jumphost/nubis/cloudformation/main.json" --parameters "file://${NUBIS_PATH}/nubis-jumphost/nubis/cloudformation/parameters-${REGION}-${ENVIRONMENT}.json" --capabilities CAPABILITY_IAM  --profile ${PROFILE} --region ${REGION} --stack-name ${STACK_NAME} 2>&1) 2> /dev/null
    # Pause to let the status update before we start to check
    sleep 5
    # Wait here till the stack delete is complete
    until [ ${STACK_STATE:-NULL} == 'CREATE_COMPLETE' ] || [ ${STACK_STATE:-NULL} == 'UPDATE_COMPLETE' ]; do
        echo -n '.'
        STACK_STATE=$(aws cloudformation describe-stacks --region ${REGION} --profile ${PROFILE} --query 'Stacks[*].[StackStatus]' --output text --stack-name ${STACK_NAME})
        sleep 2
    done
    echo -ne "\n"
    unset STACK_STATE

    echo " Uploading ssh keys to \"${JUMPHOST_NAME}\""
    # Wait until we have dns resolution
    while [ ${COUNT:-0} == 0 ]; do
        COUNT=$(dig +short ${JUMPHOST_NAME} | grep -c ^)
    done
    # Wait until dns is updated with the new jumphost IP
    NEW_JUMPHOST_IP=$(dig +short ${JUMPHOST_NAME})
    until [ ${NEW_JUMPHOST_IP:-NULL} != ${JUMPHOST_IP:-NULL} ]; do
        NEW_JUMPHOST_IP=$(dig +short ${JUMPHOST_NAME})
    done
    JUMPHOST_IP=$(dig +short ${JUMPHOST_NAME})
    # Add the new known_hosts fingerprints before we attempt the upload to avoid the 'yes' dialoge
    $(ssh-keyscan -H ${JUMPHOST_IP} >> ~/.ssh/known_hosts 2>&1) 2> /dev/null
    $(ssh-keyscan -H ${JUMPHOST_NAME} >> ~/.ssh/known_hosts 2>&1) 2> /dev/null
    cat ${NUBIS_PATH}/nubis-junkheap/authorized_keys_admins.pub | ssh -oStrictHostKeyChecking=no ec2-user@${JUMPHOST_NAME} 'cat >> .ssh/authorized_keys'
    # Detect if we are working in the sandbox and upload devs ssh keys as well
    if [ ${PROFILE} == 'mozilla-sandbox' ]; then
        cat ${NUBIS_PATH}/nubis-junkheap/authorized_keys_devs_sandbox.pub | ssh -oStrictHostKeyChecking=no ec2-user@${JUMPHOST_NAME} 'cat >> .ssh/authorized_keys'
    fi
}

update_all_accounts () {
    for PROFILE in ${PROFILES_ARRAY[*]}; do
        for REGION in ${REGIONS_ARRAY[*]}; do
            echo -e "\n ### Updating account \"${PROFILE}\" in \"${REGION}\" ###\n"
            update_stack
            # If we are working in the sandbox we have only one custom environment
            if [ ${PROFILE} == 'mozilla-sandbox' ]; then
                ENVIRONMENT='sandbox'
                replace_jumphost
            # The nubis-market account does not have jumphosts ATM
            elif [ ${PROFILE} == 'nubis-market' ]; then
                echo " Not replacing jumphosts in the \"${PROFILE}\" account."
            else
                for ENVIRONMENT in ${ENVIRONMENTS_ARRAY[*]}; do
                    replace_jumphost
                done
            fi
        done
    done
}

# jd likes to have a testing function for, well for testing stuff.
testing () {
    echo "Testing"
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
            echo -en "                      Defaults to '${PROFILE}'\n"
            echo -en "  --region    -r    Specify a region to deploy to\n"
            echo -en "                      Defaults to '${REGION}'\n"
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
        update-all )
            update_all_accounts
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
