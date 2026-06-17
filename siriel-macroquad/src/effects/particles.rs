// Siriel Macroquad - Particle System

#![allow(dead_code)]

use macroquad::prelude::*;

/// Particle types
#[derive(Debug, Clone, PartialEq)]
pub enum ParticleType {
    Explosion,
    Sparkle,
    Trail,
    Smoke,
    Dust,
}

/// Single particle
#[derive(Debug, Clone)]
pub struct Particle {
    pub x: f32,
    pub y: f32,
    pub vx: f32,
    pub vy: f32,
    pub life: f32,
    pub max_life: f32,
    pub size: f32,
    pub color: Color,
    pub particle_type: ParticleType,
}

impl Particle {
    pub fn new(x: f32, y: f32, particle_type: ParticleType) -> Self {
        let (vx, vy, life, size, color) = match particle_type {
            ParticleType::Explosion => (
                rand::gen_range(-3.0, 3.0),
                rand::gen_range(-3.0, 3.0),
                0.5,
                rand::gen_range(2.0, 6.0),
                ORANGE,
            ),
            ParticleType::Sparkle => (
                rand::gen_range(-1.0, 1.0),
                rand::gen_range(-2.0, 0.0),
                0.3,
                rand::gen_range(2.0, 4.0),
                YELLOW,
            ),
            ParticleType::Trail => (
                rand::gen_range(-0.5, 0.5),
                rand::gen_range(-0.5, 0.5),
                0.2,
                rand::gen_range(1.0, 3.0),
                WHITE,
            ),
            ParticleType::Smoke => (
                rand::gen_range(-0.5, 0.5),
                rand::gen_range(-1.0, 0.0),
                0.8,
                rand::gen_range(4.0, 8.0),
                GRAY,
            ),
            ParticleType::Dust => (
                rand::gen_range(-1.0, 1.0),
                rand::gen_range(-0.5, 0.0),
                0.3,
                rand::gen_range(2.0, 4.0),
                Color::new(0.7, 0.7, 0.6, 1.0),
            ),
        };

        Self {
            x,
            y,
            vx,
            vy,
            life,
            max_life: life,
            size,
            color,
            particle_type,
        }
    }

    pub fn update(&mut self, dt: f32) {
        self.x += self.vx;
        self.y += self.vy;
        self.life -= dt;

        // Apply gravity to some types
        match self.particle_type {
            ParticleType::Explosion | ParticleType::Dust => {
                self.vy += 0.1;
            }
            ParticleType::Smoke => {
                self.vy -= 0.05; // Rise up
                self.vx *= 0.98; // Slow down
            }
            _ => {}
        }
    }

    pub fn is_alive(&self) -> bool {
        self.life > 0.0
    }

    pub fn alpha(&self) -> f32 {
        (self.life / self.max_life).max(0.0).min(1.0)
    }

    pub fn draw(&self) {
        let alpha = self.alpha();
        let color = Color::new(self.color.r, self.color.g, self.color.b, alpha);

        match self.particle_type {
            ParticleType::Explosion | ParticleType::Dust => {
                draw_circle(self.x, self.y, self.size / 2.0, color);
            }
            ParticleType::Sparkle => {
                let s = self.size;
                draw_line(self.x - s, self.y, self.x + s, self.y, 1.0, color);
                draw_line(self.x, self.y - s, self.x, self.y + s, 1.0, color);
            }
            ParticleType::Trail => {
                draw_circle(self.x, self.y, self.size / 2.0, color);
            }
            ParticleType::Smoke => {
                draw_circle(self.x, self.y, self.size / 2.0, color);
            }
        }
    }
}

/// Particle system manager
#[derive(Debug)]
pub struct ParticleSystem {
    particles: Vec<Particle>,
}

impl ParticleSystem {
    pub fn new() -> Self {
        Self {
            particles: Vec::new(),
        }
    }

    /// Emit particles at position
    pub fn emit(&mut self, x: f32, y: f32, particle_type: ParticleType, count: usize) {
        for _ in 0..count {
            self.particles
                .push(Particle::new(x, y, particle_type.clone()));
        }
    }

    /// Create explosion effect
    pub fn explosion(&mut self, x: f32, y: f32) {
        self.emit(x, y, ParticleType::Explosion, 15);
        self.emit(x, y, ParticleType::Smoke, 5);
    }

    /// Create sparkle effect
    pub fn sparkle(&mut self, x: f32, y: f32) {
        self.emit(x, y, ParticleType::Sparkle, 8);
    }

    /// Create trail effect
    pub fn trail(&mut self, x: f32, y: f32) {
        self.emit(x, y, ParticleType::Trail, 2);
    }

    /// Create dust effect
    pub fn dust(&mut self, x: f32, y: f32) {
        self.emit(x, y, ParticleType::Dust, 5);
    }

    /// Update all particles
    pub fn update(&mut self, dt: f32) {
        for particle in &mut self.particles {
            particle.update(dt);
        }
        self.particles.retain(|p| p.is_alive());
    }

    /// Draw all particles
    pub fn draw(&self) {
        for particle in &self.particles {
            particle.draw();
        }
    }

    /// Get particle count
    pub fn count(&self) -> usize {
        self.particles.len()
    }

    /// Clear all particles
    pub fn clear(&mut self) {
        self.particles.clear();
    }
}

impl Default for ParticleSystem {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_particle_creation() {
        let particle = Particle::new(100.0, 100.0, ParticleType::Explosion);
        assert_eq!(particle.x, 100.0);
        assert_eq!(particle.y, 100.0);
        assert!(particle.is_alive());
    }

    #[test]
    fn test_particle_update() {
        let mut particle = Particle::new(100.0, 100.0, ParticleType::Explosion);
        particle.update(0.1);
        assert!(particle.life < particle.max_life);
        assert!(particle.x != 100.0 || particle.y != 100.0);
    }

    #[test]
    fn test_particle_death() {
        let mut particle = Particle::new(100.0, 100.0, ParticleType::Explosion);
        particle.life = 0.0;
        assert!(!particle.is_alive());
    }

    #[test]
    fn test_particle_alpha() {
        let particle = Particle::new(100.0, 100.0, ParticleType::Explosion);
        let alpha = particle.alpha();
        assert!(alpha >= 0.0 && alpha <= 1.0);
    }

    #[test]
    fn test_system_creation() {
        let system = ParticleSystem::new();
        assert_eq!(system.count(), 0);
    }

    #[test]
    fn test_emit() {
        let mut system = ParticleSystem::new();
        system.emit(100.0, 100.0, ParticleType::Sparkle, 5);
        assert_eq!(system.count(), 5);
    }

    #[test]
    fn test_explosion() {
        let mut system = ParticleSystem::new();
        system.explosion(100.0, 100.0);
        assert_eq!(system.count(), 20); // 15 explosion + 5 smoke
    }

    #[test]
    fn test_sparkle() {
        let mut system = ParticleSystem::new();
        system.sparkle(100.0, 100.0);
        assert_eq!(system.count(), 8);
    }

    #[test]
    fn test_trail() {
        let mut system = ParticleSystem::new();
        system.trail(100.0, 100.0);
        assert_eq!(system.count(), 2);
    }

    #[test]
    fn test_dust() {
        let mut system = ParticleSystem::new();
        system.dust(100.0, 100.0);
        assert_eq!(system.count(), 5);
    }

    #[test]
    fn test_update_removes_dead() {
        let mut system = ParticleSystem::new();
        system.emit(100.0, 100.0, ParticleType::Sparkle, 5);
        system.update(10.0); // Large DT to kill all
        assert_eq!(system.count(), 0);
    }

    #[test]
    fn test_clear() {
        let mut system = ParticleSystem::new();
        system.emit(100.0, 100.0, ParticleType::Sparkle, 5);
        system.clear();
        assert_eq!(system.count(), 0);
    }
}
