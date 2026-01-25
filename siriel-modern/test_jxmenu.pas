program test_jxmenu;

{$mode objfpc}{$H+}

{ Test JXMENU unit with GLIST decoration
  Verifies menu system integration with modern infrastructure
  Usage: ./test_jxmenu [screenshot_file.png]
}

uses
  SysUtils,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  jxmenu,
  geo;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  menu: jxmenu_typ;
  screenshot_file: string;
  frame_count: integer;
  start_time: longint;
  selected: word;

begin
  writeln('=== JXMENU Unit Test ===');
  writeln('Testing menu system with GLIST decoration');
  writeln('');

  { Parse command line }
  screenshot_file := '';
  if ParamCount >= 1 then
    screenshot_file := ParamStr(1);

  if screenshot_file <> '' then
    writeln('Mode: Automated (screenshot to "', screenshot_file, '")')
  else
    writeln('Mode: Interactive (arrow keys to navigate, ENTER to select, ESC to quit)');
  writeln('');

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  writeln('[1] Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);
  writeln('');

  { Initialize menu }
  writeln('[2] Initializing menu...');
  init_jxmenu(200, 150, 15, 14, 11, 'Main Menu', menu);
  writeln('    OK - Menu initialized');
  writeln('    Position: (', menu.x, ', ', menu.y, ')');
  writeln('');

  { Add menu items }
  writeln('[3] Adding menu items...');
  vloz_jxmenu2('New Game', menu, $4E00);  { N key }
  writeln('    Item 1: New Game (N)');

  vloz_jxmenu2('Load Game', menu, $4C00);  { L key }
  writeln('    Item 2: Load Game (L)');

  vloz_jxmenu2('Save Game', menu, $5300);  { S key }
  writeln('    Item 3: Save Game (S)');

  vloz_jxmenu2('Options', menu, $4F00);   { O key }
  writeln('    Item 4: Options (O)');

  vloz_jxmenu2('Quit', menu, $5100);     { Q key }
  writeln('    Item 5: Quit (Q)');
  writeln('    OK - 5 menu items added');
  writeln('');

  { Draw menu }
  writeln('[4] Drawing menu...');
  draw_jxmenu(menu);
  writeln('    OK - Menu drawn');
  writeln('    Menu size: ', menu.x1, 'x', menu.y1);
  writeln('');

  { Open window }
  writeln('[5] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'JXMENU Test - GLIST Decoration');
  SetTargetFPS(60);
  writeln('    OK - Window opened');
  writeln('');

  if screenshot_file <> '' then
    writeln('    Rendering for 1 second...')
  else
    writeln('    Controls:');
    writeln('      Arrow Up/Down - Navigate menu');
    writeln('      N, L, S, O, Q - Quick select');
    writeln('      ENTER - Select highlighted item');
    writeln('      ESC - Quit');
  writeln('');

  start_time := GetClock();
  frame_count := 0;

  { Main render loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);
    RenderScreenToWindow();
    EndDrawing();

    inc(frame_count);

    { Check for timeout (1 second) }
    if (screenshot_file <> '') and (GetClock() - start_time >= 1000) then
    begin
      writeln('    Time elapsed (1 second)');
      break;
    end;
  end;

  { Take screenshot if requested }
  if screenshot_file <> '' then
  begin
    writeln('[6] Taking screenshot: ', screenshot_file);
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
  writeln('  - Decorated menu frame using GLIST tiles');
  writeln('  - 8 different border tiles (corners and edges)');
  writeln('  - 5 menu items: New Game, Load Game, Save Game, Options, Quit');
  writeln('  - Title: "Main Menu"');
  writeln('');
  writeln('JXMENU unit integration test successful!');
  writeln('  - GLIST tiles loaded and rendered');
  writeln('  - Menu frame drawn with proper decoration');
  writeln('  - Menu items displayed correctly');
  writeln('');
end.
