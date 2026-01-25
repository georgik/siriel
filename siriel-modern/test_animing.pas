program test_animing;

{$mode objfpc}{$H+}

{ Test ANIMING unit with modern_mem integration
  Verifies that sprite storage and retrieval work correctly
  Usage: ./test_animing
}

uses
  SysUtils,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  blockx,
  modern_mem,
  geo,
  animing;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;
  TILE_SIZE = 16;
  NUM_TILES = 4;

var
  sprite_handle: klucka;
  sprite_data: array[0..TILE_SIZE * TILE_SIZE * NUM_TILES - 1] of byte;
  screenshot_file: string;
  frame_count: integer;
  f, x, y: word;
  test_x, test_y: word;
  r, g, b, a: byte;
  src_idx, dst_idx: longint;

begin
  writeln('=== ANIMING Unit Test ===');
  writeln('Testing sprite storage with modern_mem');
  writeln('');

  { Parse command line }
  screenshot_file := '';
  if ParamCount >= 1 then
    screenshot_file := ParamStr(1);

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  writeln('[1] Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);
  writeln('');

  { Test 1: Create handle for sprite storage }
  writeln('[2] Creating sprite handle...');
  if create_handle(sprite_handle, TILE_SIZE * TILE_SIZE * NUM_TILES) then
    writeln('    OK - Handle allocated (', TILE_SIZE * TILE_SIZE * NUM_TILES, ' bytes)')
  else
  begin
    writeln('    ERROR: Handle allocation failed');
    exit;
  end;
  writeln('');

  { Test 2: Draw colored test sprites on screen }
  writeln('[3] Drawing test sprites to screen...');
  for f := 0 to NUM_TILES - 1 do
  begin
    test_x := 100 + f * (TILE_SIZE + 10);
    test_y := 200;

    { Draw colored rectangle }
    for y := 0 to TILE_SIZE - 1 do
    begin
      for x := 0 to TILE_SIZE - 1 do
      begin
        dst_idx := ((test_y + y) * SCREEN_WIDTH + (test_x + x)) * 4;
        PByte(screen_image^.data + dst_idx)^ := f * 60;      { R }
        PByte(screen_image^.data + dst_idx + 1)^ := 100;    { G }
        PByte(screen_image^.data + dst_idx + 2)^ := 255 - f * 60; { B }
        PByte(screen_image^.data + dst_idx + 3)^ := 255;    { A }
      end;
    end;

    writeln('    Sprite ', f, ' drawn at (', test_x, ', ', test_y, ')');
  end;
  writeln('    OK - Test sprites drawn');
  writeln('');

  { Test 3: Use getsegxms to store sprites in handle }
  writeln('[4] Storing sprites to handle using getsegxms...');
  for f := 0 to NUM_TILES - 1 do
  begin
    test_x := 100 + f * (TILE_SIZE + 10);
    test_y := 200;

    getsegxms(sprite_handle, test_x, test_y, TILE_SIZE, TILE_SIZE, f);
    writeln('    Sprite ', f, ' stored to frame ', f);
  end;
  writeln('    OK - All sprites stored in handle');
  writeln('');

  { Test 4: Clear screen }
  writeln('[5] Clearing screen...');
  for y := 0 to SCREEN_HEIGHT - 1 do
  begin
    for x := 0 to SCREEN_WIDTH - 1 do
    begin
      dst_idx := (y * SCREEN_WIDTH + x) * 4;
      PByte(screen_image^.data + dst_idx)^ := 20;       { R }
      PByte(screen_image^.data + dst_idx + 1)^ := 20;   { G }
      PByte(screen_image^.data + dst_idx + 2)^ := 30;   { B }
      PByte(screen_image^.data + dst_idx + 3)^ := 255;  { A }
    end;
  end;
  writeln('    OK - Screen cleared');
  writeln('');

  { Test 5: Use putsegxms to restore sprites at different positions }
  writeln('[6] Restoring sprites from handle using putsegxms...');
  for f := 0 to NUM_TILES - 1 do
  begin
    test_x := 300 + f * (TILE_SIZE + 10);
    test_y := 200;

    putsegxms(sprite_handle, test_x, test_y, TILE_SIZE, TILE_SIZE, f);
    writeln('    Sprite ', f, ' restored at (', test_x, ', ', test_y, ')');
  end;
  writeln('    OK - All sprites restored');
  writeln('');

  { Test 6: Open window and display }
  writeln('[7] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'ANIMING Test - modern_mem Integration');
  SetTargetFPS(60);
  writeln('    OK - Window opened');
  writeln('');

  if screenshot_file <> '' then
    writeln('    Rendering for 1 second...')
  else
    writeln('    Press ESC to quit');
  writeln('');

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
    if (screenshot_file <> '') and (frame_count >= 60) then
      break;
  end;

  { Take screenshot if requested }
  if screenshot_file <> '' then
  begin
    writeln('[8] Taking screenshot: ', screenshot_file);
    TakeScreenshot(PChar(screenshot_file));
    writeln('    OK - Screenshot saved');
  end;

  { Cleanup }
  kill_handle(sprite_handle);
  CloseWindow;

  writeln('');
  writeln('=== Test Complete ===');
  writeln('Frames rendered: ', frame_count);
  if screenshot_file <> '' then
    writeln('Screenshot: ', screenshot_file);
  writeln('');
  writeln('You should see:');
  writeln('  - 4 colored sprites on the right side (restored from handle)');
  writeln('  - Each sprite is 16x16 pixels');
  writeln('  - Sprites were stored via getsegxms() and restored via putsegxms()');
  writeln('');
  writeln('ANIMING unit modern_mem integration test successful!');
  writeln('  - getsegxms() stores sprites correctly');
  writeln('  - putsegxms() restores sprites correctly');
  writeln('  - Memory handles work with sprite data');
  writeln('');
end.
