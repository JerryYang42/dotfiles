APPS_FOR_WORK=(
  "Slack"
  "Google Chrome"
  "Microsoft Teams"
  "Microsoft Outlook"
  "Microsoft OneNote"
  "Microsoft Teams"
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

# close-app "Slack"

close-apps () {
  for app in "${APPS_FOR_WORK[@]}"; do
    close-app "$app"
  done
}

# close-apps

open-app () {
  if [ -z "$1" ]; then
    echo "Usage: open-app <app-name>"
    return 1
  fi

  local app_name=$1
  open -g -a "$app_name"
}

# open-app "Slack"

open-Slack-in-background () {
  osascript -e 'tell application "Slack" to launch' \
            -e 'tell application "System Events" to set visible of process "Slack" to false'
}

open-apps () {
  open-Slack-in-background
}
open-apps


# get-off-work() {
#   if [ -z "$1" ]; then
#     echo "Usage: get-off-work <time>"
#     return 1
#   fi

#   local time=$1
#   local now=$(date +%s)
#   local target=$(gdate -d "$time" +%s)

#   if [ $now -gt $target ]; then
#     echo "It's already past $time"
#     return 1
#   fi

#   local diff=$((target - now))
#   local hours=$((diff / 3600))
#   local minutes=$((diff % 3600 / 60))

#   echo "You have $hours hours and $minutes minutes left"
# }
 
# #  Now you can run  get-off-work  with a time argument to see how much time you have left until you can leave work. 
# #  $ get-off-work 17:00


# get-off-work 17:00