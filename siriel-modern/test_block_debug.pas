program test_block_debug;

{$mode objfpc}{$H+}

{ Debug block file reading }

uses
  SysUtils,
  blockx;

type
  TResource = record
    Key: TKey;
    Start: LongInt;
    Size: LongInt;
  end;

var
  NumSounds: Word;  { Changed from integer to Word for 16-bit Turbo Pascal compatibility }
  fil: file;
  i, j: integer;
  Found: boolean;
  ResKey: TKey;
  ResHeader: TResource;

begin
  writeln('=== Block File Debug ===');
  writeln('');

  { Open file and read block count }
  AssignFile(fil, 'data/MAIN.DAT');
  {$I-}
  Reset(fil, 1);

  BlockRead(fil, NumSounds, SizeOf(NumSounds));

  writeln('Block count: ', NumSounds);
  writeln('');

  { Read and display all block headers }
  for i := 1 to NumSounds do
  begin
    BlockRead(fil, ResHeader, SizeOf(ResHeader));

    write('Block ', i, ': Key="');
    for j := 1 to 8 do
      if ResHeader.Key[j] <> #0 then
        write(ResHeader.Key[j]);
    write('" ');
    writeln('Start=', ResHeader.Start, ' ($', IntToHex(ResHeader.Start, 8), ') Size=', ResHeader.Size, ' ($', IntToHex(ResHeader.Size, 4), ')');
  end;

  CloseFile(fil);
  {$I+}

  writeln('');
  writeln('=== Testing GLOGO Search ===');
  writeln('');

  { Now test searching for GLOGO }
  Found := false;
  for i := 1 to 8 do
    if i <= 5 then
      ResKey[i] := 'GLOGO'[i]
    else
      ResKey[i] := #0;

  writeln('Searching for key: GLOGO');

  AssignFile(fil, 'data/MAIN.DAT');
  {$I-}
  Reset(fil, 1);
  BlockRead(fil, NumSounds, SizeOf(NumSounds));

  writeln('NumSounds: ', NumSounds);
  writeln('');

  for i := 1 to NumSounds do
  begin
    BlockRead(fil, ResHeader, SizeOf(ResHeader));

    write('Block ', i, ': Key="');
    for j := 1 to 8 do
      if ResHeader.Key[j] <> #0 then
        write(ResHeader.Key[j]);
    write('" ');

    if MatchingKeys(ResHeader.Key, ResKey) then
    begin
      writeln('  >>> MATCH! <<<');
      writeln('  Start offset: ', ResHeader.Start, ' ($', IntToHex(ResHeader.Start, 8), ')');
      writeln('  Size: ', ResHeader.Size, ' ($', IntToHex(ResHeader.Size, 4), ')');
      Found := true;
      Break;
    end
    else
      writeln('');
  end;

  CloseFile(fil);
  {$I+}

  if Found then
    writeln('Found GLOGO!')
  else
    writeln('GLOGO not found');
end.
