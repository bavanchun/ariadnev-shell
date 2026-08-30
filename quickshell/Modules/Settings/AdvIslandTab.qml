pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Modules.Settings.Widgets
import qs.Services
import qs.Widgets

Item {
    id: root

    property var parentModal: null
    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property var instanceChoices: {
        SettingsData.barConfigs;
        SettingsData.advIslandBarId;
        const rows = [({
                    "id": "",
                    "name": I18n.tr("Off", "island instance choice: island disabled")
                })];
        const configs = SettingsData.barConfigs || [];
        for (let i = 0; i < configs.length; i++)
            rows.push({
                "id": configs[i].id,
                "name": configs[i].name || I18n.tr("Bar %1", "island instance choice: unnamed bar, %1 is its number").arg(i + 1)
            });
        return rows;
    }
    readonly property int instanceIndex: Math.max(0, root.instanceChoices.findIndex(row => row.id === SettingsData.advIslandBarId))
    readonly property var homeSlotValues: ["left", "right", "hidden"]
    readonly property var paletteValues: ["default", "bright", "dim"]
    readonly property var batteryStyleValues: ["solid", "outline"]
    readonly property var satellitePositionValues: ["island", "edges"]
    readonly property var interactionModeValues: ["click", "hybrid"]

    function valueIndex(values, value, fallback) {
        const index = values.indexOf(value);
        return index >= 0 ? index : Math.max(0, values.indexOf(fallback));
    }

    AdvFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: mainColumn.height + Theme.spacingXL
        contentWidth: width

        Column {
            id: mainColumn

            topPadding: Theme.spacingXS
            width: Math.min(550, parent.width - Theme.spacingL * 2)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingXL

            SettingsCard {
                width: parent.width
                iconName: "view_in_ar"
                title: I18n.tr("Adv Island - Beta", "island settings: page title")
                settingKey: "advIslandInstance"

                SettingsButtonGroupRow {
                    settingKey: "advIslandBarId"
                    tags: ["island", "activities", "media", "notifications", "osd", "bar"]
                    text: I18n.tr("Island Instance", "island settings: which bar config the island replaces")
                    model: root.instanceChoices.map(row => row.name)
                    currentIndex: root.instanceIndex
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("advIslandBarId", root.instanceChoices[index]?.id ?? "");
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "open_with"
                title: I18n.tr("Position", "island settings: position card title")
                settingKey: "advIslandPlacement"
                enabled: SettingsData.advIslandEnabled

                SettingsToggleRow {
                    settingKey: "advIslandFloating"
                    tags: ["island", "placement", "float", "overlay", "exclusive", "reserve"]
                    text: I18n.tr("Float", "island settings: float toggle")
                    description: I18n.tr("Floats above windows and other content", "island settings: float toggle description")
                    checked: SettingsData.advIslandFloating
                    onToggled: checked => SettingsData.set("advIslandFloating", checked)
                }

                SettingsToggleRow {
                    settingKey: "advIslandUseOverlayLayer"
                    tags: ["island", "fullscreen", "overlay", "layer"]
                    text: I18n.tr("Use Overlay Layer", "island layer toggle: use Wayland overlay layer")
                    description: I18n.tr("Stage the Wayland overlay layer to remain visible over fullscreen apps", "island settings: overlay layer description")
                    checked: SettingsData.advIslandUseOverlayLayer
                    onToggled: checked => SettingsData.set("advIslandUseOverlayLayer", checked)
                }

                SettingsSliderRow {
                    settingKey: "advIslandReserveHeight"
                    tags: ["island", "placement", "reservation", "exclusive", "height"]
                    text: I18n.tr("Reserved Height", "island settings: reserved strip height slider")
                    description: I18n.tr("Space kept clear for compact island and satellites", "island settings: reserved height description")
                    unit: "px"
                    minimum: 24
                    maximum: 128
                    step: 1
                    defaultValue: 40
                    value: SettingsData.advIslandReserveHeight
                    enabled: !SettingsData.advIslandFloating
                    onSliderValueChanged: value => SettingsData.set("advIslandReserveHeight", value)
                }

                SettingsSliderRow {
                    settingKey: "advIslandCompactHeight"
                    tags: ["island", "placement", "compact", "height", "size", "satellite"]
                    text: I18n.tr("Compact Island Height", "island settings: compact pill height slider")
                    description: I18n.tr("Resize the resting island to align with nearby widgets", "island settings: compact height description")
                    unit: "px"
                    minimum: 24
                    maximum: 72
                    step: 1
                    defaultValue: 38
                    value: SettingsData.advIslandCompactHeight
                    onSliderValueChanged: value => SettingsData.set("advIslandCompactHeight", value)
                }

                SettingsSliderRow {
                    settingKey: "advIslandOuterGap"
                    tags: ["island", "placement", "gap", "top", "margin"]
                    text: I18n.tr("Outer Gaps", "island settings: gap between screen edge and island")
                    description: I18n.tr("Distance between display edge and island", "island settings: outer gap description")
                    unit: "px"
                    minimum: 0
                    maximum: 48
                    step: 1
                    defaultValue: 4
                    value: SettingsData.advIslandOuterGap
                    onSliderValueChanged: value => SettingsData.set("advIslandOuterGap", value)
                }

                SettingsSliderRow {
                    settingKey: "advIslandHorizontalOffset"
                    tags: ["island", "placement", "horizontal", "offset", "center"]
                    text: I18n.tr("Horizontal Offset", "island settings: horizontal offset slider")
                    description: I18n.tr("Move island and satellites left or right from display center", "island settings: horizontal offset description")
                    unit: "px"
                    minimum: -600
                    maximum: 600
                    step: 1
                    defaultValue: 0
                    value: SettingsData.advIslandHorizontalOffset
                    onSliderValueChanged: value => SettingsData.set("advIslandHorizontalOffset", value)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "home"
                title: I18n.tr("Home Compact", "island settings: home face card title")
                settingKey: "advIslandActivities"
                enabled: SettingsData.advIslandEnabled

                StyledText {
                    width: parent.width
                    text: I18n.tr("Choose which shortcuts sit left or right of the clock", "island settings: home face slot hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                SettingsButtonGroupRow {
                    settingKey: "advIslandHomeMediaSlot"
                    tags: ["island", "home", "compact", "media", "launcher", "search", "cava"]
                    text: I18n.tr("Media / Launcher", "island settings: media or launcher slot row")
                    description: I18n.tr("Search when idle, visualizer when media is playing", "island settings: media slot description")
                    model: [I18n.tr("Left", "island settings: media or launcher slot left of the clock"), I18n.tr("Right", "island settings: media or launcher slot right of the clock"), I18n.tr("Hidden", "island settings: media or launcher slot hidden")]
                    currentIndex: root.valueIndex(root.homeSlotValues, SettingsData.advIslandHomeMediaSlot, "left")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("advIslandHomeMediaSlot", root.homeSlotValues[index] ?? "left");
                    }
                }

                SettingsButtonGroupRow {
                    settingKey: "advIslandHomeStatusSlot"
                    tags: ["island", "home", "compact", "battery", "control center", "tools"]
                    text: I18n.tr("Battery / Control Center", "island settings: battery or control center slot row")
                    description: BatteryService.batteryAvailable ? I18n.tr("Battery gauge opens Control Center", "island settings: status slot description with battery") : I18n.tr("Tools icon opens Control Center", "island settings: status slot description without battery")
                    model: [I18n.tr("Left", "island settings: battery or control center slot left of the clock"), I18n.tr("Right", "island settings: battery or control center slot right of the clock"), I18n.tr("Hidden", "island settings: battery or control center slot hidden")]
                    currentIndex: root.valueIndex(root.homeSlotValues, SettingsData.advIslandHomeStatusSlot, "hidden")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("advIslandHomeStatusSlot", root.homeSlotValues[index] ?? "hidden");
                    }
                }

                SettingsButtonGroupRow {
                    settingKey: "advIslandHomeWeatherSlot"
                    tags: ["island", "home", "compact", "weather", "forecast"]
                    text: I18n.tr("Weather", "island settings: weather slot row")
                    description: SettingsData.weatherEnabled ? I18n.tr("Weather icon and temperature open the weather activity", "island settings: weather slot description") : I18n.tr("Enable weather in Time & Weather to show this shortcut", "island settings: weather slot disabled hint")
                    model: [I18n.tr("Left", "island settings: weather slot left of the clock"), I18n.tr("Right", "island settings: weather slot right of the clock"), I18n.tr("Hidden", "island settings: weather slot hidden")]
                    currentIndex: root.valueIndex(root.homeSlotValues, SettingsData.advIslandHomeWeatherSlot, "hidden")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("advIslandHomeWeatherSlot", root.homeSlotValues[index] ?? "hidden");
                    }
                }

                SettingsToggleRow {
                    settingKey: "advIslandHomeCompactTight"
                    tags: ["island", "home", "compact", "narrow", "width", "height", "clock"]
                    text: I18n.tr("Compact Clock Pill", "island settings: tighter home pill toggle")
                    description: I18n.tr("Compact home clock pill in both width and height", "island settings: tight pill description")
                    checked: SettingsData.advIslandHomeCompactTight
                    onToggled: checked => SettingsData.set("advIslandHomeCompactTight", checked)
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingS

                    AdvButton {
                        text: I18n.tr("Launcher", "island settings: button to launcher tab")
                        iconName: "grid_view"
                        onClicked: {
                            if (!root.parentModal)
                                return;
                            SettingsSearchService.navigateToSection("launcherStyle");
                            root.parentModal.showWithTabName("launcher");
                        }
                    }

                    AdvButton {
                        text: I18n.tr("Time & Weather", "island settings: button to weather tab")
                        iconName: "cloud"
                        onClicked: {
                            if (!root.parentModal)
                                return;
                            SettingsSearchService.navigateToSection("weatherEnabled");
                            root.parentModal.showWithTabName("time_weather");
                        }
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "palette"
                title: I18n.tr("Appearance", "island settings: appearance card title")
                settingKey: "advIslandAppearance"
                enabled: SettingsData.advIslandEnabled

                SettingsButtonGroupRow {
                    settingKey: "advIslandPalette"
                    tags: ["island", "appearance", "palette", "surface", "bright", "dim"]
                    text: I18n.tr("Palette", "island settings: surface tone choice")
                    model: [I18n.tr("Default", "island settings: default surface tone"), I18n.tr("Bright", "island settings: bright surface tone"), I18n.tr("Dim", "island settings: dim surface tone")]
                    currentIndex: root.valueIndex(root.paletteValues, SettingsData.advIslandPalette, "default")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("advIslandPalette", root.paletteValues[index] ?? "default");
                    }
                }

                SettingsSliderRow {
                    settingKey: "advIslandTransparency"
                    tags: ["island", "appearance", "surface", "opacity", "transparency", "blur"]
                    text: I18n.tr("Opacity", "island settings: island surface opacity slider")
                    unit: "%"
                    minimum: 0
                    maximum: 100
                    step: 1
                    defaultValue: 100
                    value: Math.round(SettingsData.advIslandTransparency * 100)
                    onSliderValueChanged: value => SettingsData.set("advIslandTransparency", value / 100)
                }

                SettingsToggleRow {
                    settingKey: "advIslandHighContrast"
                    tags: ["island", "appearance", "contrast", "accessibility", "outline"]
                    text: I18n.tr("High Contrast", "island settings: high contrast toggle")
                    description: I18n.tr("Draw an outline and use the highest-contrast surface tone", "island settings: high contrast description")
                    checked: SettingsData.advIslandHighContrast
                    onToggled: checked => SettingsData.set("advIslandHighContrast", checked)
                }

                SettingsToggleRow {
                    settingKey: "advIslandMediaClockVisible"
                    tags: ["island", "media", "clock", "compact", "time"]
                    text: I18n.tr("Keep Clock with Media", "island settings: clock in media face toggle")
                    description: I18n.tr("Show a clickable clock beside compact media details", "island settings: media clock description")
                    checked: SettingsData.advIslandMediaClockVisible
                    onToggled: checked => SettingsData.set("advIslandMediaClockVisible", checked)
                }

                SettingsButtonGroupRow {
                    settingKey: "advIslandBatteryStyle"
                    tags: ["island", "battery", "gauge", "solid", "outline", "appearance"]
                    text: I18n.tr("Material Battery Style", "island settings: battery meter style row")
                    description: I18n.tr("Solid material type or Outline", "island settings: battery style description")
                    visible: BatteryService.batteryAvailable
                    model: [I18n.tr("Solid", "island settings: filled battery meter style"), I18n.tr("Outline", "island settings: outlined battery meter style")]
                    currentIndex: root.valueIndex(root.batteryStyleValues, SettingsData.advIslandBatteryStyle, "solid")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("advIslandBatteryStyle", root.batteryStyleValues[index] ?? "solid");
                    }
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "notifications"
                title: I18n.tr("Notifications", "island settings: notifications card title")
                settingKey: "advIslandNotifications"
                enabled: SettingsData.advIslandEnabled

                SettingsToggleRow {
                    settingKey: "advIslandNotificationExpand"
                    tags: ["island", "notifications", "expand", "arrival", "size"]
                    text: I18n.tr("Expand Notifications", "island settings: expanded notification toggle")
                    description: I18n.tr("Expand notifications by default instead of click or hover", "island settings: expanded notification description")
                    checked: SettingsData.advIslandNotificationExpand
                    onToggled: checked => SettingsData.set("advIslandNotificationExpand", checked)
                }

                SettingsToggleRow {
                    settingKey: "advIslandHomeNotificationBadge"
                    tags: ["island", "home", "notifications", "badge", "unread", "count"]
                    text: I18n.tr("Show Badge", "island settings: unread notification count on the home face")
                    description: I18n.tr("Unread notification count beside the clock", "island settings: notification badge description")
                    checked: SettingsData.advIslandHomeNotificationBadge
                    onToggled: checked => SettingsData.set("advIslandHomeNotificationBadge", checked)
                }

                SettingsToggleRow {
                    settingKey: "advIslandNotificationBadgeClearOnOpen"
                    tags: ["island", "home", "notifications", "badge", "unread", "clear", "dismiss", "open"]
                    text: I18n.tr("Clear Badge on Open", "island settings: clear the notification badge when the center opens")
                    description: I18n.tr("Clears the badge on open but keeps notifications active", "island settings: clear badge on open description")
                    checked: SettingsData.advIslandNotificationBadgeClearOnOpen
                    enabled: SettingsData.advIslandHomeNotificationBadge
                    onToggled: checked => SettingsData.set("advIslandNotificationBadgeClearOnOpen", checked)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "widgets"
                title: I18n.tr("Satellite Widgets", "island settings: satellite widgets card title")
                settingKey: "advIslandSatellites"
                collapsible: true
                expanded: true
                enabled: SettingsData.advIslandEnabled

                SettingsToggleRow {
                    settingKey: "advIslandSatellitesEnabled"
                    tags: ["island", "satellite", "widgets", "left", "right"]
                    text: I18n.tr("Show Satellite Widgets", "island settings: satellite widgets toggle")
                    description: I18n.tr("Place independent widgets to left and right of island", "island settings: satellite widgets description")
                    checked: SettingsData.advIslandSatellitesEnabled
                    onToggled: checked => SettingsData.set("advIslandSatellitesEnabled", checked)
                }

                SettingsToggleRow {
                    settingKey: "advIslandSatelliteBackground"
                    tags: ["island", "satellite", "widgets", "background", "chrome"]
                    text: I18n.tr("Background", "island settings: satellite background toggle")
                    description: I18n.tr("Draw an island-styled background behind satellite widgets", "island settings: satellite background description")
                    checked: SettingsData.advIslandSatelliteBackground
                    enabled: SettingsData.advIslandSatellitesEnabled
                    onToggled: checked => SettingsData.set("advIslandSatelliteBackground", checked)
                }

                SettingsToggleRow {
                    settingKey: "advIslandSatelliteGothCorners"
                    tags: ["island", "satellite", "goth", "corners", "wing", "sweep"]
                    text: I18n.tr("Goth Corners", "island settings: satellite goth corners toggle")
                    description: I18n.tr("Sweep the background into the screen edges", "island settings: satellite goth corners description")
                    checked: SettingsData.advIslandSatelliteGothCorners
                    enabled: SettingsData.advIslandSatellitesEnabled && SettingsData.advIslandSatelliteBackground
                    onToggled: checked => SettingsData.set("advIslandSatelliteGothCorners", checked)
                }

                SettingsSliderRow {
                    settingKey: "advIslandSatelliteSwoopRadius"
                    tags: ["island", "satellite", "goth", "corners", "radius", "sweep", "size"]
                    text: I18n.tr("Corner Radius", "island settings: satellite goth corner radius slider")
                    unit: "px"
                    minimum: 4
                    maximum: 64
                    step: 1
                    defaultValue: 24
                    value: SettingsData.advIslandSatelliteSwoopRadius
                    enabled: SettingsData.advIslandSatellitesEnabled && SettingsData.advIslandSatelliteBackground && SettingsData.advIslandSatelliteGothCorners
                    onSliderValueChanged: value => SettingsData.set("advIslandSatelliteSwoopRadius", value)
                }

                SettingsSliderRow {
                    settingKey: "advIslandSatelliteTransparency"
                    tags: ["island", "satellite", "background", "opacity", "transparency", "blur"]
                    text: I18n.tr("Opacity", "island settings: satellite background opacity slider")
                    unit: "%"
                    minimum: 0
                    maximum: 100
                    step: 1
                    defaultValue: 100
                    value: Math.round(SettingsData.advIslandSatelliteTransparency * 100)
                    enabled: SettingsData.advIslandSatellitesEnabled && SettingsData.advIslandSatelliteBackground
                    onSliderValueChanged: value => SettingsData.set("advIslandSatelliteTransparency", value / 100)
                }

                SettingsButtonGroupRow {
                    settingKey: "advIslandSatellitePosition"
                    tags: ["island", "satellite", "widgets", "position", "edges", "center"]
                    text: I18n.tr("Position", "island settings: position card title")
                    description: I18n.tr("Keep widgets beside the island or align them like a standalone bar", "island settings: satellite position description")
                    model: [I18n.tr("Near Island", "island settings: satellites hug the island"), I18n.tr("Screen Edges", "island settings: satellites sit at screen edges")]
                    currentIndex: root.valueIndex(root.satellitePositionValues, SettingsData.advIslandSatellitePosition, "island")
                    enabled: SettingsData.advIslandSatellitesEnabled
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("advIslandSatellitePosition", root.satellitePositionValues[index] ?? "island");
                    }
                }

                SettingsSliderRow {
                    settingKey: "advIslandSatelliteGap"
                    tags: ["island", "satellite", "widgets", "gap", "spacing"]
                    text: I18n.tr("Island Gap", "island settings: satellite to island gap slider")
                    unit: "px"
                    minimum: 4
                    maximum: 48
                    step: 1
                    defaultValue: 12
                    value: SettingsData.advIslandSatelliteGap
                    enabled: SettingsData.advIslandSatellitesEnabled && SettingsData.advIslandSatellitePosition !== "edges"
                    onSliderValueChanged: value => SettingsData.set("advIslandSatelliteGap", value)
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Satellites widget to place left or right of the island", "island settings: satellite widgets hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    visible: SettingsData.advIslandSatellitesEnabled
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "touch_app"
                title: I18n.tr("Behavior", "island settings: behavior card title")
                settingKey: "advIslandInteraction"
                enabled: SettingsData.advIslandEnabled

                SettingsButtonGroupRow {
                    settingKey: "advIslandInteractionMode"
                    tags: ["island", "interaction", "click", "hybrid", "expand"]
                    text: I18n.tr("Expansion Mode", "island settings: click or hover expansion row")
                    description: I18n.tr("Click expands only on an intentional press. Hybrid peeks the current compact face on hover", "island settings: expansion mode description")
                    model: [I18n.tr("Click", "island settings: click expansion mode"), I18n.tr("Hybrid", "island settings: hover plus click expansion mode")]
                    currentIndex: root.valueIndex(root.interactionModeValues, SettingsData.advIslandInteractionMode, "hybrid")
                    onSelectionChanged: (index, selected) => {
                        if (selected)
                            SettingsData.set("advIslandInteractionMode", root.interactionModeValues[index] ?? "hybrid");
                    }
                }

                StyledText {
                    width: parent.width
                    text: I18n.tr("Hybrid peeks the current compact face on hover. Click pins a destination so it stays open", "island settings: hybrid mode hint")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    visible: SettingsData.advIslandInteractionMode !== "click"
                }

                SettingsSliderRow {
                    settingKey: "advIslandHoverOpenDelay"
                    tags: ["island", "interaction", "hover", "open", "delay"]
                    text: I18n.tr("Open Delay", "island settings: hover open delay slider")
                    unit: "ms"
                    minimum: 0
                    maximum: 1000
                    step: 10
                    defaultValue: 150
                    value: SettingsData.advIslandHoverOpenDelay
                    enabled: SettingsData.advIslandInteractionMode !== "click"
                    onSliderValueChanged: value => SettingsData.set("advIslandHoverOpenDelay", value)
                }

                SettingsSliderRow {
                    settingKey: "advIslandHoverCloseDelay"
                    tags: ["island", "interaction", "hover", "close", "delay"]
                    text: I18n.tr("Hide Delay", "island settings: hover hide delay slider")
                    unit: "ms"
                    minimum: 0
                    maximum: 1000
                    step: 10
                    defaultValue: 150
                    value: SettingsData.advIslandHoverCloseDelay
                    enabled: SettingsData.advIslandInteractionMode !== "click"
                    onSliderValueChanged: value => SettingsData.set("advIslandHoverCloseDelay", value)
                }
            }

            SettingsCard {
                width: parent.width
                iconName: "animation"
                title: I18n.tr("Motion & Accessibility", "island settings: motion card title")
                settingKey: "advIslandMotion"
                collapsible: true
                enabled: SettingsData.advIslandEnabled

                SettingsToggleRow {
                    settingKey: "advIslandReducedMotion"
                    tags: ["island", "motion", "animation", "reduce", "accessibility", "spring"]
                    text: I18n.tr("Reduce Motion", "island settings: reduce motion toggle")
                    description: I18n.tr("Apply island geometry changes immediately without spring overshoot", "island settings: reduce motion description")
                    checked: SettingsData.advIslandReducedMotion
                    onToggled: checked => SettingsData.set("advIslandReducedMotion", checked)
                }

                SettingsSliderRow {
                    settingKey: "advIslandSpringStiffness"
                    tags: ["island", "motion", "spring", "stiffness", "animation"]
                    text: I18n.tr("Spring Stiffness", "island settings: spring stiffness slider")
                    description: I18n.tr("Higher values pull island toward its target more strongly", "island settings: stiffness description")
                    minimum: 100
                    maximum: 1200
                    step: 10
                    value: Math.round(SettingsData.advIslandSpringStiffness)
                    defaultValue: 560
                    enabled: !SettingsData.advIslandReducedMotion
                    onSliderValueChanged: value => SettingsData.set("advIslandSpringStiffness", value)
                }

                SettingsSliderRow {
                    settingKey: "advIslandSpringDamping"
                    tags: ["island", "motion", "spring", "damping", "bounce", "animation"]
                    text: I18n.tr("Spring Damping", "island settings: spring damping slider")
                    description: I18n.tr("Higher values settle island with less bounce", "island settings: damping description")
                    minimum: 10
                    maximum: 100
                    step: 1
                    value: Math.round(SettingsData.advIslandSpringDamping)
                    defaultValue: 37
                    enabled: !SettingsData.advIslandReducedMotion
                    onSliderValueChanged: value => SettingsData.set("advIslandSpringDamping", value)
                }

                SettingsSliderRow {
                    settingKey: "advIslandSpringMass"
                    tags: ["island", "motion", "spring", "mass", "inertia", "animation"]
                    text: I18n.tr("Spring Mass", "island settings: spring mass slider")
                    description: I18n.tr("Higher percentages give island more inertia", "island settings: mass description")
                    minimum: 25
                    maximum: 300
                    step: 5
                    unit: "%"
                    value: Math.round(SettingsData.advIslandSpringMass * 100)
                    defaultValue: 100
                    enabled: !SettingsData.advIslandReducedMotion
                    onSliderValueChanged: value => SettingsData.set("advIslandSpringMass", value / 100)
                }
            }
        }
    }
}
