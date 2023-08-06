import Phaser from 'phaser';
import { MainScene } from "./MainScene";

const config: Phaser.Types.Core.GameConfig = {
    type: Phaser.AUTO,
    width: 800,
    height: 600,
    parent: 'game-container',
    scene: [MainScene],
    physics: {
        default: 'arcade',
        arcade: {
            gravity: { y: 200 }
        }
    }
};


let game = new Phaser.Game(config);

function preload() {
    // This function will handle the loading of game assets.
    // For example:
    // this.load.image('avatar', 'path_to_avatar_image.png');
}

function create() {
    // This function will handle the initialization of game objects once assets are loaded.
    // For example:
    // let avatar = this.add.image(400, 300, 'avatar');
}

function update() {
    // This function will handle game updates (e.g., player movement, collision checks, etc.).
}
