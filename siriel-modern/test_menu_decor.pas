program test_menu_decor;

{$mode objfpc}{$H+}

{ Test fancy menu decoration using GLIST tiles
  Loads GLIST spritesheet and draws a decorative menu frame
  Usage: ./test_menu_decor [screenshot_file.png]
}

uses
  SysUtils,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  blockx,
  geo;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;
  TILE_SIZE = 16;
  GLIST_TILE_COUNT = 8;  { GLIST has 8 tiles for borders }

type
  { RGBA tile buffer }
  TTileBuffer = array[0..TILE_SIZE * TILE_SIZE * 4 - 1] of byte;

var
  palette: jxfont_simple.tpalette;
  screenshot_file: string;
  frame_count: integer;
  start_time: longint;
  glist_tiles: array[0..GLIST_TILE_COUNT - 1] of TTileBuffer;  { Extracted GLIST tiles }
  glist_x, glist_y: word;         { GLIST position on screen }
  menu_x, menu_y: word;           { Menu position }
  menu_width_tiles, menu_height_tiles: word;  { Menu size in tiles }
  fill_color: byte;               { Fill color from GLIST position (0, 3) }
  tile_idx, src_idx, dst_idx: longint;
  src_x, src_y, dst_x, dst_y: word;
  r, g, b, a: byte;

{ Extract a single 16x16 tile from screen buffer }
procedure ExtractTile(src_x, src_y: word; var tile: TTileBuffer);
var
  local_x, local_y: word;
  src_idx, dst_idx: longint;
begin
  for local_y := 0 to TILE_SIZE - 1 do
  begin
    for local_x := 0 to TILE_SIZE - 1 do
    begin
      { Source pixel in screen buffer at (src_x + local_x, src_y + local_y) }
      src_idx := ((src_y + local_y) * SCREEN_WIDTH + (src_x + local_x)) * 4;

      { Destination in tile buffer }
      dst_idx := (local_y * TILE_SIZE + local_x) * 4;

      { Copy RGBA }
      tile[dst_idx] := PByte(screen_image^.data + src_idx)^;
      tile[dst_idx + 1] := PByte(screen_image^.data + src_idx + 1)^;
      tile[dst_idx + 2] := PByte(screen_image^.data + src_idx + 2)^;
      tile[dst_idx + 3] := PByte(screen_image^.data + src_idx + 3)^;
    end;
  end;
end;

{ Draw a single tile to screen buffer with transparency }
procedure DrawTile(var tile: TTileBuffer; dst_x, dst_y: word);
var
  local_x, local_y: word;
  src_idx, dst_idx: longint;
  r, g, b, a: byte;
begin
  for local_y := 0 to TILE_SIZE - 1 do
  begin
    for local_x := 0 to TILE_SIZE - 1 do
    begin
      { Read from tile buffer }
      src_idx := (local_y * TILE_SIZE + local_x) * 4;
      r := tile[src_idx];
      g := tile[src_idx + 1];
      b := tile[src_idx + 2];
      a := tile[src_idx + 3];

      { Check for magenta transparency (RGB: 255, 0, 255) }
      if (r > 250) and (g < 10) and (b > 250) then
        continue;  { Skip transparent pixels }

      { Write to screen }
      dst_idx := ((dst_y + local_y) * SCREEN_WIDTH + (dst_x + local_x)) * 4;
      PByte(screen_image^.data + dst_idx)^ := r;
      PByte(screen_image^.data + dst_idx + 1)^ := g;
      PByte(screen_image^.data + dst_idx + 2)^ := b;
      PByte(screen_image^.data + dst_idx + 3)^ := 255;
    end;
  end;
end;

{ Fill the interior of menu with solid color }
procedure FillInterior(x, y, width_tiles, height_tiles: word; fill_col: byte);
var
  start_x, start_y, end_x, end_y, fill_x, fill_y: word;
  dst_idx: longint;
begin
  { Interior starts after first tile and ends before last tile }
  start_x := x + TILE_SIZE;
  start_y := y + TILE_SIZE;
  end_x := x + (width_tiles - 1) * TILE_SIZE;
  end_y := y + (height_tiles - 1) * TILE_SIZE;

  { Fill the interior rectangle }
  for fill_y := start_y to end_y - 1 do
  begin
    for fill_x := start_x to end_x - 1 do
    begin
      dst_idx := (fill_y * SCREEN_WIDTH + fill_x) * 4;
      PByte(screen_image^.data + dst_idx)^ := fill_col;     { R }
      PByte(screen_image^.data + dst_idx + 1)^ := fill_col; { G }
      PByte(screen_image^.data + dst_idx + 2)^ := fill_col; { B }
      PByte(screen_image^.data + dst_idx + 3)^ := 255;       { A }
    end;
  end;
end;

{ Draw fancy menu frame using GLIST tiles }
procedure DrawMenuFrame(x, y, width_tiles, height_tiles: word; fill_col: byte);
var
  tile_num: word;
begin
  { Fill interior first }
  FillInterior(x, y, width_tiles, height_tiles, fill_col);

  { Top-left corner (tile 0) }
  DrawTile(glist_tiles[0], x, y);

  { Top edge (tile 1, repeated) }
  for tile_num := 1 to width_tiles - 2 do
    DrawTile(glist_tiles[1], x + tile_num * TILE_SIZE, y);

  { Top-right corner (tile 2) }
  DrawTile(glist_tiles[2], x + (width_tiles - 1) * TILE_SIZE, y);

  { Left edge (tile 3, repeated) }
  for tile_num := 1 to height_tiles - 2 do
    DrawTile(glist_tiles[3], x, y + tile_num * TILE_SIZE);

  { Right edge (tile 4, repeated) }
  for tile_num := 1 to height_tiles - 2 do
    DrawTile(glist_tiles[4], x + (width_tiles - 1) * TILE_SIZE, y + tile_num * TILE_SIZE);

  { Bottom-left corner (tile 5) }
  DrawTile(glist_tiles[5], x, y + (height_tiles - 1) * TILE_SIZE);

  { Bottom edge (tile 6, repeated) }
  for tile_num := 1 to width_tiles - 2 do
    DrawTile(glist_tiles[6], x + tile_num * TILE_SIZE, y + (height_tiles - 1) * TILE_SIZE);

  { Bottom-right corner (tile 7) }
  DrawTile(glist_tiles[7], x + (width_tiles - 1) * TILE_SIZE, y + (height_tiles - 1) * TILE_SIZE);
end;

begin
  writeln('=== Fancy Menu Decoration Test ===');
  writeln('Testing GLIST menu decoration system');
  writeln('');

  { Parse command line }
  screenshot_file := '';
  if ParamCount >= 1 then
    screenshot_file := ParamStr(1);

  if screenshot_file <> '' then
    writeln('Mode: Automated (screenshot to "', screenshot_file, '")')
  else
    writeln('Mode: Interactive (ESC to quit)');
  writeln('');

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  writeln('[1] Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);
  writeln('');

  { Load GLIST block from MAIN.DAT }
  glist_x := 50;
  glist_y := 50;
  writeln('[2] Loading GLIST from MAIN.DAT at (', glist_x, ', ', glist_y, ')...');
  if not draw_gif_block(screen_image, 'data/MAIN.DAT', 'GLIST', glist_x, glist_y, palette) then
  begin
    writeln('    ERROR: Failed to load GLIST block');
    if screenshot_file = '' then readln;
    Exit;
  end;

  writeln('    OK - GLIST loaded');
  writeln('    Position: (', glist_x, ', ', glist_y, ')');
  writeln('    Dimensions: ', gif_x, 'x', gif_y);
  writeln('');

  { Extract all 8 tiles from GLIST }
  writeln('[3] Extracting ', GLIST_TILE_COUNT, ' border tiles from GLIST...');
  for tile_idx := 0 to GLIST_TILE_COUNT - 1 do
  begin
    ExtractTile(glist_x + tile_idx * TILE_SIZE, glist_y, glist_tiles[tile_idx]);
    writeln('    Tile ', tile_idx, ' extracted (', TILE_SIZE * TILE_SIZE * 4, ' bytes)');
  end;
  writeln('    OK - All tiles extracted');
  writeln('');

  { Extract fill color from GLIST position (0, 3) }
  writeln('[3.5] Extracting fill color from GLIST position (0, 3)...');
  src_idx := ((glist_y + 3) * SCREEN_WIDTH + glist_x) * 4;
  fill_color := PByte(screen_image^.data + src_idx)^;
  writeln('    Fill color: ', fill_color, ' (grayscale value)');
  writeln('');

  { Clear screen for menu display }
  writeln('[4] Preparing menu display...');
  FillChar(screen_image^.data^, SCREEN_WIDTH * SCREEN_HEIGHT * 4, 0);

  { Draw a menu frame (e.g., 12 tiles wide, 8 tiles tall) }
  menu_x := 200;
  menu_y := 150;
  menu_width_tiles := 12;
  menu_height_tiles := 8;

  writeln('    Drawing menu frame at (', menu_x, ', ', menu_y, ')');
  writeln('    Size: ', menu_width_tiles, ' x ', menu_height_tiles, ' tiles (',
          menu_width_tiles * TILE_SIZE, 'x', menu_height_tiles * TILE_SIZE, ' pixels)');
  DrawMenuFrame(menu_x, menu_y, menu_width_tiles, menu_height_tiles, fill_color);

  writeln('    OK - Menu frame drawn');
  writeln('');

  { Open window }
  writeln('[5] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Fancy Menu Decoration - GLIST Tiles');
  SetTargetFPS(60);
  writeln('    OK - Window opened');
  writeln('');

  if screenshot_file <> '' then
    writeln('    Rendering for 1 second...')
  else
    writeln('    Press ESC to quit');
  writeln('');

  start_time := GetClock();
  frame_count := 0;

  { Main render loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);  { Dark blue background }
    RenderScreenToWindow();
    EndDrawing();

    inc(frame_count);

    { Check for timeout (1 second) }
    if (screenshot_file <> '') and (GetClock() - start_time >= 1000) then
    begin
      writeln('    Time elapsed (1 second)');
      break;
    end;
  end;

  { Take screenshot if requested }
  if screenshot_file <> '' then
  begin
    writeln('[6] Taking screenshot: ', screenshot_file);
    TakeScreenshot(PChar(screenshot_file));
    writeln('    OK - Screenshot saved');
  end;

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Frames rendered: ', frame_count);
  if screenshot_file <> '' then
    writeln('Screenshot: ', screenshot_file);
  writeln('');
  writeln('You should see:');
  writeln('  - Fancy menu frame with decorative borders');
  writeln('  - 8 different GLIST tiles (corners and edges)');
  writeln('  - Menu at (', menu_x, ', ', menu_y, ')');
  writeln('  - Size: ', menu_width_tiles * TILE_SIZE, 'x', menu_height_tiles * TILE_SIZE, ' pixels');
  writeln('');
end.
