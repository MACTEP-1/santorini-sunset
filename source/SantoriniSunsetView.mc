using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.ActivityMonitor;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application.Properties;
using Toybox.Timer;
using Toybox.Math;

//
// SantoriniSunsetView.mc - draws the whole watch face.
//
// Same overall architecture as Ritmo (fraction-of-screen layout, awake/
// asleep split, 1Hz timer only while awake) - see that project's comments
// for the reasoning behind those choices, not repeated in full here.
//
// This face's identity is a Santorini sunset background (your own photo by
// default, a procedural vector scene as the lighter-weight alternative) -
// see drawBackground() below and the "Background" setting.
//
class SantoriniSunsetView extends WatchUi.WatchFace {

    private var _isAwake as Lang.Boolean = false;
    private var _tickTimer as Timer.Timer?;
    private var _bgPhoto as Graphics.BitmapType?;

    // ---- Layout constants (fractions of screen width/height) ------------
    // Same round-display chord-width reasoning as Ritmo's layout comment:
    // sqrt(0.25 - dy^2) is the half-width available at vertical offset dy
    // from center before the round bezel clips it. Done on paper, not yet
    // verified live - see README.md.
    // Recalculated from Rossonero's real screenshot: this project used the
    // exact same TIME_Y/STATS_Y/STATS_RADIUS values Rossonero originally
    // shipped with (they were copied from here), and Rossonero's own
    // screenshot showed those values still let FONT_NUMBER_HOT's rendered
    // bottom edge overlap the stat badges - meaning this project almost
    // certainly has the identical unreported bug. Applying the same
    // correction proactively (TIME_Y up, badges nudged accordingly) -
    // not yet confirmed on an actual screenshot of this project.
    const ICON_Y = 0.10;
    const ICON_SIZE = 0.09;
    const DATE_Y = 0.225;
    const TIME_Y = 0.32;
    const STATS_Y = 0.745;
    const STATS_RADIUS = 0.095;
    const STATS_SPACING = 0.24; // center-to-center
    const BATTERY_Y = 0.875;

    const FG = 0xf2f6f8;
    const DIM = 0xc9d6dd;
    const ACCENT = 0x5fb3e0;

    function initialize() {
        WatchFace.initialize();
        // Loaded once here rather than per-frame in onUpdate() - same
        // reasoning as milan-personal's crest loading.
        _bgPhoto = WatchUi.loadResource(Rez.Drawables.BgPhoto) as Graphics.BitmapType;
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function onHide() as Void {
        stopTicking();
    }

    function onExitSleep() as Void {
        _isAwake = true;
        startTicking();
    }

    function onEnterSleep() as Void {
        _isAwake = false;
        stopTicking();
        WatchUi.requestUpdate();
    }

    function startTicking() as Void {
        if (_tickTimer == null) {
            _tickTimer = new Timer.Timer();
        }
        _tickTimer.start(method(:onTick), 1000, true);
    }

    function stopTicking() as Void {
        if (_tickTimer != null) {
            _tickTimer.stop();
        }
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    // No onPartialUpdate - same reasoning as Ritmo (see that project's
    // onUpdate comment): relies on the standard ~once-a-minute always-on
    // redraw instead of a manually clipped partial-update region.
    function onUpdate(dc as Graphics.Dc) as Void {
        draw(dc, _isAwake);
    }

    function draw(dc as Graphics.Dc, awake as Lang.Boolean) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(0x0a1826, 0x0a1826);
        dc.clear();

        if (awake) {
            drawBackground(dc, w, h);
        }
        // Always-on/low-power: no full-canvas background (photo or vector -
        // that's a lot of lit AMOLED pixels to hold for hours, same
        // battery/burn-in reasoning as Ritmo's dimmed always-on frame).
        // drawTopIcon() below still draws the windmill glyph either way,
        // just dimmer when asleep, so the face stays recognizable without
        // a second draw call here.

        var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);

        drawTopIcon(dc, w, h, awake);
        drawDate(dc, w, h, now, awake);
        drawTime(dc, w, h, awake);

        if (awake) {
            drawStats(dc, w, h);
            drawBattery(dc, w, h);
        } else {
            drawLowPowerStats(dc, w, h);
        }
    }

    // ---- Background: photo (default) or procedural vector fallback -------
    //
    // Both options you asked for are wired in now. The "Background" setting
    // (see resources/settings/settings.xml) picks between them; this
    // dispatcher also falls back to the vector scene if the photo resource
    // somehow failed to load (_bgPhoto null) rather than drawing nothing.
    function drawBackground(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var setting = Properties.getValue("Background") as Lang.Number?;
        var useVector = (setting != null && setting == 1);

        if (!useVector && _bgPhoto != null) {
            drawPhotoBackground(dc, w, h);
        } else {
            drawVectorBackground(dc, w, h);
        }
    }

    // Your Santorini sunset photo, stretched to fill the screen exactly
    // per-device via drawScaledBitmap (see manifest.xml for why that needs
    // API 4.0.0). The stored resource (bg_photo.png, 440x440, cropped
    // around the windmill/sunset/ship and color-quantized to a 200-color
    // adaptive palette) was sized once, not per-device - see README.md
    // "Background: vector vs photo" for the memory/quality reasoning
    // behind those specific numbers.
    function drawPhotoBackground(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        dc.drawScaledBitmap(0, 0, w, h, _bgPhoto);
    }

    // ---- Vector fallback: procedural twilight mountain scene --------------
    //
    // Layered polygons (back range lighter/hazier, front range darker/
    // sharper, a snow-cap highlight, a water strip, a few tree silhouettes).
    // This was the original background before you supplied the actual
    // photo - kept as the lighter-weight "Vector illustration" setting
    // option (no image resource, smaller memory footprint - see the
    // Venu 2 CIQ4 watch-face app-memory research in README.md). All
    // coordinates are fractions of screen width/height, same convention as
    // the rest of this file - hardcoded (not randomized) so the scene is
    // identical every redraw, no per-frame flicker.
    function drawVectorBackground(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        // Sky - four horizontal bands faking a vertical gradient (no native
        // gradient fill in this API; solid color bands are the cheap
        // equivalent used elsewhere in Connect IQ watch faces).
        dc.setColor(0x0a1826, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h * 0.45);
        dc.setColor(0x14304a, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.45, w, h * 0.20);
        dc.setColor(0x2f5468, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.65, w, h * 0.15);
        dc.setColor(0x4a7fa0, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.80, w, h * 0.20);

        // Back mountain range - lighter, hazier, further away.
        dc.setColor(0x35596d, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [0.0 * w, 0.62 * h], [0.15 * w, 0.48 * h], [0.28 * w, 0.57 * h],
            [0.40 * w, 0.42 * h], [0.52 * w, 0.55 * h], [0.64 * w, 0.44 * h],
            [0.76 * w, 0.56 * h], [0.90 * w, 0.46 * h], [1.0 * w, 0.60 * h],
            [1.0 * w, 0.85 * h], [0.0 * w, 0.85 * h]
        ]);

        // Front mountain range - darker, sharper, closer.
        dc.setColor(0x142838, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [0.0 * w, 0.70 * h], [0.18 * w, 0.50 * h], [0.30 * w, 0.62 * h],
            [0.42 * w, 0.38 * h], [0.52 * w, 0.60 * h], [0.64 * w, 0.49 * h],
            [0.76 * w, 0.64 * h], [0.90 * w, 0.52 * h], [1.0 * w, 0.66 * h],
            [1.0 * w, 0.95 * h], [0.0 * w, 0.95 * h]
        ]);

        // Snow cap on the tallest front peak (peak tip at 0.42, 0.38).
        dc.setColor(0xe8f1f6, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [0.395 * w, 0.415 * h], [0.42 * w, 0.38 * h], [0.445 * w, 0.415 * h],
            [0.43 * w, 0.425 * h], [0.41 * w, 0.425 * h]
        ]);

        // Water strip at the base, with a couple of faint reflection lines.
        dc.setColor(0x1c3d4c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.85, w, h * 0.15);
        dc.setColor(0x3f6a80, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(w * 0.32, h * 0.885, w * 0.68, h * 0.885);
        dc.drawLine(w * 0.30, h * 0.905, w * 0.70, h * 0.905);

        // Tree silhouettes flanking the lower sides - drawn last so they
        // sit on top of the mountains/water, below where the time/stats
        // text and stat badges are drawn (see draw() call order).
        drawTree(dc, w * 0.11, h * 0.72, w * 0.05);
        drawTree(dc, w * 0.18, h * 0.75, w * 0.035);
        drawTree(dc, w * 0.89, h * 0.72, w * 0.045);
        drawTree(dc, w * 0.82, h * 0.755, w * 0.03);
    }

    // A small stacked-triangle tree silhouette, centered at (cx, baseY),
    // baseY being where the trunk meets the ground. size scales the whole
    // tree.
    function drawTree(dc as Graphics.Dc, cx as Lang.Float, baseY as Lang.Float, size as Lang.Float) as Void {
        dc.setColor(0x0a1620, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - size, baseY - size], [cx + size, baseY - size], [cx, baseY - size * 2.0]]);
        dc.fillPolygon([[cx - size * 0.8, baseY - size * 1.7], [cx + size * 0.8, baseY - size * 1.7], [cx, baseY - size * 2.7]]);
        dc.fillPolygon([[cx - size * 0.55, baseY - size * 2.35], [cx + size * 0.55, baseY - size * 2.35], [cx, baseY - size * 3.15]]);
        dc.fillRectangle(cx - size * 0.08, baseY - size, size * 0.16, size);
    }

    // ---- Top icon + date -------------------------------------------------

    function drawTopIcon(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, awake as Lang.Boolean) as Void {
        var color = awake ? DIM : 0x777777;
        Icons.drawWindmill(dc, w * 0.5 - w * ICON_SIZE * 0.5, h * ICON_Y, w * ICON_SIZE, color);
    }

    function drawDate(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, now as Gregorian.Info, awake as Lang.Boolean) as Void {
        // FORMAT_MEDIUM's day_of_week comes back as a String ("Mon"/"Tue"/
        // etc, English-only) - see Ritmo's drawDate comment for why
        // FORMAT_SHORT (numeric) is used there instead; this face has no
        // in-app language setting so the English string form is fine here.
        var weekday = now.day_of_week as Lang.String;
        var day = now.day as Lang.Number;
        var str = weekday.toUpper() + " " + day.format("%d");
        dc.setColor(awake ? DIM : 0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.5, h * DATE_Y, Graphics.FONT_SMALL, str, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- Time: hour in fg white, colon+minute in accent blue -------------
    // Matches the reference mockup's two-tone "10 | 10" look, one visual
    // step further than Ritmo's colored-colon-only treatment.

    function drawTime(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, awake as Lang.Boolean) as Void {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
            var h12 = hour % 12;
            if (h12 == 0) { h12 = 12; }
            hour = h12;
        }
        var hourStr = hour.format("%02d");
        var minStr = clockTime.min.format("%02d");

        var showColon = true;
        var showSeconds = Properties.getValue("ShowSeconds") as Lang.Boolean?;
        if (awake && showSeconds != null && showSeconds) {
            showColon = (clockTime.sec % 2 == 0);
        }
        var colonStr = showColon ? ":" : " ";

        var timeStr = hourStr + colonStr + minStr;
        var totalWidth = dc.getTextWidthInPixels(timeStr, Graphics.FONT_NUMBER_HOT);
        var hourWidth = dc.getTextWidthInPixels(hourStr, Graphics.FONT_NUMBER_HOT);
        var startX = w * 0.5 - totalWidth / 2;
        var y = h * TIME_Y;

        var fgColor = awake ? FG : 0xdddddd;
        var accentColor = awake ? ACCENT : 0x999999;

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, y, Graphics.FONT_NUMBER_HOT, hourStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + hourWidth, y, Graphics.FONT_NUMBER_HOT, colonStr + minStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // ---- Stats: fixed steps / heart rate / calories badges ---------------
    // Not user-configurable like Ritmo's secondary fields - kept to exactly
    // the three the reference mockup shows, each in its own outlined circle
    // badge sitting on top of the mountain/tree art.

    function drawStats(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var info = ActivityMonitor.getInfo();
        var steps = (info.steps != null) ? info.steps : 0;
        var calories = (info.calories != null) ? info.calories : 0;
        var hr = readHeartRate();
        var hrText = (hr != null) ? hr.format("%d") : "--";

        var cy = h * STATS_Y;
        var r = w * STATS_RADIUS;
        var spacing = w * STATS_SPACING;
        var cxMid = w * 0.5;

        drawStatBadge(dc, cxMid - spacing, cy, r, :steps, formatSteps(steps));
        drawStatBadge(dc, cxMid, cy, r, :heart, hrText);
        drawStatBadge(dc, cxMid + spacing, cy, r, :flame, calories.format("%d"));
    }

    // Steps shown as e.g. "8.6K" once in the thousands, to keep the number
    // short enough for the small badge - plain digits below 1000.
    function formatSteps(steps as Lang.Number) as Lang.String {
        if (steps >= 1000) {
            var thousands = steps / 1000.0;
            return thousands.format("%.1f") + "K";
        }
        return steps.format("%d");
    }

    // Fixed proactively: Rossonero and Milan Personal share this exact
    // stat-badge code, and a real screenshot of Rossonero showed the
    // numbers sitting too close to the badge's bottom edge - drawText's
    // top-anchor plus a small guessed offset didn't account for how much
    // of a small badge's height FONT_TINY actually occupies. Switched to
    // TEXT_JUSTIFY_VCENTER (centers on the anchor regardless of actual
    // font height) rather than wait to hit the same bug here too.
    function drawStatBadge(dc as Graphics.Dc, cx as Lang.Float, cy as Lang.Float, r as Lang.Float, icon as Lang.Symbol, text as Lang.String) as Void {
        dc.setColor(0x0d1b26, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, r);

        var iconSize = r * 0.42;
        var iconTopY = cy - r * 0.62;
        if (icon == :steps) {
            Icons.drawSteps(dc, cx - iconSize * 0.5, iconTopY, iconSize, ACCENT);
        } else if (icon == :heart) {
            Icons.drawHeart(dc, cx - iconSize * 0.5, iconTopY, iconSize, ACCENT);
        } else if (icon == :flame) {
            Icons.drawFlame(dc, cx - iconSize * 0.5, iconTopY, iconSize, ACCENT);
        }

        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + r * 0.28, Graphics.FONT_TINY, text,
            Graphics.TEXT_JUSTIFY_CENTER + Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Dim, icon-free "steps · battery%" line for the always-on frame - same
    // pattern/reasoning as Ritmo's drawLowPowerStats.
    function drawLowPowerStats(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var info = ActivityMonitor.getInfo();
        var steps = (info.steps != null) ? info.steps : 0;
        var battery = System.getSystemStats().battery;
        var line = steps.format("%d") + " · " + battery.format("%d") + "%";
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.5, h * STATS_Y, Graphics.FONT_TINY, line, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- Battery readout --------------------------------------------------

    function drawBattery(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var battery = System.getSystemStats().battery;
        var text = battery.format("%d") + "%";
        var iconSize = w * 0.055;
        var textWidth = dc.getTextWidthInPixels(text, Graphics.FONT_XTINY);
        var groupWidth = iconSize + w * 0.02 + textWidth;
        var x = w * 0.5 - groupWidth * 0.5;
        var battYCenter = h * BATTERY_Y;

        Icons.drawBattery(dc, x, battYCenter - iconSize * 0.5, iconSize, battery, DIM, ACCENT);
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + iconSize + w * 0.02, battYCenter, Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_LEFT + Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function readHeartRate() as Lang.Number? {
        if (!(Toybox has :ActivityMonitor) || !(ActivityMonitor has :getHeartRateHistory)) {
            return null;
        }
        var it = ActivityMonitor.getHeartRateHistory(1, true);
        var sample = it.next();
        if (sample == null || sample.heartRate == null) { return null; }
        if (sample.heartRate == ActivityMonitor.INVALID_HR_SAMPLE) { return null; }
        return sample.heartRate;
    }
}
