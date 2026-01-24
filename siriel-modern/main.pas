program siriel;

{$mode objfpc}{$H+}

uses
  ctypes;

{ Raylib bindings - minimal set for Phase 1 test }
procedure InitWindow(width: cint; height: cint; title: PChar); cdecl; external;
procedure CloseWindow(); cdecl; external;
function WindowShouldClose(): cint; cdecl; external;
procedure BeginDrawing(); cdecl; external;
procedure EndDrawing(); cdecl; external;
procedure ClearBackground(r, g, b, a: cuchar); cdecl; external;
function GetFPS(): cint; cdecl; external;
procedure SetTargetFPS(fps: cint); cdecl; external;
function IsKeyDown(key: cint): cint; cdecl; external;
function GetCharPressed(): cint; cdecl; external;

{ Key codes }
const
  KEY_ESCAPE = 256;
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 400;

var
  fps: cint;

begin
  writeln('=== Siriel Modern - Phase 1 Test ===');
  writeln('Initializing Raylib...');
  
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Siriel Modern - Phase 1 Test');
  SetTargetFPS(60);
  
  writeln('Window opened successfully!');
  writeln('Press ESC to exit');
  writeln('');
  
  while not (WindowShouldClose() <> 0) do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);
    
    { Draw FPS counter }
    fps := GetFPS();
    // TODO: Add text rendering when SRFONT is implemented
    
    { Check for ESC key }
    if IsKeyDown(KEY_ESCAPE) <> 0 then
    begin
      writeln('ESC pressed, exiting...');
      break;
    end;
    
    EndDrawing();
  end;
  
  CloseWindow();
  writeln('');
  writeln('✅ Phase 1 test completed successfully!');
end.
