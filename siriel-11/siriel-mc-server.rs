use valence::prelude::*;

use std::fs;
use valence::entity::chicken::ChickenEntityBundle;

const SPAWN_Y: i32 = 64;

pub fn main() {
    App::new()
        .insert_resource(NetworkSettings {
            connection_mode: ConnectionMode::Offline, // Set to offline mode
            ..Default::default()
        })
        .add_plugins(DefaultPlugins)
        .add_systems(Startup, setup)
        .add_systems(Update,
                     (init_clients,
                      toggle_gamemode_on_sneak,
                      despawn_disconnected_clients))
        .run();
}

fn setup(
    mut commands: Commands,
    server: Res<Server>,
    dimensions: Res<DimensionTypeRegistry>,
    biomes: Res<BiomeRegistry>,
) {
    let mut layer = LayerBundle::new(ident!("overworld"), &dimensions, &biomes, &server);

    for z in -5..5 {
        for x in -5..5 {
            layer.chunk.insert_chunk([x, z], UnloadedChunk::new());
        }
    }

    for z in -25..25 {
        for x in -25..25 {
            layer
                .chunk
                .set_block([x, SPAWN_Y, z], BlockState::GRASS_BLOCK);
        }
    }


    println!("Initializing server...");
    // Load the level file
    let level_data = fs::read_to_string("FMIS01.MIE").expect("Failed to read level file");

    // Parse the map manually
    let map_start = level_data.find("map = {").expect("Map section not found");
    let map_end = level_data.find("}").expect("End of map section not found");
    let map_data = &level_data[map_start + 7..map_end];

    let map: Vec<String> = map_data
        .lines()
        .map(|line| line.trim()) // Trim leading/trailing whitespace
        .filter(|line| !line.is_empty() && !line.starts_with("map") && !line.starts_with('{') && !line.starts_with('}'))
        .map(|line| line.trim_matches(&['"', ',', ' '][..]).to_string()) // Remove quotes, commas, and extra spaces
        .collect();


    for (y, row) in map.iter().enumerate() {
        for (x, tile) in row.chars().enumerate() {
            print!("{}", tile);
            let block_state = match tile {
                '.' => continue,
                'F' => BlockState::STONE,
                'I' => BlockState::GLASS,
                'H' => BlockState::BIRCH_WOOD,
                '6' => BlockState::COBBLESTONE,
                _ => BlockState::DIRT,
            };

            // Inflate the tile into a 5x5 horizontal space and stack 5 vertically

            layer.chunk.set_block(
                [x as i32, SPAWN_Y + y as i32, 1 as i32],
                BlockState::GRASS_BLOCK,
            );

        }
        println!(".");
    }

    // layer.chunk.set_block(CHEST_POS, BlockState::CHEST);

    let layer_id = commands.spawn(layer).id();
    // commands.spawn(layer);

    let inventory = Inventory::with_title(
        InventoryKind::Generic9x3,
        "Extra".italic() + " ChestyX".not_italic().bold().color(Color::BLUE) + " Chest".not_italic(),
    );

    commands.spawn(inventory);
    // Spawn a chicken
    // commands.spawn((
    //     ChickenEntityBundle {
    //         layer: EntityLayerId(layer_id),
    //         position: Position::new([1.0, f64::from(SPAWN_Y) + 1.0, 0.0]),
    //         ..Default::default()
    //     },
    //     WanderingChicken,
    // ));
}

fn init_clients(
    mut clients: Query<
        (
            &mut EntityLayerId,
            &mut VisibleChunkLayer,
            &mut VisibleEntityLayers,
            &mut Position,
            &mut GameMode,
        ),
        Added<Client>,
    >,
    layers: Query<Entity, (With<ChunkLayer>, With<EntityLayer>)>,
) {
    for (
        mut layer_id,
        mut visible_chunk_layer,
        mut visible_entity_layers,
        mut pos,
        mut game_mode,
    ) in &mut clients
    {
        let layer = layers.single();

        layer_id.0 = layer;
        visible_chunk_layer.0 = layer;
        visible_entity_layers.0.insert(layer);
        pos.set([0.0, f64::from(SPAWN_Y) + 1.0, 0.0]);
        *game_mode = GameMode::Creative;
    }
}

fn toggle_gamemode_on_sneak(
    mut clients: Query<&mut GameMode>,
    mut events: EventReader<SneakEvent>,
) {
    for event in events.read() {
        if let Ok(mut mode) = clients.get_mut(event.client) {
            if event.state == SneakState::Start {
                *mode = match *mode {
                    GameMode::Survival => GameMode::Creative,
                    GameMode::Creative => GameMode::Survival,
                    _ => GameMode::Creative,
                };
            }
        }
    }
}


