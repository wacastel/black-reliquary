# Prototype validation — v0.3.0 Bloodfire

Test host: Apple M5, macOS 26.6.2. Rebuilt with Swift 6.3.3 as an ARM64 Mach-O executable targeting macOS 14 or newer. The locally signed app verifies after release ZIP extraction.

## Completed checks

`Tests/bloodfire-enhancements.json` records the fullscreen integration run. All 53 boolean checks passed. Values were checked separately: 26 enemies, four leapers, three Bloodfire relics, a 30-second powerup, 32 fragments per burst, and a measured 5× shotgun damage multiplier.

- Native visible AppKit window, Metal rendering, and native fullscreen.
- Valid player, enemy, and pickup positions; all seals and the exit reachable.
- Player movement, wall collision, short projectile wall sweeps, ammunition consumption, and shot cooldowns.
- Space jumps without firing, ignores typematic repeat events while held, and jumps again on a new press. Shift runs without jumping; releasing it restores walking. Diagonal running is normalized and running respects walls. The measured run/walk speed ratio is 1.54386.
- Actual mouse-down/up handlers fire and stop firing. A complete down/up tap before the next simulation tick still fires. Right-click triggers neither jumping nor firing. Focus release and pause clear held controls and queued jumps.
- Bloodfire pickup through normal collision, fivefold damage, weapon switching, pause behavior, expiry, and restart cleanup.
- Powered shotgun kills produce 32 larger fragments. Fragments move ballistically and expire. Ten rapid bursts remain bounded to 192 fragments and eight burst containers. Powered rockets retain their upgrade after the player's timer expires, and outer-edge splash bursts the leaper.
- Leapers leave the ground, travel toward the player, land, and remain in navigable space. Wall-adjacent leaps use the same clearance as ground movement. Enemy animation changes the articulated pose and emits a glow.
- The gate starts locked, remains locked with two seals, and activates its light, portal surface, and spark emitter only after the third seal. Unlocking happens once. The unlocked gate wins; the locked gate cannot win.
- All requested sounds, including `player_jump`, are bundled. `Tests/audio-v0.3.json` records five refreshed WAVs with valid PCM encoding, no clipped samples, silent endpoints, and deterministic regeneration. All 18 audio assets reproduce byte-for-byte from the generator. The new gun reports have substantial low-mid energy; gore lasts 2.8 seconds, the seal chime 5.6 seconds, and the jump grunt 0.68 seconds. These signal checks do not establish perceived realism or a manual speaker audition.

`Tests/assisted-playthrough.json` records a complete playthrough using normal movement, combat, pickups, and objectives with assisted health, ammunition, and exact aiming. It defeated all 26 enemies, collected all three seals, and reached victory. This validates the game loop; it does not measure human playtime or difficulty.

## Visual and performance checks

Native render snapshots of the revised control labels, larger powered burst, and crossing were inspected. The title screen and gameplay images in the repository reflect this version. The gate and gothic environment retain the prior validated layout.

The fullscreen smoke run sampled approximately 60 rendered FPS. The populated crossing also sampled 59.95 FPS with all 26 enemies alive in a separate four-second assisted-health scenario, recorded in `Tests/bloodfire-performance.json`. FPS comes from SceneKit render callbacks, separately from the simulation timer. Dynamic enemy aura lights are limited to the four nearest living enemies within 12 meters; emissive markings remain visible on other enemies. Debris is capped at 192 pieces and expires; at most eight finite burst containers exist at once.

These are short checks, not sustained thermal or worst-case performance benchmarks.

## Human playtest still needed

Trackpad feel, audio mix and perceived intensity, readability on your preferred display brightness, revised enemy difficulty, and powerup pacing. The automated playthrough uses assistance and cannot establish combat balance. Native game checks do not replace a manual playthrough with the actual keyboard and trackpad.
