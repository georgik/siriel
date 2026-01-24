program test_colors;

{$mode objfpc}{$H+}

{ Test color palette mapping from VGA palette indices to RGBA }

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
  x, y, frame: integer;
  color_block_width: integer;

begin
  writeln('=== Color Palette Mapping Test ===');
  writeln('Testing VGA palette index to RGBA conversion');
  writeln('');

  { Initialize Raylib }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Color Test');
  SetTargetFPS(60);

  { Initialize virtual screen }
  writeln('Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);
  writeln('');

  { Calculate block width for 16 colors }
  color_block_width := SCREEN_WIDTH div 16;

  { Draw 16 colored blocks using VGA palette indices }
  writeln('Drawing color test blocks...');
  writeln('Block 0:  Black   (index 0)');
  writeln('Block 1:  Blue    (index 1)');
  writeln('Block 2:  Green   (index 2)');
  writeln('Block 3:  Cyan    (index 3)');
  writeln('Block 4:  Red     (index 4)');
  writeln('Block 5:  Magenta (index 5)');
  writeln('Block 6:  Yellow  (index 6)');
  writeln('Block 7:  White   (index 7)');
  writeln('Block 8:  ...     (index 8-15)');
  writeln('');

  { Clear screen to black first }
  clear_bitmap(screen_image);

  { Draw 16 color blocks }
  for x := 0 to 15 do
  begin
    for y := 0 to 100 do
    begin
      for frame := 0 to color_block_width - 1 do
      begin
        { Use VGA palette index directly - should be converted to full RGBA }
        putpixel(screen_image, x * color_block_width + frame, y + 50, x);
      end;
    end;
  end;

  { Also draw using explicit RGBA for comparison }
  writeln('Drawing RGBA comparison blocks (bottom row)...');

  { Red block using explicit RGBA }
  for y := 200 to 300 do
    for x := 50 to 150 do
      putpixel(screen_image, x, y, (255 shl 24) or (255 shl 16) or (0 shl 8) or 0);

  { Green block using explicit RGBA }
  for y := 200 to 300 do
    for x := 160 to 260 do
      putpixel(screen_image, x, y, (255 shl 24) or (0 shl 16) or (255 shl 8) or 0);

  { Blue block using explicit RGBA }
  for y := 200 to 300 do
    for x := 270 to 370 do
      putpixel(screen_image, x, y, (255 shl 24) or (0 shl 16) or (0 shl 8) or 255);

  { White block using explicit RGBA }
  for y := 200 to 300 do
    for x := 380 to 480 do
      putpixel(screen_image, x, y, (255 shl 24) or (255 shl 16) or (255 shl 8) or 255);

  { Yellow block using explicit RGBA }
  for y := 200 to 300 do
    for x := 490 to 590 do
      putpixel(screen_image, x, y, (255 shl 24) or (255 shl 16) or (255 shl 8) or 0);

  writeln('Starting render loop (will run for 1 second)...');
  writeln('');

  { Render for 1 second (60 frames) }
  for frame := 1 to 60 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);  { Black background }

    { Render our virtual screen }
    RenderScreenToWindow();

    EndDrawing();
  end;

  { Take screenshot }
  writeln('Taking screenshot: color_test.png');
  TakeScreenshot(PChar('color_test.png'));
  writeln('Screenshot saved');

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Check color_test.png');
  writeln('Top row: VGA palette indices 0-15 (may be wrong colors)');
  writeln('Bottom row: Explicit RGBA colors (should be correct)');
  writeln('');
  writeln('If top row is faint/wrong: Palette conversion needed');
  writeln('If bottom row is correct: putpixel/RenderScreenToWindow work');
end.
