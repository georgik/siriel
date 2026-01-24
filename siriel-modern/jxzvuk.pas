unit jxzvuk;

{$mode objfpc}{$H+}

{ Modern sound system using Raylib audio
  Ported from original JXZVUK.PAS which used SMIX/SoundBlaster
  Sounds are WAV files stored in DAT blocks, typically mono 22kHz
}

interface

uses
  SysUtils,
  ctypes,
  raylib_helpers,
  blockx,
  dos_compat,
  koder;

const
  Max_NumSounds = 20;
  Nos = 'NOSOUND';
  def_zvuk_sub = 'MAIN.DAT';

type
  PSound = ^TSound;
  TSound =
    record
      Data: pointer;       { Audio sample data }
      Size: LongInt;       { Size in bytes }
      SampleRate: LongInt; { Sample rate (usually 22050) }
      SampleCount: LongInt;{ Number of samples }
      Channels: byte;      { 1=mono, 2=stereo }
      BitsPerSample: byte; { 8 or 16 }
    end;

  { WAV header structure for proper alignment }
  TWAVHeader = packed record
    RIFFId: array[0..3] of Char;      { "RIFF" }
    FileSize: LongInt;                { File size - 8 }
    WAVEId: array[0..3] of Char;      { "WAVE" }
    fmtId: array[0..3] of Char;       { "fmt " }
    fmtSize: LongInt;                 { 16 for PCM }
    AudioFormat: Word;                { 1 = PCM }
    NumChannels: Word;                { 1 = mono, 2 = stereo }
    SampleRate: LongInt;              { e.g., 11025 }
    ByteRate: LongInt;                { SampleRate * NumChannels * BitsPerSample/8 }
    BlockAlign: Word;                 { NumChannels * BitsPerSample/8 }
    BitsPerSample: Word;              { 8 or 16 }
    dataId: array[0..3] of Char;      { "data" }
    DataSize: LongInt;                { Size of audio data }
  end;

var
  zvuky: array[1..Max_NumSounds] of string[10];
  NumSounds, num_snd: word;
  Zvuk: boolean;
  zvukovy_subor: string;

{ Sound system management }
procedure InitAudio;
procedure ShutdownAudio;
procedure set_numsounds(num: word);
procedure set_zvuk(x: boolean);

{ Sound loading and management }
procedure LoadSounds;
procedure FreeSounds;
procedure reload_sound(num: word; meno_suboru, meno_hlavy: string);

{ Sound playback }
procedure pust(num: word);  { Play sound }
procedure pust2(num: word); { Play sound with delay }

{ Raylib audio wrappers }
function LoadSoundFromDAT(dataname, key: string): PSound;
procedure FreeSoundCustom(snd: PSound);
function PlaySoundCustom(snd: PSound): boolean;
function GetSound(num: word): PSound;

implementation

var
  Sound: array[0..Max_NumSounds-1] of PSound;
  AudioInitialized: boolean = false;

{ Initialize Raylib audio system }
procedure InitAudio;
begin
  if not AudioInitialized then
  begin
    InitAudioDevice;
    AudioInitialized := true;
    writeln('[AUDIO] Audio device initialized');
  end;
end;

{ Shutdown audio system }
procedure ShutdownAudio;
begin
  if AudioInitialized then
  begin
    FreeSounds;
    CloseAudioDevice;
    AudioInitialized := false;
    writeln('[AUDIO] Audio device shutdown');
  end;
end;

{ Set whether sound is enabled }
procedure set_zvuk(x: boolean);
begin
  zvuk := x;
  if zvuk and not AudioInitialized then
    InitAudio;
end;

{ Set number of sounds }
procedure set_numsounds(num: word);
var
  f: word;
begin
  NumSounds := num;
  num_snd := num;
  for f := 1 to Max_NumSounds do
    zvuky[f] := Nos;
end;

{ Load a WAV sound from DAT file }
function LoadSoundFromDAT(dataname, key: string): PSound;
var
  fil: file;
  NumBlocks: Word;
  ResKey: TKey;
  ResHeader: TResource;
  Index: integer;
  i: integer;
  Found: boolean;
  snd: PSound;
  bytesRead: LongInt;
begin
  LoadSoundFromDAT := nil;

  writeln('[AUDIO] Loading block: ', key, ' from ', dataname);

  if not dos_compat.subor_exist(dataname) then
  begin
    writeln('[AUDIO] ERROR: File not found: ', dataname);
    Exit;
  end;

  { Prepare key }
  for i := 1 to 8 do
    if i <= Length(key) then
      ResKey[i] := UpCase(key[i])
    else
      ResKey[i] := #0;

  { Open file and find block }
  AssignFile(fil, dataname);
  Reset(fil, 1);
  BlockRead(fil, NumBlocks, SizeOf(NumBlocks));

  Found := false;
  Index := 0;

  while not(Found) and (Index < NumBlocks) do
  begin
    Inc(Index);
    BlockRead(fil, ResHeader, SizeOf(ResHeader));

    if MatchingKeys(ResHeader.Key, ResKey) then
      Found := true;
  end;

  if not Found then
  begin
    CloseFile(fil);
    writeln('[AUDIO] ERROR: Key not found: ', key);
    Exit;
  end;

  { Allocate sound structure }
  New(snd);
  snd^.Size := ResHeader.Size;
  snd^.SampleRate := 11025;
  snd^.Channels := 1;
  snd^.BitsPerSample := 8;
  snd^.SampleCount := ResHeader.Size;

  { Allocate memory and read data }
  GetMem(snd^.Data, snd^.Size);
  Seek(fil, ResHeader.Start);
  BlockRead(fil, snd^.Data^, snd^.Size, bytesRead);
  CloseFile(fil);

  if bytesRead <> snd^.Size then
  begin
    writeln('[AUDIO] ERROR: Failed to read complete sound data');
    FreeMem(snd^.Data);
    Dispose(snd);
    Exit;
  end;

  writeln('[AUDIO] Loaded raw PCM: ', key, ' (', snd^.Size, ' bytes, ',
          snd^.SampleRate, 'Hz, ', snd^.Channels, ' ch, ', snd^.SampleCount, ' samples)');

  LoadSoundFromDAT := snd;
end;

{ Free a sound }
procedure FreeSoundCustom(snd: PSound);
begin
  if snd <> nil then
  begin
    if snd^.Data <> nil then
      FreeMem(snd^.Data);
    Dispose(snd);
  end;
end;

{ Play a sound using Raylib }
function PlaySoundCustom(snd: PSound): boolean;
var
  fil: file;
  rawData: PByte;
  samples16: PSmallInt;
  samples16_resampled: PSmallInt;
  dataSize: LongInt;
  resampledSize: LongInt;
  i, j: LongInt;
  srcPos: double;
  weight: double;
  sample1, sample2: SmallInt;
  tempFileName: string;
  tempWAV: array[0..43] of char;
  wave: TRaylibWave;
  raylib_sound: TRaylibSound;
begin
  PlaySoundCustom := false;

  if snd = nil then
    Exit;

  if not AudioInitialized then
    InitAudio;

  { First convert 8-bit to 16-bit }
  dataSize := snd^.Size * 2;
  GetMem(samples16, dataSize);

  rawData := PByte(snd^.Data);
  for i := 0 to snd^.Size - 1 do
  begin
    samples16[i] := SmallInt((rawData[i] - 128) * 256);
  end;

  { Now resample from 11025 Hz to 44100 Hz (4x) }
  resampledSize := dataSize * 4;
  GetMem(samples16_resampled, resampledSize);

  for i := 0 to (snd^.Size * 4) - 1 do
  begin
    srcPos := i / 4.0;
    j := Trunc(srcPos);
    weight := srcPos - j;

    sample1 := samples16[j];
    if j + 1 < snd^.Size then
      sample2 := samples16[j + 1]
    else
      sample2 := sample1;

    { Linear interpolation }
    samples16_resampled[i] := SmallInt(Round(sample1 + weight * (sample2 - sample1)));
  end;

  { Create temp WAV file }
  tempFileName := 'temp_sound_' + Format('%x', [PtrUInt(snd)]) + '.wav';

  AssignFile(fil, tempFileName);
  Rewrite(fil, 1);

  { Write WAV header }
  tempWAV[0] := 'R'; tempWAV[1] := 'I'; tempWAV[2] := 'F'; tempWAV[3] := 'F';
  PLongInt(@tempWAV[4])^ := resampledSize + 36;
  tempWAV[8] := 'W'; tempWAV[9] := 'A'; tempWAV[10] := 'V'; tempWAV[11] := 'E';
  tempWAV[12] := 'f'; tempWAV[13] := 'm'; tempWAV[14] := 't'; tempWAV[15] := ' ';
  PLongInt(@tempWAV[16])^ := 16;
  PWord(@tempWAV[20])^ := 1;
  PWord(@tempWAV[22])^ := snd^.Channels;
  PLongInt(@tempWAV[24])^ := 44100;
  PLongInt(@tempWAV[28])^ := 44100 * 2;
  PWord(@tempWAV[32])^ := 2;
  PWord(@tempWAV[34])^ := 16;
  tempWAV[36] := 'd'; tempWAV[37] := 'a'; tempWAV[38] := 't'; tempWAV[39] := 'a';
  PLongInt(@tempWAV[40])^ := resampledSize;

  BlockWrite(fil, tempWAV, 44);
  BlockWrite(fil, samples16_resampled^, resampledSize);
  CloseFile(fil);

  FreeMem(samples16);
  FreeMem(samples16_resampled);

  { Load WAV from file }
  writeln('[AUDIO] Loading WAV from file: ', tempFileName);
  wave := raylib_helpers.LoadWave(PChar(tempFileName));

  if wave.data = nil then
  begin
    writeln('[AUDIO] ERROR: Failed to load wave from memory');
    Exit;
  end;

  { Convert wave to sound }
  raylib_sound := raylib_helpers.LoadSoundFromWave(wave);
  raylib_helpers.UnloadWave(wave);

  if raylib_sound.stream.buffer = nil then
  begin
    writeln('[AUDIO] ERROR: Failed to create Raylib sound');
    Exit;
  end;

  { Set volume to 50% }
  raylib_helpers.SetSoundVolume(raylib_sound, 0.5);

  { Play sound }
  raylib_helpers.PlaySound(raylib_sound);

  PlaySoundCustom := true;
end;

{ Load all sounds }
procedure LoadSounds;
var
  i: integer;
begin
  if not zvuk then
    Exit;

  if not AudioInitialized then
    InitAudio;

  writeln('[AUDIO] Loading ', num_snd, ' sounds from ', zvukovy_subor);

  for i := 1 to num_snd do
  begin
    if zvuky[i] = Nos then
    begin
      { Load default sound from MAIN.DAT }
      Sound[i-1] := LoadSoundFromDAT(def_zvuk_sub, Nos);
    end
    else if zvuky[i] <> '' then
    begin
      { Load named sound from current DAT file }
      Sound[i-1] := LoadSoundFromDAT(zvukovy_subor, zvuky[i]);
    end
    else
      Sound[i-1] := nil;
  end;

  writeln('[AUDIO] Sounds loaded successfully');
end;

{ Free all sounds }
procedure FreeSounds;
var
  i: integer;
begin
  if not zvuk then
    Exit;

  writeln('[AUDIO] Freeing sounds...');

  for i := 0 to NumSounds-1 do
  begin
    if Sound[i] <> nil then
    begin
      FreeSoundCustom(Sound[i]);
      Sound[i] := nil;
    end;
  end;

  writeln('[AUDIO] Sounds freed');
end;

{ Reload a sound }
procedure reload_sound(num: word; meno_suboru, meno_hlavy: string);
begin
  if not zvuk then
    Exit;

  if num >= Max_NumSounds then
    Exit;

  { Free old sound }
  if Sound[num] <> nil then
  begin
    FreeSoundCustom(Sound[num]);
    Sound[num] := nil;
  end;

  { Load new sound }
  if meno_hlavy = Nos then
    meno_suboru := def_zvuk_sub
  else
    meno_suboru := zvukovy_subor;

  Sound[num] := LoadSoundFromDAT(meno_suboru, meno_hlavy);
end;

{ Play a sound }
procedure pust(num: word);
begin
  if not zvuk then
    Exit;

  if (num >= 0) and (num < NumSounds) and (Sound[num] <> nil) then
  begin
    PlaySoundCustom(Sound[num]);
  end;
end;

{ Play a sound with delay }
procedure pust2(num: word);
begin
  if not zvuk then
    Exit;

  pust(num);

  { Original code had delay here - you can add if needed }
  { pulzx(10); }
end;

{ Get a sound pointer }
function GetSound(num: word): PSound;
begin
  if (num >= 0) and (num < NumSounds) then
    GetSound := Sound[num]
  else
    GetSound := nil;
end;

begin
  zvuk := false;
  zvukovy_subor := def_zvuk_sub;
  num_snd := 16;
  NumSounds := 16;
end.
