unit jxvar;

{$mode objfpc}{$H+}

interface

uses
  dos;

{ Key codes - standard scancodes }
const
  kb_up            = $4800;
  kb_down          = $5000;
  kb_left          = $4b00;
  kb_right         = $4d00;
  kb_esc           = $011B;
  kb_enter         = $1C0D;
  kb_back          = $0E08;
  kb_space         = $3920;
  kb_tab           = $0F09;
  
type
  tpalette = array[0..255] of record
    r, g, b: byte;
  end;

var
  palx, blackx: tpalette;
  sr: searchrec;

implementation

{ Helper procedure to initialize black palette }
procedure fill_palette_black(var pal: tpalette);
var
  i: integer;
begin
  for i := 0 to 255 do
  begin
    pal[i].r := 0;
    pal[i].g := 0;
    pal[i].b := 0;
  end;
end;

begin
  fill_palette_black(blackx);
end.
