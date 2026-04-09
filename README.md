
# 🦖 Space Engineer – Single Server Installer (Proxmox / LXC)

This repository provides a **Bash script** to install and run **Space Engineer** on Linux using **SteamCMD + Proton GE**, fully managed by **systemd**.



The main objective is to run **one Space Engineer server per LXC container** in order to achieve:
<ul>
	<li>
		🧱 Clean isolation
	</li>
	<li>
		📉 Easy CPU / RAM / disk limits
	</li>
	<li>
		💾 Predictable disk usage (less than 20 GB per server)
	</li>
	<li>
		📦 Simple scaling on Proxmox
	</li>
</ul>

This project is designed for **self-hosters**, **homelab setups**, and **Proxmox users**.

---

## ✅ Requirements

- 🐧 **Debian 13**
- 🌐 **curl** installed
- 📦 **Debian 13 LXC container** (tested)

⚠️ Each LXC container must host **only one Space Engineer server**.

---

## 🚀 Installation

Run the installer directly:
> Run it inside Debian 13 LXC
```bash
apt update && apt upgrade -y && apt install curl -y
bash -c "$(curl -fsSL https://raw.githubusercontent.com/DragoQC/space_engineer_server_deployement_script/main/space_engineer_server_install.sh)"
```

> ℹ️ **Note**  
> SteamCMD may occasionally fail on the first run.  
> If that happens, simply run the command again.

---

## ✨ Features

- One server per LXC
- systemd managed service
- Automatic restart on crash
- Automatic update on service restart
- Mod support via config file
- Clean and simple file layout
- Default `SpaceEngineers-Dedicated.cfg` generated on install

---

## 📁 Directory Layout

```text
/opt/space-engineer/
├── start-space-engineer.sh
├── server-config/
│   ├── SpaceEngineers-Dedicated.cfg
│   ├── Saves/
│   └── Checkpoint/
├── server-files/
├── steamcmd/
└── GE-Proton10-4/
```

## ⚙️ Configuration

All user configuration is done in:

```bash
/opt/space-engineer/server-config/SpaceEngineers-Dedicated.cfg
```

### Example

```xml
<?xml version="1.0"?>
<MyConfigDedicated>
  <SessionSettings>
    <GameMode>Survival</GameMode>
    <MaxPlayers>16</MaxPlayers>
  </SessionSettings>
  <IP>0.0.0.0</IP>
  <ServerPort>27016</ServerPort>
  <ServerName>Space Engineer Server</ServerName>
  <WorldName>Self Hosted Server World</WorldName>
</MyConfigDedicated>
```
---

### Apply changes

Run the following command:
```bash
systemctl restart space-engineer
```

🔄 Updating the Server

No manual update command is required.

Every time you run:
```bash
systemctl restart space-engineer
```
The server will:
```text
Stop
Check for updates via SteamCMD
Validate files
Start again
```
🛠️ Service Commands

- Start the server:
```bash
systemctl start space-engineer
```
- Stop the server:
```bash
systemctl stop space-engineer
```
- Restart the server:
```bash
systemctl restart space-engineer
```

📜 Logs
```text
Check service status:
systemctl status space-engineer
Follow live logs:
journalctl -u space-engineer -f
```

⚠️ Notes
>Restarting the service can take 1–2 minutes due to SteamCMD checks
>Do not run multiple servers from the same install directory

❓ Why This Exists
- Space Engineer is Windows-only
- Proton works well
- Game panels overcomplicate simple infrastructure
- Linux deserves clean, scriptable tooling

❤️ Credits
- Valve – SteamCMD
- GloriousEggroll – Proton GE
- Keen Software House - Space Engineer
- You – for hosting your own servers
