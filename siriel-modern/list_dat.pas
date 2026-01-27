program list_dat;

{$mode objfpc}{$H+}

{ List all blocks in a .DAT file }

uses
  SysUtils;

type
  TKey = array[1..8] of char;

  TResource = record
    Key: TKey;
    Start: LongInt;
    Size: LongInt;
  end;

var
  f: file;
  NumBlocks: Word;
  ResHeader: TResource;
  Index: integer;
  i: integer;
  dat_filename: string;
  filter_term: string;

function KeyToString(k: TKey): string;
var
  s: string;
  i: integer;
begin
  s := '';
  for i := 1 to 8 do
  begin
    if k[i] <> #0 then
      s := s + k[i];
  end;
  KeyToString := Trim(s);
end;

begin
  { Get parameters }
  if ParamCount < 1 then
  begin
    writeln('Usage: ', ParamStr(0), ' <dat_file> [filter_term]');
    writeln('Example: ', ParamStr(0), ' SIRIEL35.DAT');
    writeln('         ', ParamStr(0), ' SIRIEL35.DAT GTEXT');
    exit;
  end;

  dat_filename := ParamStr(1);
  filter_term := '';
  if ParamCount >= 2 then
    filter_term := UpperCase(ParamStr(2));

  { Open file }
  if not FileExists(dat_filename) then
  begin
    writeln('ERROR: File not found: ', dat_filename);
    exit;
  end;

  AssignFile(f, dat_filename);
  {$I-}
  Reset(f, 1);
  {$I+}

  if IOResult <> 0 then
  begin
    writeln('ERROR: Failed to open file: ', dat_filename);
    exit;
  end;

  { Read number of blocks }
  BlockRead(f, NumBlocks, SizeOf(NumBlocks));

  if IOResult <> 0 then
  begin
    writeln('ERROR: Failed to read block count');
    CloseFile(f);
    exit;
  end;

  writeln('DAT file: ', dat_filename);
  writeln('Total blocks: ', NumBlocks);
  writeln;

  { Read and display each block }
  Index := 0;
  while Index < NumBlocks do
  begin
    Index := Index + 1;
    BlockRead(f, ResHeader, SizeOf(ResHeader));

    if IOResult <> 0 then
    begin
      writeln('ERROR: Failed to read block header at index ', Index);
      CloseFile(f);
      exit;
    end;

    { Apply filter if specified }
    if (filter_term = '') or
       (Pos(filter_term, UpperCase(KeyToString(ResHeader.Key))) > 0) then
    begin
      writeln('Block #', Index:3, ': "',
              KeyToString(ResHeader.Key), '" ',
              'offset=', ResHeader.Start:6,
              ' size=', ResHeader.Size:6);
    end;
  end;

  CloseFile(f);
  writeln;
  writeln('Done!');
end.
