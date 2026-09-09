#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPO_URL="https://github.com/MrZagreed/Yorha-rice-linux-fork-from-flick0.git"
readonly REPO_BRANCH="hyprland-yorha"
readonly THEME_DIR="${HOME}/.config/hypr/themes/yorha"
readonly STTT_URL="https://raw.githubusercontent.com/flick0/sttt/main/sttt"
readonly HYPRLAND_PLUGINS_URL="https://github.com/hyprwm/hyprland-plugins"

on_error() {
	printf 'Installation failed at line %s. Check the messages above.\n' "$1" >&2
}
trap 'on_error "$LINENO"' ERR

die() {
	printf 'Error: %s\n' "$1" >&2
	exit 1
}

has_command() {
	command -v "$1" >/dev/null 2>&1
}

require_command() {
	has_command "$1" || die "Required command not found: $1"
}

check_network() {
	printf '%s\n' "Checking network access..."
	curl --fail --silent --show-error --location --max-time 20 https://archlinux.org/ >/dev/null \
		|| die "Arch Linux is unreachable. Check your network connection."
	curl --fail --silent --show-error --location --max-time 20 "${REPO_URL}" >/dev/null \
		|| die "GitHub is unreachable. Check your network connection."
}

install_paru() {
	if has_command paru; then
		return
	fi

	printf '%s\n' "No AUR helper found; bootstrapping paru..."
	local build_dir
	build_dir="$(mktemp -d)"
	trap 'rm -rf "$build_dir"' RETURN
	git clone --depth 1 https://aur.archlinux.org/paru.git "${build_dir}/paru"
	(
		cd "${build_dir}/paru"
		makepkg -si --noconfirm
	)
	trap - RETURN
	has_command paru || die "paru installation did not complete successfully."
}

install_sttt() {
	local download_dir
	download_dir="$(mktemp -d)"
	trap 'rm -rf "$download_dir"' RETURN
	curl --fail --silent --show-error --location "${STTT_URL}" -o "${download_dir}/sttt"
	test -s "${download_dir}/sttt" || die "Downloaded sttt is empty."
	sudo install -Dm755 "${download_dir}/sttt" /usr/local/bin/sttt
	trap - RETURN
}

install_theme() {
	mkdir -p "${HOME}/.config/hypr/themes"
	if [[ -e "${THEME_DIR}" ]]; then
		if [[ -d "${THEME_DIR}/.git" ]] && [[ "$(git -C "${THEME_DIR}" remote get-url origin 2>/dev/null)" == "${REPO_URL}" ]]; then
			printf '%s\n' "Theme already exists; updating it..."
			git -C "${THEME_DIR}" fetch --depth 1 origin "${REPO_BRANCH}"
			git -C "${THEME_DIR}" checkout -q -B "${REPO_BRANCH}" "origin/${REPO_BRANCH}"
		else
			die "Refusing to overwrite existing ${THEME_DIR}. Move it and rerun the installer."
		fi
	else
		git clone --depth 1 --branch "${REPO_BRANCH}" "${REPO_URL}" "${THEME_DIR}"
	fi
}

check_installation() {
	local command_name
	local required_commands=(hyprland foot grim slurp swww fish swaylock swayidle ags theme.sh sttt hyprpm)
	for command_name in "${required_commands[@]}"; do
		has_command "${command_name}" || die "Installation check failed: ${command_name} is not available."
	done

	local required_files=(
		"${THEME_DIR}/theme.conf"
		"${THEME_DIR}/theme_nier_dark.conf"
		"${THEME_DIR}/theme_nier_light.conf"
		"${THEME_DIR}/components/ags/config.js"
		"${THEME_DIR}/components/fish/theme.fish"
	)
	local required_file
	for required_file in "${required_files[@]}"; do
		test -f "${required_file}" || die "Installation check failed: missing ${required_file}."
	done
}

install_pacman_packages() {
	local attempt=1
	while (( attempt <= 3 )); do
		if sudo pacman -Syu --needed --noconfirm --disable-download-timeout "$@"; then
			return 0
		fi
		printf 'pacman attempt %s/3 failed; retrying package download...\n' "$attempt" >&2
		((attempt++))
	done
	die "pacman could not install the required packages. Check the mirror or network connection."
}

install_optional_pacman_packages() {
	local package_name
	for package_name in "$@"; do
		if pacman -Si "${package_name}" >/dev/null 2>&1; then
			install_pacman_packages "${package_name}"
		else
			printf 'Warning: optional package %s is unavailable in the current repositories; skipping.\n' "${package_name}" >&2
		fi
	done
}

if [[ "${EUID}" -eq 0 ]]; then
	die "Run this script as a regular user; sudo is used for pacman."
fi

if [[ ! -f /etc/arch-release ]] || ! command -v pacman >/dev/null 2>&1; then
	die "This installer currently supports Arch Linux only."
fi

require_command sudo
require_command curl
require_command git
sudo -v
check_network

readonly OFFICIAL_PACKAGES=(
	hyprland foot grim slurp swww fish swaylock swayidle sassc starship
	cava imagemagick ttf-ibm-plex gnome-bluetooth-3.0 wl-clipboard
	libdbusmenu-gtk3 xorg-xrandr cpio cmake git meson gcc curl base-devel
)
readonly AUR_PACKAGES=(aylurs-gtk-shell-git theme.sh)
readonly OPTIONAL_PACKAGES=(gnome-bluetooth)

printf '%s\n' "Updating package databases and installing official packages..."
install_pacman_packages "${OFFICIAL_PACKAGES[@]}"
install_optional_pacman_packages "${OPTIONAL_PACKAGES[@]}"
install_paru
printf '%s\n' "Installing AUR packages with paru..."
paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"

install_sttt
install_theme

printf '%s\n' "Installing hyprbars plugin..."
hyprpm update
hyprpm add "${HYPRLAND_PLUGINS_URL}" 2>/dev/null || true
hyprpm enable hyprbars
hyprpm reload -n
check_installation

printf '\n%s\n' "Theme installed at ${THEME_DIR}."
printf '%s\n' 'Add these lines to your main hyprland.conf:'
printf '%s\n' '$yorha=$HOME/.config/hypr/themes/yorha' 'source = $yorha/theme.conf'
printf '%s\n' 'Installed and verified: Hyprland, AGS, theme.sh, sttt, and hyprbars.'
printf '%s\n' 'Unimatrix is optional and is not required by this theme.'
