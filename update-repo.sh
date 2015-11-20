#!/bin/bash
#
# git clone git@github.com:tinnightcap/nubis-proxy.git
# git remote -vv
#    origin  git@github.com:tinnightcap/nubis-proxy.git (fetch)
#    origin  git@github.com:tinnightcap/nubis-proxy.git (push)
# git remote rename origin tinnightcap
# git remote add -f origin git@github.com:Nubisproject/nubis-proxy.git
# git remote -vv
#    origin  git@github.com:Nubisproject/nubis-proxy.git (fetch)
#    origin  git@github.com:Nubisproject/nubis-proxy.git (push)
#    tinnightcap     git@github.com:tinnightcap/nubis-proxy.git (fetch)
#    tinnightcap     git@github.com:tinnightcap/nubis-proxy.git (push)
# git branch -vv
#    * master 017748c [tinnightcap/master] Initial commit
# git checkout --track origin/master -b originmaster
# git branch -vv
#      master       017748c [tinnightcap/master] Initial commit
#    * originmaster 017748c [origin/master] Initial commit
#

NUBIS_PATH='/home/jason/projects/mozilla/projects/nubis'
GITHUB_LOGIN='tinnightcap'
#GITHUB_ORGINIZATION='tinnightcap'
GITHUB_ORGINIZATION='nubisproject'
PROFILE='default'
set -o pipefail

# List of repositories that will be excluded form the release
declare -a RELEASE_EXCLUDES=( nubis-elasticsearch nubis-elk nubis-ha-nat nubis-junkheap nubis-meta nubis-puppet-consul-do nubis-puppet-consul-replicate nubis-puppet-envconsul nubis-wrapper nubis-mediawiki nubis-jumphost nubis-dpaste )

# List of infrastructure projects that need to be rebuilt from nubis-base during a release
declare -a INFRASTRUCTURE_ARRAY=( nubis-ci nubis-consul nubis-dpaste nubis-fluent-collector nubis-jumphost nubis-mediawiki nubis-proxy nubis-skel nubis-storage )

declare -a REPOSITORY_ARRAY

test_for_ghi () {
    TEST=$(which ghi 2>&1) 2> /dev/null
    if [ $? != 0 ]; then
        echo "hub must be installed and on your path!"
        echo "See: https://hub.github.com/"
        exit 1
    fi
}

test_for_nubis_builder () {
    TEST=$(which nubis-builder 2>&1) 2> /dev/null
    if [ $? != 0 ]; then
        echo "nubis-builder must be installed and on your path!"
        echo "See: https://github.com/Nubisproject/nubis-builder#builder-quick-start"
        exit 1
    fi
}

test_for_sponge () {
    TEST=$(which sponge 2>&1) 2> /dev/null
    if [ $? != 0 ]; then
        echo "sponge must be installed and on your path!"
        echo "sponge is provided by the 'moreutils' package on ubuntu"
        exit 1
    fi
}

test_for_jq () {
    TEST=$(which jq 2>&1) 2> /dev/null
    if [ $? != 0 ]; then
        echo "jq must be installed and on your path!"
        exit 1
    fi
}

test_for_github_changelog_generator () {
    TEST=$(which github_changelog_generator 2>&1) 2> /dev/null
    if [ $? != 0 ]; then
        echo "github_changelog_generator must be installed and on your path!"
        exit 1
    fi
}

get_repositories () {
    # Gather the list of repositories in the nubisproject from GitHub
    REPOSITORY_LIST=$(curl -s https://api.github.com/orgs/nubisproject/repos | jq -r '.[].name' | sort)

    # Format the list into an array
    for REPO in ${REPOSITORY_LIST}; do
        REPOSITORY_ARRAY=( ${REPOSITORY_ARRAY[*]} $REPO )
    done
}

clone_repository () {
    TEST=$(hub --version 2>&1) 2> /dev/null
    if [ $? != 0 ]; then
        echo "hub must be installed and on your path!"
        echo "See: https://hub.github.com/"
        exit 1
    fi
    if [ ${REPOSITORY:-NULL} == 'NULL' ]; then
        echo "You must specify a repository!"
        exit 1
    fi
    if [ -d ${NUBIS_PATH}/${REPOSITORY} ]; then
        echo "Directory \"${NUBIS_PATH}/${REPOSITORY}\" already exists. Aborting!"
        exit 1
    fi
    cd ${NUBIS_PATH}
    SSH_URL=$(curl -s https://api.github.com/repos/nubisproject/${REPOSITORY} | jq -r '.ssh_url')
    git clone ${SSH_URL}
    cd ${REPOSITORY}
    hub fork
    git checkout --track origin/master -b originmaster
    git branch -d master
    git checkout --track ${GITHUB_LOGIN}/master -b master
}

update_repository () {
    if [ ${REPOSITORY:-NULL} == 'NULL' ]; then
        echo "You must specify a repository!"
        exit 1
    fi
    if [ ! -d ${NUBIS_PATH}/${REPOSITORY} ]; then
        echo " Repository \"${REPOSITORY}\" not found... Attempting to clone locally."
        clone_repository ${REPOSITORY}
    fi
    echo -e " #### Updating repository ${REPOSITORY} ####"
    cd ${NUBIS_PATH}/${REPOSITORY}
    git checkout master
    git fetch origin
    git rebase origin/master
    if [ $? != 0 ]; then
        echo -e "\n !!!!!!!! Repository '${REPOSITORY}' not updated! !!!!!!!!\n"
    else
        git push
    fi
}

update_all_repositories () {
    get_repositories
    COUNT=1
    for REPOSITORY in ${REPOSITORY_ARRAY[*]}; do
        echo -e "\n Updating ${COUNT} of ${#REPOSITORY_ARRAY[*]} repositories"
        update_repository ${REPOSITORY}
        let COUNT=${COUNT}+1
    done
}

get_set_milestone () {
    milestone_open () {
        ghi milestone --list -- "${GITHUB_ORGINIZATION}"/"${__REPOSITORY}" | grep "${__MILESTONE}" | cut -d':' -f 1 | sed -e 's/^[[:space:]]*//'
    }
    milestone_closed () {
        ghi milestone --list --closed -- "${GITHUB_ORGINIZATION}"/"${__REPOSITORY}" | grep "${__MILESTONE}" | cut -d':' -f 1 | sed -e 's/^[[:space:]]*//'
    }
    test_for_ghi
    local __MILESTONE="${1}"
    local __REPOSITORY="${2}"
    # First check to see if we have an open milestone
    __MILESTONE_NUMBER=$(milestone_open)
    if [ "${__MILESTONE_NUMBER:-NULL}" != 'NULL' ]; then
        echo "${__MILESTONE_NUMBER}"
        return
    fi
    # Next check to see if we have the milestone but it is closed
    __MILESTONE_NUMBER=$(milestone_closed)
    if [ "${__MILESTONE_NUMBER:-NULL}" != 'NULL' ]; then
        echo "${__MILESTONE_NUMBER}"
        return
    fi
    # Finally create the milestone as it does not appear to exist
    __MILESTONE_NUMBER=$(ghi milestone -m "${__MILESTONE}" -- "${GITHUB_ORGINIZATION}"/"${__REPOSITORY}"  | cut -d'#' -f 2 | cut -d' ' -f 1)
    echo "${__MILESTONE_NUMBER}"
    return
}

create_milestones () {
    local __RELEASE="${1}"
    if [ ${__RELEASE:-NULL} == 'NULL' ]; then
        echo "Relesae nubber required"
        $0 help
        exit 1
    fi
    get_repositories
    local __COUNT=1
    for REPOSITORY in ${REPOSITORY_ARRAY[*]}; do
        if [[ " ${RELEASE_EXCLUDES[@]} " =~ " ${REPOSITORY} " ]]; then
            echo -e "\n Skipping \"${REPOSITORY}\" as it is in the excludes list. (${__COUNT} of ${#REPOSITORY_ARRAY[*]})"
            let COUNT=${COUNT}+1
        else
            echo -e "\n Creating milestone in \"${REPOSITORY}\". (${__COUNT} of ${#REPOSITORY_ARRAY[*]})"
            local __RELEASE="${1}"
            local __MILESTONE=$(get_set_milestone "${__RELEASE}" "${REPOSITORY}")
            echo " Got milestone number \"${__MILESTONE}\"."
            let __COUNT=${__COUNT}+1
        fi
    done
    unset REPOSITORY
}

file_issue () {
    test_for_ghi
    local __REPOSITORY="${1}"
    local __ISSUE_TITLE="${2}"
    local __ISSUE_BODY="${3}"
    local __MILESTONE="${4}"
    ghi open --message "${__ISSUE_BODY}" "${__ISSUE_TITLE}" --milestone "${__MILESTONE}" -- "${GITHUB_ORGINIZATION}"/"${__REPOSITORY}"
}

file_release_issues () {
    local __RELEASE="${1}"
    if [ ${__RELEASE:-NULL} == 'NULL' ]; then
        echo "Relesae number required"
        $0 help
        exit 1
    fi
    get_repositories
    local __COUNT=1
    for REPOSITORY in ${REPOSITORY_ARRAY[*]}; do
        if [[ " ${RELEASE_EXCLUDES[@]} " =~ " ${REPOSITORY} " ]]; then
            echo -e "\n Skipping \"${REPOSITORY}\" as it is in the excludes list. (${__COUNT} of ${#REPOSITORY_ARRAY[*]})"
            let COUNT=${COUNT}+1
        else
            echo -e "\n Filing release issue in \"${REPOSITORY}\". (${__COUNT} of ${#REPOSITORY_ARRAY[*]})"
            local __RELEASE="${1}"
            local __ISSUE_TITLE="Tag ${__RELEASE} release"
            local __ISSUE_BODY="Tag a release of the ${REPOSITORY} repository for the ${__RELEASE} release of the Nubis project."
            local __MILESTONE=$(get_set_milestone "${__RELEASE}" "${REPOSITORY}")
            file_issue "${REPOSITORY}" "${__ISSUE_TITLE}" "${__ISSUE_BODY}" "${__MILESTONE}"
            let __COUNT=${__COUNT}+1
        fi
    done
    unset REPOSITORY
}

merge_changes () {
    local __REPOSITORY=${1}
    echo "Merge pull-request? [y/N]"
    read CONTINUE
    if [ ${CONTINUE:-n} == "Y" ] || [ ${CONTINUE:-n} == "y" ]; then
        # Switch to the originmaster branch and merge the pull-request
        cd "${NUBIS_PATH}/${__REPOSITORY}" && git checkout originmaster
        cd "${NUBIS_PATH}/${__REPOSITORY}" && git pull
        cd "${NUBIS_PATH}/${__REPOSITORY}" && git merge --no-ff master -m "Merge branch 'master' into originmaster"
        cd "${NUBIS_PATH}/${__REPOSITORY}" && git push origin HEAD:master
        cd "${NUBIS_PATH}/${__REPOSITORY}" && git checkout master
    fi
}

check_in_changes () {
    local __REPOSITORY=${1}
    local __MESSAGE=${2}
    local __FILE=${3}
    if [ ${__FILE:-NULL} == 'NULL' ]; then
        local __FILE='.'
    fi
    echo "Check in changes for \"${__REPOSITORY}\" to: \"${__FILE}\"? [Y/n]"
    read CONTINUE
    if [ ${CONTINUE:-y} == "Y" ] || [ ${CONTINUE:-y} == "y" ]; then
        cd "${NUBIS_PATH}/${__REPOSITORY}" && git add ${__FILE}
        cd "${NUBIS_PATH}/${__REPOSITORY}" && git commit -m "${__MESSAGE}"
        cd "${NUBIS_PATH}/${__REPOSITORY}" && git push
        # GitHub is sometimes a bit slow here
        sleep 3
        cd "${NUBIS_PATH}/${__REPOSITORY}" && hub pull-request -m "${__MESSAGE}"

        merge_changes "${__REPOSITORY}"
    fi
}

build_instructions () {
    echo "RELEASE='v1.0.1'"
    echo "$0 update-all"
    echo "$0 --profile nubis-market upload-stacks \${RELEASE}"
    echo "$0 build-infrastructure \${RELEASE}"
    echo "$0 release-all \${RELEASE}"
}

# Upload nubis-stacks to release folder
upload_stacks () {
    local __RELEASE="${1}"
    if [ ${__RELEASE:-NULL} == 'NULL' ]; then
        echo "Relesae number required"
        $0 help
        exit 1
    fi

    test_for_jq
    test_for_sponge

    declare -a TEMPLATE_ARRAY
    # Gather the list of templates from nubis-stacks
    TEMPLATE_LIST=$(ls ${NUBIS_PATH}/nubis-stacks/*.template)
    # Format the list into an array
    for TEMPLATE in ${TEMPLATE_LIST}; do
        TEMPLATE_ARRAY=( ${TEMPLATE_ARRAY[*]} $TEMPLATE )
    done
    unset TEMPLATE

    # Gather the list of VPC templates from nubis-stacks
    TEMPLATE_LIST=$(ls ${NUBIS_PATH}/nubis-stacks/vpc/*.template)
    # Format the list into an array
    for TEMPLATE in ${TEMPLATE_LIST}; do
        TEMPLATE_ARRAY=( ${TEMPLATE_ARRAY[*]} $TEMPLATE )
    done
    unset TEMPLATE

    local __COUNT=1
    for TEMPLATE in ${TEMPLATE_ARRAY[*]}; do
        echo -e "Updating StacksVersion in \"${TEMPLATE}\". (${__COUNT} of ${#TEMPLATE_ARRAY[*]})"
        cat "${TEMPLATE}" | jq ".Parameters.StacksVersion.Default|=\"${__RELEASE}\"" | sponge "${TEMPLATE}"
        let __COUNT=${__COUNT}+1
    done
    unset TEMPLATE

    cd ${NUBIS_PATH}/nubis-stacks && bin/upload_to_s3 --profile ${PROFILE} --path "${__RELEASE}" push
    if [ $? != '0' ]; then
        echo "Uploads for ${__RELEASE} failed."
        echo "Aborting....."
        exit 1
    fi
    check_in_changes 'nubis-stacks' "Update StacksVersion for ${RELEASE} release"
}

# Update StacksVersion to the current release
edit_main_json () {
    local __RELEASE="${1}"
    local __REPOSITORY="${2}"
    if [ ${__RELEASE:-NULL} == 'NULL' ]; then
        echo "Relesae number required"
        $0 help
        exit 1
    fi
    test_for_jq
    test_for_sponge
    # Necessary to skip older repositories that are still using Terraform for deployments
    #+ Just silently skip the edit
    local __FILE="${NUBIS_PATH}/${__REPOSITORY}/nubis/cloudformation/main.json"
    if [ -f "${__FILE}" ]; then
        echo -e "Updating StacksVersion in \"${__FILE}\"."
        cat "${__FILE}" | jq ".Parameters.StacksVersion.Default|=\"${__RELEASE}\"" | sponge "${__FILE}"
        check_in_changes "${__REPOSITORY}" "Update StacksVersion for ${RELEASE} release" "${__FILE}"
    fi
}

# This is a special edit to update an AMI mapping in nubis-storage and copy that template to nubis-stacks
edit_storage_template () {
    local _RELEASE="${1}"
    local _US_EAST_1="${2}"
    local _US_WEST_2="${3}"
    local _FILE="${NUBIS_PATH}/nubis-storage/nubis/cloudformation/main.json"
    cat "${_FILE}" |\
    jq ".Mappings.AMIs.\"us-west-2\".AMI |=\"${_US_WEST_2}\"" |\
    jq ".Mappings.AMIs.\"us-east-1\".AMI |=\"${_US_EAST_1}\"" |\
    sponge "${__FILE}"

    check_in_changes 'nubis-storage' "Update storage AMI Ids for ${_RELEASE} release" 'nubis/cloudformation/main.json'

    # Copy the storage template to nubis-stacks as the templates should remain identical
    cp "${_FILE}" "${NUBIS_PATH}/nubis-stacks/storage.template"

    check_in_changes 'nubis-stacks' "Update storage AMI Ids for ${_RELEASE} release" 'storage.template'

    echo "Uploading updated storage.template to S3."
    cd ${NUBIS_PATH}/nubis-stacks && bin/upload_to_s3 --profile ${PROFILE} --path "${_RELEASE}" push storage.template
}

# Build new AMIs for the named repository
build_amis () {
    local _RELEASE="${1}"
    local _REPOSITORY="${2}"
    if [ ${_RELEASE:-NULL} == 'NULL' ]; then
        echo "Relesae number required"
        $0 help
        exit 1
    fi
    if [ ${_REPOSITORY:-NULL} == 'NULL' ]; then
        echo "Repository required"
        $0 help
        exit 1
    fi
    test_for_nubis_builder
    edit_main_json "${_RELEASE}" "${_REPOSITORY}"
    echo "Running nubis-builder...."
    exec 5>&1
    OUTPUT=$(cd "${NUBIS_PATH}/${_REPOSITORY}" && nubis-builder build | tee >(cat - >&5))
    if [ $? != '0' ]; then
        echo "Build for ${_REPOSITORY} failed. Contine? [y/N]"
        read CONTINUE
        if [ ${CONTINUE:-n} == "N" ] || [ ${CONTINUE:-n} == "n" ]; then
            echo "Aborting....."
            exit 1
        fi
        continue
    fi
    exec 5>&-
    # nubis-builder outputs the AMI IDs to a file. Lets check it in here
    # Lets blow away the silly project.json updates first
    cd "${NUBIS_PATH}/${_REPOSITORY}" && git checkout . 'nubis/builder/project.json'
    check_in_changes "${_REPOSITORY}" "Update AMI IDs file for ${RELEASE} release" 'nubis/builder/AMIs'

    # Special hook for nubis-storage
    if [ ${_REPOSITORY:-NULL} == 'nubis-storage' ]; then
        local _US_EAST_1=$(echo ${OUTPUT} | tail --quiet --lines=2 | grep 'us-east-1' | cut -d ':' -f 2 | sed -e 's/^[[:space:]]*//')
        local _US_WEST_2=$(echo ${OUTPUT} | tail --quiet --lines=2 | grep 'us-west-2' | cut -d ':' -f 2 | sed -e 's/^[[:space:]]*//')
        edit_storage_template "${_RELEASE}" "${_US_EAST_1}" "${_US_WEST_2}"
    fi
}

build_infrastructure_amis () {
    local _RELEASE="${1}"
    if [ ${_RELEASE:-NULL} == 'NULL' ]; then
        echo "Relesae number required"
        $0 help
        exit 1
    fi
    # Build a fresh copy of nubis-base first
    echo -e "\nBuilding AMIs for \"nubis-base\"."
    build_amis "${_RELEASE}" 'nubis-base'
    # Next build all of the infrastructure components form the fresh nubis-base
    local _COUNT=1
    for REPOSITORY in ${INFRASTRUCTURE_ARRAY[*]}; do
        if [[ " ${RELEASE_EXCLUDES[@]} " =~ " ${REPOSITORY} " ]]; then
            echo -e "\n Skipping \"${REPOSITORY}\" as it is in the excludes list. (${_COUNT} of ${#INFRASTRUCTURE_ARRAY[*]})"
            let COUNT=${_COUNT}+1
        else
            echo -e "\n Building AMIs for \"${REPOSITORY}\". (${_COUNT} of ${#INFRASTRUCTURE_ARRAY[*]})"
            build_amis "${_RELEASE}" "${REPOSITORY}"
            let _COUNT=${_COUNT}+1
        fi
    done
    unset REPOSITORY
}

release_repository () {
    local _RELEASE="${1}"
    local _REPOSITORY="${2}"
    if [ ${_RELEASE:-NULL} == 'NULL' ]; then
        echo "Relesae number required"
        $0 help
        exit 1
    fi
    if [ ${_REPOSITORY:-NULL} == 'NULL' ]; then
        echo "Repository required"
        $0 help
        exit 1
    fi
    if [ ${#CHANGELOG_GITHUB_TOKEN} == 0 ]; then
        echo 'You must have $CHANGELOG_GITHUB_TOKEN set'
        echo 'https://github.com/skywinder/github-changelog-generator#github-token'
        exit 1
    fi
    cd ${NUBIS_PATH}/${_REPOSITORY}
    
    # Update the CHANGELOG and make a pull-request, rebasing first to ensure a clean repository
    test_for_github_changelog_generator
    git checkout master
    git fetch origin
    git rebase origin/master
    github_changelog_generator --future-release ${_RELEASE} ${GITHUB_ORGINIZATION}/${_REPOSITORY}
    git add CHANGELOG.md
    git commit -m "Update CHANGELOG for ${_RELEASE} release"
    git push
    # GitHub is sometimes a bit slow here
    sleep 3
    hub pull-request -m "Update CHANGELOG for ${_RELEASE} release"

    # Switch to the originmaster branch, merge the pull-request and then tag the release
    git checkout originmaster
    git pull
    git merge --no-ff master -m "Merge branch 'master' into originmaster"
    git push origin HEAD:master
    git tag -s ${_RELEASE} -m"Signed ${_RELEASE} release"
    git push --tags
    # GitHub is sometimes a bit slow here
    sleep 3
    curl -i -H "Authorization: token ${CHANGELOG_GITHUB_TOKEN}" --request POST --data "{\"tag_name\": \"${_RELEASE}\"}" https://api.github.com/repos/${GITHUB_ORGINIZATION}/${_REPOSITORY}/releases
    git checkout master
}

release_all_repositories () {
    local _RELEASE="${1}"
    if [ ${_RELEASE:-NULL} == 'NULL' ]; then
        echo "Relesae number required"
        $0 help
        exit 1
    fi
    get_repositories
    local _COUNT=1
    for REPOSITORY in ${REPOSITORY_ARRAY[*]}; do
        if [[ " ${RELEASE_EXCLUDES[@]} " =~ " ${REPOSITORY} " ]]; then
            echo -e "\n Skipping \"${REPOSITORY}\" as it is in the excludes list. (${_COUNT} of ${#REPOSITORY_ARRAY[*]})"
            let _COUNT=${_COUNT}+1
        else
            echo -e "\n Releasing repository \"${REPOSITORY}\". (${_COUNT} of ${#REPOSITORY_ARRAY[*]})"
            local _RELEASE="${1}"
            release_repository "${_RELEASE}" "${REPOSITORY}"
            let _COUNT=${_COUNT}+1
        fi
    done
    unset REPOSITORY
}

testing () {
    get_repositories
    echo ${REPOSITORY_ARRAY[*]}
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
        -l | --login )
            # The github login to fork new repositories against
            GITHUB_LOGIN=$2
            shift
        ;;
        -P | --profile )
            # The profile to use to upload the files
            PROFILE=$2
            shift
        ;;
         -h | -H | --help )
            echo -en "$0\n\n"
            echo -en "Usage: $0 [options] command [repository]\n\n"
            echo -en "Commands:\n"
            echo -en "  update [repo]                 Update repository [repo]\n"
            echo -en "  update-all                    Update all repositories\n"
            echo -en "  file-release [rel]            File all release issues in GitHub\n"
            echo -en "  create-milestones [rel]       Create all milestones in Github\n"
            echo -en "  upload-stacks [rel]           Upload nested stacks to S3\n"
            echo -en "  build-infrastructure [rel]    Build all infrastructure components\n"
            echo -en "  release-all [rel]             Release all ${GITHUB_ORGINIZATION} repositories\n"
            echo -en "  build                         Echo build steps\n\n"
            echo -en "Options:\n"
            echo -en "  --help      -h    Print this help information and exit\n"
            echo -en "  --path      -p    Specify a path where your nubis repositories are checked out\n"
            echo -en "                      Defaults to '${NUBIS_PATH}'\n"
            echo -en "  --login     -l    Specify a login to use when forking repositories\n"
            echo -en "                      Defaults to '${GITHUB_LOGIN}'\n"
            echo -en "  --profile   -P    Specify a profile to use when uploading the files\n"
            echo -en "                      Defaults to '$PROFILE'\n"
            echo -en "  --verbose   -v    Turn on verbosity, this should be set as the first argument\n"
            echo -en "                      Basically set -x\n\n"
            exit 0
        ;;
        update )
            REPOSITORY="${2}"
            shift
            update_repository
            GOT_COMMAND=1
        ;;
        update-all )
            update_all_repositories
            GOT_COMMAND=1
        ;;
        file-release )
            RELEASE="${2}"
            shift
            file_release_issues ${RELEASE}
            GOT_COMMAND=1
        ;;
        create-milestones )
            RELEASE="${2}"
            shift
            create_milestones ${RELEASE}
            GOT_COMMAND=1
        ;;
        upload-stacks )
            RELEASE="${2}"
            shift
            upload_stacks ${RELEASE}
            GOT_COMMAND=1
        ;;
        build-infrastructure )
            RELEASE="${2}"
            shift
            build_infrastructure_amis ${RELEASE}
            GOT_COMMAND=1
        ;;
        release-all )
            RELEASE="${2}"
            shift
            release_all_repositories ${RELEASE}
            GOT_COMMAND=1
        ;;
        build )
            build_instructions
            GOT_COMMAND=1
        ;;
        testing )
            testing $2
#            RET=$(testing "$2" "nubis-base")
#            echo "RET: $RET"
            shift
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
