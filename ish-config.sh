#!/bin/sh
#
#  Part of https://github.com/jaclu/ish-config
#
#  Copyright (c) 2022: Jacob.Lundqvist@gmail.com
#
#  License: MIT
#
#  The actual script is using bash, and that might not be available on a fresh
#  install. This will install bash and other basic dependencies,
#  then launch the actual script.
#

current_dir="$(dirname -- "$(realpath "$0")")"


if [ "$(whoami)" != 'root' ]; then
    echo "Please run as root or using sudo"
    exit 1;
fi

app_name="$(grep "^dialog_app=" "$current_dir/do_ish_config.sh"  | \
            cut -d = -f 2 | sed 's/"//g' | tail -n 1 | cut -d ' ' -f 1)"
case "$app_name" in

    dialog)
        dialog_pkg="$app_name"
        dialog_app="/usr/bin/dialog"
        ;;

    whiptail)
        dialog_pkg="newt"
        dialog_app="/usr/bin/whiptail"
        ;;

    *)
        echo "Could not identify dialog app used in do_ish_config.sh [$app_name]"
        exit 1
        ;;
esac

pkgs=""
test ! -f /bin/bash && pkgs="$pkgs bash"
test ! -f $dialog_app && pkgs="$pkgs $dialog_pkg"

if [ -n "$pkgs" ]; then
    echo "Installing dependencies: $pkgs"
    if [ -f /etc/debian_version ]; then
        cmd="apt install"
    else
        cmd="apk add"
    fi
    #  shellcheck disable=SC2086
    $cmd $pkgs
fi

# shellcheck disable=SC2086
$current_dir/do_ish_config.sh
