#!/bin/bash

FILE=$1
if [ ${#1} == 0 ]; then
    if [ -f 'nubis/terraform/main.tf' ]; then
        FILE='nubis/terraform/main.tf'
    else
        echo "ERROR: You must specify the location of your 'main.tf' file."
        echo "USAGE: $0 path/to/main.tf"
        exit 1
    fi
fi

echo '|Resource Type|Resource Title|Code Location|'
echo '|-------------|--------------|-------------|'

COUNT=0
RESOURCE_COUNT=0
while read -r LINE; do
    case "$LINE" in
        resource* )
            ((RESOURCE_COUNT++))
            ((COUNT++))
            RESOURCE_TYPE=$(echo $LINE | cut -d' ' -f 2 | cut -d'"' -f 2 | cut -d'"' -f 1)
            RESOURCE_NAME=$(echo $LINE | cut -d' ' -f 3 | cut -d'"' -f 2 | cut -d'"' -f 1)
            LINE_LINK="[$FILE#L$COUNT]($FILE#L$COUNT)"
            echo "|$RESOURCE_TYPE|$RESOURCE_NAME|$LINE_LINK|"
        ;;
        * )
            ((COUNT++))
        ;;
    esac
done < "$FILE"

#echo "Resource count: $RESOURCE_COUNT"

# fin
