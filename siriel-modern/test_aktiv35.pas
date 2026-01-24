program test_aktiv35;

{$mode objfpc}{$H+}

uses
  ctypes,
  SysUtils,
  jxvar,
  aktiv35;

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
  frame_count: longint;
  test_obj: predmet;
  test_room: prechod;
  i: integer;

begin
  writeln('=== Siriel Modern - AKTIV35.PAS Test ===');
  writeln('');
  
  { Initialize AKTIV35 }
  writeln('Step 1: Initializing AKTIV35 unit...');
  InitAktiv35;
  writeln('  ✓ InitAktiv35 completed');
  
  { Test data structures }
  writeln('');
  writeln('Step 2: Testing data structures...');
  
  { Create a test object }
  test_obj.meno := 'TEST';
  test_obj.x := 100;
  test_obj.y := 200;
  test_obj.visible := True;
  for i := 0 to 255 do
    test_obj.zas[i] := i mod 256;
  
  writeln('  ✓ predmet structure initialized');
  writeln('    - meno: ', test_obj.meno);
  writeln('    - position: (', test_obj.x, ', ', test_obj.y, ')');
  writeln('    - visible: ', test_obj.visible);
  
  { Create a test room transition }
  test_room.x1 := 10;
  test_room.y1 := 10;
  test_room.x2 := 50;
  test_room.y2 := 50;
  test_room.mie1 := 1;
  test_room.mie2 := 2;
  test_room.cx := 320;
  test_room.cy := 200;
  test_room.used := False;
  
  writeln('  ✓ prechod (room transition) structure initialized');
  writeln('    - room 1 to room 2');
  writeln('    - boundary: (', test_room.x1, ',', test_room.y1, ') to (',
            test_room.x2, ',', test_room.y2, ')');
  writeln('    - target position: (', test_room.cx, ',', test_room.cy, ')');
  
  { Test constants }
  writeln('');
  writeln('Step 3: Testing constants...');
  writeln('  - VERSION: ', VERSION);
  writeln('  - mie_x: ', mie_x, ' (room width)');
  writeln('  - mie_y: ', mie_y, ' (room height)');
  writeln('  - pocet_veci: ', pocet_veci, ' (max objects)');
  writeln('  - anim_nums: ', anim_nums, ' (animation slots)');
  writeln('  - max_prechod: ', max_prechod, ' (max transitions)');
  writeln('  - max_vytahy: ', max_vytahy, ' (max elevators)');
  
  { Test memory allocation }
  writeln('');
  writeln('Step 4: Testing memory allocation...');
  New(vec);
  writeln('  ✓ Allocated vec pointer (', pocet_veci, ' items capacity)');

  New(priechody);
  writeln('  ✓ Allocated priechody pointer (', max_prechod, ' transitions capacity)');
  
  { Initialize window }
  writeln('');
  writeln('Step 5: Initializing Raylib...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Siriel Modern - AKTIV35 Test');
  SetTargetFPS(60);
  writeln('  ✓ Window opened: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);
  
  { Main loop }
  writeln('');
  writeln('Step 6: Starting main loop...');
  writeln('Press ESC to exit');
  writeln('');
  
  frame_count := 0;
  
  while not (WindowShouldClose() <> 0) do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);
    
    Inc(frame_count);
    
    { Exit on ESC }
    if IsKeyDown(KEY_ESCAPE) <> 0 then
    begin
      writeln('ESC pressed, exiting...');
      break;
    end;
    
    EndDrawing();
    
    { Print status every 60 frames }
    if frame_count mod 60 = 0 then
    begin
      writeln('Frame: ', frame_count, ' | FPS: ', GetFPS);
    end;
  end;
  
  { Cleanup }
  writeln('');
  writeln('Step 7: Cleaning up...');
  CloseWindow();
  
  writeln('');
  writeln('✅ AKTIV35.PAS test completed successfully!');
  writeln('');
  writeln('Verified:');
  writeln('  - All data structures compile correctly');
  writeln('  - Constants are accessible');
  writeln('  - Memory allocation works');
  writeln('  - Initialization successful');
  writeln('  - Total frames rendered: ', frame_count);
end.
