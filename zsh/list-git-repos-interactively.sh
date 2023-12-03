#!/bin/bash

function list_git_repos() {
    find "$1" -type d -name '.git' 2>/dev/null | sed -E 's|/\.git$||'
}

echo "Listing Git Repositories on Disk:"
read -p "Enter the starting path (press Enter for current directory): " starting_path

starting_path=${starting_path:-.}  # Set default to current directory if user presses Enter

git_repos=($(list_git_repos "$starting_path"))

if [ ${#git_repos[@]} -eq 0 ]; then
    echo -e "\nNo Git Repositories found."
    exit 1
fi

# Set the number of lines to display (half the screen)
display_lines=$(( $(tput lines) / 2 ))

selected_index=0

while true; do
    clear
    echo "Select a Git Repository (use arrow keys to navigate, press Enter to select):"

    for ((i=0; i<${#git_repos[@]}; i++)); do
        if [ $i -eq $selected_index ]; then
            echo -e "\033[1;33m➜ ${git_repos[$i]}\033[0m"
        else
            echo "  ${git_repos[$i]}"
        fi

        # Break out of the loop if we have displayed the desired number of lines
        [ $((i + 1)) -ge $((selected_index + display_lines)) ] && break
    done

    read -s -n 1 key

    case $key in
        "A")  # Up arrow
            ((selected_index--))
            [ $selected_index -lt 0 ] && selected_index=$(( ${#git_repos[@]} - 1 ))
            ;;
        "B")  # Down arrow
            ((selected_index++))
            [ $selected_index -ge ${#git_repos[@]} ] && selected_index=0
            ;;
        "")  # Enter key
            clear
            echo -e "\nYou selected: ${git_repos[$selected_index]}"
            break
            ;;
    esac
done
