// Siriel Macroquad - Script System
// Handles event triggers and commands

#![allow(dead_code)]

use crate::entities::Creature;

/// Script event triggers
#[derive(Debug, Clone, PartialEq)]
pub enum ScriptEvent {
    /// Player entered a specific area
    EnterArea { x: i32, y: i32, w: i32, h: i32 },
    /// Player picked up specific item type
    ItemPicked { item_type: i32 },
    /// Player health changed
    HealthChanged { current: i32, previous: i32 },
    /// Creature collected/activated
    CreatureActivated { index: usize },
    /// Level started
    LevelStart,
    /// Custom trigger
    Custom { id: String },
}

/// Script commands
#[derive(Debug, Clone, PartialEq)]
pub enum ScriptCommand {
    /// Show message to player
    ShowMessage(String),
    /// Play sound
    PlaySound(String),
    /// Change level
    ChangeLevel(String),
    /// Teleport player
    Teleport { x: i32, y: i32 },
    /// Modify player health
    AddHealth(i32),
    /// Set player health
    SetHealth(i32),
    /// Reveal creature group
    RevealGroup(char),
    /// Hide creature group
    HideGroup(char),
    /// Kill player
    KillPlayer,
    /// Wait (delay)
    Wait(f32),
    /// Conditional
    If {
        condition: ScriptCondition,
        then_cmds: Vec<ScriptCommand>,
        else_cmds: Option<Vec<ScriptCommand>>,
    },
}

/// Script conditions
#[derive(Debug, Clone, PartialEq)]
pub enum ScriptCondition {
    /// Check if player has X health
    HealthEquals(i32),
    /// Check if player health is greater than
    HealthGreaterThan(i32),
    /// Check if player health is less than
    HealthLessThan(i32),
    /// Check if creature is alive
    CreatureAlive(usize),
    /// Check if creature is collected
    CreatureCollected(usize),
    /// Check variable
    VariableEquals(String, i32),
    /// Always true
    Always,
}

/// Script - event with associated commands
#[derive(Debug, Clone)]
pub struct Script {
    pub event: ScriptEvent,
    pub commands: Vec<ScriptCommand>,
    pub one_shot: bool,  // Only trigger once
    pub triggered: bool, // Has been triggered
}

impl Script {
    pub fn new(event: ScriptEvent, commands: Vec<ScriptCommand>) -> Self {
        Self {
            event,
            commands,
            one_shot: false,
            triggered: false,
        }
    }

    pub fn one_shot(mut self) -> Self {
        self.one_shot = true;
        self
    }

    /// Check if script should trigger
    pub fn should_trigger(&self, trigger_event: &ScriptEvent) -> bool {
        if self.one_shot && self.triggered {
            return false;
        }
        &self.event == trigger_event
    }

    /// Mark as triggered
    pub fn mark_triggered(&mut self) {
        self.triggered = true;
    }
}

/// Script executor - runs commands
pub struct ScriptExecutor {
    pub variables: std::collections::HashMap<String, i32>,
    pub wait_timer: f32,
    pub current_script: Option<usize>,
}

impl ScriptExecutor {
    pub fn new() -> Self {
        Self {
            variables: std::collections::HashMap::new(),
            wait_timer: 0.0,
            current_script: None,
        }
    }

    /// Execute script commands
    pub fn execute(
        &mut self,
        commands: &[ScriptCommand],
        player_health: &mut i32,
        creatures: &mut [Creature],
        dt: f32,
    ) -> ScriptResult {
        if self.wait_timer > 0.0 {
            self.wait_timer -= dt;
            return ScriptResult::Waiting;
        }

        for cmd in commands {
            match cmd {
                ScriptCommand::ShowMessage(msg) => {
                    return ScriptResult::Message(msg.clone());
                }
                ScriptCommand::PlaySound(sound) => {
                    return ScriptResult::Sound(sound.clone());
                }
                ScriptCommand::ChangeLevel(level) => {
                    return ScriptResult::ChangeLevel(level.clone());
                }
                ScriptCommand::Teleport { x, y } => {
                    return ScriptResult::Teleport(*x, *y);
                }
                ScriptCommand::AddHealth(amount) => {
                    *player_health += *amount;
                }
                ScriptCommand::SetHealth(amount) => {
                    *player_health = *amount;
                }
                ScriptCommand::RevealGroup(group) => {
                    for creature in creatures.iter_mut() {
                        if creature.group == Some(*group) {
                            creature.visible = true;
                        }
                    }
                }
                ScriptCommand::HideGroup(group) => {
                    for creature in creatures.iter_mut() {
                        if creature.group == Some(*group) {
                            creature.visible = false;
                        }
                    }
                }
                ScriptCommand::KillPlayer => {
                    *player_health = 0;
                }
                ScriptCommand::Wait(duration) => {
                    self.wait_timer = *duration;
                    return ScriptResult::Waiting;
                }
                ScriptCommand::If {
                    condition,
                    then_cmds,
                    else_cmds,
                } => {
                    let condition_met = self.check_condition(condition, *player_health, creatures);
                    let empty: Vec<ScriptCommand> = Vec::new();
                    let cmds_to_run = if condition_met {
                        then_cmds
                    } else {
                        else_cmds.as_ref().unwrap_or(&empty)
                    };
                    return self.execute(cmds_to_run, player_health, creatures, dt);
                }
            }
        }

        ScriptResult::Complete
    }

    fn check_condition(
        &self,
        condition: &ScriptCondition,
        player_health: i32,
        creatures: &[Creature],
    ) -> bool {
        match condition {
            ScriptCondition::HealthEquals(value) => player_health == *value,
            ScriptCondition::HealthGreaterThan(value) => player_health > *value,
            ScriptCondition::HealthLessThan(value) => player_health < *value,
            ScriptCondition::CreatureAlive(index) => {
                creatures.get(*index).map_or(false, |c| c.base.alive)
            }
            ScriptCondition::CreatureCollected(index) => {
                creatures.get(*index).map_or(false, |c| !c.base.alive)
            }
            ScriptCondition::VariableEquals(name, value) => {
                self.variables.get(name).map_or(false, |v| v == value)
            }
            ScriptCondition::Always => true,
        }
    }
}

impl Default for ScriptExecutor {
    fn default() -> Self {
        Self::new()
    }
}

/// Result of script execution
#[derive(Debug, Clone)]
pub enum ScriptResult {
    Complete,
    Waiting,
    Message(String),
    Sound(String),
    ChangeLevel(String),
    Teleport(i32, i32),
}

/// Script manager - handles all scripts
pub struct ScriptManager {
    scripts: Vec<Script>,
    executor: ScriptExecutor,
    pending_messages: Vec<String>,
    pending_sounds: Vec<String>,
}

impl ScriptManager {
    pub fn new() -> Self {
        Self {
            scripts: Vec::new(),
            executor: ScriptExecutor::new(),
            pending_messages: Vec::new(),
            pending_sounds: Vec::new(),
        }
    }

    pub fn add_script(&mut self, script: Script) {
        self.scripts.push(script);
    }

    /// Check and trigger scripts based on event
    pub fn trigger_event(&mut self, event: &ScriptEvent) -> Vec<ScriptResult> {
        let mut results = Vec::new();

        for (i, script) in self.scripts.iter_mut().enumerate() {
            if script.should_trigger(event) {
                script.mark_triggered();
                self.executor.current_script = Some(i);
                // Execution happens in update()
                results.push(ScriptResult::Complete);
            }
        }

        results
    }

    /// Update pending scripts
    pub fn update(
        &mut self,
        player_health: &mut i32,
        creatures: &mut [Creature],
        dt: f32,
    ) -> Vec<ScriptResult> {
        let mut results = Vec::new();

        if let Some(script_idx) = self.executor.current_script {
            if let Some(script) = self.scripts.get(script_idx) {
                let result = self
                    .executor
                    .execute(&script.commands, player_health, creatures, dt);

                match &result {
                    ScriptResult::Complete => {
                        self.executor.current_script = None;
                    }
                    ScriptResult::Message(msg) => {
                        self.pending_messages.push(msg.clone());
                    }
                    ScriptResult::Sound(sound) => {
                        self.pending_sounds.push(sound.clone());
                    }
                    _ => {}
                }

                results.push(result);
            }
        }

        results
    }

    /// Get and clear pending messages
    pub fn take_messages(&mut self) -> Vec<String> {
        std::mem::take(&mut self.pending_messages)
    }

    /// Get and clear pending sounds
    pub fn take_sounds(&mut self) -> Vec<String> {
        std::mem::take(&mut self.pending_sounds)
    }

    /// Reset all scripts (for new game)
    pub fn reset(&mut self) {
        for script in &mut self.scripts {
            script.triggered = false;
        }
        self.executor = ScriptExecutor::new();
        self.pending_messages.clear();
        self.pending_sounds.clear();
    }
}

impl Default for ScriptManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_script_creation() {
        let script = Script::new(
            ScriptEvent::LevelStart,
            vec![ScriptCommand::ShowMessage("Hello".to_string())],
        );

        assert_eq!(script.commands.len(), 1);
        assert!(!script.one_shot);
        assert!(!script.triggered);
    }

    #[test]
    fn test_one_shot_script() {
        let mut script = Script::new(ScriptEvent::LevelStart, vec![]).one_shot();

        assert!(script.one_shot);
        assert!(!script.triggered);

        // First trigger should work
        assert!(script.should_trigger(&ScriptEvent::LevelStart));
        script.mark_triggered();

        // Second trigger should not work
        assert!(!script.should_trigger(&ScriptEvent::LevelStart));
    }

    #[test]
    fn test_executor_add_health() {
        let mut executor = ScriptExecutor::new();
        let mut health = 3;

        executor.execute(&[ScriptCommand::AddHealth(2)], &mut health, &mut [], 1.0);

        assert_eq!(health, 5);
    }

    #[test]
    fn test_executor_condition() {
        let executor = ScriptExecutor::new();

        assert!(executor.check_condition(&ScriptCondition::Always, 0, &[]));
        assert!(executor.check_condition(&ScriptCondition::HealthEquals(5), 5, &[]));
        assert!(!executor.check_condition(&ScriptCondition::HealthEquals(5), 3, &[]));
        assert!(executor.check_condition(&ScriptCondition::HealthGreaterThan(3), 5, &[]));
    }

    #[test]
    fn test_reveal_group() {
        // Use valid entity codes with group visibility:
        // ZNNA = PickupWalk + NotAnimated + None + Always
        // ZNNA = PickupWalk + NotAnimated + None + Group('A')
        let mut creatures = vec![
            Creature::from_toml("ZNNA", 1, 10, 10, 0, 0, 0, 0, 0).unwrap(),
            Creature::from_toml("ZNNB", 1, 20, 10, 0, 0, 0, 0, 0).unwrap(),
        ];

        // Manually set up for test - first should be in group A, second in group B
        creatures[0].group = Some('A');
        creatures[0].visible = false;
        creatures[1].group = Some('B');
        creatures[1].visible = false;

        let mut executor = ScriptExecutor::new();
        executor.execute(
            &[ScriptCommand::RevealGroup('A')],
            &mut 0,
            &mut creatures,
            1.0,
        );

        assert!(creatures[0].visible); // Group A revealed
        assert!(!creatures[1].visible); // Group B still hidden
    }

    #[test]
    fn test_script_manager() {
        let mut manager = ScriptManager::new();
        manager.add_script(Script::new(
            ScriptEvent::LevelStart,
            vec![ScriptCommand::AddHealth(1)],
        ));

        let results = manager.trigger_event(&ScriptEvent::LevelStart);
        assert!(!results.is_empty());
    }

    #[test]
    fn test_if_command() {
        let mut executor = ScriptExecutor::new();
        let mut health = 3;

        // Condition is true
        let cmd = ScriptCommand::If {
            condition: ScriptCondition::HealthEquals(3),
            then_cmds: vec![ScriptCommand::AddHealth(1)],
            else_cmds: None,
        };

        executor.execute(&[cmd], &mut health, &mut [], 1.0);
        assert_eq!(health, 4);
    }
}
