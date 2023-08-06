import Phaser from 'phaser';

type ObjectProperty = {
    collectible: boolean;
    hazardous: boolean;
    gravity: boolean;
};

enum GameObjectTypes {
    TELEPORT, PEAR, CHERRY, STOP_WHEEL, // ... add all other types here
}

const GameObjectProperties: { [key in GameObjectTypes]: ObjectProperty } = {
    [GameObjectTypes.TELEPORT]: { collectible: false, hazardous: false, gravity: false },
    [GameObjectTypes.PEAR]: { collectible: true, hazardous: false, gravity: true },
    [GameObjectTypes.CHERRY]: { collectible: true, hazardous: false, gravity: true },
    [GameObjectTypes.STOP_WHEEL]: { collectible: true, hazardous: true, gravity: false },
    // ... Define properties for all other types here
};


export class MainScene extends Phaser.Scene {
    private avatar!: Phaser.GameObjects.Sprite;
    private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
    private avatarSpeed: number = 100;


    constructor() {
        super({
            key: 'MainScene'
        });
    }

    preload(): void {
        this.load.spritesheet('avatar', 'assets/siriel-avatar.png', { frameWidth: 16, frameHeight: 16 });
        this.load.spritesheet('objects', 'assets/objects-basic.png', {
            frameWidth: 16,
            frameHeight: 16
        });
    }

    create(): void {

        // Moving down animation
        this.anims.create({
            key: 'down',
            frames: this.anims.generateFrameNumbers('avatar', { start: 0, end: 3 }),
            frameRate: 10,
            repeat: -1
        });

        // Moving left animation
        this.anims.create({
            key: 'left',
            frames: this.anims.generateFrameNumbers('avatar', { start: 4, end: 7 }),
            frameRate: 10,
            repeat: -1
        });

        // Moving right animation
        this.anims.create({
            key: 'right',
            frames: this.anims.generateFrameNumbers('avatar', { start: 8, end: 11 }),
            frameRate: 10,
            repeat: -1
        });

        // Moving up animation
        this.anims.create({
            key: 'up',
            frames: this.anims.generateFrameNumbers('avatar', { start: 36, end: 39 }), // Adjusted to third row
            frameRate: 10,
            repeat: -1
        });

        // Draw the avatar in the middle of the screen
        this.avatar = this.add.sprite(this.cameras.main.width / 2, this.cameras.main.height / 2, 'avatar');


        const totalObjects = 10;  // Number of objects to display

        for (let i = 0; i < totalObjects; i++) {
            const randomType = Phaser.Math.Between(GameObjectTypes.TELEPORT, GameObjectTypes.STOP_WHEEL);
            const objSprite = this.physics.add.sprite(Phaser.Math.Between(0, this.cameras.main.width), 
                                                      Phaser.Math.Between(0, this.cameras.main.height), 
                                                      'objects',
                                                      randomType);

            objSprite.setData('type', randomType);

            // Set gravity if defined for the game object type
            if (GameObjectProperties[randomType as GameObjectTypes].gravity) {
                (objSprite.body as Phaser.Physics.Arcade.Body).setGravityY(300);
            } else {
                const body = objSprite.body as Phaser.Physics.Arcade.Body;
                (objSprite.body as Phaser.Physics.Arcade.Body).setGravityY(0);
                (objSprite.body as Phaser.Physics.Arcade.Body).setImmovable(true);
                (objSprite.body as Phaser.Physics.Arcade.Body).setVelocity(0);
            }
        }

        // Enable physics for avatar movement
        this.physics.world.enable(this.avatar);

        // Assign cursors for keyboard inputs
        this.cursors = this.input!.keyboard!.createCursorKeys();
    }

    update(): void {
        // Reset avatar's velocity to 0 on each frame
        (this.avatar.body as Phaser.Physics.Arcade.Body).setVelocity(0, 0);

        // Move the avatar according to keyboard inputs
        if (this.cursors.left?.isDown) {
            (this.avatar.body as Phaser.Physics.Arcade.Body).setVelocityX(-this.avatarSpeed);
            this.avatar.play('left', true);
        } else if (this.cursors.right?.isDown) {
            (this.avatar.body as Phaser.Physics.Arcade.Body).setVelocityX(this.avatarSpeed);
            this.avatar.play('right', true);
        } else if (this.cursors.up?.isDown) {
            (this.avatar.body as Phaser.Physics.Arcade.Body).setVelocityY(-this.avatarSpeed);
            this.avatar.play('up', true);
        } else if (this.cursors.down?.isDown) {
            (this.avatar.body as Phaser.Physics.Arcade.Body).setVelocityY(this.avatarSpeed);
            this.avatar.play('down', true);
        } else {
            this.avatar.anims.stop(); // Stops animation if no keys are pressed
        }
    }
}
