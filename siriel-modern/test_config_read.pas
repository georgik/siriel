program test_config_read;

{$mode objfpc}{$H+}

{ Test program to read CONFIG block from SIRIEL35.DAT }

uses
  SysUtils,
  blockx,
  koder;

var
  buffer: array[0..32767] of byte;
  i: integer;
begin
  writeln('=== CONFIG Block Reader ===');
  writeln('');

  { Initialize block file system }
  openblockfile('data/SIRIEL35.DAT');

  { Try to load CONFIG block }
  writeln('Loading CONFIG block from SIRIEL35.DAT...');
  fillchar(buffer, sizeof(buffer), 0);

  if loadblock_array('data/SIRIEL35.DAT', 'CONFIG', buffer) then
  begin
    writeln('CONFIG block loaded successfully!');
    writeln('Decrypting with Caesar cipher...');
    writeln('');

    { Decrypt using dekoduj like load_level_list does }
    for i := 0 to 32767 do
    begin
      if buffer[i] <> 0 then
        koder.dekoduj(1, buffer[i]);
    end;

    { Display first 2000 bytes as text }
    writeln('CONFIG content (first 2000 bytes):');
    writeln('======================================');
    for i := 0 to 1999 do
    begin
      if buffer[i] >= 32 then
        write(chr(buffer[i]))
      else if buffer[i] = 13 then
        writeln
      else if buffer[i] = 10 then
        writeln;

      if buffer[i] = 0 then
        break;
    end;
    writeln('');
    writeln('======================================');
  end
  else
    writeln('ERROR: Failed to load CONFIG block');

  closeblockfile;

  writeln('');
  writeln('Press Enter to exit...');
  readln;
end.
