program test_red_tile;

{$mode objfpc}{$H+}

{ Test pixel blitting by drawing a red 16x16 tile
  Usage: ./test_red_tile [screenshot_file.png]
}

uses
  SysUtils,
  raylib_helpers,
  jxgraf,
  geo;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;
  TILE_SIZE = 16;

var
  screenshot_file: string;
  frame_count: integer;
  start_time: longint;
  x, y: word;
  dst_idx: longint;

begin
  writeln('=== Red Tile Test ===');
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

  { Clear screen to black }
  FillChar(screen_image^.data^, SCREEN_WIDTH * SCREEN_HEIGHT * 4, 0);

  { Draw a red 16x16 tile at position (300, 200) }
  writeln('[2] Drawing red 16x16 tile at (300, 200)...');

  for y := 200 to 200 + TILE_SIZE - 1 do
  begin
    for x := 300 to 300 + TILE_SIZE - 1 do
    begin
      dst_idx := (y * SCREEN_WIDTH + x) * 4;

      { Set pixel to red }
      PByte(screen_image^.data + dst_idx)^ := 255;     { R }
      PByte(screen_image^.data + dst_idx + 1)^ := 0;       { G }
      PByte(screen_image^.data + dst_idx + 2)^ := 0;       { B }
      PByte(screen_image^.data + dst_idx + 3)^ := 255;     { A }
    end;
  end;

  writeln('    OK - Red tile drawn');
  writeln('');

  { Open window }
  writeln('[3] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Red Tile Test - 16x16 Red Square');
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
    ClearBackground(20, 20, 30, 255);  { Dark blue background }
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
  writeln('You should see a RED 16x16 square at position (300, 200)');
  writeln('');
end.
