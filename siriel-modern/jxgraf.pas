unit jxgraf;

{$mode objfpc}{$H+}

{ This unit implements the original JXGRAF API using Raylib as the backend }
{ All function signatures from the original JXGRAF.PAS are preserved }
{ Implementation wraps Raylib calls to maintain compatibility }

interface

uses
  ctypes,
  raylib_helpers,
  SysUtils;

type
  { Original JXGRAF types }
  PByteArray = ^ByteArray;
  ByteArray = array[0..0] of byte;

  tline = array[0..1023] of longint;

  { Original Image type - compatible with JXGRAF API }
  { This is NOT the same as Raylib's Image - it's our own bitmap }
  PImage = ^TImage;
  TImage = record
    data: pointer;         { Pixel data in RGBA format }
    width: cint;          { Width in pixels }
    height: cint;         { Height in pixels }
    mipmaps: cint;        { For compatibility, not used }
    format: cint;         { For compatibility, always 7 (RGBA) }
  end;

  { Function pointer types for compatibility }
  tputpixel = procedure(bitmap: PImage; x, y: word; couleur: longint);
  tgetpixel = function(bitmap: PImage; x, y: word): longint;

  { Screen structure }
  screen_rec = record
    width, height: word;
    putpixel: tputpixel;
    getpixel: tgetpixel;
    lines: array[0..767] of pointer;
    x, y: word;
  end;

  PScreenImage = ^screen_rec;

{ === ORIGINAL JXGRAF API - PRESERVED === }
{ These functions maintain exact signature compatibility with original JXGRAF.PAS }

{ Bitmap creation/destruction }
function create_bitmap(width, height: word): PImage;
procedure destroy_bitmap(bitmap: PImage);

{ Pixel operations }
procedure putpixel(bitmap: PImage; x, y: word; couleur: longint);
function getpixel(bitmap: PImage; x, y: word): longint;

{ Line operations }
procedure write_line(bitmap: PImage; var line: tline; ordonnee: word; number: word);
procedure write_linepos(bitmap: PImage; var line: tline; abscisse, ordonnee: word; number: word);
procedure read_line(bitmap: PImage; var line: tline; ordonnee: word; number: word);
procedure read_linepos(bitmap: PImage; var line: tline; abscisse, ordonnee: word; number: word);

{ Drawing primitives }
procedure line(x1, y1, x2, y2: word; couleur: byte);
procedure rectangle(bitmap: PImage; x1, y1, x2, y2: word);
procedure rectangle2(bitmap: PImage; x1, y1, x2, y2, col: word);
procedure circle(bitmap: PImage; xc, yc, r: word; coul: longint);

{ Blitting }
procedure blit(bit1, bit2: PImage; x1, y1, x2, y2, numberx, numbery: word);

{ Palette type }
type
  tpalette = array[0..255] of record
    r, v, b: byte;
  end;

{ Global variables }
var
  screen: PScreenImage;
  screen_image: PImage;
  screen_width, screen_height: word;
  current_palette: tpalette;
  chardx, chardy: word;  { Character dimensions (8x8 font) }

{ Screen to texture rendering }
{ This converts our virtual screen to a Raylib texture and displays it }
procedure init_screen(w, h: word);
procedure RenderScreenToWindow();

{ Palette management }
function palette_to_rgba(color_index: byte): longint;
procedure fill_palette_default;

implementation

var
  screen_texture: TRaylibTexture2D; { Raylib texture for display }
  screen_lines: array[0..767] of pointer;
  screen_dirty: boolean = True;   { Flag to track if screen needs update }

{ === INTERNAL HELPER FUNCTIONS === }

{ Convert JXGRAF color (longint) to RGBA }
function ColorToRGBA(couleur: longint): cuint;
begin
  { JXGRAF stores as: AAAAAAA RRRRRRRR GGGGGGGG BBBBBBBB }
  ColorToRGBA := couleur;
end;

{ Create RGBA color from components }
function MakeRGBA(r, g, b, a: byte): longint;
begin
  MakeRGBA := (a shl 24) or (r shl 16) or (g shl 8) or b;
end;

{ === BITMAP MANAGEMENT === }

function create_bitmap(width, height: word): PImage;
begin
  New(Result);
  Result^.width := width;
  Result^.height := height;
  Result^.mipmaps := 1;
  Result^.format := 7; { RGBA }
  
  { Allocate pixel data }
  GetMem(Result^.data, width * height * 4);
  FillChar(Result^.data^, width * height * 4, 0);
end;

procedure destroy_bitmap(bitmap: PImage);
begin
  if Assigned(bitmap) then
  begin
    if Assigned(bitmap^.data) then
      FreeMem(bitmap^.data);
    Dispose(bitmap);
  end;
end;

{ === PIXEL OPERATIONS === }

procedure putpixel(bitmap: PImage; x, y: word; couleur: longint);
var
  data: PByte;
  offset: longint;
begin
  if not Assigned(bitmap) then Exit;
  if x >= bitmap^.width then Exit;
  if y >= bitmap^.height then Exit;

  data := PByte(bitmap^.data);
  offset := (y * bitmap^.width + x) * 4;

  { Store in RGBA format }
  Inc(data, offset);
  data^ := (couleur shr 16) and $FF;     { R }
  Inc(data);
  data^ := (couleur shr 8) and $FF;      { G }
  Inc(data);
  data^ := couleur and $FF;              { B }
  Inc(data);
  data^ := (couleur shr 24) and $FF;     { A }

  { Mark screen as dirty if this is the screen }
  if bitmap = screen_image then
    screen_dirty := True;
end;

function getpixel(bitmap: PImage; x, y: word): longint;
var
  data: PByte;
  offset: longint;
  r, g, b, a: byte;
begin
  getpixel := 0;

  if not Assigned(bitmap) then Exit;
  if x >= bitmap^.width then Exit;
  if y >= bitmap^.height then Exit;

  data := PByte(bitmap^.data);
  offset := (y * bitmap^.width + x) * 4;
  Inc(data, offset);

  r := data^;
  Inc(data);
  g := data^;
  Inc(data);
  b := data^;
  Inc(data);
  a := data^;

  getpixel := (a shl 24) or (r shl 16) or (g shl 8) or b;
end;

{ === LINE OPERATIONS === }

procedure write_line(bitmap: PImage; var line: tline; ordonnee: word; number: word);
var
  x: word;
begin
  if not Assigned(bitmap) then Exit;
  if ordonnee >= bitmap^.height then Exit;

  for x := 0 to number - 1 do
    putpixel(bitmap, x, ordonnee, line[x]);
end;

procedure write_linepos(bitmap: PImage; var line: tline; abscisse, ordonnee: word; number: word);
var
  x: word;
begin
  if not Assigned(bitmap) then Exit;
  if abscisse >= bitmap^.width then Exit;
  if ordonnee >= bitmap^.height then Exit;

  for x := 0 to number - 1 do
    putpixel(bitmap, abscisse + x, ordonnee, line[x]);
end;

procedure read_line(bitmap: PImage; var line: tline; ordonnee: word; number: word);
var
  x: word;
begin
  if not Assigned(bitmap) then Exit;
  if ordonnee >= bitmap^.height then Exit;

  for x := 0 to number - 1 do
    line[x] := getpixel(bitmap, x, ordonnee);
end;

procedure read_linepos(bitmap: PImage; var line: tline; abscisse, ordonnee: word; number: word);
var
  x: word;
begin
  if not Assigned(bitmap) then Exit;
  if abscisse >= bitmap^.width then Exit;
  if ordonnee >= bitmap^.height then Exit;

  for x := 0 to number - 1 do
    line[x] := getpixel(bitmap, abscisse + x, ordonnee);
end;

{ === DRAWING PRIMITIVES === }

{ Draw line directly to Raylib (not to bitmap) }
procedure line(x1, y1, x2, y2: word; couleur: byte);
var
  color: cuint;
begin
  { Assume 8-bit palette color, convert to grayscale }
  color := MakeRGBA(couleur, couleur, couleur, 255);
  raylib_helpers.DrawLine(x1, y1, x2, y2, color);
end;

procedure rectangle(bitmap: PImage; x1, y1, x2, y2: word);
var
  x, y: word;
begin
  if not Assigned(bitmap) then Exit;

  { Draw outline }
  for x := x1 to x2 do
  begin
    putpixel(bitmap, x, y1, $FFFFFF);
    putpixel(bitmap, x, y2, $FFFFFF);
  end;
  for y := y1 to y2 do
  begin
    putpixel(bitmap, x1, y, $FFFFFF);
    putpixel(bitmap, x2, y, $FFFFFF);
  end;
  
  if bitmap = screen_image then
    screen_dirty := True;
end;

procedure rectangle2(bitmap: PImage; x1, y1, x2, y2, col: word);
var
  x, y: word;
  color: longint;
begin
  if not Assigned(bitmap) then Exit;

  { Convert 16-bit color to RGBA }
  color := MakeRGBA(col and $FF, (col shr 8) and $FF, (col shr 16) and $FF, 255);

  for y := y1 to y2 do
    for x := x1 to x2 do
      putpixel(bitmap, x, y, color);
      
  if bitmap = screen_image then
    screen_dirty := True;
end;

procedure circle(bitmap: PImage; xc, yc, r: word; coul: longint);
var
  x, y: longint;
  d: longint;
begin
  if not Assigned(bitmap) then Exit;

  x := 0;
  y := r;
  d := 3 - 2 * r;

  while x <= y do
  begin
    putpixel(bitmap, xc + x, yc + y, coul);
    putpixel(bitmap, xc - x, yc + y, coul);
    putpixel(bitmap, xc + x, yc - y, coul);
    putpixel(bitmap, xc - x, yc - y, coul);
    putpixel(bitmap, xc + y, yc + x, coul);
    putpixel(bitmap, xc - y, yc + x, coul);
    putpixel(bitmap, xc + y, yc - x, coul);
    putpixel(bitmap, xc - y, yc - x, coul);

    if d < 0 then
      d := d + 4 * x + 6
    else
    begin
      d := d + 4 * (x - y) + 10;
      dec(y);
    end;
    inc(x);
  end;
  
  if bitmap = screen_image then
    screen_dirty := True;
end;

{ === BLITTING === }

procedure blit(bit1, bit2: PImage; x1, y1, x2, y2, numberx, numbery: word);
var
  x, y: word;
  color: longint;
begin
  if not Assigned(bit1) then Exit;
  if not Assigned(bit2) then Exit;

  for y := 0 to numbery - 1 do
    for x := 0 to numberx - 1 do
    begin
      color := getpixel(bit1, x1 + x, y1 + y);
      putpixel(bit2, x2 + x, y2 + y, color);
    end;
    
  if bit2 = screen_image then
    screen_dirty := True;
end;

{ === SCREEN MANAGEMENT === }

{ Initialize virtual screen }
procedure init_screen(w, h: word);
begin
  screen_width := w;
  screen_height := h;

  { Create virtual screen bitmap }
  screen_image := create_bitmap(w, h);

  { Initialize screen structure }
  New(screen);
  screen^.width := w;
  screen^.height := h;
  screen^.x := 0;
  screen^.y := 0;
  screen^.putpixel := nil;
  screen^.getpixel := nil;

  { Initialize character dimensions (8x8 font) }
  chardx := 8;
  chardy := 8;

  { Initialize line pointers to point to screen rows }
  FillChar(screen_lines, SizeOf(screen_lines), 0);
  Move(screen_lines, screen^.lines, SizeOf(screen^.lines));

  screen_dirty := True;
end;

{ Render virtual screen directly to Raylib }
{ This reads our virtual screen bitmap and draws each pixel to Raylib }
{ Simplified approach: no texture management, just direct drawing }
procedure RenderScreenToWindow;
var
  x, y: longint;
  pixel_data: PByte;
  color: cuint;
  r, g, b, a: byte;
begin
  { Read virtual screen and draw directly to Raylib }
  pixel_data := PByte(screen_image^.data);

  for y := 0 to screen_image^.height - 1 do
  begin
    for x := 0 to screen_image^.width - 1 do
    begin
      { Read RGBA from bitmap }
      r := pixel_data^;
      Inc(pixel_data);
      g := pixel_data^;
      Inc(pixel_data);
      b := pixel_data^;
      Inc(pixel_data);
      a := pixel_data^;
      Inc(pixel_data);

      { Only draw non-transparent pixels }
      if a > 0 then
      begin
        color := (a shl 24) or (r shl 16) or (g shl 8) or b;
        raylib_helpers.DrawPixel(x, y, color);
      end;
    end;
  end;

  screen_dirty := False;
end;

{ Convert palette color index to RGBA }
function palette_to_rgba(color_index: byte): longint;
var
  r, g, b: byte;
begin
  r := current_palette[color_index].r shl 2; { Convert 6-bit to 8-bit }
  g := current_palette[color_index].v shl 2;
  b := current_palette[color_index].b shl 2;

  palette_to_rgba := (longint(255) shl 24) or (longint(r) shl 16) or (longint(g) shl 8) or b;
end;

{ Fill default VGA palette }
procedure fill_palette_default;
var
  i: integer;
begin
  for i := 0 to 15 do
  begin
    case i of
      0:  begin current_palette[i].r := 0;  current_palette[i].v := 0;  current_palette[i].b := 0;  end; { Black }
      1:  begin current_palette[i].r := 0;  current_palette[i].v := 0;  current_palette[i].b := 42; end; { Blue }
      2:  begin current_palette[i].r := 0;  current_palette[i].v := 42; current_palette[i].b := 0;  end; { Green }
      3:  begin current_palette[i].r := 0;  current_palette[i].v := 42; current_palette[i].b := 42; end; { Cyan }
      4:  begin current_palette[i].r := 42; current_palette[i].v := 0;  current_palette[i].b := 0;  end; { Red }
      5:  begin current_palette[i].r := 42; current_palette[i].v := 0;  current_palette[i].b := 42; end; { Magenta }
      6:  begin current_palette[i].r := 42; current_palette[i].v := 21; current_palette[i].b := 0;  end; { Brown }
      7:  begin current_palette[i].r := 42; current_palette[i].v := 42; current_palette[i].b := 42; end; { Light gray }
      8:  begin current_palette[i].r := 21; current_palette[i].v := 21; current_palette[i].b := 21; end; { Dark gray }
      9:  begin current_palette[i].r := 21; current_palette[i].v := 21; current_palette[i].b := 63; end; { Light blue }
      10: begin current_palette[i].r := 21; current_palette[i].v := 63; current_palette[i].b := 21; end; { Light green }
      11: begin current_palette[i].r := 21; current_palette[i].v := 63; current_palette[i].b := 63; end; { Light cyan }
      12: begin current_palette[i].r := 63; current_palette[i].v := 21; current_palette[i].b := 21; end; { Light red }
      13: begin current_palette[i].r := 63; current_palette[i].v := 21; current_palette[i].b := 63; end; { Light magenta }
      14: begin current_palette[i].r := 63; current_palette[i].v := 63; current_palette[i].b := 21; end; { Yellow }
      15: begin current_palette[i].r := 63; current_palette[i].v := 63; current_palette[i].b := 63; end; { White }
    end;
  end;

  { Fill rest with grayscale }
  for i := 16 to 255 do
  begin
    current_palette[i].r := (i - 16) div 4;
    current_palette[i].v := (i - 16) div 4;
    current_palette[i].b := (i - 16) div 4;
  end;
end;

initialization
  fill_palette_default;
  init_screen(640, 480);

finalization
  { Cleanup }
  if Assigned(screen_image) then
    destroy_bitmap(screen_image);
  if Assigned(screen) then
    Dispose(screen);
  { Note: screen_texture cleanup not needed with direct rendering }

end.
