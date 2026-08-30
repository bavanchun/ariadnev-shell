pragma Singleton

import Quickshell
import qs.AdvCommon.Common as AdvCommon

Singleton {
    readonly property var rounding: AdvCommon.Appearance.rounding
    readonly property var spacing: AdvCommon.Appearance.spacing
    readonly property var fontSize: AdvCommon.Appearance.fontSize
    readonly property var anim: AdvCommon.Appearance.anim
}
