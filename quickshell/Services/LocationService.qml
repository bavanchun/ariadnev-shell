pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property bool wantsLocation: SettingsData.weatherEnabled && SettingsData.useAutoLocation
    readonly property bool locationAvailable: ADVSService.isConnected && ADVSService.capabilities.includes("location")
    readonly property bool valid: latitude !== 0 || longitude !== 0

    property var latitude: 0.0
    property var longitude: 0.0

    signal locationChanged(var data)

    onWantsLocationChanged: {
        if (wantsLocation) {
            ensureSubscription();
        } else if (ADVSService.activeSubscriptions.includes("location")) {
            ADVSService.removeSubscription("location");
        }
    }

    onLocationAvailableChanged: ensureSubscription()

    Component.onCompleted: ensureSubscription()

    Connections {
        target: ADVSService

        function onConnectionStateChanged() {
            if (ADVSService.isConnected)
                root.ensureSubscription();
        }

        function onLocationStateUpdate(data) {
            if (!root.wantsLocation)
                return;
            root.handleStateUpdate(data);
        }
    }

    function ensureSubscription() {
        if (!wantsLocation)
            return;
        if (!locationAvailable)
            return;
        if (ADVSService.activeSubscriptions.includes("location"))
            return;
        if (ADVSService.activeSubscriptions.includes("all"))
            return;

        ADVSService.addSubscription("location");
        if (!valid)
            getState();
    }

    function handleStateUpdate(data) {
        const lat = data.latitude;
        const lon = data.longitude;
        if (lat === 0 && lon === 0)
            return;

        root.latitude = lat;
        root.longitude = lon;
        root.locationChanged(data);
    }

    function getState() {
        if (!wantsLocation)
            return;
        if (!locationAvailable)
            return;

        ADVSService.sendRequest("location.getState", null, response => {
            if (response.result)
                handleStateUpdate(response.result);
        });
    }
}
