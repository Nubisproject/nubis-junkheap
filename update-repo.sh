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

NUBIS_PATH="/home/jason/projects/mozilla/projects/nubis"

declare -a REPOSITORY_ARRAY=( nubis-base nubis-builder nubis-ci nubis-consul nubis-docs nubis-dpaste nubis-elasticsearch nubis-elk nubis-fluent-collector nubis-fluent-collector nubis-jumphost nubis-junkheap nubis-mediawiki nubis-meta nubisproject.github.io nubis-proxy nubis-puppet-configuration nubis-puppet-consul-do nubis-puppet-consul-replicate nubis-puppet-discovery nubis-puppet-envconsul nubis-puppet-storage nubis-skel nubis-stacks nubis-storage nubis-wrapper )

update_repository () {
    if [ ${REPOSITORY:-NULL} == 'NULL' ]; then
        echo "You must suply a repository!"
        exit 1
    fi
    echo -e "\n #### Updating repository $REPOSITORY ####"
    cd $NUBIS_PATH/$REPOSITORY
    git checkout master
    git fetch origin
    git rebase origin/master
    if [ $? != 0 ]; then
        echo -e "\n !!!!!!!! Repository '$REPOSITORY' not updated! !!!!!!!!\n"
    else
        git push
    fi
}

update_all_repositories () {
    for REPOSITORY in ${REPOSITORY_ARRAY[*]}; do
       update_repository $REPOSITORY
    done
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
            echo -en "Usage: $0 [options] command [repository]\n\n"
            echo -en "Commands:\n"
            echo -en "  update [repo]     Update repository [repo]\n"
            echo -en "  update-all        Update all repositories\n"
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
