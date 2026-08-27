using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

//
// Icons.mc - small vector icons drawn with basic Graphics.Dc primitives only.
// Same technique as Ritmo's Icons.mc (no bitmaps, no text) - see that file
// for the reasoning. Steps/floors/battery/heart/flame copied over unchanged
// since they're generic, not theme-specific; drawChurch is new for this
// face's top-of-screen glyph (replaced an earlier generic windmill glyph -
// a blue-domed church is a much more specifically-Santorini symbol).
//
module Icons {

    function drawSteps(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var soleW = size * 0.55;
        var soleH = size * 0.75;
        dc.fillRoundedRectangle(x + size * 0.20, y + size * 0.20, soleW, soleH, soleW * 0.45);
        var toeR = size * 0.10;
        dc.fillCircle(x + size * 0.30, y + size * 0.14, toeR);
        dc.fillCircle(x + size * 0.50, y + size * 0.08, toeR * 0.9);
        dc.fillCircle(x + size * 0.68, y + size * 0.14, toeR * 0.8);
    }

    function drawBattery(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, percent as Lang.Numeric, outlineColor as Lang.Number, fillColor as Lang.Number) as Void {
        var w = size;
        var h = size * 0.5;
        var nubW = size * 0.08;
        var nubH = h * 0.4;

        dc.setColor(outlineColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, y, w - nubW, h, 3);
        dc.fillRectangle(x + w - nubW, y + (h - nubH) / 2, nubW, nubH);

        var pct = percent;
        if (pct < 0) { pct = 0; }
        if (pct > 100) { pct = 100; }
        var pad = 3;
        var innerW = (w - nubW - pad * 2) * (pct / 100.0);
        if (innerW > 0) {
            dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + pad, y + pad, innerW, h - pad * 2);
        }
    }

    function drawHeart(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var r = size * 0.28;
        dc.fillCircle(x + size * 0.32, y + size * 0.36, r);
        dc.fillCircle(x + size * 0.68, y + size * 0.36, r);
        dc.fillPolygon([
            [x + size * 0.06, y + size * 0.40],
            [x + size * 0.94, y + size * 0.40],
            [x + size * 0.50, y + size * 0.94]
        ]);
    }

    function drawFlame(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [x + size * 0.50, y + size * 0.02],
            [x + size * 0.78, y + size * 0.42],
            [x + size * 0.66, y + size * 0.40],
            [x + size * 0.80, y + size * 0.70],
            [x + size * 0.50, y + size * 0.98],
            [x + size * 0.20, y + size * 0.70],
            [x + size * 0.34, y + size * 0.40],
            [x + size * 0.22, y + size * 0.42]
        ]);
    }

    // Six new icons for the selectable stat-badge fields added this round
    // (see SantoriniSunsetView.mc's resolveFieldText/drawStats) - kept to
    // the same 1-3-shape simplicity as steps/heart/flame above, since the
    // badge icon slot is tiny. Sanity-checked together at the badge's
    // actual icon size in Python/PIL before writing these - all six read
    // as distinct shapes even that small.

    function drawDistance(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var y0 = y + size * 0.5;
        dc.drawLine(x + size * 0.05, y0, x + size * 0.35, y0);
        dc.drawLine(x + size * 0.50, y0, x + size * 0.72, y0);
        dc.fillPolygon([
            [x + size * 0.72, y0 - size * 0.14],
            [x + size * 0.72, y0 + size * 0.14],
            [x + size * 0.95, y0]
        ]);
    }

    function drawFloors(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var stepW = size * 0.26;
        var stepH = size * 0.22;
        var gap = size * 0.02;
        var i = 0;
        while (i < 3) {
            var sx = x + size * 0.08 + i * (stepW + gap);
            var sy = y + size - (i + 1) * (stepH + gap) + gap;
            dc.fillRectangle(sx, sy, stepW, (y + size) - sy);
            i += 1;
        }
    }

    function drawActiveMinutes(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var cx = x + size * 0.5;
        var cy = y + size * 0.55;
        var r = size * 0.36;
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, r);
        dc.fillRectangle(cx - size * 0.09, y + size * 0.02, size * 0.18, size * 0.12);
        dc.drawLine(cx, cy, cx, cy - r * 0.7);
    }

    function drawStress(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var y0 = y + size * 0.55;
        dc.drawLine(x + size * 0.05, y0, x + size * 0.28, y0);
        dc.drawLine(x + size * 0.28, y0, x + size * 0.40, y0 - size * 0.30);
        dc.drawLine(x + size * 0.40, y0 - size * 0.30, x + size * 0.55, y0 + size * 0.30);
        dc.drawLine(x + size * 0.55, y0 + size * 0.30, x + size * 0.68, y0);
        dc.drawLine(x + size * 0.68, y0, x + size * 0.95, y0);
    }

    function drawTemperature(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var tubeW = size * 0.22;
        var tubeX = x + size * 0.5 - tubeW * 0.5;
        var tubeTop = y + size * 0.05;
        var tubeBottom = y + size * 0.62;
        dc.fillRoundedRectangle(tubeX, tubeTop, tubeW, tubeBottom - tubeTop, tubeW * 0.5);
        var bulbR = size * 0.20;
        dc.fillCircle(x + size * 0.5, y + size * 0.80, bulbR);
    }

    // Simple circle-with-crosshair "globe" glyph - avoids Dc.drawEllipse
    // (an untested API call here) in favor of drawCircle/drawLine, both
    // already proven throughout this file.
    function drawWorldClock(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var cx = x + size * 0.5;
        var cy = y + size * 0.5;
        var r = size * 0.42;
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy, r);
        dc.setPenWidth(1);
        dc.drawLine(cx, cy - r, cx, cy + r);
        dc.drawLine(cx - r, cy, cx + r, cy);
    }

    // Small windmill line icon - the top-of-face glyph for this design,
    // echoing the Santorini windmill in the background photo. Plain
    // outline (drawLine segments), not filled, so it reads as a small
    // logo mark rather than competing with the background art. x,y is the
    // top-left of a size x size box; the sail hub sits a little above
    // center so there's room for the tower body below it.
    // A whitewashed Cycladic building with the classic blue dome and a
    // small cross - swapped in for the earlier generic windmill glyph,
    // which wasn't actually Santorini-specific. bodyColor/domeColor are
    // separate so the awake frame can use the real white/blue look while
    // the always-on frame still passes a single dark tone for both
    // (keeps the AMOLED burn-in luminance fix in draw()/drawTopIcon()
    // intact - see SantoriniSunsetView.mc's comments on that).
    //
    // Prototyped and visually checked in Python/PIL before writing this -
    // same process that fixed rossonero's soccer ball after three blind
    // vector attempts there. Monkey C's Dc has no filled-arc primitive, so
    // the dome is a 9-point polygon approximating a semicircle (cos/sin at
    // 22.5-degree steps, same trig approach as drawPerimeterTicks in the
    // view files) rather than a true arc - at this icon's actual on-screen
    // size the facets aren't visible, confirmed in the same rendered check.
    function drawChurch(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, bodyColor as Lang.Number, domeColor as Lang.Number) as Void {
        var bodyW = size * 0.60;
        var bodyH = size * 0.38;
        var bodyX = x + size * 0.5 - bodyW * 0.5;
        var bodyY = y + size * 0.62;
        dc.setColor(bodyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bodyX, bodyY, bodyW, bodyH, size * 0.05);

        // Small arched doorway notch.
        var doorW = size * 0.14;
        var doorH = size * 0.20;
        var doorX = x + size * 0.5 - doorW * 0.5;
        var doorY = bodyY + bodyH - doorH;
        dc.setColor(domeColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(doorX, doorY, doorW, doorH, doorW * 0.5);

        // Drum connecting the dome to the roofline.
        var drumW = size * 0.28;
        var drumH = size * 0.10;
        var drumX = x + size * 0.5 - drumW * 0.5;
        var drumY = bodyY - drumH;
        dc.setColor(bodyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(drumX, drumY, drumW, drumH);

        // Dome: 9-point semicircle polygon (180 to 360 degrees in 22.5-
        // degree steps), flat edge sitting on the drum's top edge.
        var domeR = size * 0.20;
        var domeCx = x + size * 0.5;
        var domeCy = drumY;
        dc.setColor(domeColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [domeCx - domeR, domeCy],
            [domeCx - domeR * 0.9239, domeCy - domeR * 0.3827],
            [domeCx - domeR * 0.7071, domeCy - domeR * 0.7071],
            [domeCx - domeR * 0.3827, domeCy - domeR * 0.9239],
            [domeCx, domeCy - domeR],
            [domeCx + domeR * 0.3827, domeCy - domeR * 0.9239],
            [domeCx + domeR * 0.7071, domeCy - domeR * 0.7071],
            [domeCx + domeR * 0.9239, domeCy - domeR * 0.3827],
            [domeCx + domeR, domeCy]
        ]);

        // Tiny cross on top.
        var crossY = domeCy - domeR;
        dc.setPenWidth(2);
        dc.drawLine(domeCx, crossY - size * 0.09, domeCx, crossY - size * 0.01);
        dc.drawLine(domeCx - size * 0.03, crossY - size * 0.065, domeCx + size * 0.03, crossY - size * 0.065);
    }

    // Shared 9-point semicircle-polygon helper (same math as drawChurch's
    // dome above) so drawSantoriniScene below isn't repeating that literal
    // point array three times for three domes.
    function fillDome(dc as Graphics.Dc, cx as Lang.Numeric, cy as Lang.Numeric, r as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [cx - r, cy],
            [cx - r * 0.9239, cy - r * 0.3827],
            [cx - r * 0.7071, cy - r * 0.7071],
            [cx - r * 0.3827, cy - r * 0.9239],
            [cx, cy - r],
            [cx + r * 0.3827, cy - r * 0.9239],
            [cx + r * 0.7071, cy - r * 0.7071],
            [cx + r * 0.9239, cy - r * 0.3827],
            [cx + r, cy]
        ]);
    }

    // One building for drawSantoriniScene below - same body/drum/dome/cross
    // shape as drawChurch, just parameterized so two of these plus a
    // backdrop dome can be composed into a small multi-building scene.
    function drawBuilding(dc as Graphics.Dc, cx as Lang.Numeric, baseY as Lang.Numeric, size as Lang.Numeric, bodyColor as Lang.Number, domeColor as Lang.Number, hasDoor as Lang.Boolean, hasWindow as Lang.Boolean) as Void {
        var bodyW = size * 0.62;
        var bodyH = size * 0.42;
        var bodyX = cx - bodyW * 0.5;
        var bodyY = baseY - bodyH;
        dc.setColor(bodyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bodyX, bodyY, bodyW, bodyH, size * 0.06);

        if (hasDoor) {
            var doorW = size * 0.16;
            var doorH = size * 0.22;
            var doorX = cx - doorW * 0.5;
            var doorY = bodyY + bodyH - doorH;
            dc.setColor(domeColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(doorX, doorY, doorW, doorH, doorW * 0.5);
        }
        if (hasWindow) {
            var winR = size * 0.07;
            var winCy = bodyY + bodyH * 0.35;
            fillDome(dc, cx, winCy, winR, domeColor);
            dc.setColor(domeColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - winR, winCy, winR * 2, winR * 0.9);
        }

        var drumW = size * 0.32;
        var drumH = size * 0.11;
        var drumX = cx - drumW * 0.5;
        var drumY = bodyY - drumH;
        dc.setColor(bodyColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(drumX, drumY, drumW, drumH);

        var domeR = size * 0.22;
        fillDome(dc, cx, drumY, domeR, domeColor);

        var crossY = drumY - domeR;
        dc.setColor(domeColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx, crossY - size * 0.10, cx, crossY - size * 0.01);
        dc.drawLine(cx - size * 0.033, crossY - size * 0.07, cx + size * 0.033, crossY - size * 0.07);
    }

    // Richer awake-only version of the icon, closer to the classic multi-
    // building Santorini postcard shot you sent: a smaller building with an
    // arched window on the left, the main domed building on the right, and
    // a soft teal/green dome peeking from behind both - the third roofline
    // in that reference. Awake-only: prototyped this at the icon's actual
    // tiny on-screen size in the same dark tone the always-on frame would
    // use, and three overlapping domes in near-black gray just reads as a
    // blob at that size - no amount of color tuning fixed it. drawChurch
    // above (a single building, already confirmed legible dimmed) is what
    // drawTopIcon uses for the always-on frame instead - same pattern this
    // project already uses for the background photo (full detail only
    // when awake).
    function drawSantoriniScene(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, bodyColor as Lang.Number, domeColor as Lang.Number, bgDomeColor as Lang.Number) as Void {
        var baseY = y + size;

        var bgR = size * 0.30;
        var bgCx = x + size * 0.46;
        var bgCy = baseY - size * 0.56;
        fillDome(dc, bgCx, bgCy, bgR, bgDomeColor);

        drawBuilding(dc, x + size * 0.24, baseY, size * 0.60, bodyColor, domeColor, false, true);
        drawBuilding(dc, x + size * 0.58, baseY, size * 0.85, bodyColor, domeColor, true, false);
    }

    // Two more icons for the "second hand / move bar / sunrise-sunset /
    // step ring" round - see rossonero/Icons.mc's comments on these same
    // functions for the full reasoning; identical implementation. Both
    // only ever get called against this project's own opaque dark badge
    // fill (same as every other stat-badge icon here), not directly over
    // the photo, so neither needs the shadow-copy technique the dial ticks/
    // numbers use - see View.mc for where that technique IS needed this
    // round (the second hand and the step ring, both drawn over the photo).
    function drawMoveBar(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, level as Lang.Number, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var barW = size * 0.15;
        var gap = size * 0.06;
        var baseY = y + size;
        var heights = [0.35, 0.5, 0.65, 0.8, 1.0];
        var i = 0;
        while (i < 5) {
            var bx = x + i * (barW + gap);
            var bh = size * 0.55 * heights[i];
            if (i < level) {
                dc.fillRectangle(bx, baseY - bh, barW, bh);
            } else {
                dc.setPenWidth(1);
                dc.drawRectangle(bx, baseY - bh, barW, bh);
            }
            i += 1;
        }
    }

    function drawSunHorizon(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number, rising as Lang.Boolean) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var horizonY = y + size * 0.62;
        dc.setPenWidth(2);
        dc.drawLine(x + size * 0.02, horizonY, x + size * 0.62, horizonY);
        var sunR = size * 0.22;
        var scx = x + size * 0.32;
        dc.fillCircle(scx, horizonY, sunR);

        var ax = x + size * 0.82;
        if (rising) {
            dc.fillPolygon([
                [ax, y + size * 0.05],
                [ax - size * 0.16, y + size * 0.42],
                [ax + size * 0.16, y + size * 0.42]
            ]);
        } else {
            dc.fillPolygon([
                [ax, y + size * 0.42],
                [ax - size * 0.16, y + size * 0.05],
                [ax + size * 0.16, y + size * 0.05]
            ]);
        }
    }

    function drawSunrise(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        drawSunHorizon(dc, x, y, size, color, true);
    }

    function drawSunset(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        drawSunHorizon(dc, x, y, size, color, false);
    }
}
