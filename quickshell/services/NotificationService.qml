pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Hyprland

Singleton {
    id: root

    property alias toastModel: toastModel
    property alias historyModel: historyModel
    property var liveNotifications: ({})
    property bool doNotDisturb: false
    property int unreadCount: 0
    readonly property int historyLimit: 30
    readonly property int normalTimeout: 3500
    readonly property int lowTimeout: 2000

    readonly property var browserNames: ({
        "brave": "brave-",
        "Brave": "brave-",
        "chrome": "chrome-",
        "Chrome": "chrome-",
        "Chromium": "chrome-",
        "firefox": "firefox-",
        "Firefox": "firefox-",
        "vivaldi": "vivaldi-",
        "Vivaldi": "vivaldi-",
        "edge": "edge-",
        "Edge": "edge-",
        "chromium": "chrome-",
    })

    readonly property var browserGenericClasses: ({
        "brave-": ["brave-browser"],
        "chrome-": ["chrome", "chromium", "google-chrome", "google-chrome-stable"],
        "firefox-": ["firefox"],
        "vivaldi-": ["vivaldi", "vivaldi-stable"],
        "edge-": ["microsoft-edge", "microsoft-edge-stable"]
    })

    function isGenericBrowserClass(prefix, cls) {
        const generic = browserGenericClasses[prefix] || [];
        const lower = String(cls || "").toLowerCase();
        for (let i = 0; i < generic.length; i++) {
            if (lower === generic[i]) return true;
        }
        return false;
    }

    function browserPrefixForAppName(appName) {
        const exact = browserNames[appName];
        if (exact) return exact;

        const lower = String(appName || "").toLowerCase();
        if (lower.indexOf("brave") !== -1) return "brave-";
        if (lower.indexOf("chrome") !== -1 || lower.indexOf("chromium") !== -1) return "chrome-";
        if (lower.indexOf("firefox") !== -1) return "firefox-";
        if (lower.indexOf("vivaldi") !== -1) return "vivaldi-";
        if (lower.indexOf("edge") !== -1) return "edge-";
        return "";
    }

    function normalizeClass(cls) {
        return String(cls || "").replace(/__-?Default$/, "");
    }

    function findBrowserWindowClass(appName, desktopEntry, title) {
        const browserPrefix = browserPrefixForAppName(`${appName} ${desktopEntry}`);
        if (!browserPrefix) return "";

        const prefix = browserPrefix.toLowerCase();
        const toplevels = [];

        const workspaces = Hyprland.workspaces.values;
        for (let w = 0; w < workspaces.length; w++) {
            const tls = workspaces[w].toplevels.values;
            for (let t = 0; t < tls.length; t++) {
                const keys = [tls[t].lastIpcObject?.class, tls[t].lastIpcObject?.initialClass, tls[t].wayland?.appId].filter(k => !!k);
                let cls = "";
                for (let k = 0; k < keys.length; k++) {
                    const key = String(keys[k]);
                    if (key.toLowerCase().startsWith(prefix)) {
                        cls = normalizeClass(key);
                        break;
                    }
                }

                if (cls.length > 0) {
                    toplevels.push({
                        cls: cls,
                        title: String(tls[t].lastIpcObject?.title || "").toLowerCase(),
                        generic: isGenericBrowserClass(prefix, cls)
                    });
                }
            }
        }

        if (toplevels.length === 0) return "";
        if (toplevels.length === 1) return toplevels[0].cls;

        const tl = String(title || "").toLowerCase();
        const tokens = String(appName || "")
            .toLowerCase()
            .replace(/[^a-z0-9 ]+/g, " ")
            .split(/\s+/)
            .filter(t => t.length >= 3);
        const summaryTokens = tl
            .replace(/[^a-z0-9 ]+/g, " ")
            .split(/\s+/)
            .filter(t => t.length >= 4 && ["from", "the", "for", "with", "this", "that", "your", "have"].indexOf(t) === -1);

        let best = toplevels[0];
        let bestScore = -Infinity;
        for (let i = 0; i < toplevels.length; i++) {
            const t = toplevels[i];
            let score = t.generic ? -100 : 0;
            for (let n = 0; n < tokens.length; n++) {
                if (t.cls.toLowerCase().indexOf(tokens[n]) !== -1) score += 30;
            }
            for (let n = 0; n < summaryTokens.length; n++) {
                if (t.cls.toLowerCase().indexOf(summaryTokens[n]) !== -1) score += 15;
            }
            if (tl.length >= 3) {
                if (tl.indexOf(t.title) !== -1 && t.title.length >= 5) score += 15;
                if (t.title.indexOf(tl) !== -1) score += 20;
            }
            if (score > bestScore) {
                bestScore = score;
                best = t;
            }
        }

        if (bestScore > -50) return best.cls;

        if (CompositorService.activeWindowClass.toLowerCase().startsWith(prefix)
                && !isGenericBrowserClass(prefix, CompositorService.activeWindowClass)) {
            return normalizeClass(CompositorService.activeWindowClass);
        }

        for (let i = 0; i < toplevels.length; i++) {
            if (!toplevels[i].generic) {
                return toplevels[i].cls;
            }
        }

        if (CompositorService.activeWindowClass.toLowerCase().startsWith(prefix)) {
            return normalizeClass(CompositorService.activeWindowClass);
        }

        return toplevels[0].cls;
    }

    function isTempPath(path) {
        return path.indexOf("/tmp/") !== -1;
    }

    function snapshotOf(notification) {
        const appName = String(notification.appName || "");
        const desktopEntry = String(notification.desktopEntry || "");
        const image = String(notification.image || "");
        const appIcon = String(notification.appIcon || "");
        const summary = String(notification.summary || "");
        let windowClass = findBrowserWindowClass(appName, desktopEntry, summary);
        let icon = "";

        const isBrowser = browserPrefixForAppName(`${appName} ${desktopEntry}`).length > 0;
        const hasImage = image.length > 0;
        const hasAppIcon = appIcon.length > 0 && !isTempPath(appIcon);

        if (isBrowser) {
            if (windowClass.length > 0) {
                const entry = CompositorService.getDesktopEntry(windowClass);
                if (entry) {
                    const resolved = CompositorService.getDesktopIcon(entry);
                    if (resolved.length > 0) {
                        icon = resolved;
                    }
                }
            }
            if (icon.length === 0 && hasImage) {
                icon = image;
            }
            if (icon.length === 0 && hasAppIcon) {
                icon = appIcon;
            }
        } else {
            if (hasAppIcon) {
                icon = appIcon;
            } else if (desktopEntry.length > 0) {
                const entry = CompositorService.getDesktopEntry(desktopEntry);
                if (entry) {
                    icon = CompositorService.getDesktopIcon(entry);
                }
            }
            if (icon.length === 0 && appName.length > 0) {
                const entry = CompositorService.getDesktopEntry(appName);
                if (entry) {
                    icon = CompositorService.getDesktopIcon(entry);
                }
            }
            if (icon.length === 0 && hasImage) {
                icon = image;
            }
        }

        return {
            notificationId: notification.id || Date.now(),
            appName: appName,
            appIcon: icon,
            windowClass: windowClass,
            desktopEntry: desktopEntry,
            summary: String(notification.summary || ""),
            body: String(notification.body || ""),
            image: image,
            urgency: notification.urgency,
            timestamp: Date.now()
        };
    }

    function handleNotification(notification) {
        notification.tracked = true;

        const item = snapshotOf(notification);
        liveNotifications[item.notificationId] = notification;

        notification.closed.connect(function() {
            if (liveNotifications[item.notificationId] === notification) {
                delete liveNotifications[item.notificationId];
            }
        });

        addHistory(item);
        unreadCount += 1;

        if (!doNotDisturb) {
            toastModel.insert(0, item);
        }
    }

    function addHistory(item) {
        historyModel.insert(0, item);
        while (historyModel.count > historyLimit) {
            historyModel.remove(historyModel.count - 1);
        }
    }

    function dismissToast(index) {
        if (index < 0 || index >= toastModel.count) return;

        const item = toastModel.get(index);
        closeLiveNotification(item.notificationId);
        toastModel.remove(index);
    }

    function expireToast(index) {
        if (index < 0 || index >= toastModel.count) return;

        const item = toastModel.get(index);
        if (item.urgency === NotificationUrgency.Critical) return;

        closeLiveNotification(item.notificationId);
        toastModel.remove(index);
    }

    function dismissAllToasts() {
        for (let i = toastModel.count - 1; i >= 0; i--) {
            dismissToast(i);
        }
    }

    function clearHistory() {
        historyModel.clear();
        unreadCount = 0;
    }

    function dismissHistory(index) {
        if (index < 0 || index >= historyModel.count) return;

        const item = historyModel.get(index);
        closeLiveNotification(item.notificationId);
        removeToastById(item.notificationId);
        historyModel.remove(index);
    }

    function markRead() {
        unreadCount = 0;
    }

    function toggleDoNotDisturb() {
        doNotDisturb = !doNotDisturb;
        if (doNotDisturb) dismissAllToasts();
    }

    function timeoutFor(urgency) {
        if (urgency === NotificationUrgency.Critical) return 0;
        if (urgency === NotificationUrgency.Low) return lowTimeout;
        return normalTimeout;
    }

    function closeLiveNotification(id) {
        const notification = liveNotifications[id];
        if (!notification) return;

        try {
            notification.dismiss();
        } catch (e) {
        }
        delete liveNotifications[id];
    }

    function invokeDefault(id) {
        const notification = liveNotifications[id];
        if (!notification) return;

        try {
            if (notification.actions) {
                for (let i = 0; i < notification.actions.length; i++) {
                    const action = notification.actions[i];
                    if (action && action.identifier === "default") {
                        action.invoke();
                        break;
                    }
                }
            }
        } catch (e) {
        }
        closeLiveNotification(id);
        removeToastById(id);
        removeHistoryById(id);
    }

    function focusAndDismiss(id, appName, windowClass) {
        if (windowClass && windowClass.length > 0) {
            CompositorService.focusWindowByClass(windowClass);
        } else if (appName && appName.length > 0) {
            CompositorService.focusWindowByAppName(appName);
        }
        invokeDefault(id);
    }

    function focusFromHistory(appName, index, windowClass) {
        if (windowClass && windowClass.length > 0) {
            CompositorService.focusWindowByClass(windowClass);
        } else if (appName && appName.length > 0) {
            CompositorService.focusWindowByAppName(appName);
        }
        if (index !== undefined && index !== null) {
            dismissHistory(index);
        }
    }

    function removeToastById(id) {
        for (let i = toastModel.count - 1; i >= 0; i--) {
            if (toastModel.get(i).notificationId === id) {
                toastModel.remove(i);
            }
        }
    }

    function removeHistoryById(id) {
        for (let i = historyModel.count - 1; i >= 0; i--) {
            if (historyModel.get(i).notificationId === id) {
                historyModel.remove(i);
            }
        }
    }

    ListModel {
        id: toastModel
    }

    ListModel {
        id: historyModel
    }

    NotificationServer {
        id: server
        imageSupported: true
        actionsSupported: true
        bodyMarkupSupported: false
        persistenceSupported: false

        onNotification: notification => root.handleNotification(notification)
    }
}
