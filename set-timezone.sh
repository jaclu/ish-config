#!/usr/bin/env bash
#
#  Part of https://github.com/jaclu/ish-config
#
#  Copyright (c) 2022: Jacob.Lundqvist@gmail.com
#
#  License: MIT
#
#  Extraction of zone time offests derived from
#  https://gist.github.com/eduardoaugustojulio/fa83cf85efa39919d6a70ca679e91f28
#

# dialog_app="dialog --erase-on-exit"
dialog_app="whiptail"


do_clear() {
    #
    #  dialog ueses an option too clear screen after an item is displayed
    #  this is only needed for whiptail
    #
    [[ "$dialog_app" = "whiptail" ]] && clear
}


check_dependencies() {
    #
    #  Ensure needed stuff is installed
    #
    apks=()

    dlg_app="$(cat $dialog_app | cut -d ' ' -f 1)"

    if [[ -z "$(command -v "$dlg_app")" ]]; then
        #
        #  Since whiptail is part of newt, we need to handle that case
        #
        dependency="$dlg_app"
        [[ $dependency = "whiptail" ]] && dependency="newt"
        apks+=("$dependency")
    fi

    [[ ! -d /usr/share/zoneinfo ]] && apks+=(tzdata)

    if (( ${#apks[@]} )); then
        do_clear
        printf 'Installing dependencies: '
        printf '%s ' "${apks[@]}"
        printf '\n\n'
        #  shellcheck disable=SC2068
        apk add ${apks[@]}
    fi
}


get_tz_regions_lst ()
{
    regions=$(find /usr/share/zoneinfo/. -maxdepth 1 -type d | \
              cut -d "/" -f6 | sed '/^$/d' | awk '{print $0 ""}' | sort)
}


get_tz_options_lst ()
{
options=$(cd /usr/share/zoneinfo/"$1" && find . | sed "s|^\./||" | \
              sed "s/^\.//" | sed '/^$/d' | sort)
}


main ()
{
    tZone=""  # Needs to be cleared in case Back (to main) was selected
    #
    #  Select Region
    #
    get_tz_regions_lst

    region_items=()
    while read -r name; do
        #  skip invalids
        [[ "$name" = "right" ]] && continue

        region_items+=("$name" "")
    done <<< "$regions"


    # tested size 20 0 10
    region=$($dialog_app \
        --title "Timezones - region" \
        --backtitle "It will take a few seconds to generate location views..." \
        --ok-button "Next" \
        --menu "Select a region, or Etc for direct TZ:" 0 0 0 \
        "${region_items[@]}" \
        3>&2 2>&1 1>&3-)

    if [[ -z "$region" ]]; then
        return
    fi
    #
    #  Select a zone within a region
    #
    get_tz_options_lst "$region"

    option_items=()
    while read -r name; do
        offset=$(TZ="$region/$name" date +%z | sed "s/00$/:00/g")
        option_items+=("$name" " ($offset)")
    done <<< "$options"


    menu_title="Select your timezone in\nregion: ${region}"
    test "$region" = 'Etc' && menu_title="$menu_title\n\nPlease note POSIX and ISO use oposite signs\nfor numerical time-zone references!\nFocus on the right column in this table"
    tz=$($dialog_app \
        --title "Timezones - location" \
        --ok-button "Select" \
        --cancel-button "Back" \
        --menu "$menu_title"  0 0 0 \
        "${option_items[@]}" \
        3>&2 2>&1 1>&3-)

    if [[ -z "$tz" ]]; then
        #
        #  Back was selected, recurse one level. If something eventually is
        #  selected, the outermost layer of this will use it once exiting.
        #
        main
    else
        tZone="$region/$tz"
    fi
}


if [[ "$(whoami)" != 'root' ]]; then
    echo "You must use sudo or run as root"
    exit 1;
fi

check_dependencies

main

if test -n "$tZone"; then
    #
    #  Use the selected time-zone
    #
    ln -sf "/usr/share/zoneinfo/$tZone" /etc/localtime
    $dialog_app --msgbox "Time Zone is now:\n\n $tZone\n" 0 0
fi

do_clear
