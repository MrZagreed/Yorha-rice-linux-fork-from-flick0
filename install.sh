#!/usr/bin/env bash
set -Eeuo pipefail

readonly REPO_URL="https://github.com/MrZagreed/Yorha-rice-linux-fork-from-flick0.git"
readonly REPO_BRANCH="hyprland-yorha"
readonly THEME_DIR="${HOME}/.config/hypr/themes/yorha"
readonly MAIN_CONFIG="${HOME}/.config/hypr/hyprland.lua"
readonly STTT_URL="https://raw.githubusercontent.com/flick0/sttt/main/sttt"
readonly HYPRLAND_PLUGINS_URL="https://github.com/hyprwm/hyprland-plugins"
readonly AGS_URL="https://github.com/striped-bass/ags.git"
readonly AGS_MARKER="/usr/local/share/yorha/ags-v1"

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

install_yay() {
	if has_command yay; then
		return
	fi

	printf '%s\n' "No AUR helper found; bootstrapping yay..."
	local build_dir
	build_dir="$(mktemp -d)"
	trap 'rm -rf "$build_dir"' RETURN
	git clone --depth 1 https://aur.archlinux.org/yay.git "${build_dir}/yay"
	(
		cd "${build_dir}/yay"
		makepkg -si --noconfirm
	)
	trap - RETURN
	has_command yay || die "yay installation did not complete successfully."
}

install_ags() {
	if [[ -f "${AGS_MARKER}" ]] && has_command ags; then
		printf '%s\n' "Compatible AGS v1 fork is already installed."
		return 0
	fi

	printf '%s\n' "Building AGS v1 fork required by this theme..."
	if ! has_command glib-mkenums || ! has_command glib-compile-resources; then
		printf '%s\n' "Repairing missing GLib build tools..."
		sudo pacman -S --noconfirm --disable-download-timeout glib2 glib2-devel
	fi
	has_command glib-mkenums || die "glib2 is installed without glib-mkenums; repair the Arch glib2 package manually."
	has_command glib-compile-resources || die "glib2 is installed without glib-compile-resources; repair the Arch glib2 package manually."
	local build_dir
	build_dir="$(mktemp -d)"
	trap 'rm -rf "$build_dir"' RETURN
	git clone --depth 1 "${AGS_URL}" "${build_dir}/ags"
	(
		cd "${build_dir}/ags"
		rm -rf node_modules package-lock.json
		npm install --no-audit --no-fund --package-lock=false --save-exact typescript@5.7.3
		[[ "$(node_modules/.bin/tsc --version)" == "Version 5."* ]] || die "AGS requires TypeScript 5.x; refusing incompatible compiler."
		node -e 'const fs=require("fs"); const p="tsconfig.json"; const c=JSON.parse(fs.readFileSync(p,"utf8")); c.compilerOptions={...(c.compilerOptions||{}), rootDir:"."}; fs.writeFileSync(p, JSON.stringify(c, null, 2)+"\n");'
		meson setup build --prefix=/usr/local
		sudo meson install -C build
	)
	sudo install -Dm644 /dev/null "${AGS_MARKER}"
	trap - RETURN
	has_command ags || die "AGS v1 installation did not complete successfully."
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

install_main_config() {
	mkdir -p "${HOME}/.config/hypr"
	if [[ -f "${MAIN_CONFIG}" ]]; then
		if grep -q '^-- YORHA_LUA_CONFIG$' "${MAIN_CONFIG}"; then
			printf '%s\n' "Yorha Lua config is already installed."
			return 0
		fi
		local backup_path="${MAIN_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
		mv "${MAIN_CONFIG}" "${backup_path}"
		printf '%s\n' "Backed up existing config to ${backup_path}."
	fi

	cp "${THEME_DIR}/hyprland.lua" "${MAIN_CONFIG}"
	printf '%s\n' "Installed Yorha main config at ${MAIN_CONFIG}."
}

check_installation() {
	local command_name
	local required_commands=(Hyprland start-hyprland kitty foot grim slurp awww awww-daemon fish swaylock swayidle ags theme.sh sttt hyprpm playerctl pavucontrol nm-applet xdg-user-dir notify-send wl-copy magick sassc cava wpctl xrandr)
	local missing_commands=()
	for command_name in "${required_commands[@]}"; do
		has_command "${command_name}" || missing_commands+=("${command_name}")
	done
	if (( ${#missing_commands[@]} > 0 )); then
		die "Installation check failed; missing commands: ${missing_commands[*]}"
	fi

	local required_files=(
		"${THEME_DIR}/hyprland.lua"
		"${THEME_DIR}/components/ags/config.js"
		"${THEME_DIR}/components/fish/theme.fish"
		"${THEME_DIR}/scripts/screenshot"
		"${THEME_DIR}/components/ags/windows/player/scripts/cava"
		"${THEME_DIR}/components/ags/windows/player/scripts/prepare_cover.sh"
		"${THEME_DIR}/components/gridlines.frag"
		"${THEME_DIR}/wallpapers/nier_light.png"
		"${THEME_DIR}/wallpapers/nier_dark.png"
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

enable_services() {
	printf '%s\n' "Enabling NetworkManager and Bluetooth services..."
	sudo systemctl enable --now NetworkManager bluetooth 2>/dev/null || \
		printf '%s\n' "Warning: enable NetworkManager/bluetooth manually if this is a container or chroot." >&2

	if systemctl --user is-enabled pipewire >/dev/null 2>&1 || systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null; then
		printf '%s\n' "PipeWire user services are enabled."
	else
		printf '%s\n' "Warning: start PipeWire after login with: systemctl --user enable --now pipewire pipewire-pulse wireplumber" >&2
	fi
}

install_hyprbars() {
	if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && has_command hyprctl; then
		printf '%s\n' "Installing hyprbars plugin into the running Hyprland session..."
		hyprpm update
		hyprpm add "${HYPRLAND_PLUGINS_URL}" 2>/dev/null || true
		hyprpm enable hyprbars
		hyprpm reload -n
		return 0
	fi

	printf '%s\n' "Hyprland is not running; skipping live hyprbars activation."
	printf '%s\n' "After starting Hyprland, run:"
	printf '%s\n' "hyprpm update && hyprpm add ${HYPRLAND_PLUGINS_URL} && hyprpm enable hyprbars"
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
	hyprland kitty foot grim slurp awww fish swaylock swayidle sassc starship
	cava imagemagick ttf-ibm-plex gnome-bluetooth-3.0 wl-clipboard
	libdbusmenu-gtk3 xorg-xrandr cpio cmake git meson gcc curl base-devel
	pipewire pipewire-pulse wireplumber bluez bluez-utils networkmanager libnotify
	gawk coreutils grep xdg-desktop-portal xdg-desktop-portal-hyprland
	polkit-kde-agent playerctl pavucontrol network-manager-applet xdg-user-dirs
	typescript npm gjs gtk3 gtk-layer-shell upower gobject-introspection libsoup3 libpulse glib2 glib2-devel
)
readonly AUR_PACKAGES=(theme.sh)

printf '%s\n' "Updating package databases and installing official packages..."
install_pacman_packages "${OFFICIAL_PACKAGES[@]}"
enable_services
install_yay
printf '%s\n' "Installing AUR packages with yay..."
yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
install_ags

install_sttt
install_theme
install_main_config
install_hyprbars
check_installation

printf '\n%s\n' "Theme installed at ${THEME_DIR}."
printf '%s\n' "Main config: ${MAIN_CONFIG}"
printf '%s\n' 'Start Hyprland with: start-hyprland'
printf '%s\n' 'Installed and verified: Hyprland, AGS, theme.sh, and sttt.'
printf '%s\n' 'Unimatrix is optional and is not required by this theme.'
