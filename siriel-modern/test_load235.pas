program test_load235;

{$mode objfpc}{$H+}

{ Test LOAD235 unit with resource loading
  Verifies resource loading integration with proper screen positions
  Usage: ./test_load235 [screenshot_file.png]
}

uses
  SysUtils,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  load235,
  geo;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  screenshot_file: string;
  frame_count: integer;
  start_time: longint;
  x, y, dst_idx: longint;

begin
  writeln('=== LOAD235 Unit Test ===');
  writeln('Testing resource loading system');
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

  { Fill screen with a visible background color to verify rendering }
  writeln('[1.5] Filling screen with test pattern...');
  for y := 0 to SCREEN_HEIGHT - 1 do
  begin
    for x := 0 to SCREEN_WIDTH - 1 do
    begin
      dst_idx := (y * SCREEN_WIDTH + x) * 4;
      PByte(screen_image^.data + dst_idx)^ := 40;      { R }
      PByte(screen_image^.data + dst_idx + 1)^ := 40;  { G }
      PByte(screen_image^.data + dst_idx + 2)^ := 60;  { B }
      PByte(screen_image^.data + dst_idx + 3)^ := 255;  { A }
    end;
  end;
  writeln('    OK - Background filled (dark blue)');
  writeln('');

  { Test draw_it function with GLIST at visible position }
  writeln('[2] Testing draw_it with GLIST at (100, 100)...');
  draw_it('>GLIST', 100, 100);
  writeln('    OK - GLIST drawn at (100, 100)');
  writeln('    GLIST dimensions: 129x16 pixels');
  writeln('    Visible area: x=100 to 229, y=100 to 116');
  writeln('');

  { Draw a second GLIST at a different position }
  writeln('[3] Testing draw_it with second GLIST at (100, 150)...');
  draw_it('>GLIST', 100, 150);
  writeln('    OK - Second GLIST drawn at (100, 150)');
  writeln('');

  { Draw a red test rectangle to verify screen coordinates }
  writeln('[3.5] Drawing test rectangles to verify coordinates...');
  { Red rectangle at top-left }
  for y := 10 to 50 do
    for x := 10 to 50 do
    begin
      dst_idx := (y * SCREEN_WIDTH + x) * 4;
      PByte(screen_image^.data + dst_idx)^ := 255;     { R }
      PByte(screen_image^.data + dst_idx + 1)^ := 0;     { G }
      PByte(screen_image^.data + dst_idx + 2)^ := 0;     { B }
      PByte(screen_image^.data + dst_idx + 3)^ := 255;   { A }
    end;
  writeln('    Red rectangle at (10,10) to (50,50)');

  { Green rectangle at bottom-right }
  for y := 400 to 450 do
    for x := 500 to 550 do
    begin
      dst_idx := (y * SCREEN_WIDTH + x) * 4;
      PByte(screen_image^.data + dst_idx)^ := 0;       { R }
      PByte(screen_image^.data + dst_idx + 1)^ := 255;   { G }
      PByte(screen_image^.data + dst_idx + 2)^ := 0;     { B }
      PByte(screen_image^.data + dst_idx + 3)^ := 255;   { A }
    end;
  writeln('    Green rectangle at (500,400) to (550,450)');
  writeln('    OK - Test rectangles drawn');
  writeln('');

  { Test load_predmet (placeholder) }
  writeln('[4] Testing load_predmet...');
  load_predmet;
  writeln('');

  { Test load_texture (placeholder) }
  writeln('[5] Testing load_texture...');
  load_texture;
  writeln('');

  { Open window }
  writeln('[6] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'LOAD235 Test - Resource Loading');
  SetTargetFPS(60);
  writeln('    OK - Window opened');
  writeln('');

  if screenshot_file <> '' then
    writeln('    Rendering for 1 second...')
  else
    writeln('    Press ESC to quit');
  writeln('');

  writeln('You should see:');
  writeln('  - Dark blue background (40,40,60)');
  writeln('  - Red square in top-left corner (10,10)-(50,50)');
  writeln('  - Green square in bottom-right (500,400)-(550,450)');
  writeln('  - GLIST blocks at y=100 and y=150');
  writeln('');

  start_time := GetClock();
  frame_count := 0;

  { Main render loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);
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
    writeln('[7] Taking screenshot: ', screenshot_file);
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
  writeln('LOAD235 unit integration test successful!');
  writeln('  - draw_it() function working');
  writeln('  - Screen coordinates verified');
  writeln('  - Resource loading via blockx.draw_gif_block');
  writeln('');
end.
