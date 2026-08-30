//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_MEDIA_BACKEND=ffmpeg
//@ pragma Env QT_FFMPEG_DECODING_HW_DEVICE_TYPES=vaapi
//@ pragma Env QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=vaapi
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Material
//@ pragma UseQApplication
//@ pragma AppId dev.vchun.ariadnev

import QtQuick
import Quickshell
import qs.Common
import qs.AdvCommon.Common as DC
import qs.Modules
import qs.Services

ShellRoot {
    id: entrypoint

    readonly property bool runGreeter: Quickshell.env("ADVS_RUN_GREETER") === "1" || Quickshell.env("ADVS_RUN_GREETER") === "true"
    readonly property bool disableHotReload: Quickshell.env("ADVS_DISABLE_HOT_RELOAD") === "1" || Quickshell.env("ADVS_DISABLE_HOT_RELOAD") === "true"

    Component.onCompleted: {
        Quickshell.watchFiles = !disableHotReload;
        DC.Style.theme = Theme;
        DC.Style.settings = SettingsData;
        DC.I18n.backend = I18n;
        DC.Paths.backend = Paths;
        DC.Log.backend = Log;
        DC.Host.session = SessionService;
        DC.Host.cache = CacheData;
        if (entrypoint.runGreeter)
            return;
        // Build the polkit agent here, outside incubation: first-touching it from a Connections target during AriadnevShell's async load crashed QQmlConnections::connectSignalsToMethods.
        void PolkitService.agent;
    }

    Loader {
        id: wallpaperLoader
        active: !entrypoint.runGreeter
        asynchronous: false

        sourceComponent: Scope {
            WallpaperBackground {}

            Loader {
                active: SettingsData.blurredWallpaperLayer && CompositorService.isNiri
                asynchronous: false
                sourceComponent: BlurredWallpaperBackground {}
            }
        }
    }

    Loader {
        id: shellCoreLoader
        active: !entrypoint.runGreeter
        asynchronous: true
        source: "ShellCore.qml"
        onLoaded: advsShellLoader.setSource("AriadnevShell.qml", {
            core: item
        })
    }

    Loader {
        id: advsShellLoader
        asynchronous: true
    }

    Loader {
        id: advsGreeterLoader
        active: entrypoint.runGreeter
        asynchronous: false
        source: "AriadnevGreeter.qml"
    }
}
