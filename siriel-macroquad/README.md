# Siriel Macroquad

Modern 2D game engine implementation using Rust and Macroquad framework. Port of original Siriel 3.5 DOS game.

## Features

- **Complete game systems:** Player physics, creature AI, scripting, menu system, particles
- **Cross-platform:** Desktop (Windows/macOS/Linux), WebAssembly (WASM), mobile
- **Touch controls:** Virtual D-pad and action buttons for mobile/WASM
- **GLIST menu decoration:** Authentic menu UI with tile-based decoration
- **Framerate-independent:** Delta-time scaled for consistent gameplay
- **RON level format:** Type-safe, Rust-native level files
- **Collision masks:** Pixel-perfect collision detection
- **Camera system:** Viewport following with deadzone, auto-center on small levels

## Quick Start

### Desktop

```bash
# Run debug build
cargo run

# Run release build
cargo build --release
./target/release/siriel

# With arguments
./target/release/siriel --timeout 60 --screenshot shot.png
```

### WebAssembly (WASM)

```bash
# Build and serve locally
cargo xtask serve-wasm

# Open http://localhost:8000

# Build only (no server)
cargo xtask build-wasm

# Clean build artifacts
cargo xtask clean
```

The xtask builds WASM and copies all artifacts to `dist/` directory for deployment:
- `siriel.wasm` - compiled WASM binary
- `index.html` - web entry point
- `assets/` - game assets (levels, sprites)

## Controls

### Desktop
- **Arrow Keys:** Move left/right
- **Space:** Jump
- **ESC:** Return to menu (desktop only)
- **Q:** Quit game (from main menu, desktop only)
- **Enter/Return:** Select menu item
- **Arrow Up/Down:** Navigate menu

### Mobile / WASM
- **Touch D-Pad:** Move left/right
- **A Button:** Jump
- **B Button:** Menu/Back
- **Touch gestures:** Tap menu items to select

## Framerate Independence

The game uses **delta-time scaling** to ensure consistent movement speed across different hardware and refresh rates. Original DOS Siriel was designed for ~60 FPS (VGA refresh rate). Movement values are scaled by `dt * TARGET_FPS` where:
- `dt` = actual frame time from Macroquad's `get_frame_time()`
- `TARGET_FPS` = 60 (defined in `src/core/constants.rs`)

This means the game plays at the same speed whether running at 30 FPS, 60 FPS, 144 FPS, or any other framerate.

## CLI Options

```
Options:
  -t, --timeout <N>         Auto-exit after N frames
  -s, --screenshot <PATH>   Save screenshot to path
      --screenshot-at <N>   Frame to capture (default: timeout)
  -l, --level <PATH>        Load specific level file (RON format)
  -d, --debug               Enable debug output
  -h, --help                Print help
  -V, --version             Print version
```

## Logging

The game uses the `log` and `env_logger` crates for structured logging. Log levels:

- **error**: Critical failures (e.g., asset loading failure)
- **warn**: Non-critical issues with fallbacks (e.g., missing optional asset)
- **info**: Normal operation messages (e.g., level loading)
- **debug**: Detailed diagnostics (e.g., level transitions, state changes)

Enable debug logging:
```bash
RUST_LOG=debug cargo run

# Specific module
RUST_LOG=siriel_macroquad=debug cargo run

# All crates at debug level
RUST_LOG=debug cargo run
```

## Project Structure

```
siriel-macroquad/
├── src/                          # Source code
│   ├── main.rs                   # Entry point, game loop (~1558 lines)
│   ├── lib.rs                    # Library exports
│   ├── hud.rs                    # HUD rendering
│   ├── touch_controls.rs         # Mobile touch input
│   │
│   ├── core/                     # Core types and constants
│   │   ├── mod.rs
│   │   ├── constants.rs          # GAME_WIDTH, TILE_SIZE, etc.
│   │   ├── types.rs              # Shared types
│   │   ├── gamestate.rs          # GameMode, Transition, GameSession
│   │   └── camera.rs             # Camera with follow/auto-center
│   │
│   ├── assets/                   # Asset loading and management
│   │   ├── mod.rs
│   │   ├── tileset.rs            # Tileset with collision masks
│   │   ├── avatar.rs             # Player sprite loader
│   │   ├── objects.rs            # Entity sprite loader
│   │   └── collision_mask.rs     # Pixel-level collision data
│   │
│   ├── audio/                    # Sound system
│   │   └── mod.rs
│   │
│   ├── effects/                  # Visual effects
│   │   ├── mod.rs
│   │   └── particles.rs          # Particle system
│   │
│   ├── entities/                 # Game entities (creatures, enemies)
│   │   ├── mod.rs
│   │   ├── types.rs              # EntityType, BaseEntity, EntityCode
│   │   ├── creature.rs           # Creature entity with AI (~783 lines)
│   │   ├── ai.rs                  # Behavior types (patrol, chase, etc.)
│   │   ├── script.rs             # Entity scripting system
│   │   ├── manager.rs            # Entity lifecycle management
│   │   └── collision.rs          # Entity collision detection
│   │
│   ├── level/                    # Level system
│   │   ├── mod.rs
│   │   ├── types.rs              # LevelData, Tile, Layer structures
│   │   ├── manager.rs            # Level loading and transitions
│   │   ├── loader.rs             # RON file parsing
│   │   └── tests.rs              # Level validation tests
│   │
│   ├── menu/                     # Menu system with GLIST decoration
│   │   ├── mod.rs                # Menu struct, configuration
│   │   ├── item.rs               # MenuItem, MenuAction
│   │   ├── renderer.rs           # Menu drawing
│   │   ├── navigation.rs         # Input handling, touch support
│   │   └── decoration.rs         # GLIST tile decoration
│   │
│   ├── player/                   # Player logic
│   │   ├── mod.rs
│   │   ├── physics.rs            # Movement, collision, gravity
│   │   └── animation.rs          # Sprite animation
│   │
│   └── tilemap/                  # Tilemap rendering
│       └── mod.rs
│
├── assets/                       # Game assets
│   ├── sprites/                  # Spritesheets
│   │   ├── objects-fmis.png      # Entity sprites
│   │   ├── avatar.png            # Player sprites
│   │   └── tiles.png             # Tileset
│   ├── levels/                   # Level files (RON format)
│   │   ├── fmis01.ron through fmis12.ron
│   ├── audio/                    # Sound effects and music
│   │   └── ZASTALA.ogg
│   └── objects-fmis.ron          # Entity sprite definitions
│
├── xtask/                        # Build and development tools
│   └── src/main.rs               # WASM build/serve commands
├── bin/                          # Converter tools
│   └── convert_mie.rs            # MIE to RON converter
├── docs/                         # Documentation
│   ├── ARCHITECTURE.md           # System architecture
│   ├── LEVEL_FORMAT.md           # RON level format spec
│   └── PHASE_*.md                # Development phase docs
└── dist/                         # WASM build output (generated)
```

## Level Format: RON

Levels use **RON (Rusty Object Notation)** format. RON was chosen over TOML for:
1. **Rust-native** - Matches `LevelData` struct exactly, no format impedance mismatch
2. **Type-safe** - Direct deserialization to Rust types
3. **Complex structures** - Handles entities, messages, behaviors better than flat TOML
4. **Tool support** - `convert_mie.rs` outputs RON natively from original MIE files

Convert MIE files:
```bash
# Single file
cargo run --bin convert_mie -- ../siriel-levels/FMIS01.MIE

# Batch convert
cargo run --bin convert_mie -- --batch ../siriel-levels/
```

## Requirements

- Rust 1.95+
- Cargo
- For WASM: wasm32-unknown-unknown target
  ```bash
  rustup target add wasm32-unknown-unknown
  ```

## Development Tools

The `xtask` package provides development commands:

```bash
# Build WASM for deployment
cargo xtask build-wasm

# Build and serve locally (port 8000)
cargo xtask serve-wasm

# Serve on custom port
cargo xtask serve-wasm --port 3000

# Clean build artifacts
cargo xtask clean
```

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - System architecture overview
- [docs/LEVEL_FORMAT.md](docs/LEVEL_FORMAT.md) - RON level format specification
- [plan-refactor.txt](plan-refactor.txt) - Codebase refactor plan and structure analysis

## Architecture Highlights

**Game Loop:** `main.rs::main()` → `GameState` update/draw cycle

**Module Dependencies:**
```
main.rs
 ├─ core/ (types, constants, camera)
 ├─ assets/ (tileset, avatar, objects)
 ├─ level/ (manager, loader, types)
 ├─ entities/ (creature, AI, scripting)
 ├─ player/ (physics, animation)
 ├─ menu/ (GLIST decoration, navigation)
 ├─ audio/ (sound)
 ├─ effects/ (particles)
 ├─ tilemap/ (rendering)
 ├─ hud.rs (HUD display)
 └─ touch_controls.rs (mobile input)
```

**Key Systems:**
- **Camera:** Auto-center when level fits viewport, follow with deadzone otherwise
- **Collision:** Pixel-perfect via collision masks (not just tile index)
- **Entities:** Creature AI with behavior types (patrol, chase, bounce, etc.)
- **Menu:** GLIST tile-based decoration with keyboard/touch navigation
- **Level Loading:** RON format with entities, layers, properties

