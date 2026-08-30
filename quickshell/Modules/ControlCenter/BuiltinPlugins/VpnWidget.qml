import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Details
import qs.Modules.Plugins

PluginComponent {
    id: root

    Ref {
        service: ADVSNetworkService
    }

    readonly property bool vpnActivating: ADVSNetworkService.vpnIsBusy || ADVSNetworkService.activeState === "activating"
    readonly property bool vpnActivated: ADVSNetworkService.connected && ADVSNetworkService.activeState === "activated"

    ccWidgetIcon: "vpn_key"
    ccWidgetPrimaryText: I18n.tr("VPN")
    ccWidgetSecondaryText: {
        if (vpnActivating)
            return I18n.tr("Connecting...");
        if (!vpnActivated)
            return I18n.tr("Disconnected");
        const names = ADVSNetworkService.activeNames || [];
        if (names.length <= 1)
            return names[0] || I18n.tr("Connected");
        return names[0] + " +" + (names.length - 1);
    }
    ccWidgetIsActive: vpnActivated

    onCcWidgetToggled: ADVSNetworkService.toggleVpn()

    ccDetailContent: Component {
        VpnDetailContent {
            listHeight: 260
        }
    }
}
