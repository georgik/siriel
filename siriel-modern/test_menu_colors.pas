program test_menu_colors;

{$mode objfpc}{$H+}

{ Test menu colors and background image loading
  Usage: ./test_menu_colors [screenshot_file.png]
}

uses
  SysUtils,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  jxmenu,
  blockx,
  geo;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  menu: jxmenu_typ;
  screenshot_file: string;
  frame_count: integer;
  start_time: longint;
  background_loaded: boolean;
  font_pal: jxfont_simple.tpalette;
  test_duration_ms: longint;

begin
  writeln('=== Menu Color Test ===');
  writeln('Testing menu with background image and proper colors');
  writeln('');

  { Parse command line }
  screenshot_file := '';
  test_duration_ms := 2000;  { Default 2 seconds }
  if ParamCount >= 1 then
  begin
    screenshot_file := ParamStr(1);
    if ParamCount >= 2 then
      test_duration_ms := StrToIntDef(ParamStr(2), 2000);
  end;

  if screenshot_file <> '' then
    writeln('Mode: Automated (screenshot to "', screenshot_file, '")')
  else
    writeln('Mode: Interactive (ESC to quit)');
  writeln('');

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  writeln('[1] Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);
  writeln('');

  { Clear screen and try to load background }
  clear_bitmap(screen_image);
  writeln('[2] Loading background image from SIRIEL35.DAT...');

  background_loaded := blockx.draw_gif_block(screen_image, 'data/SIRIEL35.DAT', 'GTREEP', 0, 0, font_pal);
  if not background_loaded then
  begin
    writeln('    GTREEP not found, trying GTEXT...');
    background_loaded := blockx.draw_gif_block(screen_image, 'data/SIRIEL35.DAT', 'GTEXT', 0, 0, font_pal);
  end;

  if background_loaded then
    writeln('    OK - Background loaded: ', blockx.gif_x, 'x', blockx.gif_y)
  else
    writeln('    WARNING - No background found');

  { Initialize graphical menu - using original structure }
  writeln('[3] Initializing menu...');
  init_jxmenu(200, 40, 0, 15, 0, 'Select DATADISK', menu);
  size_jxmenu(192, 288, menu);
  writeln('    OK - Menu initialized');
  writeln('    Position: (', menu.x, ', ', menu.y, ')');
  writeln('    Size: ', menu.x1, 'x', menu.y1);
  writeln('');

  { Add menu items }
  writeln('[4] Adding menu items...');
  vloz_jxmenu2('SIRIEL 3.5', menu, 0);
  writeln('    Item 1: SIRIEL 3.5');
  vloz_jxmenu2('Quit', menu, 0);
  writeln('    Item 2: Quit');
  writeln('    OK - 2 menu items added');
  writeln('');

  { Draw menu }
  writeln('[5] Drawing menu...');
  draw_jxmenu(menu);
  writeln('    OK - Menu drawn');
  writeln('');

  { Open window }
  writeln('[6] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Menu Color Test - SIRIEL 3.5');
  SetTargetFPS(60);
  writeln('    OK - Window opened');
  writeln('');

  if screenshot_file <> '' then
    writeln('    Rendering for ', test_duration_ms div 1000, ' second(s)...')
  else
    writeln('    Press ESC to quit');
  writeln('');

  start_time := GetClock();
  frame_count := 0;

  { Main render loop }
  while WindowShouldClose() = 0 do
  begin
    { Check for timeout }
    if (screenshot_file <> '') and (GetClock() - start_time >= test_duration_ms) then
    begin
      writeln('    Time elapsed (', test_duration_ms div 1000, ' second(s))');
      break;
    end;

    BeginDrawing();
    ClearBackground(0, 0, 0, 255);
    RenderScreenToWindow();
    EndDrawing();

    inc(frame_count);
  end;

  { Take screenshot if requested }
  if screenshot_file <> '' then
  begin
    writeln('[7] Taking screenshot: ', screenshot_file);
    TakeScreenshot(PChar(screenshot_file));
    writeln('    OK - Screenshot saved');
  end;

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Frames rendered: ', frame_count);
  if screenshot_file <> '' then
    writeln('Screenshot: ', screenshot_file);
  writeln('');
  writeln('You should see:');
  writeln('  - Background image with correct colors (no red tint)');
  writeln('  - Fancy menu frame using GLIST tiles');
  writeln('  - White menu text on dark background');
  writeln('  - Menu at (', menu.x, ', ', menu.y, ')');
  writeln('  - Title: "Select DATADISK"');
  writeln('  - 2 menu items: "SIRIEL 3.5" and "Quit"');
  writeln('');
end.
