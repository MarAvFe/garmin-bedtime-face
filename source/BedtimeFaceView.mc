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

    // Display dimensions — Forerunner 955: 360×360 AMOLED circular display.
    // These constants avoid magic numbers throughout the drawing code.
    private const DISPLAY_W = 360;
    private const DISPLAY_H = 360;
    private const CENTER_X  = 180;
    private const CENTER_Y  = 180;
    private const RADIUS    = 180; // outer edge of the circular display

    // Sector ring: filled arc from SECTOR_INNER to SECTOR_OUTER radius.
    // Leaving a gap at the center keeps the hands visually dominant.
    private const SECTOR_INNER = 60;   // px from center
    private const SECTOR_OUTER = 160;  // px from center; leaves ~20px for tick ring

    // Hand lengths (from center)
    private const HOUR_HAND_LEN   = 90;
    private const MINUTE_HAND_LEN = 130;
    private const HAND_WIDTH       = 6;  // stroke width in pixels

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

        var clockTime = System.getClockTime();
        var now       = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var sysStats  = System.getSystemStats();

        var hour   = clockTime.hour;    // 0–23
        var minute = clockTime.min;     // 0–59
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

        // 5. Draw digital time (small, lower-right area)
        drawDigitalTime(dc, clockTime);

        // 6. Draw date (bottom of dial)
        drawDate(dc, now);

        // 7. Draw battery percentage (top of dial)
        drawBattery(dc, sysStats.battery);
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

        // Draw dead-zone background first (full ring in dark gray)
        drawArcSegment(dc, 0.0f, 360.0f, Graphics.COLOR_DK_GRAY);

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
    // startAngle and endAngle are clockwise degrees from 12 o'clock (0 = top).
    // Graphics.drawArc uses counter-clockwise convention with 0° at 3 o'clock,
    // so we must convert.
    private function drawArcSegment(dc as Graphics.Dc, startAngleCW as Float, endAngleCW as Float, color as Number) as Void {
        if (endAngleCW <= startAngleCW) { return; }

        // Convert: CW from 12 o'clock → CCW from 3 o'clock
        // CW from top: 0°=top, 90°=right, 180°=bottom, 270°=left
        // DC arc convention: 0°=right(3), 90°=top(12), CCW positive
        // Mapping: dcAngle = 90 - cwAngle
        var dcStart = (90.0f - startAngleCW + 360.0f) % 360.0f; // higher value (arc start in CCW)
        var dcEnd   = (90.0f - endAngleCW   + 360.0f) % 360.0f; // lower value

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        // Draw concentric filled rings to produce a thick arc.
        // drawArc draws only the outline; to fill the sector ring we draw many
        // concentric arcs from SECTOR_INNER to SECTOR_OUTER radius.
        // Step of 1px ensures full fill with no gaps on AMOLED.
        var r = SECTOR_INNER;
        while (r <= SECTOR_OUTER) {
            // Graphics.Dc.drawArc(x, y, radius, attr, degStart, degEnd)
            // attr: Graphics.ARC_CLOCKWISE or ARC_COUNTER_CLOCKWISE — we use CCW
            // because our dcStart > dcEnd for normal CW sectors.
            dc.drawArc(CENTER_X, CENTER_Y, r, Graphics.ARC_COUNTER_CLOCKWISE, dcStart.toNumber(), dcEnd.toNumber());
            r++;
        }
    }

    // -------------------------------------------------------------------------
    // Tick marks
    // -------------------------------------------------------------------------

    private function drawTicks(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        for (var i = 0; i < 60; i++) {
            var angleDeg  = i * 6.0f;                    // 60 ticks × 6° each
            var angleRad  = angleDeg * Math.PI / 180.0f;
            var sinA      = Math.sin(angleRad);
            var cosA      = Math.cos(angleRad);

            var isHourTick = (i % 5 == 0);
            var outerR     = RADIUS - 4;
            var innerR     = isHourTick ? outerR - 12 : outerR - 6;

            var x1 = CENTER_X + (outerR * sinA).toNumber();
            var y1 = CENTER_Y - (outerR * cosA).toNumber();
            var x2 = CENTER_X + (innerR * sinA).toNumber();
            var y2 = CENTER_Y - (innerR * cosA).toNumber();

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

        // Draw hour hand (shorter, wider)
        drawHand(dc, hourAngle, HOUR_HAND_LEN, HAND_WIDTH + 2, Graphics.COLOR_WHITE);
        // Draw minute hand (longer, narrower)
        drawHand(dc, minuteAngle, MINUTE_HAND_LEN, HAND_WIDTH, Graphics.COLOR_WHITE);

        // Center dot over the hand pivot
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(CENTER_X, CENTER_Y, 5);
    }

    // Draws a single hand as a filled rectangle rotated to the given angle.
    // angleDeg: clockwise degrees from 12 o'clock.
    // length: hand length from center (px). width: stroke width (px).
    private function drawHand(dc as Graphics.Dc, angleDeg as Float, length as Number, width as Number, color as Number) as Void {
        var angleRad = angleDeg * Math.PI / 180.0f;
        var sinA     = Math.sin(angleRad);
        var cosA     = Math.cos(angleRad);

        // Tip of the hand
        var tipX = CENTER_X + (length * sinA).toNumber();
        var tipY = CENTER_Y - (length * cosA).toNumber();

        // Small back-stub behind the center (cosmetic)
        var stubLen = 15;
        var stubX   = CENTER_X - (stubLen * sinA).toNumber();
        var stubY   = CENTER_Y + (stubLen * cosA).toNumber();

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(width);
        dc.drawLine(stubX, stubY, tipX, tipY);
        dc.setPenWidth(1); // reset to default
    }

    // -------------------------------------------------------------------------
    // Text elements
    // -------------------------------------------------------------------------

    private function drawDigitalTime(dc as Graphics.Dc, clockTime as System.ClockTime) as Void {
        var hour   = clockTime.hour;
        var minute = clockTime.min;

        // Format as 12h with AM/PM; no leading zero on hour
        var isPm   = (hour >= 12);
        var h12    = hour % 12;
        if (h12 == 0) { h12 = 12; }
        var suffix = isPm ? "pm" : "am";
        var minStr = minute < 10 ? ("0" + minute.toString()) : minute.toString();
        var timeStr = h12.toString() + ":" + minStr + suffix;

        // Position: lower-right quadrant, below center
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CENTER_X + 45, CENTER_Y + 30, Graphics.FONT_SMALL, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawDate(dc as Graphics.Dc, info as Gregorian.Info) as Void {
        // Format: "Tue 23 Jun" — day-of-week index is 1-based (1=Sun) in Gregorian.Info
        var dayName   = DAY_NAMES[(info.day_of_week - 1) % 7];
        var monthName = MONTH_NAMES[info.month - 1];
        var dateStr   = dayName + " " + info.day.toString() + " " + monthName;

        // Position: bottom of the dial
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CENTER_X, CENTER_Y + 65, Graphics.FONT_SMALL, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawBattery(dc as Graphics.Dc, batteryPct as Float) as Void {
        var battStr = batteryPct.toNumber().toString() + "%";

        // Position: top of the dial, above center
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CENTER_X, CENTER_Y - 80, Graphics.FONT_SMALL, battStr, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
