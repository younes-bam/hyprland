#!/bin/bash
set -Eeuo pipefail

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
BACKUP_DIR="$HOME/.config/backup_dots_$(date +%Y%m%d_%H%M%S)_$$"
CONFIG_DIR="$HOME/.config"
LOCAL_BIN_DIR="$HOME/.local/bin"
LOG_FILE=""

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

on_error() {
  local status="$1" line="$2" command="$3"
  trap - ERR
  set +x
  log_error "Installation stopped at line $line (exit $status): $command"
  log_error "Full log: $LOG_FILE"
  exit "$status"
}

setup_logging() {
  local previous_umask
  previous_umask=$(umask)
  umask 077
  mkdir -p "$HOME/.local/state/hyprdots"
  LOG_FILE="$HOME/.local/state/hyprdots/install_$(date +%Y%m%d_%H%M%S)_$$.log"
  : >"$LOG_FILE"
  umask "$previous_umask"

  exec > >(tee -a "$LOG_FILE") 2>&1
  trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
  log_info "Full terminal log: $LOG_FILE"
  PS4=$'\033[36m+ [${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}] \033[0m'
  set -x
  printf 'Started: %s\nScript: %s\nProject directory: %s\nWorking directory: %s\n' \
    "$(date --iso-8601=seconds)" "$SCRIPT_PATH" "$REPO_DIR" "$PWD" >>"$LOG_FILE"
}

# Check if running on Arch Linux
check_arch() {
  if [[ "$EUID" -eq 0 ]]; then
    log_error "Run this installer as your normal user, not as root. It will use sudo only when needed."
    exit 1
  fi

  if ! command -v pacman &>/dev/null; then
    log_error "This script is designed for Arch Linux. pacman not found."
    exit 1
  fi
  if [[ ! -f "$REPO_DIR/.config/hypr/hyprland.conf" || ! -d "$REPO_DIR/assets/wallpaper" ]]; then
    log_error "The installer could not find the required project files."
    log_error "It is checking this directory: $REPO_DIR"
    [[ -f "$REPO_DIR/.config/hypr/hyprland.conf" ]] || log_error "Missing: $REPO_DIR/.config/hypr/hyprland.conf"
    [[ -d "$REPO_DIR/assets/wallpaper" ]] || log_error "Missing directory: $REPO_DIR/assets/wallpaper"
    log_error "Use the complete Hyprdots project directory; .config is hidden and must be copied too."
    exit 1
  fi
  local required_file
  for required_file in \
    scripts/volume_notif.sh scripts/bright_notif.sh scripts/battery_notif.sh \
    scripts/start_wallpaper.sh scripts/apply_wallpaper.sh scripts/random_wallpaper.sh \
    .config/wal/templates/colors-hyprland.conf .config/wal/templates/colors-waybar.css \
    .config/wal/templates/colors-hyprland.lua; do
    if [[ ! -f "$REPO_DIR/$required_file" ]]; then
      log_error "Required project file is missing: $REPO_DIR/$required_file"
      exit 1
    fi
  done
}

# Main package installation logic
install_packages() {
  local base_packages=(
    hyprland hypridle hyprlock
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-utils dbus
    waybar swaync kitty awww rofi
    brightnessctl playerctl grim slurp jq wl-clipboard libnotify
    polkit-gnome fcitx5 fcitx5-gtk fcitx5-qt qt6ct
    cava fastfetch htop neovim fzf git
    networkmanager network-manager-applet nm-connection-editor bluez bluez-utils blueman
    pipewire pipewire-pulse pipewire-alsa wireplumber
    python bc imagemagick
    ttf-jetbrains-mono-nerd ttf-firacode-nerd noto-fonts-emoji
  )

  sudo pacman -Syu --needed "${base_packages[@]}"

}

install_aur_packages() {
  local build_dir
  if ! command -v yay >/dev/null 2>&1; then
    log_info "yay was not found; building it from the AUR..."
    sudo pacman -S --needed base-devel
    build_dir=$(mktemp -d "${TMPDIR:-/tmp}/hyprdots-yay.XXXXXXXX")
    if ! git clone https://aur.archlinux.org/yay.git "$build_dir/yay"; then
      rm -rf -- "$build_dir"
      log_error "Could not download yay from the AUR."
      return 1
    fi
    if ! (cd "$build_dir/yay" && makepkg -si); then
      rm -rf -- "$build_dir"
      log_error "Building yay failed."
      return 1
    fi
    rm -rf -- "$build_dir"
  fi

  yay -S --needed python-pywal16 bibata-cursor-theme wlogout
}

create_backup() {
  local backup_created=false item name target
  while IFS= read -r -d '' item; do
    local name=$(basename "$item")
    local target="$CONFIG_DIR/$name"

    if [[ -e "$target" || -L "$target" ]]; then
      if [[ "$backup_created" == false ]]; then
        mkdir -p "$CONFIG_DIR"
        BACKUP_DIR=$(mktemp -d "$CONFIG_DIR/backup_dots_$(date +%Y%m%d_%H%M%S)_XXXXXX")
        backup_created=true
      fi
      mv "$target" "$BACKUP_DIR/"
    fi
  done < <(find "$REPO_DIR/.config" -mindepth 1 -maxdepth 1 -print0)
  if [[ "$backup_created" == true ]]; then
    log_info "Existing configs backed up to $BACKUP_DIR"
  fi
  return 0
}

copy_configs() {
  mkdir -p "$CONFIG_DIR"

  local item name staged
  while IFS= read -r -d '' item; do
    local name=$(basename "$item")
    staged=$(mktemp -d "$CONFIG_DIR/.hyprdots-stage.XXXXXXXX")
    cp -a -- "$item" "$staged/"
    if ! mv -T -- "$staged/$name" "$CONFIG_DIR/$name"; then
      rm -rf -- "$staged"
      log_error "Could not install configuration '$name'. Existing files were backed up first."
      return 1
    fi
    rmdir "$staged"
  done < <(find "$REPO_DIR/.config" -mindepth 1 -maxdepth 1 -print0)

  if [[ -d "$REPO_DIR/assets/wallpaper" ]]; then
    local wallpaper_dir="$HOME/Pictures/wallpaper"
    if [[ -L "$wallpaper_dir" ]]; then
      log_warning "~/Pictures/wallpaper is a symlink; leaving it untouched."
    else
      mkdir -p "$wallpaper_dir"
      cp -an -- "$REPO_DIR/assets/wallpaper/." "$wallpaper_dir/"
    fi
  fi

}

install_local_scripts() {
  mkdir -p "$LOCAL_BIN_DIR/icons"

  for script in volume_notif.sh bright_notif.sh battery_notif.sh start_wallpaper.sh apply_wallpaper.sh random_wallpaper.sh; do
    [[ -f "$REPO_DIR/scripts/$script" ]] || { log_error "Missing helper script: $script"; return 1; }
    cp -f "$REPO_DIR/scripts/$script" "$LOCAL_BIN_DIR/$script"
    chmod +x "$LOCAL_BIN_DIR/$script"
  done

  cp -f "$REPO_DIR/assets/icons/brightness_"*.svg "$LOCAL_BIN_DIR/icons/"
}

collect_missing_dependencies() {
  MISSING_DEPENDENCIES=()
  local required_commands=(Hyprland hyprctl kitty waybar swaync swaync-client awww awww-daemon wal rofi wlogout hypridle hyprlock grim slurp jq wl-copy notify-send brightnessctl pactl wpctl playerctl nmtui nmcli nm-applet nm-connection-editor fcitx5 cava python bc magick pipewire wireplumber dbus-update-activation-environment)

  for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 || MISSING_DEPENDENCIES+=("$command_name")
  done

  [[ -d /usr/share/icons/Bibata-Modern-Ice ]] || MISSING_DEPENDENCIES+=("Bibata-Modern-Ice cursor theme")
  [[ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]] || MISSING_DEPENDENCIES+=("polkit-gnome authentication agent")
  [[ -d /usr/share/wayland-sessions ]] || MISSING_DEPENDENCIES+=("Wayland session files")
  [[ -x /usr/lib/xdg-desktop-portal-hyprland ]] || MISSING_DEPENDENCIES+=("xdg-desktop-portal-hyprland")
}

package_for_dependency() {
  case "$1" in
    Hyprland|hyprctl|"Wayland session files") echo hyprland ;;
    swaync-client) echo swaync ;;
    awww-daemon) echo awww ;;
    wal) echo python-pywal16 ;;
    wl-copy) echo wl-clipboard ;;
    notify-send) echo libnotify ;;
    pactl) echo pipewire-pulse ;;
    wpctl) echo wireplumber ;;
    pipewire) echo pipewire ;;
    nmtui|nmcli) echo networkmanager ;;
    nm-applet) echo network-manager-applet ;;
    magick) echo imagemagick ;;
    dbus-update-activation-environment) echo dbus ;;
    "Bibata-Modern-Ice cursor theme") echo bibata-cursor-theme ;;
    "polkit-gnome authentication agent") echo polkit-gnome ;;
    xdg-desktop-portal-hyprland) echo xdg-desktop-portal-hyprland ;;
    *) echo "$1" ;;
  esac
}

check_runtime_dependencies() {
  local dependency package
  local official_packages=() aur_packages=()
  declare -A seen_packages=()

  collect_missing_dependencies
  if ((${#MISSING_DEPENDENCIES[@]} == 0)); then
    return 0
  fi

  log_warning "Some required components are missing; installing their packages..."
  for dependency in "${MISSING_DEPENDENCIES[@]}"; do
    package=$(package_for_dependency "$dependency")
    [[ -n "${seen_packages[$package]:-}" ]] && continue
    seen_packages[$package]=1
    case "$package" in
      python-pywal16|bibata-cursor-theme|wlogout) aur_packages+=("$package") ;;
      *) official_packages+=("$package") ;;
    esac
  done

  if ((${#official_packages[@]} > 0)) && ! sudo pacman -S --needed "${official_packages[@]}"; then
    log_error "Could not install: ${official_packages[*]}"
    return 1
  fi
  if ((${#aur_packages[@]} > 0)) && ! yay -S --needed "${aur_packages[@]}"; then
    log_error "Could not install AUR packages: ${aur_packages[*]}"
    return 1
  fi

  collect_missing_dependencies
  if ((${#MISSING_DEPENDENCIES[@]} > 0)); then
    log_error "Still missing after installation: ${MISSING_DEPENDENCIES[*]}"
    return 1
  fi
}

setup_cursor() {
  local THEME="Bibata-Modern-Ice"
  local SIZE=24

  # GTK (GSettings & Config Files)
  if command -v gsettings &>/dev/null && gsettings get org.gnome.desktop.interface cursor-theme >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface cursor-theme "$THEME" || log_warning "Could not update the GSettings cursor theme"
    gsettings set org.gnome.desktop.interface cursor-size "$SIZE" || log_warning "Could not update the GSettings cursor size"
  fi

  mkdir -p "$HOME/.config/gtk-3.0"
  local gtk_settings="$HOME/.config/gtk-3.0/settings.ini"
  if [[ -e "$gtk_settings" || -L "$gtk_settings" ]]; then
    mkdir -p "$BACKUP_DIR/extra-config"
    cp -a -- "$gtk_settings" "$BACKUP_DIR/extra-config/settings.ini.gtk-3.0"
  fi
  local gtk_tmp
  gtk_tmp=$(mktemp "$HOME/.config/gtk-3.0/.settings.ini.XXXXXXXX")
  if [[ -f "$gtk_settings" && ! -L "$gtk_settings" ]]; then
    awk -v theme="$THEME" -v size="$SIZE" '
      BEGIN { in_settings=0; found_settings=0; theme_done=0; size_done=0 }
      /^\[[^]]+\]/ {
        if (in_settings) {
          if (!theme_done) print "gtk-cursor-theme-name=" theme
          if (!size_done) print "gtk-cursor-theme-size=" size
        }
        in_settings=($0 == "[Settings]");
        if (in_settings) found_settings=1
      }
      in_settings && /^gtk-cursor-theme-name=/ { print "gtk-cursor-theme-name=" theme; theme_done=1; next }
      in_settings && /^gtk-cursor-theme-size=/ { print "gtk-cursor-theme-size=" size; size_done=1; next }
      { print }
      END {
        if (in_settings) {
          if (!theme_done) print "gtk-cursor-theme-name=" theme
          if (!size_done) print "gtk-cursor-theme-size=" size
        } else if (!found_settings) {
          print "[Settings]"
          print "gtk-cursor-theme-name=" theme
          print "gtk-cursor-theme-size=" size
        }
      }
    ' "$gtk_settings" >"$gtk_tmp"
  else
    printf '[Settings]\ngtk-cursor-theme-name=%s\ngtk-cursor-theme-size=%s\n' "$THEME" "$SIZE" >"$gtk_tmp"
  fi
  mv -f -- "$gtk_tmp" "$gtk_settings"

  # XCursor and Qt environment variables
  mkdir -p "$HOME/.config/environment.d"
  local cursor_env="$HOME/.config/environment.d/10-cursor.conf"
  if [[ -e "$cursor_env" || -L "$cursor_env" ]]; then
    mkdir -p "$BACKUP_DIR/extra-config"
    cp -a -- "$cursor_env" "$BACKUP_DIR/extra-config/10-cursor.conf"
  fi
  local env_tmp
  env_tmp=$(mktemp "$HOME/.config/environment.d/.10-cursor.conf.XXXXXXXX")
  if [[ -f "$cursor_env" && ! -L "$cursor_env" ]]; then
    awk -v theme="$THEME" -v size="$SIZE" '
      BEGIN { theme_done=0; size_done=0 }
      /^XCURSOR_THEME=/ { print "XCURSOR_THEME=" theme; theme_done=1; next }
      /^XCURSOR_SIZE=/ { print "XCURSOR_SIZE=" size; size_done=1; next }
      { print }
      END {
        if (!theme_done) print "XCURSOR_THEME=" theme
        if (!size_done) print "XCURSOR_SIZE=" size
      }
    ' "$cursor_env" >"$env_tmp"
  else
    printf 'XCURSOR_THEME=%s\nXCURSOR_SIZE=%s\n' "$THEME" "$SIZE" >"$env_tmp"
  fi
  mv -f -- "$env_tmp" "$cursor_env"

  # Legacy/X11 support
  mkdir -p "$HOME/.icons/default"
  local icon_theme="$HOME/.icons/default/index.theme"
  if [[ -e "$icon_theme" || -L "$icon_theme" ]]; then
    mkdir -p "$BACKUP_DIR/extra-config"
    cp -a -- "$icon_theme" "$BACKUP_DIR/extra-config/index.theme.icons-default"
  fi
  local icon_tmp
  icon_tmp=$(mktemp "$HOME/.icons/default/.index.theme.XXXXXXXX")
  printf '[Icon Theme]\nInherits=%s\n' "$THEME" >"$icon_tmp"
  mv -f -- "$icon_tmp" "$icon_theme"

}

setup_shell() {
  local bash_path current_shell
  bash_path=$(command -v bash)
  current_shell=$(getent passwd "$USER" | cut -d: -f7)

  if [[ -z "$bash_path" ]]; then
    log_error "Bash was not found."
    return 1
  fi

  if [[ "$(readlink -f "$current_shell")" != "$(readlink -f "$bash_path")" ]]; then
    sudo chsh -s "$bash_path" "$USER"
  fi
}

create_directories() {
  local dirs=(
    "$HOME/.local/bin" "$HOME/.cache/wal" "$HOME/.cache/rofi-walls"
    "$HOME/Pictures/Screenshots"
  )
  for dir in "${dirs[@]}"; do mkdir -p "$dir"; done
}
generate_initial_wal() {
  local wall_dir="$HOME/Pictures/wallpaper"

  local wallpaper_list=()
  if [[ -d "$wall_dir" ]]; then
    mapfile -d '' wallpaper_list < <(find "$wall_dir" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) -print0)
  fi

  if [[ ${#wallpaper_list[@]} -gt 0 ]]; then
    local random_wall="${wallpaper_list[RANDOM % ${#wallpaper_list[@]}]}"

    ln -sfn "$random_wall" "$HOME/.config/hypr/current_hyprlock_wallpaper.jpg"

    wal -i "$random_wall" -n -q

    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
      awww img "$random_wall" --transition-type simple >/dev/null || log_warning "Could not update wallpaper in the active Hyprland session"
    fi

  else
    log_warning "No wallpapers found in $wall_dir; initial colors were not generated."
  fi
}
setup_audio() {
  # Mengaktifkan service pipewire untuk user saat ini
  systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service >/dev/null
}

setup_bluetooth() {
  sudo systemctl enable --now bluetooth.service >/dev/null
}

display_summary() {
  echo -e "\n${GREEN}========================================${NC}"
  echo -e "${GREEN}    Installation Completed Successfully!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo -e "${YELLOW}What would you like to do next?${NC}"
  echo -e "1) Reboot (Recommended)"
  echo -e "2) Logout"
  echo -e "3) Exit and reboot later"

  read -rp "Enter choice [1-3]: " choice

  case $choice in
  1)
    sleep 2
    systemctl reboot
    ;;
  2)
    sleep 2
    loginctl terminate-user "$USER"
    ;;
  3)
    echo -e "\n${BLUE}Enjoy your new setup! Don't forget to reboot later.${NC}"
    exit 0
    ;;
  *)
    echo -e "${RED}Invalid option. Exiting script...${NC}"
    exit 0
    ;;
  esac
}

main() {
  setup_logging
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}           MyHyperDots Installer        ${NC}"
  echo -e "${BLUE}========================================${NC}\n"

  log_info "Checking system and project files..."
  check_arch
  create_directories
  log_info "Installing and updating packages..."
  install_packages
  log_info "Installing Pywal and Bibata with yay..."
  install_aur_packages
  log_info "Checking required Hyprland components..."
  check_runtime_dependencies
  log_info "Enabling NetworkManager..."
  sudo systemctl enable --now NetworkManager.service >/dev/null
  log_info "Installing configurations and preserving existing files..."
  create_backup
  copy_configs
  log_info "Installing helper scripts and cursor settings..."
  install_local_scripts
  setup_cursor
  log_info "Initializing wallpaper colors and enabling user services..."
  generate_initial_wal
  setup_shell
  setup_audio
  setup_bluetooth
  display_summary
}

main "$@"
