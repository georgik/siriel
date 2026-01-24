program test_sound_simple;

{$mode objfpc}{$H+}

{ Simple non-interactive test for sound loading }

uses
  SysUtils,
  jxzvuk,
  blockx;

begin
  writeln('=== Simple Sound Loading Test ===');
  writeln('');

  { Initialize audio }
  writeln('[1] Initializing audio system...');
  InitAudio;
  set_zvuk(true);
  writeln('    Audio initialized');
  writeln('');

  { Load a sound from SIRIEL35.DAT }
  writeln('[2] Loading ZNAEC sound from SIRIEL35.DAT...');
  zvukovy_subor := 'data/SIRIEL35.DAT';
  zvuky[1] := 'ZNAEC';
  num_snd := 1;
  NumSounds := 1;

  LoadSounds;
  writeln('    Sound loaded successfully');
  writeln('');

  { Try to play the sound }
  writeln('[3] Attempting to play sound...');
  pust(0);
  writeln('    Sound playback triggered');
  writeln('');

  { Wait a bit to let sound play }
  writeln('[4] Waiting 2 seconds for sound to play...');
  Sleep(2000);
  writeln('    Wait complete');
  writeln('');

  { Cleanup }
  writeln('[5] Cleaning up...');
  FreeSounds;
  ShutdownAudio;
  writeln('    Cleanup complete');
  writeln('');

  writeln('=== Test Complete ===');
  writeln('');
  writeln('If you heard sound, the audio system is working!');
end.
