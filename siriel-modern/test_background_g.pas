program test_background_g;

{$mode objfpc}{$H+}

{ Test loading G-prefixed graphics from SIRIEL35.DAT }

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

  { All G-prefixed blocks from SIRIEL35.DAT - Graphics }
  candidates: array[1..5] of record
    name: string;
    size: longint;
  end = (
    (name: 'GOUTRO'; size: 70310),
    (name: 'GTREEP'; size: 44097),
    (name: 'GTEXT';  size: 4935),
    (name: 'GANIM';  size: 2586),
    (name: 'GVECI';  size: 1975)
  );

  i: integer;

begin
  writeln('=== Background Loading Test (G-Prefixed) ===');
  writeln('Testing graphics files from SIRIEL35.DAT');
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

  { Try loading G-prefixed graphics - skip GOUTRO (ending screen) }
  for i := 2 to 5 do
  begin
    writeln('Testing: ', candidates[i].name, ' (', candidates[i].size, ' bytes)');

    gif_loaded := draw_gif_block(screen_image, 'data/SIRIEL35.DAT', candidates[i].name, 0, 0, palette);

    if gif_loaded then
    begin
      writeln('  ✓ ', candidates[i].name, ' loaded successfully!');
      writeln('    Dimensions: ', blockx.gif_x, 'x', blockx.gif_y);

      if (blockx.gif_x = 640) and (blockx.gif_y = 480) then
      begin
        writeln('    *** FOUND 640x480 BACKGROUND! ***');
        writeln('    Screenshot saved as background_test.png');

        { Render for 3 seconds }
        for frame := 1 to 180 do
        begin
          BeginDrawing();
          ClearBackground(0, 0, 0, 255);
          RenderScreenToWindow();
          EndDrawing();
        end;

        TakeScreenshot(PChar('background_test.png'));
        Break;
      end
      else
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
  print_normal(screen_image, 10, 450, 'Background Test', 15, 0);

  { Final render }
  for frame := 1 to 60 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);
    RenderScreenToWindow();
    EndDrawing();
  end;

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Check background_test.png for the 640x480 background');
end.
