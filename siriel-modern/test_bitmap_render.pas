program test_bitmap_render;

{$mode objfpc}{$H+}

{ Test RenderScreenToWindow() with a simple bitmap }

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
  red_color, white_color: longint;

begin
  writeln('=== Bitmap Render Test ===');
  writeln('Testing RenderScreenToWindow() with a colored bitmap');
  writeln('');

  { Initialize Raylib }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Bitmap Render Test');
  SetTargetFPS(60);

  { Create a test bitmap }
  test_bitmap := create_bitmap(SCREEN_WIDTH, SCREEN_HEIGHT);
  writeln('Test bitmap created: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);

  { Fill bitmap with red and draw a white rectangle }
  red_color := (255 shl 24) or (255 shl 16) or (0 shl 8) or 0;    { Full alpha, Red }
  white_color := (255 shl 24) or (255 shl 16) or (255 shl 8) or 255; { Full alpha, White }

  writeln('Filling bitmap with red color...');

  for y := 0 to SCREEN_HEIGHT - 1 do
  begin
    for x := 0 to SCREEN_WIDTH - 1 do
    begin
      putpixel(test_bitmap, x, y, red_color);
    end;
  end;

  writeln('Drawing white rectangle in center...');

  { Draw a white rectangle in the center }
  for y := 200 to 279 do
  begin
    for x := 270 to 369 do
    begin
      putpixel(test_bitmap, x, y, white_color);
    end;
  end;

  writeln('Bitmap prepared with red background and white center rect');
  writeln('');
  writeln('Starting render loop (will run for 1 second)...');
  writeln('');

  { Render for 1 second (60 frames) }
  for frame := 1 to 60 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);  { Black background }

    { Render our bitmap using RenderScreenToWindow }
    { First, manually copy our test_bitmap to screen_image }
    for y := 0 to SCREEN_HEIGHT - 1 do
    begin
      for x := 0 to SCREEN_WIDTH - 1 do
      begin
        putpixel(PImage(screen), x, y, getpixel(test_bitmap, x, y));
      end;
    end;

    { Now use RenderScreenToWindow to display it }
    RenderScreenToWindow();

    EndDrawing();
  end;

  { Take screenshot }
  writeln('Taking screenshot: bitmap_render_test.png');
  TakeScreenshot(PChar('bitmap_render_test.png'));
  writeln('Screenshot saved');

  { Cleanup }
  destroy_bitmap(test_bitmap);
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Check bitmap_render_test.png');
  writeln('If it''s BLACK: RenderScreenToWindow is not working');
  writeln('If it''s RED with WHITE center: RenderScreenToWindow works!');
end.
