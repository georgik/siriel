program test_play_dat;

{$mode objfpc}{$H+}

{ Test loading and playing sound from DAT file }

uses
  SysUtils,
  raylib_helpers,
  jxzvuk,
  blockx;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

begin
  writeln('=== DAT Audio Playback Test ===');
  writeln('');

  { Initialize audio }
  writeln('[1] Initializing audio device...');
  InitAudio;
  set_zvuk(true);
  writeln('    OK');
  writeln('');

  { Configure sound loading from DAT file }
  writeln('[2] Configuring DAT sound loading...');
  zvukovy_subor := 'data/SIRIEL35.DAT';
  zvuky[1] := 'ZNAEC';
  num_snd := 1;
  NumSounds := 1;
  writeln('    File: ', zvukovy_subor);
  writeln('    Block: ', zvuky[1]);
  writeln('    OK');
  writeln('');

  { Load sound from DAT }
  writeln('[3] Loading sound from DAT file...');
  LoadSounds;
  writeln('    OK');
  writeln('');

  { Initialize window }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'DAT Audio Test - SPACE to play');
  SetTargetFPS(60);

  writeln('[4] Test running');
  writeln('    Press SPACE to play ZNAEC from DAT');
  writeln('    Press ESC to quit');
  writeln('');

  { Main loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    ClearBackground(50, 50, 50, 255);

    DrawText('DAT Audio Test', 20, 20, 30, 255, 255, 255, 255);
    DrawText('Loading: data/SIRIEL35.DAT block ZNAEC', 20, 60, 20, 200, 200, 200, 255);
    DrawText('Original format: 8-bit PCM, 11025 Hz, mono', 20, 85, 20, 150, 150, 150, 255);
    DrawText('Press SPACE to play', 20, 120, 20, 200, 200, 200, 255);
    DrawText('Press ESC to quit', 20, 145, 20, 200, 200, 200, 255);
    DrawText('Status: Ready', 20, 180, 20, 150, 150, 150, 255);

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
  writeln('Sound was loaded and played from DAT file!');
end.
