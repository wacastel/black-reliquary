# Prototype validation

Test host: Apple M5, 8-core GPU, macOS 26.6.2. Built as an ARM64 Mach-O executable with Swift 6.3.3. Local app signing passed.

## Passed

- Native AppKit window is visible and SceneKit reports the Metal rendering backend.
- Native fullscreen transition completes; the window reports the fullscreen style.
- Player spawn, all 22 enemy spawns, and all pickup spawns are inside navigable space.
- All three seals and the final exit are reachable. An independent check also swept each planned route past obstacle footprints.
- Player movement changes position and respects walls.
- Short projectile sweeps collide with walls. This check covers a collision defect found and fixed during development.
- Firing consumes ammunition.
- Assisted automated playthrough kills all 22 guardians, collects all three seals, and triggers victory.
- Original soundtrack and eight effects are bundled; PCM generation checks found no sample clipping.
- Native render snapshots of the title screen, gameplay, and signage were visually inspected.

The fullscreen smoke scenario sampled approximately 60 rendered frames per second using SceneKit render callbacks. This is a short scene check, not a sustained thermal or whole-level performance benchmark.

The automated playthrough completed in 85.49 simulated seconds with exact aiming, route planning, replenished ammunition, and assisted health. It validates the game loop; it does not measure human playtime or combat balance. The intended first-play length is approximately five minutes.

## Human playtest still needed

Direct trackpad/WASD feel, preferred aim sensitivity, audio mix, and combat difficulty. Desktop UI automation could not run because macOS Accessibility/Screen Recording permissions were pending. Native rendering, fullscreen, and gameplay checks ran through the app's own test scenarios.
