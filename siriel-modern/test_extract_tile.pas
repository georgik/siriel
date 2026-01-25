program test_extract_tile;

{$mode objfpc}{$H+}

{ Extract first 16x16 tile from GZAL spritesheet and display it
  Uses RGBA pixel manipulation instead of palette-indexed functions
  Usage: ./test_extract_tile [screenshot_file.png]
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

var
  palette: jxfont_simple.tpalette;
  screenshot_file: string;
  frame_count: integer;
  start_time: longint;
  frame_buffer: array[0..TILE_SIZE * TILE_SIZE * 4 - 1] of byte;  { RGBA: 16x16x4 = 1024 bytes }
  src_x, src_y, dst_x, dst_y: word;
  src_idx, dst_idx: longint;
  r, g, b, a: byte;

begin
  writeln('=== Extract First Tile from GZAL ===');
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

  { Load GZAL block from MAIN.DAT }
  writeln('[2] Loading GZAL from MAIN.DAT at (50, 50)...');
  if not draw_gif_block(screen_image, 'data/MAIN.DAT', 'GZAL', 50, 50, palette) then
  begin
    writeln('    ERROR: Failed to load GZAL block');
    if screenshot_file = '' then readln;
    Exit;
  end;

  writeln('    OK - GZAL loaded');
  writeln('    Position: (50, 50)');
  writeln('    Dimensions: ', gif_x, 'x', gif_y);
  writeln('');

  { Extract first tile (frame 0 at position 50,50) using RGBA pixel copy }
  writeln('[3] Extracting first 16x16 tile from (50, 50)...');

  for src_y := 0 to TILE_SIZE - 1 do
  begin
    for src_x := 0 to TILE_SIZE - 1 do
    begin
      { Source pixel in GZAL at screen position (50 + src_x, 50 + src_y) }
      { Calculate screen index using SCREEN_WIDTH (640), not gif_x }
      src_idx := ((50 + src_y) * SCREEN_WIDTH + (50 + src_x)) * 4;

      { Destination in frame buffer }
      dst_idx := (src_y * TILE_SIZE + src_x) * 4;

      { Copy RGBA }
      r := PByte(screen_image^.data + src_idx)^;
      g := PByte(screen_image^.data + src_idx + 1)^;
      b := PByte(screen_image^.data + src_idx + 2)^;
      a := PByte(screen_image^.data + src_idx + 3)^;

      frame_buffer[dst_idx] := r;
      frame_buffer[dst_idx + 1] := g;
      frame_buffer[dst_idx + 2] := b;
      frame_buffer[dst_idx + 3] := a;
    end;
  end;

  writeln('    OK - Tile extracted to RGBA buffer (', TILE_SIZE * TILE_SIZE * 4, ' bytes)');
  writeln('    Fixed: Using SCREEN_WIDTH instead of gif_x for index calculation');
  writeln('');

  { Clear screen and draw extracted tile at visible position }
  writeln('[4] Drawing extracted tile at (300, 50)...');
  FillChar(screen_image^.data^, SCREEN_WIDTH * SCREEN_HEIGHT * 4, 0);

  { Draw the extracted tile with transparency detection }
  for src_y := 0 to TILE_SIZE - 1 do
  begin
    for src_x := 0 to TILE_SIZE - 1 do
    begin
      dst_x := 300 + src_x;
      dst_y := 50 + src_y;

      { Read from frame buffer }
      src_idx := (src_y * TILE_SIZE + src_x) * 4;
      r := frame_buffer[src_idx];
      g := frame_buffer[src_idx + 1];
      b := frame_buffer[src_idx + 2];
      a := frame_buffer[src_idx + 3];

      { Check for magenta transparency (RGB: 255, 0, 255) }
      if (r > 250) and (g < 10) and (b > 250) then
        continue;  { Skip transparent pixels }

      { Write to screen }
      dst_idx := (dst_y * SCREEN_WIDTH + dst_x) * 4;
      PByte(screen_image^.data + dst_idx)^ := r;
      PByte(screen_image^.data + dst_idx + 1)^ := g;
      PByte(screen_image^.data + dst_idx + 2)^ := b;
      PByte(screen_image^.data + dst_idx + 3)^ := 255;
    end;
  end;

  writeln('    OK - Tile drawn at (300, 50)');
  writeln('    Transparency detection: Magenta (RGB: 255, 0, 255)');
  writeln('');

  { Open window }
  writeln('[5] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Extract Tile Test - Frame 0 from GZAL');
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
  writeln('  - Right: First extracted tile (16x16) at (300, 50)');
  writeln('');
end.
