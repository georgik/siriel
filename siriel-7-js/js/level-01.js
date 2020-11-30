
map = [
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


var globalTiles;
function renderMap() {
    var canvas=document.getElementById("background-canvas");
    var context=canvas.getContext('2d');
    var line, column;
    var maxTileId = globalTiles.length;
    for(line = 0; line < map.length; line++) {
        var mapLine = map[line];
        for (column = 0; column < mapLine.length; column++) {
            var tileId = mapLine[column].charCodeAt(0) - 45;
            if (tileId >= globalTiles.length) {
                tileId = 0;
            }
            context.putImageData(globalTiles[tileId], 16*column, 16*line);
        }
    }
}

function processOnLoad(event) {
    var canvas=document.getElementById("background-canvas");
    var context=canvas.getContext('2d');
    var image=new Image();
/*    image.onload=function(){
        context.drawImage(image,0,0,canvas.width,canvas.height);
    };
*/

     var tempCanvas = document.getElementById("temp-canvas");
    var tempContext = tempCanvas.getContext("2d");

 Tiles = new TileSet();
    // parse a spritesheet into tiles
    //Tiles.addSpriteSheet("resources/tiles/tilea2.png","anyName");
    Tiles.addSpriteSheet("img/texture-basic.png","basic");

    // Tiles parser from - https://stackoverflow.com/questions/15444987/using-html5-canvas-to-parse-an-image-into-a-tileset
    function TileSet() {
        this.Tiles = [];
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
                for(var i=0; i<tilesY; i++) {

                    for(var j=0; j<tilesX; j++) {

                        // Store the image data of each tile in the array.
                        me.Tiles.push(tempContext.getImageData(j*me.tileWidth, i*me.tileHeight, me.tileWidth, me.tileHeight));
                    }
                }

                // this is just a test
                // display the last tile in a canvas
                //context.putImageData(me.Tiles[me.Tiles.length-1],0,0);
                globalTiles = me.Tiles;
                renderMap();


            }
            // load the spritesheet .png into tileSheet Image()
            tileSheet.src = spriteSheetLoc;
        }
    }

    //    image.src="img/texture-basic.png";
}

window.addEventListener("load", processOnLoad);

