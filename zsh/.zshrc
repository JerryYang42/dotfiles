export JAVA_HOME=/Library/Java/JavaVirtualMachines/adoptopenjdk-8.jdk/Contents/Home

# AWS config
alias aws-which="env | grep AWS | sort"
alias aws-clear-variables="for i in \$(aws-which | cut -d= -f1,1 | paste -); do unset \$i; done"

function aws-switch-role() {
    declare roleARN=$1 profile=$2

    export username=yangj8@science.regn.net
    LOGIN_OUTPUT="$(aws-adfs login --adfs-host federation.reedelsevier.com --region us-east-1 --session-duration 14400 --role-arn $roleARN --env --profile $profile --printenv | grep export)"
    AWS_ENV="$(echo $LOGIN_OUTPUT | grep export)"
    eval $AWS_ENV
    export AWS_REGION=us-east-1
    aws-which
}

function aws-developer-role() {
    declare accountId=$1 role=$2 profile=$3
    aws-switch-role "arn:aws:iam::${accountId}:role/${role}" "${profile}"
}

alias aws-recs-dev="aws-developer-role 975165675840 ADFS-Developer aws-rap-recommendersdev"
alias aws-recs-prod="aws-developer-role 589287149623 ADFS-Developer aws-rap-recommendersprod"

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
        | grep -e '^[^ ]\+$'
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
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/yangj8/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/yangj8/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/yangj8/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/yangj8/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

