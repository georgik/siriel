program test_animation;

{$mode objfpc}{$H+}

{ Animate first 4 frames from GZAL spritesheet
  Uses RGBA pixel manipulation for frame extraction and animation
  Usage: ./test_animation [screenshot_file.png]
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
  FRAME_COUNT = 4;          { Number of frames to animate }
  ANIMATION_FPS = 10;       { Animation speed (frames per second) }
  FRAME_DELAY = 1000 div ANIMATION_FPS;  { Milliseconds per frame }

type
  { RGBA frame buffer }
  TFrameBuffer = array[0..TILE_SIZE * TILE_SIZE * 4 - 1] of byte;

var
  palette: jxfont_simple.tpalette;
  screenshot_file: string;
  total_frames: integer;
  start_time: longint;
  frames: array[0..FRAME_COUNT - 1] of TFrameBuffer;  { Extracted frames }
  gzal_x, gzal_y: word;         { GZAL position on screen }
  current_frame: integer;       { Current animation frame }
  last_frame_time: longint;     { Time when last frame was displayed }
  src_x, src_y, dst_x, dst_y: word;
  frame_idx, src_idx, dst_idx: longint;
  r, g, b, a: byte;

begin
  writeln('=== GZAL Animation Test ===');
  writeln('Animating first ', FRAME_COUNT, ' frames from GZAL spritesheet');
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
  gzal_x := 50;
  gzal_y := 50;
  writeln('[2] Loading GZAL from MAIN.DAT at (', gzal_x, ', ', gzal_y, ')...');
  if not draw_gif_block(screen_image, 'data/MAIN.DAT', 'GZAL', gzal_x, gzal_y, palette) then
  begin
    writeln('    ERROR: Failed to load GZAL block');
    if screenshot_file = '' then readln;
    Exit;
  end;

  writeln('    OK - GZAL loaded');
  writeln('    Position: (', gzal_x, ', ', gzal_y, ')');
  writeln('    Dimensions: ', gif_x, 'x', gif_y);
  writeln('');

  { Extract first 4 frames (tiles) from first row of GZAL }
  writeln('[3] Extracting first ', FRAME_COUNT, ' frames...');

  for frame_idx := 0 to FRAME_COUNT - 1 do
  begin
    { Each frame is 16x16, positioned horizontally in the spritesheet }
    { Frame 0: (gzal_x + 0, gzal_y) to (gzal_x + 15, gzal_y + 15) }
    { Frame 1: (gzal_x + 16, gzal_y) to (gzal_x + 31, gzal_y + 15) }
    { etc. }

    for src_y := 0 to TILE_SIZE - 1 do
    begin
      for src_x := 0 to TILE_SIZE - 1 do
      begin
        { Source pixel in GZAL at screen position (gzal_x + frame_idx*16 + src_x, gzal_y + src_y) }
        src_idx := ((gzal_y + src_y) * SCREEN_WIDTH + (gzal_x + frame_idx * TILE_SIZE + src_x)) * 4;

        { Destination in frame buffer }
        dst_idx := (src_y * TILE_SIZE + src_x) * 4;

        { Copy RGBA }
        r := PByte(screen_image^.data + src_idx)^;
        g := PByte(screen_image^.data + src_idx + 1)^;
        b := PByte(screen_image^.data + src_idx + 2)^;
        a := PByte(screen_image^.data + src_idx + 3)^;

        frames[frame_idx][dst_idx] := r;
        frames[frame_idx][dst_idx + 1] := g;
        frames[frame_idx][dst_idx + 2] := b;
        frames[frame_idx][dst_idx + 3] := a;
      end;
    end;

    writeln('    Frame ', frame_idx, ' extracted (', TILE_SIZE * TILE_SIZE * 4, ' bytes)');
  end;

  writeln('    OK - All frames extracted');
  writeln('');

  { Clear screen for clean animation }
  writeln('[4] Preparing animation display...');
  FillChar(screen_image^.data^, SCREEN_WIDTH * SCREEN_HEIGHT * 4, 0);

  { Draw first frame immediately so it's visible from the start }
  dst_x := 300;
  dst_y := 200;
  for src_y := 0 to TILE_SIZE - 1 do
  begin
    for src_x := 0 to TILE_SIZE - 1 do
    begin
      { Read from first frame buffer }
      src_idx := (src_y * TILE_SIZE + src_x) * 4;
      r := frames[0][src_idx];
      g := frames[0][src_idx + 1];
      b := frames[0][src_idx + 2];
      a := frames[0][src_idx + 3];

      { Check for magenta transparency (RGB: 255, 0, 255) }
      if (r > 250) and (g < 10) and (b > 250) then
        continue;  { Skip transparent pixels }

      { Write to screen }
      dst_idx := ((dst_y + src_y) * SCREEN_WIDTH + (dst_x + src_x)) * 4;
      PByte(screen_image^.data + dst_idx)^ := r;
      PByte(screen_image^.data + dst_idx + 1)^ := g;
      PByte(screen_image^.data + dst_idx + 2)^ := b;
      PByte(screen_image^.data + dst_idx + 3)^ := 255;
    end;
  end;

  current_frame := 1;  { Next frame to display will be frame 1 }

  writeln('    OK - Screen cleared and first frame drawn');
  writeln('');

  { Open window }
  writeln('[5] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'GZAL Animation Test - 4 Frames');
  SetTargetFPS(60);
  writeln('    OK - Window opened');
  writeln('');

  if screenshot_file <> '' then
    writeln('    Rendering for 3 seconds...')
  else
    writeln('    Press ESC to quit');
  writeln('');

  start_time := GetClock();
  last_frame_time := start_time;
  current_frame := 0;
  total_frames := 0;

  { Main render loop }
  while WindowShouldClose() = 0 do
  begin
    { Check if it's time for next frame }
    if GetClock() - last_frame_time >= FRAME_DELAY then
    begin
      last_frame_time := GetClock();

      { Clear previous frame area }
      dst_x := 300;
      dst_y := 200;
      for src_y := 0 to TILE_SIZE - 1 do
      begin
        for src_x := 0 to TILE_SIZE - 1 do
        begin
          dst_idx := ((dst_y + src_y) * SCREEN_WIDTH + (dst_x + src_x)) * 4;
          PByte(screen_image^.data + dst_idx)^ := 0;
          PByte(screen_image^.data + dst_idx + 1)^ := 0;
          PByte(screen_image^.data + dst_idx + 2)^ := 0;
          PByte(screen_image^.data + dst_idx + 3)^ := 0;
        end;
      end;

      { Draw current frame with transparency }
      for src_y := 0 to TILE_SIZE - 1 do
      begin
        for src_x := 0 to TILE_SIZE - 1 do
        begin
          { Read from current frame buffer }
          src_idx := (src_y * TILE_SIZE + src_x) * 4;
          r := frames[current_frame][src_idx];
          g := frames[current_frame][src_idx + 1];
          b := frames[current_frame][src_idx + 2];
          a := frames[current_frame][src_idx + 3];

          { Check for magenta transparency (RGB: 255, 0, 255) }
          if (r > 250) and (g < 10) and (b > 250) then
            continue;  { Skip transparent pixels }

          { Write to screen }
          dst_idx := ((dst_y + src_y) * SCREEN_WIDTH + (dst_x + src_x)) * 4;
          PByte(screen_image^.data + dst_idx)^ := r;
          PByte(screen_image^.data + dst_idx + 1)^ := g;
          PByte(screen_image^.data + dst_idx + 2)^ := b;
          PByte(screen_image^.data + dst_idx + 3)^ := 255;
        end;
      end;

      { Advance to next frame }
      current_frame := (current_frame + 1) mod FRAME_COUNT;
      inc(total_frames);
    end;

    BeginDrawing();
    ClearBackground(20, 20, 30, 255);  { Dark blue background }
    RenderScreenToWindow();
    EndDrawing();

    { Check for timeout (3 seconds for automated) }
    if (screenshot_file <> '') and (GetClock() - start_time >= 3000) then
    begin
      writeln('    Time elapsed (3 seconds)');
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
  writeln('Frames rendered: ', total_frames);
  writeln('Animation speed: ', ANIMATION_FPS, ' FPS');
  if screenshot_file <> '' then
    writeln('Screenshot: ', screenshot_file);
  writeln('');
  writeln('You should see:');
  writeln('  - Animated avatar (', TILE_SIZE, 'x', TILE_SIZE, ') at (300, 200)');
  writeln('  - Cycling through ', FRAME_COUNT, ' frames at ', ANIMATION_FPS, ' FPS');
  writeln('');
end.
