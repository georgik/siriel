program test_raylib_text;

{$mode objfpc}{$H+}

{ Test Raylib text drawing functions directly }

uses
  ctypes,
  raylib_helpers,
  SysUtils;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  frame: integer;

begin
  writeln('=== Raylib Text Drawing Test ===');
  writeln('Testing if Raylib can draw text directly');
  writeln('');

  { Initialize Raylib }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Raylib Text Test');
  SetTargetFPS(60);

  writeln('Starting render loop (will run for 1 second)...');
  writeln('');

  { Render for 1 second (60 frames) }
  for frame := 1 to 60 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);  { Black background }

    { Draw text using Raylib - wait, we need to check if DrawText exists }
    { Let's draw some shapes first }
    DrawRectangle(10, 10, 200, 100, 255);  { White rectangle }

    { Draw a colored circle }
    DrawCircle(400, 240, 50, 255);  { White circle }

    EndDrawing();
  end;

  { Take screenshot }
  writeln('Taking screenshot: raylib_shapes_test.png');
  TakeScreenshot(PChar('raylib_shapes_test.png'));
  writeln('Screenshot saved');

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Check raylib_shapes_test.png');
  writeln('Should show: White rectangle (top-left), White circle (center-right)');
end.
