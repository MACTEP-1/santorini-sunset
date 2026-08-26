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
    // On-device "Customize" settings (hold the button in watch-face
    // selection mode) - see SettingsMenu.mc for the full explanation.
    // Only applies to watch faces/data fields, which this is.
    function getSettingsView() as [ WatchUi.Views ] or [ WatchUi.Views, WatchUi.InputDelegates ] or Null {
        return [ new SantoriniSunsetSettingsMenu(), new SantoriniSunsetSettingsDelegate() ];
    }
}
function getApp() as SantoriniSunsetApp {
    return Application.getApp() as SantoriniSunsetApp;
}
