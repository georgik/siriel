program test_sound;

{$mode objfpc}{$H+}

{ Test loading and playing sounds from SIRIEL35.DAT }

uses
  SysUtils,
  ctypes,
  raylib_helpers,
  jxzvuk,
  blockx;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  frame: integer;

begin
  writeln('=== Sound System Test ===');
  writeln('');

  { Initialize audio }
  writeln('Initializing audio...');
  InitAudio;
  set_zvuk(true);
  writeln('');

  { List Z-prefixed blocks (sounds) from SIRIEL35.DAT }
  writeln('Z-prefixed blocks (sounds) in SIRIEL35.DAT:');
  writeln('  ZNAEC   - 416,208 bytes');
  writeln('  ZSCHUB  - 339,564 bytes');
  writeln('  ZROCK   - 265,276 bytes');
  writeln('  ZPARA   - 148,392 bytes');
  writeln('  ZFEELGO - 108,592 bytes');
  writeln('');

  { Try loading a sound }
  writeln('Loading ZNAEC from SIRIEL35.DAT...');
  zvukovy_subor := 'data/SIRIEL35.DAT';
  zvuky[1] := 'ZNAEC';
  num_snd := 1;
  NumSounds := 1;

  LoadSounds;
  writeln('');

  { Initialize window for visual feedback }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Sound Test - Press SPACE to play, ESC to quit');
  SetTargetFPS(60);

  writeln('');
  writeln('=== Sound Test Running ===');
  writeln('Controls:');
  writeln('  SPACE - Play sound');
  writeln('  ESC   - Quit');
  writeln('');

  { Main loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    ClearBackground(50, 50, 50, 255);

    { Draw instructions }
    DrawText('Sound System Test', 20, 20, 30, 255, 255, 255, 255);
    DrawText('Press SPACE to play ZNAEC sound', 20, 60, 20, 200, 200, 200, 255);
    DrawText('Press ESC to quit', 20, 90, 20, 200, 200, 200, 255);

    { Check for key press }
    if IsKeyPressed(32) <> 0 then  { SPACE key }
    begin
      writeln('[TEST] Playing sound ZNAEC...');
      pust(0);
    end;

    EndDrawing();
  end;

  { Cleanup }
  FreeSounds;
  ShutdownAudio;
  CloseWindow;

  writeln('');
  writeln('=== Test Complete ===');
end.
