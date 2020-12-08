
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
  "---55555--------------------------------",
  "----------------------------------------",
  "----------------------------------------",
  "----------------------------------------",
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

function gameObjectFromString(definition) {
    var data = definition.split("=");
    var items = data[1].split(',');
    var gameObject = {
        tileId: items[0],
        x: items[1]*8,
        y: items[2]*8 + 8,
        room: items[3],
        take: items[4],
        score: items[5]
    }
    gameObjects.push(gameObject);
}

var globalTiles;
function renderMap() {
    var canvas=document.getElementById("background-canvas");
    var context=canvas.getContext('2d');
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
            context.putImageData(textures[tileId], 16*column, 16*line);
        }
    }
}

function renderGameObjects() {
    //var canvas=document.getElementById("objects-canvas");
    var context=backgroundCanvas.getContext('2d');
    var objectIndex;
    var objectsTexture = globalTiles.Tiles["objects"];
    var gameObject;
    for(objectIndex = 0; objectIndex < gameObjects.length; objectIndex++) {
        gameObject = gameObjects[objectIndex];
        context.putImageData(objectsTexture[gameObject.tileId], gameObject.x, gameObject.y);
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
    var context=backgroundCanvas.getContext('2d');
    var data = context.getImageData(x, y, 1, 1).data;
    var rgb = [ data[0], data[1], data[2] ];
    return ((rgb[0] + rgb[1] + rgb[2]) > 0 );
}

function keyDownHandler(event) {
    event = event || window.event;
    var oldX = avatar.x;
    var oldY = avatar.y;
    if (event.keyCode == '38') {
        // up arrow
        avatar.y -= avatarStep;
    }
    else if (event.keyCode == '40') {
        // down arrow
        avatar.y += avatarStep;
    }
    else if (event.keyCode == '37') {
        // left arrow
        avatar.x -= avatarStep;
    }
    else if (event.keyCode == '39') {
       // right arrow
       avatar.x += avatarStep;
    }

    if (avatar.x < 0) {
        avatar.x = 0;
    } else if (avatar.x > 640) {
        avatar.x = 640;
    }

    if (avatar.y < 0) {
        avatar.y = 0;
    } else if (avatar.y > 480) {
        avatar.y = 480;
    }

    var checkPoint = 13;
    if ( (checkCollisionWithBackground(avatar.x, avatar.y)) ||
        (checkCollisionWithBackground(avatar.x + checkPoint, avatar.y)) ||
        (checkCollisionWithBackground(avatar.x, avatar.y + checkPoint)) ||
        (checkCollisionWithBackground(avatar.x + checkPoint, avatar.y + checkPoint))
    ) {
        avatar.x = oldX;
        avatar.y = oldY;
    }

    avatar.style.left = avatar.x + 'px';
    avatar.style.top = avatar.y + 'px';
}

function registerControls() {
    avatar = document.getElementById("avatar");
    avatar.x = 88;
    avatar.y = 88;
    document.onkeydown = keyDownHandler;
}

function processOnLoad(event) {
    backgroundCanvas=document.getElementById("background-canvas");
    var context=backgroundCanvas.getContext('2d');
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

