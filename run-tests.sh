#!/bin/sh
set -ue
[ -z "${DEBUG:-}" ] || set -x

unset BACH_ASSERT_DIFF BACH_ASSERT_DIFF_OPTS
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin

OS_NAME="$(uname)"
if [ -e /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="${OS_NAME}-${ID}-${VERSION_ID}"
fi
case "$OS_NAME" in
    Darwin)
        if ! brew list --full-name --versions bash &>/dev/null; then
            brew install bash
        fi
        bash_bin="$(brew --prefix)"/bin/bash
        ;;
    FreeBSD)
        export PATH="/usr/local/sbin:$PATH"
        export ASSUME_ALWAYS_YES=yes
        pkg_install_pkgs="pkg -vv; pkg update -f; pkg install -y bash vim" # vim provides xxd command
        if ! hash bash || ! hash xxd; then
            if [ "$(id -u)" -gt 0 ] && hash sudo; then
                sudo /bin/sh -c "$pkg_install_pkgs"
            else
                /bin/sh -c "$pkg_install_pkgs"
            fi
        fi
        ;;
    Linux-alpine-*)
        apk update
        hash bash &>/dev/null || apk add bash
        apk add coreutils diffutils
        apk add xxd # for running `@real xxd` in ./tests/demo-xxd.test.sh
        ;;
esac

if [ -z "${bash_bin:-}" ]; then
    bash_bin="$(which bash)"
fi

uname -a
echo "Bash: $bash_bin"
test -n "$bash_bin"
"$bash_bin" --version

err() {
  echo "$*" >&2
}

set +e
retval=0
cd "$(dirname "$0")"
for file in tests/*.test.sh examples/learn*; do
    echo "Running $file"
    if grep -E "^[[:blank:]]*BACH_TESTS=.+" "$file"; then
        err "Found defination of BACH_TESTS in $file"
        retval=1
    fi
    if [ "$file" = */failed-* ]; then
        ! "$bash_bin" -euo pipefail "$file"
    else
        "$bash_bin" -euo pipefail "$file"
    fi || retval=1
done

if [ "$retval" -ne 0 ]; then
    err "Test failed!"
fi

exit "$retval"
