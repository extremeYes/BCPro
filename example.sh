#!/usr/bin/env bash

#shellcheck disable=SC2034
#shellcheck disable=SC2329

source "$(dirname "$(readlink -e "$0")")/pro.sh"
(($?)) && exit 1

# ========== Main ==========

main() {

    # Library Usage!
    spin-subproc channel p_channel

    # Example
    local i j
    for j in {1..5}; do
        {
            for i in {1..10}; do
                noti "$i"
            done
        } > "${g_pipe[channel]}"
        noti "num: $j" > "${g_pipe[channel]}"
        sleep .4
    done

    echo "EOP" > "${g_pipe[channel]}"

    # fatal "cry"
    wait "${g_subproc[channel]}"

}

# ================ ~MAIN~ ================
main "$@"
# ========================================
