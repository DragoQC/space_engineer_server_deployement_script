#!/bin/bash

export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LANGUAGE=C.UTF-8

set -e

# ===============================
# Color palette (vibrant)
# ===============================
RESET='\033[0m'

# Themed
STEAM_COLOR='\033[38;5;214m'     # orange-yellow
PROTON_COLOR='\033[38;5;208m'    # orange
ARK_COLOR='\033[38;5;117m'       # sky blue
SUCCESS_COLOR='\033[38;5;82m'    # bright green
INFO_COLOR='\033[38;5;250m'      # light gray
WARN_COLOR='\033[38;5;220m'      # warning yellow
ERROR_COLOR='\033[38;5;196m'     # bright red
SECTION_COLOR='\033[38;5;141m'   # purple


log_file() {
  echo -e "${SECTION_COLOR}[Files]${RESET} $1"
}

log_steam() {
  echo -e "${STEAM_COLOR}[Steam]${RESET} $1"
}

log_proton() {
  echo -e "${PROTON_COLOR}[Proton]${RESET} $1"
}

log_ark() {
  echo -e "${ARK_COLOR}[ARK]${RESET} $1"
}

log_ok() {
  echo -e "${SUCCESS_COLOR}✔ $1${RESET}"
}

log_info() {
  echo -e "${INFO_COLOR}ℹ $1${RESET}"
}

log_warn() {
  echo -e "${WARN_COLOR}⚠ $1${RESET}"
}

log_error() {
  echo -e "${ERROR_COLOR}✖ $1${RESET}"
}


SERVICE_NAME="asa"

# Base directory for all instances
BASE_DIR="/opt/asa"
RCON_SCRIPT="$BASE_DIR/rcon.py"

CONFIG_DIR="$BASE_DIR/server-config"
ENV_FILE="$CONFIG_DIR/asa.env"
START_SCRIPT="$BASE_DIR/start-asa.sh"
SERVICE_FILE="/etc/systemd/system/asa.service"

# Define the base paths as variables
STEAMCMD_DIR="$BASE_DIR/steamcmd"
SERVER_FILES_DIR="$BASE_DIR/server-files"
PROTON_VERSION="GE-Proton10-4"
PROTON_DIR="$BASE_DIR/$PROTON_VERSION"

# Define URLs for SteamCMD and Proton.
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$PROTON_VERSION/$PROTON_VERSION.tar.gz"

log_ark "ARK Survival Ascended – Single Server Installer"

# -------------------------------------------------------------------
# Dependencies
# -------------------------------------------------------------------
log_file "Installing dependencies..."
dpkg --add-architecture i386
dependencies=("wget" "tar" "grep" "libc6:i386" "libstdc++6:i386" "libncursesw6:i386" "python3" "libfreetype6:i386" "libfreetype6:amd64" "cron")

apt update
apt install -y "${dependencies[@]}"
log_ok "Installed dependencies..."

# -------------------------------------------------------------------
# Directories
# -------------------------------------------------------------------
mkdir -p "$STEAMCMD_DIR" "$SERVER_FILES_DIR" "$PROTON_DIR" "$CONFIG_DIR"

# -------------------------------------------------------------------
# SteamCMD
# -------------------------------------------------------------------
export HOME="$BASE_DIR"
mkdir -p "$HOME/.steam"
if [ ! -f "$STEAMCMD_DIR/steamcmd.sh" ]; then
    log_steam "Downloading SteamCMD..."
    wget -q -O "$STEAMCMD_DIR/steamcmd_linux.tar.gz" "$STEAMCMD_URL"
    tar -xzf "$STEAMCMD_DIR/steamcmd_linux.tar.gz" -C "$STEAMCMD_DIR"
    rm "$STEAMCMD_DIR/steamcmd_linux.tar.gz"
		log_ok "Installed SteamCMD..."
else
    log_ok "SteamCMD already installed."
fi

if [ ! -f "$STEAMCMD_DIR/.bootstrapped" ]; then
    log_steam "Initializing SteamCMD (first run)..."
    "$STEAMCMD_DIR/steamcmd.sh" +quit
    touch "$STEAMCMD_DIR/.bootstrapped"
		log_ok "Initialized SteamCMD (first run)..."
fi

# -------------------------------------------------------------------
# Proton GE
# -------------------------------------------------------------------
if [ ! -d "$PROTON_DIR/files" ]; then
    log_proton "Downloading Proton GE..."
    wget -q -O "$PROTON_DIR/$PROTON_VERSION.tar.gz" "$PROTON_URL"
    tar -xzf "$PROTON_DIR/$PROTON_VERSION.tar.gz" -C "$PROTON_DIR" --strip-components=1
    rm "$PROTON_DIR/$PROTON_VERSION.tar.gz"
		log_ok "Installed Proton GE..."
else
    log_ok "Proton already installed."
fi

# -------------------------------------------------------------------
# ARK server install / update
# -------------------------------------------------------------------
log_ark "Installing ARK server..."
"$STEAMCMD_DIR/steamcmd.sh" \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir "$SERVER_FILES_DIR" \
  +login anonymous \
  +app_update 2430930 validate \
  +quit
log_ok "Installed ARK server..."
# -------------------------------------------------------------------
# Proton prefix (one-time)
# -------------------------------------------------------------------

PROTON_PREFIX="$SERVER_FILES_DIR/steamapps/compatdata/2430930"

if [ ! -d "$PROTON_PREFIX/pfx" ]; then
    log_proton "Initializing Proton prefix..."
    mkdir -p "$PROTON_PREFIX"
    cp -r "$PROTON_DIR/files/share/default_pfx/." "$PROTON_PREFIX/"
    log_ok "Initialized Proton prefix..."
else
    log_ok "Proton prefix already initialized."
fi

# -----------------------------
# Create default config
# -----------------------------
log_file "Creating default config file..."
if [ ! -f "$ENV_FILE" ]; then
cat <<'EOF' > "$ENV_FILE"
# ARK Survival Ascended configuration

MAP_NAME=TheIsland_WP
SERVER_NAME="ARK ASA Server"
MAX_PLAYERS=20

GAME_PORT=7777
QUERY_PORT=27015
RCON_PORT=27020

# Comma-separated mod IDs
MOD_IDS=""

# Cluster (Optional Set cluster ID when ready to use)
CLUSTER_ID=""
CLUSTER_DIR="/opt/asa/cluster"

# Extra flags
EXTRA_ARGS="-NoBattlEye -crossplay"
EOF
fi
log_ok "Created default config file..."
# -----------------------------
# Start script
# -----------------------------
log_file "Creating start script..."

cat <<'EOF' > "$START_SCRIPT"
#!/bin/bash
set -e

source /opt/asa/server-config/asa.env

BASE_DIR="/opt/asa"
SERVER_FILES_DIR="$BASE_DIR/server-files"
STEAMCMD_DIR="$BASE_DIR/steamcmd"
PROTON_DIR="$BASE_DIR/GE-Proton10-4"

# -----------------------------
# Optional cluster support
# -----------------------------
CLUSTER_ARGS=""
if [ -n "$CLUSTER_ID" ]; then
  mkdir -p "$CLUSTER_DIR"
  CLUSTER_ARGS="-ClusterDirOverride=$CLUSTER_DIR -ClusterId=$CLUSTER_ID"
fi

# -----------------------------
# Optional Extra args
# -----------------------------
CONFIG_EXTRA_ARGS=""
if [ -n "$EXTRA_ARGS" ]; then
  CONFIG_EXTRA_ARGS=$EXTRA_ARGS
fi


# -----------------------------
# Proton environment
# -----------------------------
export STEAM_COMPAT_DATA_PATH="$SERVER_FILES_DIR/steamapps/compatdata/2430930"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$BASE_DIR"

# -----------------------------
# Mods
# -----------------------------
MOD_ARG=""
if [ -n "$MOD_IDS" ]; then
  MOD_ARG="-Mods=$MOD_IDS"
fi

# -----------------------------
# Start server (PID belongs to systemd)
# -----------------------------
exec "$PROTON_DIR/proton" run \
  "$SERVER_FILES_DIR/ShooterGame/Binaries/Win64/ArkAscendedServer.exe" \
  "$MAP_NAME?listen?SessionName=$SERVER_NAME?RCONEnabled=True" \
  -WinLiveMaxPlayers=$MAX_PLAYERS \
  -Port=$GAME_PORT \
  $MOD_ARG \
	$CLUSTER_ARGS \
  -QueryPort=$QUERY_PORT \
  -RCONPort=$RCON_PORT \
  -NoSteamClient \
  -NoSteam \
  -NoEOS \
  -nullrhi \
  -nosound \
  -NoSplash \
  -log \
  -server \
  -nosteamclient \
  -game	\
	$CONFIG_EXTRA_ARGS
EOF

chmod +x "$START_SCRIPT"
log_ok "Created start script..."
# -----------------------------
# systemd service
# -----------------------------
log_file "Creating service..."
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=ARK Survival Ascended Server
After=network.target

[Service]
TimeoutStartSec=0
Type=simple
WorkingDirectory=/opt/asa
ExecStartPre=/opt/asa/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir /opt/asa/server-files +login anonymous +app_update 2430930 validate +quit
ExecStart=/opt/asa/start-asa.sh
Restart=on-failure
SuccessExitStatus=0 3
RestartSec=10
TimeoutStopSec=120
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF
log_ok "Created service..."

# Reload systemd and enable service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

log_ok "Installation complete."
log_ark "Service status:"
systemctl status "$SERVICE_NAME" --no-pager



