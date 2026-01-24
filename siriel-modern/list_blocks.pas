program list_blocks;

{$mode objfpc}{$H+}

{ List all block keys in MAIN.DAT and SIRIEL35.DAT }

uses
  SysUtils,
  blockx;

var
  fil: file;
  NumSounds: integer;
  ResHeader: TResource;
  Index: integer;
  FoundKeys: array[1..100] of string[20];
  KeyCount: integer;

begin
  writeln('=== Block File Listing ===');
  writeln('');

  { List MAIN.DAT }
  writeln('MAIN.DAT blocks:');
  writeln('----------------');

  KeyCount := 0;
  AssignFile(fil, 'data/MAIN.DAT');
  {$I-}
  Reset(fil, 1);
  {$I+}

  if IOResult = 0 then
  begin
    BlockRead(fil, NumSounds, SizeOf(NumSounds));
    writeln('Total blocks: ', NumSounds);
    writeln('');
    writeln('Listing first 20 blocks:');
    writeln('');

    for Index := 1 to Min(20, NumSounds) do
    begin
      BlockRead(fil, ResHeader, SizeOf(ResHeader));

      if IOResult = 0 then
      begin
        Inc(KeyCount);
        FoundKeys[KeyCount] := '';
        for Index := 1 to 8 do
          if ResHeader.Key[Index] <> #0 then
            FoundKeys[KeyCount] := FoundKeys[KeyCount] + ResHeader.Key[Index];

        writeln('  Block ', Index:3, ': Key="', FoundKeys[KeyCount], '" ',
                'Start=', ResHeader.Start:5, ' ',
                'Size=', ResHeader.Size:6);
      end;
    end;

    CloseFile(fil);
  end
  else
    writeln('ERROR: Cannot open MAIN.DAT');

  writeln('');
  writeln('');

  { List SIRIEL35.DAT }
  writeln('SIRIEL35.DAT blocks:');
  writeln('--------------------');

  KeyCount := 0;
  AssignFile(fil, 'data/SIRIEL35.DAT');
  {$I-}
  Reset(fil, 1);
  {$I+}

  if IOResult = 0 then
  begin
    BlockRead(fil, NumSounds, SizeOf(NumSounds));
    writeln('Total blocks: ', NumSounds);
    writeln('');
    writeln('Listing first 30 blocks:');
    writeln('');

    for Index := 1 to Min(30, NumSounds) do
    begin
      BlockRead(fil, ResHeader, SizeOf(ResHeader));

      if IOResult = 0 then
      begin
        Inc(KeyCount);
        FoundKeys[KeyCount] := '';
        for Index := 1 to 8 do
          if ResHeader.Key[Index] <> #0 then
            FoundKeys[KeyCount] := FoundKeys[KeyCount] + ResHeader.Key[Index];

        writeln('  Block ', Index:3, ': Key="', FoundKeys[KeyCount], '" ',
                'Start=', ResHeader.Start:5, ' ',
                'Size=', ResHeader.Size:6);
      end;
    end;

    CloseFile(fil);
  end
  else
    writeln('ERROR: Cannot open SIRIEL35.DAT');

  writeln('');
  writeln('=== Listing Complete ===');
end.
