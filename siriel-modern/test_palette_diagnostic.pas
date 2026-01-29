program test_palette_diagnostic;

{$mode objfpc}{$H+}

{ Diagnostic test to understand GIF palette issue
  Checks actual RGB values in loaded GIF images
}

uses
  SysUtils,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  blockx,
  geo;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  pixel_data: PByte;
  r, g, b, a: byte;
  x, y, sample_count: integer;
  palette: jxfont_simple.tpalette;
  screenshot_file: string;

begin
  writeln('=== GIF Palette Diagnostic Test ===');
  writeln('');

  { Parse command line }
  if ParamCount >= 1 then
    screenshot_file := ParamStr(1)
  else
    screenshot_file := '';

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  writeln('Screen initialized');
  writeln('');

  { Load GTREEP as test case }
  writeln('[1] Loading GTREEP from SIRIEL35.DAT...');
  if blockx.draw_gif_block(screen_image, 'data/SIRIEL35.DAT', 'GTREEP', 0, 0, palette) then
    writeln('    Loaded: ', blockx.gif_x, 'x', blockx.gif_y)
  else
  begin
    writeln('    ERROR: Failed to load GTREEP');
    Exit;
  end;
  writeln('');

  { Sample pixels at various locations }
  writeln('[2] Sampling RGB values from loaded image...');
  writeln('    Format: Checking 10 sample points');
  writeln('');

  sample_count := 0;
  for y := 0 to 47 do
  begin
    for x := 0 to 63 do
    begin
      if (x mod 10 = 0) and (y mod 20 = 0) and (sample_count < 10) then
      begin
        { Get pixel data directly from screen buffer }
        pixel_data := PByte(screen_image^.data + ((y * SCREEN_WIDTH + x) * 4));

        r := pixel_data^;
        Inc(pixel_data);
        g := pixel_data^;
        Inc(pixel_data);
        b := pixel_data^;
        Inc(pixel_data);
        a := pixel_data^;

        writeln('    Pixel (', x:3, ',', y:3, '): R=', r:3, ' G=', g:3, ' B=', b:3, ' A=', a:3);

        { Check for red tint pattern }
        if (r > 100) and (g < 50) and (b < 50) then
          writeln('      ⚠ WARNING: Red pixel detected! Possible palette issue.')
        else if (r = g) and (g = b) then
          writeln('      ✓ Grayscale pixel')
        else if (r > 200) and (g > 200) and (b > 200) then
          writeln('      ✓ Light pixel')
        else if (r < 50) and (g < 50) and (b < 50) then
          writeln('      ✓ Dark pixel');

        inc(sample_count);
      end;
    end;
  end;
  writeln('');

  { Render and save if requested }
  if screenshot_file <> '' then
  begin
    writeln('[3] Rendering to window...');
    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Palette Diagnostic');

    { Render for 2 seconds }
    for x := 1 to 120 do
    begin
      BeginDrawing();
      ClearBackground(0, 0, 0, 255);
      RenderScreenToWindow();
      EndDrawing();
    end;

    writeln('[4] Saving screenshot: ', screenshot_file);
    TakeScreenshot(PChar(screenshot_file));
    CloseWindow;
    writeln('    Screenshot saved');
  end;

  writeln('');
  writeln('=== Diagnostic Complete ===');
  writeln('');
  writeln('Analysis:');
  writeln('• If you see many red pixels with low G and B values,');
  writeln('  the palette is being misinterpreted as channel-swapped.');
  writeln('• Check the screenshot visually for red tint.');
  writeln('• Compare original GIF if available.');
  writeln('');
end.
