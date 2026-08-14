# Siriel Macroquad - Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Game Loop                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Input      │  │   Update     │  │   Render     │    │
│  │  Handler     │─>│   Physics    │─>│   Engine     │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Module Layers                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Core Layer (constants, types)                       │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Assets Layer (tileset, avatar)                      │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Game Layer (player, physics, animation)              │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Macroquad Framework                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Texture  │  │ Drawing  │  │  Input   │  │   Audio  │    │
│  │  Loader  │  │  Engine  │  │ Handler  │  │  System  │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      MiniQuad Backend                         │
│                   (OpenGL context management)                │
└─────────────────────────────────────────────────────────────┘
```

## Module Responsibilities

### Core Module

**Purpose:** Shared constants and data structures

**Responsibilities:**
- Define game-wide constants (screen size, physics values)
- Provide common data structures (Point, Rect, Animation)
- No dependencies on other game modules

**Dependencies:** None

### Assets Module

**Purpose:** Asset loading and rendering

**Responsibilities:**
- Load texture files from disk
- Parse spritesheet layouts
- Provide drawing utilities
- Manage animation definitions

**Dependencies:**
- Core (for constants and types)
- Macroquad (for texture loading)

### Player Module

**Purpose:** Player character logic

**Responsibilities:**
- Handle keyboard input
- Update physics (gravity, velocity, position)
- Determine animation state
- Provide position query interface

**Dependencies:**
- Core (for constants)
- Macroquad (for input handling)

## Data Flow

### Initialization Phase

```
main()
  ├─> Parse CLI arguments
  ├─> Load AvatarAtlas
  │   └─> load_texture("siriel-avatar.png")
  ├─> Load Tileset
  │   └─> load_texture("texture-basic.png")
  └─> Create PhysicsState
```

### Game Loop Phase

```
loop
  ├─> Handle Input
  │   ├─> is_key_down(KeyCode::Escape) → break
  │   ├─> is_key_down(KeyCode::Left/Right) → movement
  │   └─> is_key_pressed(KeyCode::Space) → jump
  │
  ├─> Update Physics
  │   ├─> Apply gravity to velocity
  │   ├─> Apply input to position
  │   └─> Check ground collision
  │
  ├─> Update Animation
  │   ├─> Get animation name from physics state
  │   ├─> Update animation frame timer
  │   └─> Advance frame if duration exceeded
  │
  ├─> Render
  │   ├─> Clear screen
  │   ├─> Draw game area
  │   ├─> Draw tilemap
  │   ├─> Draw player avatar
  │   └─> Draw HUD text
  │
  └─> next_frame().await (complete frame)
```

## Coordinate Systems

### Screen Coordinates

- **Origin:** Top-left corner (0, 0)
- **X-axis:** Increases to the right
- **Y-axis:** Increases downward
- **Screen size:** 1280x960 pixels

### Game Area Coordinates

- **Position:** Centered on screen
- **Size:** 640x480 pixels
- **Offset X:** (1280 - 640) / 2 = 320 pixels
- **Offset Y:** (960 - 480) / 2 + 20 = 260 pixels

### Tile Coordinates

- **Tile size:** 8x8 pixels (map)
- **Sprite size:** 16x16 pixels (spritesheet)
- **Scale factor:** 0.5 (spritesheet to map)

## Animation System

### State Machine

```
Physics State
    │
    ├─> on_ground == true
    │   ├─> vx == 0 → "idle_down"
    │   ├─> vx < 0 → "left"
    │   └─> vx > 0 → "right"
    │
    └─> on_ground == false
        ├─> vy < 0 → "jump_up"
        └─> vy > 0 → "parachute"
```

### Animation Update

```
for each frame:
    timer += delta_time
    if timer >= duration:
        timer = 0
        match loop_mode:
            Loop → frame = (frame + 1) % frame_count
            Once → if frame < count - 1: frame += 1
            PingPong → (reverse direction)
```

## Asset Loading Pipeline

### Texture Loading

```
load_texture(path)
    ├─> Resolve path relative to executable
    ├─> Load PNG file
    ├─> Upload to GPU
    ├─> Set filter mode (Nearest for pixel art)
    └─> Return Texture2D handle
```

### Spritesheet Parsing

```
Tileset::load(path)
    ├─> Load texture
    ├─> Calculate grid dimensions
    │   ├─> columns = width / SPRITE_SIZE
    │   └─> rows = height / SPRITE_SIZE
    ├─> Store tile count
    └─> Return Tileset
```

## Rendering Pipeline

### Frame Rendering Order

```
1. Clear background (WHITE)
2. Calculate game area position
3. Draw game area background (DARKGRAY)
4. Draw game area border (BLACK)
5. Draw tilemap tiles
6. Draw player avatar
7. Draw HUD text
8. Complete frame (next_frame)
```

### Batch Rendering

Macroquad automatically batches draw calls:
- Same texture draws are grouped
- Minimizes state changes
- Optimized GPU usage

### Texture Sampling

- **Filter Mode:** Nearest (no interpolation)
- **Wrap Mode:** Clamp
- **Format:** RGBA8
- **Mipmaps:** Disabled (pixel art)

## Input Handling

### Key States

```
is_key_down(KeyCode) → bool (continuous press)
is_key_pressed(KeyCode) → bool (single frame)
is_key_released(KeyCode) → bool (single frame)
```

### Key Bindings

| Key | Action | State |
|-----|--------|-------|
| Left | Move left | is_key_down |
| Right | Move right | is_key_down |
| Space | Jump | is_key_pressed |
| Escape | Exit | is_key_down |

## Physics Model

### Movement

```
position.x += velocity.x
position.y += velocity.y
velocity.y += gravity
```

### Collision

```
// Current implementation (simplified)
if position.y > ground_level:
    position.y = ground_level
    velocity.y = 0
    on_ground = true
```

### Constants

```
GRAVITY = 0.5     // pixels/frame^2
MOVE_SPEED = 1.0  // pixels/frame
JUMP_FORCE = -6.0 // initial jump velocity
```

## Build System

### Compilation

```
Source Files (.rs)
    ├─> rustc (compilation)
    ├─> cargo (dependency management)
    └─> macroquad (framework linking)
```

### Optimization

**Release Profile:**
- opt-level = "z" (optimize for size)
- lto = true (link-time optimization)
- codegen-units = 1 (better optimization)
- strip = true (remove symbols)

**Dev Profile:**
- Dependencies built with opt-level = 3
- Fast iteration despite release artifacts

## Platform Differences

### Desktop

- Direct file system access
- Native window management
- Full keyboard input
- No canvas limitations

### WASM

- Assets served via HTTP
- Canvas-based rendering
- Requires focus for keyboard
- Limited WebGL 1 fallback

## Performance Considerations

### Memory Usage

```
Static:
- Textures: ~50 KB (compressed)
- Code: ~1.4 MB
- Runtime heap: 10-20 MB

Per-frame:
- Sprite batches: Minimal (automatic)
- State updates: O(1) complexity
- Render calls: Batched automatically
```

### CPU Usage

```
Main thread:
- Input handling: < 1ms
- Physics update: < 1ms
- Rendering: 1-2ms
- Total: < 5ms per frame (at 60 FPS)
```

### Optimization Opportunities

1. **Tile culling:** Only draw visible tiles
2. **Object pooling:** Reuse animation states
3. **Lazy loading:** Load assets on demand
4. **Texture atlases:** Combine sprite sheets

## Security Considerations

### Asset Loading

- Path validation prevents directory traversal
- Only PNG format supported
- File size limits implicit in memory constraints

### User Input

- No code execution from user input
- Keyboard input only for game control
- CLI args parsed safely (clap)

## Extensibility Points

### Adding New Animations

```rust
// In AvatarAtlas::load()
animations.push(Animation {
    name: "new_anim".into(),
    start_frame: N,
    frame_count: N,
    duration: 0.1,
    loop_mode: LoopMode::Loop,
});
```

### Adding New Tilesets

```rust
// Create new asset module
pub struct NewTileset {
    pub texture: Texture2D,
    pub columns: i32,
    // ...
}

impl NewTileset {
    pub async fn load(path: &str) -> Result<Self, String> {
        // Same pattern as Tileset
    }
}
```

### Custom Physics

```rust
// Implement alternative physics system
pub struct CustomPhysics {
    // Custom state
}

impl CustomPhysics {
    pub fn update(&mut self, tilemap: &[Vec<i32>]) {
        // Custom collision logic
    }
}
```
