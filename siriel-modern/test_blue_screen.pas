program test_blue_screen;

{$mode objfpc}{$H+}

{ Minimal test: Fill virtual screen with blue to verify rendering pipeline }

uses
  ctypes,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  dos_compat,
  SysUtils;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  test_bitmap: PImage;
  x, y, frame: integer;
  blue_color: longint;

begin
  writeln('=== Blue Screen Test ===');
  writeln('This test creates a bitmap filled with blue pixels');
  writeln('');

  { Initialize Raylib }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Blue Screen Test');
  SetTargetFPS(60);

  { Create a test bitmap }
  test_bitmap := create_bitmap(SCREEN_WIDTH, SCREEN_HEIGHT);
  writeln('Test bitmap created: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);

  { Fill bitmap with blue }
  blue_color := (255 shl 24) or (0 shl 16) or (0 shl 8) or 255;  { RGBA: Full alpha, Blue }
  writeln('Filling bitmap with blue color...');

  for y := 0 to SCREEN_HEIGHT - 1 do
  begin
    for x := 0 to SCREEN_WIDTH - 1 do
    begin
      putpixel(test_bitmap, x, y, blue_color);
    end;
  end;

  writeln('Bitmap filled with ', (SCREEN_WIDTH * SCREEN_HEIGHT), ' blue pixels');
  writeln('');
  writeln('Starting render loop (will run for 1 second)...');
  writeln('');

  { Render for 1 second (60 frames) }
  for frame := 1 to 60 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);  { Black background }

    { Manually render our bitmap to verify rendering works }
    { This bypasses RenderScreenToWindow to test the raw putpixel -> DrawPixel pipeline }
    for y := 0 to SCREEN_HEIGHT - 1 do
    begin
      for x := 0 to SCREEN_WIDTH - 1 do
      begin
        DrawPixel(x, y, blue_color);
      end;
    end;

    EndDrawing();
  end;

  { Take screenshot }
  writeln('Taking screenshot: blue_screen_test.png');
  TakeScreenshot(PChar('blue_screen_test.png'));
  writeln('Screenshot saved');

  { Cleanup }
  destroy_bitmap(test_bitmap);
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Check blue_screen_test.png');
  writeln('If it''s BLACK: Raylib DrawPixel is not working');
  writeln('If it''s BLUE: Raylib DrawPixel works!');
end.
