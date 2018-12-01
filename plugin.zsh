if [ -n "$(uname | grep -i freebsd)" ]; then
    grep='/usr/local/bin/grep'
    if [[ ! -f $grep ]]; then
        echo "Install GNU grep: pkg install gnugrep"
        return 1
    fi
    pattern='s/^([^:]+:[^:]+):\s*(.*)/\1:  \2/'

elif [ -n "$(uname | grep -i darwin)" ]; then
    grep=`which ggrep`
    if [[ ! -f $grep ]]; then
        echo "Install GNU grep: brew install grep"
        return 1
    fi
    pattern='s/^([^:]+:[^:]+):\s*(.*)/\x1b[35m\1\x1b[0m:  \2/'

else
    grep='grep'
    pattern='s/^([^:]+:[^:]+):\s*(.*)/\x1b[35m\1\x1b[0m:  \2/'
fi


function :fuzzy-search-and-edit:get-files() {
    local directory="$1"
    local fifo="$2"
    cd "$directory"
    command $grep --line-buffered -r -nEHI '[[:alnum:]]' "." --color=never --exclude-dir=".git" \
        | cut -b3- \
        | command sed -ru $pattern > "$fifo"
}


function :fuzzy-search-and-edit:get-files-custom() {
    local directory="$1"
    local fifo="$2"
    cd "$directory"
    command $grep --line-buffered -r -nEHI '[[:alnum:]]' "." --color=never --exclude-dir=".git" \
        --include="*.php" \
        --include="*.js"  \
        --include="*.py"  \
        --include="*.rb"  \
        --include="*.liq" \
        --include="*.xml" \
        --include="*.htm" \
        --include="*.css" \
        --include="*.ini" \
        --include="*.sql" \
        --include="*.json" \
        --include="*.txt" \
        --include="*.conf" \
        --include="*.html" \
        | cut -b3- \
        | command sed -ru $pattern > "$fifo"
}


function :fuzzy-search-and-edit:abort-job() {
    local match

    read -r match
    printf "%s\n" "$match"

    async_flush_jobs ":fuzzy-search-and-edit:worker"
}


function fuzzy-search-and-edit() {
    local dir="$(mktemp -d /tmp/fuzzy-search-and-edit.XXXXXX)"
    local fifo="$dir/fifo"

    mkfifo "$fifo"

    async_job ":fuzzy-search-and-edit:worker" ":fuzzy-search-and-edit:get-files" "$(pwd)" "$fifo"

    local match=$(
        fzf +x --ansi -1 < "$fifo" \
            | :fuzzy-search-and-edit:abort-job
    )

    if [ "$match" ]; then
        local file
        local line

        IFS=: read -r file line _ <<< "$match"

        "${=EDITOR}" "+$line" "$file" < /dev/tty
    fi

    rm -r "$dir"
    find /tmp -maxdepth 1 -name "fuzzy-search-and-edit.*" -user $USER -type d -mmin +30 -exec rm -rf {} \;

    zle -I
}

:fuzzy-search-and-edit:completed() {
    :
}

async_start_worker ":fuzzy-search-and-edit:worker"
async_register_callback ":fuzzy-search-and-edit:worker" \
    ":fuzzy-search-and-edit:completed"

zle -N fuzzy-search-and-edit
