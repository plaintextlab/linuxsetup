#!/usr/bin/env bash
# =============================================================================
#  Arch Linux Minimal i3 Setup — Maximum Compatibility
#  Run this AFTER a base Arch install (pacstrap base base-devel linux linux-firmware)
#  Usage: chmod +x arch-i3-setup.sh && ./arch-i3-setup.sh
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }

# ── Helpers ───────────────────────────────────────────────────────────────────
pac() { 
for pkg in "$@"; do
	echo ">>> $pkg"
	if ! sudo pacman -S --needed --noconfirm "$pkg"; then
		echo "ERROR: target not found -> $pkg" 
	fi
done
}

aur_install() {
  if ! command -v yay &>/dev/null; then
    info "Installing yay (AUR helper)..."
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
  fi
  yay -S --needed --noconfirm "$@"
}

enable_service()      { sudo systemctl enable "$1"      && success "Enabled $1"; }
enable_user_service() { systemctl --user enable "$1"    && success "Enabled user $1"; }

# =============================================================================
# 1. SYSTEM BASE & MIRRORS
# =============================================================================
info "=== 1. System base ==="
pac base-devel git curl wget reflector

info "Updating pacman mirrors..."
#sudo reflector --latest 20 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
sudo pacman -Syyu --noconfirm

# Enable multilib repo (required for 32-bit gaming libs) — do this first
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  info "Enabling multilib repo..."
  sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
  sudo pacman -Syyu --noconfirm
  success "multilib enabled"
fi

# =============================================================================
# 1b. FLATPAK — setup early
# =============================================================================
info "=== 1b. Flatpak ==="
pac flatpak xdg-desktop-portal xdg-desktop-portal-gtk
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
success "Flathub remote added"

# =============================================================================
# 2. WINDOW MANAGER — i3 + polybar
# =============================================================================
info "=== 2. i3 Window Manager ==="
pac \
  i3-wm \
  i3lock \
  rofi \
  polybar \
  picom \
  feh \
  xss-lock

# =============================================================================
# 3. DISPLAY SERVER & LOGIN
# =============================================================================
info "=== 3. Display server & login ==="
pac \
  xorg-server \
  xorg-xinit \
  xorg-xrandr \
  xorg-xset \
  xorg-setxkbmap \
  xorg-xrdb \
  xorg-xprop \
  xorg-xkill \
  arandr \
  ly

enable_service ly@tty1

# =============================================================================
# 4. AUDIO
# =============================================================================
info "=== 4. Audio ==="
pac \
  pipewire \
  pipewire-alsa \
  pipewire-pulse \
  pipewire-jack \
  wireplumber \
  alsa-utils \
  playerctl

aur_install wiremix      # TUI PipeWire mixer

enable_user_service pipewire
enable_user_service pipewire-pulse
enable_user_service wireplumber

# =============================================================================
# 5. NETWORKING
# =============================================================================
info "=== 5. Networking ==="
pac \
  networkmanager \
  dhcpcd \
  iwd \
  bluez \
  bluez-utils \
  openssh \
  nss-mdns \
  avahi

aur_install impala       # TUI WiFi manager
aur_install bluetui      # TUI Bluetooth manager

enable_service NetworkManager
enable_service bluetooth
enable_service avahi-daemon

sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' /etc/nsswitch.conf

# =============================================================================
# 6. STORAGE — AUTO-MOUNT & FILESYSTEM SUPPORT
# =============================================================================
info "=== 6. Storage & filesystems ==="
pac \
  ntfs-3g \
  exfatprogs \
  dosfstools \
  f2fs-tools \
  btrfs-progs \
  xfsprogs \
  e2fsprogs \
  reiserfsprogs \
  hfsprogs \
  hfsplus \
  udftools \
  nfs-utils \
  cifs-utils \
  udisks2 \
  udiskie \
  gvfs \
  gvfs-mtp \
  gvfs-gphoto2 \
  libmtp \
  android-file-transfer\
  gvfs-smb

#aur_install gvfs-google

sudo udevadm control --reload-rules && sudo udevadm trigger

# =============================================================================
# 7. PRINTING — HP & GENERIC
# =============================================================================
info "=== 7. Printing ==="
pac \
  cups \
  cups-pdf \
  ghostscript \
  gutenprint \
  foomatic-db \
  foomatic-db-engine \
  foomatic-db-gutenprint-ppds \
  hplip

enable_service cups
info "Run 'hp-setup' to configure your HP printer"
info "Use 'lpstat -p' to list printers, 'lpadmin' to manage them"

# =============================================================================
# 8. FONTS — Nerd Fonts + system fonts
# =============================================================================
info "=== 8. Fonts ==="
pac \
  ttf-dejavu \
  ttf-liberation \
  ttf-font-awesome \
  noto-fonts \
  noto-fonts-emoji \
  noto-fonts-cjk \
  ttf-roboto \
  ttf-ubuntu-font-family

# Nerd Fonts — full patched families (includes icons for polybar/kitty/prompt)
aur_install \
  ttf-hack-nerd \
  ttf-jetbrains-mono-nerd \
  ttf-firacode-nerd \
  ttf-nerd-fonts-symbols \
  ttf-nerd-fonts-symbols-mono

fc-cache -fv
success "Fonts installed and cache updated"

# =============================================================================
# 9. TERMINAL & SHELL — kitty + bash
# =============================================================================
info "=== 9. Terminal & shell ==="
pac \
  kitty \
  bash-completion \
  tmux \
  starship

# bash_completion is already the default shell — just configure it well
# (see section 22 for .bashrc)

# =============================================================================
# 10. FILE MANAGER & UTILITIES
# =============================================================================
info "=== 10. File manager & utilities ==="
pac \
  nemo \
  nemo-fileroller \
  nemo-preview \
  nemo-share \
  ffmpegthumbnailer \
  ranger \
  lf \
  fd \
  ripgrep \
  fzf \
  bat \
  eza \
  btop \
  dust \
  duf

pac \
  file-roller \
  zip unzip \
  p7zip \
  unrar \
  tar \
  gzip bzip2 xz \
  zstd \
  nano \
  micro

# =============================================================================
# 11. CLIPBOARD & NOTIFICATIONS
# =============================================================================
info "=== 11. Clipboard & notifications ==="
pac \
  xclip \
  xdotool \
  dunst \
  libnotify

# =============================================================================
# 12. POWER MANAGEMENT
# =============================================================================
info "=== 12. Power management ==="
pac \
  acpi \
  acpid \
  tlp \
  tlp-rdw \
  powertop \
  brightnessctl

enable_service acpid
enable_service tlp

# =============================================================================
# 13. HARDWARE SUPPORT + CPU/GPU AUTO-DETECTION
# =============================================================================
info "=== 13. Hardware support ==="
pac \
  linux-firmware \
  linux-firmware-whence \
  fwupd \
  lshw \
  hwinfo \
  usbutils \
  pciutils \
  v4l-utils \
  sane \
  xf86-input-libinput \
  libinput

# --- CPU microcode auto-detection ---
info "Detecting CPU vendor..."
CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
  pac intel-ucode
  success "Intel microcode installed"
  sudo grub-mkconfig -o /boot/grub/grub.cfg
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
  pac amd-ucode
  success "AMD microcode installed"
  sudo grub-mkconfig -o /boot/grub/grub.cfg
else
  warn "Could not detect CPU vendor — install intel-ucode or amd-ucode manually"
fi

# --- GPU auto-detection ---
info "Detecting GPU..."
if lspci | grep -qi nvidia; then
  info "NVIDIA GPU detected — installing open kernel driver (required for RTX 50xx Blackwell)"
  pac \
    nvidia-open-dkms \
    nvidia-utils \
    nvidia-settings \
    lib32-nvidia-utils \
    opencl-nvidia \
    libvdpau \
    libva-nvidia-driver

  if ! grep -q 'nvidia-drm.modeset=1' /etc/default/grub 2>/dev/null; then
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    success "GRUB updated with NVIDIA DRM modesetting"
  fi

  if ! grep -q 'nvidia' /etc/mkinitcpio.conf; then
    sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
    success "mkinitcpio updated with NVIDIA modules"
  fi

  enable_service nvidia-hibernate
  enable_service nvidia-resume
  enable_service nvidia-suspend
  success "NVIDIA driver stack installed"

elif lspci | grep -qi 'amd\|radeon'; then
  info "AMD GPU detected — installing AMDGPU + Mesa stack"
  pac \
    xf86-video-amdgpu \
    mesa \
    lib32-mesa \
    vulkan-radeon \
    lib32-vulkan-radeon \
    libva-mesa-driver \
    mesa-vdpau
  success "AMD GPU drivers installed"

elif lspci | grep -qi intel; then
  info "Intel GPU detected — installing Intel Mesa stack"
  pac \
    xf86-video-intel \
    mesa \
    lib32-mesa \
    vulkan-intel \
    lib32-vulkan-intel \
    intel-media-driver \
    libva-intel-driver
  success "Intel GPU drivers installed"

else
  warn "No known GPU detected — install drivers manually"
fi

# =============================================================================
# GAMING — Vulkan, Wine, DXVK, launchers
# =============================================================================
info "=== Gaming stack ==="

pac \
  vulkan-icd-loader \
  lib32-vulkan-icd-loader \
  vulkan-tools \
  spirv-tools \
  mesa \
  lib32-mesa \
  wine-staging \
  lib32-alsa-lib \
  lib32-alsa-plugins \
  lib32-libpulse \
  lib32-pipewire \
  lib32-gst-plugins-base \
  lib32-gst-plugins-good \
  wine-gecko \
  wine-mono \
  winetricks \
  dxvk \
  gamemode \
  lib32-gamemode \
  mangohud \
  lib32-mangohud \
  gamescope \
  lib32-libx11 \
  lib32-libxext \
  lib32-libxrandr \
  lib32-libxinerama \
  lib32-libxi \
  lib32-libxcursor \
  lib32-openal \
  lib32-sdl2 \
  lib32-sdl2_image \
  lib32-sdl2_mixer \
  lib32-sdl2_ttf \
  sdl2 sdl2_image sdl2_mixer \
  lib32-libjpeg-turbo \
  lib32-libpng \
  lib32-zlib
  
pac \
  steam \
  lutris

aur_install vkd3d-proton-mingw

#flatpak install -y flathub com.valvesoftware.Steam
flatpak install -y flathub com.heroicgameslauncher.hgl
#flatpak install -y flathub net.lutris.Lutris
#flatpak install -y flathub net.davidotek.pupgui2 # Protonup QT
flatpak install -y flathub com.vysp3r.ProtonPlus # Proton plus - https://flathub.org/en/apps/com.vysp3r.ProtonPlus

# =============================================================================
# 14. MEDIA CODECS & FRAMEWORKS
# =============================================================================
info "=== 14. Media codecs ==="
pac \
  ffmpeg \
  gstreamer \
  gst-plugins-base \
  gst-plugins-good \
  gst-plugins-bad \
  gst-plugins-ugly \
  gst-libav \
  flac \
  opus-tools \
  sox \
  imv

# =============================================================================
# 15. APPLICATIONS
# =============================================================================
info "=== 15. Applications ==="

pac \
  qutebrowser \
  gnome-keyring \
  xdg-utils \
  xdg-user-dirs \
  polkit-gnome \
  gparted \
  pass \
  timeshift \
  redshift


info "Installing GUI apps via Flatpak..."
flatpak install -y flathub \
  org.mozilla.firefox \
  org.libreoffice.LibreOffice \
  org.gimp.GIMP \
  org.videolan.VLC \
  io.mpv.Mpv \
  org.gnome.Evince \
  com.github.tchx84.Flatseal \
  org.filezillaproject.Filezilla

# =============================================================================
# 16. SYSTEM TOOLS
# =============================================================================
info "=== 16. System tools ==="
pac \
  man-db \
  man-pages \
  tldr \
  lsof \
  strace \
  htop \
  ncdu \
  neovim \
  nano \
  tree \
  jq \
  rsync \
  cronie \
  logrotate \
  mlocate

enable_service cronie
sudo updatedb

# =============================================================================
# 17. SECURITY
# =============================================================================
info "=== 17. Security ==="
pac \
  ufw \
  fail2ban \
  gnupg \
  pass

sudo ufw default deny incoming
sudo ufw default allow outgoing
enable_service ufw
enable_service fail2ban

# =============================================================================
# 18. SCREENSHOT TOOL
# =============================================================================
pac scrot

# =============================================================================
# 19. i3 CONFIG
# =============================================================================
info "=== 19. Writing i3 config ==="
mkdir -p ~/.config/i3

cat > ~/.config/i3/config << 'I3EOF'

# ── i3 Config ────────────────────────────────────────────────────────────────
set $mod Mod4
set $term kitty
set $menu rofi -show drun -show-icons

font pango:JetBrainsMono Nerd Font 14

# ── Source autostart (keeps this file clean) ──────────────────────────────────
exec --no-startup-id ~/.config/i3/autostart.sh

# ── Key Bindings ──────────────────────────────────────────────────────────────
bindsym $mod+Return exec $term
bindsym $mod+d      exec $menu
bindsym $mod+q kill
bindsym $mod+Shift+e exec i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'
bindsym $mod+Shift+r restart
bindsym $mod+Shift+c reload

# Focus
bindsym $mod+Left  focus left
bindsym $mod+Down  focus down
bindsym $mod+Up    focus up
bindsym $mod+Right focus right

# Move
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Layout
bindsym $mod+v       split v
bindsym $mod+b       split h
bindsym $mod+f       fullscreen toggle
bindsym $mod+s       layout stacking
bindsym $mod+w       layout tabbed
bindsym $mod+x       layout toggle split
bindsym $mod+Shift+s sticky toggle
bindsym $mod+Shift+space floating toggle
bindsym $mod+space   focus mode_toggle
bindsym $mod+a       focus parent
bindsym $mod+r       mode "resize"

# Workspaces
set $ws1 "1"
set $ws2 "2"
set $ws3 "3"
set $ws4 "4"
set $ws5 "5"
set $ws6 "6"
set $ws7 "7"
set $ws8 "8"
set $ws9 "9"
set $ws10 "10"

bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+6 workspace number $ws6
bindsym $mod+7 workspace number $ws7
bindsym $mod+8 workspace number $ws8
bindsym $mod+9 workspace number $ws9
bindsym $mod+0 workspace number $ws10

bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Shift+6 move container to workspace number $ws6
bindsym $mod+Shift+7 move container to workspace number $ws7
bindsym $mod+Shift+8 move container to workspace number $ws8
bindsym $mod+Shift+9 move container to workspace number $ws9
bindsym $mod+Shift+0 move container to workspace number $ws10

# Media keys
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute        exec pactl set-sink-mute @DEFAULT_SINK@ toggle
bindsym XF86AudioMicMute     exec pactl set-source-mute @DEFAULT_SOURCE@ toggle
bindsym XF86AudioPlay        exec playerctl play-pause
bindsym XF86AudioNext        exec playerctl next
bindsym XF86AudioPrev        exec playerctl previous
bindsym XF86MonBrightnessUp   exec brightnessctl set +10%
bindsym XF86MonBrightnessDown exec brightnessctl set 10%-

# Screenshot
bindsym Print            exec scrot ~/Pictures/Screenshots/%Y%m%d_%H%M%S.png
bindsym Shift+Print      exec scrot -s ~/Pictures/Screenshots/%Y%m%d_%H%M%S.png
bindsym $mod+Shift+Print exec scrot -u ~/Pictures/Screenshots/%Y%m%d_%H%M%S.png

# App shortcuts
bindsym $mod+e       exec nemo
bindsym $mod+Shift+p       exec kitty wiremix
bindsym $mod+i       exec kitty impala
bindsym $mod+Shift+b exec kitty bluetui
#bindsym $mod+Shift+l exec i3lock -c 1e1e2e
# Night light
bindsym $mod+n exec --no-startup-id redshift -O 3500
bindsym $mod+Shift+n exec --no-startup-id redshift -x

# ── Source custom user scripts (add your bindings in scripts.conf) ────────────
# Example:  bindsym $mod+x exec ~/.config/i3/scripts/my-script.sh
include ~/.config/i3/scripts.conf

# Resize mode
mode "resize" {
  bindsym h resize shrink width  10 px or 10 ppt
  bindsym j resize grow   height 10 px or 10 ppt
  bindsym k resize shrink height 10 px or 10 ppt
  bindsym l resize grow   width  10 px or 10 ppt
  bindsym Left  resize shrink width  10 px or 10 ppt
  bindsym Down  resize grow   height 10 px or 10 ppt
  bindsym Up    resize shrink height 10 px or 10 ppt
  bindsym Right resize grow   width  10 px or 10 ppt
  bindsym Return mode "default"
  bindsym Escape mode "default"
}

# ── Colors (Catppuccin Mocha) ──────────────────────────────────────────────────
# class                 border  bg      text    indicator child_border
client.focused          #89b4fa #89b4fa #1e1e2e #f5c2e7   #89b4fa
client.focused_inactive #313244 #313244 #cdd6f4 #45475a   #313244
client.unfocused        #1e1e2e #1e1e2e #6c7086 #1e1e2e   #1e1e2e
client.urgent           #f38ba8 #f38ba8 #1e1e2e #f38ba8   #f38ba8

# ── Gaps ──────────────────────────────────────────────────────────────────────
gaps inner 6
gaps outer 2
default_border pixel 2
hide_edge_borders smart

# ── Floating rules ────────────────────────────────────────────────────────────
for_window [class="Arandr"]          floating enable
for_window [class="GParted"]         floating enable
for_window [title="File Transfer*"]  floating enable
for_window [class="Nemo"]            floating enable, resize set 900 600
for_window [class="^.*"]             border pixel 2

# Prevent Nemo from managing the desktop
exec --no-startup-id gsettings set org.nemo.desktop show-desktop-icons false


I3EOF

success "i3 config written"

# =============================================================================
# 20. AUTOSTART FILE — all startup daemons live here, not in i3/config
# =============================================================================
info "=== 20. Writing autostart.sh ==="

cat > ~/.config/i3/autostart.sh << 'AUTOEOF'
#!/usr/bin/env bash
# =============================================================================
#  i3 Autostart — sourced by i3/config on login
#  Edit this file to add/remove startup daemons and services.
#  Each entry uses run_once() to avoid duplicate processes on i3 restart.
# =============================================================================

run_once() {
  local cmd="$1"
  local name
  name=$(basename "$cmd" | cut -d' ' -f1)
  pgrep -x "$name" > /dev/null 2>&1 || "$@" &
}

# ── D-Bus / session environment ───────────────────────────────────────────────
dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY XAUTHORITY

# ── XDG Desktop Portal (needed by Flatpak, screen share, file pickers) ────────
run_once /usr/lib/xdg-desktop-portal-gtk
run_once /usr/lib/xdg-desktop-portal

# ── Polkit agent (privilege escalation for GUI apps) ──────────────────────────
run_once /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

# ── Compositor ────────────────────────────────────────────────────────────────
run_once picom --config ~/.config/picom/picom.conf

# ── Notifications ─────────────────────────────────────────────────────────────
run_once dunst

# ── Auto-mount removable drives ───────────────────────────────────────────────
run_once udiskie --tray

# ── Screen locker hook (locks on systemd suspend/lid close) ───────────────────
run_once xss-lock -- i3lock -c 1e1e2e

# ── Wallpaper ─────────────────────────────────────────────────────────────────
if [[ -f ~/.config/i3/wallpaper.jpg ]]; then
  feh --bg-scale ~/.config/i3/wallpaper.jpg
else
  feh --bg-solid '#1e1e2e'
fi

# ── Keyboard settings ─────────────────────────────────────────────────────────
xset r rate 300 30            # Key repeat: delay 300ms, rate 30/s

# ── XDG user dirs ─────────────────────────────────────────────────────────────
xdg-user-dirs-update

# ── Polybar ───────────────────────────────────────────────────────────────────
~/.config/polybar/launch.sh

AUTOEOF
chmod +x ~/.config/i3/autostart.sh
success "autostart.sh written to ~/.config/i3/autostart.sh"




# =============================================================================
# 20. Audio output change script - on Win + p key (Shortcut can be changed in i3 config file)
# =============================================================================
info "=== 20. Writing audio-device-switch.sh ==="

cat > ~/.config/scripts/audio-device-switch.sh << 'AUDIOEOF'

#!/usr/bin/env bash

# audio-device-switch - audio device switch with a keybind
# Adapted from this: 
# https://gist.githubusercontent.com/kbravh/1117a974f89cc53664e55823a55ac320/raw/9d04a10ae925074536047ae8100c6b0dbfc303d6/audio-device-switch.sh
# Readme: https://gist.github.com/kbravh/1117a974f89cc53664e55823a55ac320
# Creator: https://github.com/kbravh

# Audio Output Switcher
# This script will cycle to the next available audio output device. 
# It can be tied to a hotkey to easily be triggered.
# This is handy, for example, for swapping between speakers and headphones.
# This script will work on systems running PulseAudio or Pipewire services.



# Check which sound server is running
if pgrep pulseaudio >/dev/null; then
  sound_server="pulseaudio"
elif pgrep pipewire >/dev/null; then
  sound_server="pipewire"
else
  echo "Neither PulseAudio nor PipeWire is running."
  exit 1
fi

# Grab a count of how many audio sinks we have
if [[ "$sound_server" == "pulseaudio" ]]; then
  sink_count=$(pacmd list-sinks | grep -c "index:[[:space:]][[:digit:]]")
  # Create an array of the actual sink IDs
  sinks=()
  mapfile -t sinks < <(pacmd list-sinks | grep 'index:[[:space:]][[:digit:]]' | sed -n -e 's/.*index:[[:space:]]\([[:digit:]]\)/\1/p')
  # Get the ID of the active sink
  active_sink=$(pacmd list-sinks | sed -n -e 's/[[:space:]]*\*[[:space:]]index:[[:space:]]\([[:digit:]]\)/\1/p')

elif [[ "$sound_server" == "pipewire" ]]; then
  sink_count=$(pactl list sinks | grep -c "Sink #[[:digit:]]")
  # Create an array of the actual sink IDs
  sinks=()
  mapfile -t sinks < <(pactl list sinks | grep 'Sink #[[:digit:]]' | sed -n -e 's/.*Sink #\([[:digit:]]\)/\1/p')
  # Get the ID of the active sink
  active_sink_name=$(pactl info | grep 'Default Sink:' | sed -n -e 's/.*Default Sink:[[:space:]]\+\(.*\)/\1/p')
  active_sink=$(pactl list sinks | grep -B 2 "$active_sink_name" | sed -n -e 's/Sink #\([[:digit:]]\)/\1/p' | head -n 1)
fi

# Get the ID of the last sink in the array
final_sink=${sinks[$((sink_count - 1))]}

# Find the index of the active sink
for index in "${!sinks[@]}"; do
  if [[ "${sinks[$index]}" == "$active_sink" ]]; then
    active_sink_index=$index
  fi
done

# Default to the first sink in the list
next_sink=${sinks[0]}
next_sink_index=0

# If we're not at the end of the list, move up the list
if [[ $active_sink -ne $final_sink ]]; then
  next_sink_index=$((active_sink_index + 1))
  next_sink=${sinks[$next_sink_index]}
fi

#change the default sink
if [[ "$sound_server" == "pulseaudio" ]]; then
  pacmd "set-default-sink ${next_sink}"
elif [[ "$sound_server" == "pipewire" ]]; then
  # Get the name of the next sink
  next_sink_name=$(pactl list sinks | grep -C 2 "Sink #$next_sink" | sed -n -e 's/.*Name:[[:space:]]\+\(.*\)/\1/p' | head -n 1)
  pactl set-default-sink "$next_sink_name"
fi

#move all inputs to the new sink
if [[ "$sound_server" == "pulseaudio" ]]; then
  for app in $(pacmd list-sink-inputs | sed -n -e 's/index:[[:space:]]\([[:digit:]]\)/\1/p'); do
    pacmd "move-sink-input $app $next_sink"
  done
elif [[ "$sound_server" == "pipewire" ]]; then
  for app in $(pactl list sink-inputs | sed -n -e 's/.*Sink Input #\([[:digit:]]\)/\1/p'); do
    pactl "move-sink-input $app $next_sink"
  done
fi

# Create a list of the sink descriptions
sink_descriptions=()
if [[ "$sound_server" == "pulseaudio" ]]; then
  mapfile -t sink_descriptions < <(pacmd list-sinks | sed -n -e 's/.*alsa.name[[:space:]]=[[:space:]]"\(.*\)"/\1/p')
elif [[ "$sound_server" == "pipewire" ]]; then
  mapfile -t sink_descriptions < <(pactl list sinks | sed -n -e 's/.*Description:[[:space:]]\+\(.*\)/\1/p')
fi

# Find the index that matches our new active sink
for sink_index in "${!sink_descriptions[@]}"; do
  if [[ "$sink_index" == "$next_sink_index" ]]; then
    notify-send -i audio-volume-high "Sound output switched to:" "${sink_descriptions[$sink_index]}"
    exit
  fi
done



AUDIOEOF
chmod +x ~/.config/scripts/audio-device-switch.sh
success "audio-device-switch.sh written to ~/.config/scripts/audio-device-switch.sh"


# =============================================================================
# 21. SCRIPTS STUB — user custom script bindings
# =============================================================================
info "=== 21. Writing scripts stub ==="
mkdir -p ~/.config/i3/scripts

cat > ~/.config/i3/scripts.conf << 'SCRIPTEOF'
# =============================================================================
#  i3 Custom Script Bindings
#  Add your own keybindings here. This file is included by ~/.config/i3/config.
#  Scripts should be placed in ~/.config/i3/scripts/ and made executable.
#
#  Example:
#    bindsym $mod+F1 exec ~/.config/i3/scripts/my-script.sh
#    bindsym $mod+F2 exec ~/.config/i3/scripts/toggle-monitor.sh
#    bindsym $mod+F3 exec kitty ~/.config/i3/scripts/system-info.sh
# =============================================================================

# ── Add your custom bindings below ────────────────────────────────────────────
bindsym $mod+p exec ~/.config/scripts/audio-device-switch.sh

SCRIPTEOF
success "scripts.conf stub written — add your keybindings to ~/.config/i3/scripts.conf"
success "Place script files in ~/.config/i3/scripts/"

# =============================================================================
# 22. POLYBAR CONFIG
# =============================================================================
info "=== 22. Writing polybar config ==="
mkdir -p ~/.config/polybar/scripts

# ── launch.sh ─────────────────────────────────────────────────────────────────
cat > ~/.config/polybar/launch.sh << 'LAUNCHEOF'
#!/usr/bin/env bash
# Kill any existing polybar instances
killall -q polybar
while pgrep -u "$UID" -x polybar > /dev/null; do sleep 0.1; done

# Launch polybar on all connected monitors
if type xrandr > /dev/null 2>&1; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload main &
  done
else
  polybar --reload main &
fi
LAUNCHEOF
chmod +x ~/.config/polybar/launch.sh

# ── current-audio-device.sh ───────────────────────────────────────────────────
cat > ~/.config/polybar/scripts/current-audio-device.sh << 'AUDIOEOF'
#!/usr/bin/env bash
# Outputs the current default PipeWire/PulseAudio sink's short name.
# Used as a polybar custom/script module.

get_sink_name() {
  pactl get-default-sink 2>/dev/null
}

get_sink_desc() {
  local sink
  sink=$(get_sink_name)
  pactl list sinks 2>/dev/null \
    | awk -v sink="$sink" '
        /^Sink #/ { found=0 }
        $0 ~ "Name: " sink { found=1 }
        found && /Description:/ {
          sub(/.*Description: /, "")
          print
          exit
        }
      '
}

# Shorten common sink names to fit on the bar
shorten() {
  local desc="$1"
  case "$desc" in
    *"Built-in Audio"*|*"HDA Intel"*)  echo " Built-in" ;;
    *"HDMI"*)                           echo " HDMI" ;;
    *"USB"*)                            echo " USB" ;;
    *"Bluetooth"*|*"bluez"*)           echo " BT" ;;
    *"DisplayPort"*)                    echo " DP" ;;
    *)                                  echo " ${desc:0:14}" ;;
  esac
}

DESC=$(get_sink_desc)
if [[ -z "$DESC" ]]; then
  echo " N/A"
else
  shorten "$DESC"
fi
AUDIOEOF
chmod +x ~/.config/polybar/scripts/current-audio-device.sh

# ── colors.ini ────────────────────────────────────────────────────────────────
cat > ~/.config/polybar/colors.ini << 'COLOREOF'
; Catppuccin Mocha palette
[colors]
base      = #1e1e2e
mantle    = #181825
crust     = #11111b
surface0  = #313244
surface1  = #45475a
surface2  = #585b70
overlay0  = #6c7086
overlay1  = #7f849c
overlay2  = #9399b2
subtext0  = #a6adc8
subtext1  = #bac2de
text      = #cdd6f4
lavender  = #b4befe
blue      = #89b4fa
sapphire  = #74c7ec
sky       = #89dceb
teal      = #94e2d5
green     = #a6e3a1
yellow    = #f9e2af
peach     = #fab387
maroon    = #eba0ac
red       = #f38ba8
mauve     = #cba6f7
pink      = #f5c2e7
flamingo  = #f2cdcd
rosewater = #f5e0dc
COLOREOF

# ── config.ini ────────────────────────────────────────────────────────────────
cat > ~/.config/polybar/config.ini << 'POLYEOF'
; =============================================================================
;  Polybar Config — Catppuccin Mocha / Nerd Font icons
;  Modules: volume | wifi | datetime | audio-device (custom script)
; =============================================================================

include-file = ~/.config/polybar/colors.ini

; ── Bar definition ────────────────────────────────────────────────────────────
[bar/main]
monitor                 = ${env:MONITOR:}
width                   = 100%
height                  = 28
offset-x                = 0
offset-y                = 0
radius                  = 0
fixed-center            = true

background              = ${colors.base}
foreground              = ${colors.text}

line-size               = 2
line-color              = ${colors.blue}

border-size             = 0
padding-left            = 1
padding-right           = 1
module-margin-left      = 1
module-margin-right     = 1

; Nerd Font — ensure the correct index for your installed fonts
font-0                  = "JetBrainsMono Nerd Font:size=10:weight=Bold;2"
font-1                  = "Nerd Fonts Symbols Mono:size=13;3"
font-2                  = "Noto Color Emoji:scale=8;2"

modules-left            = i3 xwindow
modules-center          = date
modules-right           = audio-device volume network memory cpu

tray-position           = right
tray-padding            = 4
tray-background         = ${colors.base}

cursor-click            = pointer
cursor-scroll           = ns-resize

enable-ipc              = true

; ── i3 workspaces ─────────────────────────────────────────────────────────────
[module/i3]
type                    = internal/i3
format                  = <label-state> <label-mode>
index-sort              = true
wrapping-scroll         = false

label-focused           = %index%
label-focused-background = ${colors.surface0}
label-focused-foreground = ${colors.blue}
label-focused-underline  = ${colors.blue}
label-focused-padding   = 2

label-unfocused         = %index%
label-unfocused-foreground = ${colors.overlay0}
label-unfocused-padding = 2

label-visible           = %index%
label-visible-foreground = ${colors.subtext1}
label-visible-padding   = 2

label-urgent            = %index%
label-urgent-background = ${colors.red}
label-urgent-foreground = ${colors.base}
label-urgent-padding    = 2

; ── Active window title ───────────────────────────────────────────────────────
[module/xwindow]
type                    = internal/xwindow
label                   = %title:0:50:...%
label-foreground        = ${colors.subtext0}

; ── Date & time ───────────────────────────────────────────────────────────────
[module/date]
type                    = internal/date
interval                = 5
date                    = "%a %d %b"
time                    = "%H:%M"
label                   = " %date%   %time%"
label-foreground        = ${colors.text}

; ── Volume (PulseAudio/PipeWire) ──────────────────────────────────────────────
[module/volume]
type                    = internal/pulseaudio
use-ui-max              = false
interval                = 2

format-volume           = <ramp-volume> <label-volume>
label-volume            = %percentage%%
label-volume-foreground = ${colors.text}

format-muted-prefix     = "󰝟 "
format-muted-prefix-foreground = ${colors.red}
label-muted             = muted
label-muted-foreground  = ${colors.overlay0}

ramp-volume-0           = 󰕿
ramp-volume-1           = 󰖀
ramp-volume-2           = 󰕾
ramp-volume-foreground  = ${colors.green}

click-right             = kitty wiremix &

; ── Current audio device (custom script) ──────────────────────────────────────
[module/audio-device]
type                    = custom/script
exec                    = ~/.config/polybar/scripts/current-audio-device.sh
interval                = 3
label-foreground        = ${colors.sapphire}
click-left              = kitty wiremix &

; ── Network / WiFi ────────────────────────────────────────────────────────────
[module/network]
type                    = internal/network
; Set to your interface — polybar will auto-pick if left empty
interface-type          = wireless
interval                = 3

format-connected        = <ramp-signal> <label-connected>
label-connected         = %essid% %local_ip%
label-connected-foreground = ${colors.text}

format-disconnected     = <label-disconnected>
label-disconnected      = "󰤭 disconnected"
label-disconnected-foreground = ${colors.red}

ramp-signal-0           = 󰤯
ramp-signal-1           = 󰤟
ramp-signal-2           = 󰤢
ramp-signal-3           = 󰤥
ramp-signal-4           = 󰤨
ramp-signal-foreground  = ${colors.blue}

click-left              = kitty impala &

; ── Memory ────────────────────────────────────────────────────────────────────
[module/memory]
type                    = internal/memory
interval                = 3
format-prefix           = "󰍛 "
format-prefix-foreground = ${colors.mauve}
label                   = %percentage_used%%
label-foreground        = ${colors.text}

; ── CPU ───────────────────────────────────────────────────────────────────────
[module/cpu]
type                    = internal/cpu
interval                = 2
format-prefix           = " "
format-prefix-foreground = ${colors.peach}
label                   = %percentage%%
label-foreground        = ${colors.text}
POLYEOF

success "Polybar config written to ~/.config/polybar/"

# =============================================================================
# 23. picom CONFIG
# =============================================================================
info "=== 23. picom config ==="
mkdir -p ~/.config/picom
cat > ~/.config/picom/picom.conf << 'PICOMEOF'

backend = "glx";
vsync = true;
log-level = "warn";

animations = (
  { triggers = ["open", "show"];  preset = "appear";          direction = "up";   duration = 0.25; easing = "ease-out";    },
  { triggers = ["close", "hide"]; preset = "disappear";       direction = "down"; duration = 0.25; easing = "ease-in";     },
  { triggers = ["geometry"];      preset = "geometry-change";                     duration = 0.20; easing = "ease-in-out"; }
);

animation-window-mass = 0.9;
animation-stiffness = 180.0;
animation-dampening = 15.0;
animation-clamping = false;

shadow = true;
shadow-radius = 16;
shadow-opacity = 0.5;
shadow-ignore-shaped = false;

inactive-opacity = 0.85;
active-opacity = 0.95;
frame-opacity = 1.0;
fullscreen-opacity = 1.0;

fading = true;
fade-delta = 10;
fade-in-step = 0.05;
fade-out-step = 0.05;

blur-method = "dual_kawase";
blur-strength = 5;
blur-background = true;
blur-ovredir = false;
blur-background-frame = true;
blur-background-fixed = true;

corner-radius = 0;
round-borders = 0;

opacity-rule = [
  "100:fullscreen",
  "100:class_g = 'firefox-esr'",
  "100:class_g = 'firefox'",
  "100:class_g = 'vlc'",
  "100:class_g = 'mpv'",
  "100:class_g = 'steam_app_default'",
  "100:class_g = 'Gimp'",
  "100:class_g = 'libreoffice-writer'",
  "100:class_g = 'kdenlive'",
  "100:class_g = 'Virt-manager'",
  "100:class_g = 'steam'",
  "100:class_g = 'Thunar'",
  "100:class_g = 'resolve'",
];

shadow-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "window_type = 'menu'",
  "window_type = 'dropdown_menu'",
  "window_type = 'popup_menu'",
  "window_type = 'tooltip'",
  "_GTK_FRAME_EXTENTS@:c",
  "class_g = 'conky'",
  "class_g = 'mpv'",
];

blur-background-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "window_type = 'menu'",
  "window_type = 'dropdown_menu'",
  "window_type = 'popup_menu'",
  "window_type = 'tooltip'",
  "_GTK_FRAME_EXTENTS@:c",
  "_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'",
  "_NET_WM_WINDOW_TYPE@:a *= '_NET_WM_WINDOW_TYPE_DND'",
  "window_role *= 'nemo-dnd-window'",
  "class_g *= 'nemo-dnd-window'",
  "name *= 'Drag'",
  "name *= 'dnd'",
  "class_g = 'nemo'",
  "class_g = 'conky'",
  "class_g = 'mpv'",
];

blur-exclude = [
  "class_g = 'slop'",
  "_NET_WM_WINDOW_TYPE@:a *= '_NET_WM_WINDOW_TYPE_DND'",
  "window_type = 'dock'",
  "window_type = 'desktop'",
];

rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "window_type = 'dropdown_menu'",
  "window_type = 'popup_menu'",
  "window_type = 'menu'",
  "class_g = 'mpv'",
];

wintypes: {
  tooltip     = { fade = true; shadow = true; opacity = 0.9; focus = true; full-shadow = false; };
  dock        = { shadow = false; };
  dnd         = { shadow = false; };
  popup_menu  = { opacity = 0.9; };
  dropdown_menu = { opacity = 0.9; };
};

PICOMEOF

# =============================================================================
# 24. kitty CONFIG
# =============================================================================
info "=== 24. kitty config ==="
mkdir -p ~/.config/kitty
cat > ~/.config/kitty/kitty.conf << 'KITTYEOF'
font_family      JetBrainsMono Nerd Font
font_size        11.0
bold_font        auto
italic_font      auto
bold_italic_font auto

window_padding_width   10
background_opacity     0.95
hide_window_decorations yes
remember_window_size   yes

shell /usr/bin/bash

sync_to_monitor yes
repaint_delay   10
input_delay     3

foreground            #cdd6f4
background            #1e1e2e
selection_foreground  #1e1e2e
selection_background  #f5c2e7

color0  #45475a
color1  #f38ba8
color2  #a6e3a1
color3  #f9e2af
color4  #89b4fa
color5  #f5c2e7
color6  #94e2d5
color7  #bac2de
color8  #585b70
color9  #f38ba8
color10 #a6e3a1
color11 #f9e2af
color12 #89b4fa
color13 #f5c2e7
color14 #94e2d5
color15 #a6adc8

cursor           #f5e0dc
cursor_text_color #1e1e2e
url_color        #f5c2e7
KITTYEOF

# =============================================================================
# 25. BASH CONFIG — completions, history tweaks, starship prompt
# =============================================================================
info "=== 25. Bash config ==="

cat > ~/.bashrc << 'BASHEOF'
# ── Guard: only run in interactive shells ─────────────────────────────────────
[[ $- != *i* ]] && return

# ── Completions ───────────────────────────────────────────────────────────────
[[ -r /usr/share/bash-completion/bash_completion ]] && \
  source /usr/share/bash-completion/bash_completion

# Source any extra completion scripts dropped in ~/.bash_completion.d/
if [[ -d ~/.bash_completion.d ]]; then
  for f in ~/.bash_completion.d/*.sh; do
    [[ -r "$f" ]] && source "$f"
  done
fi

# ── History tweaks ────────────────────────────────────────────────────────────
HISTSIZE=50000                    # In-memory history size
HISTFILESIZE=100000               # On-disk history file size
HISTFILE=~/.bash_history

HISTCONTROL=ignoreboth:erasedups  # No duplicates, no lines starting with space
HISTIGNORE="ls:ll:la:cd:cd -:pwd:exit:clear:history:bg:fg:jobs"

shopt -s histappend               # Append to history file, don't overwrite
shopt -s cmdhist                  # Save multi-line commands as single entry
shopt -s lithist                  # Preserve newlines in multi-line commands

# Sync history across terminals: flush + reload before each prompt
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a; history -c; history -r"

# ── Shell options ─────────────────────────────────────────────────────────────
shopt -s checkwinsize             # Update LINES/COLUMNS after each command
shopt -s globstar                 # Enable **  glob pattern
shopt -s nocaseglob               # Case-insensitive globbing
shopt -s autocd                   # Type a dir name to cd into it
shopt -s cdspell                  # Correct minor cd typos

# ── Smarter tab completion ────────────────────────────────────────────────────
bind "set completion-ignore-case on"
bind "set show-all-if-ambiguous on"
bind "set mark-symlinked-directories on"
bind "set colored-stats on"
bind "set visible-stats on"
# History search with Up/Down arrows
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
# Ctrl+R — already reverse-search, but also bind Ctrl+S forward search
bind '"\C-s": forward-search-history'
stty -ixon   # Disable Ctrl+S/Q terminal freeze so Ctrl+S works

# ── Aliases ───────────────────────────────────────────────────────────────────
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first --git'
alias la='eza -a --icons'
alias lt='eza --tree --icons --level=2'
alias cat='bat --style=plain'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'
alias df='duf'
alias du='dust'
alias top='btop'
alias vim='nvim'
alias vi='nvim'
alias mkdir='mkdir -pv'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -iv'

# ── Environment ───────────────────────────────────────────────────────────────
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'
export MANPAGER='less -R --use-color -Dd+r -Du+b'
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# ── PATH additions ────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

# ── Starship prompt ───────────────────────────────────────────────────────────
eval "$(starship init bash)"
BASHEOF

mkdir -p ~/.bash_completion.d
success ".bashrc written with completions, history tweaks, and starship"

# =============================================================================
# 26. MISC DIRECTORIES
# =============================================================================
mkdir -p ~/Pictures/Screenshots
xdg-user-dirs-update

# =============================================================================
# DONE
# =============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Arch + i3 setup complete! Reboot to start i3.                 ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Key files:                                                      ║${NC}"
echo -e "${GREEN}║  ~/.config/i3/config          — i3 keybindings & rules          ║${NC}"
echo -e "${GREEN}║  ~/.config/i3/autostart.sh    — all startup daemons             ║${NC}"
echo -e "${GREEN}║  ~/.config/i3/scripts.conf    — your custom script keybindings  ║${NC}"
echo -e "${GREEN}║  ~/.config/i3/scripts/        — place your scripts here         ║${NC}"
echo -e "${GREEN}║  ~/.config/polybar/config.ini — polybar bar config              ║${NC}"
echo -e "${GREEN}║  ~/.config/polybar/scripts/   — polybar custom scripts          ║${NC}"
echo -e "${GREEN}║  ~/.bashrc                    — bash config                     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Post-install:                                                   ║${NC}"
echo -e "${GREEN}║  • Microcode + GPU: detected and installed automatically         ║${NC}"
echo -e "${GREEN}║  • NVIDIA: verify with 'nvidia-smi'                             ║${NC}"
echo -e "${GREEN}║  • HP printer: run 'hp-setup'                                   ║${NC}"
echo -e "${GREEN}║  • Firewall: run 'sudo ufw enable'                              ║${NC}"
echo -e "${GREEN}║  • Polybar network: edit interface-type in config.ini if needed  ║${NC}"
echo -e "${GREEN}║  • Steam / Proton-GE: use ProtonUp-Qt Flatpak                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
