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
using Toybox.Activity;
using Toybox.Position;

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
    // Long-press-to-swap-fields state - see RossoneroView.mc's identical
    // field for the full reasoning (not persisted, resets on relaunch).
    private var _showAltFields as Lang.Boolean = false;

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

    // Left/right badges lifted a little relative to the middle one, so
    // the row echoes the round bezel instead of a flat line across it -
    // see Rossonero's comment on this same constant for the full
    // reasoning and how 0.035 was picked.
    const STATS_OUTER_LIFT = 0.035;

    const FG = 0xf2f6f8;
    const DIM = 0xc9d6dd;
    const ACCENT = 0x5fb3e0;
    const CHARGE_COLOR = 0xffcc00;
    // Soft teal/green for the backdrop dome in the awake-only top icon
    // scene - see Icons.drawSantoriniScene.
    const BG_DOME = 0x8cc3aa;

    // Hour ticks + numbers ring for Analog clock style (Settings > Clock
    // Style). Rossonero/milan-personal already had a decorative perimeter
    // tick ring to build on; this project has none, so this adds a plain
    // 12-mark ring instead of reusing an existing one. Two separate radii
    // (ticks nearer the bezel, numbers a bit further in) rather than one
    // shared radius - putting both at the same distance made the number
    // glyphs and the tick marks draw right on top of each other in an
    // early version of the mockup. Checked against the actual
    // resources/drawables/bg_photo.png (not just guessed) with the same
    // black-shadow-then-FG-text technique drawDate() already uses for
    // this exact "flat color can't win against every part of a photo"
    // problem - reads clearly across sky/sea/windmill in the rendered
    // check. Skips "12" - the top icon marks that spot instead, same
    // reasoning as the other two projects.
    const HOUR_NUM_RADIUS = 0.46;
    const HOUR_TICK_OUTER_RADIUS = 0.485;
    const HOUR_TICK_LEN = 0.03;

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
    // Added in the "second hand / move bar / sunrise-sunset / step ring"
    // round - see Rossonero's comment on these same constants for the full
    // reasoning. Sunrise/sunset land especially fittingly on this project
    // given its name, though see sunriseText()/sunsetText() below for why
    // it's also the least certain thing added this round.
    const FIELD_MOVE_BAR = 10;
    const FIELD_SUNRISE = 11;
    const FIELD_SUNSET = 12;

    // Steps-progress ring - Digital clock style only, see Rossonero's
    // comment on these same constants for the full reasoning. TRACK is a
    // cooler dark tone than Rossonero/milan-personal's to sit better
    // against this project's blue-toned dusk photo rather than their warm
    // near-black red.
    const STEP_RING_RADIUS = 0.43;
    const STEP_RING_TICK_LEN = 0.024;
    const STEP_RING_SEGMENTS = 32;
    const STEP_RING_GREEN = 0x3ddc84;
    const STEP_RING_TRACK = 0x16323e;

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

    // Called by WatchFaceInputDelegate.onPress() - see garmin-shared-src/
    // WatchFaceInputDelegate.mc and SantoriniSunsetApp.mc's getInitialView().
    function toggleAltFields() as Void {
        _showAltFields = !_showAltFields;
        WatchUi.requestUpdate();
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
            drawStepRing(dc, w, h);
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

    // ---- Vector fallback: procedural Santorini sunset scene ---------------
    //
    // REPLACED entirely this round - you flagged that the original vector
    // fallback (layered mountain ranges, a snow cap, pine trees) "looks
    // nothing like the photo," which is a fair, literal description: it was
    // a generic alpine scene, not Santorini. This version is built from
    // pixel values actually sampled from resources/drawables/bg_photo.png
    // (not eyeballed) - sky/sea band colors, the sun's real x-position
    // (~0.35w, the brightest column in a horizontal scan at the horizon
    // row), and the dark windmill silhouette's real horizontal span
    // (~0.75-0.93w, confirmed as the darkest block in that same scan). Same
    // "solid color bands fake a gradient" technique the original used (no
    // native gradient fill in this API), just aimed at the right subject -
    // a sunset sky/sea gradient, a glowing sun low on the horizon, a
    // windmill silhouette, a dusk-toned building with an arched doorway,
    // and a terrace railing across the foreground, echoing the actual
    // photo's composition rather than a stand-in scene. Rendered and
    // compared side-by-side against the real photo before porting to
    // Monkey C - see verify/santorini_vector_v2_sidebyside.png. All
    // coordinates are fractions of screen width/height, same convention as
    // the rest of this file - hardcoded (not randomized) so the scene is
    // identical every redraw, no per-frame flicker.
    function drawVectorBackground(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        // Sky - four bands, cool blue-grey at top down through a warm gold
        // band where the sun's glow sits, matching the real photo's
        // vertical color progression.
        dc.setColor(0x9fb0b0, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h * 0.18);
        dc.setColor(0xc9c2a3, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.18, w, h * 0.12);
        dc.setColor(0xe3b478, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.30, w, h * 0.12);
        dc.setColor(0xb89478, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.42, w, h * 0.04);

        // Sun + glow: 4 closely-stepped rings (not widely-spaced) so each
        // ring's outer edge stays close to the surrounding band color -
        // reads as a soft brightening toward the center rather than a
        // hard-edged target. Centered at the real sampled sun position.
        var sunX = w * 0.35;
        var sunY = h * 0.44;
        dc.setColor(0xe3b980, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunX, sunY, w * 0.26);
        dc.setColor(0xe9c48c, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunX, sunY, w * 0.19);
        dc.setColor(0xf0d09a, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunX, sunY, w * 0.13);
        dc.setColor(0xf8e2b2, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunX, sunY, w * 0.07);

        // Sea - hazy grey-blue at the horizon, graduated darker toward the
        // foreground, same 4-band technique as the sky.
        dc.setColor(0x8d9092, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.46, w, h * 0.09);
        dc.setColor(0x767a7e, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.55, w, h * 0.15);
        dc.setColor(0x5c6167, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.70, w, h * 0.15);
        dc.setColor(0x454a52, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h * 0.85, w, h * 0.15);

        // Sun's reflection shimmer on the water - a short tapering warm
        // streak plus two broken dashes fading out below it.
        dc.setColor(0xc9a878, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [w * 0.335, h * 0.46], [w * 0.365, h * 0.46], [w * 0.35, h * 0.545]
        ]);
        dc.setPenWidth(2);
        dc.drawLine(w * 0.328, h * 0.485, w * 0.372, h * 0.485);
        dc.drawLine(w * 0.336, h * 0.515, w * 0.364, h * 0.515);

        // A couple of small boat silhouettes on the water, left-of-center.
        dc.setColor(0x141414, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [w * 0.155, h * 0.565], [w * 0.205, h * 0.565], [w * 0.197, h * 0.577]
        ]);
        dc.fillPolygon([
            [w * 0.253, h * 0.585], [w * 0.288, h * 0.585], [w * 0.280, h * 0.597]
        ]);

        // Windmill silhouette, right side - matches the real photo's dark
        // block (sampled as the darkest column span in a horizontal scan
        // at the horizon row, roughly 0.75-0.93 of the screen width).
        var dark = 0x141414;
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        var towerTopY = h * 0.42;
        var towerBaseY = h * 0.63;
        var towerCx = w * 0.815;
        var topHalfW = w * 0.035;
        var baseHalfW = w * 0.055;
        dc.fillPolygon([
            [towerCx - topHalfW, towerTopY], [towerCx + topHalfW, towerTopY],
            [towerCx + baseHalfW, towerBaseY], [towerCx - baseHalfW, towerBaseY]
        ]);
        // Conical roof.
        dc.fillPolygon([
            [towerCx - topHalfW * 1.3, towerTopY], [towerCx + topHalfW * 1.3, towerTopY],
            [towerCx, towerTopY - h * 0.045]
        ]);
        // Sail blades fanning up-left from a hub near the roof, like the
        // real windmill's spokes.
        var hubX = towerCx - topHalfW * 1.1;
        var hubY = towerTopY + h * 0.01;
        var bladeLen = w * 0.16;
        dc.setPenWidth(2);
        var bladeAngles = [-100.0, -75.0, -50.0, -25.0, 0.0];
        var i = 0;
        while (i < bladeAngles.size()) {
            var rad = Math.toRadians(bladeAngles[i]);
            var ex = hubX + bladeLen * Math.cos(rad);
            var ey = hubY + bladeLen * Math.sin(rad);
            dc.drawLine(hubX, hubY, ex, ey);
            i += 1;
        }

        // Foreground building silhouette, bottom-right - dusk-toned rather
        // than pure black (the real photo's building still catches some
        // light), with a rounded/arched dark-blue doorway.
        dc.setColor(0x2a2f38, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(w * 0.80, h * 0.60, w * 0.20, h * 0.25);
        var doorW = w * 0.045;
        var doorX = w * 0.855;
        var doorTop = h * 0.70;
        var doorH = h * 0.15;
        dc.setColor(0x16223a, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(doorX, doorTop, doorW, doorH, doorW * 0.5);

        // Terrace railing across the very bottom, same dark silhouette
        // tone as the windmill/boats - echoes the real photo's foreground
        // railing and gives the vector scene a grounded bottom edge
        // instead of ending mid-sea.
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        var railY = h * 0.90;
        dc.setPenWidth(3);
        dc.drawLine(0, railY, w, railY);
        dc.setPenWidth(2);
        var postX = 0.0;
        var postGap = w * 0.045;
        while (postX <= w) {
            dc.drawLine(postX, railY - h * 0.045, postX, railY);
            postX += postGap;
        }
        dc.fillRectangle(0, railY, w, h - railY);
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

        // Awake-only: the photo itself is already swapped for solid black
        // when asleep (see draw()'s burn-in fix), so there's no photo-
        // contrast problem then, but 11 more lit numerals plus a 12-mark
        // ring would still cost more of the AMOLED luminance budget than
        // this project can spare, matching its existing "decoration is
        // awake-only" pattern (top icon, date shadow, etc).
        if (awake) {
            drawAnalogDialMarks(dc, w, h);
        }

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        drawHandPolygon(dc, cx, cy, hourAngle, hourLen, w * 0.022, hourLen * 0.18);

        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        drawHandPolygon(dc, cx, cy, minuteAngle, minLen, w * 0.015, minLen * 0.15);

        // Seconds hand - same design as Rossonero's (reuses this project's
        // own 1Hz _tickTimer), but WITH the black-shadow-then-FG technique
        // drawAnalogDialMarks()/drawDate() already use, unlike the hour/
        // minute hands just above. Those two are thick enough (halfWidth
        // 0.022/0.015) to stay legible against the photo on their own
        // already-shipped without a shadow; this hand is much thinner
        // (0.006) to look distinctly different from them, and a line that
        // thin is exactly the kind of element that disappeared against the
        // photo before the shadow technique was added for the tick ring/
        // numbers - not shipping it unprotected here just because the
        // other two hands happen to get away without one.
        if (awake) {
            var secAngle = clockTime.sec * 6.0;
            var secLen = w * 0.34;
            var secRad = Math.toRadians(secAngle);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            drawHandPolygon(dc, cx + 1, cy + 1, secAngle, secLen, w * 0.006, secLen * 0.25);
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            drawHandPolygon(dc, cx, cy, secAngle, secLen, w * 0.006, secLen * 0.25);

            var tailX = cx - Math.sin(secRad) * secLen * 0.25;
            var tailY = cy + Math.cos(secRad) * secLen * 0.25;
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tailX + 1, tailY + 1, w * 0.012);
            dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tailX, tailY, w * 0.012);
        }

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, w * 0.022);
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, w * 0.022);
    }

    // 12 tick marks (all hours) plus the numbers 1-11, each drawn with a
    // 1px-offset black shadow copy first, exactly like drawDate()'s fix
    // above - a flat color can't stay legible across every part of a
    // photo (bright sky, dark sea, the windmill silhouette all pass
    // through this ring depending on the time of day), so a dark halo
    // behind bright FG is used instead of picking one "safe" color.
    function drawAnalogDialMarks(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var cx = w * 0.5;
        var cy = h * 0.5;
        var rNum = w * HOUR_NUM_RADIUS;
        var rOuter = w * HOUR_TICK_OUTER_RADIUS;
        var rInner = w * (HOUR_TICK_OUTER_RADIUS - HOUR_TICK_LEN);

        var n = 1;
        while (n <= 12) {
            var rad = Math.toRadians(n * 30.0);
            var sinA = Math.sin(rad);
            var cosA = Math.cos(rad);

            var outerX = cx + rOuter * sinA;
            var outerY = cy - rOuter * cosA;
            var innerX = cx + rInner * sinA;
            var innerY = cy - rInner * cosA;

            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            dc.drawLine(innerX + 1, innerY + 1, outerX + 1, outerY + 1);
            dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            dc.drawLine(innerX, innerY, outerX, outerY);

            if (n != 12) {
                var numX = cx + rNum * sinA;
                var numY = cy - rNum * cosA;
                var label = n.format("%d");
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
                dc.drawText(numX + 1, numY + 1, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER + Graphics.TEXT_JUSTIFY_VCENTER);
                dc.setColor(FG, Graphics.COLOR_TRANSPARENT);
                dc.drawText(numX, numY, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER + Graphics.TEXT_JUSTIFY_VCENTER);
            }
            n += 1;
        }
    }

    // Tapered "dauphine"-style hand - see Rossonero's comment on this
    // same function for the full reasoning; identical implementation.
    function drawHandPolygon(dc as Graphics.Dc, cx as Lang.Float, cy as Lang.Float, angleDeg as Lang.Float, length as Lang.Float, halfWidth as Lang.Float, tailLen as Lang.Float) as Void {
        var rad = Math.toRadians(angleDeg);
        var dirX = Math.sin(rad);
        var dirY = -Math.cos(rad);
        var perpX = Math.cos(rad);
        var perpY = Math.sin(rad);

        var tip = [cx + dirX * length, cy + dirY * length];
        var baseLeft = [cx + perpX * halfWidth, cy + perpY * halfWidth];
        var baseRight = [cx - perpX * halfWidth, cy - perpY * halfWidth];
        var tail = [cx - dirX * tailLen, cy - dirY * tailLen];

        dc.fillPolygon([baseLeft, tip, baseRight, tail]);
    }

    // ---- Stats: user-selectable badges (Settings > Field 1/2/3) -----------
    // Used to be fixed steps/heart rate/calories. Each of the three circles
    // now independently shows whatever FIELD_* the user picked in Settings
    // (defaults are still steps/heart rate/calories, so an existing install
    // that hasn't touched Settings looks identical to before this change).

    function drawStats(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var info = ActivityMonitor.getInfo();

        var field1;
        var field2;
        var field3;
        if (_showAltFields) {
            field1 = Properties.getValue("Field1Alt") as Lang.Number?;
            field2 = Properties.getValue("Field2Alt") as Lang.Number?;
            field3 = Properties.getValue("Field3Alt") as Lang.Number?;
            if (field1 == null) { field1 = FIELD_FLOORS; }
            if (field2 == null) { field2 = FIELD_STRESS; }
            if (field3 == null) { field3 = FIELD_MOVE_BAR; }
        } else {
            field1 = Properties.getValue("Field1") as Lang.Number?;
            field2 = Properties.getValue("Field2") as Lang.Number?;
            field3 = Properties.getValue("Field3") as Lang.Number?;
            if (field1 == null) { field1 = FIELD_STEPS; }
            if (field2 == null) { field2 = FIELD_HEART; }
            if (field3 == null) { field3 = FIELD_CALORIES; }
        }

        var cy = h * STATS_Y;
        var cyOuter = cy - h * STATS_OUTER_LIFT;
        var r = w * STATS_RADIUS;
        var spacing = w * STATS_SPACING;
        var cxMid = w * 0.5;

        drawStatBadge(dc, cxMid - spacing, cyOuter, r, field1, fieldText(field1, info));
        drawStatBadge(dc, cxMid, cy, r, field2, fieldText(field2, info));
        drawStatBadge(dc, cxMid + spacing, cyOuter, r, field3, fieldText(field3, info));
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
        } else if (fieldId == FIELD_MOVE_BAR) {
            return moveBarText(info);
        } else if (fieldId == FIELD_SUNRISE) {
            return sunriseText();
        } else if (fieldId == FIELD_SUNSET) {
            return sunsetText();
        }
        // FIELD_STEPS, and the fallback for any unrecognized value.
        var steps = (info.steps != null) ? info.steps : 0;
        return formatSteps(steps);
    }

    // See Rossonero's comment on this same function for the full reasoning;
    // identical implementation.
    function moveBarText(info as ActivityMonitor.Info) as Lang.String {
        var level = (info.moveBarLevel != null) ? info.moveBarLevel : 0;
        return level.format("%d") + "/5";
    }

    // See Rossonero's comment on this same function for the full reasoning;
    // identical implementation.
    function sunLocation() as Position.Location? {
        if ((Toybox has :Activity) && (Activity has :getActivityInfo)) {
            var actInfo = Activity.getActivityInfo();
            if (actInfo != null && actInfo.currentLocation != null) {
                return actInfo.currentLocation;
            }
        }
        if (Toybox has :Weather) {
            var conditions = Weather.getCurrentConditions();
            if (conditions != null && conditions.observationLocationPosition != null) {
                return conditions.observationLocationPosition;
            }
        }
        return null;
    }

    // See Rossonero's comment on these same functions for the full
    // reasoning (least field-tested part of this round); identical
    // implementation.
    function sunriseText() as Lang.String {
        var loc = sunLocation();
        if (loc == null || !(Toybox has :Weather) || !(Weather has :getSunrise)) {
            return "--";
        }
        var moment = Weather.getSunrise(loc, Time.now());
        return sunMomentText(moment);
    }

    function sunsetText() as Lang.String {
        var loc = sunLocation();
        if (loc == null || !(Toybox has :Weather) || !(Weather has :getSunset)) {
            return "--";
        }
        var moment = Weather.getSunset(loc, Time.now());
        return sunMomentText(moment);
    }

    function sunMomentText(moment as Time.Moment?) as Lang.String {
        if (moment == null) {
            return "--";
        }
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        var hour = info.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        return hour.format("%02d") + ":" + info.min.format("%02d");
    }

    // Steps-progress ring, same trig/design as Rossonero's - see that
    // project's comment on this same function for the full reasoning. WITH
    // the black-shadow-then-color technique (same reason as the seconds
    // hand above): this ring draws over the same photo/vector background
    // as drawAnalogDialMarks(), and it's thin ticks, exactly the shape
    // that needed the shadow fix there too.
    function drawStepRing(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number) as Void {
        var clockStyle = Properties.getValue("ClockStyle") as Lang.Number?;
        if (clockStyle != null && clockStyle == 1) {
            return;
        }
        var showRing = Properties.getValue("ShowStepRing") as Lang.Boolean?;
        if (showRing != null && !showRing) {
            return;
        }

        var info = ActivityMonitor.getInfo();
        var goal = (info.stepGoal != null) ? info.stepGoal : 0;
        if (goal <= 0) {
            return;
        }
        var steps = (info.steps != null) ? info.steps : 0;
        var progress = steps.toFloat() / goal;
        if (progress > 1.0) { progress = 1.0; }

        var cx = w * 0.5;
        var cy = h * 0.5;
        var r = w * STEP_RING_RADIUS;
        var tickLen = w * STEP_RING_TICK_LEN;

        var i = 0;
        while (i < STEP_RING_SEGMENTS) {
            var angleDeg = i * (360.0 / STEP_RING_SEGMENTS);
            var filled = (i.toFloat() / STEP_RING_SEGMENTS) <= progress;
            var rad = Math.toRadians(angleDeg);
            var dirX = Math.sin(rad);
            var dirY = -Math.cos(rad);
            var outerX = cx + dirX * r;
            var outerY = cy + dirY * r;
            var innerX = cx + dirX * (r - tickLen);
            var innerY = cy + dirY * (r - tickLen);

            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(filled ? 4 : 3);
            dc.drawLine(innerX + 1, innerY + 1, outerX + 1, outerY + 1);

            dc.setColor(filled ? STEP_RING_GREEN : STEP_RING_TRACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(filled ? 3 : 2);
            dc.drawLine(innerX, innerY, outerX, outerY);
            i += 1;
        }
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
            var stats = System.getSystemStats();
            Icons.drawBattery(dc, iconX, iconTopY + iconSize * 0.25, iconSize, stats.battery, ACCENT, ACCENT);
            // Solid badge background (0x0d1b26 fill above), not the raw
            // photo - no shadow-copy needed here, same as every other icon
            // in this function.
            if (stats.charging) {
                Icons.drawChargingBolt(dc, cx + r * 0.25, cy - r * 0.85, r * 0.30, CHARGE_COLOR);
            }
        } else if (fieldId == FIELD_STRESS) {
            Icons.drawStress(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_TEMPERATURE) {
            var cat = weatherIconCategory();
            if (cat == 0) {
                Icons.drawWeatherClear(dc, iconX, iconTopY, iconSize, ACCENT);
            } else if (cat == 1) {
                Icons.drawWeatherCloud(dc, iconX, iconTopY, iconSize, ACCENT);
            } else if (cat == 2) {
                Icons.drawWeatherRain(dc, iconX, iconTopY, iconSize, ACCENT);
            } else if (cat == 3) {
                Icons.drawWeatherSnow(dc, iconX, iconTopY, iconSize, ACCENT);
            } else if (cat == 4) {
                Icons.drawWeatherStorm(dc, iconX, iconTopY, iconSize, ACCENT);
            } else {
                Icons.drawTemperature(dc, iconX, iconTopY, iconSize, ACCENT);
            }
        } else if (fieldId == FIELD_WORLD_CLOCK) {
            Icons.drawWorldClock(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_MOVE_BAR) {
            var info2 = ActivityMonitor.getInfo();
            var level = (info2.moveBarLevel != null) ? info2.moveBarLevel : 0;
            Icons.drawMoveBar(dc, iconX, iconTopY, iconSize, level, ACCENT);
        } else if (fieldId == FIELD_SUNRISE) {
            Icons.drawSunrise(dc, iconX, iconTopY, iconSize, ACCENT);
        } else if (fieldId == FIELD_SUNSET) {
            Icons.drawSunset(dc, iconX, iconTopY, iconSize, ACCENT);
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
        var stats = System.getSystemStats();
        var battery = stats.battery;
        var charging = stats.charging;
        var text = battery.format("%d") + "%";
        var iconSize = w * 0.055;
        var textWidth = dc.getTextWidthInPixels(text, Graphics.FONT_XTINY);
        var boltSize = iconSize * 0.55;
        var boltGap = charging ? w * 0.015 : 0;
        var groupWidth = iconSize + w * 0.02 + textWidth + boltGap + (charging ? boltSize : 0);
        var x = w * 0.5 - groupWidth * 0.5;
        var battYCenter = h * BATTERY_Y;

        Icons.drawBattery(dc, x, battYCenter - iconSize * 0.5, iconSize, battery, DIM, ACCENT);
        dc.setColor(DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + iconSize + w * 0.02, battYCenter, Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_LEFT + Graphics.TEXT_JUSTIFY_VCENTER);
        if (charging) {
            // This readout sits directly over the photo (no badge fill
            // behind it), unlike the FIELD_BATTERY badge case above - gets
            // the same black-shadow-then-color technique as the seconds
            // hand/step ring, since it's exactly the kind of thin shape
            // that's disappeared against the photo before without it.
            var boltX = x + iconSize + w * 0.02 + textWidth + boltGap;
            var boltY = battYCenter - boltSize * 0.5;
            Icons.drawChargingBolt(dc, boltX + 1, boltY + 1, boltSize, Graphics.COLOR_BLACK);
            Icons.drawChargingBolt(dc, boltX, boltY, boltSize, CHARGE_COLOR);
        }
    }

    // See rossonero/RossoneroView.mc's weatherIconCategory() for the full
    // reasoning (54 CONDITION_* codes mapped to 5 icon buckets) - identical
    // logic, ported as-is.
    function weatherIconCategory() as Lang.Number {
        if (!(Toybox has :Weather)) { return -1; }
        var conditions = Weather.getCurrentConditions();
        if (conditions == null || conditions.condition == null) { return -1; }
        var c = conditions.condition;
        if (c == Weather.CONDITION_CLEAR || c == Weather.CONDITION_FAIR ||
            c == Weather.CONDITION_PARTLY_CLEAR || c == Weather.CONDITION_MOSTLY_CLEAR) {
            return 0;
        }
        if (c == Weather.CONDITION_THUNDERSTORMS || c == Weather.CONDITION_SCATTERED_THUNDERSTORMS ||
            c == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS ||
            c == Weather.CONDITION_TORNADO || c == Weather.CONDITION_HURRICANE ||
            c == Weather.CONDITION_TROPICAL_STORM || c == Weather.CONDITION_WINDY ||
            c == Weather.CONDITION_SQUALL) {
            return 4;
        }
        if (c == Weather.CONDITION_SNOW || c == Weather.CONDITION_LIGHT_SNOW || c == Weather.CONDITION_HEAVY_SNOW ||
            c == Weather.CONDITION_CHANCE_OF_SNOW || c == Weather.CONDITION_FLURRIES ||
            c == Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW || c == Weather.CONDITION_WINTRY_MIX ||
            c == Weather.CONDITION_LIGHT_RAIN_SNOW || c == Weather.CONDITION_HEAVY_RAIN_SNOW ||
            c == Weather.CONDITION_RAIN_SNOW || c == Weather.CONDITION_CHANCE_OF_RAIN_SNOW ||
            c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW || c == Weather.CONDITION_FREEZING_RAIN ||
            c == Weather.CONDITION_SLEET || c == Weather.CONDITION_ICE_SNOW || c == Weather.CONDITION_ICE ||
            c == Weather.CONDITION_HAIL) {
            return 3;
        }
        if (c == Weather.CONDITION_RAIN || c == Weather.CONDITION_LIGHT_RAIN || c == Weather.CONDITION_HEAVY_RAIN ||
            c == Weather.CONDITION_SCATTERED_SHOWERS || c == Weather.CONDITION_LIGHT_SHOWERS ||
            c == Weather.CONDITION_SHOWERS || c == Weather.CONDITION_HEAVY_SHOWERS ||
            c == Weather.CONDITION_CHANCE_OF_SHOWERS || c == Weather.CONDITION_DRIZZLE ||
            c == Weather.CONDITION_UNKNOWN_PRECIPITATION || c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN) {
            return 2;
        }
        if (c == Weather.CONDITION_UNKNOWN) { return -1; }
        return 1;
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
