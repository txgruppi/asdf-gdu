#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/dundee/gdu"

fail() {
	echo -e "asdf-gdu: $*"
	exit 1
}

fail_if_not_install_type_version() {
	if [ "$ASDF_INSTALL_TYPE" != "version" ]; then
		fail "only release install type is supported"
	fi
}

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n |
		awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' |
		grep -vF 'gdu-' |
		cut -d/ -f3- |
		sed 's/^v//' |
		grep -v '^[12]\.'
}

get_platform() {
	local plat
	case "$OSTYPE" in
		darwin*) plat="darwin" ;;
		FreeBSD*) plat="freebsd" ;;
		linux*) plat="linux" ;;
		netbsd*) plat="netbsd" ;;
		openbsd*) plat="openbsd" ;;
		*) fail "unsupported platform '$OSTYPE'" ;;
	esac
	echo "$plat"
}

get_architecture() {
	local arch
	case "$(uname -m)" in
		aarch64* | arm64*) arch="arm64" ;;
		armv5* | armv6* | armv7*) arch="arm" ;;
		i686* | i386* | 386*) arch="386" ;;
		x86_64* | amd64*) arch="amd64" ;;
		ppc64le*) arch="ppc64le" ;;
		ppc64*) arch="ppc64" ;;
		ppc*) arch="ppc" ;;
		mipsel*) arch="mipsle" ;;
		mips*) arch="mips" ;;
		*) fail "unsupported architecture '$(uname -m)'"
	esac
	echo "$arch"
}

do_download() {
	local curl_opts=(-fsSL)
	if [ -n "${GITHUB_API_TOKEN:-}" ]; then
		curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
	fi
	fail_if_not_install_type_version
	mkdir -p "$ASDF_DOWNLOAD_PATH"
	local version="$ASDF_INSTALL_VERSION"
	local plat="$(get_platform)"
	local arch="$(get_architecture)"
	local filename="$ASDF_DOWNLOAD_PATH/gdu_${plat}_${arch}.tgz"
	local url="$GH_REPO/releases/download/v${version}/gdu_${plat}_${arch}.tgz"
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "could not download $url"
	tar -xf "$filename" -C "$ASDF_DOWNLOAD_PATH" || (
		rm -f "$filename" &>/dev/null || true
		fail "could not extract $filename"
	)
	rm -f "$filename"
	mv "$ASDF_DOWNLOAD_PATH/gdu_$(get_platform)_$(get_architecture)" "$ASDF_DOWNLOAD_PATH/gdu_$ASDF_INSTALL_VERSION"
}

do_install() {
	fail_if_not_install_type_version
	if [ -z "${ASDF_DOWNLOAD_PATH:-}" ]; then
		export ASDF_DOWNLOAD_PATH="$ASDF_INSTALL_PATH/bin"
		do_download
	fi
	mv "$ASDF_DOWNLOAD_PATH/gdu_$ASDF_INSTALL_VERSION" "$ASDF_DOWNLOAD_PATH/gdu"
}
