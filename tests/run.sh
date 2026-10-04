#!/bin/sh
# End-to-end tests for dot. Every test runs in a throwaway HOME; nothing on
# the real machine is read or written.
#
#   sh tests/run.sh [shell]       e.g. sh tests/run.sh dash
#                                      sh tests/run.sh "busybox sh"
#
# Fake secrets are assembled at run time, so this file never contains one.
# $SH is split on purpose ("busybox sh"); single-quoted '$' is literal.
# shellcheck disable=SC2016,SC2086

set -u
SH=${1:-sh}
HERE=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
SRC=$HERE/../dot
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dot-test.XXXXXX")
ROOT=$(cd -P -- "$ROOT" && pwd -P)
trap 'rm -rf -- "$ROOT"' EXIT
PASS=0 FAIL=0
LOG=$ROOT/log

# A stub gh that is never logged in: no test can reach a real GitHub account.
mkdir -p "$ROOT/bin"
printf '#!/bin/sh\nexit 1\n' >"$ROOT/bin/gh"
chmod +x "$ROOT/bin/gh"
PATH=$ROOT/bin:$PATH
export PATH NO_COLOR=1 DOT_YES=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_CONFIG_NOSYSTEM=1

# rep <text> <n>: <text> repeated <n> times
rep() {
    r_s='' r_i=0
    while [ "$r_i" -lt "$2" ]; do
        r_s=$r_s$1 r_i=$((r_i + 1))
    done
    printf '%s' "$r_s"
}
GHTOKEN="gh""p_$(rep a 36)"
PRIVKEY="-----BEGIN OPENSSH ""PRIVATE KEY-----"
LOADS='. "$HOME/.config/sh/rc"'

ok() {
    PASS=$((PASS + 1))
    printf '  ok   %s\n' "$1"
}
no() {
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n' "$1"
}
check() { # check <description> <command...>
    c_d=$1
    shift
    if "$@" >>"$LOG" 2>&1; then ok "$c_d"; else no "$c_d"; fi
}
refute() { # refute <description> <command...>
    r_d=$1
    shift
    if "$@" >>"$LOG" 2>&1; then no "$r_d"; else ok "$r_d"; fi
}
same() { [ "$(cat "$1")" = "$2" ]; }
islink() { [ -L "$1" ]; }
contains() { grep -q -F -- "$2" "$1"; }
# has <text> <pattern>: the text contains the fixed string
has() { printf '%s' "$1" | grep -q -F -- "$2"; }
# says <pattern> <command...>: the command's output contains the pattern
says() {
    s_p=$1
    shift
    "$@" 2>&1 | grep -q -- "$s_p"
}
# some <glob>: at least one file matches
some() {
    for s_f in $1; do [ -e "$s_f" ] && return 0; done
    return 1
}
commits() { git -C "$REPO" rev-list --count HEAD; }

# machine <name>: fresh HOME with a dot repo at $REPO
machine() {
    export HOME=$ROOT/$1
    mkdir -p "$HOME/.config"
    export DOT_STATE=$HOME/.local/state/dot
    unset DOT_TARGET DOT_DIR XDG_CONFIG_HOME XDG_STATE_HOME
    REPO=$HOME/dotfiles
    CFG=$HOME/.config
    RC=$REPO/config
}
dot() { $SH "$REPO/dot" "$@"; }

printf 'dot tests with: %s\n' "$SH"

# --------------------------------------------------------------- capture
printf '%s\n' '[capture]'
machine m1
mkdir -p "$RC" && cp "$SRC" "$REPO/dot"
git -C "$REPO" init -q
git -C "$REPO" symbolic-ref HEAD refs/heads/main
for d in vim sh gh ssh rclone app big 'my dir'; do mkdir -p "$CFG/$d"; done
printf 'set number\n" not a password, just a comment about passwords\n' \
    >"$CFG/vim/vimrc"
printf '%s\n' 'export TOKEN=$OTHER_VARIABLE' \
    'export GH_TOKEN="$(gh auth token)"' 'alias ll="ls -l"' >"$CFG/sh/rc"
printf 'git_protocol: https\n' >"$CFG/gh/config.yml"
printf 'github.com:\n    oauth_token: %s\n' "$GHTOKEN" >"$CFG/gh/hosts.yml"
printf '%s\nabc\n' "$PRIVKEY" >"$CFG/ssh/id_rsa"
printf 'Host x\n' >"$CFG/ssh/config"
printf '[s5]\ntype = sftp\npass = %s\n' "$(rep Q 30)" \
    >"$CFG/rclone/rclone.conf"
printf 'name = fine\nkey = %s\n' "$GHTOKEN" >"$CFG/app/settings.ini"
printf 'theme = dark\napi_key = "%s"  # dot:allow\n' "$(rep z 20)" \
    >"$CFG/app/allowed.ini"
printf 'x\n' >"$CFG/.DS_Store"
printf 'ls\ncd\n' >"$CFG/sh/zsh_history"
printf 'a\000b' >"$CFG/app/blob.bin"
dd if=/dev/zero bs=1024 count=1100 2>/dev/null | tr '\000' 'x' \
    >"$CFG/big/huge.txt"
printf 'spaced\n' >"$CFG/my dir/file name.conf"
ln -s vimrc "$CFG/vim/init.vim"
ln -s /etc/hosts "$CFG/app/hosts-link"
# a plugin: a git clone with a remote
P=$ROOT/plugin-work
git init -q --bare "$ROOT/plugin.git"
git clone -q "$ROOT/plugin.git" "$P" 2>/dev/null
printf 'p\n' >"$P/plugin.vim"
git -C "$P" add . && git -C "$P" commit -q -m p
git -C "$P" push -q origin HEAD:main 2>/dev/null
git -C "$ROOT/plugin.git" symbolic-ref HEAD refs/heads/main
mkdir -p "$CFG/vim/pack/x/start"
git clone -q "$ROOT/plugin.git" "$CFG/vim/pack/x/start/plug"
ln -s .config/sh/rc "$HOME/.zshrc"

OUT=$(dot capture 2>&1)
check 'exit status 0' test $? -eq 0
check 'vimrc captured' same "$RC/vim/vimrc" "$(cat "$CFG/vim/vimrc")"
check 'rc with $VAR assignments captured (no false positive)' \
    test -f "$RC/sh/rc"
check 'gh/config.yml captured' test -f "$RC/gh/config.yml"
check 'file with spaces captured' test -f "$RC/my dir/file name.conf"
check 'dot:allow line keeps file' test -f "$RC/app/allowed.ini"
check 'internal symlink kept as link' islink "$RC/vim/init.vim"
refute 'gh/hosts.yml kept out' test -e "$RC/gh/hosts.yml"
refute 'ssh folder kept out' test -e "$RC/ssh"
refute 'rclone.conf kept out' test -e "$RC/rclone"
refute 'file with a token in its content kept out' \
    test -e "$RC/app/settings.ini"
refute '.DS_Store kept out' test -e "$RC/.DS_Store"
refute 'history kept out' test -e "$RC/sh/zsh_history"
refute 'binary kept out' test -e "$RC/app/blob.bin"
refute 'huge file kept out' test -e "$RC/big/huge.txt"
refute 'absolute symlink kept out' test -e "$RC/app/hosts-link"
refute 'plugin clone not copied' test -e "$RC/vim/pack"
check 'plugin recorded' contains "$REPO/dot.plugins" \
    "vim/pack/x/start/plug $ROOT/plugin.git main"
check 'home link recorded' contains "$REPO/dot.links" '.zshrc'
check '.zshrc recorded in source mode' \
    sh -c 'grep "^\.zshrc " "$1" | grep -q " source$"' _ "$REPO/dot.links"
check 'secret reported with line and rule' has "$OUT" \
    'app/settings.ini  (secret: line 2: GitHub token)'
refute 'secret value never printed' has "$OUT" "$GHTOKEN"
check 'commit created' test "$(commits)" = 1
check '.gitignore safety net written' \
    contains "$REPO/.gitignore" 'dot safety net'
check 'pre-commit hook installed' test -x "$REPO/.git/hooks/pre-commit"
OUT=$(dot capture 2>&1)
check 'second capture: nothing new' has "$OUT" '0 new, 0 updated'
check 'second capture: no extra commit' test "$(commits)" = 1

# --------------------------------------------------------- secret guard
printf '%s\n' '[secret guard]'
printf 'leak = %s\n' "$GHTOKEN" >"$RC/vim/leak.conf"
git -C "$REPO" add config/vim/leak.conf
refute 'pre-commit hook blocks a staged secret' \
    git -C "$REPO" commit -q -m leak
git -C "$REPO" rm -q --cached config/vim/leak.conf
rm "$RC/vim/leak.conf"
mkdir -p "$RC/ssh" && printf 'x\n' >"$RC/ssh/known"
git -C "$REPO" add -f config/ssh/known
refute 'pre-commit hook blocks an ignored path' \
    git -C "$REPO" commit -q -m ssh
git -C "$REPO" rm -q --cached config/ssh/known
rm -r "$RC/ssh"
printf 'k = %s\n' "$GHTOKEN" >"$ROOT/loose.txt"
refute 'scan <file> exits 1 on a secret' dot scan "$ROOT/loose.txt"
check 'scan of the clean repo passes' dot scan
check 'scan --history passes' dot scan --history
check 'explain names the rule' \
    says "rule .gh/hosts.yml\*." dot explain gh/hosts.yml
check 'explain: backed up file' says 'backed up' dot explain vim/vimrc
dot ignore 'vim/init.vim' >/dev/null
dot capture --prune >>"$LOG" 2>&1
refute 'ignore + capture --prune removes the file from the repo' \
    test -e "$RC/vim/init.vim"
check 'dot status runs' dot status
check 'dot rules runs' dot rules
check 'completion script lists the commands' \
    says 'rollback snapshot adopt' dot completion

# ------------------------------------------------ apply on a new machine
printf '%s\n' '[apply: new machine]'
M1=$REPO
machine m2
rm -rf "$CFG"
git clone -q "$M1" "$REPO"
dot apply >>"$LOG" 2>&1
check 'apply exit 0' test $? -eq 0
check 'files placed' same "$CFG/vim/vimrc" "$(cat "$M1/config/vim/vimrc")"
check 'spaced file placed' test -f "$CFG/my dir/file name.conf"
check 'home link created' islink "$HOME/.zshrc"
check 'home link resolves' test -f "$HOME/.zshrc"
check 'home link is relative' \
    test "$(readlink "$HOME/.zshrc")" = .config/sh/rc
check 'plugin cloned' test -f "$CFG/vim/pack/x/start/plug/plugin.vim"
check 'backup recorded' some "$DOT_STATE/backups/*/manifest"
refute 'no snapshot when ~/.config was empty' \
    some "$DOT_STATE/snapshots/*"
dot rollback >>"$LOG" 2>&1
refute 'rollback removes what apply created' test -e "$CFG/vim/vimrc"
refute 'rollback removes the home link' test -e "$HOME/.zshrc"
dot rollback >>"$LOG" 2>&1
check 'rollback of the rollback brings it back' test -f "$CFG/vim/vimrc"

# ----------------------------------------- apply on a lived-in machine
printf '%s\n' '[apply: existing machine]'
machine m3
git clone -q "$M1" "$REPO"
mkdir -p "$CFG/vim" "$CFG/other"
printf 'mine\n' >"$CFG/vim/vimrc"
printf 'keep me\n' >"$CFG/other/conf"
printf 'my zshrc\n' >"$HOME/.zshrc"
REPO_VIMRC=$(cat "$M1/config/vim/vimrc")
dot apply -n >>"$LOG" 2>&1
check 'dry run changes nothing' same "$CFG/vim/vimrc" mine
refute 'dry run creates nothing' test -e "$CFG/gh/config.yml"
dot apply --keep >>"$LOG" 2>&1
check 'keep: my vimrc stays' same "$CFG/vim/vimrc" mine
check 'keep: new files still added' test -f "$CFG/gh/config.yml"
check 'keep: unrelated files untouched' same "$CFG/other/conf" 'keep me'
check 'keep: existing ~/.zshrc kept' same "$HOME/.zshrc" 'my zshrc'
check 'first apply on a used machine takes a snapshot' \
    some "$DOT_STATE/snapshots/*.tar*"
dot apply --overwrite >>"$LOG" 2>&1
check 'overwrite: repo vimrc in place' same "$CFG/vim/vimrc" "$REPO_VIMRC"
check 'overwrite: existing ~/.zshrc now loads the rc' \
    contains "$HOME/.zshrc" "$LOADS"
check 'overwrite: existing ~/.zshrc keeps its lines' \
    contains "$HOME/.zshrc" 'my zshrc'
check 'overwrite: unrelated files untouched' \
    same "$CFG/other/conf" 'keep me'
dot rollback >>"$LOG" 2>&1
check 'rollback restores my vimrc' same "$CFG/vim/vimrc" mine
check 'rollback restores my ~/.zshrc' same "$HOME/.zshrc" 'my zshrc'
check 'backups lists entries' says undo- dot backups
touch -t 203001010000 "$CFG/vim/vimrc"
dot apply --newer >>"$LOG" 2>&1
check 'newer: my newer file stays' same "$CFG/vim/vimrc" mine
touch -t 200001010000 "$CFG/vim/vimrc"
dot apply --newer >>"$LOG" 2>&1
check 'newer: older file replaced' same "$CFG/vim/vimrc" "$REPO_VIMRC"
chmod 600 "$CFG/vim/vimrc" && printf 'changed\n' >"$CFG/vim/vimrc"
dot apply --overwrite >>"$LOG" 2>&1
check 'overwrite keeps existing permissions' \
    says '^-rw-------' ls -l "$CFG/vim/vimrc"

# ------------------------------------------- link mode, overlays, adopt
printf '%s\n' '[link mode, overlays, adopt]'
machine m4
git clone -q "$M1" "$REPO"
dot apply --link >>"$LOG" 2>&1
check 'link mode: file is a symlink' islink "$CFG/vim/vimrc"
check 'link mode: points into the repo' test "$(readlink "$CFG/vim/vimrc")" \
    = "$(cd -P "$REPO" && pwd -P)/config/vim/vimrc"
HOSTNAME_=$(dot status 2>/dev/null | sed -n 's/.*, host \([^ ]*\).*/\1/p')
HO=$REPO/overlay/host.$HOSTNAME_
mkdir -p "$HO/gh"
printf 'host specific\n' >"$HO/gh/config.yml"
dot apply --copy --overwrite >>"$LOG" 2>&1
check "host overlay wins (host.$HOSTNAME_)" \
    same "$CFG/gh/config.yml" 'host specific'
printf 'host edit\n' >"$CFG/gh/config.yml"
dot capture --no-commit >>"$LOG" 2>&1
check 'capture writes back into the host overlay' \
    same "$HO/gh/config.yml" 'host edit'
check 'common copy untouched' same "$RC/gh/config.yml" 'git_protocol: https'
printf 'startup_message off\n' >"$HOME/.screenrc"
dot adopt "$HOME/.screenrc" >>"$LOG" 2>&1
check 'adopt moves the file into ~/.config' \
    same "$CFG/screen/screenrc" 'startup_message off'
check 'adopt links it back' islink "$HOME/.screenrc"
check 'adopt records the link' contains "$REPO/dot.links" '.screenrc'
dot rollback >>"$LOG" 2>&1
check 'rollback of adopt restores the real file' \
    sh -c '[ -f "$1" ] && [ ! -L "$1" ]' _ "$HOME/.screenrc"
refute 'rollback of adopt removes the moved copy' \
    test -e "$CFG/screen/screenrc"

# ------------------------------------------------------------- bash rc
printf '%s\n' '[shell rc files: source mode]'
BASH_ENTRY='.bashrc              sh/rc        source'
# an Ubuntu-style home: a .bashrc, and a .profile that already loads it
machine m6
git clone -q "$M1" "$REPO"
printf '%s\n' "$BASH_ENTRY" >>"$REPO/dot.links"
printf 'DOT_TEST_RC=loaded\n' >>"$RC/sh/rc"
printf '# distro defaults\nHISTSIZE=1000\n' >"$HOME/.bashrc"
printf '%s\n' 'if [ -n "$BASH_VERSION" ]; then' '    . "$HOME/.bashrc"' \
    'fi' >"$HOME/.profile"
cp "$HOME/.profile" "$ROOT/profile.orig"
dot apply >>"$LOG" 2>&1
check 'existing .bashrc kept' contains "$HOME/.bashrc" 'HISTSIZE=1000'
check '.bashrc now loads the shared rc' contains "$HOME/.bashrc" "$LOADS"
check 'sourcing .bashrc really loads it' \
    says loaded sh -c '. "$1"; echo "$DOT_TEST_RC"' _ "$HOME/.bashrc"
check '.profile that loads .bashrc is untouched' \
    cmp "$HOME/.profile" "$ROOT/profile.orig"
refute 'no .bash_profile shadowing .profile' test -e "$HOME/.bash_profile"
dot apply >>"$LOG" 2>&1
check 'second apply adds no duplicate line' \
    test "$(grep -c 'config/sh/rc' "$HOME/.bashrc")" = 1
check 'status counts it as linked' says ' 0 not linked' dot status
dot rollback >>"$LOG" 2>&1
refute 'rollback removes the added line' \
    contains "$HOME/.bashrc" 'config/sh/rc'
check 'rollback keeps the original lines' \
    contains "$HOME/.bashrc" 'HISTSIZE=1000'
# a macOS-style home: no .bashrc, no .profile
machine m7
git clone -q "$M1" "$REPO"
printf '%s\n' "$BASH_ENTRY" >>"$REPO/dot.links"
dot apply >>"$LOG" 2>&1
check 'missing .bashrc becomes a symlink' islink "$HOME/.bashrc"
check 'missing .zshrc becomes a symlink' islink "$HOME/.zshrc"
check 'login shells get a .bash_profile' \
    contains "$HOME/.bash_profile" '. "$HOME/.bashrc"'
# an existing .zshrc (a framework's, say) is kept and gets the line
machine m9
git clone -q "$M1" "$REPO"
printf 'export ZSH_THEME=robbyrussell\n' >"$HOME/.zshrc"
dot apply >>"$LOG" 2>&1
check 'existing .zshrc keeps its lines' contains "$HOME/.zshrc" 'ZSH_THEME'
check 'existing .zshrc now loads the rc' contains "$HOME/.zshrc" "$LOADS"
refute 'existing .zshrc stays a regular file' islink "$HOME/.zshrc"
dot apply >>"$LOG" 2>&1
check 'no duplicate line in .zshrc' \
    test "$(grep -c 'config/sh/rc' "$HOME/.zshrc")" = 1
# an existing .bash_profile that does not load .bashrc
machine m8
git clone -q "$M1" "$REPO"
printf '%s\n' "$BASH_ENTRY" >>"$REPO/dot.links"
printf 'export EDITOR=vi\n' >"$HOME/.bash_profile"
printf 'mine\n' >"$HOME/.bashrc"
dot apply --keep >>"$LOG" 2>&1
check '--keep leaves .bashrc alone' same "$HOME/.bashrc" mine
dot apply --overwrite >>"$LOG" 2>&1
check '.bash_profile now loads .bashrc' \
    contains "$HOME/.bash_profile" '. "$HOME/.bashrc"'
check '.bash_profile keeps its lines' \
    contains "$HOME/.bash_profile" 'EDITOR=vi'

# --------------------------------------------- secrets (opt-in, openssl)
printf '%s\n' '[secrets: encrypted in the repo, opt-in]'
machine m10
git clone -q "$M1" "$REPO"
mkdir -p "$CFG/gh"
printf 'github.com:\n    oauth_token: %s\n' "$GHTOKEN" >"$CFG/gh/hosts.yml"
KEY=$HOME/.local/share/dot/key
check 'secret init makes a key' dot secret init --openssl
check 'the key is private (600)' says '^-rw-------' ls -l "$KEY"
dot secret add gh/hosts.yml >>"$LOG" 2>&1
ENC=$REPO/secrets/gh/hosts.yml.enc
check 'secret add encrypts it into secrets/' test -f "$ENC"
refute 'no plain text in the encrypted file' contains "$ENC" "$GHTOKEN"
check 'it is listed in dot.secrets' contains "$REPO/dot.secrets" 'gh/hosts.yml'
dot capture >>"$LOG" 2>&1
check 'the encrypted file is committed' \
    git -C "$REPO" ls-files --error-unmatch secrets/gh/hosts.yml.enc
refute 'the plain file is not committed' \
    git -C "$REPO" ls-files --error-unmatch config/gh/hosts.yml
check 'scan accepts the encrypted file' dot scan
cp "$ENC" "$ROOT/enc.before"
printf 'changed: yes\n' >>"$CFG/gh/hosts.yml"
dot capture >>"$LOG" 2>&1
check 'without --secrets the encrypted copy is left alone' \
    cmp "$ENC" "$ROOT/enc.before"
dot capture --secrets >>"$LOG" 2>&1
refute 'capture --secrets re-encrypts a changed secret' \
    cmp "$ENC" "$ROOT/enc.before"
check 'secret list says it is up to date' says 'up to date' dot secret list
SECRET_ORIG=$(cat "$CFG/gh/hosts.yml")
M10=$REPO M10KEY=$KEY
# another machine with the same key
machine m11
git clone -q "$M10" "$REPO"
mkdir -p "$HOME/.local/share/dot"
cp "$M10KEY" "$HOME/.local/share/dot/key"
dot apply >>"$LOG" 2>&1
refute 'apply without --secrets decrypts nothing' test -e "$CFG/gh/hosts.yml"
dot apply --secrets >>"$LOG" 2>&1
check 'apply --secrets restores the file' \
    same "$CFG/gh/hosts.yml" "$SECRET_ORIG"
check 'the restored secret is private (600)' \
    says '^-rw-------' ls -l "$CFG/gh/hosts.yml"
# a machine with a different key
machine m12
git clone -q "$M10" "$REPO"
dot secret init --openssl >>"$LOG" 2>&1
dot apply --secrets >>"$LOG" 2>&1
refute 'a wrong key decrypts nothing' test -e "$CFG/gh/hosts.yml"
# the right key, but a tampered file
cp "$M10KEY" "$HOME/.local/share/dot/key"
awk 'NR == 3 { c = substr($0, 1, 1); $0 = (c == "A" ? "B" : "A") \
    substr($0, 2) } { print }' "$REPO/secrets/gh/hosts.yml.enc" \
    >"$ROOT/tampered" && cp "$ROOT/tampered" "$REPO/secrets/gh/hosts.yml.enc"
dot apply --secrets >>"$LOG" 2>&1
refute 'a tampered file is refused' test -e "$CFG/gh/hosts.yml"
printf 'k = %s\n' "$GHTOKEN" >"$REPO/secrets/leak.enc"
git -C "$REPO" add -f secrets/leak.enc
refute 'pre-commit hook refuses plain text in secrets/' \
    git -C "$REPO" commit -q -m leak
# the age backend, when age is installed
if command -v age >/dev/null 2>&1 && command -v age-keygen >/dev/null 2>&1
then
    machine m13
    git clone -q "$M1" "$REPO"
    mkdir -p "$CFG/gh"
    printf 'token: %s\n' "$GHTOKEN" >"$CFG/gh/hosts.yml"
    dot secret init --age >>"$LOG" 2>&1
    check 'age: the key is an age identity' \
        contains "$HOME/.local/share/dot/key" 'AGE-SECRET-KEY-'
    dot secret add gh/hosts.yml >>"$LOG" 2>&1
    check 'age: stored as an age file' contains \
        "$REPO/secrets/gh/hosts.yml.enc" 'BEGIN AGE ENCRYPTED FILE'
    refute 'age: no plain text' \
        contains "$REPO/secrets/gh/hosts.yml.enc" "$GHTOKEN"
    rm "$CFG/gh/hosts.yml"
    dot apply --secrets >>"$LOG" 2>&1
    check 'age: apply --secrets restores it' \
        contains "$CFG/gh/hosts.yml" "$GHTOKEN"
else
    printf '  skip age tests (age is not installed)\n'
fi

# ------------------------------------------------------------ templates
printf '%s\n' '[templates]'
machine m14
git clone -q "$M1" "$REPO"
mkdir -p "$RC/app"
printf '%s\n' 'host={{host}}' '{{if os=darwin}}' 'kind=mac' '{{else}}' \
    'kind=other' '{{end}}' 'name={{name}}' 'editor={{ env:DOT_T_EDITOR }}' \
    >"$RC/app/greet.conf.tmpl"
printf 'name = everyone\n[host=%s]\nname = this machine\n' "$HOSTNAME_" \
    >"$REPO/dot.vars"
export DOT_T_EDITOR=vi
KIND=other
[ "$(uname -s)" = Darwin ] && KIND=mac
G=$CFG/app/greet.conf
dot apply >>"$LOG" 2>&1
check 'template: {{host}}' contains "$G" "host=$HOSTNAME_"
check 'template: {{if}}/{{else}}' contains "$G" "kind=$KIND"
check 'template: a [host=..] section in dot.vars wins' \
    contains "$G" 'name=this machine'
check 'template: {{env:NAME}}' contains "$G" 'editor=vi'
refute 'template: no markers left' contains "$G" '{{'
check 'render prints the same result' \
    says "kind=$KIND" dot render app/greet.conf
check 'vars lists the built-ins' says '^host = ' dot vars
printf 'edited\n' >>"$G"
dot capture --no-commit >>"$LOG" 2>&1
refute 'capture never overwrites a template' \
    contains "$RC/app/greet.conf.tmpl" 'edited'
refute 'capture writes no rendered copy' test -e "$RC/app/greet.conf"
printf 'oops={{nope}}\n' >"$RC/app/bad.conf.tmpl"
dot apply --overwrite >>"$LOG" 2>&1
refute 'a template with an unknown variable is not installed' \
    test -e "$CFG/app/bad.conf"
rm "$RC/app/bad.conf.tmpl"
dot apply --link --overwrite >>"$LOG" 2>&1
refute 'link mode copies rendered templates' islink "$G"
dot template vim/vimrc >>"$LOG" 2>&1
check 'dot template makes a .tmpl' test -f "$RC/vim/vimrc.tmpl"
refute 'and removes the plain copy' test -e "$RC/vim/vimrc"

# ------------------------------------------------------------ bootstrap
printf '%s\n' '[bootstrap]'
machine m5
rm -rf "$CFG"
NEW=$HOME/somewhere/dots
$SH "$SRC" bootstrap "$M1" "$NEW" >>"$LOG" 2>&1
check 'bootstrap clones' test -f "$NEW/dot"
check 'bootstrap applies' test -f "$CFG/vim/vimrc"
check 'bootstrap installs the dot command' islink "$HOME/.local/bin/dot"
check 'doctor passes' $SH "$NEW/dot" doctor
$SH "$NEW/dot" snapshot >>"$LOG" 2>&1
check 'manual snapshot' some "$DOT_STATE/snapshots/*manual*"

printf '\n%s passed, %s failed (%s)\n' "$PASS" "$FAIL" "$SH"
if [ "$FAIL" -ne 0 ]; then
    [ -n "${TEST_LOG:-}" ] && cp "$LOG" "$TEST_LOG"
    exit 1
fi
