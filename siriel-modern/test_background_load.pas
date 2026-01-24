program test_background_load;

{$mode objfpc}{$H+}

{ Test loading 640x480 background from SIRIEL35.DAT }

uses
  ctypes,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  blockx,
  dos_compat,
  SysUtils;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  frame: integer;
  palette: tpalette;
  gif_loaded: boolean;
  candidates: array[1..5] of string = ('ZNAEC', 'ZSCHUB', 'ZROCK', 'ZPARA', 'ZFEELGO');
  i: integer;

begin
  writeln('=== Background Loading Test ===');
  writeln('Searching for 640x480 background in SIRIEL35.DAT');
  writeln('');

  { Initialize Raylib }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Background Test');
  SetTargetFPS(60);

  { Initialize screen }
  writeln('Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);

  { Load palette }
  writeln('Loading palette from MAIN.DAT...');
  load_palette_block('data/MAIN.DAT', 'PALETA', palette);
  writeln('Palette loaded');
  writeln('');

  { Clear screen }
  clear_bitmap(screen_image);

  { Try loading background candidates }
  for i := 1 to 5 do
  begin
    writeln('Trying: ', candidates[i]);
    writeln('  File exists: ', subor_exist('data/SIRIEL35.DAT'));
    writeln('  Block exists: ', checkblock_info('data/SIRIEL35.DAT', candidates[i]));

    gif_loaded := draw_gif_block(screen_image, 'data/SIRIEL35.DAT', candidates[i], 0, 0, palette);

    if gif_loaded then
    begin
      writeln('  ✓ ', candidates[i], ' loaded successfully!');
      writeln('    Dimensions: ', gif_x, 'x', gif_y);

      if (gif_x = 640) and (gif_y = 480) then
      begin
        writeln('    *** FOUND 640x480 BACKGROUND! ***');
        Break;
      end;

      { If not 640x480, clear and try next }
      if i < 5 then
      begin
        writeln('    Not 640x480, clearing and trying next...');
        clear_bitmap(screen_image);
      end;
    end
    else
      writeln('  ✗ Failed to load');

    writeln('');
  end;

  { Add test text }
  print_normal(screen_image, 10, 450, 'Background Test - SIRIEL35.DAT', 15, 0);

  writeln('Starting render loop (will run for 3 seconds)...');
  writeln('');

  { Render for 3 seconds (180 frames) }
  for frame := 1 to 180 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);

    RenderScreenToWindow();

    EndDrawing();
  end;

  { Take screenshot }
  writeln('Taking screenshot: background_test.png');
  TakeScreenshot(PChar('background_test.png'));
  writeln('Screenshot saved');

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Check background_test.png');
end.
