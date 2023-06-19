
var map = [
  "----------------------------------------",
  "----------------------------------------",
  "----------------------------------------",
  "----------------------------------------",
  "----------------------------------------",
  "---5---5--------------------------------",
  "----------------------------------------",
  "-----5----------------------------------",
  "----------------------------------------",
  "---5---5--------------------------------",
  "---55555--EEEEH-------------------------",
  "--------------GEEH----------------------",
  "-----------------GEEH-------------------",
  "--------------------GH------------------",
  "----------------------------------------",
  "EEEEH--------IEKEEH---------------------",
  "----GEEEEEEEEF----GEEEEEEEEEEEEH--------",
  "-------------------------------GH-------",
  "------------------------------------IEEE",
  "---------------IJEEEEEEEEEEEEEEEEEEEF---",
  "EEEEEEEEEEEEEEEF------------------------",
  "----------------------------------------",
  "----------------------------------------",
  "----------------------------------------",
  "----------------------------------------",
  "----------------------------------------",
  "----------------------------------------",
];
var gameObjectString = `[ZNNA]=1,8,17,1,3,10
[ZNNA]=1,10,17,1,3,10
[ZNNA]=1,12,17,1,3,10
[ZANA]=6,17,29,1,3,50
[ZNNA]=2,38,29,1,3,5
[ZNNA]=2,40,29,1,3,5
[ZNNA]=2,42,29,1,3,5
[ZNNA]=2,67,29,1,3,5
[ZNNA]=2,0,37,1,3,5
[ZNNA]=2,2,37,1,3,5
[ZNNA]=2,4,37,1,3,5
[ZNNA]=2,6,37,1,3,5
[ZNNA]=2,8,37,1,3,5
[ZNNA]=2,0,27,1,3,5
[ZNNA]=2,6,15,1,3,5`;
/*
[YNN~]=10,76,34,9,1
*/


var gameObjects = [];
var avatar;
var avatarStep = 4;
var backgroundCanvas;
var backgroundContext = null;
var objectCanvas;
var objectContext = null;
var keyboard = {};
var score = 0;
var displayedScore = 0;

// Type of game objects
const COLLECTIBLE = '3';

// Delay between engine heartbeat
const ENGINE_HEARTBEAT_INTERVAL = 50;

function gameObjectFromString(definition) {
    var data = definition.split("=");
    var items = data[1].split(',');
    var gameObject = {
        tileId: items[0],
        x: items[1]*8,
        y: items[2]*8 + 8,
        room: items[3],
        take: items[4],
        score: parseInt(items[5])
    }
    gameObjects.push(gameObject);
}

// Redraw scene. Clear the canvas and redraw all game objects.
function redraw() {
    objectContext.clearRect(0, 0, objectCanvas.width, objectCanvas.height);
    renderMap();
    renderGameObjects();
}

// Remove game object from the list of gameobjects based on identity
function removeGameObject(gameObject) {
    var index = gameObjects.indexOf(gameObject);
    if (index > -1) {
        gameObjects.splice(index, 1);
        redraw();
    }
}

var globalTiles;
function renderMap() {
    var line, column;
    var maxTileId = globalTiles.length;
    var textures = globalTiles.Tiles["textures"];
    for(line = 0; line < map.length; line++) {
        var mapLine = map[line];
        for (column = 0; column < mapLine.length; column++) {
            var tileId = mapLine[column].charCodeAt(0) - 45;
            if (tileId >= globalTiles.length) {
                tileId = 0;
            }
            backgroundContext.putImageData(textures[tileId], 16*column, 16*line);
        }
    }
}

function renderGameObjects() {
    var objectIndex;
    var objectsTexture = globalTiles.Tiles["objects"];
    var gameObject;
    for(objectIndex = 0; objectIndex < gameObjects.length; objectIndex++) {
        gameObject = gameObjects[objectIndex];
        objectContext.putImageData(objectsTexture[gameObject.tileId], gameObject.x, gameObject.y);
    }
}

function tilesReady(name) {
    if (name == "textures") {
        renderMap();
    } else if (name == "objects") {
        var lineIndex;
        var lines = gameObjectString.split('\n');
        for(lineIndex = 0; lineIndex <lines.length; lineIndex++) {
            gameObjectFromString(lines[lineIndex]);
        }
        renderGameObjects();
    }
}

function checkCollisionWithBackground(x, y) {
    if (backgroundContext == null) {
        return;
    }
    var data = backgroundContext.getImageData(x, y, 1, 1).data;
    var rgb = [ data[0], data[1], data[2] ];
    return ((rgb[0] + rgb[1] + rgb[2]) > 0 );
}

function getCollisionWithGameObjects(x, y) {
  var collisionList = [];
  for(var index = 0; index < gameObjects.length; index++) {
    var gameObject = gameObjects[index];
    if ((gameObject.x == x) && (gameObject.y == y)) {
      collisionList.push(gameObject);
    }
  }
  return collisionList;
}

function applyMove(item, deltaX, deltaY) {
    item.lastPositionChanged = false;
    if ((deltaY == 0) && (deltaX == 0)) {
        return false;
    }
    var newX = item.x + deltaX;
    var newY = item.y + deltaY;
    var checkPoint = 13;

    var collisionPointTopLeft = checkCollisionWithBackground(newX, newY + checkPoint);
    var collisionPointTopRight = checkCollisionWithBackground(newX + checkPoint, newY);
    var collisionPointBottomLeft = checkCollisionWithBackground(newX, newY + checkPoint);
    var collisionPointBottomRight = checkCollisionWithBackground(newX + checkPoint, newY + checkPoint);

    /* Slope climb detection - left */
    if ((deltaX != 0) && (deltaY == 0) &&
        (collisionPointBottomLeft || collisionPointBottomRight) &&
        (!collisionPointTopLeft || !collisionPointTopRight)) {
        newY -= avatarStep;
    }

    /* Slope climb detection - right */
    /*if ((deltaX > 0) && (deltaY == 0) &&
        (checkCollisionWithBackground(newX + checkPoint, newY + checkPoint))) {
        newY -= avatarStep;
    }*/

    if ((checkCollisionWithBackground(newX, newY)) ||
        (checkCollisionWithBackground(newX + checkPoint, newY)) ||
        (checkCollisionWithBackground(newX, newY + checkPoint)) ||
        (checkCollisionWithBackground(newX + checkPoint, newY + checkPoint))
    ) {
        return false;
    }

    if ((newX < 0) || (newX > 640) || (newY > 480) || (newY < 0)) {
        return false;
    }

    item.x = newX;
    item.y = newY;
    item.lastPositionChanged = true;
    item.style.left = item.x + 'px';
    item.style.top = item.y + 'px';
    return true;
}

function keyDownHandler(event) {
    event = event || window.event;
    if (event.keyCode == '38') {
        // up arrow
        keyboard.up = true;
    }
    if (event.keyCode == '40') {
        // down arrow
        keyboard.down = true;
    }
    else if (event.keyCode == '37') {
        // left arrow
        keyboard.left = true;
    }
    else if (event.keyCode == '39') {
       // right arrow
       keyboard.right = true;
    }
}

function keyUpHandler(event) {
  if (event.keyCode == '38') {
    keyboard.up = false;
  }
  if (event.keyCode == '40') {
    keyboard.down = false;
  }
  if (event.keyCode == '37') {
    // left arrow
    keyboard.left = false;
  } else if (event.keyCode == '39') {
    // right arrow
    keyboard.right = false;
  }
}

function classListAdd(item, className) {
  if (!item.classList.contains(className)) {
    item.classList.add(className);
  }
}

function classListRemove(item, className) {
  if (item.classList.contains(className)) {
    item.classList.remove(className);
  }
}

// Process collision with game object.
// In case of collectible objects, remove the object and increase the score.
function processCollisionWithGameObject(gameObject) {
  if (gameObject.take == COLLECTIBLE) {
    score += gameObject.score;
    removeGameObject(gameObject);
  }
}

// Update displayed score if value is lower than score.
// Use 10 steps to update the score.
// If difference is less than ten, update the displayed score just once.
function updateDisplayedScore() {
  var scoreDifference = score - displayedScore;

  var scoreStep = Math.floor(scoreDifference / 10);
  if (scoreStep < 1) {
    scoreStep = 1;
  }

  displayedScore += scoreStep;

  if (displayedScore > score) {
    displayedScore = score;
  }

  scoreElement = document.getElementById('hud-score-value');
  scoreElement.innerHTML = displayedScore;
}

function heartBeat() {
  if (keyboard.up) {
    if ((avatar.yEnergy == 0) && (!avatar.lastPositionChanged)) {
      avatar.yEnergy = 10;

      if (keyboard.right) {
        classListAdd(avatar, 'jump-right');
      } else if (keyboard.left) {
        classListAdd(avatar, 'jump-left');
      } else {
        classListAdd(avatar, 'jump-up');
      }
    }
  }

  if (keyboard.left) {
    applyMove(avatar, -avatarStep, 0);
    classListAdd(avatar, 'left');
  } else {
    classListRemove(avatar, 'left');
  }


  if (keyboard.right) {
    applyMove(avatar, avatarStep, 0);
    classListAdd(avatar, 'right');
  } else {
    classListRemove(avatar, 'right');
  }

  // Jump
  if (avatar.yEnergy > 0) {
    avatar.yEnergy--;

    if (!applyMove(avatar, 0, -4)) {
      // Collision with ceiling object
      avatar.yEnergy = 0;
    }
  } else {
    classListRemove(avatar, 'jump-up');
    classListRemove(avatar, 'jump-left');
    classListRemove(avatar, 'jump-right');
    // gravity
    applyMove(avatar, 0, 4);
  }

  var collisionList = getCollisionWithGameObjects(avatar.x, avatar.y);
  if (collisionList.length > 0) {
    for (var index = 0; index < collisionList.length; index++) {
      console.log("Collision:" + collisionList[index].score);
      processCollisionWithGameObject(collisionList[index]);
    }
  }

  if (score != displayedScore) {
    updateDisplayedScore();
  }
}

function registerControls() {
    avatar = document.getElementById("avatar");
    avatar.x = 88;
    avatar.y = 88;
    avatar.yEnergy = 0;
    avatar.lastPositionChanged = false;
    document.onkeydown = keyDownHandler;
    document.onkeyup = keyUpHandler;
    keyboard.left = false;
    keyboard.right = false;
    keyboard.up = false;
    setInterval(heartBeat, ENGINE_HEARTBEAT_INTERVAL);
}

function processOnLoad(event) {
    backgroundCanvas=document.getElementById("background-canvas");
    backgroundContext=backgroundCanvas.getContext('2d');

    objectCanvas = document.getElementById("objects-canvas");
    objectContext = objectCanvas.getContext('2d');

    var image=new Image();

    var tempCanvas = document.getElementById("temp-canvas");
    var tempContext = tempCanvas.getContext("2d");

    globalTiles = new TileSet();
    // parse a spritesheet into tiles
    //Tiles.addSpriteSheet("resources/tiles/tilea2.png","anyName");
    globalTiles.addSpriteSheet("img/texture-basic.png", "textures");
    globalTiles.addSpriteSheet("img/animations-basic.png", "animations");
    globalTiles.addSpriteSheet("img/objects-basic.png", "objects");

    // Tiles parser from - https://stackoverflow.com/questions/15444987/using-html5-canvas-to-parse-an-image-into-a-tileset
    function TileSet() {
        this.Tiles = {};
        this.tileHeight = 16;
        this.tileWidth = 16;
        this.tileCount = 4;

        this.addSpriteSheet = function (spriteSheetLoc, name) {

        var tileSheet = new Image();
            var me=this;  // me==this==TileSet

            tileSheet.onload = function() {

                // calculate the rows/cols in the spritesheet
                // tilesX=rows, tilesY=cols
                var tilesX = tileSheet.width / me.tileWidth;
                var tilesY = tileSheet.height / me.tileHeight;

                // set the spritesheet canvas to spritesheet.png size
                // then draw spritesheet.png into the canvas
                tempCanvas.width = tileSheet.width;
                tempCanvas.height = tileSheet.height;
                tempContext.drawImage(tileSheet, 0, 0);
                me.Tiles[name] = [];
                for(var i=0; i<tilesY; i++) {

                    for(var j=0; j<tilesX; j++) {

                        // Store the image data of each tile in the array.
                        me.Tiles[name].push(tempContext.getImageData(j*me.tileWidth, i*me.tileHeight, me.tileWidth, me.tileHeight));
                    }
                }

                tilesReady(name);


            }
            // load the spritesheet .png into tileSheet Image()
            tileSheet.src = spriteSheetLoc;
        }
    };

    registerControls();
}

window.addEventListener("load", processOnLoad);

