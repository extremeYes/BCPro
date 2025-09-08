#!/usr/bin/env bash

#shellcheck disable=SC2034
#shellcheck disable=SC2329

source "$(dirname "$(readlink -e "$0")")/BCPro.sh"
(($?)) && exit 1

# ========== Main ==========

main() {

    # Library Usage!
    bcpro_init

    # Example
    local i j
    for j in {1..5}; do
        {
            msg_head foo

            for i in {1..10}; do
                echo "$i"
            done
            echo "num: $j"
        } > "$G_REL"
        sleep .4
    done

    echo "EOP" > "$G_REL"

    wait "${g_proc[relay]}"

}

# ================ ~MAIN~ ================
main "$@"
# ========================================
