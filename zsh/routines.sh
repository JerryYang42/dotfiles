APPS_FOR_WORK=(
  "Slack"
  "Google Chrome"
  "Microsoft Teams"
  "Microsoft Outlook"
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

remove-from-dock "Slack"

close-apps () {
  for app in "${APPS_FOR_WORK[@]}"; do
    close-app "$app"
  done
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
tell application "System Events" to set visible of process "$1" to false
EOF
}

open-apps () {
  open-app-in-background-in-osascript-way "Slack"
  open-app-in-background-in-osascript-way "Microsoft Outlook"
  open-app-in-background-in-osascript-way "Microsoft Teams"
}


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