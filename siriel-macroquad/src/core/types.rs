// Siriel Macroquad - Core Types

#![allow(dead_code)]

use serde::{Deserialize, Serialize};

/// Animation name constants
pub mod anim {
    pub const IDLE: &str = "idle";
    pub const WALK_LEFT: &str = "walk_left";
    pub const WALK_RIGHT: &str = "walk_right";
    pub const WALK_UP: &str = "walk_up";
    pub const JUMP_UP: &str = "jump_up";
    pub const JUMP_LEFT: &str = "jump_left";
    pub const JUMP_RIGHT: &str = "jump_right";
    pub const PARACHUTE: &str = "parachute";
    pub const BACK: &str = "back";
    pub const EMPTY: &str = "empty";
    pub const STARS: &str = "stars";
}

/// 2D point with integer coordinates
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Point {
    pub x: i32,
    pub y: i32,
}

impl Point {
    pub fn new(x: i32, y: i32) -> Self {
        Self { x, y }
    }
}

/// Rectangle with integer coordinates
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Rect {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}

impl Rect {
    pub fn new(x: i32, y: i32, w: i32, h: i32) -> Self {
        Self { x, y, w, h }
    }

    pub fn contains(&self, point: Point) -> bool {
        point.x >= self.x
            && point.x < self.x + self.w
            && point.y >= self.y
            && point.y < self.y + self.h
    }

    pub fn overlaps(&self, other: &Rect) -> bool {
        self.x < other.x + other.w
            && self.x + self.w > other.x
            && self.y < other.y + other.h
            && self.y + self.h > other.y
    }
}

/// Animation loop mode
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum LoopMode {
    Once,
    Loop,
    PingPong,
}

/// Animation definition
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Animation {
    pub name: String,
    pub start_frame: i32,
    pub frame_count: i32,
    pub duration: f32,
    pub loop_mode: LoopMode,
}

/// Animation state
#[derive(Clone, Debug)]
pub struct AnimState {
    pub current: String,
    pub frame: i32,
    pub timer: f32,
    pub playing: bool,
}

impl AnimState {
    pub fn new(anim_name: &str) -> Self {
        Self {
            current: anim_name.to_string(),
            frame: 0,
            timer: 0.0,
            playing: true,
        }
    }

    pub fn set_anim(&mut self, anim_name: &str) {
        if self.current != anim_name {
            self.current = anim_name.to_string();
            self.frame = 0;
            self.timer = 0.0;
            self.playing = true;
        }
    }

    pub fn update(&mut self, animations: &[Animation], dt: f32) {
        if !self.playing {
            return;
        }

        let anim = match animations.iter().find(|a| a.name == self.current) {
            Some(a) => a,
            None => return,
        };

        if anim.frame_count == 0 {
            return;
        }

        self.timer += dt;
        if self.timer >= anim.duration {
            self.timer = 0.0;
            match anim.loop_mode {
                LoopMode::Loop => {
                    self.frame = (self.frame + 1) % anim.frame_count;
                }
                LoopMode::Once => {
                    if self.frame < anim.frame_count - 1 {
                        self.frame += 1;
                    } else {
                        self.playing = false;
                    }
                }
                LoopMode::PingPong => {
                    // TODO: Implement ping-pong
                    self.frame = (self.frame + 1) % anim.frame_count;
                }
            }
        }
    }
}

/// Level data structure
#[derive(Clone, Debug)]
pub struct LevelData {
    pub name: String,
    pub music: String,
    pub start_position: (i32, i32),
    pub width: usize,
    pub height: usize,
    pub tiles: Vec<Vec<i32>>,
}

impl LevelData {
    pub fn width(&self) -> usize {
        self.tiles.first().map(|row| row.len()).unwrap_or(0)
    }

    pub fn height(&self) -> usize {
        self.tiles.len()
    }

    pub fn get_tile(&self, x: usize, y: usize) -> i32 {
        self.tiles
            .get(y)
            .and_then(|row| row.get(x))
            .copied()
            .unwrap_or(0)
    }
}
