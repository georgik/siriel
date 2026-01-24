program test_wav_header;

{$mode objfpc}{$H+}

{ Test WAV header structure size }

type
  TWAVHeader = packed record
    RIFFId: array[0..3] of Char;
    FileSize: LongInt;
    WAVEId: array[0..3] of Char;
    fmtId: array[0..3] of Char;
    fmtSize: LongInt;
    AudioFormat: Word;
    NumChannels: Word;
    SampleRate: LongInt;
    ByteRate: LongInt;
    BlockAlign: Word;
    BitsPerSample: Word;
    dataId: array[0..3] of Char;
    DataSize: LongInt;
  end;

begin
  writeln('WAV Header Size: ', SizeOf(TWAVHeader), ' bytes');
  writeln('Expected: 44 bytes');

  if SizeOf(TWAVHeader) <> 44 then
    writeln('WARNING: Header size mismatch! This will cause WAV parsing to fail.')
  else
    writeln('OK: Header size is correct.');
end.
