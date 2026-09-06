# Prototype validation — v0.2.0 Bloodfire

Test host: Apple M5, macOS 26.6.2. Rebuilt with Swift 6.3.3 as an ARM64 Mach-O executable targeting macOS 14 or newer. The locally signed app verifies after release ZIP extraction.

## Completed checks

`Tests/bloodfire-enhancements.json` records the fullscreen integration run. All 36 boolean checks passed. Counts were checked separately: 26 enemies, four leapers, three Bloodfire relics, and a measured 5× shotgun damage multiplier.

- Native visible AppKit window, Metal rendering, and native fullscreen.
- Valid player, enemy, and pickup positions; all seals and the exit reachable.
- Player movement, wall collision, short projectile wall sweeps, ammunition consumption, and shot cooldowns.
- Bloodfire pickup through normal collision, fivefold damage, weapon switching, pause behavior, expiry, and restart cleanup.
- Powered shotgun kills produce fragments. Fragments move ballistically. Powered rockets retain their upgrade after the player's timer expires, and outer-edge splash bursts the leaper.
- Leapers leave the ground, travel toward the player, land, and remain in navigable space. Wall-adjacent leaps use the same clearance as ground movement. Enemy animation changes the articulated pose and emits a glow.
- The gate starts locked, remains locked with two seals, and activates its light, portal surface, and spark emitter only after the third seal. Unlocking happens once. The unlocked gate wins; the locked gate cannot win.
- All eight new sound effects are bundled. Their generated PCM was separately checked for valid encoding, no clipped samples, silent endpoints, and deterministic regeneration.

`Tests/assisted-playthrough.json` records a complete playthrough using normal movement, combat, pickups, and objectives with assisted health, ammunition, and exact aiming. It defeated all 26 enemies, collected all three seals, and reached victory in 84.73 simulated seconds. This validates the game loop; it does not measure human playtime or difficulty.

## Visual and performance checks

Native render snapshots of the darker crossing, glowing enemies, an airborne leaper, a powered impact, and the unlocked gate were inspected. Paths and signage remained readable. The title screen and gameplay images in the repository reflect this version.

The fullscreen smoke run sampled approximately 60 rendered FPS. The populated crossing also sampled 59.97 FPS with all 26 enemies alive in a separate four-second assisted-health scenario, recorded in `Tests/bloodfire-performance.json`. FPS comes from SceneKit render callbacks, separately from the simulation timer. Dynamic enemy aura lights are limited to the four nearest living enemies within 12 meters; emissive markings remain visible on other enemies. Debris is capped at 160 pieces and expires.

These are short checks, not sustained thermal or worst-case performance benchmarks.

## Human playtest still needed

Trackpad feel, audio mix and perceived intensity, readability on your preferred display brightness, revised enemy difficulty, and powerup pacing. The automated playthrough uses assistance and cannot establish combat balance. Native game checks do not replace a manual playthrough with the actual keyboard and trackpad.
