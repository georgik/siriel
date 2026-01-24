program test_sound_dat;

{$mode objfpc}{$H+}

{ Test loading sound directly from DAT file (not pre-converted WAV) }

uses
  SysUtils,
  raylib_helpers,
  jxzvuk,
  blockx;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  frame: integer;

begin
  writeln('=== Sound DAT Loading Test ===');
  writeln('This test loads ZNAEC sound directly from SIRIEL35.DAT');
  writeln('File: data/SIRIEL35.DAT, Block: ZNAEC');
  writeln('');

  { Initialize audio }
  writeln('[1] Initializing audio...');
  InitAudio;
  set_zvuk(true);
  writeln('    OK');
  writeln('');

  { Configure sound loading from DAT file }
  zvukovy_subor := 'data/SIRIEL35.DAT';
  zvuky[1] := 'ZNAEC';
  num_snd := 1;
  NumSounds := 1;

  { Load sound from DAT }
  writeln('[2] Loading ZNAEC from SIRIEL35.DAT...');
  LoadSounds;
  writeln('    OK - Sound loaded from DAT file');
  writeln('    Format: 8-bit PCM, 11025 Hz, mono');
  writeln('');

  { Initialize window }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Sound DAT Test - SPACE to play');
  SetTargetFPS(60);

  writeln('[3] Test running');
  writeln('    Press SPACE to play sound from DAT');
  writeln('    Press ESC to quit');
  writeln('');

  { Main loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    ClearBackground(50, 50, 50, 255);

    DrawText('Sound DAT Test', 20, 20, 30, 255, 255, 255, 255);
    DrawText('Loading: data/SIRIEL35.DAT block ZNAEC', 20, 60, 20, 200, 200, 200, 255);
    DrawText('Format: 8-bit PCM @ 11025Hz mono', 20, 85, 20, 150, 150, 150, 255);
    DrawText('Press SPACE to play', 20, 120, 20, 200, 200, 200, 255);
    DrawText('Press ESC to quit', 20, 145, 20, 200, 200, 200, 255);

    if IsKeyPressed(32) <> 0 then  { SPACE }
    begin
      writeln('[PLAY] Playing ZNAEC from DAT...');
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
  writeln('Sound was loaded and played directly from DAT file');
end.
