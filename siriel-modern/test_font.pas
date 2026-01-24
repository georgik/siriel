program test_font;

{$mode objfpc}{$H+}

{ Test loading and displaying actual font from MAIN.DAT }

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
  font_width, font_height: word;
  palette: tpalette;

begin
  writeln('=== Font Loading Test ===');
  writeln('Testing actual font loading from MAIN.DAT');
  writeln('');

  { Initialize Raylib }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Font Test');
  SetTargetFPS(60);

  { Initialize screen }
  writeln('Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);

  { Load palette }
  writeln('Loading palette from MAIN.DAT...');
  load_palette_block('data/MAIN.DAT', 'PAL256', palette);
  writeln('Palette loaded');

  { Try to load font }
  writeln('Attempting to load font from MAIN.DAT...');
  writeln('Looking for font blocks...');
  writeln('');

  { Try to load a font - we need to find the correct key }
  { Common font keys might be: 'FONT', 'FONT8', 'FONT8X8', etc. }
  try
    Font_Load_block('data/MAIN.DAT', 'FONT', font_width, font_height);
    writeln('Font loaded successfully!');
    writeln('  Font width: ', font_width);
    writeln('  Font height: ', font_height);
  except
    on E: Exception do
    begin
      writeln('Font loading failed: ', E.Message);
      writeln('Trying alternative font keys...');

      { Try 'FONT8' }
      try
        Font_Load_block('data/MAIN.DAT', 'FONT8', font_width, font_height);
        writeln('FONT8 loaded: ', font_width, 'x', font_height);
      except
        writeln('FONT8 not available');
      end;
    end;
  end;

  { Clear screen }
  clear_bitmap(screen_image);

  { Draw test text using different colors }
  writeln('');
  writeln('Drawing test text...');

  { Draw text at various positions with different colors }
  print_normal(screen_image, 50, 50, 'SIRIEL 3.5', 15, 0);  { White }
  print_normal(screen_image, 50, 80, 'Font Test', 14, 0);   { Yellow }
  print_normal(screen_image, 50, 110, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 11, 0);  { Light cyan }
  print_normal(screen_image, 50, 140, 'abcdefghijklmnopqrstuvwxyz', 10, 0);  { Light green }
  print_normal(screen_image, 50, 170, '0123456789', 12, 0);  { Light red }
  print_normal(screen_image, 50, 200, 'Quick brown fox jumps over lazy dog', 13, 0);  { Light magenta }

  writeln('Text drawn');
  writeln('');
  writeln('Starting render loop (will run for 2 seconds)...');
  writeln('');

  { Render for 2 seconds (120 frames) }
  for frame := 1 to 120 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);  { Black background }

    { Render our virtual screen }
    RenderScreenToWindow();

    EndDrawing();
  end;

  { Take screenshot }
  writeln('Taking screenshot: font_test.png');
  TakeScreenshot(PChar('font_test.png'));
  writeln('Screenshot saved');

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Check font_test.png');
  writeln('');
  writeln('If text is visible: Font loading works!');
  writeln('If text is blocks: Font not loaded, using fallback');
end.
