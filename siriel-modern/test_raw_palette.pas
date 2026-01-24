program test_raw_palette;

{$mode objfpc}{$H+}

{ Test raw palette data from MAIN.DAT }

uses
  SysUtils,
  blockx;

var
  buf: array[0..767] of byte;
  i: integer;
begin
  writeln('=== Raw Palette Data Test ===');
  writeln('');

  { Load raw palette data }
  writeln('Loading raw PALETA data from MAIN.DAT...');
  if loadblock_array('data/MAIN.DAT', 'PALETA', buf) then
    writeln('Raw data loaded')
  else
  begin
    writeln('Failed to load!');
    Exit;
  end;

  writeln('');
  writeln('First 48 bytes (16 colors x 3 channels):');
  for i := 0 to 47 do
  begin
    write(buf[i]:3, ' ');
    if (i + 1) mod 3 = 0 then
    begin
      write(' | ');
      if (i + 1) mod 24 = 0 then
        writeln;
    end;
  end;

  writeln('');
  writeln('');
  writeln('Last 48 bytes (entry 255):');
  for i := 768-48 to 767 do
  begin
    write(buf[i]:3, ' ');
    if (i + 1) mod 3 = 0 then
    begin
      write(' | ');
      if (i + 1) mod 24 = 0 then
        writeln;
    end;
  end;

  writeln('');
  writeln('');
  writeln('Raw first color (entry 0): R=', buf[0], ' G=', buf[1], ' B=', buf[2]);
  writeln('Raw last color (entry 255): R=', buf[765], ' G=', buf[766], ' B=', buf[767]);

  writeln('');
  writeln('After shr 2:');
  writeln('Entry 0: R=', buf[0] shr 2, ' G=', buf[1] shr 2, ' B=', buf[2] shr 2);
  writeln('Entry 255: R=', buf[765] shr 2, ' G=', buf[766] shr 2, ' B=', buf[767] shr 2);

  writeln('');
  writeln('After shr 2 and x4:');
  writeln('Entry 0: R=', (buf[0] shr 2) * 4, ' G=', (buf[1] shr 2) * 4, ' B=', (buf[2] shr 2) * 4);
  writeln('Entry 255: R=', (buf[765] shr 2) * 4, ' G=', (buf[766] shr 2) * 4, ' B=', (buf[767] shr 2) * 4);

  writeln('');
  writeln('=== Test Complete ===');
end.
