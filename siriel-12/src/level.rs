use serde::Deserialize;

/// The overall Tiled map.
#[derive(Debug, Deserialize)]
pub struct TiledMap {
    pub height: u32,
    pub width: u32,
    pub tileheight: u32,
    pub tilewidth: u32,
    pub layers: Vec<TiledLayer>,
    // (Properties and tilesets are omitted or not used in this example.)
}

/// A layer in the Tiled map. We only care about tile layers and object layers.
#[derive(Debug, Deserialize)]
#[serde(tag = "type")]
pub enum TiledLayer {
    #[serde(rename = "tilelayer")]
    TileLayer {
        id: u32,
        name: String,
        visible: bool,
        opacity: f32,
        width: u32,
        height: u32,
        data: Vec<u32>,
        x: i32,
        y: i32,
    },
    #[serde(rename = "objectgroup")]
    ObjectLayer {
        id: u32,
        name: String,
        visible: bool,
        opacity: f32,
        draworder: String,
        objects: Vec<TiledObject>,
    },
}

/// A single object from an object layer.
#[derive(Debug, Deserialize)]
pub struct TiledObject {
    pub id: u32,
    pub name: String,
    #[serde(rename = "type")]
    pub object_type: String,
    pub x: f32,
    pub y: f32,
    pub width: Option<f32>,
    pub height: Option<f32>,
    pub properties: Option<Vec<TiledProperty>>,
}

/// A property attached to an object.
#[derive(Debug, Deserialize)]
pub struct TiledProperty {
    pub name: String,
    #[serde(rename = "type")]
    pub property_type: String,
    pub value: serde_json::Value,
}
