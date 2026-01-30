program test_rgba_formats;

{$mode objfpc}{$H+}

{ Test VGA palette colors directly
  Uses palette indices, not RGBA values
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
  x, y: word;
  color_idx: byte;
  r, g, b: byte;
  label_str: string;
begin
  writeln('=== VGA Palette Color Test ===');
  writeln('');

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'VGA Palette Test');
  SetTargetFPS(60);

  { Initialize VGA palette }
  jxgraf.fill_palette_default;
  writeln('VGA palette initialized');
  writeln('');

  { Clear screen to black }
  clear_bitmap(screen_image);

  { Display palette colors 0-15 }
  y := 50;
  for color_idx := 0 to 15 do
  begin
    x := 50 + (color_idx * 35);

    { Draw rectangle using palette index }
    rectangle2(screen_image, x, y, 30, 30, color_idx);

    { Display the color number below }
    str(color_idx, label_str);
    print_normal(screen_image, x + 5, y + 35, label_str, 15, 0);
  end;

  { Display color names }
  y := 130;
  print_normal(screen_image, 50, y, 'VGA Palette 0-15:', 15, 0);
  inc(y, 30);
  print_normal(screen_image, 50, y, '0=Black 1=Blue 2=Green 3=Cyan', 14, 0);
  inc(y, 20);
  print_normal(screen_image, 50, y, '4=Red 5=Magenta 6=Brown 7=Gray', 14, 0);
  inc(y, 20);
  print_normal(screen_image, 50, y, '8=DGray 9=LBlu 10=LGrn 11=LCyan', 14, 0);
  inc(y, 20);
  print_normal(screen_image, 50, y, '12=LRed 13=LMag 14=Yell 15=White', 14, 0);

  { Show expected values for Yellow (color 14) }
  inc(y, 40);
  print_normal(screen_image, 50, y, 'Color 14 should be YELLOW (R=252, G=252, B=84)', 15, 0);
  inc(y, 20);
  print_normal(screen_image, 50, y, 'Color 15 should be WHITE', 14, 0);

  { Render for 3 seconds }
  writeln('[1] Rendering for 3 seconds...');
  for x := 1 to 180 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);
    RenderScreenToWindow();
    EndDrawing();
    Sleep(16);
  end;

  writeln('[2] Saving screenshot: vga_palette_test.png');
  TakeScreenshot(PChar('vga_palette_test.png'));
  writeln('    Screenshot saved');

  CloseWindow;
  writeln('');
  writeln('Test complete.');
  writeln('');
  writeln('Check screenshot: Color 14 should be YELLOW');
  writeln('Check screenshot: Color 15 should be WHITE');
  writeln('Check screenshot: Color 1 should be BLUE');
  writeln('Check screenshot: Color 2 should be GREEN');
  writeln('');
end.
