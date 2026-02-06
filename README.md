# MergeDropX

A hyper-casual Suika-style merge-and-drop game built with Godot 4.2. Drop numbered balls into the container — when two matching numbers collide, they merge into the next tier. Chase combos, earn coins, and try to reach 2048!

## Gameplay

- Tap/click to drop balls into the container
- Same-numbered balls merge on contact (2+2=4, 4+4=8, etc.)
- Balls stack up — if they cross the danger line, game over!
- Chain merges for combo multipliers
- Use power-ups (Bomb, Shake, Freeze) to survive longer
- Earn coins to buy upgrades in the shop
- Daily rewards with streak bonuses

## Addictive Features

- Combo system with escalating multipliers and flashy particle effects
- Screen shake, floating score text, expanding ring effects
- Procedurally generated sound effects (no asset files needed)
- Coin economy with shop upgrades
- Daily login rewards with streak bonuses
- Fake interstitial ads (the authentic asset flip experience)
- "Watch ad to revive" mechanic
- Power-up consumables

## Run in Godot Editor

1. Install [Godot 4.2+](https://godotengine.org/download)
2. Open this folder as a Godot project
3. Hit Play (F5)

## Build for Android

1. Set up Android export templates in Godot (Editor > Manage Export Templates)
2. Configure your keystore in `export_presets.cfg`
3. Export via Project > Export > Android

## Build for iOS

1. Export templates must be installed (macOS + Xcode required)
2. Export via Project > Export > iOS
3. Open the generated Xcode project and build to device

## Project Structure

```
project.godot          — Godot project config
scenes/
  main.tscn            — Main scene (board + camera + effects + UI)
  ui.tscn              — All UI screens (menu, HUD, game over, shop, modals)
scripts/
  main.gd              — Main controller, ties everything together
  game_manager.gd      — Global state, scoring, combo system (autoload)
  save_manager.gd      — Persistence, daily rewards, shop (autoload)
  audio_manager.gd     — Procedural sound effects (autoload)
  game_board.gd        — Physics board, ball dropping, merge detection
  ball.gd              — Individual ball (RigidBody2D), rendering, merge logic
  board_renderer.gd    — Visual container, danger line, animated background
  effects.gd           — Particles, screen shake, floating text, combo effects
  ui_manager.gd        — All UI screen management
export_presets.cfg     — Android + iOS export configurations
```

## Tech Stack

- **Godot 4.2** — the same engine used for real mobile games
- **GDScript** — all game logic
- **Zero external assets** — everything is procedurally generated (graphics via `_draw()`, audio via waveform synthesis)
- Native Android (ARM) and iOS export support
