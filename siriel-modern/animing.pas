unit animing;

{$mode objfpc}{$H+}

{ This unit implements the original ANIMING.PAS API }
{ All function signatures are preserved for compatibility with SI35.PAS }

interface

uses
  jxgraf,
  SysUtils;

{ === ORIGINAL ANIMING API - PRESERVED === }
{ These functions maintain exact signature compatibility }

{ Sector operations - read/write rectangular regions to/from arrays }
procedure getseg(gx, gy, gd, gs, num: word; var aw: array of byte);
procedure putseg(gx, gy, gd, gs, num: word; var aw: array of byte);

{ Transparent color versions }
procedure getseg2(gx, gy, gd, gs, num, col: word; var aw: array of byte);
procedure putseg2(gx, gy, gd, gs, num, col: word; var aw: array of byte);
procedure putseg3(gx, gy, gd, gs, num, col, col2: word; var aw: array of byte);

{ Mirror/flip versions }
procedure putseg2_rev(gx, gy, gd, gs, num, col: word; var aw: array of byte);

{ Mix/blend versions }
procedure putseg2_mix(gx, gy, gd, gs, num, col: word; var aw: array of byte; num2: word; var av: array of byte);
procedure putseg2_rev_mix(gx, gy, gd, gs, num, col: word; var aw: array of byte; num2: integer; var av: array of byte);

{ Color query }
function getcol(gx, gy, num: word; var am: array of byte): word;

{ Character/sprite management }
procedure charakter(chx, chy, choldx, choldy, chpoloha, chbuf: word; var am: array of byte);
procedure init_charakter(chsizex, chsizey, chx, chy, chpoloha, chbuf: word; var am: array of byte);
procedure vypni_charakter(choldx, choldy, chbuf: word; var am: array of byte);
procedure zapni_charakter(chx, chy, num, chbuf: word; var am: array of byte);

{ XMS versions - for compatibility, using standard memory }
procedure getsegxms(var kluka; gx, gy, gd, gs, num: longint);
procedure putsegxms(var kluka; gx, gy, gd, gs, num: longint);
procedure getseg2xms(var kluka; gx, gy, gd, gs, num, col: word);
procedure putseg2xms(var kluka; gx, gy, gd, gs, num, col: longint);
procedure putseg2_revxms(var kluka; gx, gy, gd, gs, num, col: word);
procedure putseg2_mixxms(var kluka, kluka2; gx, gy, gd, gs, num, col, num2: word);
procedure putseg2_rev_mixxms(var kluka, kluka2; gx, gy, gd, gs, num, col, num2: word);

{ Global variables }
var
  sizex, sizey: word;      { Current sprite size }
  lajna, lajno: tline;    { Line buffers }

implementation

type
  TKlucka = record
    data: pointer;
    size: longint;
  end;

{ === SECTOR OPERATIONS === }

{ getseg - Read rectangular region from screen to array }
{ Parameters:
  gx, gy   - top-left corner position on screen
  gd, gs   - width and height of region
  num      - frame index (for multi-frame sprites)
  aw       - output array to store pixel data
}
procedure getseg(gx, gy, gd, gs, num: word; var aw: array of byte);
var
  gf, gff, cxx, cxx2: word;
begin
  cxx := num * gd * gs;

  for gf := 0 to gs - 1 do
  begin
    read_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
    cxx2 := cxx + gf * gs;

    for gff := 0 to gd - 1 do
    begin
      { Extract color index from pixel data }
      aw[cxx2 + gff] := lajna[gff] and $FF;
    end;
  end;
end;

{ putseg - Write rectangular region from array to screen }
{ Parameters:
  gx, gy   - top-left corner position on screen
  gd, gs   - width and height of region
  num      - frame index (for multi-frame sprites)
  aw       - input array with pixel data
}
procedure putseg(gx, gy, gd, gs, num: word; var aw: array of byte);
var
  gf, gff, cxx, cxx2: word;
begin
  cxx := num * gd * gs;

  for gf := 0 to gs - 1 do
  begin
    cxx2 := cxx + gf * gs;

    for gff := 0 to gs - 1 do
      lajna[gff] := aw[cxx2 + gff];

    write_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
  end;
end;

{ getseg2 - Read region, ignoring transparent color }
procedure getseg2(gx, gy, gd, gs, num, col: word; var aw: array of byte);
var
  gf, gff, cxx, cxx2: word;
  pixel_val: longint;
begin
  cxx := num * gd * gs;

  for gf := 0 to gs - 1 do
  begin
    read_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
    cxx2 := cxx + gf * gs;

    for gff := 0 to gd - 1 do
    begin
      pixel_val := lajna[gff] and $FF;
      if pixel_val <> col then
        aw[cxx2 + gff] := pixel_val;
    end;
  end;
end;

{ putseg2 - Write region with transparency }
{ Pixels equal to 'col' are not written (transparent) }
procedure putseg2(gx, gy, gd, gs, num, col: word; var aw: array of byte);
var
  gf, gff, cxx, cxx2: word;
begin
  cxx := num * gd * gs;

  for gf := 0 to gs - 1 do
  begin
    { Read current screen content }
    read_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
    cxx2 := cxx + gf * gs;

    for gff := 0 to gs - 1 do
    begin
      { Only write non-transparent pixels }
      if aw[cxx2 + gff] <> col then
        lajna[gff] := aw[cxx2 + gff];
    end;

    write_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
  end;
end;

{ putseg3 - Write with color substitution }
{ All non-col pixels are replaced with col2 }
procedure putseg3(gx, gy, gd, gs, num, col, col2: word; var aw: array of byte);
var
  gf, gff, cxx2, cxx: word;
begin
  cxx := num * gd * gs;

  for gf := 0 to gs - 1 do
  begin
    read_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
    cxx2 := cxx + gf * gs;

    for gff := 0 to gs - 1 do
    begin
      if aw[cxx2 + gff] <> col then
        lajna[gff] := col2;
    end;

    write_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
  end;
end;

{ putseg2_rev - Write mirrored (horizontal flip) with transparency }
procedure putseg2_rev(gx, gy, gd, gs, num, col: word; var aw: array of byte);
var
  gf, gff, cxx2, cxx: word;
begin
  cxx := num * gd * gs;

  for gf := 0 to gs - 1 do
  begin
    read_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
    cxx2 := cxx + gf * gs;

    for gff := 0 to gd - 1 do
    begin
      { Mirror horizontally: read from right, write to left }
      if aw[cxx2 + (gd - 1 - gff)] <> col then
        lajna[gff] := aw[cxx2 + (gd - 1 - gff)];
    end;

    write_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
  end;
end;

{ putseg2_mix - Mix two images based on transparency }
{ Pixels equal to col in aw are replaced with pixels from av }
procedure putseg2_mix(gx, gy, gd, gs, num, col: word; var aw: array of byte; num2: word; var av: array of byte);
var
  gf, gff, cxx2, cxx, cxx3: word;
begin
  cxx := num * gd * gs;

  for gf := 0 to gs - 1 do
  begin
    cxx2 := cxx + gf * gs;
    cxx3 := num2 * gd * gs + gf * gs;

    read_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);

    for gff := 0 to gs - 1 do
    begin
      if aw[cxx2 + gff] = col then
        lajna[gff] := av[cxx3 + gff]
      else
        lajna[gff] := aw[cxx2 + gff];
    end;

    write_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
  end;
end;

{ putseg2_rev_mix - Mix two images with mirror }
procedure putseg2_rev_mix(gx, gy, gd, gs, num, col: word; var aw: array of byte; num2: integer; var av: array of byte);
var
  gf, gff, cxx2, cxx, cxx3: word;
begin
  cxx := num * gd * gs;

  for gf := 0 to gs - 1 do
  begin
    cxx2 := cxx + gf * gs;
    cxx3 := num2 * gd * gs + gf * gs;

    read_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);

    for gff := 0 to gs - 1 do
    begin
      if aw[cxx2 + (gd - 1 - gff)] = col then
        lajna[gff] := av[cxx3 + gff]
      else
        lajna[gff] := aw[cxx2 + (gd - 1 - gff)];
    end;

    write_linepos(PImage(jxgraf.screen), lajna, gx, gf + gy, gd);
  end;
end;

{ === COLOR QUERY === }

{ Get color from sprite array at given position }
function getcol(gx, gy, num: word; var am: array of byte): word;
var
  cxx: word;
begin
  cxx := num * sizex * sizey + (gy - gy div sizey * sizey) * sizex + (gx - gx div sizex * sizex);
  getcol := am[cxx];
end;

{ === CHARACTER/SPRITE MANAGEMENT === }

{ Move character from old position to new position }
procedure charakter(chx, chy, choldx, choldy, chpoloha, chbuf: word; var am: array of byte);
begin
  { Draw at new position }
  putseg(chx, chy, sizex, sizey, chpoloha, am);
  { Restore background at old position (with transparency) }
  putseg2(choldx, choldy, sizex, sizey, chbuf, 255, am);
end;

{ Initialize character/sprite }
procedure init_charakter(chsizex, chsizey, chx, chy, chpoloha, chbuf: word; var am: array of byte);
begin
  sizex := chsizex;
  sizey := chsizey;
end;

{ Hide character (restore background) }
procedure vypni_charakter(choldx, choldy, chbuf: word; var am: array of byte);
begin
  putseg2(choldx, choldy, sizex, sizey, chbuf, 255, am);
end;

{ Show character at position }
procedure zapni_charakter(chx, chy, num, chbuf: word; var am: array of byte);
begin
  putseg2(chx, chy, sizex, sizey, num, 255, am);
end;

{ === XMS VERSIONS (Using Standard Memory) === }
{ These are stubs for now - will be implemented if needed }

procedure getsegxms(var kluka; gx, gy, gd, gs, num: longint);
begin
  { TODO: Implement if needed for XMS handle support }
end;

procedure putsegxms(var kluka; gx, gy, gd, gs, num: longint);
begin
  { TODO: Implement if needed }
end;

procedure getseg2xms(var kluka; gx, gy, gd, gs, num, col: word);
begin
  { TODO: Implement if needed }
end;

procedure putseg2xms(var kluka; gx, gy, gd, gs, num, col: longint);
begin
  { TODO: Implement if needed }
end;

procedure putseg2_revxms(var kluka; gx, gy, gd, gs, num, col: word);
begin
  { TODO: Implement if needed }
end;

procedure putseg2_mixxms(var kluka, kluka2; gx, gy, gd, gs, num, col, num2: word);
begin
  { TODO: Implement if needed }
end;

procedure putseg2_rev_mixxms(var kluka, kluka2; gx, gy, gd, gs, num, col, num2: word);
begin
  { TODO: Implement if needed }
end;

end.
