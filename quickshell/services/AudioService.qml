pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Singleton {
    id: audioService

    property string preferredPlayerKey: ""
    property var playerStartedAt: ({})
    property int playSerial: 0
    property string osdMessage: ""
    property string osdIcon: "󰎈"
    property bool osdVisible: false
    property string lastTrackSignature: ""

    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var playbackStreams: playbackStreamList()
    readonly property var sourcePlayers: orderedSourcePlayers()
    readonly property var sourceCyclePlayers: orderedCycleSourcePlayers()
    readonly property var player: selectActivePlayer()
    readonly property bool hasMedia: player !== null && (player.trackTitle || player.trackArtist)

    function isProxyPlayer(player) {
        const dbusName = String(player?.dbusName || "").toLowerCase();
        const desktopEntry = String(player?.desktopEntry || "").toLowerCase();
        return dbusName.indexOf("playerctld") !== -1 || desktopEntry === "playerctld";
    }

    function hasMetadata(player) {
        return !!(player && (player.trackTitle || player.trackArtist || player.identity || player.desktopEntry));
    }

    function hasTrackMetadata(player) {
        return !!(player && (player.trackTitle || player.trackArtist || player.trackAlbum || player.trackArtUrl));
    }

    function playerCanControl(player) {
        return !!(player && (player.canTogglePlaying || player.canPlay || player.canPause || player.canGoNext || player.canGoPrevious));
    }

    function canHandleAction(player, action) {
        if (!player) return false;
        if (action === "next") return !!player.canGoNext;
        if (action === "previous") return !!player.canGoPrevious;
        if (action === "play") return !!(player.canPlay || player.canTogglePlaying);
        if (action === "pause") return !!(player.canPause || player.canTogglePlaying);
        if (action === "playPause") return !!(player.canTogglePlaying || player.canPlay || player.canPause);
        return false;
    }

    function canCycleSource(player) {
        return !!(player && hasMetadata(player) && (player.isPlaying || player.canPlay));
    }

    function nodeProps(node) {
        return node && node.ready && node.properties ? node.properties : {};
    }

    function isPlaybackStream(node) {
        if (!node || !node.isStream) return false;
        if (node.isSink === true) return true;

        const mediaClass = String(node.type || "");
        return mediaClass.indexOf("Stream/Output/Audio") !== -1
            || mediaClass.indexOf("AudioOutStream") !== -1
            || mediaClass.indexOf("Output") !== -1;
    }

    function playbackStreamList() {
        const list = [];
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n && n.isStream && isPlaybackStream(n) && n.audio) list.push(n);
        }
        return list;
    }

    function streamLabelKey(label) {
        let key = String(label || "").toLowerCase();
        key = key.replace(/^pipewire alsa \[/, "");
        key = key.replace(/\]$/, "");
        key = key.replace(/^alsa playback \[/, "");
        key = key.replace(/[^a-z0-9]+/g, "");
        return key;
    }

    function rawStreamLabel(node) {
        if (!node) return "";
        const p = nodeProps(node);
        return p["application.name"] || node.description || p["media.name"] || p["node.name"] || node.name || "";
    }

    function playerAppLabel(player) {
        if (!player) return "";
        let dbus = String(player.dbusName || "");
        dbus = dbus.replace(/^org\.mpris\.MediaPlayer2\./, "");
        dbus = dbus.replace(/\.instance[0-9]+$/, "");
        return player.desktopEntry || player.identity || dbus;
    }

    function playerHasPlaybackStream(player) {
        const playerKey = streamLabelKey(playerAppLabel(player));
        if (!playerKey) return false;

        for (let i = 0; i < playbackStreams.length; i++) {
            const streamKey = streamLabelKey(rawStreamLabel(playbackStreams[i]));
            if (!streamKey) continue;
            if (streamKey === playerKey || streamKey.indexOf(playerKey) !== -1 || playerKey.indexOf(streamKey) !== -1) return true;
        }
        return false;
    }

    function playerKey(player) {
        if (!player) return "";
        return String(player.dbusName || player.desktopEntry || player.identity || "");
    }

    function labelFor(player) {
        if (!player) return "";
        return player.trackTitle || player.identity || player.desktopEntry || "";
    }

    function trackSignature(player) {
        if (!player) return "";
        return [player.trackTitle || "", player.trackArtist || "", player.trackAlbum || "", player.trackArtUrl || ""].join("\u001f");
    }

    function osdTextFor(player, fallback) {
        if (!player) return fallback;
        const label = labelFor(player);
        if (label && player.trackArtist) return label + " - " + player.trackArtist;
        return label || fallback;
    }

    function playerOrder(player, fallback) {
        const key = playerKey(player);
        const value = key ? playerStartedAt[key] : undefined;
        return value === undefined ? fallback : value;
    }

    function syncPlayingOrder() {
        const next = {};
        const alive = {};
        let serial = playSerial;

        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            const key = playerKey(p);
            if (!key) continue;

            alive[key] = true;
            if (!p.isPlaying) continue;

            if (playerStartedAt[key] === undefined) {
                serial += 1;
                next[key] = serial;
            } else {
                next[key] = playerStartedAt[key];
            }
        }

        if (preferredPlayerKey && !alive[preferredPlayerKey]) preferredPlayerKey = "";
        playSerial = serial;
        playerStartedAt = next;
    }

    function orderedSourcePlayers() {
        const list = [];
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (hasMetadata(p)) list.push(p);
        }

        list.sort((a, b) => {
            if (!!a.isPlaying !== !!b.isPlaying) return a.isPlaying ? -1 : 1;
            if (isProxyPlayer(a) !== isProxyPlayer(b)) return isProxyPlayer(a) ? 1 : -1;
            if (a.isPlaying && b.isPlaying) {
                const orderDelta = playerOrder(a, 1000) - playerOrder(b, 1000);
                if (orderDelta !== 0) return orderDelta;
            }
            return labelFor(a).localeCompare(labelFor(b));
        });

        return list;
    }

    function orderedCycleSourcePlayers() {
        const list = [];
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (canCycleSource(p)) list.push(p);
        }

        list.sort((a, b) => {
            if (isProxyPlayer(a) !== isProxyPlayer(b)) return isProxyPlayer(a) ? 1 : -1;
            return labelFor(a).localeCompare(labelFor(b));
        });

        return list;
    }

    function oldestPlayingPlayer(requirePlaybackStream) {
        let oldest = null;
        let oldestOrder = 0;
        let playingProxy = null;
        let proxyOrder = 0;

        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (!p || !p.isPlaying) continue;
            if (requirePlaybackStream && !playerHasPlaybackStream(p)) continue;

            const proxy = isProxyPlayer(p);
            const order = playerOrder(p, i + 1000);
            if (!proxy && (!oldest || order < oldestOrder)) {
                oldest = p;
                oldestOrder = order;
            } else if (proxy && (!playingProxy || order < proxyOrder)) {
                playingProxy = p;
                proxyOrder = order;
            }
        }

        return oldest || playingProxy || null;
    }

    function selectActivePlayer() {
        let preferred = null;
        let trackPlayer = null;
        let trackProxy = null;
        let streamPlayer = null;
        let streamProxy = null;
        let controllablePlayer = null;
        let controllableProxy = null;
        let identityPlayer = null;
        let identityProxy = null;

        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (!p) continue;
            const proxy = isProxyPlayer(p);

            if (preferredPlayerKey && playerKey(p) === preferredPlayerKey && hasMetadata(p)) preferred = p;

            if (playerHasPlaybackStream(p)) {
                if (!proxy && !streamPlayer) streamPlayer = p;
                else if (proxy && !streamProxy) streamProxy = p;
            } else if (hasTrackMetadata(p)) {
                if (!proxy && !trackPlayer) trackPlayer = p;
                else if (proxy && !trackProxy) trackProxy = p;
            } else if (playerCanControl(p)) {
                if (!proxy && !controllablePlayer) controllablePlayer = p;
                else if (proxy && !controllableProxy) controllableProxy = p;
            } else if (hasMetadata(p)) {
                if (!proxy && !identityPlayer) identityPlayer = p;
                else if (proxy && !identityProxy) identityProxy = p;
            }
        }

        if (preferred && preferred.isPlaying) return preferred;
        const streamCandidate = streamPlayer || streamProxy;
        const streamPreferred = preferred && playerHasPlaybackStream(preferred) ? preferred : null;
        return oldestPlayingPlayer(true) || oldestPlayingPlayer(false) || streamPreferred || streamCandidate || preferred || trackPlayer || trackProxy || controllablePlayer || controllableProxy || identityPlayer || identityProxy || null;
    }

    function playerForKey(key) {
        if (!key) return null;
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (playerKey(p) === key) return p;
        }
        return null;
    }

    function selectPlayer(key) {
        const p = playerForKey(key);
        if (!p || !hasMetadata(p)) return false;
        preferredPlayerKey = playerKey(p);
        showOsd("Source", "󰎈", p);
        return true;
    }

    function playPlayer(player) {
        if (!player) return false;
        if (player.canPlay) {
            player.play();
            return true;
        }
        return false;
    }

    function pausePlayer(player) {
        if (!player) return false;
        if (player.canPause) {
            player.pause();
            return true;
        }
        if (player.canTogglePlaying && player.isPlaying) {
            player.togglePlaying();
            return true;
        }
        return false;
    }

    function switchSource(delta, transferPlayback, showFeedback) {
        const list = sourceCyclePlayers;
        if (!list || list.length === 0) return false;

        const activeKey = playerKey(player);
        let index = 0;
        for (let i = 0; i < list.length; i++) {
            if (playerKey(list[i]) === activeKey) {
                index = i;
                break;
            }
        }

        index = (index + delta + list.length) % list.length;
        const current = player;
        const next = list[index];
        const currentWasPlaying = current && current.isPlaying;
        const currentKey = playerKey(current);
        const nextKey = playerKey(next);

        preferredPlayerKey = nextKey;

        if (transferPlayback && currentWasPlaying && next && nextKey !== currentKey) {
            const nextStarted = next.isPlaying || playPlayer(next);
            if (nextStarted) pausePlayer(current);
        }

        if (showFeedback !== false) showOsd("Source", "󰎈", next);
        return true;
    }

    function playerForAction(action, targetKey) {
        const targeted = playerForKey(targetKey);
        if (targeted) return targeted;

        if (action === "pause" || action === "playPause") {
            const oldest = oldestPlayingPlayer(true) || oldestPlayingPlayer(false);
            if (oldest) return oldest;
        }

        if (canHandleAction(player, action)) return player;

        for (let i = 0; i < sourcePlayers.length; i++) {
            if (canHandleAction(sourcePlayers[i], action)) return sourcePlayers[i];
        }

        return player;
    }

    function showOsd(actionLabel, iconName, targetPlayer) {
        osdIcon = iconName || "󰎈";
        osdMessage = osdTextFor(targetPlayer || player, actionLabel);
        osdVisible = true;
        osdHideTimer.restart();
    }

    function runAction(action, showFeedback, targetKey) {
        const targetPlayer = playerForAction(action, targetKey);
        const key = playerKey(targetPlayer);
        let actionLabel = "Play/pause";
        let iconName = "󰎈";
        let handled = false;

        if (action === "next") {
            actionLabel = "Next";
            iconName = "󰒭";
            if (targetPlayer && targetPlayer.canGoNext) {
                targetPlayer.next();
                handled = true;
            }
        } else if (action === "previous") {
            actionLabel = "Previous";
            iconName = "󰒮";
            if (targetPlayer && targetPlayer.canGoPrevious) {
                targetPlayer.previous();
                handled = true;
            }
        } else if (action === "play") {
            actionLabel = "Play";
            iconName = "󰐊";
            handled = playPlayer(targetPlayer);
        } else if (action === "pause") {
            actionLabel = "Pause";
            iconName = "󰏤";
            handled = pausePlayer(targetPlayer);
        } else if (action === "playPause") {
            actionLabel = targetPlayer && targetPlayer.isPlaying ? "Pause" : "Play";
            iconName = targetPlayer && targetPlayer.isPlaying ? "󰏤" : "󰐊";
            if (targetPlayer && targetPlayer.isPlaying) handled = pausePlayer(targetPlayer);
            else handled = playPlayer(targetPlayer);
            if (!handled && targetPlayer && targetPlayer.canTogglePlaying) {
                targetPlayer.togglePlaying();
                handled = true;
            }
        }

        if (handled && key) preferredPlayerKey = key;
        if (handled && showFeedback !== false) showOsd(actionLabel, iconName, targetPlayer);
        return handled;
    }

    Component.onCompleted: {
        syncPlayingOrder();
        lastTrackSignature = trackSignature(player);
    }
    onPlayersChanged: syncPlayingOrder()

    Instantiator {
        model: audioService.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { audioService.syncPlayingOrder(); }
            function onTrackTitleChanged() {
                const sig = audioService.trackSignature(audioService.player);
                if (sig.length > 0 && sig !== audioService.lastTrackSignature) {
                    audioService.lastTrackSignature = sig;
                    audioService.showOsd("Media", "󰎈", audioService.player);
                }
            }
        }
    }

    Timer {
        id: osdHideTimer
        interval: 1600
        onTriggered: audioService.osdVisible = false
    }

    PwObjectTracker {
        objects: audioService.playbackStreams
    }

    Process {
        id: pipewireCmd
        command: ["wpctl"]
    }

    function setDefault(id) {
        pipewireCmd.command = ["wpctl", "set-default", id];
        pipewireCmd.running = true;
    }

    Process {
        id: settingsCmd
        command: ["pavucontrol"]
    }

    function openSettings() {
        settingsCmd.running = true;
    }

    readonly property string currentAudioIcon: {
        const vol = Pipewire.defaultAudioSink?.audio.volume * 100;
        if (Pipewire.defaultAudioSink?.audio.muted)
            return "󰝟";
        if (vol >= 65)
            return "󰕾";
        if (vol >= 25)
            return "󰖀";
        return "󰕿";
    }
}
