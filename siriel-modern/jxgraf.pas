unit jxgraf;

{$mode objfpc}{$H+}

{ This unit implements the original JXGRAF API using Raylib as the backend }
{ All function signatures from the original JXGRAF.PAS are preserved }
{ Implementation wraps Raylib calls to maintain compatibility }

interface

uses
  ctypes,
  raylib_helpers,
  SysUtils,
  Math;  { For Max and Min functions }

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
procedure rectangle2(bitmap: PImage; x1, y1, x2, y2, col: word); overload;
procedure rectangle2(bitmap: PScreenImage; x1, y1, x2, y2, col: word); overload;
procedure circle(bitmap: PImage; xc, yc, r: word; coul: longint);

{ Blitting }
procedure blit(bit1, bit2: PImage; x1, y1, x2, y2, numberx, numbery: word);

{ Palette type }
type
  tpalette = array[0..255] of record
    r, v, b: byte;
  end;

  { Point type for TFrame }
  TPoint = record
    x, y: word;
  end;

  { Handle type (from original JXEFEKT.PAS) }
  klucka = word;

  { TFrame object - stub implementation }
  PFrame = ^TFrame;
  TFrame = object
    ha_frame      : klucka;
    ha_back       : klucka;
    fill_color    : byte;
    size_x,size_y : word;
    version       : byte;
    save          : boolean;
    P1,P2         : TPoint;
    killable      : boolean;
    constructor init(handle:klucka;Block_file,Gif_file:string;Asave:boolean);
    procedure   draw(x,y,dx,dy:word);
    procedure   set_params(var Framex:TFrame);
    destructor  done;
  end;

  { TPrint object - stub implementation }
  PPrint_option = ^TPrint_option;
  TPrint_option = record
    px,py         : integer;
    text_color    : byte;
    shadow_color  : byte;
    roll_color    : byte;
    shadow        : boolean;
    center        : boolean;
    input_char    : char;
  end;

  PPrint = ^TPrint;

  TPrint = object
    opt : PPrint_option;
    constructor init(PPx,PPy:integer;Tcol,CShadow,Roll:byte;Pcenter,Pshadow:boolean);
    procedure   print(x,y:word;s:string);
    procedure   print_col(x,y:word;s:string;col:byte);
    function    input(x,y:word;max_len:word):string;
    destructor  done;
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

{ Type conversion helpers for PScreenImage <-> PImage compatibility }
function ScreenImageToImage(scr: PScreenImage): PImage;
function ImageToScreenImage(img: PImage): PScreenImage;

{ Palette management }
function palette_to_rgba(color_index: byte): longint;
procedure fill_palette_default;

{ Palette manipulation functions }
procedure decrease_palette(var pal: tpalette; steps: integer);
procedure increase_palette(var pal: tpalette; steps: integer); overload;
procedure increase_palette(var pal: tpalette); overload;
procedure increase_palette(start, palx: tpalette; steps: integer); overload;
procedure write_palette(var pal: tpalette; start, count: integer);

{ GIF loading functions }
procedure draw_gif(bitmap: PScreenImage; const filename: string; x, y: word; var pal: tpalette);
procedure draw_gif_block(bitmap: PScreenImage; const datfile, blockname: string; x, y: word; var pal: tpalette);

{ Text output functions }
procedure printc(bitmap: PScreenImage; y: word; const text: string; col, back: word);
procedure printx2(bitmap: PScreenImage; x, y: word; const text: string; col, back, transparent, styl: word; delay: word);
procedure print_normal(bitmap: PScreenImage; x, y: word; const text: string; col, back: word); overload;
procedure print_normal(bitmap: PImage; x, y: word; const text: string; col, back: word); overload;

{ Drawing functions }
procedure okno(x, y, w, h, back: word);
procedure clear_bitmap(bitmap: PImage);
procedure stvorec2(bitmap: PScreenImage; x, y, w, h, col, back: word);

{ Frame and print wrapper functions (compatibility with original object methods) }
procedure old_frame_draw(x, y, dx, dy: word);
procedure old_frame_init(handle:word; const block_file, gif_file: string; asave:boolean);
procedure old_frame_done;
procedure napis_print(x, y: word; const s: string);
procedure napis2_print(x, y: word; const s: string);
function napis_input(x, y: word; max_len: word): string;
procedure napis_init(px, py: integer; tcol, cshadow, roll: byte; pcenter, pshadow: boolean);
procedure napis_done;

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

{ Overload for PScreenImage - convert to PImage and call original }
procedure rectangle2(bitmap: PScreenImage; x1, y1, x2, y2, col: word);
begin
  if not Assigned(bitmap) then Exit;
  rectangle2(ScreenImageToImage(bitmap), x1, y1, x2, y2, col);
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

{ ========================================
   PALETTE MANIPULATION FUNCTIONS
   ======================================== }

procedure decrease_palette(var pal: tpalette; steps: integer);
begin
  { Stub: Original palette darkening for fade-out effects }
  { In modern Raylib, use alpha blending instead }
  { For now, no-op - visual effects can be added later }
end;

procedure increase_palette(var pal: tpalette; steps: integer);
begin
  { Stub: Original palette brightening for fade-in effects }
  { In modern Raylib, use alpha blending instead }
  { For now, no-op - visual effects can be added later }
end;

procedure increase_palette(var pal: tpalette);
begin
  { Stub: Default fade-in }
  { In modern Raylib, use alpha blending instead }
end;

{ 3-parameter version: copy from source palette to destination }
procedure increase_palette(start, palx: tpalette; steps: integer);
var
  i: integer;
begin
  { Copy source palette to destination }
  { In original, this would fade between palettes }
  { For modern implementation, just copy directly }
  for i := 0 to 255 do
  begin
    palx[i].r := start[i].r;
    palx[i].v := start[i].v;
    palx[i].b := start[i].b;
  end;
end;

procedure write_palette(var pal: tpalette; start, count: integer);
var
  i: integer;
begin
  { Copy palette to current palette }
  for i := start to Min(255, start + count - 1) do
    current_palette[i] := pal[i];
end;

{ ========================================
   GIF LOADING FUNCTIONS (Stubs)
   ======================================== }

procedure draw_gif(bitmap: PScreenImage; const filename: string; x, y: word; var pal: tpalette);
begin
  { TODO: Implement GIF loading from file }
  { For now, this is a stub }
  writeln('STUB: draw_gif(', filename, ') at (', x, ',', y, ')');
end;

procedure draw_gif_block(bitmap: PScreenImage; const datfile, blockname: string; x, y: word; var pal: tpalette);
begin
  { TODO: Implement GIF loading from DAT block }
  { For now, this is a stub }
  writeln('STUB: draw_gif_block(', datfile, ',', blockname, ') at (', x, ',', y, ')');
end;

{ ========================================
   TEXT OUTPUT FUNCTIONS
   ======================================== }

procedure printc(bitmap: PScreenImage; y: word; const text: string; col, back: word);
begin
  { Print text centered horizontally at y position }
  { TODO: Implement proper text rendering }
  writeln('STUB: printc at y=', y, ' text=', text);
end;

procedure printx2(bitmap: PScreenImage; x, y: word; const text: string; col, back, transparent, styl: word; delay: word);
begin
  { Print text with extended options }
  { TODO: Implement proper text rendering }
  writeln('STUB: printx2 at (', x, ',', y, ') text=', text);
end;

procedure print_normal(bitmap: PScreenImage; x, y: word; const text: string; col, back: word);
begin
  { Print text normally }
  { TODO: Implement proper text rendering }
  writeln('STUB: print_normal at (', x, ',', y, ') text=', text);
end;

{ PImage version - convert and call through }
procedure print_normal(bitmap: PImage; x, y: word; const text: string; col, back: word);
begin
  { TODO: Implement proper text rendering }
  writeln('STUB: print_normal(PImage) at (', x, ',', y, ') text=', text);
end;

{ ========================================
   DRAWING FUNCTIONS
   ======================================== }

procedure okno(x, y, w, h, back: word);
begin
  { Draw window/box }
  { TODO: Implement window drawing }
  writeln('STUB: okno at (', x, ',', y, ') size=', w, 'x', h);
end;

procedure clear_bitmap(bitmap: PImage);
begin
  { Clear bitmap to black }
  if Assigned(bitmap) and Assigned(bitmap^.data) then
    FillByte(bitmap^.data^, bitmap^.width * bitmap^.height * 4, 0);
end;

procedure stvorec2(bitmap: PScreenImage; x, y, w, h, col, back: word);
begin
  { Draw rectangle }
  { TODO: Implement rectangle drawing }
  writeln('STUB: stvorec2 at (', x, ',', y, ') size=', w, 'x', h);
end;

{ ========================================
   TFrame and TPrint Object Implementations
   ======================================== }

constructor TFrame.init(handle:klucka;Block_file,Gif_file:string;Asave:boolean);
begin
  { TODO: Implement frame initialization }
  writeln('STUB: TFrame.init');
  ha_frame := handle;
  save := Asave;
end;

procedure TFrame.draw(x,y,dx,dy:word);
begin
  { TODO: Implement frame drawing }
  writeln('STUB: TFrame.draw at (', x, ',', y, ') size=', dx, 'x', dy);
end;

procedure TFrame.set_params(var Framex:TFrame);
begin
  { TODO: Implement parameter copying }
  writeln('STUB: TFrame.set_params');
end;

destructor TFrame.done;
begin
  { TODO: Implement frame cleanup }
  writeln('STUB: TFrame.done');
end;

constructor TPrint.init(PPx,PPy:integer;Tcol,CShadow,Roll:byte;Pcenter,Pshadow:boolean);
begin
  { TODO: Implement print initialization }
  writeln('STUB: TPrint.init');
  New(opt);
  if Assigned(opt) then
  begin
    opt^.px := PPx;
    opt^.py := PPy;
    opt^.text_color := Tcol;
    opt^.shadow_color := CShadow;
    opt^.roll_color := Roll;
    opt^.center := Pcenter;
    opt^.shadow := Pshadow;
  end;
end;

procedure TPrint.print(x,y:word;s:string);
begin
  { TODO: Implement text printing }
  writeln('STUB: TPrint.print at (', x, ',', y, ') text=', s);
end;

procedure TPrint.print_col(x,y:word;s:string;col:byte);
begin
  { TODO: Implement colored text printing }
  writeln('STUB: TPrint.print_col at (', x, ',', y, ') text=', s, ' col=', col);
end;

function TPrint.input(x,y:word;max_len:word):string;
begin
  { TODO: Implement text input }
  writeln('STUB: TPrint.input at (', x, ',', y, ') max_len=', max_len);
  Result := '';
end;

destructor TPrint.done;
begin
  { TODO: Implement print cleanup }
  writeln('STUB: TPrint.done');
  if Assigned(opt) then
    Dispose(opt);
end;

{ ========================================
   TYPE CONVERSION HELPERS
   ======================================== }

function ScreenImageToImage(scr: PScreenImage): PImage;
begin
  { Convert PScreenImage to PImage }
  { For screen, we return the underlying image }
  if Assigned(scr) then
    Result := screen_image
  else
    Result := nil;
end;

function ImageToScreenImage(img: PImage): PScreenImage;
begin
  { Convert PImage to PScreenImage }
  { This is a simplified conversion - return screen }
  Result := screen;
end;

{ ========================================
   FRAME AND PRINT WRAPPER FUNCTIONS
   ======================================== }

procedure old_frame_draw(x, y, dx, dy: word);
begin
  { Stub: Draw frame at position }
  writeln('STUB: old_frame_draw at (', x, ',', y, ') size=', dx, 'x', dy);
end;

procedure old_frame_init(handle:word; const block_file, gif_file: string; asave:boolean);
begin
  { Stub: Initialize frame }
  writeln('STUB: old_frame_init');
end;

procedure old_frame_done;
begin
  { Stub: Cleanup frame }
  writeln('STUB: old_frame_done');
end;

procedure napis_print(x, y: word; const s: string);
begin
  { Stub: Print text using napis object }
  writeln('STUB: napis_print at (', x, ',', y, ') text=', s);
end;

procedure napis2_print(x, y: word; const s: string);
begin
  { Stub: Print text using napis2 object }
  writeln('STUB: napis2_print at (', x, ',', y, ') text=', s);
end;

function napis_input(x, y: word; max_len: word): string;
begin
  { Stub: Input text using napis object }
  writeln('STUB: napis_input at (', x, ',', y, ') max_len=', max_len);
  Result := '';
end;

procedure napis_init(px, py: integer; tcol, cshadow, roll: byte; pcenter, pshadow: boolean);
begin
  { Stub: Initialize napis object }
  writeln('STUB: napis_init');
end;

procedure napis_done;
begin
  { Stub: Cleanup napis object }
  writeln('STUB: napis_done');
end;

initialization
  fill_palette_default;
  init_screen(640, 480);

  { Initialize text rendering objects (automatically done by object constructors) }

finalization
  { Cleanup }
  if Assigned(screen_image) then
    destroy_bitmap(screen_image);
  if Assigned(screen) then
    Dispose(screen);
  { Note: screen_texture cleanup not needed with direct rendering }

end.
