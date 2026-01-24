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
  dos_compat;

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
  data: pointer;
  BytesRead: LongInt;
begin
  LoadSoundFromDAT := nil;

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
  snd^.Data := nil;
  snd^.SampleRate := 11025; { Siriel sounds are 11.025 kHz, not 22.05 kHz }
  snd^.Channels := 1;      { Mono }
  snd^.BitsPerSample := 8;  { 8-bit PCM }
  snd^.SampleCount := ResHeader.Size; { For raw PCM, 1 byte per sample }

  { Allocate memory and read data }
  GetMem(snd^.Data, snd^.Size);
  Seek(fil, ResHeader.Start);
  BlockRead(fil, snd^.Data^, snd^.Size, BytesRead);
  CloseFile(fil);

  if BytesRead <> snd^.Size then
  begin
    writeln('[AUDIO] ERROR: Failed to read complete sound data');
    FreeMem(snd^.Data);
    Dispose(snd);
    Exit;
  end;

  { Check if it's a WAV file or raw PCM }
  if snd^.Size >= 4 then
  begin
    if PChar(snd^.Data) = 'RIFF' then
    begin
      { It's a WAV file - parse header }
      if snd^.Size >= 44 then
      begin
        snd^.Channels := PByte(snd^.Data + 20)^;
        snd^.SampleRate := PLongInt(snd^.Data + 24)^;
        snd^.BitsPerSample := PByte(snd^.Data + 34)^;

        { Calculate sample count }
        snd^.SampleCount := (snd^.Size - 44) div ((snd^.BitsPerSample div 8) * snd^.Channels);

        writeln('[AUDIO] Loaded WAV: ', key, ' (', snd^.SampleRate, 'Hz, ',
                snd^.Channels, ' ch, ', snd^.BitsPerSample, ' bit, ',
                snd^.SampleCount, ' samples)');
      end;
    end
    else
    begin
      { Raw PCM data (8-bit unsigned) }
      writeln('[AUDIO] Loaded raw PCM: ', key, ' (', snd^.Size, ' bytes, ',
              snd^.SampleRate, 'Hz, ', snd^.Channels, ' ch)');
    end;
  end;

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
  wave: TRaylibWave;
  raylib_sound: TRaylibSound;
  rawData: PByte;
  samples16: PSmallInt;
  wavBuffer: pointer;
  wavHeader: TWAVHeader absolute wavBuffer;
  dataSize: LongInt;
  i: LongInt;
begin
  PlaySoundCustom := false;

  if snd = nil then
    Exit;

  if not AudioInitialized then
    InitAudio;

  { Convert 8-bit unsigned PCM (0-255) to 16-bit signed PCM (-32768 to 32767) }
  { 8-bit value 128 (silence) maps to 16-bit value 0 }
  dataSize := snd^.Size * 2;  { 16-bit = 2 bytes per sample }
  GetMem(samples16, dataSize);

  rawData := PByte(snd^.Data);
  for i := 0 to snd^.Size - 1 do
  begin
    { Convert: (0-255) -> (-32768 to 32767) }
    { 128 -> 0, 0 -> -32768, 255 -> 32767 }
    samples16[i] := SmallInt((rawData[i] - 128) * 256);
  end;

  { Debug: Check header size }
  writeln('[AUDIO] WAV header size: ', SizeOf(TWAVHeader), ' bytes (expected 44)');

  { Allocate buffer for header + data }
  GetMem(wavBuffer, SizeOf(TWAVHeader) + dataSize);

  { Fill WAV header using structured record }
  wavHeader.RIFFId[0] := 'R';
  wavHeader.RIFFId[1] := 'I';
  wavHeader.RIFFId[2] := 'F';
  wavHeader.RIFFId[3] := 'F';
  wavHeader.FileSize := SizeOf(TWAVHeader) + dataSize - 8;
  wavHeader.WAVEId[0] := 'W';
  wavHeader.WAVEId[1] := 'A';
  wavHeader.WAVEId[2] := 'V';
  wavHeader.WAVEId[3] := 'E';
  wavHeader.fmtId[0] := 'f';
  wavHeader.fmtId[1] := 'm';
  wavHeader.fmtId[2] := 't';
  wavHeader.fmtId[3] := ' ';
  wavHeader.fmtSize := 16;
  wavHeader.AudioFormat := 1;  { PCM }
  wavHeader.NumChannels := snd^.Channels;
  wavHeader.SampleRate := snd^.SampleRate;
  wavHeader.ByteRate := snd^.SampleRate * snd^.Channels * 2;  { 16-bit }
  wavHeader.BlockAlign := snd^.Channels * 2;
  wavHeader.BitsPerSample := 16;
  wavHeader.dataId[0] := 'd';
  wavHeader.dataId[1] := 'a';
  wavHeader.dataId[2] := 't';
  wavHeader.dataId[3] := 'a';
  wavHeader.DataSize := dataSize;

  { Debug output }
  writeln('[AUDIO] WAV header: Rate=', wavHeader.SampleRate, ', Ch=', wavHeader.NumChannels,
          ', Bits=', wavHeader.BitsPerSample, ', DataSize=', wavHeader.DataSize);

  { Copy converted 16-bit data after header }
  Move(samples16^, (PByte(wavBuffer) + SizeOf(TWAVHeader))^, dataSize);

  { Load WAV from memory }
  writeln('[AUDIO] Loading WAV from memory (', SizeOf(TWAVHeader) + dataSize, ' bytes)...');
  wave := raylib_helpers.LoadWaveFromMemory('wav', wavBuffer, SizeOf(TWAVHeader) + dataSize);

  FreeMem(samples16);
  FreeMem(wavBuffer);

  if wave.data = nil then
  begin
    writeln('[AUDIO] ERROR: Failed to load wave from memory');
    Exit;
  end;

  { Convert wave to sound }
  raylib_sound := raylib_helpers.LoadSoundFromWave(wave);
  raylib_helpers.UnloadWave(wave);

  if raylib_sound.stream = nil then
  begin
    writeln('[AUDIO] ERROR: Failed to create Raylib sound');
    Exit;
  end;

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

begin
  zvuk := false;
  zvukovy_subor := def_zvuk_sub;
  num_snd := 16;
  NumSounds := 16;
end.
