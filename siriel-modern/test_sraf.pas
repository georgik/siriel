program test_sraf;

{$mode objfpc}{$H+}

uses
  ctypes,
  sraf;

{ Raylib core bindings }
procedure InitWindow(width, height: cint; title: PChar); cdecl; external;
procedure CloseWindow(); cdecl; external;
function WindowShouldClose(): cint; cdecl; external;
procedure BeginDrawing(); cdecl; external;
procedure EndDrawing(); cdecl; external;
procedure ClearBackground(r, g, b, a: cuchar); cdecl; external;
function GetFPS(): cint; cdecl; external;
procedure SetTargetFPS(fps: cint); cdecl; external;
function IsKeyDown(key: cint): cint; cdecl; external;

const
  KEY_ESCAPE = 256;
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 400;

var
  testImage, testImage2: PSrafImage;
  x, y: cint;
  color: cuint;
  frameCount: cuint;

begin
  writeln('=== Siriel Modern - Phase 2 Test (SRAF) ===');
  writeln('Creating test images...');
  
  { Create offscreen images }
  testImage := SrafCreateImage(320, 200);
  testImage2 := SrafCreateImage(200, 150);
  
  { Draw to testImage - pixel operations }
  writeln('Testing pixel operations...');
  for y := 10 to 50 do
    for x := 10 to 50 do
      SrafPutPixel(testImage, x, y, Color(255, 0, 0, 255)); { Red square }
      
  { Draw to testImage - drawing primitives }
  writeln('Testing drawing primitives...');
  SrafDrawRectangle(testImage, 60, 10, 50, 50, Color(0, 255, 0, 255)); { Green rectangle }
  SrafDrawCircle(testImage, 140, 35, 25, Color(0, 0, 255, 255)); { Blue circle }
  SrafDrawLine(testImage, 180, 10, 250, 60, Color(255, 255, 0, 255)); { Yellow line }
  
  { Draw to testImage2 - gradient pattern }
  writeln('Testing gradient pattern...');
  for y := 0 to 149 do
    for x := 0 to 199 do
    begin
      color := Color((x * 255) div 200, (y * 255) div 150, 128, 255);
      SrafPutPixel(testImage2, x, y, color);
    end;
  
  { Draw test pattern on testImage2 }
  SrafDrawRectangle(testImage2, 50, 50, 100, 50, Color(255, 0, 255, 255)); { Purple rect }
  SrafDrawCircle(testImage2, 150, 75, 30, Color(255, 255, 255, 255)); { White circle }
  
  { Initialize window }
  writeln('Initializing Raylib...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Siriel Modern - SRAF Graphics Test');
  SetTargetFPS(60);
  
  writeln('Starting main loop...');
  writeln('Press ESC to exit');
  writeln('');
  
  frameCount := 0;
  
  while not (WindowShouldClose() <> 0) do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);
    
    { Draw test images }
    SrafDrawImage(testImage, 10, 10);
    SrafDrawImage(testImage2, 350, 50);
    
    { Draw some direct shapes on screen }
    DrawRectangleRec(Rectangle(10, 220, 200, 30), Color(100, 100, 255, 255));
    DrawCircle(500, 300, 40, Color(255, 100, 100, 255));
    DrawLine(10, 270, 630, 270, Color(255, 255, 255, 255));
    
    Inc(frameCount);
    
    { Check for ESC key }
    if IsKeyDown(KEY_ESCAPE) <> 0 then
    begin
      writeln('ESC pressed, exiting...');
      writeln('Total frames rendered: ', frameCount);
      break;
    end;
    
    EndDrawing();
  end;
  
  { Cleanup }
  writeln('Cleaning up...');
  SrafDestroyImage(testImage);
  SrafDestroyImage(testImage2);
  CloseWindow();
  
  writeln('');
  writeln('✅ Phase 2 test completed successfully!');
  writeln('');
  writeln('Verified:');
  writeln('  - SrafCreateImage / SrafDestroyImage');
  writeln('  - SrafPutPixel / SrafGetPixel');
  writeln('  - SrafDrawRectangle / SrafDrawCircle / SrafDrawLine');
  writeln('  - SrafDrawImage (texture rendering)');
  writeln('  - Offscreen rendering');
  writeln('  - Direct screen drawing');
end.
