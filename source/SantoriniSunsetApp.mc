using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

// App version - shown in the on-device Customize menu's title (see
// garmin-shared-src/SettingsMenu.mc). Bump on every push, same value
// typed into the Store dashboard when updating this project's Beta
// listing. See rossonero/source/RossoneroApp.mc's comment and the
// project status doc's "Versioning introduced" section for the full
// MAJOR.MINOR.PATCH scheme. 1.0.1 = step-progress-ring rendering fix;
// 1.1.0 = this round, ring now also shown in Analog mode (MINOR, a real
// behavior change, not just a fix).
const APP_VERSION = "1.1.0";

class SantoriniSunsetApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }
    function onStart(state as Lang.Dictionary?) as Void {
    }
    function onStop(state as Lang.Dictionary?) as Void {
    }
    function getInitialView() as [ WatchUi.Views ] or [ WatchUi.Views, WatchUi.InputDelegates ] {
        // WatchFaceInputDelegate (garmin-shared-src) wires up long-press-to-swap-
        // fields - see that file and SantoriniSunsetView.mc's
        // toggleAltFields().
        var view = new SantoriniSunsetView();
        return [ view, new WatchFaceInputDelegate(view) ];
    }
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
    // On-device "Customize" settings (hold the button in watch-face
    // selection mode) - see garmin-shared-src/SettingsMenu.mc for the full
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
