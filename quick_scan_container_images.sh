#!/bin/bash

quay_oauth_api_key="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
quay_registry_domain="quay.xxxxxxxx.bos2.lab"
preflight_image_scan_result_csv="preflight_image_scan_result.csv"

print_help() {
    echo "------------------------------------------------------------------------------------------------------------------------"
    echo "Usage: $0 -rn|--repo-ns <org_name|user_name> -cp|--cnf-prefix <common_image_name> -t|--tag-type <name|digest> -tk|--api-token <xxxxxx> -fq|--fqdn <quay.io> -ft|--filter <filter_me>"
    echo "Usage: $0 [-h | --help]"
    echo "Usage Ex1: $0 -rn ava -cp \"global-|specific\" -tk xxxxxx -fq quay.io -t name -ft \"existed_image|tested_image\""
    echo "Usage Ex2: $0 --repo-ns avareg_5gc --cnf-prefix global- --tag-type name --fqdn quay.io"
    echo "Usage Ex3: $0 --repo-ns avareg_5gc --cnf-prefix global- --api-token xxxxx --fqdn quay.io"
    echo "Usage Ex4: $0 --repo-ns avareg_5gc --cnf-prefix global-"
    echo ""
    echo "Note: tag-type and log-type can be excluded from argument"
    echo "Note1: if quay_oauth_api_key and quay_registry_domain are defined on line #3&4 then use Ex4 to as usage"
    echo ""
    echo "
    -rn|--repo-ns        :  An organization or user name e.g avareg_5gc or avu0
    -cp|--cnf-prefix     :  Is CNF image prefix e.g. global-amf-rnic or using wildcard
                            It also uses more one prefix e.g. \"global|non-global\"

    -t|--tag-type        :  Image Tag Type whether it requires to use tag or digest name, preferred tag name
                            If name or digest argument is omitted it uses default tag name

    -fq|--fqdn           :  Private registry fqdn/host e.g quay.io

    -tk|--api-token      :  Bearer Token that created by Registry Server Admin from application->oauth-token
 
    -ft|--filter         :  If you want to exclude images or unwanted e.g. chartrepo or tested-images, then
                            pass to script argument like this:
                            $0 -rn ava -cp global- -t name -ft \"existed_image|tested_image\"
    "
    echo "------------------------------------------------------------------------------------------------------------------------"
    exit 0
}
for i in "$@"; do
    case $i in
    -rn | --repo-ns)
        if [ -n "$2" ]; then
            REPO_NS="$2"
            shift 2
            continue
        fi
        ;;
    -cp | --cnf-prefix)
        if [ -n "$2" ]; then
            CNF_PREFIX="$2"
            shift 2
            continue
        fi
        ;;
    -t | --tag-type)
        if [ -n "$2" ]; then
            TAG_TYPE="$2"
            shift 2
            continue
        fi
        ;;
    -fq | --fqdn)
        if [ -n "$2" ]; then
            FQDN="$2"
            shift 2
            continue
        fi
        ;;
    -tk | --api-token)
        if [ -n "$2" ]; then
            API_TOKEN="$2"
            shift 2
            continue
        fi
        ;;
    -ft | --filter)
        if [ -n "$2" ]; then
            FILTER="$2"
            shift 2
            continue
        fi
        ;;
    -h | -\? | --help)
        print_help
        shift #
        ;;
    *)
        # unknown option
        ;;
    esac
done

#Note: tag-type and log-type can be excluded from argument#
if [[ "$REPO_NS" == "" || "$CNF_PREFIX" == "" ]]; then
    print_help
fi

if [[ "$TAG_TYPE" == "" ]]; then
    TAG_TYPE="name"
fi

#if filter arg is empty, then we will filter chartrepo
if [[ "$FILTER" == "" ]]; then
    FILTER="chartrepo"
fi

if [[ "$FQDN" == "" ]]; then
    FQDN=$(echo $quay_registry_domain)
fi

echo "FQDN: $FQDN"

if [[ "$API_TOKEN" == "" ]]; then
    API_TOKEN=$(echo ${quay_oauth_api_key})
fi

#check if requirement files are existed
file_exists() {
    [ -z "${1-}" ] && bye Usage: file_exists name.
    ls "$1" >/dev/null 2>&1
}
# Prints all parameters and exits with the error code.
bye() {
    log "$*"
    exit 1
}

# Prints all parameters to stdout, prepends with a timestamp.
log() {
    printf '%s %s\n' "$(date +"%Y%m%d-%H:%M:%S")" "$*"
}

rename_file() {
    # Check if the filename argument is provided
    if [ -z "$1" ]; then
        log "Usage: rename_file old_filename new_filename"
        return 1
    fi

    # Check if the file exists
    if [ ! -f "$1" ]; then
        log "Error: file '$1' does not exist" >/dev/null 2>&1
        return 1
    fi

    # Check if the new filename argument is provided
    if [ -z "$2" ]; then
        log "Usage: rename_file old_filename new_filename"
        return 1
    fi

    # Rename the file
    mv "$1" "$2"
    log "File '$1' has been renamed to '$2'" >/dev/null 2>&1
    return 0
}

check_tools() {
    if file_exists "$(which python3)" && file_exists "$(which preflight)"; then
        #log "python3 and preflight are installed"
        printf "%-48s \e[1;32m%-24s\e[m\n" "python3 and preflight installed" "OK"
    else
        #bye "python3 and/or preflight are not installed"
        printf "%-48s \e[1;31m%-24s\e[m\n" "python3 and preflight installed" "NOK"
        exit 1
    fi
    file_exists "ava_csv_to_xlsx_conv.py" || bye "ava_csv_to_xlsx_conv.py: No such file."
}

check_preflight_version() {
    # Set the minimum Preflight version required
    MIN_PREFLIGHT_VERSION="1.5.2"

    # Check if Preflight is installed and get the version
    PREFLIGHT_VERSION=$(preflight --version | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+')

    # Compare the Preflight version to the minimum version required
    if [ "$(printf '%s\n' "$MIN_PREFLIGHT_VERSION" "$PREFLIGHT_VERSION" | sort -V | head -n1)" != "$MIN_PREFLIGHT_VERSION" ]; then
        printf "%-48s \e[1;31m%-24s\e[m\n" "Check Preflight Minimum version 1.5.2+" "NOK"
        exit 1
    else
        printf "%-48s \e[1;32m%-24s\e[m\n" "Check Preflight Minimum version 1.5.2+" "OK"
    fi
}
#Check if python pandas and openpyxl packages are installed
check_python_packages() {
    if pip3 show pandas &>/dev/null && pip3 show openpyxl &>/dev/null; then
        #log "pandas and openpyxl are installed"
        printf "%-48s \e[1;32m%-24s\e[m\n" "Python Pandas and Openpyxl installed" "OK"
        return 1
    elif pip3 show pandas &>/dev/null; then
        #log "pandas is installed, but openpyxl is not" && bye "openpyxl is not installed!"
        printf "%-48s \e[1;31m%-24s\e[m\n" "Python Openpyxl" "NOK"
        exit 1
    elif pip3 show openpyxl &>/dev/null; then
        #log "openpyxl is installed, but pandas is not" && bye "pandas is not installed!"
        printf "%-48s \e[1;31m%-24s\e[m\n" "Python Pandas" "NOK"
        exit 1
    else
        #log "pandas and openpyxl are not installed" && bye "both pandas and openpyxl are not installed!"
        printf "%-48s \e[1;31m%-24s\e[m\n" "Python Pandas and Openpyxl" "NOK"
        exit 1
    fi
}

check_registry_server_connection() {
    HOST="$1"
    #GOOGLE="${2:-google.com}"

    if command -v nc >/dev/null 2>&1; then
        if nc -zv4 "$HOST" 80 >/dev/null 2>&1; then
            printf "%-48s \e[1;32m%-24s\e[m\n" "$HOST's Connection" "OK"
        else
            printf "%-48s \e[1;31m%-24s\e[m\n" "$HOST's Connection" "NOK"
            exit 1
        fi
    else
        printf "%-48s \e[1;33m%-24s\e[m\n" "$HOST's Connection" "SKIPPED"
    fi
}

check_docker_auth_json_connection() {
    HOST=$1

    cat "${XDG_RUNTIME_DIR}/containers/auth.json" | grep $HOST >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        #log "Check Docker Authentication to $HOST succeeded!"
        printf "%-48s \e[1;32m%-24s\e[m\n" "Docker Authentication" "OK"
    else
        #log "Check Docker Authentication to $HOST failed!"
        printf "%-48s \e[1;31m%-24s\e[m\n" "Docker Authentication" "NOK"
        exit 1
    fi
}

check_private_registry_server_auth() {
    HOST=$1
    status_url="https://${HOST}/api/v1/repository?namespace=${REPO_NS}"
    status_code=$(curl -I --silent -o /dev/null -w "%{http_code}" -X GET -H "Authorization: Bearer ${API_TOKEN}" "${status_url}")

    if [ $status_code = "200" ]; then # succeed checking authenatication using Bear API_TOKEN
        #log "Check Private Registry Server to $HOST succeeded"
        printf "%-48s \e[1;32m%-24s\e[m\n" "Registry Server Bearer-Token Access" "OK"
    else
        #log "Check Private Registry Server to $HOST is FAILED, please check your Bear Token manually!"
        printf "%-48s \e[1;31m%-24s\e[m\n" "Registry Server Bearer-Token Access" "NOK"
        exit 1
    fi
}

start_convert_csv_xlsx_format_sort() {
    input_csv=$1
    output_xlsx=$2

    if [ ! -f "$input_csv" ]; then
        log "Input file $input_file does not exist!"
        exit 1
    fi

    python3 ava_csv_to_xlsx_conv.py $input_csv $output_xlsx
    if [ $? -eq 0 ]; then
        log "Successfully Converted from $input_csv to $output_xlsx!" >/dev/null 2>&1
    else
        log "Failed to Convert from $input_csv $output_xlsx!!!"
        exit 1
    fi
}

start_container_images_scan() {
    #Preflight ENV settings
    export PFLT_JUNIT="true"
    export PFLT_LOGLEVEL=trace
    export PFLT_LOGFILE=/tmp/preflight.log

    printf "%s\n" "Please be patient while scanning images..."
    count=0
    total_time=0
    total_seconds=0
    for ((j = 0; j < ${#ImageLists[*]}; j++)); do
        start_time=$(date +%s.%N)

        printf "\n%s\n" "Scaning the following image: ${ImageLists[$j]}"
        printf "%s\n" "======================================================"

        find $(pwd)/artifacts/ -type f -delete
        image_url="https://${FQDN}/api/v1/repository/${REPO_NS}/${ImageLists[$j]}"

        if [[ "${TAG_TYPE}" == "name" ]]; then
            tag_type_flag=".name + \":\" + .tags[].name"
        else # digest
            tag_type_flag=".name + \"@\" + .tags[].manifest_digest"
        fi
        image_details=$(curl --silent -X GET -H "Authorization: Bearer ${API_TOKEN}" "${image_url}" | jq -r "$tag_type_flag" | head -n1)

        tag=$(echo $image_details | cut -d ':' -f2)
        inspect_url="${FQDN}/${REPO_NS}/${ImageLists[$j]}:$tag"

        #since this script using preflight to do quick image scan so certification-project-id is dummy
        result_output=$(preflight check container "$inspect_url" --certification-project-id 63ec090760bb63386e44a33e \
            -d "${XDG_RUNTIME_DIR}/containers/auth.json" 2>&1 |
            awk 'match($0, /check=([^ ]+)/, c) && match($0, /result=([^ ]+)/, r) {print c[1] "," r[1]}')

        img_name=$(echo ${ImageLists[$j]} | rev | cut -d '/' -f1 | rev)
        final_output_csv=$(printf "%s\n" $result_output | awk -v img="$img_name" '{print img "," $0}')
        printf "%-20s %-25s %-10s\n" "Image Name" "Test Case" "Status"
        printf "%s\n" "------------------------------------------------------"

        console_output=($(printf "%s\n" "$result_output" | awk -v img="$img_name" '{print img "," $0}'))
        for line in "${console_output[@]}"; do
            image=$(printf "%s\n" "$line" | awk -F',' '{print $1}')
            testcase=$(printf "%s\n" "$line" | awk -F',' '{print $2}')
            status=$(printf "%s\n" "$line" | awk -F',' '{print $3}')

            if [ "$status" = "FAILED" ]; then
                printf "%-20s %-25s \e[1;31m%-10s\e[m\n" "${image}" "${testcase}" "${status}"
            elif [ "$status" = "PASSED" ]; then
                printf "%-20s %-25s \e[1;32m%-10s\e[m\n" "${image}" "${testcase}" "${status}"
            else
                printf "%-20s %-25s \e[1;31m%-10s\e[m\n" "${image}" "${testcase}" "${status}"
            fi
        done
        printf "%s\n" "$final_output_csv" >>$preflight_image_scan_result_csv
        printf "%s\n" "======================================================"

        #verdict_status=$(cat /tmp/preflight.log | awk -F'[:="]+' '/result:/ {print "Verdict:" $9}')
        verdict_status=$(cat /tmp/preflight.log | awk 'match($0, /result: ([^"]+)/, r) {print "Verdict: " r[1]}')
        vstatus=$(echo "$verdict_status" | awk '{print $2}')
        if [[ "$vstatus" =~ "FAILED" ]]; then
            printf "Verdict: \e[1;31m%-10s\e[m\n" "${vstatus}"
        elif [[ "$vstatus" =~ "PASSED" ]]; then
            printf "Verdict: \e[1;32m%-10s\e[m\n" "${vstatus}"
        else
            printf "Verdict: \e[1;31m%-10s\e[m\n" "${vstatus}"
        fi
        touch /tmp/preflight.log

        # Stop timer
        end_time=$(date +%s.%N)
        printf "Time elapsed: %.3f seconds\n" $(echo "$end_time - $start_time" | bc)

        elapsed_time=$(echo "$end_time - $start_time" | bc)
        total_seconds=$(echo "$total_seconds + $elapsed_time" | bc)
        count=$((count + 1))
    done
    printf "%s\n" "------------------------------------------------------"
    # convert total seconds to elapsed time format
    total_time=$(date -u -d "@$total_seconds" '+%Hh:%Mm:%Ss')

    printf "Total Number Images Scanned: %s\n" "$count"
    printf "Total Time Scanned: %s\n" "$total_time"
    printf "%s\n" "------------------------------------------------------"

}

###############################Main Function###################################
printf "\n%s\n" "Checking the pre-requirements steps..........."
printf "%s\n" "========================================================"
printf "%-46s %-10s\n" "Pre-Requirements Checking" "Status"
printf "%s\n" "---------------------------------------------------------"
#check preflight and python3 exist
check_tools

#check preflight minimum version 1.5.2+
check_preflight_version

#check registry server is reachable
check_registry_server_connection $FQDN

#Check Private Registry Server authentication
check_private_registry_server_auth $FQDN

#Check python pandas and openpyxl packages are installed
check_python_packages

#check docker authentication to private registry server has been login
check_docker_auth_json_connection $FQDN
printf "%s\n" "======================================================="

#Get all images based user's criteria and filters from QAUY via REST API#
readarray -t _ImageLists <<<$(curl --silent -X GET -H "Authorization: Bearer ${API_TOKEN}" "https://${FQDN}/api/v1/repository?namespace=${REPO_NS}" | jq -r '.repositories[].name' | egrep ${CNF_PREFIX} | egrep -v ${FILTER})
if [ -z $_ImageLists ]; then
    log "There is no image in the array list"
    log "Please check with curl cmd manually to see if this image responded to REST API or not!!!"
    exit 1
fi

#some cases where new images are not responded via REST API then add an exception here
#new_images=('global-amf-smsf' 'rel-core/global-amf-uercm' 'rel-core/global-mme-mbmc' 'rel-core/global-mme-mscic' 'rel-core/global-mme-mssic' 'rel-core/global-nf-alpine' 'rel-core/global-nf-clbc' 'rel-core/global-nf-csshd' 'rel-core/global-nf-mls' 'rel-core/global-nf-nlic')
ImageLists=("${_ImageLists[@]}" "${new_images[@]}")

#check if exist csv is existed and rename it
rename_file $preflight_image_scan_result_csv "${preflight_image_scan_result_csv}_saved"

#Print header for CSV
printf "%s\n" "Image Name,Test Case,Status" | tee $preflight_image_scan_result_csv >/dev/null
#Start to using Quay REST API and Preflight to do quick snapshot testing
start_container_images_scan

#Start convert csv to xlsx and sort/format only-if panda/openpyxl packages are installed
start_convert_csv_xlsx_format_sort $preflight_image_scan_result_csv "images_scan_results.xlsx"
