#!/bin/bash

set -e

# Port validation
if ! [[ "$SERVERGAMEPORT" =~ $NUMCHECK ]]; then
    printf "Invalid server port given: %s\\n" "$SERVERGAMEPORT"
    SERVERGAMEPORT="7777"
fi
printf "Setting server port to %s\\n" "$SERVERGAMEPORT"

if ! [[ "$SERVERMESSAGINGPORT" =~ $NUMCHECK ]]; then
    printf "Invalid messaging port given: %s\\n" "$SERVERMESSAGINGPORT"
    SERVERMESSAGINGPORT="8888"
fi
printf "Setting messaging port to %s\\n" "$SERVERMESSAGINGPORT"

# Backup validation. Set BACKUPINTERVAL=0 to disable.
if ! [[ "$BACKUPINTERVAL" =~ $NUMCHECK ]]; then
    printf "Invalid backup interval given: %s\\n" "$BACKUPINTERVAL"
    BACKUPINTERVAL="3600"
fi
printf "Setting backup interval to %s seconds\\n" "$BACKUPINTERVAL"

if ! [[ "$BACKUPKEEP" =~ $NUMCHECK ]] || [[ "$BACKUPKEEP" -eq 0 ]]; then
    printf "Invalid backup retention count given: %s\\n" "$BACKUPKEEP"
    BACKUPKEEP="24"
fi
printf "Keeping the last %s backups\\n" "$BACKUPKEEP"

# Engine.ini settings.
if ! [[ "$AUTOSAVENUM" =~ $NUMCHECK ]]; then
    printf "Invalid autosave number given: %s\\n" "$AUTOSAVENUM"
    AUTOSAVENUM="5"
fi
printf "Setting autosave number to %s\\n" "$AUTOSAVENUM"

if ! [[ "$MAXOBJECTS" =~ $NUMCHECK ]]; then
    printf "Invalid max objects number given: %s\\n" "$MAXOBJECTS"
    MAXOBJECTS="2162688"
fi
printf "Setting max objects to %s\\n" "$MAXOBJECTS"

if ! [[ "$MAXTICKRATE" =~ $NUMCHECK ]] ; then
    printf "Invalid max tick rate number given: %s\\n" "$MAXTICKRATE"
    MAXTICKRATE="30"
fi
printf "Setting max tick rate to %s\\n" "$MAXTICKRATE"

[[ "${SERVERSTREAMING,,}" == "true" ]] && SERVERSTREAMING="1" || SERVERSTREAMING="0"
printf "Setting server streaming to %s\\n" "$SERVERSTREAMING"

if ! [[ "$TIMEOUT" =~ $NUMCHECK ]] ; then
    printf "Invalid timeout number given: %s\\n" "$TIMEOUT"
    TIMEOUT="30"
fi
printf "Setting timeout to %s\\n" "$TIMEOUT"

# Game.ini settings.
if ! [[ "$MAXPLAYERS" =~ $NUMCHECK ]] ; then
    printf "Invalid max players given: %s\\n" "$MAXPLAYERS"
    MAXPLAYERS="4"
fi
printf "Setting max players to %s\\n" "$MAXPLAYERS"

# GameUserSettings.ini settings.
if [[ "${DISABLESEASONALEVENTS,,}" == "true" ]]; then
    printf "Disabling seasonal events\\n"
    DISABLESEASONALEVENTS="-DisableSeasonalEvents"
else
    DISABLESEASONALEVENTS=""
fi

# Bandwidth settings (Engine.ini, Game.ini, Scalability.ini).
for var in CONFIGUREDINTERNETSPEED CONFIGUREDLANSPEED MAXCLIENTRATE MAXINTERNETCLIENTRATE TOTALNETBANDWIDTH MAXDYNAMICBANDWIDTH MINDYNAMICBANDWIDTH; do
    if ! [[ "${!var}" =~ $NUMCHECK ]]; then
        printf "Invalid %s given: %s\\n" "$var" "${!var}"
        declare "$var=104857600"
    fi
done
printf "Setting bandwidth limits (internet speed: %s, lan speed: %s, client rate: %s/%s, net bandwidth: %s/%s/%s)\\n" \
    "$CONFIGUREDINTERNETSPEED" "$CONFIGUREDLANSPEED" "$MAXCLIENTRATE" "$MAXINTERNETCLIENTRATE" \
    "$TOTALNETBANDWIDTH" "$MAXDYNAMICBANDWIDTH" "$MINDYNAMICBANDWIDTH"

# ServerSettings.ini settings.
[[ "${AUTOPAUSE,,}" == "false" ]] && AUTOPAUSE="False" || AUTOPAUSE="True"
printf "Setting auto pause to %s\\n" "$AUTOPAUSE"

[[ "${AUTOSAVEONDISCONNECT,,}" == "false" ]] && AUTOSAVEONDISCONNECT="False" || AUTOSAVEONDISCONNECT="True"
printf "Setting auto save on disconnect to %s\\n" "$AUTOSAVEONDISCONNECT"

# Validate and set multihome address for network connections (useful for v6-only networks).
if [[ "$MULTIHOME" != "" ]]; then
    if [[ "$MULTIHOME" != "" ]] && [[ "$MULTIHOME" != "::" ]]; then
        # IPv4 regex matches addresses from 0.0.0.0 to 255.255.255.255.
        IPv4='^([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$'

        # IPv6 regex supports full and shortened formats like 2001:db8::1.
        IPv6='^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:))$'

        if [[ "$MULTIHOME" =~ $IPv4 ]]; then
            printf "Multihome will accept IPv4 connections only\n"
        elif [[ "$MULTIHOME" =~ $IPv6 ]]; then
            printf "Multihome will accept IPv6 connections only\n"
        else
            printf "Invalid multihome address: %s (defaulting to ::)\n" "$MULTIHOME"
            MULTIHOME="::"
        fi
    fi

    if [[ "$MULTIHOME" == "::" ]]; then
        printf "Multihome will accept IPv4 and IPv6 connections\n"
    fi

    printf "Setting multihome to %s\n" "$MULTIHOME"
    MULTIHOME="-multihome=$MULTIHOME"
fi

ini_args=(
  "-ini:Engine:[/Script/FactoryGame.FGSaveSession]:mNumRotatingAutosaves=$AUTOSAVENUM"
  "-ini:Engine:[/Script/Engine.GarbageCollectionSettings]:gc.MaxObjectsInEditor=$MAXOBJECTS"
  "-ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:LanServerMaxTickRate=$MAXTICKRATE"
  "-ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:NetServerMaxTickRate=$MAXTICKRATE"
  "-ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:ConnectionTimeout=$TIMEOUT"
  "-ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:InitialConnectTimeout=$TIMEOUT"
  "-ini:Engine:[ConsoleVariables]:wp.Runtime.EnableServerStreaming=$SERVERSTREAMING"
  "-ini:Game:[/Script/Engine.GameSession]:ConnectionTimeout=$TIMEOUT"
  "-ini:Game:[/Script/Engine.GameSession]:InitialConnectTimeout=$TIMEOUT"
  "-ini:Game:[/Script/Engine.GameSession]:MaxPlayers=$MAXPLAYERS"
  "-ini:GameUserSettings:[/Script/Engine.GameSession]:MaxPlayers=$MAXPLAYERS"
  "-ini:Engine:[/Script/Engine.Player]:ConfiguredInternetSpeed=$CONFIGUREDINTERNETSPEED"
  "-ini:Engine:[/Script/Engine.Player]:ConfiguredLanSpeed=$CONFIGUREDLANSPEED"
  "-ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:MaxClientRate=$MAXCLIENTRATE"
  "-ini:Engine:[/Script/OnlineSubsystemUtils.IpNetDriver]:MaxInternetClientRate=$MAXINTERNETCLIENTRATE"
  "-ini:Engine:[/Script/SocketSubsystemEpic.EpicNetDriver]:MaxClientRate=$MAXCLIENTRATE"
  "-ini:Engine:[/Script/SocketSubsystemEpic.EpicNetDriver]:MaxInternetClientRate=$MAXINTERNETCLIENTRATE"
  "-ini:Game:[/Script/Engine.GameNetworkManager]:TotalNetBandwidth=$TOTALNETBANDWIDTH"
  "-ini:Game:[/Script/Engine.GameNetworkManager]:MaxDynamicBandwidth=$MAXDYNAMICBANDWIDTH"
  "-ini:Game:[/Script/Engine.GameNetworkManager]:MinDynamicBandwidth=$MINDYNAMICBANDWIDTH"
  "-ini:Scalability:[NetworkQuality@3]:TotalNetBandwidth=$TOTALNETBANDWIDTH"
  "-ini:Scalability:[NetworkQuality@3]:MaxDynamicBandwidth=$MAXDYNAMICBANDWIDTH"
  "-ini:Scalability:[NetworkQuality@3]:MinDynamicBandwidth=$MINDYNAMICBANDWIDTH"
  "-ini:ServerSettings:[/Script/FactoryGame.FGServerSubsystem]:mAutoPause=$AUTOPAUSE"
  "-ini:ServerSettings:[/Script/FactoryGame.FGServerSubsystem]:mAutoSaveOnDisconnect=$AUTOSAVEONDISCONNECT"
  "$DISABLESEASONALEVENTS"
  "$MULTIHOME"
)

if [[ "${SKIPUPDATE,,}" != "false" ]] && [ ! -f "/config/gamefiles/FactoryServer.sh" ]; then
    printf "%s Skip update is set, but no game files exist. Updating anyway\\n" "${MSGWARNING}"
    SKIPUPDATE="false"
fi

if [[ "${SKIPUPDATE,,}" != "true" ]]; then
    STEAMBETAPASSWORD=""

    if [[ -n "${STEAMBETAID}" ]]; then
        printf "STEAMBETAID is set. Using beta ID: %s\\n" "$STEAMBETAID"
        STEAMBETAFLAG="$STEAMBETAID"
        if [[ -n "${STEAMBETAKEY}" ]]; then
            STEAMBETAPASSWORD="-betapassword $STEAMBETAKEY"
            printf "Beta password provided\\n"
        fi
    elif [[ "${STEAMBETA,,}" == "true" ]]; then
        printf "Experimental flag is set. Experimental will be downloaded instead of Early Access.\\n"
        STEAMBETAFLAG="experimental"
    else
        STEAMBETAFLAG="public"
    fi

    STORAGEAVAILABLE=$(stat -f -c "%a*%S" .)
    STORAGEAVAILABLE=$((STORAGEAVAILABLE/1024/1024/1024))
    printf "Checking available storage: %sGB detected\\n" "$STORAGEAVAILABLE"

    if [[ "$STORAGEAVAILABLE" -lt 8 ]]; then
        printf "You have less than 8GB (%sGB detected) of available storage to download the game.\\nIf this is a fresh install, it will probably fail.\\n" "$STORAGEAVAILABLE"
    fi

    printf "\\nDownloading the latest version of the game...\\n"
    if [ -f "/config/gamefiles/steamapps/appmanifest_1690800.acf" ]; then
        printf "\\nRemoving the app manifest to force Steam to check for an update...\\n"
        rm "/config/gamefiles/steamapps/appmanifest_1690800.acf" || true
    fi
    STEAMCMD_ATTEMPTS=3
    for attempt in $(seq 1 $STEAMCMD_ATTEMPTS); do
        if steamcmd +force_install_dir /config/gamefiles +login anonymous +app_update "$STEAMAPPID" -beta "$STEAMBETAFLAG" $STEAMBETAPASSWORD validate +quit; then
            break
        elif [ "$attempt" -eq "$STEAMCMD_ATTEMPTS" ]; then
            printf "steamcmd failed after %s attempts\\n" "$STEAMCMD_ATTEMPTS"
            exit 1
        else
            printf "steamcmd failed (attempt %s/%s), retrying...\\n" "$attempt" "$STEAMCMD_ATTEMPTS"
            sleep 5
        fi
    done
    cp -r /home/steam/.steam/steam/logs/* "/config/logs/steam" || printf "Failed to store Steam logs\\n"
else
    printf "Skipping update as flag is set\\n"
fi

printf "Launching game server\\n\\n"

cp -r "/config/saved/server/." "/config/backups/"
cp -r "${GAMESAVESDIR}/server/." "/config/backups" # Useful after the first run.
rm -rf "$GAMESAVESDIR"
ln -sf "/config/saved" "$GAMESAVESDIR"

if [ ! -f "/config/gamefiles/FactoryServer.sh" ]; then
    printf "FactoryServer launch script is missing.\\n"
    exit 1
fi

cd /config/gamefiles || exit 1

chmod +x FactoryServer.sh || true
./FactoryServer.sh -Port="$SERVERGAMEPORT" -ReliablePort="$SERVERMESSAGINGPORT" -ExternalReliablePort="$SERVERMESSAGINGPORT" "${ini_args[@]}" "$@" &
factory_wrapper_pid=$!

sleep 2
satisfactory_pid=$(ps --ppid $factory_wrapper_pid o pid=)

backup_pid=""
if [[ "$BACKUPINTERVAL" -gt 0 ]]; then
    (
        while sleep "$BACKUPINTERVAL"; do
            tar -czf "/config/backups/save-$(date +%Y%m%d-%H%M%S).tar.gz" -C /config/saved . || printf "Backup failed\\n"
            ls -1t /config/backups/save-*.tar.gz 2>/dev/null | tail -n "+$((BACKUPKEEP + 1))" | xargs -r rm -f
        done
    ) &
    backup_pid=$!
fi

shutdown() {
    printf "\\nReceived SIGINT. Shutting down.\\n"
    kill -INT $satisfactory_pid 2>/dev/null
    [[ -n "$backup_pid" ]] && kill $backup_pid 2>/dev/null
}
trap shutdown SIGINT SIGTERM

wait $factory_wrapper_pid
