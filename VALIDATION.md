# Prototype validation — v0.4.0 The Winding Cathedral

Test host: Apple M5, macOS 26.6.2. Built with Swift 6.3.3 for Apple Silicon, targeting macOS 14 or newer. The release ZIP was extracted, its local ad-hoc signature verified, and the extracted app launched successfully. `Tests/extracted-release-smoke.json` records the successful windowed native smoke run.

## Native integration

`Tests/vertical-enhancements.json` records the final fullscreen run. All 60 top-level boolean checks passed, including all nested vertical check groups. Existing controls, 30-second Bloodfire, fivefold damage, bursts, leapers, audio resources, and gate progression continue to pass.

- Player movement physically traversed both three-flight staircases in both directions. Feet reached the west ossuary at −6 m and east gallery at +6 m, with each frame changing height by at most approximately 0.032 m at walking speed.
- Ground, stair, and gallery layers remain distinct at overlapping horizontal coordinates. The player can walk under the gallery, jump and land on top, and fall onto the upper slab. An upward headroom probe stops beneath the slab.
- Enemies follow the actual stair routes to targets above and below. All 26 enemy spawns, pickups, seals, and the exit are valid and reachable.
- Shotgun hits and rockets damage visible enemies higher on stairs. Gallery slabs block shots, splash, hostile missiles, and rising debris.
- Close-range regressions verify that a rocket muzzle cannot spawn beyond a low overhead landing, and a hostile shot stopped by that landing cannot also damage the player on its impact frame.
- Seals and pickups require the player to be on the corresponding floor. The gate still requires all three seals, lights and sparkles once, and triggers victory only at the exit elevation.
- Space remains one jump per press, Shift runs, and mouse/trackpad click fires. Focus release and pause clear held input. Normal movement speed is 5.7 m/s, running 8.8 m/s.

`Tests/assisted-playthrough.json` records a complete run through the normal movement, navigation, combat, pickup, and victory logic. It defeated all 26 enemies, collected three seals, and won in 84.74 simulated seconds. Assistance provides health, ammunition, and exact aiming; this is not a human difficulty or playtime measurement.

## Architecture and performance

Original 1024px diffuse/normal/roughness maps are cached for worn sandstone, flagstone, iron, carved trim, and gothic ceiling panels. Reference screenshots of original Quake's Gloom Keep and Grisly Grotto were visually inspected; source links are in README. No Quake textures or other game assets are included.

The world contains 23 floor/ramp surfaces and 741 finite collision volumes. Vault peaks include the 14 m nave, 18 m crossing, and 16 m northern crypt. The two side wings add ±6 m elevations and walkable space below the upper gallery. Layered navigation uses spatial indexing and cached routes; initial stair routes are prepared during loading.

Six actual native render snapshots in `Architecture/` were inspected: nave, crossing vault, ascending staircase, upper gallery, gallery underpass, and sunken crypt. This inspection prompted refined pillar tiling and tapered brazier flames. The revised brown palette, worn surfaces, ceiling relief, and vertical separation are visible in the snapshots.

`Tests/architecture-performance.json` records approximately 60 FPS in each of those six scenes after a one-second settling period. The complete assisted playthrough sampled 60.06 FPS. These are short observations on this host, not sustained thermal or worst-case benchmarks for every MacBook Air. Initial loading and shader preparation are excluded from the scene samples.

## Human playtesting

The remaining human checks are stair readability, exploration flow, aim and trackpad feel, combat balance, perceived audio intensity, and sustained performance at the user's chosen display settings. The game works offline; no browser or engine installation is required to play.
