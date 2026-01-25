program test_tile_display;

{$mode objfpc}{$H+}

{ Simple test to load GZAL spritesheet and display first tile
  Usage: ./test_tile_display [screenshot_file.png] [duration_seconds]
  Examples:
    ./test_tile_display                         # Interactive mode
    ./test_tile_display screenshot.png          # Take screenshot then quit
    ./test_tile_display screenshot.png 2        # Run for 2 seconds, take screenshot, quit
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

var
  palette: jxfont_simple.tpalette;
  screenshot_file: string;
  duration_seconds: integer;
  frame_count: integer;
  start_time: longint;
  src_x, src_y, dst_x, dst_y: word;
  src_idx, dst_idx: longint;
  r, g, b: byte;

{ Convert palette-indexed pixel to RGBA }
procedure palette_pixel_to_rgba(dest: pointer; src: PByte; width, height: word; pal: jxfont_simple.tpalette);
var
  x, y: word;
  src_idx, dst_idx: longint;
  color_idx: byte;
  r, g, b: byte;
begin
  for y := 0 to height - 1 do
  begin
    for x := 0 to width - 1 do
    begin
      src_idx := y * width + x;
      dst_idx := (y * width + x) * 4;

      color_idx := src[src_idx];

      { Get RGB from palette }
      r := pal[color_idx].r;
      g := pal[color_idx].v;
      b := pal[color_idx].b;

      { Write RGBA (with full alpha) }
      PByte(dest + dst_idx)^ := r;
      PByte(dest + dst_idx + 1)^ := g;
      PByte(dest + dst_idx + 2)^ := b;
      PByte(dest + dst_idx + 3)^ := 255;
    end;
  end;
end;

{ Draw palette-indexed frame to RGBA screen image }
procedure draw_frame_to_screen(src: PByte; x, y, width, height: word; pal: jxfont_simple.tpalette);
var
  px, py: word;
  src_idx: longint;
  dst_x, dst_y: word;
  dst_idx: longint;
  color_idx: byte;
  r, g, b: byte;
begin
  for py := 0 to height - 1 do
  begin
    for px := 0 to width - 1 do
    begin
      src_idx := py * width + px;
      dst_x := x + px;
      dst_y := y + py;

      if (dst_x < SCREEN_WIDTH) and (dst_y < SCREEN_HEIGHT) then
      begin
        color_idx := src[src_idx];

        { Skip transparent color (index 13) }
        if color_idx <> 13 then
        begin
          { Get RGB from palette }
          r := pal[color_idx].r;
          g := pal[color_idx].v;
          b := pal[color_idx].b;

          { Calculate destination index }
          dst_idx := (dst_y * SCREEN_WIDTH + dst_x) * 4;

          { Write RGBA }
          PByte(screen_image^.data + dst_idx)^ := r;
          PByte(screen_image^.data + dst_idx + 1)^ := g;
          PByte(screen_image^.data + dst_idx + 2)^ := b;
          PByte(screen_image^.data + dst_idx + 3)^ := 255;
        end;
      end;
    end;
  end;
end;

begin
  writeln('=== Siriel Modern - Tile Display Test ===');
  writeln('');

  { Parse command line }
  screenshot_file := '';
  duration_seconds := 0;

  if ParamCount >= 1 then
    screenshot_file := ParamStr(1);

  if ParamCount >= 2 then
    duration_seconds := StrToIntDef(ParamStr(2), 0);

  if screenshot_file <> '' then
    writeln('Mode: Automated (screenshot to "', screenshot_file, '")')
  else
    writeln('Mode: Interactive');

  if duration_seconds > 0 then
    writeln('Duration: ', duration_seconds, ' seconds');

  writeln('');

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  writeln('[1] Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);
  writeln('');

  { Load GZAL block from MAIN.DAT }
  writeln('[2] Loading GZAL from MAIN.DAT...');
  if not draw_gif_block(screen_image, 'data/MAIN.DAT', 'GZAL', 0, 0, palette) then
  begin
    writeln('    ERROR: Failed to load GZAL block');
    if screenshot_file = '' then readln;
    Exit;
  end;
  writeln('    OK - GZAL loaded');
  writeln('    Dimensions: ', gif_x, 'x', gif_y, ' (', gif_x div 16, 'x', gif_y div 16, ' = ', (gif_x div 16) * (gif_y div 16), ' frames)');
  writeln('');

  { Now we have GZAL loaded at (0,0) in screen_image
    Let's extract frame 0 data and redraw it at a visible position }

  { Clear screen to black }
  FillChar(screen_image^.data^, SCREEN_WIDTH * SCREEN_HEIGHT * 4, 0);

  { The GIF is already loaded at (0,0) in screen_image
    Frame 0 is at position (0,0) with size 16x16
    Let's copy it to a visible position (100, 100) }

  writeln('[3] Extracting and redrawing first tile at (100, 100)...');

  { Copy pixels from (0,0) to (100,100) with transparency handling }
  for src_y := 0 to 15 do
  begin
    for src_x := 0 to 15 do
    begin
      dst_x := 100 + src_x;
      dst_y := 100 + src_y;

      { Read source pixel from GIF at (src_x, src_y) }
      src_idx := (src_y * gif_x + src_x) * 4;
      r := PByte(screen_image^.data + src_idx)^;
      g := PByte(screen_image^.data + src_idx + 1)^;
      b := PByte(screen_image^.data + src_idx + 2)^;

      { Check if it's transparent (magenta/pink) }
      if (r > 250) and (g < 100) and (b > 250) then
      begin
        { Transparent - skip }
        continue;
      end;

      { Write to destination }
      dst_idx := (dst_y * SCREEN_WIDTH + dst_x) * 4;
      PByte(screen_image^.data + dst_idx)^ := r;
      PByte(screen_image^.data + dst_idx + 1)^ := g;
      PByte(screen_image^.data + dst_idx + 2)^ := b;
      PByte(screen_image^.data + dst_idx + 3)^ := 255;
    end;
  end;

  writeln('    OK - Tile copied to (100, 100)');
  writeln('');

  { Open window }
  writeln('[4] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Tile Display Test - First Frame from GZAL');
  SetTargetFPS(60);
  writeln('    OK - Window opened');
  writeln('');

  if screenshot_file <> '' then
    writeln('    Running for ', duration_seconds, ' seconds...')
  else
    writeln('    Press ESC to quit');
  writeln('');

  start_time := GetClock();
  frame_count := 0;

  { Main render loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    RenderScreenToWindow();
    EndDrawing();

    inc(frame_count);

    { Check for timeout }
    if (duration_seconds > 0) and (GetClock() - start_time >= duration_seconds * 1000) then
    begin
      writeln('    Time elapsed (', duration_seconds, ' seconds)');
      break;
    end;
  end;

  { Take screenshot if requested }
  if screenshot_file <> '' then
  begin
    writeln('[5] Taking screenshot: ', screenshot_file);
    TakeScreenshot(PChar(screenshot_file));
    writeln('    OK - Screenshot saved');
  end;

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Frames rendered: ', frame_count);
  if screenshot_file <> '' then
    writeln('Screenshot saved to: ', screenshot_file);
  writeln('');
end.
