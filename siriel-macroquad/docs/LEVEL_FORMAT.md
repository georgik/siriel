# Siriel Macroquad - Level Format Documentation

## Overview

Siriel Macroquad uses a Rust-native level format that supports both compile-time inclusion (levels baked into binary) and runtime loading (levels loaded from files).

## Level Structure

### Metadata

```rust
pub struct LevelMeta {
    pub name: String,      // Level display name
    pub author: String,    // Level author
    pub version: String,   // Format version
    pub width: usize,      // Map width in tiles
    pub height: usize,     // Map height in tiles
}
```

### Level Data

```rust
pub struct Level {
    pub meta: LevelMeta,           // Level metadata
    pub tiles: Vec<Vec<i32>>,      // 2D tile array
    pub player_start: (i32, i32),  // Spawn position in pixels
}
```

## Tile Values

| Value | Type        | Description          |
|-------|-------------|----------------------|
| 0     | Empty       | Walkable space       |
| 1-23  | Decoration  | Non-solid tiles      |
| 24+   | Solid       | Walls, ground, platforms |

## Level File Format

### Format Specification

Level files use simple Rust-like syntax:

```
// Comment lines start with //
name: "Level Name"
author: "Author Name"
player_start: (x, y)
tiles: [[row1], [row2], ...]
```

### Example Level File

```
// Siriel Macroquad - Level 01
name: "Level 01 - The Beginning"
author: "Siriel Team"
player_start: (88, 88)
tiles: [
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 24, 24, 24, 24, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0],
    [24, 24, 24, 24, 24, 24, 24, 24],
]
```

### Coordinate Systems

**Player Start:** Pixels from top-left
- `(88, 88)` = 88px right, 88px down
- Screen size: 336x208 pixels
- Tile size: 8x8 pixels

**Tiles:** Row-major 2D array
- `tiles[y][x]` = tile at column x, row y
- Origin: top-left corner

## Implementation Patterns

### Compile-Time Level

```rust
pub struct Level1;

impl LevelDef for Level1 {
    fn meta() -> LevelMeta {
        LevelMeta {
            name: "Level 1".to_string(),
            author: "Author".to_string(),
            version: "1.0".to_string(),
            width: 42,
            height: 26,
        }
    }

    fn tiles() -> Vec<Vec<i32>> {
        vec![
            vec![0; 42],
            vec![24; 42],
            // ... more rows
        ]
    }

    fn player_start() -> (i32, i32) {
        (88, 88)
    }
}
```

### Runtime Level Loading

```rust
use std::path::Path;
use crate::level::load_from_file;

let level = load_from_file(Path::new("assets/levels/level1.rs"))?;
```

### Using Level in Game

```rust
// Load level
let level = Level::empty();
let tiles = level.tiles;

// Render tilemap
draw_tilemap(&tileset, &tiles, offset_x, offset_y);

// Player collision
physics.update_with_collision(&tiles, dt);
```

## Level Design Guidelines

### Dimensions

- **Width:** 42 tiles (336 pixels)
- **Height:** 26 tiles (208 pixels)
- **Tile Size:** 8x8 pixels
- **Sprite Size:** 16x16 pixels

### Solid Tiles

Use tile ID >= 24 for:
- Ground surfaces
- Walls
- Platforms
- Obstacles

### Player Start

Recommended spawn zones:
- Top area of map
- Away from hazards
- Clear space below

## Tools

### Creating Levels

1. Use text editor with Rust syntax
2. Visual editor (future)
3. Convert from existing formats (future)

### Testing Levels

```bash
# Test parser
cargo test parse_level

# Run game with level
cargo run --release

# Validate level format
cargo test
```

## Migration from Original Format

Original DOS levels can be converted by:
1. Extract tile data from original files
2. Map tile IDs to new system
3. Add metadata
4. Set player spawn position

## Performance

**Compile-Time:**
- Zero runtime overhead
- Binary size increase: ~1KB per level

**Runtime:**
- Parse time: <1ms per level
- Memory: ~4KB per loaded level
