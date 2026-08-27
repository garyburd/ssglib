# Gravity-rail 35mm slide feeder

A LEGO Technic mechanism that presents one mounted 35mm slide at a time in a registered photography gate. One lever throw feeds the next slide in and drops the previous slide into a bin.

The design assumes you already have a camera copy stand and a backlight. This machine only handles **transport, registration, and catch**.

---

## 1. What it has to do

Scanning a large pile of slides by hand is slow because every cycle is: pick up, blow dust, seat, shoot, put down, next. The feeder should reduce that to:

1. Load a cassette of ~40–60 slides.
2. Seat the first slide.
3. Focus and expose once; leave the camera alone.
4. Throw a lever, wait a beat, shoot, repeat until the cassette is empty.
5. Swap cassettes. The last cassette’s slides are in the catch bin, still in order (reversed).

Hard requirements:

- Slide **film plane** must land in the same place every time (focus and framing).
- Nothing Technic may enter the **24 × 36 mm** image, or cast a shadow into it.
- Rails may touch only the **mount**, never the film.
- Mixed mount thicknesses (about **1.0–3.2 mm**) must not double-feed, or at least must be tunable per batch.
- Jams must be visible and pickable with fingers — no fully enclosed tunnel.

---

## 2. Why this architecture

A 50 × 50 mm slide does not sit cleanly on LEGO’s 8 mm grid (50 / 8 = 6.25). A tight 6-module channel is 48 mm (bind). A 7-module channel is 56 mm (sloppy). Fighting that with a precision slot is how homemade feeders jam.

So this design **does not try to be a tight 50 mm tube**. It does three separate jobs with three separate features:

| Job | How |
| --- | --- |
| Carry the slide | Two parallel Technic beams, **smooth face up**, used as rails |
| Keep it on the rails | Loose 56 mm side fences plus a light rubber side spring |
| Register it for the photo | A kinematic corner at the gate, located by the pusher stroke — not by channel width |

Feed is a **bottom-of-stack linear shuttle**, the same family as a PEZ dispenser or a straight-tray slide projector:

- Gravity keeps the stack sitting on the rails.
- A thin pusher kicks only the bottom slide forward.
- That slide drives the previous slide out of the gate and off a downhill ramp into the bin.
- The track is slightly downhill so the gated slide does not follow the pusher home.

Pure gravity (an escapement that merely *releases* a slide) is included as a later option. It is nicer when every mount is the same slippery plastic. It is unreliable on old cardboard. The shuttle is positive: it *pushes*. Gravity assists.

---

## 3. Slide and LEGO numbers that actually matter

### 3.1 The slide

| | |
| --- | --- |
| Mount | **50 × 50 mm** (2" × 2") |
| Film opening | **24 × 36 mm**, not always perfectly centered |
| Cardboard thickness | ~1.0–1.5 mm (some older ones thinner, often warped) |
| Common plastic (CS / LKM / Paximat) | ~1.8–2.3 mm |
| GEPE glassless 2 mm | 2.0 mm — treat as the “standard” batch |
| GEPE / glass 3 mm | 3.0–3.2 mm |
| Mount border beside the 24 mm side | (50 − 24) / 2 = **13 mm** |
| Mount border beside the 36 mm side | (50 − 36) / 2 = **7 mm** |

The 7 mm border is narrower than a Technic beam (~7.8 mm). If you feed along the 36 mm axis, the rails sit under the film and vignette the backlight.

**Feed along the 24 mm axis** so the 36 mm film span sits *between* the rails. Rails then live entirely on the 13 mm borders.

Scan portrait and landscape the same way. Rotate in software.

### 3.2 The brick

| | |
| --- | --- |
| Module (hole pitch) | **8.0 mm** |
| Technic beam width / height | **~7.8 mm** (measured 7.4–7.8; never a full 8) |
| Plate / tile thickness | **3.2 mm** |
| Pin through-hole | 4.8 mm |

A beam used as a rail, rotated so the **plain side faces up** and the holes run sideways, is a 7.8 mm-wide smooth track with no hole dimples in the running surface.

### 3.3 Rail spacing (the important bit)

```
  Y
  ^
  |  7.8 mm rail     40.2 mm clear      7.8 mm rail
  |  ████████     (film 36 mm fits)     ████████
  |  ████████                           ████████
  |      |<-------- 48 mm = 6M ------->|
  |      centerline to centerline
```

- Rail **centerlines 6 modules (48 mm)** apart.
- Inner clear width **48 − 7.8 ≈ 40.2 mm**, which clears 36 mm of film with ~2 mm spare each side.
- A 50 mm slide overhangs each rail by (50 − 40.2) / 2 ≈ **4.9 mm** of mount — contact is on plastic/cardboard, not film.
- Outer width of the rail pair ≈ 55.8 mm.

Mount every rail pin on the **outboard** side. Pin heads on the inner faces will snag slides.

---

## 4. Layout

Left to right, looking from the side. Camera looks **down**. Light looks **up**. Slide is horizontal at the gate.

```
                      [ camera on copy stand ]
                               │
                               ▼
   ┌──────────┐   ┌─────────────────┐   ╲
   │ MAGAZINE │   │      GATE       │    ╲ exit ramp
   │  stack   │──▶│  24×36 window   │─────╲────────▶ bin
   │  15M tall│   │  registered     │      ╲
   └──────────┘   └─────────────────┘
        ▲                 ▲                  ▲
   gravity on        backlight +          gravity drop
   the stack         diffuser below
        │
   pusher blade (one slide thick)
```

Approximate footprint: **25 × 13 modules** (200 × 104 mm) plus the bin. Gate window sits ~40–50 mm above the table so a light panel and a diffuser can slide underneath.

### 4.1 Heights along the track (gravity assist)

Do not make the photography plane steep — the camera’s depth of field and evenness of light both want a **flat gate**. Put the slope in the magazine and the exit, not in the picture.

| Zone | Slope | Role |
| --- | --- | --- |
| Magazine pocket | 0° floor, stack vertical (or 5–10° lean toward the gate) | Gravity loads the next slide onto the rails |
| Gate rails | **One plate (3.2 mm) drop over 8–10 modules** ≈ 2–2.5° | Stops the seated slide following the pusher back |
| Exit ramp | **~37°** (a 3–4–5 Technic triangle: rise 3M, run 4M) | Slide leaves under gravity; no free-fall onto glass mounts |
| Bin | Felt / cloth lined, short drop off the ramp | Catch without chipping plastic or breaking glass |

A 3–4–5 triangle is `arctan(3/4) = 36.9°`. Connector angle #4 (135° complement = 45°) is an acceptable substitute if you do not want to count the triangle.

---

## 5. The five sub-assemblies

Build them as separate chunks that pin together. That is how you debug a jam without rebuilding the camera alignment.

### 5.1 Base frame

A rigid ladder of 15M and 13M beams, cross-braced. This is the only part that has to be stiff: if the gate flexes when you throw the lever, the focus plane moves.

- Two long 15M side members, 13M apart (outer).
- Cross beams at magazine, gate, and ramp hinge.
- Rubber feet (Technic bushes, or actual stick-on feet) so it does not skate on the table when you pull the lever.
- A 5 × 11 open frame (**part 64178**) or four beams as a rectangular window under the gate — this is the light well. Keep it black.

Tie the whole base to the copy-stand table with a couple of clamps or a heavy book on the rear beam. The camera never touches this machine.

### 5.2 Rails

Two 15M beams for the magazine + gate, then two 9M or 11M beams continuing onto the ramp (hinged at the gate/ramp joint so the ramp angle is adjustable).

**Orientation.** Rotate each rail 90° about its long axis:

- Smooth, hole-free face points **up** (running surface).
- Holes run **sideways** (Y), so you pin the rail to the frame from the outside.
- The camera, looking down, sees a solid 7.8 mm strip — no hole pattern, no light leaks through the rail.

Wipe the running faces with a dry cloth. Do not oil them. Oil migrates onto mounts and then onto film.

If a particular beam has a moulding seam that catches cardboard, flip it end-for-end or pick a smoother one. The user request to use the smooth side is exactly to avoid the dimpled hole face.

Optional: a single layer of matte Magic Tape on the running face makes cardboard quieter and slightly slower, which is good. Skip it for plastic mounts; they already slide too well.

### 5.3 Magazine cassette (removable)

A vertical box the size of one slide in plan, 15M (120 mm) tall.

| | |
| --- | --- |
| Inner plan | 7M × 7M = **56 × 56 mm** |
| Play around a 50 mm slide | 3 mm each axis, total |
| Capacity at 2 mm/slide | ~55 slides with a little headroom |
| Capacity at 3 mm/slide | ~35 slides |
| Capacity at 1.3 mm cardboard | ~80 slides — **do not fill that full**; the stack gets heavy and the bottom cardboard crushes |

The cassette hangs on two long pins at the rear of the magazine well and lifts straight up. Build two or three cassettes. Load the next one while the camera is shooting the current one. That is the actual throughput trick; the lever is only half of “efficient.”

**Walls.** 5 × 11 Technic panels (**64782**) or stacked 11M / 15M beams. Leave the **front open below the throat lip** so the bottom slide can leave, and leave the **top open** for loading. Leave one side openable (a pinned panel) so a jam is a two-second fix.

**Throat lip (singulator).** A 7M beam bridging the front of the cassette, one plate to two plates (3.2–6.4 mm) above the rail surface. This is the slot the bottom slide has to fit through.

| Batch | Lip height |
| --- | --- |
| Cardboard only | 1 plate (3.2 mm) plus retard pad (below) — two cardboards can theoretically fit, so the pad is mandatory |
| 2 mm plastic | 1 plate + a tile shim, or just 1 plate with ~0.2 mm extra from beam tolerances |
| 3 mm GEPE / glass | 2 plates (6.4 mm) — generous, so the retard pad does the singulating |

Change lip height by repinning the bridge through a different hole in a vertical 5M beam, or by stacking plates under the bridge. Mark the three settings on the beam with a Sharpie.

**Retard pad.** A small Technic tyre (**2815** wedge-belt tyre, or a 24 × 7 tyre) on a 3M axle, hanging in front of the stack, sprung lightly down with a rubber belt (**85544** or a real rubber band). It rests on the *second* slide. The bottom slide is pushed out under it. This is the inkjet-printer trick, and it is what makes cardboard behave.

**Pusher slot.** Rear of the cassette, on the rail plane: a gap ~4 mm high and ~24 mm wide, centered. Only the blade goes in; the carriage stays outside.

### 5.4 Pusher and lever

The pusher is a sliding carriage under / behind the magazine whose only job is to move **56 mm** (7M) and come back.

**Carriage.** A 7M or 9M beam with two 3M uprights, sliding on two parallel 10M or 12M axles that run in the base (a drawer). Axles as slide rods are smoother than beams-on-pins. Bush the ends so the carriage cannot rack.

**Blade.** This is the one place LEGO is the wrong thickness. A tile is 3.2 mm; two cardboard slides are ~2.4 mm. Native options, in order of preference:

1. **1 × 4 tile** on the front of the carriage — correct for 2–3 mm plastic.
2. For cardboard: tape a **0.8 mm gift-card shim** to the face of that tile, so the working edge is ~1.2–1.5 mm and catches one mount. This is the recommended hybrid. Do not pretend a 7.8 mm beam edge can pick one cardboard slide; it will push three.
3. A **Technic cam (6575)** on a 2M axle as a “finger” if you would rather pick from the *edge* than push a full-width blade. Works, but needs more tuning.

The blade should hit the **rear edge of the mount**, centered, below the film. Never let it rise high enough to touch film.

**Stroke.** 7 modules = 56 mm = one slide plus 6 mm of overtravel. Overtravel is what guarantees the outgoing slide is fully onto the ramp. The incoming slide is then sitting where the old one was.

**Drive.** A 5M–7M hand lever on the right side of the base, linked to the carriage with a 9M beam. Optional 8-tooth to 24-tooth reduction (3:1) if you want a longer, slower throw. A rubber band returns the carriage.

**Detents.** A pin on the carriage that drops into a hole at each end of the stroke. You want to *feel* “seated” without looking. Shoot only after the return detent, so your hand is off the machine.

**Do not shoot at the forward stop** with your hand on the lever. You will shake the gate.

### 5.5 Gate, light well, and drop

The gate is just a stretch of the same rails, with four extra pieces:

1. **Aperture mat.** Black. Opening about **28 × 40 mm** (comfortable around 24 × 36, shows a sliver of mount which is useful for cropping later). Build it from black tiles or black tape on a 5 × 11 open frame, **below** the rails. Nothing above the film except the camera.
2. **Side spring.** One **flexible axle connector (45590)** or a rubber belt loop, pressing the slide toward the left fence. Combined with the pusher locating the rear edge, this is two-edge (kinematic) registration. Repeatability is far better than a 50 mm slot.
3. **Corner hold-downs.** Four ½-bushes on bars at the mount corners, set ~0.5–1 mm above a flat slide. They do nothing to a flat mount and they flatten a warped cardboard just enough to stay in depth of field. They must not touch film.
4. **Diffuser shelf.** Two 11M beams under the base, 20–40 mm below the slide, holding tracing paper, opal acrylic, or a white styrene sheet. The user’s light source sits under that. Distance is what hides LED dots.

**Exit.** At the front of the gate the rails stop being level and become the 37° ramp. The outgoing slide is already moving (the next slide is hitting it), so it does not need a trap door. It rides the ramp and drops a few millimetres into a felt-lined bin — or, better, into a second cassette standing at the bottom of the ramp. A receiving cassette keeps order (reversed). A jumble bin is faster and scratches more.

Glass mounts: use the cassette catch, not a 15 cm free-fall.

---

## 6. One cycle

Assume slide N is seated in the gate, pusher retracted, stack resting on the rails.

| Step | What moves | What you do |
| --- | --- | --- |
| 0 | Everything still | Shoot. Wait for the shutter / mirror to finish. |
| 1 | Lever forward. Blade enters the rear slot and drives slide N+1. | Throw the lever until the forward detent. |
| 2 | N+1’s front edge hits N’s rear edge. Both travel 50 mm. | — |
| 3 | N reaches the ramp, slides down, drops into the bin. N+1 is now in the gate, located by the blade. | — |
| 4 | Lever returns. Blade retracts. The side spring keeps N+1 from coming back; the 2° downhill does the rest. The stack drops one thickness onto the rails. | Take your hand off. Wait ~0.5 s for vibration. |
| 5 | Back to step 0. | Shoot. |

Empty cassette: the last slide is in the gate with nothing behind it. One extra throw with no new slide will push it out, or pick it out by hand.

First slide of a cassette: the gate is empty, so the first throw only seats slide 1. No drop. Then shoot, then continue.

---

## 7. Bill of materials

Quantities are for **one feeder + two cassettes**. Colours do not matter except the aperture (black) and anything next to the light well (also black, to kill bounce).

### 7.1 Technic structure

| Qty | Part (BrickLink / common name) | Use |
| --- | --- | --- |
| 8 | Beam 15M (32278) | Side frame, rails, cassette walls |
| 6 | Beam 13M (41239) | Cross members, cassette |
| 8 | Beam 11M (32525) | Ramp, light-well, cassette |
| 8 | Beam 9M (40490) | Lever, links, cassette |
| 10 | Beam 7M (32524) | Gate, throat bridge, carriage |
| 10 | Beam 5M (32316) | Uprights, detents |
| 12 | Beam 3M (32523) | Corners, blade carrier |
| 4 | Liftarm 3 × 5 L (32526) | Magazine well, ramp braces |
| 4 | Liftarm 2 × 4 L (32140) | Lever hub, cassette hooks |
| 2 | Frame 5 × 11 open (64178) | Light well / aperture |
| 4 | Panel 5 × 11 (64782) | Cassette walls (nice if you have them; beams substitute) |

### 7.2 Pins, axles, motion

| Qty | Part | Use |
| --- | --- | --- |
| 40 | Pin with friction 2M (2780) | General |
| 16 | Pin long 3M (6558 / 32556) | Cassette hooks, rail mounts |
| 8 | Pin 3M with bush (32054) | Rail outboard mounts |
| 6 | Axle 12M (3708) | Carriage rods, cassette hinge |
| 4 | Axle 8M (3707) | Lever shaft, retard roller |
| 6 | Axle 6M (3706) | Hold-downs, general |
| 8 | Axle 4M (3705) | — |
| 4 | Axle 3M (4519) | Tyre roller |
| 16 | Bush (3713) | — |
| 12 | Bush ½ (32123) | Hold-downs, detents |
| 8 | Axle connector perpendicular (6536) | Frame |
| 4 | Axle connector flexible / rubber (45590) | Side spring, optional dampers |
| 2 | Gear 8 tooth (10928 / 3647) | Optional lever reduction |
| 2 | Gear 24 tooth (3648) | Optional lever reduction |
| 1 | Cam (6575) | Optional edge-picker instead of tile blade |
| 2 | Gear rack 1 × 4 (3743) or 1 × 7 (87761) | Optional; only if you prefer rack drive to a beam link |

### 7.3 Rubber, tiles, System extras

| Qty | Part | Use |
| --- | --- | --- |
| 2 | Wedge-belt tyre (2815) or small tyre 24 × 7 | Retard pad |
| 2 | Rubber belt 24 mm (85544) or 33 mm | Retard spring, carriage return (or use office rubber bands) |
| 8 | Tile 1 × 4, black | Aperture mat, blade face |
| 8 | Tile 2 × 4 or 1 × 8, black | Aperture mat |
| 4 | Plate 1 × 4 | Lip-height shims |
| 4 | Plate 2 × 8 or 1 × 8 jumper (3794) | Only if you insist on a tighter channel; not required |

### 7.4 Not LEGO (on purpose)

| Item | Why |
| --- | --- |
| 0.8 mm plastic card, ~15 × 40 mm | Cardboard pusher shim |
| Black paper or flocking tape | Aperture, kill reflections |
| Tracing paper / 2 mm opal acrylic, ~80 × 80 mm | Diffuser |
| Felt or microfibre scrap | Bin lining |
| Two extra rubber bands | Carriage return, retard |
| Sharpie | Mark lip-height holes and “this way up” on cassettes |

A typical Technic collection already covers 80% of this. The parts you may need to pick up are the 5 × 11 frames, a couple of tyres, and black tiles.

---

## 8. Build order

Do not build it all and then try to feed slides. Commission each interface.

1. **Base + light well.** Confirm the copy-stand camera can see through the 5 × 11 frame, and that the light + diffuser fill it evenly. Tape the base down. Focus on a single slide held by hand on the future rail plane. Lock the camera.
2. **Rails only.** Pin the two 15M rails at 6M centers, smooth face up, pins outboard. Test-slide one plastic mount and one cardboard mount along them. They should glide with a fingertip. If cardboard stutters, the running face is the hole side — rotate the beam.
3. **Gate furniture.** Aperture mat, side spring, corner hold-downs. Seat a slide by hand. Shoot a test frame. Check: film not clipped, rails not in the image, even light, square-ish mount. Adjust the side spring until two consecutive hand-seated shots crop the same.
4. **Ramp + bin.** Confirm a slide pushed off the gate with a finger rides down and lands softly.
5. **Pusher.** Add the drawer, blade, lever, return band, detents. With the magazine *off*, put one slide in front of the blade and throw. It should move 56 mm and stop in the gate. Throw again with a second slide behind it; the first should leave.
6. **Magazine well + one cassette.** Lip on the 2 mm setting. Load ten identical plastic slides. Run the cassette through. Then ten cardboards with the shim and retard pad. Then, only if you have them, glass.
7. **Second cassette.** Match the first. Mark them A / B.

If step 5 already fails, do not add the magazine — the stroke or the blade height is wrong.

---

## 9. Optical setup (the feeder cannot fix a bad copy stand)

The mechanism only delivers a slide to a plane. The picture still depends on the camera and the light.

- **Lens.** A 90–100 mm macro is ideal. A 50 mm with extension tubes works; watch distortion and how close the camera sits to the lever.
- **Aperture.** f/5.6–f/8. Wider, and a warped cardboard’s corners go soft. Narrower, and you start seeing diffuser texture and dust.
- **Shutter.** Electronic first curtain or full electronic. Mirror slap will show up as a slight smear because the gate is light.
- **Focus.** Manual, once, on the emulsion of a representative slide. Do not autofocus every frame — the mount surface and the film are different planes.
- **Exposure.** Manual. Set white balance and exposure on the empty diffuser (or a well-exposed slide you do not care about), then do not touch it. Slide density varies; that is what RAW is for.
- **Light.** Daylight LED, 5000–6500 K, high CRI. The original projector lamp is the wrong tool: heat, and a yellow spike. The user’s existing light source goes **under the diffuser**, not against the film (Newton’s rings, dust specks as hard shadows).
- **Emulsion.** Pick a convention and keep it. Many people shoot emulsion toward the camera so dust on the base is more out of focus; others match the projector orientation. Software can flip. The feeder does not care.
- **Dust.** A rocket blower on each cassette while it is still in your hand beats any in-machine brush. Do not add a Lego brush. It will scratch.

---

## 10. Tuning and failure modes

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Two slides leave at once | Lip too high, no retard pad, or blade too thick | Lower the lip one plate; add the tyre; shim the blade thinner |
| Pusher skips under the slide | Blade too thin / too low | Raise the blade with a plate; check the rear slot is not letting the blade dive |
| Slide comes back with the pusher | Track is dead level or uphill; side spring too strong dragging it | Add the 3.2 mm drop; weaken the side spring; add a one-way rubber flap at the gate entry |
| Slide arrives rotated / not square | Side spring missing; rails not parallel | Re-pin rails; the 6M centerline is not optional |
| Soft focus on one side | Hold-downs crushing one corner, or gate not parallel to the sensor | Back the hold-downs off; shim a foot of the base |
| Dark corners | Aperture mat too small, or rails in the 36 mm span | Confirm feed is along the 24 mm axis; enlarge the mat toward 28 × 40 |
| Cardboard chatters on the rails | Hole-face up, or a burr | Rotate beams to smooth face; a wipe of tape on the rail |
| Glass mount chips in the bin | Too much free-fall | Use the receiving cassette; line the ramp |
| Bottom cardboard crushed | Cassette overfilled | Cap cardboard stacks at ~40 |
| Lever shakes the picture | Shooting before the return detent | Shoot only after the hand is off; optional: put the lever on a separate little base that is not the gate frame (advanced) |
| Jam in the throat | Label / tape proud of the mount, or a bent cardboard | Open the side panel, pick it, put that slide in a “hand feed” pile |

Proud labels are the number one real-world jam. Run a finger around each cassette while loading. Anything that catches your skin will catch the lip.

---

## 11. Optional: motor later

Get the hand lever reliable first. Motorizing a jammed feeder just jams faster.

A reasonable second stage:

- A Control+ / SPIKE / PF Medium motor on the 8T/24T reduction, cranking a 24-tooth gear that has a pin → connecting rod → carriage (Scotch yoke). One revolution = one stroke, with a natural dwell near top dead center if you time the crank.
- A reed switch or a simple Technic touch pin at the return detent.
- Pause 0.8–1.2 s for vibration + exposure, then fire the camera’s wired remote (2.5 mm jack, typically focus and shutter shorted in sequence).
- Count throws. Stop at cassette capacity so it does not hammer an empty gate.

Do not put the motor on the gate frame if you can help it. Put it on the rear of the base, rubber-mounted.

---

## 12. Alternatives that were considered

**Kodak Carousel as the feeder.** The usual DIY path: gut a projector, put an LED in the lamp house, point a camera at the gate. Excellent if you already have trays of slides in carousel magazines. Useless if the pile is in boxes and drawers — you would spend the whole project loading carousels. This design is for loose slides.

**Vertical drop-through gate.** Slide drops from a stack into a window, trap door opens, slide falls, next drops. Hard to register the film plane, and glass mounts hate the fall. Rejected.

**Friction roller (printer style) as the only feeder.** A tyre grabbing the bottom slide. Works until it doesn’t (glazed cardboard, shiny plastic). Kept as the *retard* pad, not as the prime mover. The pusher is still in charge.

**Pure gravity escapement (two-finger clock pallet).** Elegant, small motion, very “Technic.” Unreliable on mixed friction. Documented here as a possible conversion: replace the 56 mm pusher with a rocker whose lower finger holds the gated slide and whose upper finger holds the stack. One rocker flip drops the current slide and then admits the next. Try it only after plastic-only batches run perfectly on the shuttle.

**Tight 52 mm channel with jumper plates.** Tempting. 6.5 studs = 52 mm. It will work in a climate-controlled room with one mount type and then jam on the first proud label. Loose fences + kinematic gate is the right split.

---

## 13. Suggested work session

1. Sort slides into three piles: plastic ~2 mm, cardboard, glass. Do not mix in one cassette.
2. Blow dust, drop into cassette A, all the same way up (spot the thumb mark on the mount).
3. Shoot cassette A. Load cassette B during the last ten frames.
4. Swap. Empty the catch into the original box **as a reversed stack**, or accept reverse order and reverse the file names later.
5. Stop every two cassettes and look at four random files at 100%: dust, clipping, focus, colour. Fix before you scan a thousand.

Throughput, hand-lever, once it is tuned: about **4–8 seconds per slide** including the shutter, or roughly 450–800 an hour of machine time. Loading and dusting are the real clock. That is the point of the spare cassettes.
