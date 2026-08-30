pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "../Common/ConfigIncludeResolve.js" as ConfigIncludeResolve
import "../Common/KeybindActions.js" as Actions

Singleton {
    id: root
    readonly property var log: Log.scoped("KeybindsService")

    property bool available: CompositorService.isNiri || CompositorService.isHyprland || CompositorService.isMango
    property string currentProvider: {
        if (CompositorService.isNiri)
            return "niri";
        if (CompositorService.isHyprland)
            return "hyprland";
        if (CompositorService.isMango)
            return "mangowc";
        return "";
    }

    readonly property string cheatsheetProvider: {
        if (CompositorService.isNiri)
            return "niri";
        if (CompositorService.isHyprland)
            return "hyprland";
        if (CompositorService.isMango)
            return "mangowc";
        return "";
    }
    property bool cheatsheetAvailable: cheatsheetProvider !== ""
    property bool cheatsheetLoading: false
    property var cheatsheet: ({})

    property bool loading: false
    property bool saving: false
    property bool fixing: false
    property string lastError: ""
    property string modKey: "Super"
    property bool advsBindsIncluded: true

    property var advsStatus: ({
            "exists": true,
            "included": true,
            "includePosition": -1,
            "totalIncludes": 0,
            "bindsAfterAdvs": 0,
            "effective": true,
            "overriddenBy": 0,
            "statusMessage": "",
            "configFormat": "",
            "readOnly": false
        })

    property var _rawData: null
    property var keybinds: ({})
    property var _allBinds: ({})
    property var _categories: []
    property var _flatCache: []
    property var displayList: []
    property int _dataVersion: 0
    property string _pendingSavedKey: ""

    readonly property var categoryOrder: Actions.getCategoryOrder()
    readonly property string configDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation))
    readonly property string compositorConfigDir: {
        switch (currentProvider) {
        case "niri":
            return configDir + "/niri";
        case "hyprland":
            return configDir + "/hypr";
        case "mangowc":
            return configDir + "/mango";
        default:
            return "";
        }
    }
    readonly property string advsBindsPath: {
        switch (currentProvider) {
        case "niri":
            return compositorConfigDir + "/advs/binds.kdl";
        case "hyprland":
            return compositorConfigDir + "/advs/binds.lua";
        case "mangowc":
            return compositorConfigDir + "/advs/binds.conf";
        default:
            return "";
        }
    }
    readonly property string mainConfigPath: {
        switch (currentProvider) {
        case "niri":
            return compositorConfigDir + "/config.kdl";
        case "hyprland":
            return compositorConfigDir + "/hyprland.lua";
        case "mangowc":
            return compositorConfigDir + "/config.conf";
        default:
            return "";
        }
    }
    readonly property bool readOnly: currentProvider === "hyprland" && advsStatus.readOnly === true
    readonly property var actionTypes: Actions.getActionTypes()
    readonly property var advsActions: getAdvsActions()

    signal bindsLoaded
    signal bindSaved(string key)
    signal bindSaveCompleted(bool success)
    signal bindRemoved(string key)
    signal advsBindsFixed
    signal cheatsheetLoaded

    Connections {
        target: CompositorService
        function onCompositorChanged() {
            if (!CompositorService.isNiri && !CompositorService.isMango)
                return;
            Qt.callLater(root.loadBinds);
        }
    }

    Connections {
        target: NiriService
        enabled: CompositorService.isNiri
        function onConfigReloaded() {
            Qt.callLater(root.loadBinds, false);
        }
    }

    Process {
        id: cheatsheetProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.cheatsheet = JSON.parse(text);
                } catch (e) {
                    log.error("Failed to parse cheatsheet:", e);
                    root.cheatsheet = {};
                }
                root.cheatsheetLoading = false;
                root.cheatsheetLoaded();
            }
        }

        onExited: exitCode => {
            if (exitCode === 0)
                return;
            log.warn("Cheatsheet load failed with code:", exitCode);
            root.cheatsheetLoading = false;
        }
    }

    Process {
        id: loadProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._rawData = JSON.parse(text);
                    root._processData();
                } catch (e) {
                    log.error("Failed to parse binds:", e);
                }
                root.loading = false;
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                log.warn("Load process failed with code:", exitCode);
                root.loading = false;
            }
        }
    }

    Process {
        id: saveProcess
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                root.lastError = text.trim();
                ToastService.showError(I18n.tr("Failed to save keybind"), "", root.lastError, "keybinds");
            }
        }

        onExited: exitCode => {
            root.saving = false;
            if (exitCode !== 0) {
                log.error("Save failed with code:", exitCode);
                root.bindSaveCompleted(false);
                return;
            }
            root.lastError = "";
            root.bindSaveCompleted(true);
            if (CompositorService.isMango)
                MangoService.reloadConfig();
            root.loadBinds(false);
        }
    }

    Process {
        id: removeProcess
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                root.lastError = text.trim();
                ToastService.showError(I18n.tr("Failed to remove keybind"), "", root.lastError, "keybinds");
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                log.error("Remove failed with code:", exitCode);
                return;
            }
            root.lastError = "";
            if (CompositorService.isMango)
                MangoService.reloadConfig();
            root.loadBinds(false);
        }
    }

    Process {
        id: fixProcess
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                root.lastError = text.trim();
                ToastService.showError(I18n.tr("Failed to add binds include"), "", root.lastError, "keybinds");
            }
        }

        onExited: exitCode => {
            root.fixing = false;
            if (exitCode !== 0) {
                log.error("Fix failed with code:", exitCode);
                return;
            }
            root.lastError = "";
            root.advsBindsIncluded = true;
            root.advsBindsFixed();
            const bindsRel = root.currentProvider === "niri" ? "advs/binds.kdl" : root.currentProvider === "hyprland" ? "advs/binds.lua" : "advs/binds.conf";
            ToastService.showInfo(I18n.tr("Binds include added"), I18n.tr("%1 is now included in config").arg(bindsRel), "", "keybinds");
            if (CompositorService.isMango)
                MangoService.reloadConfig();
            Qt.callLater(root.forceReload);
        }
    }

    function fixAdvsBindsInclude() {
        if (fixing || advsBindsIncluded || !compositorConfigDir)
            return;
        if (readOnly) {
            showHyprlandReadOnlyWarning();
            return;
        }
        fixing = true;
        const timestamp = Math.floor(Date.now() / 1000);
        const backupPath = `${mainConfigPath}.advsbackup${timestamp}`;
        let script;
        switch (currentProvider) {
        case "niri":
            script = ConfigIncludeResolve.buildRepairScript({
                configFile: mainConfigPath,
                backupFile: backupPath,
                fragmentFile: compositorConfigDir + "/advs/binds.kdl",
                grepPattern: 'include.*"advs/binds.kdl"',
                includeLine: 'include "advs/binds.kdl"'
            });
            break;
        case "hyprland":
            script = ConfigIncludeResolve.buildRepairScript({
                configFile: mainConfigPath,
                backupFile: backupPath,
                fragmentFiles: [compositorConfigDir + "/advs/binds.lua", compositorConfigDir + "/advs/binds-user.lua"],
                includes: [
                    {
                        grepPattern: "advs.binds",
                        includeLine: "require(\"advs.binds\")"
                    },
                    {
                        grepPattern: "advs.binds-user",
                        includeLine: "require(\"advs.binds-user\")"
                    }
                ]
            });
            break;
        case "mangowc":
            script = ConfigIncludeResolve.buildRepairScript({
                configFile: mainConfigPath,
                backupFile: backupPath,
                fragmentFile: compositorConfigDir + "/advs/binds.conf",
                grepPattern: "source.*advs/binds.conf",
                includeLine: "source = ./advs/binds.conf"
            });
            break;
        default:
            fixing = false;
            return;
        }
        fixProcess.command = ["sh", "-c", script];
        fixProcess.running = true;
    }

    function forceReload() {
        _allBinds = {};
        _flatCache = [];
        _categories = [];
        loadBinds(true);
    }

    function loadCheatsheet(provider) {
        if (cheatsheetProcess.running)
            return;
        const target = provider || cheatsheetProvider;
        if (!target)
            return;
        cheatsheetLoading = true;
        cheatsheetProcess.command = ["advs", "keybinds", "show", target];
        cheatsheetProcess.running = true;
    }

    function loadBinds(showLoading) {
        if (loadProcess.running || !available)
            return;
        const hasData = Object.keys(_allBinds).length > 0;
        loading = showLoading !== false && !hasData;
        loadProcess.command = ["advs", "keybinds", "show", currentProvider];
        loadProcess.running = true;
    }

    function _processData() {
        keybinds = _rawData || {};
        modKey = currentProvider === "niri" ? (_rawData?.modKey || "Super") : "Super";
        advsBindsIncluded = _rawData?.advsBindsIncluded ?? true;
        const status = _rawData?.advsStatus;
        if (status) {
            advsStatus = {
                "exists": status.exists ?? true,
                "included": status.included ?? true,
                "includePosition": status.includePosition ?? -1,
                "totalIncludes": status.totalIncludes ?? 0,
                "bindsAfterAdvs": status.bindsAfterAdvs ?? 0,
                "effective": status.effective ?? true,
                "overriddenBy": status.overriddenBy ?? 0,
                "statusMessage": status.statusMessage ?? "",
                "configFormat": status.configFormat ?? "",
                "readOnly": status.readOnly === true
            };
        }
        _maybeWarnHyprlandLegacyConf();

        if (!_rawData?.binds) {
            _allBinds = {};
            _categories = [];
            _flatCache = [];
            displayList = [];
            _dataVersion++;
            bindsLoaded();
            if (_pendingSavedKey) {
                bindSaved(_pendingSavedKey);
                _pendingSavedKey = "";
            }
            return;
        }

        const processed = {};
        const bindsData = _rawData.binds;
        for (const cat in bindsData) {
            const binds = bindsData[cat];
            for (var i = 0; i < binds.length; i++) {
                const bind = binds[i];
                if (currentProvider === "hyprland" && bind.action && bind.action.startsWith("exec "))
                    bind.action = "spawn " + bind.action.slice(5);
                const targetCat = Actions.isAdvsAction(bind.action) ? "ADVS" : cat;
                if (!processed[targetCat])
                    processed[targetCat] = [];
                processed[targetCat].push(bind);
            }
        }

        const sortedCats = Object.keys(processed).sort((a, b) => {
            const ai = categoryOrder.indexOf(a);
            const bi = categoryOrder.indexOf(b);
            return (ai === -1 ? 999 : ai) - (bi === -1 ? 999 : bi);
        });

        const grouped = [];
        const actionMap = {};
        for (var ci = 0; ci < sortedCats.length; ci++) {
            const category = sortedCats[ci];
            const binds = processed[category];
            if (!binds)
                continue;
            for (var i = 0; i < binds.length; i++) {
                const bind = binds[i];
                const action = bind.action || "";
                const sourceStr = bind.source || "config";
                const keyData = {
                    "key": bind.key || "",
                    "desc": bind.desc || "",
                    "source": sourceStr,
                    "isOverride": sourceStr === "advs",
                    "isADVSManaged": sourceStr === "advs" || sourceStr === "advs-default",
                    "hasDefault": bind.hasDefault === true,
                    "cooldownMs": bind.cooldownMs || 0,
                    "flags": bind.flags || "",
                    "allowWhenLocked": bind.allowWhenLocked || false,
                    "allowInhibiting": bind.allowInhibiting,
                    "repeat": bind.repeat
                };
                if (actionMap[action]) {
                    actionMap[action].keys.push(keyData);
                    if (!actionMap[action].desc && bind.desc)
                        actionMap[action].desc = bind.desc;
                    if (!actionMap[action].conflict && bind.conflict)
                        actionMap[action].conflict = bind.conflict;
                } else {
                    const entry = {
                        "category": category,
                        "action": action,
                        "desc": bind.desc || "",
                        "keys": [keyData],
                        "conflict": bind.conflict || null
                    };
                    actionMap[action] = entry;
                    grouped.push(entry);
                }
            }
        }

        const list = [];
        for (const cat of sortedCats) {
            list.push({
                "id": "cat:" + cat,
                "type": "category",
                "name": cat
            });
            const binds = processed[cat];
            if (!binds)
                continue;
            for (const bind of binds)
                list.push({
                    "id": "bind:" + bind.key,
                    "type": "bind",
                    "key": bind.key,
                    "desc": bind.desc
                });
        }

        _allBinds = processed;
        _categories = sortedCats;
        _flatCache = grouped;
        displayList = list;
        _dataVersion++;
        bindsLoaded();
        if (_pendingSavedKey) {
            bindSaved(_pendingSavedKey);
            _pendingSavedKey = "";
        }
    }

    function getCategories() {
        return _categories;
    }

    function getFlatBinds() {
        return _flatCache;
    }

    function keysForAction(actionId) {
        if (!actionId)
            return [];
        for (let i = 0; i < _flatCache.length; i++) {
            const group = _flatCache[i];
            if (!group || group.action !== actionId || !Array.isArray(group.keys))
                continue;
            const keys = [];
            for (let k = 0; k < group.keys.length; k++) {
                const key = group.keys[k]?.key || "";
                if (key)
                    keys.push(key);
            }
            return keys;
        }
        return [];
    }

    function saveBind(originalKey, bindData) {
        if (readOnly) {
            showHyprlandReadOnlyWarning();
            return;
        }
        if (!bindData.key || !Actions.isValidAction(bindData.action))
            return;
        saving = true;
        const cmd = ["advs", "keybinds", "set", currentProvider, bindData.key, bindData.action, "--desc", bindData.desc || ""];
        if (originalKey && originalKey !== bindData.key)
            cmd.push("--replace-key", originalKey);
        if (bindData.cooldownMs > 0)
            cmd.push("--cooldown-ms", String(bindData.cooldownMs));
        if (bindData.allowWhenLocked)
            cmd.push("--allow-when-locked");
        if (bindData.repeat === false)
            cmd.push("--no-repeat");
        if (bindData.allowInhibiting === false)
            cmd.push("--no-inhibiting");
        if (bindData.flags)
            cmd.push("--flags", bindData.flags);
        saveProcess.command = cmd;
        saveProcess.running = true;
        _pendingSavedKey = bindData.key;
    }

    property bool _hyprlandLegacyWarnShown: false

    function _maybeWarnHyprlandLegacyConf() {
        if (_hyprlandLegacyWarnShown)
            return;
        if (currentProvider !== "hyprland")
            return;
        if (readOnly) {
            _hyprlandLegacyWarnShown = true;
            showHyprlandReadOnlyWarning();
            return;
        }
        if (!advsStatus.exists || advsStatus.included)
            return;
        _hyprlandLegacyWarnShown = true;
        ToastService.showWarning(I18n.tr("Hyprland config include missing"), I18n.tr("ADVS Settings writes Lua keybinds. Add the ADVS include so edits apply."), "advs setup", "hyprland-migration");
    }

    function showHyprlandReadOnlyWarning() {
        ToastService.showWarning(I18n.tr("Hyprland conf mode"), I18n.tr("This install is still using hyprland.conf. Run advs setup to migrate before changing these settings."), "advs setup", "hyprland-migration");
    }

    function removeBind(key) {
        if (readOnly) {
            showHyprlandReadOnlyWarning();
            return;
        }
        if (!key)
            return;
        removeProcess.command = ["advs", "keybinds", "remove", currentProvider, key];
        removeProcess.running = true;
        bindRemoved(key);
    }

    function resetBind(key) {
        if (readOnly) {
            showHyprlandReadOnlyWarning();
            return;
        }
        if (!key)
            return;
        removeProcess.command = ["advs", "keybinds", "reset", currentProvider, key];
        removeProcess.running = true;
        bindRemoved(key);
    }

    function getActionLabel(action) {
        return Actions.getActionLabel(action, currentProvider);
    }

    function getCompositorCategories() {
        return Actions.getCompositorCategories(currentProvider);
    }

    function getCompositorActions(category) {
        return Actions.getCompositorActions(currentProvider, category);
    }

    function getAdvsActions() {
        return Actions.getAdvsActions(CompositorService.isNiri, CompositorService.isHyprland);
    }
}
