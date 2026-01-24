program test_simple;

{$mode objfpc}{$H+}

uses
  ctypes,
  raylib_helpers,
  jxgraf,
  SysUtils;

type
  PcChar = PChar;

const
  KEY_ESCAPE = 256;

var
  i: integer;

begin
  writeln('=== Simple Render Test ===');
  
  InitWindow(640, 400, 'Simple Test');
  SetTargetFPS(60);
  
  { Draw some test patterns directly to screen }
  putpixel(PImage(jxgraf.screen), 100, 100, $0000FF);  { Red }
  putpixel(PImage(jxgraf.screen), 110, 100, $00FF00);  { Green }
  putpixel(PImage(jxgraf.screen), 120, 100, $0000FF);  { Blue }
  
  rectangle2(PImage(jxgraf.screen), 50, 50, 100, 100, $FFFF00); { Yellow rect }
  circle(PImage(jxgraf.screen), 320, 200, 50, $FF00FF); { Purple circle }
  
  writeln('Starting render loop, press ESC to exit...');
  
  i := 0;
  while not (WindowShouldClose() <> 0) do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);
    
    { Render our virtual screen }
    RenderScreenToWindow();
    
    Inc(i);
    if IsKeyDown(KEY_ESCAPE) <> 0 then
    begin
      writeln('ESC pressed, exiting after ', i, ' frames');
      break;
    end;
    
    EndDrawing();
  end;
  
  CloseWindow();
  writeln('Test completed successfully!');
end.
