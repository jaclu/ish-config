#!/usr/bin/env bash
#
#  Part of https://github.com/jaclu/ish-config
#
#  Copyright (c) 2022: Jacob.Lundqvist@gmail.com
#
#  License: MIT
#
#  This script is using bash, and that might not be available on a fresh
#  install. The ish_config.sh will install bash and other basic dependencies
#  then launch this script.
#
#  When potentially changing states depending on OK being pressed,
#  the current state is stored as an upper-case variable ending with _CUR
#  and the new state as a lower case variable ending in _new in order to make
#  the difference obvious.
#  sudo apk add git && sudo git clone https://github.com/jaclu/ish_config.git /opt/ish-config
#  TODO: check with emkey1 /proc/ish/defaults/option_mapping cant be changed

dialog_app="dialog"
#dialog_app="whiptail"

ish_service_disclaimer() {
    echo
    echo "Some errors might displayed when services are started/stopped."
    echo "They can be ignored. The iSH family doesn't fully support openrc yet,"
    echo "but the important parts work!"
    echo
}

enable_sshd() {
    clear
    echo "Activating sshd service"
    echo
    #
    # Install missing dependencies
    #
    pkgs=()
    test ! -f /usr/sbin/sshd && pkgs+=("openssh")
    test ! -f /bin/rc-status && pkgs+=("openrc")
    if (( ${#pkgs[@]} )); then
        echo "Installing dependencies: ${pkgs[*]}"
        apk add "${pkgs[@]}"
    fi

    if grep -q " sysinit" /etc/inittab ; then
         sed -i 's/ sysinit//' /etc/inittab
         echo
         echo "/etc/inittab was changed. You need to restart iSH now!"
         exit 0
    fi

    #
    #  Save an unmodified sshd_config
    #
    sshd_backup_file="/etc/ssh/sshd_config.bak"
    [[ ! -f $sshd_backup_file ]] && cp /etc/ssh/sshd_config "$sshd_backup_file"

    #
    #  Set the selected port
    #
    sed -i "/Port /c\Port $sshd_port" /etc/ssh/sshd_config

    #
    #  This needs to be run once after openrc is installed to set things up,
    #  running it again is harmless, so no need for a check if it was installed
    #
    printf "Initializing openrc..."
    rc-status > /dev/null 2>&1
    printf "Done!\n"

    if [[ "$(ls /home)" = "" ]]; then
        # Don't do this on AOK FS, it comes with users
        echo
        echo "Since no users are defined, root logins have been permitted"
        echo
        allow_root_logins="PermitRootLogin yes"
        if ! grep -q "$allow_root_logins" /etc/ssh/sshd_config; then
            echo  "$allow_root_logins" > /etc/ssh/sshd_config
        fi
    fi

    if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
        echo "Generating SSH host keys, this will take a few minutes..."
        ssh-keygen -A
    fi

    ish_service_disclaimer

    rc-update add sshd
    rc-service sshd start

    echo
    echo "Please be aware that in order for any account to be able to login"
    echo "using ssh, that account must have a password set!"
    echo "As the intended user, run: passwd"
    echo "To set a password"
    echo
    echo "sshd will be restarted each time iSH is run."
    echo "sshd listens on port $sshd_port"
}

disable_sshd() {
    echo "Disabling sshd service"
    echo
    ish_service_disclaimer

    rc-service sshd stop
    rc-update del sshd
}

dialog_console() {

    bcu_file="/proc/ish/defaults/blink_cursor"
    state="$(cat $bcu_file)"
    if [[ "$state" = "true" ]]; then
        CUB_CUR="on"
    else
        CUB_CUR="off"
    fi

    bme_file="/proc/ish/defaults/backtick_mapping_escape"
    state="$(cat $bme_file)"
    if [[ "$state" = "true" ]]; then
        BME_CUR="on"
    else
        BME_CUR="off"
    fi

    ddi_file="/proc/ish/defaults/disable_dimming"
    state="$(cat $ddi_file)"
    if [[ "$state" = "true" ]]; then
        DDI_CUR="on"
    else
        DDI_CUR="off"
    fi

    hek_file="/proc/ish/defaults/hide_extra_keys_with_external_keyboard"
    if [[ -f $hek_file ]]; then
        state="$(cat $hek_file)"
        if [[ "$state" = "true" ]]; then
            EKH_CUR="on"
        else
            EKH_CUR="off"
        fi
    else
        EKH_CUR="unavailable"
    fi

    hsb_file="/proc/ish/defaults/hide_status_bar"
    state="$(cat $hsb_file)"
    if [[ "$state" = "true" ]]; then
        SBH_CUR="on"
    else
        SBH_CUR="off"
    fi

    ocs_file="/proc/ish/defaults/override_control_space"
    if [[ -f $ocs_file ]]; then
        state="$(cat $ocs_file)"
        if [[ "$state" = "true" ]]; then
            OCS_CUR="on"
        else
            OCS_CUR="off"
        fi
    else
        OCS_CUR="unavailable"
    fi

    optional_items=()
    #
    #  Depending on kernel versions some console features might be unavailable
    #
    if [[ $EKH_CUR != "unavailable" ]]; then
        optional_items+=("ekh" "Hide extra keys with external keyboard" "$EKH_CUR")
    fi
    if [[ $OCS_CUR != "unavailable" ]]; then
        optional_items+=("ocs" "Override Control Space" "$OCS_CUR")
    fi

    #  Min sizses
    #    whiptail 14 56 7
    console=$($dialog_app                                                   \
        --title     "Console Settings"                                      \
        --ok-button "Update"                                                \
        --checklist "Select features to be active:" 0 0 0                   \
        "bme"       "Backtick  Mapping Escape"                "$BME_CUR"    \
        "cub"       "Blinking Cursor"                         "$CUB_CUR"    \
        "ddi"       "Disable Dimming"                         "$DDI_CUR"    \
        "sbh"       "Hide Status Bar"                         "$SBH_CUR"    \
        "${optional_items[@]}"                                              \
        3>&2 2>&1 1>&3-)

    exitstatus=$?
    test $exitstatus -ne 0 && return  # abort on cancel

    #
    #  Blinking Cursor
    #
    if echo "$console" | grep -q "cub"; then
        cub_new="on"
        kernel_param="true"
    else
        cub_new="off"
        kernel_param="false"
    fi
    # Only apply if changed
    [[ "$CUB_CUR" != "$cub_new" ]] && echo "$kernel_param" > "$bcu_file"

    #
    #  Backtick Mapping Escape
    #
    if echo "$console" | grep -q "bme"; then
        bme_new="on"
        kernel_param="true"
    else
        bme_new="off"
        kernel_param="false"
    fi
    [[ "$BME_CUR" != "$bme_new" ]] && echo "$kernel_param" > "$bme_file"

    #
    #  Disable Dimming
    #
    if echo "$console" | grep -q "ddi"; then
        ddi_new="on"
        kernel_param="true"
    else
        ddi_new="off"
        kernel_param="false"
    fi
    [[ "$DDI_CUR" != "$ddi_new" ]] && echo "$kernel_param" > "$ddi_file"

    #
    #  Hide extra keys with external keyboard
    #
    if echo "$console" | grep -q "ekh"; then
        ekh_new="on"
        kernel_param="true"
    else
        ekh_new="off"
        kernel_param="false"
    fi
    [[ "$EKH_CUR" != "$ekh_new" ]] && echo "$kernel_param" > "$hek_file"

    #
    #  Hide Status Bar
    #
    if echo "$console" | grep -q "sbh"; then
        sbh_new="on"
        kernel_param="true"
    else
        sbh_new="off"
        kernel_param="false"
    fi
    [[ "$SBH_CUR" != "$sbh_new" ]] && echo "$kernel_param" > "$hsb_file"

    #
    #  Override Control Space
    #
    if echo "$console" | grep -q "ocs"; then
        ocs_new="on"
        kernel_param="true"
    else
        ocs_new="off"
        kernel_param="false"
    fi
    [[ "$OCS_CUR" != "$ocs_new" ]] && echo "$kernel_param" > "$ocs_file"
}


dialog_options() {   # TODO: VNC
    optional_items=()

    if [[ -n "$(command -v rc-status)" ]] &&  rc-status -a | grep -qw sshd ; then
        SSHD_CUR="ON"
    else
        SSHD_CUR="OFF"
    fi

    options=$($dialog_app                                   \
        --title "Optional Features"                         \
        --ok-button "Update"                                \
        --checklist "Select what should be active:" 0 0 0   \
        "sshd" "Run sshd service" "$SSHD_CUR"               \
        "${optional_items[@]}"                              \
        3>&2 2>&1 1>&3-)

    exitstatus=$?
    test $exitstatus -ne 0 && return  # abort on cancel

    if [[ $options == *sshd* ]]; then
        sshd_new="ON"
    else
        sshd_new="OFF"
    fi
    if [[ "$SSHD_CUR" != "$sshd_new" ]]; then
        [[ $sshd_new = "ON" ]] && script=enable_sshd || script=disable_sshd
        if [[ $script = "enable_sshd" ]]; then
            sshd_port="$(
                grep -i ^port /etc/ssh/sshd_config | awk 'NF>1{print $NF}'
                )"
            test -z "$sshd_port" && sshd_port=2222  # default
            sshd_port=$($dialog_app                     \
                --nocancel                              \
                --inputbox "sshd port" 8 13 $sshd_port  \
                3>&2 2>&1 1>&3)
        fi

        $script

        echo
        read -n 1 -r -s -p $'Press enter to continue...\n'
        clear
    fi
}


dialog_software() {

    py_bin="$(command -v python3)"
    if [[ -n $py_bin ]]; then
        PY3_CUR="on"
    else
        PY3_CUR="off"
    fi

    opt_softw=$($dialog_app                                 \
        --title     "Optional Software"                     \
        --ok-button "Update"                                \
        --checklist "Select items to be installed:" 0 0 30  \
        "py3"       "Python3"                   "$PY3_CUR"  \
        3>&2 2>&1 1>&3-)

    exitstatus=$?
    test $exitstatus -ne 0 && return  # abort on cancel

    if echo "$opt_softw" | grep -q "py3"; then
        py3_new="on"
    else
        py3_new="off"
    fi

    if [[ $PY3_CUR != "$py3_new" ]]; then
        clear
        if [[ $py3_new = "on" ]]; then
            echo "Installing Python3..."
            apk add py3-pip
        else
            echo "Removing Python3..."
            apk del py3-pip python3
        fi
        echo
        read -p $"Press enter to continue\n"
        clear
    fi
}


dialog_aok_tweaks() {
    # It has already been verified this is an AOK kernel...

    elock_file="/proc/ish/defaults/enable_extralocking"
    state="$(cat $elock_file)"
    if [[ "$state" = "true" ]]; then
        ELOCK_CUR="on"
    else
        ELOCK_CUR="off"
    fi

    mc_file="/proc/ish/defaults/enable_multicore"
    state="$(cat $mc_file)"
    if [[ "$state" = "true" ]]; then
        MC_CUR="on"
    else
        MC_CUR="off"
    fi


    tweaks=$($dialog_app                                                    \
        --title     "Kernel Tweaks"                                         \
        --ok-button "Update"                                                \
        --checklist "Select features to be active:" 0 0 0                   \
        "elock"     "Switch extra locking on or off"         "$ELOCK_CUR"   \
        "mc"        "Switch multicore processing on or off"  "$MC_CUR"      \
        3>&2 2>&1 1>&3-)

    exitstatus=$?
    test $exitstatus -ne 0 && return  # abort on cancel

    #
    #  Switch extra locking on or off.
    #
    if echo "$tweaks" | grep -q "elock"; then
        elock_new="on"
        kernel_param="true"
    else
        elock_new="off"
        kernel_param="false"
    fi
    # Only apply if changed
    [[ "$ELOCK_CUR" != "$elock_new" ]] && echo "$kernel_param" > "$elock_file"

    #
    #  Switch multicore processing on or off.
    #
    if echo "$tweaks" | grep -q "mc"; then
        mc_new="on"
        kernel_param="true"
    else
        mc_new="off"
        kernel_param="false"
    fi
    # Only apply if changed
    [[ "$MC_CUR" != "$mc_new" ]] && echo "$kernel_param" > "$mc_file"
}


main() {
    optional_items=()
    #  Only available for AOK kernels
    if [[ -e /proc/ish/defaults/enable_multicore ]]; then
        optional_items+=("Tweaks" "AOK kernel tweaks")
    fi

    main_menu=$($dialog_app                               \
        --title "Select option to configure"              \
        --backtitle "iSH-AOK Options"                     \
        --ok-button "Select"                              \
        --cancel-button "Exit"                            \
        --menu "" 0 0 0                                   \
        "Console"     "Settings for the ish-app console"  \
        "Options"     "Select services to be enabled"     \
        "Software"    "Install some common stuff"         \
        "Time-Zone"   "Set time zone"                     \
       "${optional_items[@]}"                             \
        3>&2 2>&1 1>&3-)

    case "$main_menu" in

        "Console")
            dialog_console
            ;;

        "Options")
            dialog_options
            ;;

        "Software")
            dialog_software
            ;;

        "Time-Zone")
            current_dir="$(dirname -- "$(realpath "$0")")"
            "$current_dir"/set-timezone.sh
            ;;

        "Tweaks")
            dialog_aok_tweaks
            ;;

        *) exit ;;

    esac
    main
}


if [[ "$(whoami)" != 'root' ]]; then
    echo "Please run as root or using sudo"
    exit 1;
fi

main

