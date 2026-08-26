# Santorini Sunset - a Connect IQ watch face

A Garmin watch face built around your own Santorini sunset photo - a
small windmill glyph and date at the top, a large two-tone time readout
(hour white, minute/colon blue), three stat badges (steps, heart rate,
calories) sitting near the bottom, and a small battery readout. A
procedural vector mountain-scene illustration is available as a
lighter-weight alternative background via the "Background" setting.

This project started as "Arctic Peak" (a generic vector mountain scene)
before you sent your actual Santorini photo and asked for the theme
changed to match it - renamed throughout (folder, classes, app name) once
that direction was set. Same caveat as the other projects in this set: I
(Claude) wrote this without access to the SDK compiler or a real/
simulated device - treat it as a carefully-reasoned first draft, not
tested software.

## Second fix carried over from Rossonero

Rossonero shipped with the exact same `TIME_Y`/`STATS_Y`/`STATS_RADIUS`
values this project still has (they were originally copied from here),
and Rossonero's own screenshot showed those values let the time overlap
the stat badges - `FONT_NUMBER_HOT` renders taller than assumed. This
project almost certainly has the identical bug, just not yet seen in a
screenshot. Applied the same correction proactively: `TIME_Y` 0.40 ->
0.32, `STATS_Y`/`STATS_RADIUS` and `BATTERY_Y` adjusted to match. Not
confirmed here specifically - worth checking on your first build of this
project too.

## Fix carried over from Rossonero

Rossonero (which shares this exact stat-badge code) turned up a real bug
in a screenshot: the numbers were rendering too close to each badge's
bottom edge because the text was top-anchored with a guessed offset
rather than actually centered. Fixed here too, proactively, before it
showed up in this project's own screenshot - see `rossonero/README.md`'s
"Fixes after the first real build" for the full explanation
(`TEXT_JUSTIFY_VCENTER` plus a small radius bump).

## Background: photo (default) vs vector

Both are fully wired in - pick with the "Background" setting.

- **Photo (default):** your Santorini photo, cropped to a square around
  the windmill/sunset/cruise ship (the original was 1740x1305; the crop
  keeps both the sunset point and the windmill in frame rather than a
  plain center-crop) and resized to 440x440. Color-quantized to a
  200-color adaptive palette to keep the resource small - the saved file
  is about 80KB. Drawn with `Dc.drawScaledBitmap()` so it fills the
  screen exactly on every device in the product list regardless of that
  device's actual resolution (this is why `minApiLevel` is 4.0.0 here,
  see manifest.xml).
- **Vector illustration:** the original procedural mountain scene
  (layered polygons, no image resource) - lighter on memory, no photo
  needed. Kept as the fallback option rather than deleted.

**Why 440x440 and a 200-color palette, not the original photo at full
size/quality:** per a Garmin developer forum thread, the Venu 2 (CIQ4)'s
watch-face app-memory limit is roughly 123KB, and CIQ4 devices draw
images from a separate but also finite shared graphics pool. A full-
resolution, full-color photo risks that budget for real; 440x440 covers
every device in the product list (the largest, fr965, is 454x454) once
scaled per-device, and reduced color depth is roughly what compiled
image resources get stored as anyway, so quantizing ahead of time keeps
the *file* small without changing what actually shows up on-screen much.
Worth confirming actual memory use in the simulator's memory profiler on
your first build regardless - this was reasoned through, not measured.

## Layout - not yet verified live

Same layout constants as the original Arctic Peak build (see the
constants block in `source/SantoriniSunsetView.mc` for the chord-width
paper-math reasoning) - unaffected by the photo/rename, since only the
background content changed, not the screen positions.

## Building

Same process as the other projects: open this folder in VS Code with the
Monkey C extension, F5 to run in the simulator.

## Before you publish (if submitting to the Connect IQ Store)

- [ ] Confirm the photo is actually yours to redistribute (your own
      photo, not downloaded from somewhere you don't have rights to) -
      not a concern for sideloading to your own watch, but worth
      confirming before a public Store submission.
- [ ] Check the stat-badge row and windmill glyph against the bezel on a
      real screenshot.
- [ ] Confirm on the actual Venu 2 hardware, not just the simulator.

## What's in here

```
manifest.xml              App metadata, target devices (minApiLevel 4.0.0)
monkey.jungle              Build file
resources/
  strings/strings.xml       App name + settings labels
  settings/properties.xml   User-configurable settings (storage/defaults)
  settings/settings.xml     Settings screen UI (includes Background)
  drawables/                Launcher icon + bg_photo.png (your Santorini photo)
source/
  SantoriniSunsetApp.mc      App entry point
  SantoriniSunsetView.mc     All drawing logic (photo + vector backgrounds)
  Icons.mc                   Small vector icons (steps/heart/flame/battery/windmill)
```
