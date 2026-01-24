program test_sound_wav;

{$mode objfpc}{$H+}

{ Test sound loading from extracted WAV files }

uses
  SysUtils,
  raylib_helpers;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  frame: integer;
  sound: TRaylibSound;
begin
  writeln('=== Sound WAV Test ===');
  writeln('');

  { Initialize audio }
  writeln('[1] Initializing audio...');
  InitAudioDevice;
  writeln('    Audio initialized');
  writeln('');

  { Load a WAV file }
  writeln('[2] Loading ZNAEC.wav from extracted files...');
  sound := LoadSound(PChar('/Volumes/ssdt5/Users/georgik/projects/siriel/siriel-bevy/assets/audio/extracted/SIRIEL35/ZNAEC.wav'));

  if sound.stream = nil then
  begin
    writeln('    ERROR: Failed to load sound!');
    CloseAudioDevice;
    Exit;
  end;

  writeln('    Sound loaded successfully!');
  writeln('');

  { Initialize window }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Sound Test - Press SPACE to play');
  SetTargetFPS(60);

  writeln('[3] Test running. Press SPACE to play sound, ESC to quit.');
  writeln('');

  { Main loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    ClearBackground(50, 50, 50, 255);

    DrawText('Sound WAV Test', 20, 20, 30, 255, 255, 255, 255);
    DrawText('Press SPACE to play ZNAEC sound', 20, 60, 20, 200, 200, 200, 255);
    DrawText('Press ESC to quit', 20, 90, 20, 200, 200, 200, 255);

    if IsKeyPressed(32) <> 0 then  { SPACE }
    begin
      writeln('[PLAY] Playing sound...');
      PlaySound(sound);
    end;

    EndDrawing();
  end;

  { Cleanup }
  UnloadSound(sound);
  CloseAudioDevice;
  CloseWindow;

  writeln('');
  writeln('=== Test Complete ===');
end.
