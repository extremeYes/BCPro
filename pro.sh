
#shellcheck disable=SC2034

# ========================================
# ================ ~PRO~ =================
# ========================================

trap-cleanup() {
    local dir=$1
    shift
    local killtargets=("$@")

    local p
    for p in "${killtargets[@]}"; do
        kill "$p" 2>/dev/null
    done

    rm -rf "$dir"
}

# ========== Main ==========

pro_main() {

    # Globals
    declare -g g_pipedir
    declare -gA g_pipe
    declare -gA g_subproc

    # Trap to clean all pipes and subprocesses
    trap 'trap-cleanup "$g_pipedir" "${g_subproc[@]}"' EXIT SIGINT SIGTERM

    if ! g_pipedir=$(mktemp -d); then
        fatal "Failed to create temporary directory"
    fi

}

spin-subproc() {
    local name=$1
    local process=$2
    local args=$3
    [[ $# -lt 2 || $# -gt 3 ]] && fatal-assert "Use <name> <process> [args] as parameters for spin-subproc"

    make-pipe "$name"

    # see about error handling here
    bash -c "$process ${g_pipe[$name]} $args" &

    g_subproc[$name]=$!
}

make-pipe() {
    local pipename=$1

    local pipepath="$g_pipedir/$RANDOM.$RANDOM.$RANDOM"
    if ! mkfifo "$pipepath"; then
        fatal "Failed to create pipe"
    fi

    g_pipe[$pipename]=$pipepath
}

# ========== Sub-processes ==========
#
# All processes take the name of their corresponding pipe as the first argument.
# This pipe is the mailing box of the process, used to talk to it.
#

# it prints stuff for now, but this will be the main communication channel
p_channel() {
    local pipe=$1
    [[ -z $pipe ]] && return 2 # improve UX

    # main loop
    local EOP=0
    local line
    until ((EOP)); do
        while IFS= read -r line; do
            noti "[channel] $line"
            [[ $line == 'EOP' ]] && EOP=1
        done < "$pipe"
        noti "[channel] <EOF found>"
    done
    noti "[channel] <EOP found>"
}

export -f p_channel


# ==========
# ====================
# ==============================
# ========================================
# ==============================
# ====================
# ==========


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

fatal-assert() {
    erro "  Fatal Assertion Failure (bug):"
    fatal "    $*"
}

#shellcheck disable=SC1090
load-module() {
    local mod="$HERE/modules/$1.sh"

    source "$mod" 2>/dev/null || fatal "Could not load module: $mod"
}

canonical-path() {
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

export -f noti erro fatal fatal-assert load-module canonical-path

# ================ ~MAIN~ ================
pro_main
# ========================================
