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
        // WatchFaceInputDelegate (shared-src) wires up long-press-to-swap-
        // fields - see that file and SantoriniSunsetView.mc's
        // toggleAltFields().
        var view = new SantoriniSunsetView();
        return [ view, new WatchFaceInputDelegate(view) ];
    }
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
    // On-device "Customize" settings (hold the button in watch-face
    // selection mode) - see shared-src/SettingsMenu.mc for the full
    // explanation. SettingsMenu/SettingsDelegate now come from that
    // shared file (via monkey.jungle's sourcePath), not a per-project
    // class - class names dropped their "SantoriniSunset" prefix
    // accordingly.
    // Only applies to watch faces/data fields, which this is.
    function getSettingsView() as [ WatchUi.Views ] or [ WatchUi.Views, WatchUi.InputDelegates ] or Null {
        return [ new SettingsMenu(), new SettingsDelegate() ];
    }
}
function getApp() as SantoriniSunsetApp {
    return Application.getApp() as SantoriniSunsetApp;
}
