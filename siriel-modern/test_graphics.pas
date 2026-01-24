program test_graphics;

{$mode objfpc}{$H+}

uses
  ctypes,
  SysUtils,
  jxgraf,
  animing;

{ Raylib core bindings - not in jxgraf yet }
procedure InitWindow(width, height: cint; title: PChar); cdecl; external;
procedure CloseWindow(); cdecl; external;
function WindowShouldClose(): cint; cdecl; external;
procedure BeginDrawing(); cdecl; external;
procedure EndDrawing(); cdecl; external;
procedure ClearBackground(r, g, b, a: cuchar); cdecl; external;
procedure SetTargetFPS(fps: cint); cdecl; external;
function IsKeyDown(key: cint): cint; cdecl; external;

const
  KEY_ESCAPE = 256;

var
  test_bitmap: PImage;
  test_array: array[0..255] of byte;
  x, y, i: word;

begin
  writeln('=== Siriel Modern - Graphics API Test ===');
  writeln('');
  
  { Initialize window }
  writeln('Step 1: Initializing window...');
  InitWindow(640, 400, 'Siriel Modern - Graphics Test');
  SetTargetFPS(60);
  writeln('  Window opened');
  
  { Create bitmap }
  writeln('');
  writeln('Step 2: Creating test bitmap...');
  test_bitmap := create_bitmap(16, 16);
  writeln('  Created 16x16 bitmap');
  
  { Fill test array with pattern }
  writeln('');
  writeln('Step 3: Creating test pattern...');
  for i := 0 to 255 do
    test_array[i] := i;
  writeln('  Test pattern created');
  
  { Draw using ANIMING functions }
  writeln('');
  writeln('Step 4: Testing putseg...');
  putseg(100, 100, 16, 16, 0, test_array);
  writeln('  putseg at (100, 100)');
  
  { Test transparent blit }
  writeln('');
  writeln('Step 5: Testing putseg2 (transparent)...');
  for i := 0 to 127 do
    test_array[i] := 255; { Half transparent }
  putseg2(150, 100, 16, 16, 0, 255, test_array);
  writeln('  putseg2 at (150, 100) with color 255 as transparent');
  
  { Main loop }
  writeln('');
  writeln('Step 6: Starting main loop...');
  writeln('Press ESC to exit');
  writeln('');
  
  x := 0;
  y := 0;
  
  while not (WindowShouldClose() <> 0) do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);
    
    { Draw test pattern moving }
    putseg(x, y, 16, 16, 0, test_array);
    
    Inc(x);
    if x > 600 then
    begin
      x := 0;
      Inc(y);
      if y > 350 then
        y := 0;
    end;
    
    if IsKeyDown(KEY_ESCAPE) <> 0 then
    begin
      writeln('ESC pressed, exiting...');
      break;
    end;
    
    EndDrawing();
  end;
  
  { Cleanup }
  writeln('');
  writeln('Step 7: Cleaning up...');
  destroy_bitmap(test_bitmap);
  CloseWindow();
  
  writeln('');
  writeln('Test completed successfully!');
end.
