# MIE Level Format Documentation

This document describes the original Siriel 3.5 DOS .MIE level format and how it's converted to the modern RON format.

## Original MIE Format Structure

MIE files are text-based configuration files with a specific structure used by the original Siriel 3.5 DOS game.

### File Structure

```
[MENO]=<level_name>
[START]=<x>,<y>
[SNDSTART]=<sound_name>
[<entity_type>]=<param1>,<param2>,<param3>,<param4>[,<param5>]
...more entities...
[MAPA]=
<ascii_tilemap_data>
```

### Section Breakdown

#### 1. Level Metadata

- `[MENO]=<name>` - Level name identifier
- `[START]=<x>,<y>` - Player starting position in pixels
- `[SNDSTART]=<sound>` - Sound effect to play when level starts

#### 2. Entity Definitions

Entities are defined with the format: `[<TYPE>]=<x>,<y>,<behavior_id>,<param1>,<param2>[,<param3>]`

**Common Entity Types:**

- `[ZNNA]` - Normal enemy
  - Format: `[ZNNA]=<behavior_id>,<x>,<y>,<param1>,<param2>,<param3>`
  - Example: `[ZNNA]=1,8,17,1,3,10`
  
- `[ZANA]` - Special enemy
  - Format: `[ZANA]=<behavior_id>,<x>,<y>,<param1>,<param2>,<param3>`
  - Example: `[ZANA]=6,17,29,1,3,50`
  
- `[YNN~]` - Pickup item
  - Format: `[YNN~]=<item_id>,<x>,<y>,<value>,<type>`
  - Example: `[YNN~]=10,76,34,9,1`

**Parameter Meanings:**
- `x,y` - Position in pixels (original coordinate system)
- `behavior_id` - Defines entity AI behavior (1-18)
- `param1,param2,param3` - Behavior-specific parameters

#### 3. Tilemap Data

- `[MAPA]=` - Marks the start of tilemap data
- Each subsequent line represents one row of tiles
- Width: 39 characters per row
- Height: 27 rows
- ASCII characters map directly to tile IDs via their ASCII codes

**Character-to-Tile Mapping:**
```
ASCII Character -> Tile ID
' ' (space, 32)  -> 0 (empty)
'!' (33)         -> 1
'"' (34)         -> 2
...
'~' (126)        -> 94
```

**Special Characters in Original Maps:**
- `\u000f` (ASCII 15) - Empty space/air
- `'` (apostrophe) - Platform tile
- `*`, `+`, `-` - Various platform/wall tiles
- `(`, `)` - Curved platform pieces
- Numbers and letters - Special tiles

## Coordinate System Conversion

### Original DOS System
- Origin (0,0) at **top-left**
- X increases **rightward**
- Y increases **downward**
- Tile size: 16x16 pixels

### Modern Bevy System
- Origin (0,0) at **bottom-left**  
- X increases **rightward**
- Y increases **upward**
- Tile size: 16x16 pixels

### Conversion Formulas

**For Tilemaps:**
```rust
// Convert Y coordinate for tiles
bevy_y = level_height - 1 - original_y

// For 27-row map: bevy_y = 26 - original_y
```

**For Entities and Player:**
```rust
// Convert Y coordinate for entities/player
bevy_y = (level_height * 16.0) - original_y

// For 27-row map: bevy_y = 432.0 - original_y  
```

## Modern RON Format Structure

The converted levels use RON (Rusty Object Notation) with this structure:

```ron
(
    name: "START",
    width: 39,
    height: 27,
    spawn_point: (88.0, 344.0),
    background_image: None,
    tilemap: [
        // 2D array of tile IDs (u16)
        [0, 0, 0, ...],
        [0, 0, 1, ...],
        // ...
    ],
    entities: [
        (
            id: "ZNNA_0",
            entity_type: "ZNNA",
            position: (8.0, 415.0),
            sprite_id: 1,
            behavior_type: 1,
            behavior_params: [1, 3, 10, 0, 0, 0, 0],
            room: 1,
            pickupable: false,
            pickup_value: 0,
            sound_effects: None,
        ),
        // ...more entities...
    ],
    transitions: [],
    scripts: [],
    music: None,
    time_limit: Some(300.0),
)
```

## Entity Behavior Mapping

The original game uses 18 different behavior types (1-18). Here's the mapping:

| Behavior ID | Original Name | Modern BehaviorType | Description |
|------------|---------------|-------------------|-------------|
| 1 | Static | Static | Stationary entity |
| 2 | Horizontal Oscillator | HorizontalOscillator | Moves left-right between boundaries |
| 3 | Vertical Oscillator | VerticalOscillator | Moves up-down between boundaries |
| 4 | Platform w/ Gravity | PlatformWithGravity | Moving platform affected by gravity |
| 5 | Edge Walking | EdgeWalkingPlatform | Walks along platform edges |
| 6-11 | Various AI | Static | (Mapped to static for now) |
| 12 | Random Movement | RandomMovement | Moves randomly |
| 13-14 | Projectiles | Static | (Mapped to static for now) |
| 15 | Fireball | Fireball | Fire projectile |
| 16 | Hunter | Hunter | Seeks player |
| 17 | Sound Trigger | SoundTrigger | Plays sound on trigger |
| 18 | Advanced Projectile | AdvancedProjectile | Complex projectile AI |

## Conversion Process

### 1. Parse MIE File
1. Read metadata section ([MENO], [START], [SNDSTART])
2. Parse entity definitions (all [TYPE] entries before [MAPA])
3. Parse ASCII tilemap data (everything after [MAPA])

### 2. Convert Coordinates
1. Convert tilemap Y-coordinates using tile-based formula
2. Convert entity Y-coordinates using pixel-based formula
3. Keep X-coordinates unchanged

### 3. Map Entity Types
1. Convert entity type strings to modern enum values
2. Map behavior IDs to modern behavior types
3. Convert parameters to modern parameter arrays
4. Set additional properties (pickupable, sound_effects, etc.)

### 4. Generate Modern Structure
1. Create LevelData with converted tilemap
2. Add converted entities with proper positioning
3. Set spawn point with coordinate conversion
4. Add empty collections for transitions/scripts (for future expansion)

## Usage Examples

### Convert Single File
```bash
cargo run --bin convert_mie -- ../siriel-3.5-dos/BIN/DISKY/FIRSTMIS/1.MIE assets/levels/level1.ron
```

### Batch Convert Directory
```bash
cargo run --bin convert_mie -- --batch ../siriel-3.5-dos/BIN/DISKY/FIRSTMIS/
```

### Load Converted Level in Game
```rust
// Modified level loading system now tries RON files first
pub fn load_level_system(
    mut commands: Commands,
    mut tilemap_manager: ResMut<TilemapManager>,
    sprite_atlas: Res<SpriteAtlas>,
) {
    // Try RON file first, then MIE as fallback
    let level_data = match load_level_from_file("1.ron") {
        Ok(level) => {
            info!("Loaded RON level: {}", level.name);
            level
        }
        Err(_) => match load_mie_level("../siriel-3.5-dos/BIN/DISKY/FIRSTMIS/1.MIE") {
            Ok(mie_level) => {
                info!("Loaded MIE level: {}", mie_level.name);
                convert_mie_to_level_data(mie_level)
            }
            Err(_) => create_test_level(),
        }
    };
    
    // ... rest of loading logic
}
```

## Benefits of Conversion

### 1. **Performance**
- No parsing overhead during game startup
- Faster level loading times
- Pre-processed coordinate conversion

### 2. **Maintainability**
- Human-readable RON format
- Easy to edit and modify levels
- Version control friendly
- Extensible structure for new features

### 3. **Development Workflow**
- Preserve original content exactly
- Add modern features (scripts, transitions)
- Easy to debug and inspect
- Supports incremental enhancement

### 4. **Future Expansion**
- Add level scripts for interactive elements
- Implement level transitions/doors
- Support custom properties per level
- Easy A/B testing with level variants

## File Organization

```
siriel-bevy/
├── assets/
│   └── levels/           # Converted RON files
│       ├── 1.ron         # Level 1 (converted from 1.MIE)
│       ├── 2.ron         # Level 2 (converted from 2.MIE)
│       └── ...
├── docs/
│   └── MIE_FORMAT.md     # This documentation
├── src/
│   ├── bin/
│   │   └── convert_mie.rs # Conversion tool
│   ├── level.rs          # Level loading and modern format
│   └── mie_parser.rs     # Original MIE format parser
└── siriel-3.5-dos/      # Original DOS game files
    └── BIN/DISKY/FIRSTMIS/
        ├── 1.MIE         # Original level files
        ├── 2.MIE
        └── ...
```