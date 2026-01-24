program test_gif_load;

{$mode objfpc}{$H+}

{ Test loading GIF images from MAIN.DAT and SIRIEL35.DAT }

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

begin
  writeln('=== GIF Loading Test ===');
  writeln('Testing GIF loading from DAT files');
  writeln('');

  { Initialize Raylib }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'GIF Loading Test');
  SetTargetFPS(60);

  { Initialize screen }
  writeln('Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);

  { Load palette }
  writeln('Loading palette from MAIN.DAT...');
  load_palette_block('data/MAIN.DAT', 'PAL256', palette);
  writeln('Palette loaded');
  writeln('');

  { Clear screen }
  clear_bitmap(screen_image);

  { Try to load various GIF images from MAIN.DAT }
  writeln('Trying to load GIF images from MAIN.DAT...');
  writeln('');

  { First, let's manually check if blocks exist }
  writeln('Checking block existence...');
  writeln('  MAIN.DAT exists: ', subor_exist('data/MAIN.DAT'));
  writeln('  MAIN.DAT has PALETA: ', checkblock_info('data/MAIN.DAT', 'PALETA'));
  writeln('  MAIN.DAT has GLOGO: ', checkblock_info('data/MAIN.DAT', 'GLOGO'));
  writeln('  MAIN.DAT has FMOD: ', checkblock_info('data/MAIN.DAT', 'FMOD'));
  writeln('');

  { Test 1: Try 'GLOGO' (game logo) }
  writeln('Test 1: Loading GLOGO from MAIN.DAT...');
  try
    gif_loaded := draw_gif_block(screen_image, 'data/MAIN.DAT', 'GLOGO', 100, 10, palette);
    if gif_loaded then
      writeln('  ✓ GLOGO loaded successfully')
    else
      writeln('  ✗ GLOGO not found');
  except
    on E: Exception do
      writeln('  ✗ GLOGO error: ', E.Message);
  end;

  { Test 2: Try 'INTRO' or similar keys }
  writeln('Test 2: Trying INTRO from MAIN.DAT...');
  try
    gif_loaded := draw_gif_block(screen_image, 'data/MAIN.DAT', 'INTRO', 0, 0, palette);
    if gif_loaded then
      writeln('  ✓ INTRO loaded successfully')
    else
      writeln('  ✗ INTRO not found');
  except
    on E: Exception do
      writeln('  ✗ INTRO error: ', E.Message);
  end;

  { Test 3: Try loading from SIRIEL35.DAT }
  writeln('Test 3: Trying INTRO from SIRIEL35.DAT...');
  try
    gif_loaded := draw_gif_block(screen_image, 'data/SIRIEL35.DAT', 'INTRO', 0, 0, palette);
    if gif_loaded then
      writeln('  ✓ INTRO from SIRIEL35.DAT loaded successfully')
    else
      writeln('  ✗ INTRO not found in SIRIEL35.DAT');
  except
    on E: Exception do
      writeln('  ✗ INTRO error: ', E.Message);
  end;

  { Test 4: Try 'POHYBY' (background/intro) }
  writeln('Test 4: Trying POHYBY from SIRIEL35.DAT...');
  try
    gif_loaded := draw_gif_block(screen_image, 'data/SIRIEL35.DAT', 'POHYBY', 0, 0, palette);
    if gif_loaded then
      writeln('  ✓ POHYBY loaded successfully')
    else
      writeln('  ✗ POHYBY not found');
  except
    on E: Exception do
      writeln('  ✗ POHYBY error: ', E.Message);
  end;

  { Test 5: Try 'MENU' }
  writeln('Test 5: Trying MENU from MAIN.DAT...');
  try
    gif_loaded := draw_gif_block(screen_image, 'data/MAIN.DAT', 'MENU', 0, 0, palette);
    if gif_loaded then
      writeln('  ✓ MENU loaded successfully')
    else
      writeln('  ✗ MENU not found');
  except
    on E: Exception do
      writeln('  ✗ MENU error: ', E.Message);
  end;

  { Add some test text }
  writeln('');
  writeln('Drawing test text on top...');
  print_normal(screen_image, 10, 450, 'GIF Loading Test', 15, 0);

  writeln('');
  writeln('Starting render loop (will run for 3 seconds)...');
  writeln('');

  { Render for 3 seconds (180 frames) }
  for frame := 1 to 180 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);  { Black background }

    { Render our virtual screen }
    RenderScreenToWindow();

    EndDrawing();
  end;

  { Take screenshot }
  writeln('Taking screenshot: gif_load_test.png');
  TakeScreenshot(PChar('gif_load_test.png'));
  writeln('Screenshot saved');

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Check gif_load_test.png');
  writeln('');
  writeln('If GIF loaded: You should see game graphics');
  writeln('If no GIF: Screen will be black with text at bottom');
end.
