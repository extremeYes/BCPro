
#shellcheck disable=SC2034

# ========================================
# =============== ~BCPro~ ================
# ========================================

# ===================================
# ============== Main ===============
# ===================================

bcpro_init() {

    # Globals
    declare -xg G_HERE G_SYSTEM

    declare -xg G_PIPEDIR # the temporary directory in which to store named pipes

    declare -gA g_pipe # an array containing the path to each named pipe
    declare -gA g_proc # an array containing the PIDs of each created process

    declare -xg G_REL # pipe to the communication relay

    # Name of the main program (might change this)
    BASH_ARGV0=main
    make_pipe main

    # Program path
    G_HERE=$(canonical_path "$0")
    G_HERE=${G_HERE%/*} # dirname

    # System recognition
    if cmd_exists cygpath; then
        G_SYSTEM=win
    else
        G_SYSTEM=lin
    fi

    # Trap to clean all pipes and subprocesses
    trap 'trap_cleanup "$G_PIPEDIR" "${g_proc[@]}"' EXIT SIGINT SIGTERM

    if ! G_PIPEDIR=$(mktemp -d); then
        fatal "Failed to create temporary directory"
    fi

    spin_proc relay p_relay

    G_REL="${g_pipe[relay]}"

}

spin_proc() {
    local name=$1
    local fn=$2
    local args=$3
    [[ $# -lt 2 || $# -gt 3 ]] && fatal_assert "Use <name> <fn> [args] as parameters for spin_proc"

    make_pipe "$name"

    bash -c '$1 "$2" "$3"' "$name" "$fn" "${g_pipe[$name]}" "$args" &

    g_proc[$name]=$!
}

make_pipe() {
    local name=$1

    local pipepath="$G_PIPEDIR/$RANDOM.$RANDOM.$RANDOM"
    if ! mkfifo "$pipepath"; then
        fatal "Failed to create pipe"
    fi

    g_pipe[$name]=$pipepath
}

msg_head() {
    # ~>sender>receiver
    echo "~>$0>$1"
}

export -f spin_proc make_pipe

# ===================================
# ========== Sub-Processes ==========
# ===================================
#
# All processes take the name of their corresponding pipe as the first argument.
# This pipe is the mailing box of the process, used to talk to it.
#

# it prints stuff for now, but this will be the main communication channel
p_relay() {
    local pipe=$1
    [[ -z $pipe ]] && return 2 # improve UX

    # main loop
    local EOP=0
    local line
    until ((EOP)); do
        while IFS= read -r line; do
            noti "[relay] $line"
            [[ $line == 'EOP' ]] && EOP=1
        done < "$pipe"
        noti "[relay] <EOF found>"
    done
    noti "[relay] <EOP found>"
}

export -f p_relay

# ==========
# ====================
# ==============================
# ========================================
# ================================================================================
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ================================================================================
# ========================================
# ==============================
# ====================
# ==========

cmd_exists() {
    command -v "$1" &>/dev/null
    return $?
}

trap_cleanup() {
    local dir=$1
    shift
    local killtargets=("$@")

    local p
    for p in "${killtargets[@]}"; do
        kill "$p" 2>/dev/null
    done

    rm -rf "$dir"
}

# ========== Constants ==========

# ANSI Colors
C_RESET=$'\e[m'
C_RED=$'\e[31m'
C_BLUE=$'\e[34m'
C_PURPLE=$'\e[35m'
C_GREEN_B=$'\e[1;32m'
C_RED_B_BL=$'\e[1;5;31m'
C_UNDERLINE=$'\e[4m'
C_NOT_UNDERLINE=$'\e[24m'
C_STRIKETHROUGH=$'\e[9m'

echo -n $'\e[m' # just for clean tracing

export C_RESET C_RED C_BLUE C_PURPLE C_GREEN_B C_RED_B_BL C_UNDERLINE C_NOT_UNDERLINE C_STRIKETHROUGH

# ========== Essential Functions ==========

noti() {
    echo "$C_PURPLE#>>>$C_RESET${*}"
}

erro() {
    echo "$C_RED!>>>$C_RESET${*}" >&2
    return 1
}

fatal() {
    erro "$*"
    exit 1
}

fatal_assert() {
    erro "  Fatal Assertion Failure (bug):"
    fatal "    $*"
}

#shellcheck disable=SC1090
load_module() {
    local mod="$HERE/modules/$1.sh"

    source "$mod" 2>/dev/null || fatal "Could not load module: $mod"
}

canonical_path() {
    local path=$1

    local old_path
    while true; do
        old_path=$path
        path=$(readlink -e -- "$path")
        (($?)) && return 1
        [[ $path == "$old_path" ]] && break
    done

    echo "$path"
}

export -f noti erro fatal fatal_assert load_module canonical_path

# ========== File Operations ==========

file_to_array() {
    # file < stdin
    local -n arr=$1

    local line
    while read -r line || [[ -n "$line" ]]; do
        line=${line%$'\r'} # delete CR
        [[ -z "$line" ]] && continue

        arr+=("$line")
    done
}

load_config() {
    # configFile < stdin
    local -n table=$1
    local required_entries=$2
    local optional_entries=$3

    local entry value is_valid line

    while read -r line || [[ -n "$line" ]]; do
        line=${line%$'\r'} # delete CR
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        if [[ $line != *=* ]]; then
            fatal "Invalid line in config file: $line"
        fi

        entry=${line%%=*}
        value=${line#*=}

        is_valid=false
        for x in $required_entries $optional_entries; do
            [[ $entry == "$x" ]] && is_valid=true && break
        done
        if ! $is_valid; then
            fatal "Invalid entry in config file: $entry"
        fi

        if [[ -n ${table[$entry]} ]]; then
            fatal "Duplicate entry in config file: $entry"
        fi

        table[$entry]=$value
    done

    for x in $required_entries; do
        if [[ -z ${table[$x]} ]]; then
            fatal "Missing required entry in config file: $x"
        fi
    done
}

export -f file_to_array load_config
