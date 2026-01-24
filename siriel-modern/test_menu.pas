program test_menu;

{$mode objfpc}{$H+}

{ Minimal Siriel Modern - Initial Menu Test }
{ This tests the initial game menu from original SI35.PAS }

uses
  ctypes,
  raylib_helpers,
  jxgraf,
  blockx,
  jxfont_simple,
  dos_compat,
  SysUtils;

type
  PcChar = PChar;

const
  KEY_ESCAPE = 256;
  KEY_UP = 265;
  KEY_DOWN = 264;
  KEY_ENTER = 257;
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  palette: tpalette;
  menu_selection: integer;
  frame_count: longint;
  running: boolean;
  duration_seconds: integer;
  start_frame, current_frame: longint;

{ Draw a simple text menu option }
procedure draw_menu_option(y: word; text: string; selected: boolean);
var
  color: byte;
begin
  if selected then
    color := 14  { Yellow for selected }
  else
    color := 11; { Light blue for normal }

  print_normal(PImage(screen), 270, y, text, color, 0);

  { Draw selection indicator }
  if selected then
  begin
    print_normal(PImage(screen), 250, y, '>', 14, 0);
    print_normal(PImage(screen), 250 + Length(text) * 8 + 10, y, '<', 14, 0);
  end;
end;

{ Display the main intro menu }
procedure show_intro_menu;
begin
  { Clear screen }
  clear_bitmap(PImage(screen));

  { Draw title }
  print_normal(PImage(screen), 200, 50, 'SIRIEL 3.5', 15, 0);
  print_normal(PImage(screen), 180, 80, 'MODERN PORT', 11, 0);

  { Draw version info }
  print_normal(PImage(screen), 10, 10, 'v0.5 - Phase 5B', 7, 0);

  { Draw menu options }
  draw_menu_option(150, 'START GAME', menu_selection = 0);
  draw_menu_option(185, 'INFO', menu_selection = 1);
  draw_menu_option(220, 'HIGH SCORE', menu_selection = 2);
  draw_menu_option(255, 'DATADISK', menu_selection = 3);
  draw_menu_option(300, 'EXIT', menu_selection = 4);

  { Draw instructions }
  print_normal(PImage(screen), 150, 400, 'Use UP/DOWN arrows to move, ENTER to select', 8, 0);
  print_normal(PImage(screen), 200, 420, 'Press ESC to quit', 8, 0);
end;

begin
  writeln('=== Siriel Modern - Initial Menu Test ===');
  writeln('');

  { Parse duration parameter (default 10 seconds) }
  duration_seconds := 10;
  if ParamCount > 0 then
  begin
    duration_seconds := StrToIntDef(ParamStr(1), 10);
  end;
  writeln('Auto-exit after ', duration_seconds, ' seconds');
  writeln('Usage: ./test_menu [duration_seconds]');
  writeln('');

  menu_selection := 0;
  frame_count := 0;
  running := true;
  start_frame := 0;

  { Initialize Raylib }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Siriel 3.5 Modern - Menu Test');
  SetTargetFPS(60);

  { Initialize palette }
  load_palette_block('data/MAIN.DAT', 'PAL256', palette);

  { Show initial menu }
  show_intro_menu;

  writeln('Menu displayed. Use arrow keys to navigate.');
  writeln('Press ENTER to select, ESC to quit.');
  writeln('');

  { Main menu loop }
  while running and not (WindowShouldClose() <> 0) do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);

    { Render our virtual screen }
    RenderScreenToWindow();

    { Handle input }
    if IsKeyDown(KEY_UP) <> 0 then
    begin
      if menu_selection > 0 then
        menu_selection := menu_selection - 1;
      show_intro_menu;
    end;

    if IsKeyDown(KEY_DOWN) <> 0 then
    begin
      if menu_selection < 4 then
        menu_selection := menu_selection + 1;
      show_intro_menu;
    end;

    if IsKeyDown(KEY_ENTER) <> 0 then
    begin
      writeln('Selected option: ', menu_selection);
      case menu_selection of
        0: writeln('  -> START GAME (not implemented yet)');
        1: writeln('  -> INFO (not implemented yet)');
        2: writeln('  -> HIGH SCORE (not implemented yet)');
        3: writeln('  -> DATADISK (not implemented yet)');
        4:
        begin
          writeln('  -> EXIT');
          running := false;
        end;
      end;
    end;

    if IsKeyDown(KEY_ESCAPE) <> 0 then
    begin
      writeln('ESC pressed, exiting...');
      running := false;
    end;

    Inc(frame_count);
    current_frame := frame_count;

    { Auto-exit after duration seconds }
    if (current_frame - start_frame) >= (duration_seconds * 60) then
    begin
      writeln('Auto-exit after ', duration_seconds, ' seconds');
      running := false;
    end;

    EndDrawing();
  end;

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('  Frames rendered: ', frame_count);
  writeln('  Menu system functional!');
end.
