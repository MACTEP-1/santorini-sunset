using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

class SantoriniSunsetApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }
    function onStart(state as Lang.Dictionary?) as Void {
    }
    function onStop(state as Lang.Dictionary?) as Void {
    }
    function getInitialView() as [ WatchUi.Views ] or [ WatchUi.Views, WatchUi.InputDelegates ] {
        return [ new SantoriniSunsetView() ];
    }
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
function getApp() as SantoriniSunsetApp {
    return Application.getApp() as SantoriniSunsetApp;
}
