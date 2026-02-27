program test_gzal;

{$mode objfpc}{$H+}

uses
  SysUtils, jxgraf, jxfont_simple, blockx;

var
  pal: jxfont_simple.tpalette;

begin
  writeln('Testing GZAL loading...');

  init_screen(640, 480);

  if blockx.draw_gif_block(screen_image, 'data/MAIN.DAT', 'GZAL', 0, 0, pal) then
    writeln('SUCCESS: GZAL loaded!')
  else
    writeln('FAILED: GZAL not found');

  readln;
end.
