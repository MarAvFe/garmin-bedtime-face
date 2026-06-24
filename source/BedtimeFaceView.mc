// BedtimeFaceView.mc
// The watch face view. Connect IQ calls onUpdate() once per minute (at the top
// of each minute) while the watch face is active. There is no per-second update
// in this implementation — that is intentional (spec section 5).

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class BedtimeFaceView extends WatchUi.WatchFace {

    // Geometry derived from dc at render time — avoids hardcoded pixel assumptions.
    private var mCx     as Number = 0;
    private var mCy     as Number = 0;
    private var mRadius as Number = 0;  // half the shorter screen dimension

    // Sector ring radii as fractions of mRadius, set in onUpdate.
    private var mSectorInner as Number = 0;
    private var mSectorOuter as Number = 0;

    // Hand lengths and width, set in onUpdate.
    private var mHourLen    as Number = 0;
    private var mMinuteLen  as Number = 0;
    private var mHandWidth  as Number = 6;

    // Day and month abbreviations (English; spec allows locale strings if available,
    // but Connect IQ Gregorian API returns integer values, so we map manually).
    private const DAY_NAMES   = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] as Array<String>;
    private const MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"] as Array<String>;

    // Loaded from Properties on each onUpdate() call so settings changes take
    // effect without reinstalling. See properties.xml for field descriptions.
    private var mPmGreenStart  as Number = 1020;
    private var mPmYellowStart as Number = 1080;
    private var mPmRedStart    as Number = 1170;
    private var mPmRedEnd      as Number = 1230;
    private var mAmGreenStart  as Number = 300;
    private var mAmYellowStart as Number = 390;
    private var mAmRedStart    as Number = 435;
    private var mAmRedEnd      as Number = 465;

    function initialize() {
        WatchFace.initialize();
    }

    // onLayout is called once after initialize(). Use it for resource loading.
    // We have no bitmap resources, so nothing to do here.
    function onLayout(dc as Graphics.Dc) as Void {
    }

    // onShow is called when the watch face becomes visible (e.g., wrist raised).
    function onShow() as Void {
    }

    // onHide is called when the watch face is obscured (e.g., menu opened).
    function onHide() as Void {
    }

    // onExitSleep is called when the watch exits low-power/always-on mode.
    // We do nothing special here; onUpdate() will follow shortly.
    function onExitSleep() as Void {
    }

    // onEnterSleep is called when the watch enters low-power mode.
    // The spec deliberately excludes special always-on handling (section 5).
    // Garmin will display the last rendered frame in a dimmed state automatically
    // on AMOLED watches — no additional burn-in logic is required for MVP.
    function onEnterSleep() as Void {
    }

    // onUpdate is the main render method. The framework calls it once per minute.
    // All drawing happens here — no partial-update (onPartialUpdate) logic per spec.
    function onUpdate(dc as Graphics.Dc) as Void {
        loadSettings();

        // Derive all geometry from actual DC dimensions each frame.
        mCx     = dc.getWidth()  / 2;
        mCy     = dc.getHeight() / 2;
        mRadius = mCx < mCy ? mCx : mCy;
        mSectorInner = (mRadius * 33) / 100;  // ~33% of radius
        mSectorOuter = (mRadius * 88) / 100;  // ~88% of radius, leaves gap for ticks
        mHourLen     = (mRadius * 72) / 100;  // same reach as minute hand
        mMinuteLen   = (mRadius * 72) / 100;

        var clockTime = System.getClockTime();
        var now       = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var sysStats  = System.getSystemStats();

        var hour     = clockTime.hour;
        var minute   = clockTime.min;
        var totalMin = hour * 60 + minute; // minutes since midnight, 0–1439

        // 1. Clear background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // 2. Draw colored routine sectors (bottom layer, under everything)
        drawSectors(dc, totalMin);

        // 3. Draw tick marks around the dial perimeter
        drawTicks(dc);

        // 4. Draw analog hands (on top of sectors)
        drawHands(dc, hour, minute);

        // 5. Draw date — small, at 3 o'clock position, out of hands' sweep
        drawDate(dc, now);

        // 6. Draw battery as a bezel arc (top of dial)
        drawBattery(dc, sysStats.battery);

        // 7. Digital time — small, near 12 o'clock, below the battery arc
        drawDigitalTime(dc, clockTime);
    }

    // -------------------------------------------------------------------------
    // Settings loading
    // -------------------------------------------------------------------------

    // Application.Properties stores the user's configured values.
    // We reload on every onUpdate() so changes from the Garmin Connect app
    // are picked up without needing to restart the watch face.
    private function loadSettings() as Void {
        mPmGreenStart  = Application.Properties.getValue("PmGreenStart")  as Number;
        mPmYellowStart = Application.Properties.getValue("PmYellowStart") as Number;
        mPmRedStart    = Application.Properties.getValue("PmRedStart")    as Number;
        mPmRedEnd      = Application.Properties.getValue("PmRedEnd")      as Number;
        mAmGreenStart  = Application.Properties.getValue("AmGreenStart")  as Number;
        mAmYellowStart = Application.Properties.getValue("AmYellowStart") as Number;
        mAmRedStart    = Application.Properties.getValue("AmRedStart")    as Number;
        mAmRedEnd      = Application.Properties.getValue("AmRedEnd")      as Number;
    }

    // -------------------------------------------------------------------------
    // Sector drawing
    // -------------------------------------------------------------------------

    // Returns the color for a given time (minutes since midnight).
    // The watch face shows a 12-hour analog dial, so we map both AM and PM
    // times to the same visual position. We determine which "routine window"
    // is active and return the appropriate sector color.
    private function getSectorColor(totalMin as Number) as Number {
        // AM routine check
        if (totalMin >= mAmGreenStart && totalMin < mAmYellowStart) {
            return Graphics.COLOR_GREEN;
        }
        if (totalMin >= mAmYellowStart && totalMin < mAmRedStart) {
            return Graphics.COLOR_YELLOW;
        }
        if (totalMin >= mAmRedStart && totalMin < mAmRedEnd) {
            return Graphics.COLOR_RED;
        }

        // PM routine check
        if (totalMin >= mPmGreenStart && totalMin < mPmYellowStart) {
            return Graphics.COLOR_GREEN;
        }
        if (totalMin >= mPmYellowStart && totalMin < mPmRedStart) {
            return Graphics.COLOR_YELLOW;
        }
        if (totalMin >= mPmRedStart && totalMin < mPmRedEnd) {
            return Graphics.COLOR_RED;
        }

        // Outside any routine window
        return Graphics.COLOR_DK_GRAY;
    }

    // Converts minutes-since-midnight to the clock-face angle (degrees).
    // On an analog 12-hour face, each hour occupies 30°, each minute 0.5°.
    // 12:00 = 0° (top), values increase clockwise.
    // We mod by 720 (12 hours in minutes) to fold 24h into 12h.
    private function minutesToAngle(totalMin as Number) as Float {
        var clockMin = totalMin % 720; // fold to 12-hour cycle
        return (clockMin / 2.0f);     // 720 min → 360°; each minute = 0.5°
    }

    // Draws all colored sector arcs for the current time.
    // Strategy: build a list of [startAngle, endAngle, color] segments spanning
    // the full 360° of the dial, then fill each with drawArc().
    private function drawSectors(dc as Graphics.Dc, totalMin as Number) as Void {
        // We define sector boundaries by their clock positions (minutes since midnight).
        // Both AM and PM boundaries are combined; dead zones fill the rest.
        // We paint a continuous 360° ring by walking all 720 "clock minutes" and
        // grouping consecutive minutes with the same color into arcs.

        // Convert each boundary pair to an angle range and draw.
        // This is the clearest representation of the spec table without
        // requiring complex interval arithmetic.

        // List of [startMin (0–1439), endMin (0–1439), color]
        var segments = [
            [mAmGreenStart,  mAmYellowStart, Graphics.COLOR_GREEN],
            [mAmYellowStart, mAmRedStart,    Graphics.COLOR_YELLOW],
            [mAmRedStart,    mAmRedEnd,       Graphics.COLOR_RED],
            [mPmGreenStart,  mPmYellowStart, Graphics.COLOR_GREEN],
            [mPmYellowStart, mPmRedStart,    Graphics.COLOR_YELLOW],
            [mPmRedStart,    mPmRedEnd,       Graphics.COLOR_RED],
        ] as Array<Array<Number>>;

        // Dead zone: near-black so it recedes behind colored sectors
        drawArcSegment(dc, 0.0f, 360.0f, 0x181818);

        // Overlay colored segments on top
        for (var i = 0; i < segments.size(); i++) {
            var seg   = segments[i] as Array<Number>;
            var sMin  = seg[0] as Number;
            var eMin  = seg[1] as Number;
            var color = seg[2] as Number;

            if (eMin <= sMin) { continue; } // skip degenerate/unconfigured

            var startAngle = minutesToAngle(sMin);
            var endAngle   = minutesToAngle(eMin);
            drawArcSegment(dc, startAngle, endAngle, color);
        }
    }

    // Draws a filled arc segment in the sector ring.
    // startAngleCW and endAngleCW are clockwise degrees from 12 o'clock (0=top).
    // Garmin drawArc(x, y, w, h, attr, degStart, degEnd):
    //   - x,y is the TOP-LEFT of the bounding box, not the center
    //   - 0° = 3 o'clock, angles increase counter-clockwise
    //   - ARC_CLOCKWISE draws from degStart DOWN to degEnd (clockwise on screen)
    private function drawArcSegment(dc as Graphics.Dc, startAngleCW as Float, endAngleCW as Float, color as Number) as Void {
        if (endAngleCW <= startAngleCW) { return; }

        // Convert CW-from-12 → Garmin DC convention (CCW-from-3):
        //   garmin = 90 - cwAngle  (and wrap into 0–359)
        // Because we go CW on screen, use ARC_CLOCKWISE with degStart > degEnd.
        var dcStart = ((90.0f - startAngleCW + 360.0f).toNumber() % 360);
        var dcEnd   = ((90.0f - endAngleCW   + 360.0f).toNumber() % 360);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        // Fill the ring by drawing concentric arcs from SECTOR_INNER to SECTOR_OUTER.
        // drawArc(x, y, width, height, attr, degStart, degEnd)
        // x,y = top-left of bounding box = CENTER - radius
        var r = mSectorInner;
        while (r <= mSectorOuter) {
            dc.drawArc(mCx, mCy, r, Graphics.ARC_CLOCKWISE, dcStart, dcEnd);
            r++;
        }
    }

    // -------------------------------------------------------------------------
    // Tick marks
    // -------------------------------------------------------------------------

    private function drawTicks(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        for (var i = 0; i < 60; i++) {
            var angleDeg  = i * 6.0f;
            var angleRad  = angleDeg * Math.PI / 180.0f;
            var sinA      = Math.sin(angleRad);
            var cosA      = Math.cos(angleRad);

            var isHourTick = (i % 5 == 0);
            var outerR     = mRadius - 2;
            var innerR     = isHourTick ? outerR - (mRadius / 15) : outerR - (mRadius / 30);

            var x1 = mCx + (outerR * sinA).toNumber();
            var y1 = mCy - (outerR * cosA).toNumber();
            var x2 = mCx + (innerR * sinA).toNumber();
            var y2 = mCy - (innerR * cosA).toNumber();

            dc.drawLine(x1, y1, x2, y2);
        }
    }

    // -------------------------------------------------------------------------
    // Analog hands
    // -------------------------------------------------------------------------

    private function drawHands(dc as Graphics.Dc, hour as Number, minute as Number) as Void {
        // Hour hand angle: each hour = 30°, each minute adds 0.5°
        var hourAngle   = ((hour % 12) * 30.0f) + (minute * 0.5f);
        // Minute hand angle: each minute = 6°
        var minuteAngle = minute * 6.0f;

        drawHand(dc, hourAngle, mHourLen, mHandWidth + 2, Graphics.COLOR_WHITE);
        // drawHand(dc, minuteAngle, mMinuteLen, mHandWidth, Graphics.COLOR_WHITE);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mCx, mCy, 5);
    }

    // Draws a single hand as a filled rectangle rotated to the given angle.
    // angleDeg: clockwise degrees from 12 o'clock.
    // length: hand length from center (px). width: stroke width (px).
    private function drawHand(dc as Graphics.Dc, angleDeg as Float, length as Number, width as Number, color as Number) as Void {
        var angleRad = angleDeg * Math.PI / 180.0f;
        var sinA     = Math.sin(angleRad);
        var cosA     = Math.cos(angleRad);

        var tipX = mCx + (length * sinA).toNumber();
        var tipY = mCy - (length * cosA).toNumber();

        var stubLen = mRadius / 12;
        var stubX   = mCx - (stubLen * sinA).toNumber();
        var stubY   = mCy + (stubLen * cosA).toNumber();

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(width);
        dc.drawLine(stubX, stubY, tipX, tipY);
        dc.setPenWidth(1); // reset to default
    }

    // -------------------------------------------------------------------------
    // Secondary indicators (low visual weight — peripheral, small, dim)
    // -------------------------------------------------------------------------

    // Date: "23 Jun" at the 3 o'clock position, clear of the hands' sweep.
    // FONT_XTINY keeps it small; 0x555555 keeps it dim.
    private function drawDate(dc as Graphics.Dc, info as Gregorian.Info) as Void {
        var monthName = MONTH_NAMES[info.month - 1];
        var dateStr   = info.day.toString() + " " + monthName;

        // 3 o'clock: x = cx + 55% radius, y = cy (vertically centered)
        var x = mCx + (mRadius * 55) / 100;
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, mCy, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Battery: thin arc along the outer bezel, top of dial (spanning ±battery/2 degrees).
    // Full = 180° arc centered on 12; empty = 0°. Drawn just inside the tick ring.
    // Color shifts from dim green → dim red as charge drops below 20%.
    private function drawBattery(dc as Graphics.Dc, batteryPct as Float) as Void {
        // Arc spans up to 180° total centered on 12 o'clock (±90° from top).
        // At 100% → 180° sweep; at 0% → 0° sweep.
        var sweepDeg = (batteryPct * 1.8f).toNumber(); // 100% → 180°
        if (sweepDeg <= 0) { return; }

        // Arc occupies 2px wide just inside the outermost tick ring
        var arcR = mRadius - 1;

        var color = batteryPct < 20.0f ? 0x993333 : 0x336633;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        // CW-from-12: arc starts at (360 - sweep/2) and ends at (sweep/2),
        // i.e. centered on 12 o'clock.
        var halfSweep  = sweepDeg / 2;
        var startAngle = (360 - halfSweep).toFloat();
        var endAngle   = halfSweep.toFloat();

        // Convert to Garmin DC convention: dcAngle = 90 - cwAngle (mod 360)
        var dcStart = ((90 - startAngle.toNumber() + 360) % 360);
        var dcEnd   = ((90 - endAngle.toNumber()   + 360) % 360);

        var i = 0;
        while (i < 5) {
            dc.drawArc(mCx, mCy, arcR - i, Graphics.ARC_CLOCKWISE, dcStart, dcEnd);
            i++;
        }
    }

    // Digital time: small, near 12 o'clock, just inside the battery arc.
    // Low contrast — reference only, not competing with the hand.
    private function drawDigitalTime(dc as Graphics.Dc, clockTime as System.ClockTime) as Void {
        var hour   = clockTime.hour;
        var minute = clockTime.min;

        var h12    = hour % 12;
        if (h12 == 0) { h12 = 12; }
        var minStr  = minute < 10 ? ("0" + minute.toString()) : minute.toString();
        var timeStr = h12.toString() + ":" + minStr;

        // Just below 12 o'clock, inside the battery arc
        var y = mCy - (mRadius * 62) / 100;
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, y, Graphics.FONT_LARGE, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
