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
using Toybox.Weather;

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
    // Soft teal/green for the backdrop dome in the awake-only top icon
    // scene - see Icons.drawSantoriniScene.
    const BG_DOME = 0x8cc3aa;

    // Selectable stat-badge fields - numeric IDs match the Field1/Field2/
    // Field3 settings.xml list values exactly, so don't renumber these
    // without updating settings.xml/strings.xml to match.
    const FIELD_STEPS = 0;
    const FIELD_HEART = 1;
    const FIELD_CALORIES = 2;
    const FIELD_DISTANCE = 3;
    const FIELD_FLOORS = 4;
    const FIELD_ACTIVE_MIN = 5;
    const FIELD_BATTERY = 6;
    const FIELD_STRESS = 7;
    const FIELD_TEMPERATURE = 8;
    const FIELD_WORLD_CLOCK = 9;

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

        // BUG FIX: this used to clear to 0x0a1826 (a dark navy) in BOTH
        // states, then only draw the photo/vector background on top when
        // awake - meaning every pixel on the display sat at that navy
        // value, not true black, for the entire always-on period. On an
        // AMOLED display that's real, continuous power draw and burn-in
        // exposure across the whole screen, which is exactly what tripped
        // your simulator's "luminance exceeding 10%" warning - confirmed
        // by rendering both versions and measuring: the navy base fill
        // alone accounts for the majority of that 10.81% usage. Rossonero
        // and milan-personal never had this bug - they already clear to
        // true COLOR_BLACK unconditionally and only tint the canvas when
        // awake. Matching that pattern here.
        if (awake) {
            dc.setColor(0x0a1826, 0x0a1826);
            dc.clear();
            drawBackground(dc, w, h);
        } else {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
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

    // Swapped the generic windmill glyph for a blue-domed Cycladic scene -
    // a much more specifically-Santorini symbol (your suggestion, further
    // refined to match the multi-building reference photo you sent). Awake
    // and asleep use two different icon functions on purpose - see
    // Icons.drawSantoriniScene's comment for why the richer version isn't
    // used when asleep.
    function drawTopIcon(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, awake as Lang.Boolean) as Void {
        var iconX = w * 0.5 - w * ICON_SIZE * 0.5;
        var iconY = h * ICON_Y;
        var iconW = w * ICON_SIZE;
        if (awake) {
            Icons.drawSantoriniScene(dc, iconX, iconY, iconW, FG, ACCENT, BG_DOME);
        } else {
            // Single building, single dark tone for both body and dome -
            // same burn-in luminance-budget reasoning as draw()'s comment
            // above (darkened from windmill's 0x777777 to 0x444444
            // already), and the only version of the icon that stays
            // legible once everything's reduced to near-black gray at
            // this size - see Icons.drawSantoriniScene's comment.
            Icons.drawChurch(dc, iconX, iconY, iconW, 0x444444, 0x444444);
        }
    }

    function drawDate(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, now as Gregorian.Info, awake as Lang.Boolean) as Void {
        // FORMAT_MEDIUM's day_of_week comes back as a String ("Mon"/"Tue"/
        // etc, English-only) - see Ritmo's drawDate comment for why
        // FORMAT_SHORT (numeric) is used there instead; this face has no
        // in-app language setting so the English string form is fine here.
        var weekday = now.day_of_week as Lang.String;
        var day = now.day as Lang.Number;
        var str = weekday.toUpper() + " " + day.format("%d");

        // BUG FIX: DIM (a pale blue-gray, 0xc9d6dd) turned out to be
        // almost exactly the same brightness as the sky at DATE_Y in your
        // actual photo (sampled it - around RGB 216,200,161 there, a warm
        // cream), just a different hue - nearly invisible, confirmed from
        // your screenshot. A flat color can't win against every part of a
        // photo (dark sea, bright sky, dark windmill silhouette all pass
        // through this row on different builds/settings), so instead of
        // picking a different single color and hoping, this draws a small
        // dark shadow copy of the text first, then the real text in FG
        // (bright white, same tone the time's hour digits already use and
        // read fine in your screenshot) on top - checked against the
        // actual photo crop at this position before shipping, reads
        // clearly now. Shadow only drawn when awake - asleep already sits
        // on a solid black background (see draw()'s burn-in fix), so a
        // shadow there would just be wasted always-on pixels.
        if (awake) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w * 0.5 + 1, h * DATE_Y + 1, Graphics.FONT_SMALL, str, Graphics.TEXT_JUSTIFY_CENTER);
        }
        // Darkened from 0x777777 when asleep - same burn-in margin
        // reasoning as drawTopIcon() above.
        dc.setColor(awake ? FG : 0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 0.5, h * DATE_Y, Graphics.FONT_SMALL, str, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---- Time: hour in fg white, colon+minute in accent blue -------------
    // Matches the reference mockup's two-tone "10 | 10" look, one visual
    // step further than Ritmo's colored-colon-only treatment.

    function drawTime(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, awake as Lang.Boolean) as Void {
        var clockStyle = Properties.getValue("ClockStyle") as Lang.Number?;
        if (clockStyle != null && clockStyle == 1) {
            drawAnalogTime(dc, w, h, awake);
            return;
        }

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

        // Darkened from 0xdddddd/0x999999 - same burn-in margin reasoning
        // as drawTopIcon()/drawDate() above. This is the single biggest
        // lever here: FONT_NUMBER_HOT is a lot of always-on screen area,
        // so even a moderate brightness cut meaningfully reduces the
        // luminance budget without changing size or position.
        var fgColor = awake ? FG : 0x666666;
        var accentColor = awake ? ACCENT : 0x555555;

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, y, Graphics.FONT_NUMBER_HOT, hourStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + hourWidth, y, Graphics.FONT_NUMBER_HOT, colonStr + minStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // ---- Analog clock hands, drawn from the screen's TRUE center -----------
    //
    // Added as an alternative to the digital time readout (Settings >
    // Clock Style). Deliberately minimal, per your own scope choice when
    // asked: only the time element changes - the top icon, date row, the
    // 3 stat badges, and the battery readout all stay exactly where they
    // already are. The hands pivot from (w*0.5, h*0.5), the screen's
    // actual center - NOT the same spot the digital time sits (TIME_Y is
    // offset upward from center to leave room for the stat badges below
    // it), so depending on the time of day a hand can visually pass near
    // the date, the top icon, or the badges. That's the accepted tradeoff
    // of keeping this a small, isolated change instead of redesigning the
    // whole layout (and the photo background composition) around a bigger
    // analog face.
    //
    // Hour + minute hands only, no seconds hand - your call, and it also
    // keeps this exactly as burn-in-safe as everything else on this face:
    // no per-second redraw to worry about, awake or asleep. Same dimmed
    // asleep colors as the digital mode just above (0x666666/0x555555,
    // already tuned this session for the AMOLED luminance budget fix) -
    // reused as-is rather than picking new numbers for this project's
    // darker-than-the-other-two-projects asleep palette.
    function drawAnalogTime(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number, awake as Lang.Boolean) as Void {
        var clockTime = System.getClockTime();
        var hour12 = clockTime.hour % 12;
        var min = clockTime.min;

        var cx = w * 0.5;
        var cy = h * 0.5;
        var hourLen = w * 0.20;
        var minLen = w * 0.32;

        var minuteAngle = min * 6.0;
        var hourAngle = hour12 * 30.0 + min * 0.5;

        var fgColor = awake ? FG : 0x666666;
        var accentColor = awake ? ACCENT : 0x555555;

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        drawClockHand(dc, cx, cy, hourAngle, hourLen);

        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        drawClockHand(dc, cx, cy, minuteAngle, minLen);

        dc.fillCircle(cx, cy, w * 0.015);
    }

    // angleDeg is clockwise degrees from 12 o'clock (0 = straight up),
    // matching how clock hands are conventionally described - converted
    // here to screen coordinates (0deg => negative-y/up, 90deg => positive-
    // x/right).
    function drawClockHand(dc as Graphics.Dc, cx as Lang.Float, cy as Lang.Float, angleDeg as Lang.Float, length as Lang.Float) as Void {
        var rad = Math.toRadians(angleDeg);
        var x = cx + length * Math.sin(rad);
        var y = cy - length * Math.cos(rad);
        dc.drawLine(cx, cy, x, y);
    }

    // ---- Stats: user-selectable badges (Settings > Field 1/2/3) -----------
    // Used to be fixed steps/heart rate/calories. Each of the three circles
    // now independently shows whatever FIELD_* the user picked in Settings
    // (defaults are still steps/heart rate/calories, so an existing install
    // that hasn't touched Settings looks identical to before this change).

    function drawStats(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var info = ActivityMonitor.getInfo();

        var field1 = Properties.getValue("Field1") as Lang.Number?;
        var field2 = Properties.getValue("Field2") as Lang.Number?;
        var field3 = Properties.getValue("Field3") as Lang.Number?;
        if (field1 == null) { field1 = FIELD_STEPS; }
        if (field2 == null) { field2 = FIELD_HEART; }
        if (field3 == null) { field3 = FIELD_CALORIES; }

        var cy = h * STATS_Y;
        var r = w * STATS_RADIUS;
        var spacing = w * STATS_SPACING;
        var cxMid = w * 0.5;

        drawStatBadge(dc, cxMid - spacing, cy, r, field1, fieldText(field1, info));
        drawStatBadge(dc, cxMid, cy, r, field2, fieldText(field2, info));
        drawStatBadge(dc, cxMid + spacing, cy, r, field3, fieldText(field3, info));
    }

    // Text for one FIELD_* id. info is the shared ActivityMonitor.getInfo()
    // snapshot from drawStats() - passed in rather than re-fetched per
    // field so all three badges reflect the exact same instant.
    function fieldText(fieldId as Lang.Number, info as ActivityMonitor.Info) as Lang.String {
        if (fieldId == FIELD_HEART) {
            var hr = readHeartRate();
            return (hr != null) ? hr.format("%d") : "--";
        } else if (fieldId == FIELD_CALORIES) {
            var cal = (info.calories != null) ? info.calories : 0;
            return cal.format("%d");
        } else if (fieldId == FIELD_DISTANCE) {
            // Info.distance is centimeters since midnight - convert to the
            // device's configured unit (System.UNIT_METRIC/UNIT_STATUTE,
            // same enum distanceUnits uses elsewhere in Connect IQ).
            var distCm = (info.distance != null) ? info.distance : 0;
            if (System.getDeviceSettings().distanceUnits == System.UNIT_METRIC) {
                return (distCm / 100000.0).format("%.1f") + "km";
            }
            return (distCm / 160934.4).format("%.1f") + "mi";
        } else if (fieldId == FIELD_FLOORS) {
            var floors = (info.floorsClimbed != null) ? info.floorsClimbed : 0;
            return floors.format("%d");
        } else if (fieldId == FIELD_ACTIVE_MIN) {
            var mins = 0;
            if (info.activeMinutesDay != null) {
                mins = info.activeMinutesDay.total;
            }
            return mins.format("%d") + "m";
        } else if (fieldId == FIELD_BATTERY) {
            return System.getSystemStats().battery.format("%d") + "%";
        } else if (fieldId == FIELD_STRESS) {
            var stress = info.stressScore;
            return (stress != null) ? stress.format("%d") : "--";
        } else if (fieldId == FIELD_TEMPERATURE) {
            return temperatureText();
        } else if (fieldId == FIELD_WORLD_CLOCK) {
            return worldClockText();
        }
        // FIELD_STEPS, and the fallback for any unrecognized value.
        var steps = (info.steps != null) ? info.steps : 0;
        return formatSteps(steps);
    }

    // Ambient temperature via the connected phone's weather data - NOT a
    // physical sensor on this device, so it needs a Bluetooth-connected
    // phone with the Connect app and (per manifest.xml) the Weather
    // permission, and can legitimately come back null (no phone, no signal
    // yet, weather not synced). Falls back to "--" rather than guessing.
    // Least-tested part of this feature - see README.
    function temperatureText() as Lang.String {
        var conditions = (Toybox has :Weather) ? Weather.getCurrentConditions() : null;
        if (conditions == null || conditions.temperature == null) {
            return "--";
        }
        var celsius = conditions.temperature;
        var metric = (System.getDeviceSettings().temperatureUnits == System.UNIT_METRIC);
        var value = metric ? celsius : (celsius * 9.0 / 5.0 + 32.0);
        return value.format("%d") + "°";
    }

    // A second timezone as a fixed UTC-offset-in-hours clock (Settings >
    // World Clock Offset) rather than a real timezone/DST lookup - Monkey C
    // has no on-device timezone database, so this is the honest version of
    // that feature: shift the current instant by the configured offset and
    // read it back as UTC, which is equivalent to reading local time at
    // that offset. Whole-hour offsets only - the handful of half-hour zones
    // (India, Nepal, etc) aren't selectable, noted in strings.xml.
    function worldClockText() as Lang.String {
        var offsetHours = Properties.getValue("WorldClockOffset") as Lang.Number?;
        if (offsetHours == null) { offsetHours = 0; }
        var shifted = Time.now().add(new Time.Duration(offsetHours * 3600));
        var info = Gregorian.utcInfo(shifted, Time.FORMAT_SHORT);
        var hour = info.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        return hour.format("%02d") + ":" + info.min.format("%02d");
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
    function drawStatBadge(dc as Graphics.Dc, cx as Lang.Float, cy as Lang.Float, r as Lang.Float, fieldId as Lang.Number, text as Lang.String) as Void {
        dc.setColor(0x0d1b26, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, r);

        var iconSize = r * 0.42;
        var iconTopY = cy - r * 0.62;
        var iconX = cx - iconSize * 0.5;
        if (fieldId == FIELD_HEART) {
            Icons.drawHeart(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_CALORIES) {
            Icons.drawFlame(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_DISTANCE) {
            Icons.drawDistance(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_FLOORS) {
            Icons.drawFloors(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_ACTIVE_MIN) {
            Icons.drawActiveMinutes(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_BATTERY) {
            // drawBattery's box is size x size*0.5 (half-height), unlike
            // the other icons here - nudge down to stay vertically
            // centered in the same icon slot instead of hugging the top.
            var pct = System.getSystemStats().battery;
            Icons.drawBattery(dc, iconX, iconTopY + iconSize * 0.25, iconSize, pct, ACCENT, ACCENT);
        } else if (fieldId == FIELD_STRESS) {
            Icons.drawStress(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_TEMPERATURE) {
            Icons.drawTemperature(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_WORLD_CLOCK) {
            Icons.drawWorldClock(dc, iconX, iconTopY, iconSize, ACCENT);
        } else {
            Icons.drawSteps(dc, iconX, iconTopY, iconSize, ACCENT);
        }

        // FIX (carried over from rossonero/milan-personal - same shared
        // badge code): steps can go well past 3 digits, and once
        // formatSteps() switches to "12.3K"-style text it's noticeably
        // wider than a bare "0" or "80" - never checked against how much
        // horizontal room this small a badge actually has. Measure the
        // actual rendered width at runtime and drop to a smaller font if
        // FONT_TINY would run wider than the badge's chord width at this
        // text row (r * 1.7, leaving a little padding inside the circle).
        var textFont = Graphics.FONT_TINY;
        var maxTextWidth = r * 1.7;
        if (dc.getTextWidthInPixels(text, textFont) > maxTextWidth) {
            textFont = Graphics.FONT_XTINY;
        }

        dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + r * 0.28, textFont, text,
            Graphics.TEXT_JUSTIFY_CENTER + Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Dim, icon-free "steps · battery%" line for the always-on frame - same
    // pattern/reasoning as Ritmo's drawLowPowerStats.
    function drawLowPowerStats(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var info = ActivityMonitor.getInfo();
        var steps = (info.steps != null) ? info.steps : 0;
        var battery = System.getSystemStats().battery;
        var line = steps.format("%d") + " · " + battery.format("%d") + "%";
        // Darkened from 0x999999 - same burn-in margin reasoning as above.
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
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
