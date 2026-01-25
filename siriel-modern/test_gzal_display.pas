program test_gzal_display;

{$mode objfpc}{$H+}

{ Simple test to load and display GZAL GIF from MAIN.DAT
  Usage: ./test_gzal_display [screenshot_file.png]
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
  frame_count: integer;
  start_time: longint;

begin
  writeln('=== GZAL GIF Display Test ===');
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

  { Clear screen to dark background }
  FillChar(screen_image^.data^, SCREEN_WIDTH * SCREEN_HEIGHT * 4, 0);

  { Load GZAL block from MAIN.DAT at visible position (50, 50) }
  writeln('[2] Loading GZAL from MAIN.DAT at position (50, 50)...');
  if not draw_gif_block(screen_image, 'data/MAIN.DAT', 'GZAL', 50, 50, palette) then
  begin
    writeln('    ERROR: Failed to load GZAL block');
    if screenshot_file = '' then readln;
    Exit;
  end;

  writeln('    OK - GZAL loaded');
  writeln('    Position: (50, 50)');
  writeln('    Dimensions: ', gif_x, 'x', gif_y, ' (', gif_x div 16, 'x', gif_y div 16, ' = ', (gif_x div 16) * (gif_y div 16), ' frames)');
  writeln('');

  { Open window }
  writeln('[3] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'GZAL Display Test - Full Spritesheet');
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
end.
