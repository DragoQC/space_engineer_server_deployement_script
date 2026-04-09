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
GAME_COLOR='\033[38;5;203m'       # warm red
SUCCESS_COLOR='\033[38;5;82m'    # bright green
INFO_COLOR='\033[38;5;250m'      # light gray
WARN_COLOR='\033[38;5;220m'      # warning yellow
ERROR_COLOR='\033[38;5;196m'     # bright red
SECTION_COLOR='\033[38;5;141m'   # purple

# App ID of the dedicated server on SteamDB
APP_ID="298740"
GAME_NAME="Space Engineer"
SERVER_NAME="Space Engineer Server"


log_file() {
  echo -e "${SECTION_COLOR}[Files]${RESET} $1"
}

log_steam() {
  echo -e "${STEAM_COLOR}[Steam]${RESET} $1"
}

log_proton() {
  echo -e "${PROTON_COLOR}[Proton]${RESET} $1"
}

log_game() {
  echo -e "${GAME_COLOR}[${GAME_NAME}]${RESET} $1"
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

run_steamcmd_update() {
  local max_attempts=3
  local attempt

  for attempt in $(seq 1 "$max_attempts"); do
    if "$STEAMCMD_DIR/steamcmd.sh" \
      +@sSteamCmdForcePlatformType windows \
      +force_install_dir "$SERVER_FILES_DIR" \
      +login anonymous \
      +app_update "$APP_ID" validate \
      +quit; then
      return 0
    fi

    if [ "$attempt" -lt "$max_attempts" ]; then
      log_warn "SteamCMD install failed on attempt $attempt/$max_attempts. Retrying in 10 seconds..."
      sleep 10
    fi
  done

  log_error "SteamCMD failed to install/update app $APP_ID after $max_attempts attempts."
  return 1
}


SERVICE_NAME="space-engineer"

# Base directory for all instances
BASE_DIR="/opt/space-engineer"

CONFIG_DIR="$BASE_DIR/server-config"
CFG_FILE="$CONFIG_DIR/SpaceEngineers-Dedicated.cfg"
START_SCRIPT="$BASE_DIR/start-space-engineer.sh"
UPDATE_SCRIPT="$BASE_DIR/update-space-engineer.sh"
SERVICE_FILE="/etc/systemd/system/space-engineer.service"
WINDOWS_USERDATA_DIR='C:\users\steamuser\Application Data\SpaceEngineersDedicated'

# Define the base paths as variables
STEAMCMD_DIR="$BASE_DIR/steamcmd"
SERVER_FILES_DIR="$BASE_DIR/server-files"
PROTON_VERSION="GE-Proton10-4"
PROTON_DIR="$BASE_DIR/$PROTON_VERSION"

# Define URLs for SteamCMD and Proton.
STEAMCMD_URL="https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz"
PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$PROTON_VERSION/$PROTON_VERSION.tar.gz"

log_game "$GAME_NAME - Single Server Installer"

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
mkdir -p "$STEAMCMD_DIR" "$SERVER_FILES_DIR" "$PROTON_DIR" "$CONFIG_DIR" "$CONFIG_DIR/Saves/World" "$CONFIG_DIR/Checkpoint"

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
# Space Engineer server install / update
# -------------------------------------------------------------------
log_game "Installing $GAME_NAME server..."
run_steamcmd_update
log_ok "Installed $GAME_NAME server..."
# -------------------------------------------------------------------
# Proton prefix (one-time)
# -------------------------------------------------------------------

PROTON_PREFIX="$SERVER_FILES_DIR/steamapps/compatdata/$APP_ID"

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
if [ ! -f "$CFG_FILE" ]; then
cat <<EOF > "$CFG_FILE"
<?xml version="1.0"?>
<MyConfigDedicated xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <SessionSettings>
    <GameMode>Survival</GameMode>
    <InventorySizeMultiplier>3</InventorySizeMultiplier>
    <BlocksInventorySizeMultiplier>1</BlocksInventorySizeMultiplier>
    <AssemblerSpeedMultiplier>3</AssemblerSpeedMultiplier>
    <AssemblerEfficiencyMultiplier>3</AssemblerEfficiencyMultiplier>
    <RefinerySpeedMultiplier>3</RefinerySpeedMultiplier>
    <OnlineMode>PUBLIC</OnlineMode>
    <MaxPlayers>16</MaxPlayers>
    <MaxFloatingObjects>100</MaxFloatingObjects>
    <MaxBackupSaves>5</MaxBackupSaves>
    <MaxGridSize>0</MaxGridSize>
    <MaxBlocksPerPlayer>0</MaxBlocksPerPlayer>
    <TotalPCU>320000</TotalPCU>
    <PiratePCU>50000</PiratePCU>
    <MaxFactionsCount>0</MaxFactionsCount>
    <BlockLimitsEnabled>PER_PLAYER</BlockLimitsEnabled>
    <EnableRemoteBlockRemoval>true</EnableRemoteBlockRemoval>
    <EnvironmentHostility>SAFE</EnvironmentHostility>
    <AutoHealing>true</AutoHealing>
    <EnableCopyPaste>false</EnableCopyPaste>
    <WeaponsEnabled>true</WeaponsEnabled>
    <ShowPlayerNamesOnHud>true</ShowPlayerNamesOnHud>
    <ThrusterDamage>true</ThrusterDamage>
    <CargoShipsEnabled>true</CargoShipsEnabled>
    <EnableSpectator>false</EnableSpectator>
    <WorldSizeKm>0</WorldSizeKm>
    <RespawnShipDelete>true</RespawnShipDelete>
    <ResetOwnership>false</ResetOwnership>
    <WelderSpeedMultiplier>2</WelderSpeedMultiplier>
    <GrinderSpeedMultiplier>2</GrinderSpeedMultiplier>
    <RealisticSound>false</RealisticSound>
    <HackSpeedMultiplier>0.33</HackSpeedMultiplier>
    <PermanentDeath>false</PermanentDeath>
    <AutoSaveInMinutes>5</AutoSaveInMinutes>
    <EnableSaving>true</EnableSaving>
    <InfiniteAmmo>false</InfiniteAmmo>
    <EnableContainerDrops>false</EnableContainerDrops>
    <SpawnShipTimeMultiplier>0</SpawnShipTimeMultiplier>
    <ProceduralDensity>0.35</ProceduralDensity>
    <ProceduralSeed>0</ProceduralSeed>
    <DestructibleBlocks>true</DestructibleBlocks>
    <EnableIngameScripts>true</EnableIngameScripts>
    <ViewDistance>15000</ViewDistance>
    <EnableToolShake>true</EnableToolShake>
    <VoxelGeneratorVersion>4</VoxelGeneratorVersion>
    <EnableOxygen>true</EnableOxygen>
    <EnableOxygenPressurization>true</EnableOxygenPressurization>
    <Enable3rdPersonView>true</Enable3rdPersonView>
    <EnableEncounters>true</EnableEncounters>
    <EnableConvertToStation>true</EnableConvertToStation>
    <StationVoxelSupport>false</StationVoxelSupport>
    <EnableSunRotation>true</EnableSunRotation>
    <EnableRespawnShips>true</EnableRespawnShips>
    <ScenarioEditMode>false</ScenarioEditMode>
    <Scenario>false</Scenario>
    <CanJoinRunning>false</CanJoinRunning>
    <PhysicsIterations>8</PhysicsIterations>
    <SunRotationIntervalMinutes>119.999992</SunRotationIntervalMinutes>
    <EnableJetpack>true</EnableJetpack>
    <SpawnWithTools>true</SpawnWithTools>
    <StartInRespawnScreen>false</StartInRespawnScreen>
    <EnableVoxelDestruction>true</EnableVoxelDestruction>
    <MaxDrones>5</MaxDrones>
    <EnableDrones>true</EnableDrones>
    <EnableWolfs>false</EnableWolfs>
    <EnableSpiders>false</EnableSpiders>
    <FloraDensityMultiplier>1</FloraDensityMultiplier>
    <EnableStructuralSimulation>false</EnableStructuralSimulation>
    <MaxActiveFracturePieces>50</MaxActiveFracturePieces>
    <BlockTypeLimits>
      <dictionary>
      </dictionary>
    </BlockTypeLimits>
    <EnableScripterRole>true</EnableScripterRole>
    <MinDropContainerRespawnTime>5</MinDropContainerRespawnTime>
    <MaxDropContainerRespawnTime>8</MaxDropContainerRespawnTime>
    <EnableTurretsFriendlyFire>false</EnableTurretsFriendlyFire>
    <EnableSubgridDamage>false</EnableSubgridDamage>
    <SyncDistance>3000</SyncDistance>
    <ExperimentalMode>true</ExperimentalMode>
    <AdaptiveSimulationQuality>true</AdaptiveSimulationQuality>
    <EnableVoxelHand>true</EnableVoxelHand>
    <RemoveOldIdentitiesH>0</RemoveOldIdentitiesH>
    <TrashRemovalEnabled>true</TrashRemovalEnabled>
    <StopGridsPeriodMin>15</StopGridsPeriodMin>
    <TrashFlagsValue>7706</TrashFlagsValue>
    <AFKTimeountMin>0</AFKTimeountMin>
    <BlockCountThreshold>20</BlockCountThreshold>
    <PlayerDistanceThreshold>500</PlayerDistanceThreshold>
    <OptimalGridCount>0</OptimalGridCount>
    <PlayerInactivityThreshold>0</PlayerInactivityThreshold>
    <PlayerCharacterRemovalThreshold>15</PlayerCharacterRemovalThreshold>
    <VoxelTrashRemovalEnabled>false</VoxelTrashRemovalEnabled>
    <VoxelPlayerDistanceThreshold>5000</VoxelPlayerDistanceThreshold>
    <VoxelGridDistanceThreshold>5000</VoxelGridDistanceThreshold>
    <VoxelAgeThreshold>24</VoxelAgeThreshold>
    <EnableResearch>true</EnableResearch>
    <EnableGoodBotHints>true</EnableGoodBotHints>
    <OptimalSpawnDistance>50000</OptimalSpawnDistance>
    <EnableAutorespawn>true</EnableAutorespawn>
    <EnableBountyContracts>true</EnableBountyContracts>
    <EnableSupergridding>false</EnableSupergridding>
    <EnableEconomy>true</EnableEconomy>
    <DepositsCountCoefficient>1</DepositsCountCoefficient>
    <DepositSizeDenominator>60</DepositSizeDenominator>
    <WeatherSystem>true</WeatherSystem>
    <HarvestRatioMultiplier>0.8</HarvestRatioMultiplier>
    <TradeFactionsCount>15</TradeFactionsCount>
    <StationsDistanceInnerRadius>10000000</StationsDistanceInnerRadius>
    <StationsDistanceOuterRadiusStart>10000000</StationsDistanceOuterRadiusStart>
    <StationsDistanceOuterRadiusEnd>30000000</StationsDistanceOuterRadiusEnd>
    <EconomyTickInSeconds>1200</EconomyTickInSeconds>
    <SimplifiedSimulation>false</SimplifiedSimulation>
    <SuppressedWarnings />
    <EnablePcuTrading>true</EnablePcuTrading>
    <FamilySharing>true</FamilySharing>
    <EnableSelectivePhysicsUpdates>false</EnableSelectivePhysicsUpdates>
  </SessionSettings>
  <LoadWorld>${WINDOWS_USERDATA_DIR}\\Saves\\World</LoadWorld>
  <IP>0.0.0.0</IP>
  <SteamPort>8766</SteamPort>
  <ServerPort>27016</ServerPort>
  <AsteroidAmount>0</AsteroidAmount>
  <Administrators>
  </Administrators>
  <Banned />
  <GroupID>0</GroupID>
  <ServerName>${SERVER_NAME}</ServerName>
  <WorldName>Self Hosted Server World</WorldName>
  <PauseGameWhenEmpty>false</PauseGameWhenEmpty>
  <MessageOfTheDay />
  <MessageOfTheDayUrl />
  <AutoRestartEnabled>true</AutoRestartEnabled>
  <AutoRestatTimeInMin>720</AutoRestatTimeInMin>
  <AutoRestartSave>true</AutoRestartSave>
  <AutoUpdateEnabled>true</AutoUpdateEnabled>
  <AutoUpdateCheckIntervalInMin>10</AutoUpdateCheckIntervalInMin>
  <AutoUpdateRestartDelayInMin>15</AutoUpdateRestartDelayInMin>
  <AutoUpdateSteamBranch />
  <AutoUpdateBranchPassword />
  <IgnoreLastSession>true</IgnoreLastSession>
  <PremadeCheckpointPath>${WINDOWS_USERDATA_DIR}\\Checkpoint</PremadeCheckpointPath>
  <ServerDescription />
  <ServerPasswordHash />
  <ServerPasswordSalt />
  <Reserved />
  <RemoteApiEnabled>false</RemoteApiEnabled>
  <RemoteSecurityKey />
  <RemoteApiPort>8080</RemoteApiPort>
  <Plugins />
  <WatcherInterval>30</WatcherInterval>
  <WatcherSimulationSpeedMinimum>0.05</WatcherSimulationSpeedMinimum>
  <ManualActionDelay>5</ManualActionDelay>
  <ManualActionChatMessage>Server will be shut down in {0} min(s).</ManualActionChatMessage>
  <AutodetectDependencies>true</AutodetectDependencies>
  <SaveChatToLog>false</SaveChatToLog>
  <NetworkParameters>
    <Parameter>globalMaxUpload:600</Parameter>
    <Parameter>peerMaxUpload:600</Parameter>
    <Parameter>statWindow:60</Parameter>
    <Parameter>peakStatWindow:60</Parameter>
  </NetworkParameters>
</MyConfigDedicated>
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

APP_ID="298740"
BASE_DIR="/opt/space-engineer"
CONFIG_DIR="$BASE_DIR/server-config"
SERVER_FILES_DIR="$BASE_DIR/server-files"
PROTON_DIR="$BASE_DIR/GE-Proton10-4"
PROTON_PREFIX="$SERVER_FILES_DIR/steamapps/compatdata/$APP_ID"
WINE_USERDATA_DIR="$PROTON_PREFIX/pfx/drive_c/users/steamuser/Application Data/SpaceEngineersDedicated"

mkdir -p "$CONFIG_DIR" "$CONFIG_DIR/Saves/World" "$CONFIG_DIR/Checkpoint" "$WINE_USERDATA_DIR"

cp "$CONFIG_DIR/SpaceEngineers-Dedicated.cfg" "$WINE_USERDATA_DIR/SpaceEngineers-Dedicated.cfg"

if [ ! -e "$WINE_USERDATA_DIR/Saves" ]; then
  ln -s "$CONFIG_DIR/Saves" "$WINE_USERDATA_DIR/Saves"
fi

if [ ! -e "$WINE_USERDATA_DIR/Checkpoint" ]; then
  ln -s "$CONFIG_DIR/Checkpoint" "$WINE_USERDATA_DIR/Checkpoint"
fi

# -----------------------------
# Proton environment
# -----------------------------
export STEAM_COMPAT_DATA_PATH="$SERVER_FILES_DIR/steamapps/compatdata/$APP_ID"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$BASE_DIR"

# -----------------------------
# Start server (PID belongs to systemd)
# -----------------------------
exec "$PROTON_DIR/proton" run \
  "$SERVER_FILES_DIR/DedicatedServer64/SpaceEngineersDedicated.exe" \
  -noconsole \
  -ignorelastsession
EOF

chmod +x "$START_SCRIPT"
log_ok "Created start script..."

# -----------------------------
# Update script
# -----------------------------
log_file "Creating update script..."

cat <<'EOF' > "$UPDATE_SCRIPT"
#!/bin/bash
set -e

APP_ID="298740"
STEAMCMD_DIR="/opt/space-engineer/steamcmd"
SERVER_FILES_DIR="/opt/space-engineer/server-files"

for attempt in 1 2 3; do
  if "$STEAMCMD_DIR/steamcmd.sh" \
    +@sSteamCmdForcePlatformType windows \
    +force_install_dir "$SERVER_FILES_DIR" \
    +login anonymous \
    +app_update "$APP_ID" validate \
    +quit; then
    exit 0
  fi

  if [ "$attempt" -lt 3 ]; then
    sleep 10
  fi
done

exit 1
EOF

chmod +x "$UPDATE_SCRIPT"
log_ok "Created update script..."
# -----------------------------
# systemd service
# -----------------------------
log_file "Creating service..."
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=$GAME_NAME Server
After=network.target

[Service]
TimeoutStartSec=0
Type=simple
WorkingDirectory=/opt/space-engineer
ExecStartPre=/opt/space-engineer/update-space-engineer.sh
ExecStart=/opt/space-engineer/start-space-engineer.sh
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
log_game "Service status:"
systemctl status "$SERVICE_NAME" --no-pager
