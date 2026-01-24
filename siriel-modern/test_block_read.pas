program test_block_read;

{$mode objfpc}{$H+}

{ Simple test to read GLOGO block }

uses
  SysUtils,
  blockx;

var
  fil: file;
  NumSounds: integer;
  ResHeader: TResource;
  Index: integer;
  ResKey: TKey;
  i: integer;
  Found: boolean;
  data: pointer;
  DataSize: longint;
  BytesRead: longint;

begin
  writeln('=== Block Read Test ===');
  writeln('');

  { Prepare GLOGO key }
  for i := 1 to 8 do
  begin
    if i <= 5 then
      ResKey[i] := 'GLOGO'[i]
    else
      ResKey[i] := #0;
  end;

  writeln('Searching for key: GLOGO');
  for i := 1 to 8 do
    write('"', ResKey[i], '" ');
  writeln('');

  { Open MAIN.DAT }
  AssignFile(fil, 'data/MAIN.DAT');
  {$I-}
  Reset(fil, 1);
  {$I+}

  if IOResult <> 0 then
  begin
    writeln('ERROR: Cannot open MAIN.DAT');
    Exit;
  end;

  { Read block count }
  BlockRead(fil, NumSounds, SizeOf(NumSounds));
  writeln('Total blocks in file: ', NumSounds);
  writeln('');

  { Search for GLOGO }
  Found := false;
  Index := 0;

  while not(Found) and (Index < NumSounds) do
  begin
    Inc(Index);
    BlockRead(fil, ResHeader, SizeOf(ResHeader));

    if IOResult <> 0 then
    begin
      writeln('ERROR reading block header at index ', Index);
      Break;
    end;

    { Show what we found }
    write('Block ', Index:2, ': Key="');
    for i := 1 to 8 do
      if ResHeader.Key[i] <> #0 then
        write(ResHeader.Key[i]);
    write('" ');
    writeln('Start=', ResHeader.Start:5, ' Size=', ResHeader.Size:5);

    if MatchingKeys(ResHeader.Key, ResKey) then
    begin
      writeln('  >>> FOUND GLOGO! <<<');
      Found := true;
    end;
  end;

  CloseFile(fil);

  if Found then
  begin
    writeln('');
    writeln('GLOGO block found at index ', Index);
    writeln('  Start offset: ', ResHeader.Start);
    writeln('  Size: ', ResHeader.Size, ' bytes');
  end
  else
    writeln('GLOGO not found!');
end.
