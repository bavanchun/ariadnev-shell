pragma Singleton

import QtQuick
import Quickshell
import qs.AdvCommon.Common as AdvCommon

Singleton {
    readonly property bool enabled: AdvCommon.ListViewTransitions.enabled
    readonly property Transition add: AdvCommon.ListViewTransitions.add
    readonly property Transition remove: AdvCommon.ListViewTransitions.remove
    readonly property Transition displaced: AdvCommon.ListViewTransitions.displaced
    readonly property Transition move: AdvCommon.ListViewTransitions.move
}
