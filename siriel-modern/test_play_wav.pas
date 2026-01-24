program test_play_wav;

{$mode objfpc}{$H+}

{ Simple test to verify Raylib audio works with Pascal
  Loads and plays a pre-converted WAV file from disk }

uses
  SysUtils,
  raylib_helpers;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  sound: TRaylibSound;
  loaded: boolean;
begin
  writeln('=== Raylib Audio WAV Test ===');
  writeln('');

  { Initialize audio device }
  writeln('[1] Initializing audio device...');
  InitAudioDevice;

  if IsAudioDeviceReady() = 0 then
    writeln('    WARNING: Audio device not ready!')
  else
    writeln('    OK - Audio device ready');

  writeln('    OK - Audio device initialized');
  writeln('');

  { Load WAV file from disk }
  writeln('[2] Loading CONFIG_16.wav from disk (16-bit, 44100Hz)...');
  sound := LoadSound(PChar('data/CONFIG_16.wav'));

  writeln('    Debug: sound.stream.buffer = ', SysUtils.Format('%p', [sound.stream.buffer]));
  writeln('    Debug: sound.stream.sampleRate = ', sound.stream.sampleRate);
  writeln('    Debug: sound.stream.channels = ', sound.stream.channels);
  writeln('    Debug: sound.frameCount = ', sound.frameCount);
  writeln('    Note: 44100 Hz * 1 sec = ', 44100, ' frames expected');
  writeln('    Note: sound.duration = ', (sound.frameCount / 44100.0):0:3, ' seconds');

  if sound.stream.buffer = nil then
  begin
    writeln('    ERROR: Failed to load sound (stream.buffer is nil)!');
    CloseAudioDevice;
    Exit;
  end;

  loaded := true;
  writeln('    OK - Sound loaded successfully');

  { Set volume to maximum }
  SetSoundVolume(sound, 1.0);
  writeln('    Volume set to 1.0 (maximum)');
  writeln('');

  { Initialize window }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'WAV Audio Test - Press SPACE to play');
  SetTargetFPS(60);

  writeln('[3] Interactive test running');
  writeln('    Press SPACE to play CONFIG.wav');
  writeln('    Press ESC to quit');
  writeln('');

  { Main loop }
  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();
    ClearBackground(50, 50, 50, 255);

    DrawText('Raylib Audio WAV Test', 20, 20, 30, 255, 255, 255, 255);
    DrawText('File: data/CONFIG_16.wav', 20, 60, 20, 200, 200, 200, 255);
    DrawText('Format: 16-bit PCM, 44100 Hz, mono', 20, 85, 20, 150, 150, 150, 255);
    DrawText('Press SPACE to play sound', 20, 120, 20, 200, 200, 200, 255);
    DrawText('Press ESC to quit', 20, 145, 20, 200, 200, 200, 255);

    { Show sound playing status }
    if IsSoundPlaying(sound) <> 0 then
      DrawText('Status: PLAYING', 20, 180, 20, 0, 255, 0, 255)
    else
      DrawText('Status: Not playing', 20, 180, 20, 255, 100, 100, 255);

    if IsKeyPressed(32) <> 0 then  { SPACE }
    begin
      writeln('[PLAY] Attempting to play sound...');
      writeln('      sound.stream.buffer = ', SysUtils.Format('%p', [sound.stream.buffer]));
      writeln('      sound.frameCount = ', sound.frameCount);
      writeln('      Calling PlaySound()...');
      PlaySound(sound);
      writeln('      PlaySound() returned successfully');
      writeln('');

      { Wait a moment and check again }
      { Note: We'll check in the next frame iteration }
    end;

    EndDrawing();
  end;

  { Cleanup }
  if loaded then
    UnloadSound(sound);

  CloseAudioDevice;
  CloseWindow;

  writeln('');
  writeln('=== Test Complete ===');
  writeln('If you heard the sound, Raylib audio is working correctly!');
end.
