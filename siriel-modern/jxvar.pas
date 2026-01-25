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

  { Time structure for timer }
  time_struct = record
    h, m, s, o: word;
  end;

var
  palx, blackx: tpalette;
  sr: searchrec;

  { Game state variables }
  poloha: word;          { Current animation frame }
  anim_count: word;      { Animation counter }
  bloing: word;          { Animation index }
  anic: word;            { Creature animation counter }

  { Timer variables }
  timer: integer;        { Level countdown timer (seconds) }
  tim, tim2: time_struct; { Time tracking for timer }

  { Power-up timers }
  freez_time: integer;   { Freeze power-up timer }
  god_time: integer;     { God mode power-up timer }

  { Game state flags }
  shut_down_siriel: boolean;  { Flag to redraw player character }

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
