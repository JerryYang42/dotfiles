# Begin added by argcomplete
fpath=( /Users/yangj8/Developer/elsevier-research/cr-recs/kd-recs-infra/common/airflow/config/venv/lib/python3.10/site-packages/argcomplete/bash_completion.d "${fpath[@]}" )
# End added by argcomplete


# General settings                                                          {{{1
# ==============================================================================

export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_NONE='\033[0m'
export COLOR_BLUE="\033[0;34m"
export COLOR_MAGENTA="\033[0;35m"
export COLOR_CYAN="\033[0;36m"
export COLOR_CLEAR_LINE='\r\033[K'

# Display success message
# msg-success "Something succeeded"
function msg-success() {
    declare msg=$1
    printf "${CLEAR_LINE}${COLOR_GREEN}✔ ${msg}${COLOR_NONE}\n"
}

# Display a warning message
# msg-error "An error occurred"
function msg-error() {
    declare msg=$1
    printf "${CLEAR_LINE}${COLOR_RED}✘ ${msg}${COLOR_NONE}\n"
}