program test_geo;

{$mode objfpc}{$H+}

uses
  geo;

var
  x, y: integer;
  kluc: word;
  clock_val: longint;
  frame_count: longint;

begin
  writeln('=== Siriel Modern - GEO.PAS Test ===');
  writeln('Initializing graphics system...');
  
  { Initialize graphics }
  grafika_init(640, 400, 32);
  
  writeln('Starting main loop...');
  writeln('Use arrow keys to move, ESC to exit');
  writeln('');
  
  x := 320;
  y := 200;
  frame_count := 0;
  
  while not (WindowShouldClose() <> 0) do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);
    
    { Update input using GEO functions }
    sipky(x, y, kluc);
    
    { Draw position indicator }
    { Note: Would use SRAF here, but for now we just clear screen }
    
    { Exit on ESC }
    if IsKeyDown(KEY_ESCAPE) <> 0 then
    begin
      writeln('ESC pressed, exiting...');
      break;
    end;
    
    EndDrawing();
    
    inc(frame_count);
    
    { Print status every 60 frames }
    if frame_count mod 60 = 0 then
    begin
      clock_val := GetClock;
      writeln('Position: (', x, ', ', y, ') Clock: ', clock_val, ' Frame: ', frame_count);
    end;
  end;
  
  CloseWindow();
  
  writeln('');
  writeln('✅ GEO.PAS test completed successfully!');
  writeln('Total frames rendered: ', frame_count);
end.
