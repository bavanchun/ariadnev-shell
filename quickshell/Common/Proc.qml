pragma Singleton

import Quickshell
import qs.AdvCommon.Common as AdvCommon

Singleton {
    readonly property int noTimeout: AdvCommon.Proc.noTimeout
    readonly property string advsBin: AdvCommon.Proc.advsBin

    function runCommand(id, command, callback, debounceMs, timeoutMs, owner) {
        AdvCommon.Proc.runCommand(id, command, callback, debounceMs, timeoutMs, owner);
    }

    function release(id) {
        AdvCommon.Proc.release(id);
    }
}
