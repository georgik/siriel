program test_color_channels;

{$mode objfpc}{$H+}

{ Test to check if RGB channels are swapped
  Displays VGA palette colors with normal and swapped channels
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
  label_text: string;
begin
  writeln('=== RGB Channel Swap Test ===');
  writeln('');

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'RGB Channel Test');
  SetTargetFPS(60);

  { Initialize VGA palette }
  jxgraf.fill_palette_default;
  writeln('VGA palette initialized');
  writeln('');

  { Clear screen }
  clear_bitmap(screen_image);

  { Display top 16 VGA colors in two rows }
  writeln('[1] Top row: Normal RGBA (Red in high byte)');
  writeln('[2] Bottom row: Swapped RGBA (Blue in high byte)');
  writeln('');

  { Top row: Normal channel order }
  for color_idx := 0 to 15 do
  begin
    x := color_idx * 40;
    y := 100;

    { Get color values from palette }
    r := current_palette[color_idx].r shl 2;
    g := current_palette[color_idx].v shl 2;
    b := current_palette[color_idx].b shl 2;

    { Normal RGBA: 0xAA RR GG BB }
    rectangle2(screen_image, x, y, 40, 40, (255 shl 24) or (longint(r) shl 16) or (longint(g) shl 8) or b);

    { Label }
    str(color_idx, label_text);
    print_normal(screen_image, x + 5, y + 45, label_text, 15, 0);
  end;

  { Bottom row: Swapped channel order (swap R and B) }
  for color_idx := 0 to 15 do
  begin
    x := color_idx * 40;
    y := 200;

    { Get color values from palette }
    r := current_palette[color_idx].r shl 2;
    g := current_palette[color_idx].v shl 2;
    b := current_palette[color_idx].b shl 2;

    { Swapped RGBA: 0xAA BB GG RR (R and B swapped) }
    rectangle2(screen_image, x, y, 40, 40, (255 shl 24) or (longint(b) shl 16) or (longint(g) shl 8) or r);

    { Label }
    str(color_idx, label_text);
    print_normal(screen_image, x + 5, y + 45, label_text, 15, 0);
  end;

  { Display color names for reference }
  y := 300;
  print_normal(screen_image, 10, y, 'Normal: 0=Black 1=Blue 2=Green 3=Cyan 4=Red 5=Magenta 6=Brown 7=Gray', 14, 0);
  print_normal(screen_image, 10, y + 20, '       8=DGray 9=LBlu 10=LGrn 11=LCyan 12=LRed 13=LMag 14=Yell 15=White', 14, 0);

  print_normal(screen_image, 10, y + 60, 'Top row should show: Black Blue Green Cyan Red Magenta Brown Gray...', 15, 0);
  print_normal(screen_image, 10, y + 80, '                    DarkGra LtBlu LtGrn LtCyan LtRed LtMag Yellow White', 15, 0);

  print_normal(screen_image, 10, y + 120, 'Color 14 (Yellow) should be YELLOW (R=255, G=255, B=0)', 14, 0);

  { Render for 2 seconds then save screenshot }
  writeln('[3] Rendering for 2 seconds...');
  for x := 1 to 120 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);
    RenderScreenToWindow();
    EndDrawing();
    Sleep(16);
  end;

  writeln('[4] Saving screenshot: color_channels_test.png');
  TakeScreenshot(PChar('color_channels_test.png'));
  writeln('    Screenshot saved');

  CloseWindow;
  writeln('');
  writeln('Test complete. Check which row shows correct colors.');
  writeln('• If top row looks correct: channels are normal (RR GG BB)');
  writeln('• If bottom row looks correct: channels are swapped (BB GG RR)');
  writeln('');
end.
