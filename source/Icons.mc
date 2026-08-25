using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

//
// Icons.mc - small vector icons drawn with basic Graphics.Dc primitives only.
// Same technique as Ritmo's Icons.mc (no bitmaps, no text) - see that file
// for the reasoning. Steps/floors/battery/heart/flame copied over unchanged
// since they're generic, not theme-specific; drawWindmill is new for this
// face's top-of-screen glyph.
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

    // Small windmill line icon - the top-of-face glyph for this design,
    // echoing the Santorini windmill in the background photo. Plain
    // outline (drawLine segments), not filled, so it reads as a small
    // logo mark rather than competing with the background art. x,y is the
    // top-left of a size x size box; the sail hub sits a little above
    // center so there's room for the tower body below it.
    function drawWindmill(dc as Graphics.Dc, x as Lang.Numeric, y as Lang.Numeric, size as Lang.Numeric, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        var hubX = x + size * 0.42;
        var hubY = y + size * 0.30;
        var sail = size * 0.42;

        // Four sails as simple lines from the hub, roughly like an X/+.
        dc.drawLine(hubX, hubY, hubX - sail * 0.75, hubY - sail);
        dc.drawLine(hubX, hubY, hubX + sail * 0.85, hubY - sail * 0.55);
        dc.drawLine(hubX, hubY, hubX + sail * 0.55, hubY + sail * 0.85);
        dc.drawLine(hubX, hubY, hubX - sail * 0.55, hubY + sail * 0.55);
        dc.fillCircle(hubX, hubY, size * 0.045);

        // Tower body (trapezoid) below the hub, with a small dome cap.
        var bodyTop = hubY + size * 0.10;
        var bodyBottom = y + size;
        var topHalf = size * 0.16;
        var botHalf = size * 0.24;
        dc.drawLine(hubX - topHalf, bodyTop, hubX - botHalf, bodyBottom);
        dc.drawLine(hubX + topHalf, bodyTop, hubX + botHalf, bodyBottom);
        dc.drawLine(hubX - botHalf, bodyBottom, hubX + botHalf, bodyBottom);
        dc.fillPolygon([
            [hubX - topHalf * 1.3, bodyTop],
            [hubX + topHalf * 1.3, bodyTop],
            [hubX, bodyTop - size * 0.10]
        ]);
    }
}
