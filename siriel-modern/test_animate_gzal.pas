program test_animate_gzal;

{$mode objfpc}{$H+}

{ Animate through all GZAL frames
  Usage: ./test_animate_gzal [screenshot_file.png]
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
  FRAME_DELAY_MS = 100;  { 10 FPS }
  TOTAL_FRAMES = 56;

var
  palette: jxfont_simple.tpalette;
  screenshot_file: string;
  frame_count: integer;
  start_time: longint;
  gzal_start_x, gzal_start_y: word;
  current_frame: word;
  last_frame_time: longint;
  src_x, src_y, dst_x, dst_y: word;
  src_idx, dst_idx: longint;
  r, g, b, a: byte;

begin
  writeln('=== Animate GZAL Frames ===');
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
  gzal_start_x := 50;
  gzal_start_y := 50;

  writeln('[2] Loading GZAL from MAIN.DAT at (', gzal_start_x, ', ', gzal_start_y, ')...');
  if not draw_gif_block(screen_image, 'data/MAIN.DAT', 'GZAL', gzal_start_x, gzal_start_y, palette) then
  begin
    writeln('    ERROR: Failed to load GZAL block');
    if screenshot_file = '' then readln;
    Exit;
  end;

  writeln('    OK - GZAL loaded');
  writeln('    Dimensions: ', gif_x, 'x', gif_y);
  writeln('    Total frames: ', TOTAL_FRAMES);
  writeln('    Animation speed: ', 1000 div FRAME_DELAY_MS, ' FPS');
  writeln('');

  { Open window }
  writeln('[3] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'GZAL Animation Test - All 56 Frames');
  SetTargetFPS(60);
  writeln('    OK - Window opened');
  writeln('');

  if screenshot_file <> '' then
    writeln('    Animating for 3 seconds...')
  else
    writeln('    Press ESC to quit');
  writeln('');

  start_time := GetClock();
  last_frame_time := GetClock();
  current_frame := 0;
  frame_count := 0;

  { Main render loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);  { Dark blue background }

    { Clear screen area for animation }
    FillChar(screen_image^.data^, SCREEN_WIDTH * SCREEN_HEIGHT * 4, 0);

    { Calculate current frame position in spritesheet grid }
    { GZAL is 224x64 = 14 columns x 4 rows }
    { Each frame is 16x16 }
    { Frame N is at: column = N mod 14, row = N div 14 }
    { Pixel position: x = 50 + (column * 16), y = 50 + (row * 16) }

    if current_frame < TOTAL_FRAMES then
    begin
      src_y := current_frame div 14;  { Row in spritesheet }
      src_x := current_frame mod 14;  { Column in spritesheet }

      { Extract frame from GZAL spritesheet }
      for src_y := 0 to TILE_SIZE - 1 do
      begin
        for src_x := 0 to TILE_SIZE - 1 do
        begin
          { Source: GZAL at (50 + frame_col*16 + src_x, 50 + frame_row*16 + src_y) }
          { Actually need to recalculate - let me fix this }
        end;
      end;

      { Simpler approach: copy directly from loaded GZAL }
      { Calculate source position in GZAL }
      src_y := (current_frame div 14) * TILE_SIZE;
      src_x := (current_frame mod 14) * TILE_SIZE;

      { Copy frame to display position (300, 200) }
      for src_y := 0 to TILE_SIZE - 1 do
      begin
        for src_x := 0 to TILE_SIZE - 1 do
        begin
          dst_x := 300 + src_x;
          dst_y := 200 + src_y;

          { Source pixel in GZAL }
          src_idx := ((gzal_start_y + (current_frame div 14) * TILE_SIZE + src_y) * gif_x +
                     (gzal_start_x + (current_frame mod 14) * TILE_SIZE + src_x)) * 4;

          r := PByte(screen_image^.data + src_idx)^;
          g := PByte(screen_image^.data + src_idx + 1)^;
          b := PByte(screen_image^.data + src_idx + 2)^;
          a := PByte(screen_image^.data + src_idx + 3)^;

          { Check for magenta transparency }
          if (r > 250) and (g < 10) and (b > 250) then
            continue;

          { Write to display position }
          dst_idx := (dst_y * SCREEN_WIDTH + dst_x) * 4;
          PByte(screen_image^.data + dst_idx)^ := r;
          PByte(screen_image^.data + dst_idx + 1)^ := g;
          PByte(screen_image^.data + dst_idx + 2)^ := b;
          PByte(screen_image^.data + dst_idx + 3)^ := 255;
        end;
      end;
    end;

    RenderScreenToWindow();
    EndDrawing();

    inc(frame_count);

    { Update animation frame }
    if GetClock() - last_frame_time >= FRAME_DELAY_MS then
    begin
      inc(current_frame);
      if current_frame >= TOTAL_FRAMES then
        current_frame := 0;
      last_frame_time := GetClock();
    end;

    { Check for timeout (3 seconds) }
    if (screenshot_file <> '') and (GetClock() - start_time >= 3000) then
    begin
      writeln('    Time elapsed (3 seconds)');
      break;
    end;
  end;

  { Take screenshot if requested }
  if screenshot_file <> '' then
  begin
    writeln('[4] Taking screenshot: ', screenshot_file);
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
end.
