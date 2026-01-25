unit jxvar;

{$mode objfpc}{$H+}

interface

uses
  dos,
  jxgraf;  { For tpalette type }

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
  num_lang         = 5;  { Number of supported languages }

type
  { Time structure for timer }
  time_struct = record
    h, m, s, o: word;
  end;

var
  palx, blackx: tpalette;
  sr: searchrec;

  { Text output variables }
  tx2: array[1..3, 1..30] of string;  { Alternative text array }

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

  { Language and text variables }
  tx: array[1..3, 1..30] of string;  { Text strings for multiple languages }
  language: array[1..5] of string;   { Supported language codes }
  ja: integer;                        { Current language index }

  { Sound variables }
  zvukovy_subor: string;   { DAT file containing sounds }
  zvuky: array[0..50] of string;  { Sound effect names }
  basic_snd: integer;       { Base sound index }

  { Constants }
  nos: string;              { Empty/none constant }

  { Text file variable }
  t: text;                  { Generic text file for level loading }

  { Font variables }
  fontik: pointer;          { Font handle }

implementation

{ Helper procedure to initialize black palette }
procedure fill_palette_black(var pal: tpalette);
var
  i: integer;
begin
  for i := 0 to 255 do
  begin
    pal[i].r := 0;
    pal[i].v := 0;  { Use "v" not "g" for green component }
    pal[i].b := 0;
  end;
end;

begin
  fill_palette_black(blackx);

  { Initialize language array }
  language[1] := 'ENG';
  language[2] := 'SVK';
  language[3] := 'CZE';
  language[4] := 'GER';
  language[5] := 'FRE';
  ja := 1;  { Default to English }

  { Initialize sound variables }
  zvukovy_subor := '';
  basic_snd := 0;

  { Initialize constant }
  nos := 'NOS';

  { Initialize font variables }
  fontik := nil;
end.
