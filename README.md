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

## Ninth fix: on-device "Customize" settings, no phone needed

You noticed some of your other installed watch faces show a gear icon/
"Customize" option when you hold the button in watch-face selection mode,
letting you edit their settings right on the watch, and asked if we could
do that here too for the 3 stat circles.

Good news: yes, and it's a real, separate Connect IQ API
(`AppBase.getSettingsView()`, since API 3.2.0 - this project targets
4.0.0, no issue) - researched properly against Garmin's docs and forum
threads before writing this rather than guessing (see `source/
SettingsMenu.mc`'s header comment for the sourcing). Crucially, it's
**independent of the phone-based Settings from settings.xml/
properties.xml** (the 8th-round feature below): this new one works while
sideloaded, no store/Beta publication required, which is exactly the
"test it right now" path you have. Hold the button in watch-face
selection mode, select this one, and you should see "Customize" alongside
"Apply"/"Delete" - selecting it opens a menu: Left/Middle/Right circle
(each showing its current field, tap to change) and World Clock Offset.
Both mechanisms read/write the exact same underlying Properties, so they
can't get out of sync - whichever one you used most recently is what's
showing.

One real implementation detail worth flagging: Garmin's own bundled
"Analog" sample app (the canonical example most forum posts point to for
this feature) wraps its menu in an extra intermediate View, and multiple
independent bug reports trace a real double-back-press glitch on actual
hardware directly to that wrapper pattern. Not something I could catch
myself without a device, so this was deliberately built flatter instead -
`getSettingsView()` returns the real top-level menu/delegate pair
directly, matching the pattern a couple of forum threads confirmed
working cleanly, rather than copying Analog's structure.

The world-clock offset submenu shows plain "UTC+2"-style labels rather
than the city-name hints ("UTC+2 (Athens)") the phone-based Settings
show - simplification to keep this on-device submenu's code (and the
watch's tiny screen) simple, the offset number is what actually matters
functionally.

Like everything else in this project, this has not run on real hardware
or the simulator - the `Menu2`/`MenuItem`/`Menu2InputDelegate` API calls
are verified against Garmin's actual API docs and real forum code
samples, not guessed, but this is genuinely the largest chunk of
previously-unused API surface added in one round this whole project. If
"Customize" doesn't show up at all after a build, or a submenu comes back
empty, that's the first place to look.

## Eighth fix: user-selectable stat-badge data, plus a world clock

You asked for the 3 stat circles to be customizable, and floated a
secondary screen as an option "if it's too hard" - otherwise just
settings. A quick look at Connect IQ's watch-face touch/tap support
didn't turn up a clean path to a second screen for an always-on watch
face without meaningfully more risk in code I can't compile-test, so per
your own stated fallback this went the settings route instead: each of
the 3 circles is now independently configurable in Settings (Left/
Middle/Right circle shows...) rather than fixed to steps/heart rate/
calories. Defaults are still steps/heart rate/calories, so this looks
identical to before until you actually open Settings.

New options beyond the original three: distance (today, converts to km
or mi from your device's unit setting), floors climbed, active minutes,
battery %, stress score, temperature, and a world clock. Two of those are
worth flagging honestly rather than presenting as sure things, since none
of this has run on a real device or simulator:

- **Temperature** is not a physical sensor on any of these watches - it
  comes from `Weather.getCurrentConditions()`, which needs a Bluetooth-
  connected phone running Connect. **Correction, confirmed against a real
  compiler run:** the manifest originally declared a `Weather` permission,
  guessed from Garmin's usual module-name convention since I couldn't
  fully verify it from this sandbox - and monkeybrains rejected it outright
  ("Invalid permission provided: Weather") the first time you actually
  built this. Checked Garmin's actual `Toybox.Weather`/`CurrentConditions`
  docs afterward: no permission is needed at all for `.temperature` (the
  field this code reads) - the only fields that need a permission are
  `observationLocationPosition`/`observationLocationName`, which need
  `Positioning` instead. The `<iq:permissions>` block is removed from
  `manifest.xml` entirely now. No phone connected, and the field falls
  back to "--" rather than crashing.
- **World clock** is a fixed whole-hour UTC offset (new "World Clock
  Offset" setting, -12 to +14), not a real timezone lookup - Monkey C has
  no on-device timezone database, so there's no way to do automatic DST
  or half-hour-offset zones (India, Nepal, etc.) without one. If you
  pick, say, "UTC-5 (New York)" it'll drift an hour off during whichever
  side of DST New York isn't currently observing, until you manually
  change the offset.

New tiny icons for each of the new fields (distance arrow, stair-step
floors, stopwatch, zigzag stress line, thermometer, clock-face) were
prototyped in Python at the actual on-screen badge size before being
ported to Monkey C vector code, same verification habit as the church-
icon rounds below - see `tools/` if you want to see the mockups. Battery
reuses the existing battery icon rather than a new one.

## Seventh fix: the date was nearly invisible against the sky

**Note on this fix and your last screenshot:** if the date/day still
looked pale blue in the screenshot you sent after this landed, that
screenshot was very likely taken from a build compiled before this fix
was in the code - the fix below is already in the source (drawDate() now
draws a black shadow copy behind bright-white FG text), it just needs a
rebuild from the latest zip to actually show up on the watch. Worth
double-checking against the newest build before assuming the fix didn't
work.

You flagged this directly - the pale blue-gray date text was hard to read
against the photo. Checked why rather than just guessing at a new color:
sampled the actual `bg_photo.png` pixels at `DATE_Y` and the old `DIM`
color (`0xc9d6dd`) turned out to be almost exactly the same *brightness*
as the sky there (a warm cream, roughly RGB 216,200,161), just a
different hue - nearly invisible for exactly the reason low-contrast text
usually is.

A single flat color can't reliably win against a photo background either
way (dark sea, bright sky, and the dark windmill silhouette all pass
through this row depending on layout), so instead of swapping in a
different guessed color, `drawDate()` (awake only) now draws a small dark
shadow copy of the text first, then the real text in `FG` (bright white -
same tone the time's hour digits already use, and those read fine in your
screenshot) on top. Rendered this against an actual crop of your photo at
the real `DATE_Y` position before shipping - reads clearly now, checked
side-by-side against the old color and against plain white with no
shadow (better than the old color, but the shadow is what makes it solid
everywhere). Asleep is unchanged (solid black background there already,
so a shadow would just be extra always-on pixels for no benefit).

Also spot-checked the time digits (the next most obvious "text over
photo" spot) against the real photo the same way - already reads clearly
as-is, no change needed there.

## Sixth change: the church became a small multi-building scene when awake

You sent a reference photo - a classic Santorini postcard shot with two
whitewashed buildings, blue domes, arched windows, and a teal/green dome
roofline peeking from behind. Closer match now: `Icons.drawSantoriniScene`
draws a smaller building on the left (arched window, its own small blue
dome) and the original church on the right (door, dome, cross), with a
soft teal dome (`BG_DOME = 0x8cc3aa`) peeking out from behind both -
that third color/shape is the piece that makes it read as a little scene
rather than a single building.

This is **awake-mode only**. Checked it at the icon's actual tiny on-
screen size in the always-on frame's near-black gray tone before
deciding, and three overlapping domes just collapse into an
indistinguishable blob at that size and color depth - no color tuning
fixed it, there just isn't enough resolution/contrast budget for that
much shape when everything's forced dark for the burn-in luminance fix
above. So the always-on frame still uses the simpler single-building
`Icons.drawChurch` (unchanged, already confirmed legible dimmed) -
exactly the same "less detail when asleep" pattern this project already
uses for the background photo. `drawTopIcon` now branches on `awake` to
pick between the two.

Prototyped and visually checked in Python/PIL (zoomed and at actual icon
size, in both the target awake colors and the always-on dim tone) before
writing any Monkey C, same as the single-building version - that's what
caught the always-on blob problem before it shipped. Same bounding box as
before (`ICON_Y`/`ICON_SIZE` unchanged, backdrop dome's top edge stays
inside the icon box with room to spare), so no layout risk - re-checked
against the date position, still ~0.035 clear. Not yet confirmed in an
actual simulator screenshot.

## Fifth change: windmill glyph replaced with a blue-domed church

You pointed out the windmill wasn't really a Santorini-specific symbol -
the blue-domed whitewashed church is the much more iconic one, so
`Icons.drawWindmill` is gone, replaced by `Icons.drawChurch`: a rounded
white building body, a small arched doorway notch, a drum, a blue dome,
and a tiny cross on top - `FG`/`ACCENT` (already this project's white/sky-
blue palette) when awake, a single dark tone for both when asleep to keep
the burn-in luminance fix above intact.

Learned from the soccer-ball saga in rossonero (three failed blind vector
attempts before switching to a visually-checked bitmap): prototyped this
one in Python/PIL first, at both a zoomed-in size and the icon's actual
tiny on-screen size, in both the awake color scheme and the dimmed
always-on tone, before writing a line of Monkey C - all four looked right
before any code was written. Monkey C's `Dc` has no filled-arc primitive,
so the dome is a 9-point polygon approximating a semicircle rather than a
true arc; confirmed in the same rendered check that the facets aren't
visible at this icon's actual size. Same bounding box as the old windmill
(`ICON_Y`/`ICON_SIZE` unchanged), so no layout risk - checked against the
date text position too, ~0.035 clear.

Still not confirmed in an actual simulator screenshot - worth a look on
your next build like everything else here.

## Fourth fix: always-on mode was exceeding the AMOLED burn-in luminance budget

Your simulator flagged this directly: "Screen update will be shutoff due to
display luminance exceeding 10% of maximum display luminance in low power
mode" (measured at 10.81%). This was a real bug, not a false alarm, and it
was specific to this project - Rossonero and milan-personal don't have it.

**Root cause:** `draw()` cleared the whole screen to `0x0a1826` (a dark
navy) unconditionally, in both awake and always-on states, and only drew
the actual photo/vector background on top when awake. That meant every
pixel on the display sat at that navy value - not true black - for the
entire always-on period, hours at a stretch. On an AMOLED screen that's
real continuous power draw and burn-in exposure across the *whole* screen,
which is what tripped the threshold. Rossonero and milan-personal never
had this because they already clear to true `Graphics.COLOR_BLACK`
unconditionally and only tint the canvas when awake - this project just
didn't follow that same pattern for its background clear.

**Fix:** matched that pattern - clear to black when asleep, only use the
navy/photo/vector background when awake. Also darkened the dimmed
always-on text/icon colors a further notch (windmill icon and date:
`0x777777` → `0x444444`; time: `0xdddddd`/`0x999999` →
`0x666666`/`0x555555`; the steps·battery line: `0x999999` → `0x444444`)
for real margin under the 10% budget rather than landing just under it -
the time text in particular is a lot of always-on screen area
(`FONT_NUMBER_HOT`), so even a moderate brightness cut there matters more
than anywhere else on the face.

Checked this with a rendered luminance estimate (Python/PIL, circular-
display-area-weighted mean pixel luminance, same technique as this
session's other visual verifications) rather than just reasoning about it
- the navy-background version came out around 15% in that estimate (order
of magnitude matches your measured 10.81%, my proxy runs a bit hot since
it isn't pixel-identical to Monkey C's actual font rendering), and the
fixed version came out around 4%, well clear of the threshold. Still
worth confirming the actual number in your simulator's Screen Heat Map on
your next build, since this is an estimate, not a guarantee.

**Worth checking on rossonero/milan-personal too, just not urgent:** the
same rendered estimate put their existing always-on luminance at roughly
6.7%/7.5% - under the 10% limit with real but not huge margin, using the
same dimmed colors this project had before today's fix. They haven't
thrown this warning and I'm not touching already-shipped, user-approved
code without a reason, but if you run the Screen Burn-In Simulation on
either of them and it's closer to the edge than expected, the same fix
(darken the always-on time/date colors a further notch) is the lever to
pull.

## Third fix carried over from Rossonero/milan-personal

Same badge-text fix as the other two projects (identical drawStatBadge
code): once `formatSteps()` switches to "12.3K"-style text for step
counts over 1000, that string runs wider than a bare "0" or "80", and the
badge text was always drawn at a fixed font size regardless of length.
Now measures the actual rendered width at runtime and drops to
`FONT_XTINY` if the normal font would overflow the badge. This project
has no perimeter tick ring, so the tick-overlap bugs found in the other
two don't apply here - this is the only relevant fix from that round.

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
