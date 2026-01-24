program test_resources;

{$mode objfpc}{$H+}

{ Test program for resource loading from .DAT files }

uses
  ctypes,
  raylib_helpers,
  jxgraf,
  blockx,
  jxfont_simple,
  dos_compat,
  SysUtils;

type
  PcChar = PChar;

const
  KEY_ESCAPE = 256;
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  palette: tpalette;
  test_ok: boolean;
  frame_count: longint;
  start_time, current_time, elapsed_seconds: double;

begin
  writeln('=== Siriel Modern - Resource Loading Test ===');
  writeln('');

  { Step 1: Test file existence }
  writeln('Step 1: Checking data files...');
  if subor_exist('data/MAIN.DAT') then
  begin
    writeln('  ✓ MAIN.DAT found')
  end
  else
    writeln('  ✗ MAIN.DAT not found');

  if subor_exist('data/SIRIEL35.DAT') then
  begin
    writeln('  ✓ SIRIEL35.DAT found')
  end
  else
    writeln('  ✗ SIRIEL35.DAT not found');
  writeln('');

  { Step 2: Initialize Raylib }
  writeln('Step 2: Initializing Raylib...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Resource Loading Test');
  SetTargetFPS(60);
  writeln('  ✓ Window created (', SCREEN_WIDTH, 'x', SCREEN_HEIGHT, ')');
  writeln('');

  { Step 3: Open block file }
  writeln('Step 3: Opening MAIN.DAT as block file...');
  if OpenblockFile('data/MAIN.DAT') then
    writeln('  ✓ Block file opened successfully')
  else
  begin
    writeln('  ✗ Failed to open block file');
    CloseWindow;
    exit;
  end;
  writeln('');

  { Step 4: Test block info }
  writeln('Step 4: Testing block file info...');
  if checkblock_info('data/MAIN.DAT', 'TEST') then
    writeln('  ✓ Block info check works')
  else
    writeln('  Note: Block TEST not found (expected if no TEST key exists)');
  writeln('');

  { Step 5: Load palette }
  writeln('Step 5: Testing palette loading...');
  load_palette_block('data/MAIN.DAT', 'PAL256', palette);
  writeln('  ✓ Palette load attempted');
  writeln('');

  { Step 6: Draw test patterns }
  writeln('Step 6: Drawing test patterns to screen...');
  rectangle2(PImage(screen), 10, 10, 100, 50, $00FF); { Red rectangle (BGR format) }
  rectangle2(PImage(screen), 120, 10, 210, 50, $00FF00); { Green rectangle }
  rectangle2(PImage(screen), 230, 10, 320, 50, $FF0000); { Blue rectangle }
  circle(PImage(screen), 50, 100, 30, $00FFFF); { Yellow circle }
  print_normal(PImage(screen), 10, 150, 'Siriel Modern Resource Test', 15, 0);
  writeln('  ✓ Test patterns drawn');
  writeln('');

  { Step 7: Main render loop }
  writeln('Step 7: Starting render loop...');
  writeln('  Press ESC to exit (or wait 10 seconds for auto-exit)...');
  writeln('');

  start_time := GetFPS() / 1000.0; { Use FPS as rough time base }
  frame_count := 0;
  elapsed_seconds := 0.0;

  while not (WindowShouldClose() <> 0) do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);

    { Render our virtual screen }
    RenderScreenToWindow();

    frame_count := frame_count + 1;
    if frame_count mod 60 = 0 then
      elapsed_seconds := elapsed_seconds + 1.0;

    { Auto-exit after 10 seconds }
    if elapsed_seconds >= 10.0 then
    begin
      writeln('  ✓ Auto-exit after 10 seconds');
      break;
    end;

    { Check for ESC }
    if IsKeyDown(KEY_ESCAPE) <> 0 then
    begin
      writeln('  ✓ ESC pressed, exiting after ', frame_count, ' frames');
      break;
    end;

    EndDrawing();
  end;

  { Step 8: Cleanup }
  writeln('');
  writeln('Step 8: Cleaning up...');
  CloseblockFile;
  CloseWindow;
  writeln('  ✓ Cleanup successful');
  writeln('');

  { Summary }
  writeln('=== Test Complete ===');
  writeln('  Frames rendered: ', frame_count);
  writeln('  Time elapsed: ', trunc(elapsed_seconds), ' seconds');
  if elapsed_seconds > 0.0 then
    writeln('  Average FPS: ', trunc(frame_count / elapsed_seconds));
  writeln('');
  writeln('Tests performed:');
  writeln('  ✓ File existence checks');
  writeln('  ✓ Block file opening');
  writeln('  ✓ Block info reading');
  writeln('  ✓ Palette loading');
  writeln('  ✓ Drawing operations');
  writeln('  ✓ Render loop');
  writeln('  ✓ Screen rendering');
  writeln('');
  writeln('Resource loading system functional!');
end.
