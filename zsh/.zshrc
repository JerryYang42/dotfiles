# vim:fdm=marker

# Zsh initialisation                                                        {{{1
# ==============================================================================

# ENV VARs                          {{{2
# ======================================
source ~/.env

# Completion system                 {{{2
# ======================================

fpath=(~/.zsh-completion $fpath)

# See https://gist.github.com/ctechols/ca1035271ad134841284

# Only regenerate .zcompdump once every day
autoload -Uz compinit
for dump in ~/.zcompdump(N.mh+24); do
    compinit
done
compinit -C

# AWS config
alias aws-which="env | grep AWS | sort"
alias aws-clear-variables="for i in \$(aws-which | cut -d= -f1,1 | paste -); do unset \$i; done"
# alias aws-identity="aws sts get-caller-identity"
function aws-identity() {
    aws sts get-caller-identity
}
function aws-ls-profiles() {
    aws configure list-profiles | grep -v '^default$'
}

# function aws-is-authenticated() {
#     [[ -n $(aws-which) ]]
# }

function aws-is-authenticated() {
    # First, check if any AWS environment variables are set
    if [[ -z "$(aws-which)" ]]; then
        echo "AWS environment variables are not set." >&2
        return 1 # Not authenticated
    fi

    # If no AWS env vars, then check authentication
    if [[ -n "$(aws sts get-caller-identity 2>/dev/null)" ]]; then
        return 0  # Authenticated
    else
        return 1  # Not authenticated
    fi
}

function aws-is-authenticated-as() {
    if ! aws-is-authenticated >/dev/null 2>&1; then
        echo "AWS is not authenticated." >&2;
        return 1; 
    fi

    if [[ $# -ne 1 ]]; then
        echo "Usage: aws-is-authenticated-as PROFILE" >&2;
        return 1
    fi

    local profile=$1

    local profileAccountId=$(aws configure get --profile ${profile} sso_account_id)
    local profileRoleName=$(aws configure get --profile ${profile} sso_role_name)

    local actualAccountId=$(aws-identity | jq -r ".Account")
    local actualSaltedRoleName=$(aws-identity | jq -r ".Arn" | cut -d'/' -f2 | awk '{print $1}')

    if [[ "${profileAccountId}" != "${actualAccountId}" ]]; then
        echo "Error: Account ID mismatch. Expected ${profileAccountId}, got ${actualAccountId}." >&2; return 1; 
    fi

    if [[ "${actualSaltedRoleName}" != *"${profileRoleName}"* ]]; then
        echo "Error: Role name mismatch. Expected ${profileRoleName}, got ${actualSaltedRoleName}." >&2; return 1; 
    fi

    return 0;
}

# AWS SSO login via IDC
function aws-sso-login() {

    if [[ $# -ne 1 ]]; then
        echo "Usage: aws-sso-login PROFILE"; return 1;
    fi

    local profile=$1

    if aws-is-authenticated-as $profile; then 
        echo "Already authenticated as ${profile}";
        return 0;
    else 
        echo "Not authenticated as ${profile}";
    fi

    aws sso login --profile ${profile}

    local ssoCachePath=~/.aws/sso/cache

    local ssoAccountId=$(aws configure get --profile ${profile} sso_account_id)
    local ssoRoleName=$(aws configure get --profile ${profile} sso_role_name)
    local mostRecentSSOLogin=$(ls -t1 ${ssoCachePath}/*.json | head -n 1)
    local ssoCacheAccessToken=$(jq -r '.accessToken' ${mostRecentSSOLogin})
    local response=$(aws sso get-role-credentials \
        --role-name ${ssoRoleName} \
        --account-id ${ssoAccountId} \
        --access-token ${ssoCacheAccessToken} \
        --region eu-west-1
    )

    local accessKeyId=$(echo "${response}" | jq -r '.roleCredentials | .accessKeyId')
    local secretAccessKey=$(echo "${response}" | jq -r '.roleCredentials | .secretAccessKey')
    local sessionToken=$(echo "${response}" | jq -r '.roleCredentials | .sessionToken')

    export AWS_ACCESS_KEY_ID="${accessKeyId}"
    export AWS_SECRET_ACCESS_KEY="${secretAccessKey}"
    export AWS_SESSION_TOKEN="${sessionToken}"
    export AWS_DEFAULT_REGION="us-east-1"
    export AWS_REGION="us-east-1"

    aws-which
}

# alias aws-recs-dev="aws-clear-variables && aws-sso-login recs-dev"
# alias aws-recs-dev="aws-sso-login recs-dev"

function aws-recs-dev() {
    if [[ "$1" == "-f" ]]; then
        aws-clear-variables
        shift  # Remove the -f from the arguments
    fi
    aws-sso-login recs-dev
}

# alias aws-recs-live="aws-clear-variables && aws-sso-login recs-live"
# alias aws-recs-live="aws-sso-login recs-live"

function aws-recs-live() {
    if [[ "$1" == "-f" ]]; then
        aws-clear-variables
        shift  # Remove the -f from the arguments
    fi
    aws-sso-login recs-live
}

export username=yangj8@science.regn.net

# Useful functions
# https://github.com/elsevier-research/kd-recs-utils/blob/main/scripts/rr-scripts.sh
# vim:fdm=marker

# Formatting                                                                {{{1
# ==============================================================================

# Tabluate TSV
# cat foo.tsv | tabulate-by-tab
function tabulate-by-tab() {
    gsed 's/\t\t/\t-\t/g' \
        | column -t -s $'\t'
}

# Tabluate CSV
# cat foo.csv | tabulate-by-comma
function tabulate-by-comma() {
    gsed 's/,,/,-,/g' \
        | column -t -s '',''
}

# Calculate the result of an expression
# calc 2 + 2
function calc () {
    echo "scale=2;$*" | bc | sed 's/\.0*$//'
}


# Vim injection to prevent "cannot find compdef" error
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
 
autoload -Uz compinit
compinit

# AWS authentication                                                        {{{1
# ==============================================================================

function aws-recs-login() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: aws-recs-login (dev|staging|live)"
        return 1
    fi

    local recsEnv="${1}"

    case "${recsEnv}" in
        dev*)
            aws-recs-dev
            ;;

        staging*)
            aws-recs-dev
            ;;

        live*)
            aws-recs-prod
            ;;

        *)
            echo "ERROR: Unrecognised environment ${recsEnv}"
            return 1
            ;;
    esac
}
compdef "_arguments \
    '1:environment arg:(dev staging live)'" \
    aws-recs-login

# AWS resources                                                             {{{1
# ==============================================================================

function aws-sagemaker-endpoints() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: aws-sagemaker-endpoints (dev|staging|live)"
        return 1
    fi

    local recsEnv="${1}"
    aws-recs-login "${recsEnv}" > /dev/null

    aws sagemaker list-endpoints \
        | jq -r '["EndpointName", "CreationTime"], (.Endpoints[] | [.EndpointName, .CreationTime]) | @tsv' \
        | tabulate-by-tab
}
compdef "_arguments \
    '1:environment arg:(dev staging live)'" \
    aws-sagemaker-endpoints

function aws-feature-groups() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: aws-feature-groups (dev|staging|live)"
        return 1
    fi

    local recsEnv="${1}"
    aws-recs-login "${recsEnv}" > /dev/null

    aws sagemaker list-feature-groups \
        | jq -r '["Name", "Creation time", "Status", "Offline store status"], (.FeatureGroupSummaries[] | [.FeatureGroupName, .CreationTime, .FeatureGroupStatus, .OfflineStoreStatus.Status]) | @tsv' \
        | tabulate-by-tab
}
compdef "_arguments \
    '1:environment arg:(dev staging live)'" \
    aws-feature-groups

# Reviewer Recommender                                                      {{{1
# ==============================================================================

function rr-quality-metrics() {
    aws-recs-login live > /dev/null

    latestRun=$(aws s3 ls s3://com-elsevier-recs-live-reviewers/quality-metrics/metrics/demographic-parities/gender/selection-rates/ \
        | tail -n 1 \
        | gsed -r 's/.* PRE (.+)\/$/\1/')

    runId=${latestRun}

    echo ${runId}
    echo

    metrics=(
        demographic-parities
        equal-opportunity-statistics
    )

    characteristics=(
        gender
        geographicallocation
        seniority
    )

    subMetrics=(
        selection-rate-parities
        selection-rates
    )

    for characteristic in "${characteristics[@]}"
    do
        for metric in "${metrics[@]}"
        do
            for subMetric in "${subMetrics[@]}"
            do
                echo "${metric}/${characteristic}/${subMetric}"
                echo
                jsonFile=$(aws s3 ls s3://com-elsevier-recs-live-reviewers/quality-metrics/metrics/${metric}/${characteristic}/${subMetric}/${runId}/data/ \
                    | grep 'part-' \
                    | gsed -r 's/.* (part-.+\.json)$/\1/g')

                if [[ "${subMetric}" = 'selection-rates' ]]; then
                    aws s3 cp s3://com-elsevier-recs-live-reviewers/quality-metrics/metrics/${metric}/${characteristic}/${subMetric}/${runId}/data/${jsonFile} - \
                        | jq -s '.' \
                        | json-to-csv \
                        | strip-quotes \
                        | tabulate-by-comma
                else
                    aws s3 cp s3://com-elsevier-recs-live-reviewers/quality-metrics/metrics/${metric}/${characteristic}/${subMetric}/${runId}/data/${jsonFile} - \
                        | jq '[.label, .selectionRateA.model, .selectionRateParity]' \
                        | jq -s '.' \
                        | json-to-csv \
                        | tail -n +2 \
                        | strip-quotes \
                        | tabulate-by-comma
                fi
                echo
            done
        done
    done
}

function rr-lambda-performance() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: rr-lambda-performance (dev|staging|live)"
        return 1
    fi

    local recsEnv="${1}"
    aws-recs-login "${recsEnv}" > /dev/null

    # Pull out manuscript ID, stage, and duration from the logs
    # Ignore JDBCService initialisation because there is no manuscript ID associated to group by
    local timingData=$(
        awslogs get --no-group --no-stream --timestamp -s "5m" /aws/lambda/recs-reviewers-recommender-lambda-${recsEnv} \
            | grep -e 'Instrumentation\$:' \
            | grep -v 'JDBCService#initialise' \
            | gsed -r 's/^.* \[(.+)\] Instrumentation\$:.+ (.+) - ([0-9]+) ms$/\1 \2 \3/' \
            | (echo 'ManuscriptId' 'Stage' 'Duration' && cat)
    )

    # Sum stages for each manuscript, so multiple invocations of the same operation are added together
    local totalPerStage=$(
        echo ${timingData} \
            | datamash --sort --field-separator=' ' --header-in -g ManuscriptId,Stage sum Duration \
            | (echo 'ManuscriptId' 'Stage' 'TotalDuration' && cat)
    )

    # Display min, mean, and max for each stage
    local statsPerStage=$(
        echo ${totalPerStage} \
            | datamash --sort --field-separator=' ' --header-in --round=1 -g Stage min TotalDuration mean TotalDuration max TotalDuration \
            | (echo 'Stage' 'Min' 'Mean' 'Max' && cat) \
    )
    echo ${statsPerStage} | tabulate-by-space

    # Display min, mean, and max total time
    echo
    echo ${statsPerStage} \
        | datamash --sort --field-separator=' ' --header-in --round=1 sum Min sum Mean sum Max \
        | (echo 'TotalMin' 'TotalMean' 'TotalMax' && cat) \
        | tabulate-by-space

    # Display ElasticSearch configuration for reference
    echo
    aws es describe-elasticsearch-domain --domain-name "recs-reviewers" \
        | jq -r '["Instance", "InstanceCount", "Master", "MasterCount", "VolumeType", "IOPs"], (.DomainStatus | [(.ElasticsearchClusterConfig | .InstanceType, .InstanceCount, .DedicatedMasterType, .DedicatedMasterCount), (.EBSOptions | .VolumeType, .Iops)]) | @tsv' \
        | tabulate-by-tab
}
compdef "_arguments \
    '1:environment arg:(dev staging live)'" \
    rr-lambda-performance

function rr-error-queue-depth-live() {
    aws-recs-login live > /dev/null

    aws sqs get-queue-attributes \
        --queue-url https://sqs.us-east-1.amazonaws.com/589287149623/recs_rev_recommender_lambda_errors_dlq \
        --attribute-names All \
        | jq -r '.Attributes.ApproximateNumberOfMessages'
}

function rr-lambda-iterator-age() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: rr-lambda-iterator-age (dev|staging|live)"
        return 1
    fi

    local recsEnv="${1}"
    aws-recs-login "${recsEnv}" > /dev/null

    echo 'Iterator age at' $(date --iso-8601=seconds)
    echo
    aws cloudwatch get-metric-statistics \
        --namespace 'AWS/Lambda' \
        --dimensions Name=FunctionName,Value=recs-reviewers-recommender-lambda-${recsEnv} \
        --metric-name 'IteratorAge' \
        --start-time $(date --iso-8601=seconds --date='45 minutes ago') \
        --end-time   $(date --iso-8601=seconds) \
        --period 300 \
        --statistics Maximum \
        | jq -r '["Time", "Seconds", "Minutes", "Hours"], (.Datapoints | sort_by(.Timestamp) | .[] | [.Timestamp, .Maximum/1000, .Maximum/(60 * 1000), .Maximum/(60 * 60 * 1000)]) | @tsv' \
        | tabulate-by-tab
}
compdef "_arguments \
    '1:environment arg:(dev staging live)'" \
    rr-lambda-iterator-age

function rr-data-pump-lambda-submitted-manuscripts() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: rr-data-pump-lambda-submitted-manuscripts (dev|staging|live)"
        return 1
    fi

    local recsEnv="${1}"
    aws-recs-login "${recsEnv}" > /dev/null

    local KINESIS_STREAM_NAME="recs-reviewers-submitted-manuscripts-stream-${recsEnv}"

    local SHARD_ITERATOR=$(aws kinesis get-shard-iterator \
        --shard-id shardId-000000000000 \
        --shard-iterator-type TRIM_HORIZON \
        --stream-name $KINESIS_STREAM_NAME \
        --query 'ShardIterator')

    aws kinesis get-records --shard-iterator $SHARD_ITERATOR \
        | jq -r '.Records[] | .Data | @base64d' \
        | jq -r '.'
}
compdef "_arguments \
    '1:environment arg:(dev staging live)'" \
    rr-data-pump-lambda-submitted-manuscripts

function rr-recent-recommendations() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: rr-recent-recommendations (dev|staging|live)"
        return 1
    fi

    local recsEnv="${1}"
    aws-recs-login "${recsEnv}" > /dev/null

    awslogs get --no-group --no-stream --timestamp "/aws/lambda/recs-reviewers-recommender-lambda-${recsEnv}" -f 'ManuscriptService' \
        | gsed -r 's/.* Manuscript id: (.+)$/\1/g' \
        | grep -v ' '
}
compdef "_arguments \
    '1:environment arg:(dev staging live)'" \
    rr-recent-recommendations

function rr-lambda-invocations() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: rr-lambda-invocations (dev|staging|live)"
        return 1
    fi

    local recsEnv="${1}"
    aws-recs-login "${recsEnv}" > /dev/null

    lambdas=(
        recs-rev-reviewers-data-pump-lambda-${recsEnv}
        recs-rev-manuscripts-data-pump-lambda-${recsEnv}
        recs-reviewers-recommender-lambda-${recsEnv}
    )

    for lambda in "${lambdas[@]}"
    do
        echo "${lambda}"
        aws cloudwatch get-metric-statistics \
            --namespace 'AWS/Lambda' \
            --dimensions Name=FunctionName,Value="${lambda}" \
            --metric-name 'Invocations' \
            --start-time $(date --iso-8601=seconds --date='7 days ago') \
            --end-time   $(date --iso-8601=seconds) \
            --period $(calc '60 * 60 * 24') \
            --statistics Sum \
            | jq -r '["Time", "Total"], (.Datapoints | sort_by(.Timestamp) | .[] | [.Timestamp, .Sum]) | @csv' \
            | gsed 's/"//g' \
            | gsed "s/,,/,-,/g" \
            | column -t -s ','
        echo
    done
}
compdef "_arguments \
    '1:environment arg:(dev staging live)'" \
    rr-lambda-invocations

# read-heredoc myVariable <<'HEREDOC'
# this is
# multiline text
# HEREDOC
# echo $myVariable
function read-heredoc() {
    local varName=${1:-reply}
    shift

    local newlineChar=$'\n'

    local value=""
    while IFS="${newlineChar}" read -r line; do
        value="${value}${line}${newlineChar}"
    done

    eval ${varName}'="${value}"'
}

function rr-lambda-backlog() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: rr-lambda-backlog (dev|staging|live)"
        return 1
    fi

    local _lambda-invocations() {
        local lambda="${1}"

        aws cloudwatch get-metric-statistics \
            --namespace 'AWS/Lambda' \
            --dimensions Name=FunctionName,Value="${lambda}" \
            --metric-name 'Invocations' \
            --start-time $(date --iso-8601=seconds --date='3 days ago') \
            --end-time   $(date --iso-8601=seconds) \
            --period $(calc '60 * 60') \
            --statistics Sum \
            | jq -r '["Time", "Total"], (.Datapoints | sort_by(.Timestamp) | .[] | [.Timestamp, .Sum]) | @csv'
    }

    local pumpDataFilename=.data-pump-invocations.csv
    local lambdaDataFilename=.lambda-invocations.csv
    local backlogDataFilename=backlog.txt
    local backlogImageFilename=backlog.png

    local recsEnv="${1}"
    aws-recs-login "${recsEnv}" > /dev/null

    _lambda-invocations recs-rev-manuscripts-data-pump-lambda-${recsEnv} > ${pumpDataFilename}
    _lambda-invocations recs-reviewers-recommender-lambda-${recsEnv}     > ${lambdaDataFilename}

    local joinScript
    read-heredoc joinScript <<HEREDOC
        SELECT
            dp.Time AS time,
            dp.Total AS pump_count,
            l.Total AS lambda_count
        FROM ${pumpDataFilename} dp INNER JOIN ${lambdaDataFilename} l
        ON dp.Time = l.Time
HEREDOC

    local metricsScript
    read-heredoc metricsScript <<HEREDOC
        SELECT
            time,
            pump_count,
            sum(pump_count) over (ORDER BY time ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as pump_total,
            lambda_count,
            sum(lambda_count) over (ORDER BY time ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as lambda_total
        FROM -
HEREDOC

    q -d ',' -H -O "${joinScript}" \
        | q -d ',' -H -O "${metricsScript}" \
        | q -d ',' -H -O "SELECT time, pump_total, lambda_total, pump_total - lambda_total as backlog_size FROM -" \
        | tabulate-by-comma \
        > backlog.txt

    local gnuplotScript
    read-heredoc gnuplotScript <<HEREDOC
        set style data line
        set xdata time
        set timefmt "%Y-%m-%dT%H:%M:%S+00:00"
        set terminal png size 800,600 enhanced
        set output 'backlog.png'
        plot \
            "backlog.txt" using 1:2 title "Pump total"   linewidth 3, \
            "backlog.txt" using 1:3 title "Lambda total" linewidth 3, \
            "backlog.txt" using 1:4 title "Backlog"      linewidth 3
HEREDOC

    echo ${gnuplotScript} | gnuplot 
    imgcat backlog.png

    rm ${pumpDataFilename}
    rm ${lambdaDataFilename}
    rm ${backlogDataFilename}
    rm ${backlogImageFilename}
}
compdef "_arguments \
    '1:environment arg:(dev staging live)'" \
    rr-lambda-backlog


# k9: https://github.com/stubillwhite/dotfiles/blob/7ae97d03043f18c7b74051908ff788b75737b77c/zsh/.zshrc.ELSLAPM-156986#L86-L137


function recs-get-k8s() {
    if [[ $# -ne 2 ]] ; then
        echo "Usage: recs-get-k8s (dev|live) (util|main)"
    else
        local recsEnv=$1
        local recsSubEnv=$2
        aws s3 cp s3://com-elsevier-recs-${recsEnv}-certs/eks/recs-eks-${recsSubEnv}-${recsEnv}.conf ~/.kube/
    fi
}
compdef "_arguments \
    '1:environment arg:(dev live)' \
    '2:sub-environment arg:(util main)'" \
    recs-get-k8s

function k9s-recs() {
    if [[ $# -ne 2 ]] ; then
        echo "Usage: k9s-recs (dev|staging|live) (util|main)" >&2
        return 1;
    fi

    local recsEnv=$1
    if [[ $recsEnv == "dev" ]]; then
        aws-recs-dev
    elif [[ $recsEnv == "staging" ]]; then
        aws-recs-dev
    elif [[ $recsEnv == "live" ]]; then
        aws-recs-live
    else 
        echo "Unrecognised environment ${1}" >&2
        return 1
    fi
    
    local recsSubEnv=$2
    recs-get-k8s ${recsEnv} ${recsSubEnv}
    export KUBECONFIG=~/.kube/recs-eks-${recsSubEnv}-${recsEnv}.conf
    k9s; unset KUBECONFIG  # use ';' to ensure unsetting is executed even if k9s fails
}
compdef "_arguments \
    '1:environment arg:(dev staging live)' \
    '2:sub-environment arg:(util main)'" \
    k9s-recs

function kube-ls-pods() {
    kubectl get pods --all-namespaces -o wide
}

# function kube-recs() {
#     if [[ $# -ne 2 ]] ; then
#         echo "Usage: k9s-recs (dev|staging|live) (util|main)" >&2
#         return 1;
#     fi

#     local recsEnv=$1
#     if [[ $recsEnv == "dev" ]]; then
#         aws-recs-dev
#     elif [[ $recsEnv == "staging" ]]; then
#         aws-recs-dev
#     elif [[ $recsEnv == "live" ]]; then
#         aws-recs-live
#     else 
#         echo "Unrecognised environment ${1}" >&2
#         return 1
#     fi
    
#     local recsSubEnv=$2
#     recs-get-k8s ${recsEnv} ${recsSubEnv}
#     export KUBECONFIG=~/.kube/recs-eks-${recsSubEnv}-${recsEnv}.conf
#     kube-ls-pods
#     # echo "Enter the namespace: "
#     # read namespace
#     # unset KUBECONFIG
# }
# compdef "_arguments \
#     '1:environment arg:(dev staging live)' \
#     '2:sub-environment arg:(util main)'" \
#     kube-recs


# Python                                                                    {{{1
# ==============================================================================

# set trusted hosts for pip install 
alias pipinstall="pip install --trusted-host files.pythonhosted.org --trusted-host pypi.org --trusted-host pypi.python.org --default-timeout=1000"


# Git                               {{{2
# ======================================

source /opt/homebrew/bin/env_parallel.zsh

export GIT_TRUNK=main

function git-set-trunk() {
    if [[ $# -ne 1 ]] ; then
        echo 'Usage: git-set-trunk GIT_TRUNK'
        return 1
    fi

    export GIT_TRUNK=$1
    echo "GIT_TRUNK set to ${GIT_TRUNK}"
}
compdef "_arguments \
    '1:branch arg:(main master)'" \
    git-set-trunk

# For each directory within the current directory, if the directory is a Git
# repository then execute the supplied function 
function git-for-each-repo() {
    setopt local_options glob_dots
    for fnam in *; do
        if [[ -d $fnam ]]; then
            pushd "$fnam" > /dev/null || return 1
            if git rev-parse --git-dir > /dev/null 2>&1; then
                "$@"
            fi
            popd > /dev/null || return 1
        fi
    done
}

# For each directory within the current directory, if the directory is a Git
# repository then execute the supplied function in parallel
function git-for-each-repo-parallel() {
    local dirs=$(find . -type d -maxdepth 1)

    echo "$dirs" \
        | env_parallel --env "$1" -j20 \
            "
            pushd {} > /dev/null;                               \
            if git rev-parse --git-dir > /dev/null 2>&1; then   \
                $@;                                             \
            fi;                                                 \
            popd > /dev/null;                                   \
            "
}

# For each repo within the current directory, pull the repo
function git-repos-pull() {
    pull-repo() {
        echo "Pulling $(basename $PWD)"
        git pull -r --autostash
        echo
    }

    git-for-each-repo-parallel pull-repo 
    git-repos-status
}

# For each repo within the current directory, fetch the repo
function git-repos-fetch() {
    local args=$*

    fetch-repo() {
        echo "Fetching $(basename $PWD)"
        git fetch ${args}
        echo
    }

    git-for-each-repo-parallel fetch-repo 
    git-repos-status
}

# Parse Git status into a Zsh associative array
function git-parse-repo-status() {
    local aheadAndBehind
    local ahead=0
    local behind=0
    local added=0
    local modified=0
    local deleted=0
    local renamed=0
    local untracked=0
    local stashed=0

    branch=$(git rev-parse --abbrev-ref HEAD 2> /dev/null)
    ([[ $? -ne 0 ]] || [[ -z "$branch" ]]) && branch="unknown"

    aheadAndBehind=$(git status --porcelain=v1 --branch | perl -ne '/\[(.+)\]/ && print $1' )
    ahead=$(echo $aheadAndBehind | perl -ne '/ahead (\d+)/ && print $1' )
    [[ -z "$ahead" ]] && ahead=0
    behind=$(echo $aheadAndBehind | perl -ne '/behind (\d+)/ && print $1' )
    [[ -z "$behind" ]] && behind=0

    # See https://git-scm.com/docs/git-status for output format
    while read -r line; do
      # echo "$line"
      echo "$line" | gsed -r '/^[A][MD]? .*/!{q1}'   > /dev/null && (( added++ ))
      echo "$line" | gsed -r '/^[M][MD]? .*/!{q1}'   > /dev/null && (( modified++ ))
      echo "$line" | gsed -r '/^[D][RCDU]? .*/!{q1}' > /dev/null && (( deleted++ ))
      echo "$line" | gsed -r '/^[R][MD]? .*/!{q1}'   > /dev/null && (( renamed++ ))
      echo "$line" | gsed -r '/^[\?][\?] .*/!{q1}'   > /dev/null && (( untracked++ ))
    done < <(git status --porcelain)

    stashed=$(git stash list | wc -l)

    unset gitRepoStatus
    typeset -gA gitRepoStatus
    gitRepoStatus[branch]=$branch
    gitRepoStatus[ahead]=$ahead
    gitRepoStatus[behind]=$behind
    gitRepoStatus[added]=$added
    gitRepoStatus[modified]=$modified
    gitRepoStatus[deleted]=$deleted
    gitRepoStatus[renamed]=$renamed
    gitRepoStatus[untracked]=$untracked
    gitRepoStatus[stashed]=$stashed
}

# For each repo within the current directory, display the respository status
function git-repos-status() {
    display-status() {
        git-parse-repo-status
        repo=$(basename $PWD) 

        local branchColor="${COLOR_RED}"
        if [[ "$gitRepoStatus[branch]" =~ (^main$) ]]; then
            branchColor="${COLOR_GREEN}"
        fi
        local branch="${branchColor}$gitRepoStatus[branch]${COLOR_NONE}"

        local sync="${COLOR_GREEN}in-sync${COLOR_NONE}"
        if (( $gitRepoStatus[ahead] > 0 )) && (( $gitRepoStatus[behind] > 0 )); then
            sync="${COLOR_RED}ahead/behind${COLOR_NONE}"
        elif (( $gitRepoStatus[ahead] > 0 )); then
            sync="${COLOR_RED}ahead${COLOR_NONE}"
        elif (( $gitRepoStatus[behind] > 0 )); then
            sync="${COLOR_RED}behind${COLOR_NONE}"
        fi

        local dirty="${COLOR_GREEN}clean${COLOR_NONE}"
        (($gitRepoStatus[added] + $gitRepoStatus[modified] + $gitRepoStatus[deleted] + $gitRepoStatus[renamed] > 0)) && dirty="${COLOR_RED}dirty${COLOR_NONE}"

        print "${branch},${sync},${dirty},${repo}\n"
    }

    git-for-each-repo display-status | column -t -s ','
}

# For each repo within the current directory, display whether the repo contains
# unmerged branches locally
function git-repos-unmerged-branches() {
    display-unmerged-branches() {
        local cmd="git unmerged-branches"
        unmergedBranches=$(eval "$cmd") 
        if [[ $unmergedBranches = *[![:space:]]* ]]; then
            echo "$fnam"
            eval "$cmd"
            echo
        fi
    }

    git-for-each-repo display-unmerged-branches
}

# For each repo within the current directory, display whether the repo contains
# unmerged branches locally and remote
function git-repos-unmerged-branches-all() {
    display-unmerged-branches-all() {
        local cmd="git unmerged-branches-all"
        unmergedBranches=$(eval "$cmd") 
        if [[ $unmergedBranches = *[![:space:]]* ]]; then
            echo "$fnam"
            eval "$cmd"
            echo
        fi
    }

    git-for-each-repo display-unmerged-branches-all
}

function convert-timestamp-from-iso8601-to-epoch () {
    local timestamp=$1
    date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" +%s
}

function relative-time () {
    local timestamp=$1

    if [[ -z "$timestamp" ]]; then
        echo "Requires a timestamp as an argument"
        echo "Usage: relative-time TIMESTAMP"
        return
    fi

    local diff=$(ddiff $start_date now -f "%S")

    if [[ $diff -lt 60 ]]; then
        echo "just now"
    elif [[ $diff -lt 3600 ]]; then
        echo "$((diff / 60)) minutes ago"
    elif [[ $diff -lt 86400 ]]; then
        echo "$((diff / 3600)) hours ago"
    else
        echo "$((diff / 86400)) days ago"
    fi
}


# List out Pull Request (PR) associated with a specific branch on GitHub
function gh-pr () {
    PR_LIST=$(gh pr list --head "$(git branch --show-current)" --json number,title,url,baseRefName,closed,createdAt,latestReviews)
    PR_COUNT=$(echo "$PR_LIST" | jq '. | length')

    if [ "$PR_COUNT" -gt 0 ]; then
        FILTERED_PR_LIST=$(echo "$PR_LIST" | jq '[.[] | select(.closed == false)] | sort_by(.createdAt) | reverse')
        
        # TODO: prettify the output table
        echo -e "ID\tTITLE\tURL\tBASE BRANCH\tCREATED AT"
        echo "$FILTERED_PR_LIST" | jq -r '.[] | [.number, .title, .url, .baseRefName, .createdAt] | @tsv' | while IFS=$'\t' read -r number title url baseRefName createdAt; do
        relative_created_at=$(relative-time "$createdAt")
        printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$number" "$title" "$url" "$baseRefName" "$relative_created_at"
        done | column -t -s $'\t'
        # echo "$PR_LIST" | jq -r '.[] | [.number, .title, .url, .baseRefName, .closed, (.createdAt | relative-time), .latestReviews] | @tsv' | column -t -s $'\t'
    else
        echo "No pull requests found."
    fi
}

function gh-open-prs-mine () {
    # Define the organization and author
    ORG="elsevier-research"
    AUTHOR="JerryYang42"

    # Get the current date and subtract 6 months
    SIX_MONTHS_AGO=$(date -v -6m +"%Y-%m-%dT%H:%M:%SZ")

    # Fetch the PRs using GitHub GraphQL API
    response=$(curl --silent --request POST \
    --url https://api.github.com/graphql \
    --header "Authorization: bearer $GITHUB_TOKEN" \
    --header 'User-Agent: zsh-script' \
    --data "{\"query\":\"{ search(query: \\\"org:$ORG author:$AUTHOR is:pr is:open\\\", type: ISSUE, first: 100) { edges { node { ... on PullRequest { title url createdAt updatedAt repository { name url } } } } } }\"}")

    # Parse and filter the JSON response
    echo "Updated At\t\tTITLE\t\tURL"
    echo "$response" | jq -r --arg date "$SIX_MONTHS_AGO" '
        .data.search.edges
        | map(select(.node.updatedAt > $date))
        | sort_by(.node.updatedAt)
        | reverse
        | .[]
        | "\(.node.updatedAt) \(.node.title) --> \(.node.url)"
    ' | awk -v now="$(date +%s)" '{
        cmd = "date -j " $1 " +%s"
        cmd | getline pr_time
        close(cmd)
        
        # Calculate the difference in seconds
        diff = now - pr_time
        
        # Convert the difference to a human-readable format
        if (diff < 60) {
            rel_time = diff " seconds ago"
        } else if (diff < 3600) {
            rel_time = int(diff / 60) " minutes ago"
        } else if (diff < 86400) {
            rel_time = int(diff / 3600) " hours ago"
        } else {
            rel_time = int(diff / 86400) " days ago"
        }
        
        $1 = rel_time
        print $1 "\t\t" $2 "\t\t" $3
    }'


}


# For a new repo, uploaded to GitHub, set the origin
function mk-git-repo() {
    local repo_name=""
    local is_private=false

    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -p|--private) is_private=true ;;
            *) 
                if [ -z "$repo_name" ]; then
                    repo_name="$1"
                else
                    echo "Unknown parameter passed: $1"
                    return 1
                fi
                ;;
        esac
        shift
    done

    # Check if repo name was provided
    if [ -z "$repo_name" ]; then
        echo "Please provide a repository name."
        return 1
    fi

    # Construct the GitHub URL
    # Get the GitHub username from Git config or environment variable
    local github_username=$(git config --global github.user || echo "${GITHUB_USERNAME:-}")
    # Check if we have a GitHub username
    if [ -z "$github_username" ]; then
        echo "Error: GitHub username not found. Please set it using 'git config --global github.user YOUR_USERNAME' or set the GITHUB_USERNAME environment variable."
        return 1
    fi
    # GitHub URL (SSH format)
    local github_ssh="git@github.com:$github_username/$repo_name.git"

    # Print out the GitHub remote and ask for consent
    echo "This script will create a new $([ "$is_private" = true ] && echo "private" || echo "public") repository named '$repo_name' and push it to:"
    echo "$github_ssh"
    echo -n "Do you want to continue? (y/n) "
    read REPLY
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        echo "Operation cancelled."
        return 1
    fi

    # Create the directory and navigate into it
    mkdir "$repo_name" && cd "$repo_name" || return 1

    # Initialize the Git repository
    git init

    # Create a README file
    echo "# $repo_name" > README.md

    # Add the README file to the repository
    git add README.md

    # Commit the changes
    git commit -m "Initial commit"

    # Create the repository on GitHub using the GitHub CLI and push the local changes
    if [ "$is_private" = true ]; then
        gh repo create "$repo_name" --private --source=. --remote=origin --push
    else
        gh repo create "$repo_name" --public --source=. --remote=origin --push
    fi

    echo "Repository $repo_name created and pushed to GitHub."

    # Open the repository URL in the default browser
    local github_url="https://github.com/$github_username/$repo_name.git"
    case "$(uname -s)" in
        Darwin*)    open "$github_url" ;;
        Linux*)     xdg-open "$github_url" ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*) start "$github_url" ;;
        *)          echo "Unsupported operating system. Please open $github_url manually." ;;
    esac
}


# Visual Studio Code                {{{2
# ======================================
export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"


# Java                                                                      {{{1
# ==============================================================================
# export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home
jdk() {
    version=$1
    export JAVA_HOME=$(/usr/libexec/java_home -v"$version");
    java -version
}

# Switch Java version
function java-version() {
    if [[ $# -ne 1 ]] ; then
        echo 'Usage: java-version JVM'
        return 1
    fi

    export JAVA_HOME=/Library/Java/JavaVirtualMachines/${1}/Contents/Home/
}
compdef '_alternative \
    "arguments:custom arg:(temurin-8.jdk temurin-11.jdk temurin-17.jdk temurin-20.jdk)"' \
    java-version

# Default Java 17
java-version temurin-17.jdk


# Fetch k8s credentials
getk8s() {
    aws s3 cp s3://com-elsevier-recs-$1-certs/eks/recs-eks-main-$1.conf ~/.kube/
    export KUBECONFIG=~/.kube/recs-eks-main-$1.conf
}

# Add IntelliJ Community Edition to PATH
export PATH="$PATH:/Applications/IntelliJ IDEA CE.app/Contents/MacOS"

function idea() {
    open -na "IntelliJ IDEA CE" --args "$@"  # https://stackoverflow.com/questions/57309605/how-to-run-intellij-idea-from-terminal-in-detached-mode
}


# Zscalar                                                                   {{{1
# ==============================================================================
export SSL_CERT_FILE=~/zscalar/ZscalerRootCertificate-2048-SHA256.crt
# export SSL_CERT_FILE=/usr/local/etc/openssl@3/certs
# export SSL_CERT_FILE="${SSL_CERT_FILE}"        # openssl
# export REQUESTS_CA_BUNDLE="${SSL_CERT_FILE}"   # requests
# export AWS_CA_BUNDLE="${SSL_CERT_FILE}"        # botocore
# export CURL_CA_BUNDLE="${SSL_CERT_FILE}"       # curl
# export HTTPLIB2_CA_CERTS="${SSL_CERT_FILE}"    # httplib2
# export NODE_EXTRA_CA_CERTS="${SSL_CERT_FILE}"  # node

function install-java-certificate() {
    if [[ $# -ne 1 ]] ; then
        echo 'Usage: install-java-certificate FILE'
        return 1
    fi

    local certificate=$1

    local keystores=$(find /Library -name cacerts | grep JavaVirtualMachines)
    while IFS= read -r keystore; do
        echo
        echo sudo keytool -importcert -file \
            "${certificate}" -keystore "${keystore}" -alias Zscalar

        # keytool -list -keystore "${keystore}" | grep -i zscalar
    done <<< "${keystores}"
}


# Homebrew                                                                  {{{1
# ==============================================================================

if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Error: Homebrew is not installed or not found in the expected location." >&2
    echo "Please install Homebrew or check its installation path." >&2
    echo "Visit https://brew.sh for installation instructions." >&2
fi


# Recs                                                                      {{{1
# ==============================================================================
# Reviewer Recommender              {{{2
# ======================================

# Fetch rr recent recommendations
function rr-recent-recommendations () {
	if [[ $# -ne 1 ]]
	then
		gecho "Usage: rr-recent-recommendations (dev|staging|live)"
		return 1
	fi
	local recsEnv="${1}"
	aws-recs-login "${recsEnv}" > /dev/null
	awslogs get --no-group --no-stream --timestamp "/aws/lambda/recs-reviewers-recommender-lambda-${recsEnv}" -f 'ManuscriptService' | gsed -r 's/.* Manuscript id: (.+)$/\1/g' | grep -e '^[^ ]\+$'
}


# Routines                                                                  {{{1
# ==============================================================================
# Desktop env management            {{{2
# ======================================

APPS_FOR_WORK=(
  "Slack"
  "Google Chrome"
  "Microsoft Teams"
  "Microsoft Outlook"
  "Microsoft Visual Studio Code"
  "Terminal"
  "iTerm"
  "IntelliJ IDEA CE"
)

close-app () {
  if [ -z "$1" ]; then
    echo "Usage: close-app <app-name>"
    return 1
  fi

  local app_name=$1
  local app_pid=$(pgrep -i "$app_name")

  if [ -z "$app_pid" ]; then
    echo "$app_name is not running"
    return 1
  fi
  osascript -e "quit app \"$1\""  # https://apple.stackexchange.com/questions/354954/how-can-i-quit-an-app-using-terminal
}

remove-from-dock() {
    if [ $# -eq 0 ]; then
        echo "Usage: remove_from_dock <app_name>"
        return 1
    fi

    local app_name="$1"
    
    # Remove the app from the Dock
    dockutil --remove "$app_name" --no-restart

    # Restart the Dock to apply changes
    killall Dock

    echo "Removed $app_name from the Dock and restarted the Dock."
}

add-to-dock() {
    if [ $# -eq 0 ]; then
        echo "Usage: add-to-dock <app_name> [position]"
        return 1
    fi

    local app_name="$1"
    local position="${2:-}"
    local app_path="/Applications/${app_name}.app"

    # Check if the app exists
    if [ ! -d "$app_path" ]; then
        echo "Error: $app_name not found in /Applications"
        return 1
    fi

    # Add the app to the Dock
    if [ -n "$position" ]; then
        dockutil --add "$app_path" --position "$position" --no-restart
    else
        dockutil --add "$app_path" --no-restart
    fi

    # Restart the Dock to apply changes
    killall Dock

    echo "Added $app_name to the Dock and restarted the Dock."
}


close-apps () {
  for app in "${APPS_FOR_WORK[@]}"; do
    close-app "$app"
  done
  remove-from-dock "Slack"
  remove-from-dock "Microsoft Outlook"
  remove-from-dock "Microsoft Teams"
}


open-app () {
  if [ -z "$1" ]; then
    echo "Usage: open-app <app-name>"
    return 1
  fi

  local app_name=$1
  open -g -a "$app_name"
}


open-app-in-background-in-osascript-way () {
  if [ -z "$1" ]; then
    echo "Usage: set-app-invisible-in-osascript-way <app-name>"
    return 1
  fi
  
  echo "Opening $1 in the background"

  osascript <<EOF
tell application "$1" to launch
tell application "System Events"
  repeat until exists (processes where name is "$1")
      delay 0.5
  end repeat
  
  repeat until (exists window 1 of process "$1")
      delay 0.5
  end repeat
  
  # Additional delay to ensure content is loaded
  delay 2
end tell
tell application "$1" to activate
tell application "System Events" to set visible of process "$1" to false
EOF

echo "Opened $1 in the background"
}

open-apps () {
  add-to-dock "Slack" 1
  add-to-dock "Microsoft Outlook" 2
  add-to-dock "Microsoft Teams" 3
  
  # Run the following commands in parallel
  open-app-in-background-in-osascript-way "Slack" &
  open-app-in-background-in-osascript-way "Microsoft Outlook" &
  open-app-in-background-in-osascript-way "Microsoft Teams" &  # something wrong with Teams openning, looping forever
  wait  # Wait for all background jobs to finish
}

# Quick Navigation                  {{{2
# ======================================

cd-recs () {
    cd ~/Developer/elsevier-research/recs || exit
    cd "$(find . -type d -name "kd-*" -maxdepth 2 | fzf)" || exit
}

cd-cr-recs () {
    cd ~/Developer/elsevier-research/cr-recs || exit
    cd "$(find . -type d -name "kd-*" -maxdepth 2 | fzf)" || exit
}
