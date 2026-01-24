program test_palette;

{$mode objfpc}{$H+}

{ Test palette loading and conversion }

uses
  SysUtils,
  jxfont_simple,
  blockx;

var
  palette: tpalette;
  i: integer;
  r, g, b: byte;

begin
  writeln('=== Palette Loading Test ===');
  writeln('');

  { Load palette }
  writeln('Loading PALETA from MAIN.DAT...');
  load_palette_block('data/MAIN.DAT', 'PALETA', palette);
  writeln('Palette loaded');
  writeln('');

  { Display first 16 palette entries }
  writeln('First 16 palette entries:');
  for i := 0 to 15 do
  begin
    r := palette[i].r;
    g := palette[i].v;  { Note: 'v' is green }
    b := palette[i].b;

    write('  Entry ', i:2, ': R=', r:3, ' G=', g:3, ' B=', b:3);

    { Check if values are in VGA range (0-63) or full range (0-255) }
    if (r <= 63) and (g <= 63) and (b <= 63) then
      write('  [VGA format - needs x4 conversion]')
    else if (r > 63) or (g > 63) or (b > 63) then
      write('  [8-bit format]');

    writeln;
  end;

  writeln('');
  writeln('First entry (black):');
  writeln('  R=', palette[0].r, ' G=', palette[0].v, ' B=', palette[0].b);
  writeln('');

  writeln('Last entry (white?):');
  writeln('  R=', palette[255].r, ' G=', palette[255].v, ' B=', palette[255].b);
  writeln('');

  writeln('=== Test Complete ===');
end.
