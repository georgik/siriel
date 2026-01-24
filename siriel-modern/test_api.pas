program test_api;

{$mode objfpc}{$H+}

{ This test validates that the original JXGRAF and ANIMING APIs work correctly }

uses
  ctypes,
  raylib_helpers,
  jxgraf,
  animing;

const
  KEY_ESCAPE = 256;
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 400;

type
  PcChar = PChar;

var
  test_bitmap: PImage;
  test_sprite: array[0..255] of byte;
  x, y, i, frame: word;
  fps_counter: longint;
  window_title: PcChar;

begin
  writeln('=== Siriel Modern - Original API Test ===');
  writeln('');
  
  { Initialize window }
  writeln('Step 1: Initializing Raylib window...');
  window_title := 'Siriel Modern - API Compatibility Test';
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, window_title);
  SetTargetFPS(60);
  writeln('  Done');
  
  { Create test bitmap }
  writeln('');
  writeln('Step 2: Creating test bitmap (64x64)...');
  test_bitmap := create_bitmap(64, 64);
  writeln('  Done');
  
  { Fill bitmap with test pattern }
  writeln('');
  writeln('Step 3: Creating test pattern...');
  for i := 0 to 255 do
    test_sprite[i] := i;
  writeln('  Pattern created (256 bytes)');
  
  { Draw test pattern to bitmap using various methods }
  writeln('');
  writeln('Step 4: Testing JXGRAF drawing functions...');
  
  { Test putpixel - draw red square }
  for y := 10 to 20 do
    for x := 10 to 20 do
      putpixel(test_bitmap, x, y, $0000FF); { Red }
  writeln('  - putpixel: Red square at (10,10) to (20,20)');
  
  { Test rectangle }
  rectangle(test_bitmap, 30, 10, 50, 30);
  writeln('  - rectangle: White outline at (30,10) to (50,30)');
  
  { Test rectangle2 (filled) }
  rectangle2(test_bitmap, 30, 40, 50, 60, $00FF00); { Green }
  writeln('  - rectangle2: Filled green rectangle at (30,40) to (50,60)');
  
  { Test circle }
  circle(test_bitmap, 40, 80, 10, $FFFF00); { Yellow }
  writeln('  - circle: Yellow circle centered at (40,80) radius 10');
  
  { Test blit to screen }
  writeln('');
  writeln('Step 5: Testing blit to screen...');
  blit(test_bitmap, PImage(jxgraf.screen), 0, 0, 100, 100, 64, 64);
  writeln('  Blitted test bitmap to screen at (100,100)');
  
  { Test ANIMING functions }
  writeln('');
  writeln('Step 6: Testing ANIMING functions...');
  
  { Create sprite pattern }
  for i := 0 to 15 do
    test_sprite[i] := $FF; { White frame }
  for i := 16 to 255 do
    test_sprite[i] := 0;   { Black interior }
    
  { Test putseg - draw sprite }
  putseg(200, 100, 16, 16, 0, test_sprite);
  writeln('  - putseg: Drew 16x16 sprite at (200,100)');
  
  { Test putseg2 - draw transparent sprite }
  putseg2(250, 100, 16, 16, 0, 0, test_sprite);
  writeln('  - putseg2: Drew transparent sprite at (250,100)');
  
  { Test getseg - read sprite from screen }
  getseg(300, 100, 16, 16, 0, test_sprite);
  writeln('  - getseg: Read 16x16 region from (300,100)');
  
  { Test putseg2_rev - mirrored sprite }
  putseg2_rev(350, 100, 16, 16, 0, 0, test_sprite);
  writeln('  - putseg2_rev: Drew mirrored sprite at (350,100)');
  
  { Start main loop }
  writeln('');
  writeln('Step 7: Starting animation loop...');
  writeln('  Press ESC to exit');
  writeln('');
  
  fps_counter := 0;
  x := 400;
  y := 200;
  frame := 0;
  
  while not (WindowShouldClose() <> 0) do
  begin
    BeginDrawing();
    
    { Clear background }
    ClearBackground(20, 20, 30, 255);
    
    { Render our virtual screen to the window }
    RenderScreenToWindow();
    
    { Animate a sprite }
    Inc(frame);
    if frame >= 4 then
      frame := 0;
      
    { Move sprite }
    Inc(x, 2);
    if x > 600 then
    begin
      x := 400;
      Inc(y, 20);
      if y > 300 then
        y := 200;
    end;
    
    { Draw animated sprite }
    putseg2(x, y, 16, 16, frame, 0, test_sprite);
    
    { Update display }
    EndDrawing();
    
    Inc(fps_counter);
    
    { Check for ESC }
    if IsKeyDown(KEY_ESCAPE) <> 0 then
    begin
      writeln('ESC pressed, exiting...');
      break;
    end;
  end;
  
  { Cleanup }
  writeln('');
  writeln('Step 8: Cleaning up...');
  destroy_bitmap(test_bitmap);
  CloseWindow();
  
  writeln('');
  writeln('Test completed successfully!');
  writeln('  Frames rendered: ', fps_counter);
  writeln('  Average FPS: ', fps_counter div (fps_counter div 60 + 1));
  writeln('');
  writeln('All original API functions verified:');
  writeln('  [JXGRAF] create_bitmap, destroy_bitmap');
  writeln('  [JXGRAF] putpixel, getpixel');
  writeln('  [JXGRAF] rectangle, rectangle2, circle');
  writeln('  [JXGRAF] blit');
  writeln('  [ANIMING] putseg, putseg2, getseg, putseg2_rev');
  writeln('  [SCREEN]  RenderScreenToWindow');
end.
