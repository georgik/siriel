program test_dat_blocks;

{$mode objfpc}{$H+}

{ Test program to list all blocks in SIRIEL35.DAT }

uses
  SysUtils,
  Dos;

var
  datFile: string;
  blockNames: array[1..100] of string;
  blockCount: integer;

function GetBlockNamesFromFile(const filename: string): integer;
var
  f: file;
  buffer: array[0..9999] of byte;
  bytes_read: integer;
  i: integer;
  block_name: string;
begin
  Result := 0;

  Assign(f, filename);
  Reset(f, 1);

  if IOResult <> 0 then
  begin
    writeln('Error: Cannot open file: ', filename);
    exit;
  end;

  BlockRead(f, buffer, 10000, bytes_read);
  Close(f);

  writeln('');
  writeln('DAT File Analysis: ', filename);
  writeln('======================================');
  writeln('Total bytes read: ', bytes_read);
  writeln('');

  { Look for block names - 4-6 letter uppercase names }
  i := 0;
  while i < bytes_read - 4 do
  begin
    if (buffer[i] >= ord('A')) and (buffer[i] <= ord('Z')) and
       (buffer[i+1] >= ord('A')) and (buffer[i+1] <= ord('Z')) and
       (buffer[i+2] >= ord('A')) and (buffer[i+2] <= ord('Z')) and
       (buffer[i+3] >= ord('A')) and (buffer[i+3] <= ord('Z')) then
    begin
      { Found potential block name }
      block_name := '';
      while (i < bytes_read) and (buffer[i] >= ord('A')) and (buffer[i] <= ord('Z')) do
      begin
        block_name := block_name + chr(buffer[i]);
        inc(i);
      end;

      if (length(block_name) >= 4) and (length(block_name) <= 8) then
      begin
        inc(Result);
        if Result <= 100 then
        begin
          blockNames[Result] := block_name;
          writeln('Block ', Result:3, ': ', block_name);
        end;
      end;
      continue;
    end;
    inc(i);
  end;
end;

begin
  writeln('=== SIRIEL35.DAT Block Explorer ===');
  writeln('');

  datFile := 'data/SIRIEL35.DAT';

  if FileExists(datFile) then
  begin
    blockCount := GetBlockNamesFromFile(datFile);
    writeln('');
    writeln('Total blocks found: ', blockCount);
  end
  else
    writeln('File not found: ', datFile);

  writeln('');
  writeln('Press Enter to exit...');
  Readln;
end.
