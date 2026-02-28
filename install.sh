#!/bin/sh

set -e

# Colors
col_n="\033[0m"
col_r="\033[0;31m"
#col_g="\033[0;32m"
#col_y="\033[0;33m"

fail() {
	msg=${1:-"Installation failed"}
	printf "${col_r}%s${col_n}\n" "$msg"
	exit 1
}

ensure_jq() {
	bin_dir="/usr/bin"
	jq="${bin_dir}/jq"
	if [ -f "$jq" ]; then
		return
	fi

	arch=$(uname -m)
	case "$arch" in
	"aarch64")
		arch="arm64"
		;;
	"armv7l")
		arch="armel"
		;;
	*)
		fail "Could not guess right jq binary for arch '${arch}'"
		;;
	esac

	jq_url="https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-linux-${arch}"
	printf "Downloading jq for %s into %s\n" "${arch}" "${bin_dir}"
	wget -q -O "${jq}" "${jq_url}"
	if ! [ -x "${jq}" ]; then
		chmod 755 "${jq}"
	fi
}

install_updater() {
	installer="/jffs/scripts/nordvpn_updater.sh"
	wget -q -O "$installer" https://codeberg.org/kdehairy/nordvpn_updater/raw/branch/main/nordvpn-updater.sh
	chmod 7555 "$installer"
}

setup_schedule() {
	services_start_script="/jffs/scripts/services_start"
	touch "$services_start_script"
	chmod +x "$services_start_script"
	schedule="00 */2 * * *"
	job_id="nordvpn_updater"
	sed -i "/${job_id}/d" "$services_start_script"
	command="/bin/sh /jffs/scripts/nordvpn_updater.sh > /dev/null 2>&1"
	cron="cru a ${job_id} ${schedule} ${command}"
	eval "$cron"
	echo "$cron" >> "$services_start_script"
	printf "Added cron: %s\n" "$cron"
}

main() {
	jffs_enabled=$(nvram get jffs2_scripts)
	if [ "$jffs_enabled" != 1 ]; then
		fail "${col_r} JFFS partition is disabled"
	fi

	ensure_jq
	install_updater
	setup_schedule
	/jffs/scripts/nordvpn_updater.sh
}

main
