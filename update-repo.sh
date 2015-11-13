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
GITHUB_ORGINIZATION='tinnightcap'
#GITHUB_ORGINIZATION='nubisproject'
declare -a RELEASE_EXCLUDES=( nubis-elasticsearch nubis-elk nubis-ha-nat nubis-junkheap nubis-meta nubis-puppet-consul-do nubis-puppet-consul-replicate nubis-puppet-envconsul nubis-wrapper )
declare -a REPOSITORY_ARRAY

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

test_for_ghi () {
    TEST=$(which ghi 2>&1) 2> /dev/null
    if [ $? != 0 ]; then
        echo "hub must be installed and on your path!"
        echo "See: https://hub.github.com/"
        exit 1
    fi
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
         -h | -H | --help )
            echo -en "$0\n\n"
            echo -en "Usage: $0 [options] command [repository]\n\n"
            echo -en "Commands:\n"
            echo -en "  update [repo]     Update repository [repo]\n"
            echo -en "  update-all        Update all repositories\n"
            echo -en "Options:\n"
            echo -en "  --help      -h    Print this help information and exit\n"
            echo -en "  --path      -p    Specify a path where your nubis repositories are checked out\n"
            echo -en "                      Defaults to '${NUBIS_PATH}'\n"
            echo -en "  --login     -l    Specify a login to use when forking repositories\n"
            echo -en "                      Defaults to '${GITHUB_LOGIN}'\n"
            echo -en "  --verbose   -v    Turn on verbosity, this should be set as the first argument\n"
            echo -en "                      Basically set -x\n\n"
            exit 0
        ;;
        update )
            REPOSITORY=$2
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
            file_release_issues ${RELEASE}
            GOT_COMMAND=1
        ;;
        create-milestones )
            RELEASE="${2}"
            create_milestones ${RELEASE}
            GOT_COMMAND=1
        ;;
        testing )
#            testing $2
            RET=$(testing "$2" "nubis-base")
            echo "RET: $RET"
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
