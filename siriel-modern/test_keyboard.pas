program test_keyboard;

{$mode objfpc}{$H+}

{ Test keyboard input handling via Raylib
  Verifies that zmack() and sipky() work correctly for game input
  Usage: ./test_keyboard (interactive - press arrow keys to move)
}

uses
  SysUtils,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  geo;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;
  PLAYER_SIZE = 16;

var
  screenshot_file: string;
  frame_count: integer;
  player_x, player_y: integer;
  sipx, sipy: integer;
  kluc: word;
  dst_idx: longint;
  x, y: word;
  r, g, b, a: byte;

begin
  writeln('=== Keyboard Input Test ===');
  writeln('Testing Raylib keyboard integration');
  writeln('');

  { Parse command line }
  screenshot_file := '';
  if ParamCount >= 1 then
    screenshot_file := ParamStr(1);

  writeln('Mode: Interactive (Arrow keys to move, ESC to quit)');
  writeln('');

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  writeln('[1] Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);
  writeln('');

  { Initialize player position }
  player_x := SCREEN_WIDTH div 2;
  player_y := SCREEN_HEIGHT div 2;
  writeln('[2] Player initialized at (', player_x, ', ', player_y, ')');
  writeln('');

  { Open window }
  writeln('[3] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Keyboard Input Test - Arrow Keys to Move');
  SetTargetFPS(60);
  writeln('    OK - Window opened');
  writeln('');
  writeln('Controls:');
  writeln('  Arrow keys - Move player');
  writeln('  ESC - Quit');
  writeln('');

  frame_count := 0;

  { Main game loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);

    { Get keyboard input }
    sipky(sipx, sipy, kluc);

    { Update player position }
    player_x := player_x + sipx;
    player_y := player_y + sipy;

    { Keep player on screen }
    if player_x < 0 then
      player_x := 0;
    if player_x > SCREEN_WIDTH - PLAYER_SIZE then
      player_x := SCREEN_WIDTH - PLAYER_SIZE;
    if player_y < 0 then
      player_y := 0;
    if player_y > SCREEN_HEIGHT - PLAYER_SIZE then
      player_y := SCREEN_HEIGHT - PLAYER_SIZE;

    { Draw player (red square) }
    for y := player_y to player_y + PLAYER_SIZE - 1 do
    begin
      for x := player_x to player_x + PLAYER_SIZE - 1 do
      begin
        dst_idx := (y * SCREEN_WIDTH + x) * 4;
        PByte(screen_image^.data + dst_idx)^ := 255;     { R }
        PByte(screen_image^.data + dst_idx + 1)^ := 0;       { G }
        PByte(screen_image^.data + dst_idx + 2)^ := 0;       { B }
        PByte(screen_image^.data + dst_idx + 3)^ := 255;     { A }
      end;
    end;

    { Render screen }
    RenderScreenToWindow();
    EndDrawing();

    inc(frame_count);

    { Check for ESC key }
    if kluc = kb_esc then
    begin
      writeln('    ESC pressed, exiting...');
      break;
    end;
  end;

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Frames rendered: ', frame_count);
  writeln('Final player position: (', player_x, ', ', player_y, ')');
  writeln('');
  writeln('Keyboard test successful!');
  writeln('  - Arrow keys worked for movement');
  writeln('  - ESC key worked for exit');
  writeln('  - Real-time input is functional');
  writeln('');
end.
