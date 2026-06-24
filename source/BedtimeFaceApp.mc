// BedtimeFaceApp.mc
// Entry point. Connect IQ watch faces extend WatchUi.WatchFace (not Application.AppBase).
// The framework calls onStart() once at launch, then drives the view lifecycle separately.

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class BedtimeFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // Called once when the watch face is loaded. Return the initial view.
    // WatchFace views don't use a delegate — the view handles all rendering.
    function getInitialView() {
        return [ new BedtimeFaceView() ];
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }
}
