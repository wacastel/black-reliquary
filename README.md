# Black Reliquary

**Chapter 01 — The Hollow Cathedral**

An original gothic first-person shooter prototype for Apple Silicon Macs. Fight through a weathered cathedral with dark stone, rust, and ominous light: recover three seals, defeat their guardians, and escape through the northern gate. The compact level is designed for roughly five minutes of first-time play.

## Play

Download the ready-to-play Apple Silicon app from the [latest GitHub release](https://github.com/wacastel/black-reliquary/releases/latest) while signed in to your GitHub account. Extract the ZIP, then double-click **Black Reliquary.app**. You can drag the app into Applications for convenient access. Press **Enter** or click to begin.

If you already have the original project folder on your Mac, double-click **Black Reliquary.app** there, or run **Play Black Reliquary.command**. No rebuild is needed to play that copy.

The app runs in its own native macOS window. It renders through Metal and works offline. No browser, JavaScript runtime, downloads, or game-engine installation is required to play.

The app uses a local ad-hoc signature and has not been notarized for public distribution. If macOS reports an unverified developer for the copy you downloaded from this repository, try opening it once, then use **System Settings → Privacy & Security → Open Anyway** for Black Reliquary. See [Apple's instructions](https://support.apple.com/en-us/102445). The existing locally built copy should open normally.

## Controls

| Input | Action |
|---|---|
| W / A / S / D | Move forward / left / backward / right |
| Trackpad movement or mouse movement | Aim |
| Space or primary mouse click (hold for repeated fire) | Fire |
| Shift or secondary mouse click | Jump |
| 1 | Iron shotgun |
| 2 | Rocket lance |
| F | Toggle native fullscreen |
| Escape | Pause / resume and release the pointer |
| [ / ] | Decrease / increase aim sensitivity |
| M | Mute / unmute sound |
| R, while paused | Restart the level |
| Enter, after death or victory | Restart |
| Command-Q | Quit |

**Trackpad tip:** Use one finger to aim, your other hand for WASD, and Space to fire. You do not need to click while dragging. The pointer is captured only during play and restored on pause, focus loss, or quit. Standard macOS Control-Command-F also toggles fullscreen.

## Your objective

Follow the central aisle to the crossing. The west ossuary, east furnace chapel, and northern crypt each hold a floating gold seal. Defeat nearby guardians before collecting a seal. Once all three are yours, the northern exit shines bright emerald and showers sparks: continue through the crypt to escape.

Red reliquaries restore vitality; ammunition boxes replenish shells or rockets. Each seal restores some vitality. The level has 26 enemies, two weapons, health and ammunition pickups, a death/restart loop, and a victory screen.

## Bloodfire update — v0.2

- **Darker gothic atmosphere:** weathered masonry, grime, rust, and darker lighting deepen the cathedral's mood.
- **Bloodfire relics:** find three weapon powerups, with the first available early in the nave. Each grants **25 seconds of fivefold damage** for both weapons, plus **8 shells and 2 rockets**. Switching weapons preserves the effect. Another relic refreshes the timer to 25 seconds; durations do not stack. Pausing freezes the timer, and restarting clears it.
- **Explosive combat:** empowered weapons have heavier, thunderous reports, and their kills blast enemies into blood, bone, and armor with a visceral impact sound. Empowered rocket splash deals at least 140 damage even at its outer edge. Rockets still hurt you at close range; Bloodfire does not increase that self-damage.
- **Livelier monsters:** existing enemies move faster with articulated limbs and glowing bodies. Four new Ossuary monsters leap toward you with snarls, roars, and heavy landing impacts.
- **A clear escape signal:** the gate remains locked until all three guarded seals are collected, then glows emerald, sparkles, and sounds a mystical chime.

All architecture, rune designs, and sound assets are original. The soundtrack is a looping 72-second ambient composition with drones, breath textures, metallic tolls, and distant choir-like tones.

## Build and expand

Requirements to rebuild: Apple Silicon Mac, macOS 14 or later, and Apple Command Line Tools with Swift. The delivered binary was built with Swift 6.3.3 in Swift 5 compatibility mode.

From this folder:

```sh
./build.sh
open 'Black Reliquary.app'
```

The script builds an ARM64 executable, bundles all audio and the icon, and signs the app locally.

For a fresh checkout of this private repository, use an authenticated GitHub CLI:

```sh
gh repo clone wacastel/black-reliquary
cd black-reliquary
./build.sh
open 'Black Reliquary.app'
```

If Command Line Tools are missing, run `xcode-select --install` and finish Apple's installer before building. The Git repository contains source, original assets, build scripts, screenshots, and validation records. Generated `.app` bundles and ZIP archives are kept in GitHub Releases instead of Git history. After a build, **Play Black Reliquary.command** opens the app from the checkout.

- `Source/main.swift`: macOS window, fullscreen, keyboard, and relative pointer input.
- `Source/Game.swift`: movement, collision, weapons, enemies, pickups, objectives, and test scenarios.
- `Source/Entities.swift`: enemy models and enemy state.
- `Source/Effects.swift`: Bloodfire relics, weapon effects, and blood, bone, and armor fragments.
- `Source/World.swift`: cathedral geometry, textures, spawn placement, and navigation boundaries.
- `Source/HUD.swift`: native menus and heads-up display.
- `Source/Audio.swift`: native audio playback.
- `Source/Core.swift`: shared map data types.
- `Source/Validation.swift`: enhancement integration checks and showcase captures.
- `Resources`: original soundtrack, effects, and app icon.

This is a single-player prototype with one level and primitive-based creature models. Playtime varies with exploration and combat; five minutes is the design target, not a countdown. Human playtesting is still needed to tune trackpad feel and difficulty.

## Verification

The executable contains optional developer checks:

```sh
RELIQUARY_TEST_OUTPUT=/tmp/reliquary-smoke.json \
  'Black Reliquary.app/Contents/MacOS/BlackReliquary' --smoke-test

RELIQUARY_TEST_OUTPUT=/tmp/reliquary-fullscreen.json \
  'Black Reliquary.app/Contents/MacOS/BlackReliquary' --smoke-test --fullscreen

RELIQUARY_TEST_OUTPUT=/tmp/reliquary-playthrough.json \
  'Black Reliquary.app/Contents/MacOS/BlackReliquary' --autoplay-test

RELIQUARY_TEST_OUTPUT=/tmp/reliquary-enhancements.json \
  'Black Reliquary.app/Contents/MacOS/BlackReliquary' --enhancement-test
```

Smoke checks validate Metal, visible native window, movement, ammunition consumption, wall collision, valid spawns, and paths to all objectives. Fullscreen mode additionally checks the native window style. The automated playthrough uses assisted health and ammunition to check the combat/objective/ending sequence; it is not a difficulty benchmark. Render FPS is sampled from SceneKit render callbacks, separately from the simulation timer.

The optional enhancement checks in `Source/Validation.swift` exercise actual gameplay paths: Bloodfire collection, fivefold damage, weapon switching, pause and expiry behavior, shot cooldowns, powered rocket persistence and edge damage, fragment motion, leaper movement and wall clearance, enemy animation, gate unlocking and victory, reset cleanup, and bundled sounds. The report also records relic and leaper counts. These integration checks do not replace playtesting combat feel or difficulty.

`Tools/generate_audio.py` can regenerate the original WAV assets; it requires Python 3 and NumPy. Regeneration is optional and is not part of building or playing the app. See `VALIDATION.md` for the completed checks and their limits.
