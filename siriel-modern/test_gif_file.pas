program test_gif_file;

{$mode objfpc}{$H+}

{ Test loading GIF file directly using Raylib }

uses
  ctypes,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  SysUtils;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;
  TRANSPARENT_PINK = $FF00FF;  { RGB 255,0,255 }

var
  frame: integer;
  gif_image: TRaylibImage;
  x, y: integer;
  pixel_ptr: PByte;
  r, g, b, a: byte;
  pixel_color: longint;
  has_transparency: boolean;
  transparent_count, opaque_count: integer;

begin
  writeln('=== GIF File Loading Test ===');
  writeln('Loading GLOGO.GIF from data directory');
  writeln('');

  { Initialize Raylib }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'GIF File Loading Test');
  SetTargetFPS(60);

  { Initialize screen }
  writeln('Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);

  { Clear screen }
  clear_bitmap(screen_image);

  { Load GIF file using Raylib }
  writeln('Loading GLOGO.GIF...');
  gif_image := LoadImage('data/GLOGO.GIF');

  if gif_image.data = nil then
  begin
    writeln('ERROR: Failed to load GLOGO.GIF');
    writeln('Please make sure the file exists in the data directory');
    CloseWindow;
    Exit;
  end;

  writeln('GIF loaded successfully!');
  writeln('  Dimensions: ', gif_image.width, 'x', gif_image.height);
  writeln('  Format: RGBA (', gif_image.width * gif_image.height * 4, ' bytes)');
  writeln('');

  { Draw GIF to our virtual screen }
  writeln('Drawing GIF to virtual screen...');
  writeln('Position: centered at (', (SCREEN_WIDTH - gif_image.width) div 2, ', ', (SCREEN_HEIGHT - gif_image.height) div 2, ')');
  writeln('');

  pixel_ptr := PByte(gif_image.data);
  has_transparency := false;
  transparent_count := 0;
  opaque_count := 0;

  { First pass: analyze colors }
  writeln('Analyzing GIF colors (showing first 20 pixels)...');
  for y := 0 to gif_image.height - 1 do
  begin
    for x := 0 to gif_image.width - 1 do
    begin
      { Read RGBA from Raylib }
      r := pixel_ptr^;
      Inc(pixel_ptr);
      g := pixel_ptr^;
      Inc(pixel_ptr);
      b := pixel_ptr^;
      Inc(pixel_ptr);
      a := pixel_ptr^;
      Inc(pixel_ptr);

      { Show first few pixels }
      if (y * gif_image.width + x) < 20 then
        writeln('  Pixel (', x, ',', y, '): RGBA(', r, ',', g, ',', b, ',', a, ')');

      { Check for transparent pink shades }
      { Pure pink: RGB(255, 0, 255) }
      { Magenta-like in GIF: RGB(252, 84, 252) }
      { Use a range to catch similar pink/magenta shades }
      if (r >= 250) and (r <= 255) and (g >= 0) and (g <= 100) and (b >= 250) and (b <= 255) then
      begin
        Inc(transparent_count);
        if transparent_count <= 5 then
          writeln('  Pink/magenta pixel at (', x, ',', y, ') RGB(', r, ',', g, ',', b, ')');
      end
      else if a = 0 then
      begin
        { Also check for alpha = 0 (fully transparent) }
        Inc(transparent_count);
        if transparent_count <= 5 then
          writeln('  Transparent pixel (alpha=0) at (', x, ',', y, ')');
      end
      else
        Inc(opaque_count);
    end;
  end;
  writeln('Total pixels: ', gif_image.width * gif_image.height);
  writeln('  Transparent (pink/magenta or alpha=0): ', transparent_count);
  writeln('  Opaque: ', opaque_count);
  writeln('');

  { Second pass: draw non-pink pixels }
  pixel_ptr := PByte(gif_image.data);
  for y := 0 to gif_image.height - 1 do
  begin
    for x := 0 to gif_image.width - 1 do
    begin
      { Read RGBA from Raylib }
      r := pixel_ptr^;
      Inc(pixel_ptr);
      g := pixel_ptr^;
      Inc(pixel_ptr);
      b := pixel_ptr^;
      Inc(pixel_ptr);
      a := pixel_ptr^;
      Inc(pixel_ptr);

      { Check for transparent pink/magenta shades or alpha=0 }
      if ((r >= 250) and (r <= 255) and (g >= 0) and (g <= 100) and (b >= 250) and (b <= 255)) or (a = 0) then
      begin
        { Skip transparent pixels }
        has_transparency := true;
      end
      else
      begin
        { Draw opaque pixel }
        pixel_color := (a shl 24) or (r shl 16) or (g shl 8) or b;
        putpixel(screen_image,
                (SCREEN_WIDTH - gif_image.width) div 2 + x,
                (SCREEN_HEIGHT - gif_image.height) div 2 + y,
                pixel_color);
      end;
    end;
  end;

  if has_transparency then
    writeln('Transparency detected: ', transparent_count, ' pink pixels skipped, ', opaque_count, ' opaque pixels drawn')
  else
    writeln('No transparent pink pixels found (', opaque_count, ' pixels drawn)');

  { Unload GIF image }
  UnloadImage(gif_image);

  { Add test text }
  writeln('');
  writeln('Drawing test text...');
  print_normal(screen_image, 10, 450, 'GIF File Loading Test - GLOGO.GIF', 15, 0);

  { Render for 3 seconds (180 frames) }
  writeln('');
  writeln('Starting render loop (will run for 3 seconds)...');
  writeln('');

  for frame := 1 to 180 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);  { Black background }

    { Render our virtual screen }
    RenderScreenToWindow();

    EndDrawing();
  end;

  { Take screenshot }
  writeln('Taking screenshot: gif_file_test.png');
  TakeScreenshot(PChar('gif_file_test.png'));
  writeln('Screenshot saved');

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Check gif_file_test.png for the loaded GLOGO');
end.
