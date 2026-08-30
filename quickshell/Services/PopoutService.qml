pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services

Singleton {
    id: root

    property var controlCenterPopout: null
    property var controlCenterLoader: null
    property var notificationCenterPopout: null
    property var notificationCenterLoader: null
    property var appDrawerPopout: null
    property var appDrawerLoader: null
    property var processListPopout: null
    property var processListPopoutLoader: null
    property var advDashPopout: null
    property var advDashPopoutLoader: null
    property var batteryPopout: null
    property var batteryPopoutLoader: null
    property var vpnPopout: null
    property var vpnPopoutLoader: null
    property var colorPickerPopout: null
    property var colorPickerPopoutLoader: null
    property var systemUpdatePopout: null
    property var systemUpdateLoader: null
    property var layoutPopout: null
    property var layoutPopoutLoader: null
    property var clipboardHistoryPopout: null
    property var clipboardHistoryPopoutLoader: null

    property var settingsModal: null
    property var settingsModalLoader: null
    property var clipboardHistoryModal: null
    property var advLauncherV2Modal: null
    property var advLauncherV2ModalLoader: null
    property var advIslandRouter: null
    property var spotlightBarModal: null
    property var spotlightBarModalLoader: null
    property var powerMenuModal: null
    property var powerMenuModalLoader: null
    property var powerMenuPopout: null
    property var powerMenuPopoutLoader: null
    property var processListModal: null
    property var processListModalLoader: null
    property var colorPickerModal: null
    property var notificationModal: null
    property var wifiPasswordModal: null
    property var wifiPasswordModalLoader: null
    property var wifiQRCodeModal: null
    property var wifiQRCodeModalLoader: null
    property var qrGeneratorModal: null
    property var qrGeneratorModalLoader: null
    property var polkitAuthModal: null
    property var polkitAuthModalLoader: null
    property var bluetoothPairingModal: null
    property var bluetoothPairingModalLoader: null
    property var networkInfoModal: null
    property var windowRuleModalLoader: null
    property var powerProfileModal: null
    property var powerProfileModalLoader: null

    property var notepadSlideouts: []

    property string pendingThemeInstall: ""
    property string pendingPluginInstall: ""

    // Deferred unload: keep popouts warm while the session is active and reclaim them on lock/monitors-off.
    property var _pendingUnloads: ({})

    Connections {
        target: SessionService
        function onSessionLocked() {
            root._flushPendingUnloads();
        }
    }

    Connections {
        target: IdleService
        function onMonitorsOffChanged() {
            if (IdleService.monitorsOff)
                root._flushPendingUnloads();
        }
    }

    function _scheduleUnload(key) {
        _pendingUnloads[key] = true;
    }

    function _flushPendingUnloads() {
        const keys = Object.keys(_pendingUnloads);
        _pendingUnloads = ({});
        for (let i = 0; i < keys.length; i++) {
            const unload = _deferredUnloaders[keys[i]];
            if (unload)
                unload();
        }
    }

    function _popoutStillPresented(popout) {
        return !!popout && (popout.shouldBeVisible === true || popout.isClosing === true);
    }

    function _unloadPopoutNow(popoutName, loaderName) {
        const loader = root[loaderName];
        if (!loader)
            return;
        if (_popoutStillPresented(root[popoutName]))
            return;
        root[popoutName] = null;
        loader.active = false;
    }

    readonly property var _deferredUnloaders: ({
            "advDash": () => _unloadPopoutNow("advDashPopout", "advDashPopoutLoader"),
            "controlCenter": () => _unloadPopoutNow("controlCenterPopout", "controlCenterLoader"),
            "notificationCenter": () => _unloadPopoutNow("notificationCenterPopout", "notificationCenterLoader"),
            "appDrawer": () => _unloadPopoutNow("appDrawerPopout", "appDrawerLoader"),
            "processList": () => _unloadPopoutNow("processListPopout", "processListPopoutLoader"),
            "battery": () => _unloadPopoutNow("batteryPopout", "batteryPopoutLoader"),
            "vpn": () => _unloadPopoutNow("vpnPopout", "vpnPopoutLoader"),
            "colorPicker": () => _unloadPopoutNow("colorPickerPopout", "colorPickerPopoutLoader"),
            "powerMenuPopout": () => _unloadPopoutNow("powerMenuPopout", "powerMenuPopoutLoader"),
            "systemUpdate": () => _unloadPopoutNow("systemUpdatePopout", "systemUpdateLoader"),
            "layout": () => _unloadPopoutNow("layoutPopout", "layoutPopoutLoader"),
            "clipboardHistory": () => _unloadPopoutNow("clipboardHistoryPopout", "clipboardHistoryPopoutLoader"),
            "settings": () => unloadSettingsNow()
        })

    function setPosition(popout, x, y, width, section, screen) {
        if (popout && popout.setTriggerPosition && arguments.length >= 6) {
            popout.setTriggerPosition(x, y, width, section, screen);
        }
    }

    function _islandOwnsSharedTrigger(screen) {
        const target = screen ?? advIslandRouter?.focusedIslandScreen?.() ?? null;
        if (advIslandRouter?.hasHostForScreen?.(target) !== true)
            return false;
        return SettingsData.advIslandIsSoleBarForScreen(target);
    }

    readonly property bool islandControlCenterOpen: advIslandRouter?.controlCenterOpen ?? false

    function routeToIsland(activityId, screen, shouldToggle, section) {
        if (!_islandOwnsSharedTrigger(screen))
            return false;
        if (shouldToggle === true)
            return advIslandRouter.toggleActivity(activityId, screen ?? null, section || "") === true;
        return advIslandRouter.openActivity(activityId, screen ?? null, section || "") === true;
    }

    function closeIslandActivity(activityId) {
        return advIslandRouter?.closeActivity?.(activityId) === true;
    }

    function openControlCenter(x, y, width, section, screen) {
        if (routeToIsland("controlcenter", screen, false, section))
            return;
        if (controlCenterPopout) {
            setPosition(controlCenterPopout, x, y, width, section, screen);
            controlCenterPopout.open();
        }
    }

    function closeControlCenter() {
        if (closeIslandActivity("controlcenter"))
            return;
        controlCenterPopout?.close();
    }

    function unloadControlCenter() {
        _scheduleUnload("controlCenter");
    }

    function toggleControlCenter(x, y, width, section, screen) {
        if (routeToIsland("controlcenter", screen, true, section))
            return;
        if (controlCenterPopout) {
            setPosition(controlCenterPopout, x, y, width, section, screen);
            controlCenterPopout.toggle();
        }
    }

    function openNotificationCenter(x, y, width, section, screen) {
        if (routeToIsland("notificationcenter", screen, false))
            return;
        if (notificationCenterPopout) {
            setPosition(notificationCenterPopout, x, y, width, section, screen);
            notificationCenterPopout.open();
        }
    }

    function closeNotificationCenter() {
        if (closeIslandActivity("notificationcenter"))
            return;
        notificationCenterPopout?.close();
    }

    function unloadNotificationCenter() {
        _scheduleUnload("notificationCenter");
    }

    function toggleNotificationCenter(x, y, width, section, screen) {
        if (routeToIsland("notificationcenter", screen, true))
            return;
        if (notificationCenterPopout) {
            setPosition(notificationCenterPopout, x, y, width, section, screen);
            notificationCenterPopout.toggle();
        }
    }

    function openAppDrawer(x, y, width, section, screen) {
        if (appDrawerPopout) {
            setPosition(appDrawerPopout, x, y, width, section, screen);
            appDrawerPopout.open();
        }
    }

    function closeAppDrawer() {
        appDrawerPopout?.close();
    }

    function unloadAppDrawer() {
        _scheduleUnload("appDrawer");
    }

    function toggleAppDrawer(x, y, width, section, screen) {
        if (appDrawerPopout) {
            setPosition(appDrawerPopout, x, y, width, section, screen);
            appDrawerPopout.toggle();
        }
    }

    function openProcessList(x, y, width, section, screen) {
        if (processListPopout) {
            setPosition(processListPopout, x, y, width, section, screen);
            processListPopout.open();
        }
    }

    function closeProcessList() {
        processListPopout?.close();
    }

    function unloadProcessListPopout() {
        _scheduleUnload("processList");
    }

    function toggleProcessList(x, y, width, section, screen) {
        if (processListPopout) {
            setPosition(processListPopout, x, y, width, section, screen);
            processListPopout.toggle();
        }
    }

    property bool _advDashWantsOpen: false
    property bool _advDashWantsToggle: false
    property var _advDashPendingTab: 0
    property real _advDashPendingX: 0
    property real _advDashPendingY: 0
    property real _advDashPendingWidth: 0
    property string _advDashPendingSection: ""
    property var _advDashPendingScreen: null
    property bool _advDashHasPosition: false

    function _storeAdvDashPosition(x, y, width, section, screen, hasPos) {
        _advDashPendingX = x;
        _advDashPendingY = y;
        _advDashPendingWidth = width;
        _advDashPendingSection = section;
        _advDashPendingScreen = screen;
        _advDashHasPosition = hasPos;
    }

    // `tab` is a view id ("weather"); a numeric index into the visible tabs is
    // still accepted for plugin compatibility.
    function _advDashTabId(tab) {
        if (typeof tab === "string" && tab !== "")
            return tab;
        const ids = SettingsData.visibleDashTabIds();
        return ids[typeof tab === "number" ? tab : 0] ?? "overview";
    }

    function openAdvDash(tab, x, y, width, section, screen) {
        _advDashPendingTab = tab || 0;
        if (advDashPopout) {
            if (arguments.length >= 6)
                setPosition(advDashPopout, x, y, width, section, screen);
            advDashPopout.requestTab(_advDashTabId(_advDashPendingTab));
            advDashPopout.dashVisible = true;
            return;
        }
        if (!advDashPopoutLoader)
            return;
        _storeAdvDashPosition(x, y, width, section, screen, arguments.length >= 6);
        _advDashWantsOpen = true;
        _advDashWantsToggle = false;
        advDashPopoutLoader.active = true;
    }

    function closeAdvDash() {
        if (advDashPopout)
            advDashPopout.dashVisible = false;
    }

    function toggleAdvDash(tab, x, y, width, section, screen) {
        _advDashPendingTab = tab || 0;
        if (advDashPopout) {
            if (arguments.length >= 6)
                setPosition(advDashPopout, x, y, width, section, screen);
            if (advDashPopout.dashVisible) {
                advDashPopout.dashVisible = false;
            } else {
                advDashPopout.requestTab(_advDashTabId(_advDashPendingTab));
                advDashPopout.dashVisible = true;
            }
            return;
        }
        if (!advDashPopoutLoader)
            return;
        _storeAdvDashPosition(x, y, width, section, screen, arguments.length >= 6);
        _advDashWantsToggle = true;
        _advDashWantsOpen = false;
        advDashPopoutLoader.active = true;
    }

    function _onAdvDashPopoutLoaded() {
        if (!advDashPopout)
            return;

        if (_advDashHasPosition)
            setPosition(advDashPopout, _advDashPendingX, _advDashPendingY, _advDashPendingWidth, _advDashPendingSection, _advDashPendingScreen);

        if (_advDashWantsOpen) {
            _advDashWantsOpen = false;
            advDashPopout.requestTab(_advDashTabId(_advDashPendingTab));
            advDashPopout.dashVisible = true;
            return;
        }
        if (_advDashWantsToggle) {
            _advDashWantsToggle = false;
            if (advDashPopout.dashVisible) {
                advDashPopout.dashVisible = false;
            } else {
                advDashPopout.requestTab(_advDashTabId(_advDashPendingTab));
                advDashPopout.dashVisible = true;
            }
        }
    }

    function openBattery(x, y, width, section, screen) {
        if (batteryPopout) {
            setPosition(batteryPopout, x, y, width, section, screen);
            batteryPopout.open();
        }
    }

    function closeBattery() {
        batteryPopout?.close();
    }

    function unloadBattery() {
        _scheduleUnload("battery");
    }

    function toggleBattery(x, y, width, section, screen) {
        if (batteryPopout) {
            setPosition(batteryPopout, x, y, width, section, screen);
            batteryPopout.toggle();
        }
    }

    function openVpn(x, y, width, section, screen) {
        if (vpnPopout) {
            setPosition(vpnPopout, x, y, width, section, screen);
            vpnPopout.open();
        }
    }

    function closeVpn() {
        vpnPopout?.close();
    }

    function unloadVpn() {
        _scheduleUnload("vpn");
    }

    function toggleVpn(x, y, width, section, screen) {
        if (vpnPopout) {
            setPosition(vpnPopout, x, y, width, section, screen);
            vpnPopout.toggle();
        }
    }

    function openSystemUpdate(x, y, width, section, screen) {
        if (systemUpdatePopout) {
            if (arguments.length >= 5)
                setPosition(systemUpdatePopout, x, y, width, section, screen);
            systemUpdatePopout.open();
        }
    }

    function closeSystemUpdate() {
        systemUpdatePopout?.close();
    }

    function unloadSystemUpdate() {
        _scheduleUnload("systemUpdate");
    }

    function toggleSystemUpdate(x, y, width, section, screen) {
        if (systemUpdatePopout) {
            if (arguments.length >= 5)
                setPosition(systemUpdatePopout, x, y, width, section, screen);
            systemUpdatePopout.toggle();
        }
    }

    property bool _settingsWantsOpen: false
    property bool _settingsWantsToggle: false

    property string _settingsPendingTab: ""
    property int _settingsPendingTabIndex: -1

    property double _settingsShownAt: 0

    function _settingsWindowDead() {
        if (!settingsModal?.visible)
            return false;
        // toplevel registration is async; a freshly shown window looks dead
        if (Date.now() - _settingsShownAt < 2000)
            return false;
        const settingsTitle = I18n.tr("Settings", "settings window title");
        for (const toplevel of ToplevelManager.toplevels.values) {
            if (toplevel.title === "Settings" || toplevel.title === settingsTitle)
                return false;
        }
        return true;
    }

    function _rebuildDeadSettings() {
        settingsModal.visible = false;
        settingsModal = null;
        settingsModalLoader.active = false;
        _settingsWantsOpen = true;
        _settingsWantsToggle = false;
        Qt.callLater(() => {
            if (settingsModalLoader)
                settingsModalLoader.activeAsync = true;
        });
    }

    function openSettings() {
        if (settingsModal) {
            if (_settingsWindowDead()) {
                _rebuildDeadSettings();
                return;
            }
            settingsModal.show();
        } else if (settingsModalLoader) {
            _settingsWantsOpen = true;
            _settingsWantsToggle = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    property var _settingsReturnOrigin: null
    property var _settingsReturnReopen: null

    Connections {
        target: root.settingsModal
        function onClosingModal() {
            root._restoreSettingsOrigin();
        }
        function onVisibleChanged() {
            if (root.settingsModal?.visible)
                root._settingsShownAt = Date.now();
        }
    }

    function _restoreSettingsOrigin() {
        const origin = _settingsReturnOrigin;
        const reopen = _settingsReturnReopen;
        _settingsReturnOrigin = null;
        _settingsReturnReopen = null;
        if (!origin || !reopen)
            return;
        reopen();
    }

    function openSettingsWithTab(tabName: string, returnOrigin, reopen) {
        _settingsReturnOrigin = returnOrigin ?? null;
        _settingsReturnReopen = reopen ?? null;
        if (settingsModal) {
            if (_settingsWindowDead()) {
                _settingsPendingTab = tabName;
                _rebuildDeadSettings();
                return;
            }
            settingsModal.showWithTabName(tabName);
            return;
        }
        if (settingsModalLoader) {
            _settingsPendingTab = tabName;
            _settingsWantsOpen = true;
            _settingsWantsToggle = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function openSettingsWithTabIndex(tabIndex: int) {
        if (settingsModal) {
            if (_settingsWindowDead()) {
                _settingsPendingTabIndex = tabIndex;
                _rebuildDeadSettings();
                return;
            }
            settingsModal.showWithTab(tabIndex);
            return;
        }
        if (settingsModalLoader) {
            _settingsPendingTabIndex = tabIndex;
            _settingsWantsOpen = true;
            _settingsWantsToggle = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function closeSettings() {
        settingsModal?.hide();
    }

    function toggleSettings() {
        if (settingsModal) {
            settingsModal.toggle();
        } else if (settingsModalLoader) {
            _settingsWantsToggle = true;
            _settingsWantsOpen = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function toggleSettingsWithTab(tabName: string) {
        if (settingsModal) {
            var idx = settingsModal.resolveTabIndex(tabName);
            settingsModal.setTabIndex(idx);
            settingsModal.toggle();
            return;
        }
        if (settingsModalLoader) {
            _settingsPendingTab = tabName;
            _settingsWantsToggle = true;
            _settingsWantsOpen = false;
            settingsModalLoader.activeAsync = true;
        }
    }

    function focusOrToggleSettings() {
        if (settingsModal?.visible) {
            const settingsTitle = I18n.tr("Settings", "settings window title");
            for (const toplevel of ToplevelManager.toplevels.values) {
                if (toplevel.title !== "Settings" && toplevel.title !== settingsTitle)
                    continue;
                if (toplevel.activated) {
                    settingsModal.hide();
                    return;
                }
                CompositorService.activateToplevel(toplevel);
                return;
            }
        }
        openSettings();
    }

    function focusOrToggleSettingsWithTab(tabName: string) {
        if (settingsModal?.visible) {
            const settingsTitle = I18n.tr("Settings", "settings window title");
            for (const toplevel of ToplevelManager.toplevels.values) {
                if (toplevel.title !== "Settings" && toplevel.title !== settingsTitle)
                    continue;
                if (toplevel.activated) {
                    settingsModal.hide();
                    return;
                }
                var idx = settingsModal.resolveTabIndex(tabName);
                settingsModal.setTabIndex(idx);
                CompositorService.activateToplevel(toplevel);
                return;
            }
        }
        openSettingsWithTab(tabName);
    }

    function unloadSettingsNow() {
        if (!settingsModalLoader)
            return;
        if (settingsModal && settingsModal.visible)
            return;
        delete _pendingUnloads["settings"];
        settingsModal = null;
        settingsModalLoader.active = false;
    }

    function _onSettingsModalLoaded() {
        if (_settingsWantsOpen) {
            _settingsWantsOpen = false;
            if (_settingsPendingTabIndex >= 0) {
                settingsModal?.showWithTab(_settingsPendingTabIndex);
                _settingsPendingTabIndex = -1;
            } else if (_settingsPendingTab) {
                settingsModal?.showWithTabName(_settingsPendingTab);
                _settingsPendingTab = "";
            } else {
                settingsModal?.show();
            }
            return;
        }
        if (_settingsWantsToggle) {
            _settingsWantsToggle = false;
            if (_settingsPendingTabIndex >= 0) {
                settingsModal?.setTabIndex(_settingsPendingTabIndex);
                _settingsPendingTabIndex = -1;
            } else if (_settingsPendingTab) {
                var idx = settingsModal?.resolveTabIndex(_settingsPendingTab) ?? -1;
                settingsModal?.setTabIndex(idx);
                _settingsPendingTab = "";
            }
            settingsModal?.toggle();
        }
    }

    function openClipboardHistory() {
        clipboardHistoryModal?.show();
    }

    function closeClipboardHistory() {
        clipboardHistoryModal?.hide();
    }

    function unloadClipboardHistoryPopout() {
        _scheduleUnload("clipboardHistory");
    }

    function unloadLayoutPopout() {
        _scheduleUnload("layout");
    }

    property bool _advLauncherV2WantsOpen: false
    property bool _advLauncherV2WantsToggle: false
    property string _advLauncherV2PendingQuery: ""
    property string _advLauncherV2PendingMode: ""
    property bool _advLauncherV2TriggerUsesOverlayLayer: false
    property bool _advLauncherV2EdgeHoverManaged: false

    function _setAdvLauncherV2TriggerUsesOverlayLayer(value) {
        _advLauncherV2TriggerUsesOverlayLayer = value === true;
        // Disable edge-hover by default on every open/toggle path unless explicitly enabled.
        _setAdvLauncherV2EdgeHoverManaged(false);
        if (advLauncherV2Modal)
            advLauncherV2Modal.triggerUsesOverlayLayer = _advLauncherV2TriggerUsesOverlayLayer;
    }

    // Set edgeHoverManaged to enable hover retraction for edge-hover triggered launcher sessions.
    function _setAdvLauncherV2EdgeHoverManaged(value) {
        _advLauncherV2EdgeHoverManaged = value === true;
        if (advLauncherV2Modal)
            advLauncherV2Modal.edgeHoverManaged = _advLauncherV2EdgeHoverManaged;
    }

    function openAdvLauncherV2(triggerUsesOverlayLayer, edgeHoverManaged) {
        _setAdvLauncherV2TriggerUsesOverlayLayer(triggerUsesOverlayLayer);
        _setAdvLauncherV2EdgeHoverManaged(edgeHoverManaged);
        if (advLauncherV2Modal) {
            advLauncherV2Modal.show();
        } else if (advLauncherV2ModalLoader) {
            _advLauncherV2WantsOpen = true;
            _advLauncherV2WantsToggle = false;
            advLauncherV2ModalLoader.active = true;
        }
    }

    function openAdvLauncherV2WithQuery(query: string, triggerUsesOverlayLayer) {
        _setAdvLauncherV2TriggerUsesOverlayLayer(triggerUsesOverlayLayer);
        if (advLauncherV2Modal) {
            advLauncherV2Modal.showWithQuery(query);
        } else if (advLauncherV2ModalLoader) {
            _advLauncherV2PendingQuery = query;
            _advLauncherV2WantsOpen = true;
            _advLauncherV2WantsToggle = false;
            advLauncherV2ModalLoader.active = true;
        }
    }

    function openAdvLauncherV2WithMode(mode: string, triggerUsesOverlayLayer) {
        _setAdvLauncherV2TriggerUsesOverlayLayer(triggerUsesOverlayLayer);
        if (advLauncherV2Modal) {
            advLauncherV2Modal.showWithMode(mode);
        } else if (advLauncherV2ModalLoader) {
            _advLauncherV2PendingMode = mode;
            _advLauncherV2WantsOpen = true;
            _advLauncherV2WantsToggle = false;
            advLauncherV2ModalLoader.active = true;
        }
    }

    function closeAdvLauncherV2() {
        advLauncherV2Modal?.hide();
    }

    function unloadAdvLauncherV2() {
        if (advLauncherV2ModalLoader) {
            advLauncherV2Modal = null;
            advLauncherV2ModalLoader.active = false;
        }
    }

    function toggleAdvLauncherV2(triggerUsesOverlayLayer) {
        _setAdvLauncherV2TriggerUsesOverlayLayer(triggerUsesOverlayLayer);
        if (advLauncherV2Modal) {
            advLauncherV2Modal.toggle();
        } else if (advLauncherV2ModalLoader) {
            _advLauncherV2WantsToggle = true;
            _advLauncherV2WantsOpen = false;
            advLauncherV2ModalLoader.active = true;
        }
    }

    function toggleAdvLauncherV2WithMode(mode: string, triggerUsesOverlayLayer) {
        _setAdvLauncherV2TriggerUsesOverlayLayer(triggerUsesOverlayLayer);
        if (advLauncherV2Modal) {
            advLauncherV2Modal.toggleWithMode(mode);
        } else if (advLauncherV2ModalLoader) {
            _advLauncherV2PendingMode = mode;
            _advLauncherV2WantsToggle = true;
            _advLauncherV2WantsOpen = false;
            advLauncherV2ModalLoader.active = true;
        }
    }

    function toggleAdvLauncherV2WithQuery(query: string, triggerUsesOverlayLayer) {
        _setAdvLauncherV2TriggerUsesOverlayLayer(triggerUsesOverlayLayer);
        if (advLauncherV2Modal) {
            advLauncherV2Modal.toggleWithQuery(query);
        } else if (advLauncherV2ModalLoader) {
            _advLauncherV2PendingQuery = query;
            _advLauncherV2WantsOpen = true;
            _advLauncherV2WantsToggle = false;
            advLauncherV2ModalLoader.active = true;
        }
    }

    function _onAdvLauncherV2ModalLoaded() {
        if (advLauncherV2Modal) {
            advLauncherV2Modal.triggerUsesOverlayLayer = _advLauncherV2TriggerUsesOverlayLayer;
            advLauncherV2Modal.edgeHoverManaged = _advLauncherV2EdgeHoverManaged;
        }
        if (_advLauncherV2WantsOpen) {
            _advLauncherV2WantsOpen = false;
            if (_advLauncherV2PendingQuery) {
                advLauncherV2Modal?.showWithQuery(_advLauncherV2PendingQuery);
                _advLauncherV2PendingQuery = "";
            } else if (_advLauncherV2PendingMode) {
                advLauncherV2Modal?.showWithMode(_advLauncherV2PendingMode);
                _advLauncherV2PendingMode = "";
            } else {
                advLauncherV2Modal?.show();
            }
            return;
        }
        if (_advLauncherV2WantsToggle) {
            _advLauncherV2WantsToggle = false;
            if (_advLauncherV2PendingMode) {
                advLauncherV2Modal?.toggleWithMode(_advLauncherV2PendingMode);
                _advLauncherV2PendingMode = "";
            } else {
                advLauncherV2Modal?.toggle();
            }
        }
    }

    property bool _spotlightBarWantsOpen: false
    property bool _spotlightBarWantsToggle: false
    property string _spotlightBarPendingQuery: ""
    property string _spotlightBarPendingMode: ""

    function openSpotlightBar() {
        if (spotlightBarModal) {
            spotlightBarModal.show();
        } else if (spotlightBarModalLoader) {
            _spotlightBarWantsOpen = true;
            _spotlightBarWantsToggle = false;
            spotlightBarModalLoader.active = true;
        }
    }

    function openSpotlightBarWithQuery(query: string) {
        if (spotlightBarModal) {
            spotlightBarModal.showWithQuery(query);
        } else if (spotlightBarModalLoader) {
            _spotlightBarPendingQuery = query;
            _spotlightBarWantsOpen = true;
            _spotlightBarWantsToggle = false;
            spotlightBarModalLoader.active = true;
        }
    }

    function openSpotlightBarWithMode(mode: string) {
        if (spotlightBarModal) {
            spotlightBarModal.showWithMode(mode);
        } else if (spotlightBarModalLoader) {
            _spotlightBarPendingMode = mode;
            _spotlightBarWantsOpen = true;
            _spotlightBarWantsToggle = false;
            spotlightBarModalLoader.active = true;
        }
    }

    function closeSpotlightBar() {
        spotlightBarModal?.hide();
    }

    function toggleSpotlightBar() {
        if (spotlightBarModal) {
            spotlightBarModal.toggle();
        } else if (spotlightBarModalLoader) {
            _spotlightBarWantsToggle = true;
            _spotlightBarWantsOpen = false;
            spotlightBarModalLoader.active = true;
        }
    }

    function toggleSpotlightBarWithMode(mode: string) {
        if (spotlightBarModal) {
            spotlightBarModal.toggleWithMode(mode);
        } else if (spotlightBarModalLoader) {
            _spotlightBarPendingMode = mode;
            _spotlightBarWantsToggle = true;
            _spotlightBarWantsOpen = false;
            spotlightBarModalLoader.active = true;
        }
    }

    function toggleSpotlightBarWithQuery(query: string) {
        if (spotlightBarModal) {
            spotlightBarModal.toggleWithQuery(query);
        } else if (spotlightBarModalLoader) {
            _spotlightBarPendingQuery = query;
            _spotlightBarWantsOpen = true;
            _spotlightBarWantsToggle = false;
            spotlightBarModalLoader.active = true;
        }
    }

    function _onSpotlightBarModalLoaded() {
        if (_spotlightBarWantsOpen) {
            _spotlightBarWantsOpen = false;
            if (_spotlightBarPendingQuery) {
                spotlightBarModal?.showWithQuery(_spotlightBarPendingQuery);
                _spotlightBarPendingQuery = "";
            } else if (_spotlightBarPendingMode) {
                spotlightBarModal?.showWithMode(_spotlightBarPendingMode);
                _spotlightBarPendingMode = "";
            } else {
                spotlightBarModal?.show();
            }
            return;
        }
        if (_spotlightBarWantsToggle) {
            _spotlightBarWantsToggle = false;
            if (_spotlightBarPendingMode) {
                spotlightBarModal?.toggleWithMode(_spotlightBarPendingMode);
                _spotlightBarPendingMode = "";
            } else {
                spotlightBarModal?.toggle();
            }
        }
    }

    function openPowerMenu() {
        powerMenuModal?.openCentered();
    }

    function closePowerMenu() {
        powerMenuModal?.close();
    }

    function togglePowerMenu() {
        if (powerMenuModal) {
            if (powerMenuModal.shouldBeVisible) {
                powerMenuModal.close();
            } else {
                powerMenuModal.openCentered();
            }
        }
    }

    function openPowerProfileModal() {
        if (powerProfileModal) {
            powerProfileModal.openCentered();
        } else if (powerProfileModalLoader) {
            powerProfileModalLoader.active = true;
            Qt.callLater(() => powerProfileModal?.openCentered());
        }
    }

    function closePowerProfileModal() {
        powerProfileModal?.close();
    }

    function togglePowerProfileModal() {
        if (powerProfileModal) {
            if (powerProfileModal.shouldBeVisible) {
                powerProfileModal.close();
            } else {
                powerProfileModal.openCentered();
            }
        } else if (powerProfileModalLoader) {
            powerProfileModalLoader.active = true;
            Qt.callLater(() => {
                if (powerProfileModal) {
                    if (powerProfileModal.shouldBeVisible) {
                        powerProfileModal.close();
                    } else {
                        powerProfileModal.openCentered();
                    }
                }
            });
        }
    }

    function showProcessListModal() {
        if (processListModal) {
            processListModal.show();
        } else if (processListModalLoader) {
            processListModalLoader.active = true;
            Qt.callLater(() => processListModal?.show());
        }
    }

    function hideProcessListModal() {
        processListModal?.hide();
    }

    function unloadProcessListModal() {
        if (processListModalLoader) {
            processListModal = null;
            processListModalLoader.active = false;
        }
    }

    function toggleProcessListModal() {
        if (processListModal) {
            processListModal.toggle();
        } else if (processListModalLoader) {
            processListModalLoader.active = true;
            Qt.callLater(() => processListModal?.show());
        }
    }

    function showColorPicker() {
        colorPickerModal?.show();
    }

    function hideColorPicker() {
        colorPickerModal?.close();
    }

    function unloadColorPicker() {
        _scheduleUnload("colorPicker");
    }

    function unloadPowerMenuPopout() {
        _scheduleUnload("powerMenuPopout");
    }

    function ensureBluetoothPairingModal() {
        if (bluetoothPairingModal)
            return bluetoothPairingModal;
        if (!bluetoothPairingModalLoader)
            return null;
        bluetoothPairingModalLoader.active = true;
        return bluetoothPairingModalLoader.item;
    }

    function showNotificationModal() {
        notificationModal?.show();
    }

    function hideNotificationModal() {
        notificationModal?.close();
    }

    function showWifiPasswordModal(ssid) {
        if (wifiPasswordModalLoader)
            wifiPasswordModalLoader.active = true;
        if (wifiPasswordModal) {
            wifiPasswordModal.show(ssid);
        } else {
            Qt.callLater(() => wifiPasswordModal?.show(ssid));
        }
    }

    function showWifiQRCodeModal(ssid) {
        if (wifiQRCodeModalLoader)
            wifiQRCodeModalLoader.active = true;
        if (wifiQRCodeModal)
            wifiQRCodeModal.show(ssid);
    }

    function showQRGeneratorModal(initialText) {
        if (qrGeneratorModalLoader)
            qrGeneratorModalLoader.active = true;
        if (qrGeneratorModal)
            qrGeneratorModal.show(initialText || "");
    }

    function showHiddenNetworkModal() {
        if (wifiPasswordModalLoader)
            wifiPasswordModalLoader.active = true;
        if (wifiPasswordModal) {
            wifiPasswordModal.showHidden();
        } else {
            Qt.callLater(() => wifiPasswordModal?.showHidden());
        }
    }

    function hideWifiPasswordModal() {
        wifiPasswordModal?.hide();
    }

    function showNetworkInfoModal() {
        networkInfoModal?.show();
    }

    function hideNetworkInfoModal() {
        networkInfoModal?.close();
    }

    function closeNotepadSlideouts() {
        for (var i = 0; i < notepadSlideouts.length; i++) {
            if (notepadSlideouts[i] && notepadSlideouts[i].isVisible)
                notepadSlideouts[i].hide();
        }
    }

    function notepadSlideoutForFocusedScreen() {
        if (!notepadSlideouts || notepadSlideouts.length === 0)
            return null;
        const focused = BarWidgetService.getFocusedScreenName();
        if (focused) {
            for (var i = 0; i < notepadSlideouts.length; i++) {
                if (notepadSlideouts[i]?.modelData?.name === focused)
                    return notepadSlideouts[i];
            }
        }
        return notepadSlideouts[0];
    }

    // Remembered presentation wins over the configured default until the user
    // changes the default in settings (handled below).
    readonly property string notepadResolvedMode: SessionData.notepadLastMode || SettingsData.notepadDefaultMode

    function openNotepadSlideout() {
        SessionData.setNotepadLastMode("slideout");
        notepadPopout?.hide();
        if (notepadSlideouts.length > 0) {
            notepadSlideoutForFocusedScreen()?.show();
        }
    }

    // Keep the notepad in a single presentation for default modes
    Connections {
        target: SettingsData
        function onNotepadDefaultModeChanged() {
            SessionData.setNotepadLastMode(SettingsData.notepadDefaultMode);
            if (SettingsData.notepadDefaultMode === "popout") {
                var hadSlideout = false;
                for (var i = 0; i < root.notepadSlideouts.length; i++) {
                    if (root.notepadSlideouts[i] && root.notepadSlideouts[i].isVisible) {
                        hadSlideout = true;
                        root.notepadSlideouts[i].hide();
                    }
                }
                if (hadSlideout)
                    root.openNotepadPopout();
            } else if (root.notepadPopout && root.notepadPopout.visible) {
                root.notepadPopout.hide();
                root.openNotepadSlideout();
            }
        }
    }

    function openNotepad() {
        if (notepadResolvedMode === "popout") {
            openNotepadPopout();
            return;
        }
        openNotepadSlideout();
    }

    function closeNotepad() {
        if (notepadResolvedMode === "popout") {
            notepadPopout?.hide();
            return;
        }
        if (notepadSlideouts.length > 0) {
            notepadSlideoutForFocusedScreen()?.hide();
        }
    }

    function toggleNotepad() {
        if (notepadResolvedMode === "popout") {
            toggleNotepadPopout();
            return;
        }
        if (notepadSlideouts.length > 0) {
            notepadSlideoutForFocusedScreen()?.toggle();
        }
    }

    property var notepadPopout: null
    property var notepadPopoutLoader: null
    property bool _notepadPopoutWantsOpen: false
    property string _notepadPendingOpenFilePath: ""

    function openNotepadPopout() {
        SessionData.setNotepadLastMode("popout");
        closeNotepadSlideouts();
        if (notepadPopout) {
            notepadPopout.show();
        } else if (notepadPopoutLoader) {
            _notepadPopoutWantsOpen = true;
            notepadPopoutLoader.active = true;
        }
    }

    function openNotepadPopoutWithFile(path) {
        closeNotepadSlideouts();
        if (notepadPopout) {
            notepadPopout.show();
            notepadPopout.notepad?.openExternalFile(path);
        } else if (notepadPopoutLoader) {
            _notepadPendingOpenFilePath = path;
            _notepadPopoutWantsOpen = true;
            notepadPopoutLoader.active = true;
        }
    }

    function _onNotepadPopoutLoaded() {
        if (_notepadPopoutWantsOpen && notepadPopout) {
            _notepadPopoutWantsOpen = false;
            notepadPopout.show();
            if (_notepadPendingOpenFilePath) {
                const pendingPath = _notepadPendingOpenFilePath;
                _notepadPendingOpenFilePath = "";
                notepadPopout.notepad?.openExternalFile(pendingPath);
            }
        }
    }

    function toggleNotepadPopout() {
        if (notepadPopout) {
            if (!notepadPopout.visible)
                closeNotepadSlideouts();
            notepadPopout.toggle();
        } else {
            openNotepadPopout();
        }
    }
}
