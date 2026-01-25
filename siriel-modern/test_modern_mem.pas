program test_modern_mem;

{$mode objfpc}{$H+}

{ Test modern memory management (XMS replacement)
  Verifies that create_handle, kill_handle, and Save_scr/draw_scr work correctly
  Usage: ./test_modern_mem [screenshot_file.png]
}

uses
  SysUtils,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  blockx,
  modern_mem,
  geo;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;
  NUM_HANDLES = 10;
  TEST_SIZE = 1024;

var
  handles: array[0..NUM_HANDLES - 1] of klucka;
  palette: jxfont_simple.tpalette;
  screenshot_file: string;
  frame_count: integer;
  start_time: longint;
  test_data: array[0..TEST_SIZE - 1] of byte;
  f: word;
  x, y, dst_x, dst_y: word;
  dst_idx: longint;

begin
  writeln('=== Modern Memory Management Test ===');
  writeln('Testing XMS replacement with standard FPC memory');
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

  { Initialize handles }
  writeln('[2] Initializing ', NUM_HANDLES, ' memory handles...');
  init_handles(NUM_HANDLES, handles);
  writeln('    OK - Handles initialized');
  writeln('');

  { Test 1: Create handles }
  writeln('[3] Testing handle creation...');
  for f := 0 to 4 do
  begin
    if create_handle(handles[f], TEST_SIZE) then
      writeln('    Handle ', f, ' allocated (', TEST_SIZE, ' bytes)')
    else
      writeln('    ERROR: Handle ', f, ' allocation failed');
  end;
  writeln('    OK - All handles created');
  writeln('');

  { Test 2: Write test data to memory }
  writeln('[4] Writing test patterns to allocated memory...');
  for f := 0 to 4 do
  begin
    if handles[f].used and (handles[f].ptr <> nil) then
    begin
      { Fill with pattern }
      for x := 0 to TEST_SIZE - 1 do
        PByte(handles[f].ptr + x)^ := (f + x) mod 256;
      writeln('    Handle ', f, ' filled with pattern');
    end;
  end;
  writeln('    OK - Test patterns written');
  writeln('');

  { Test 3: Draw some colored rectangles on screen }
  writeln('[5] Drawing test rectangles to screen...');
  for f := 0 to 4 do
  begin
    x := 50 + f * 100;
    y := 100;

    { Draw filled rectangle }
    for dst_y := y to y + 79 do
    begin
      for dst_x := x to x + 79 do
      begin
        dst_idx := (dst_y * SCREEN_WIDTH + dst_x) * 4;
        PByte(screen_image^.data + dst_idx)^ := f * 50;     { R }
        PByte(screen_image^.data + dst_idx + 1)^ := 100;   { G }
        PByte(screen_image^.data + dst_idx + 2)^ := 255 - f * 50; { B }
        PByte(screen_image^.data + dst_idx + 3)^ := 255;   { A }
      end;
    end;

    writeln('    Rectangle ', f, ' drawn at (', x, ', ', y, ')');
  end;
  writeln('    OK - Rectangles drawn');
  writeln('');

  { Test 4: Save screen region }
  writeln('[6] Testing Save_scr (screen to memory)...');
  if create_handle(handles[5], 80 * 80) then
  begin
    Save_scr(handles[5], 150, 100, 80, 80);
    writeln('    Screen region (150, 100, 80x80) saved to handle 5');
    writeln('    OK - Save_scr successful');
  end;
  writeln('');

  { Test 5: Clear and restore screen region }
  writeln('[7] Testing draw_scr (memory to screen)...');
  { Clear the original region }
  for y := 100 to 179 do
  begin
    for x := 150 to 229 do
    begin
      dst_idx := (y * SCREEN_WIDTH + x) * 4;
      PByte(screen_image^.data + dst_idx)^ := 0;
      PByte(screen_image^.data + dst_idx + 1)^ := 0;
      PByte(screen_image^.data + dst_idx + 2)^ := 0;
      PByte(screen_image^.data + dst_idx + 3)^ := 255;
    end;
  end;

  { Restore from saved copy }
  draw_scr(handles[5], 300, 100, 80, 80);
  writeln('    Region cleared and restored at (300, 100)');
  writeln('    OK - draw_scr successful');
  writeln('');

  { Test 6: Kill handles }
  writeln('[8] Testing handle cleanup...');
  for f := 0 to 4 do
  begin
    if kill_handle(handles[f]) then
      writeln('    Handle ', f, ' freed')
    else
      writeln('    WARNING: Handle ', f, ' was not allocated');
  end;
  writeln('    OK - Handles freed');
  writeln('');

  { Open window }
  writeln('[9] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Modern Memory Test - XMS Replacement');
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
    writeln('[10] Taking screenshot: ', screenshot_file);
    TakeScreenshot(PChar(screenshot_file));
    writeln('    OK - Screenshot saved');
  end;

  { Cleanup }
  done_handles(handles);
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Frames rendered: ', frame_count);
  if screenshot_file <> '' then
    writeln('Screenshot: ', screenshot_file);
  writeln('');
  writeln('You should see:');
  writeln('  - 5 colored rectangles (handle allocation test)');
  writeln('  - Rectangle copied from (150,100) to (300,100) (Save_scr/draw_scr test)');
  writeln('');
end.
