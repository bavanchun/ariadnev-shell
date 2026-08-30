pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.AdvBar
import qs.Services

// Renders the bar(s) inside the frame surface in connected mode: one AdvBarBody per
// active bar edge, positioned in the frame's cutout band. Reuses the existing AdvBar
// item (per bar config) as rootWindow so colour-picker, overview loader and widget
// models are shared with the standalone path.
Item {
    id: host

    required property var frameWindow
    required property var targetScreen

    readonly property string screenName: targetScreen ? targetScreen.name : ""

    readonly property var barSlots: {
        SettingsData.barConfigs;
        const out = [];
        const configs = SettingsData.barConfigs || [];
        for (let i = 0; i < configs.length; i++) {
            const bc = configs[i];
            if (!bc.enabled || (bc.useOverlayLayer ?? false))
                continue;
            if (!SettingsData.barConfigCoversScreen(bc, host.targetScreen))
                continue;
            if (SettingsData.isIslandBarConfig(bc))
                continue;
            if (SettingsData.advIslandOwnsEdge(host.targetScreen, SettingsData.positionToSide(bc.position ?? SettingsData.Position.Top)))
                continue;
            let edge = "top";
            switch (bc.position ?? 0) {
            case SettingsData.Position.Bottom:
                edge = "bottom";
                break;
            case SettingsData.Position.Left:
                edge = "left";
                break;
            case SettingsData.Position.Right:
                edge = "right";
                break;
            }
            out.push({
                "barId": bc.id,
                "edge": edge
            });
        }
        // Horizontal bars own the corners, so render them last (on top) — their edge widget
        // must receive the corner click over the vertical bar's hover area beneath it.
        out.sort((a, b) => {
            const rank = e => (e === "left" || e === "right") ? 0 : 1;
            return rank(a.edge) - rank(b.edge);
        });
        return out;
    }

    Repeater {
        model: host.barSlots

        delegate: Item {
            id: slot

            required property var modelData

            readonly property string edge: modelData.edge
            readonly property var advBarItem: BarWidgetService.advBarItems[modelData.barId] ?? null
            readonly property var slotBarConfig: advBarItem?.barConfig ?? SettingsData.getBarConfig(modelData.barId)

            // Each bar spans its full edge (matching the standalone window extent) so
            // AdvBarContent's own adjacency margins inset it, rather than double-insetting
            // against a pre-carved strip.
            x: edge === "right" ? host.frameWindow._windowRegionWidth - host.frameWindow.cutoutRightInset : 0
            y: edge === "bottom" ? host.frameWindow._windowRegionHeight - host.frameWindow.cutoutBottomInset : 0
            width: {
                switch (edge) {
                case "left":
                    return host.frameWindow.cutoutLeftInset;
                case "right":
                    return host.frameWindow.cutoutRightInset;
                default:
                    return host.frameWindow._windowRegionWidth;
                }
            }
            height: {
                switch (edge) {
                case "top":
                    return host.frameWindow.cutoutTopInset;
                case "bottom":
                    return host.frameWindow.cutoutBottomInset;
                default:
                    return host.frameWindow._windowRegionHeight;
                }
            }

            Loader {
                anchors.fill: parent
                active: slot.advBarItem !== null && slot.slotBarConfig !== null

                sourceComponent: AdvBarBody {
                    hostWindow: host.frameWindow
                    modelData: host.targetScreen
                    rootWindow: slot.advBarItem
                    barConfig: slot.slotBarConfig
                    leftWidgetsModel: slot.advBarItem?.leftWidgetsModel ?? null
                    centerWidgetsModel: slot.advBarItem?.centerWidgetsModel ?? null
                    rightWidgetsModel: slot.advBarItem?.rightWidgetsModel ?? null

                    Component.onCompleted: BarWidgetService.registerFrameBar(host.screenName, this)
                    Component.onDestruction: BarWidgetService.unregisterFrameBar(host.screenName, this)
                }
            }
        }
    }
}
