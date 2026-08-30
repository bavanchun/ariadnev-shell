import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

AdvOSD {
    id: root

    osdWidth: Theme.iconSize + Theme.spacingS * 2
    osdHeight: Theme.iconSize + Theme.spacingS * 2
    autoHideInterval: 2000
    enableMouseInteraction: false

    property bool lastCapsLockState: false

    Connections {
        target: ADVSService

        function onCapsLockStateChanged() {
            if (lastCapsLockState !== ADVSService.capsLockState && SettingsData.osdCapsLockEnabled) {
                root.show()
            }
            lastCapsLockState = ADVSService.capsLockState
        }
    }

    Component.onCompleted: {
        lastCapsLockState = ADVSService.capsLockState
    }

    content: AdvIcon {
        anchors.centerIn: parent
        name: ADVSService.capsLockState ? "shift_lock" : "shift_lock_off"
        size: Theme.iconSize
        color: Theme.primary
    }
}
