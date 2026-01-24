unit jxfont_simple;

{$mode objfpc}{$H+}

{ This unit provides simple font rendering to replace TXT.PAS }
{ TXT.PAS was only available as compiled .TPU, so we're recreating it }

interface

uses
  jxgraf,
  SysUtils;

type
  tpalette = array[0..255] of record
    r, v, b: byte;
  end;

  timagestruct = record
    width, height: word;
    NumberOfColors: word;
    BitsPerPixel: byte;
    SizeOfImage: longint;
    Information: byte;
  end;

{ Font and text rendering }
var
  fontik: array[1..4107] of byte;

procedure print_normal(bitmap: PImage; x, y: word; text: string; fg, bg: byte);
procedure SetFont(font_data: pointer; width, height: word);
procedure setstartchar(start: byte);

{ Palette operations }
procedure load_palette(name: string; var pal: tpalette; start, num_colors: word; transparent: boolean);
procedure clear_bitmap(bitmap: PImage);
procedure draw_it(name: string; x, y: word; var pal: tpalette);

implementation

uses
  raylib_helpers,
  dos_compat;

{ Simple text rendering - draws text using 8x8 bitmap font }
procedure print_normal(bitmap: PImage; x, y: word; text: string; fg, bg: byte);
const
  { Simple 8x8 font for uppercase A-Z and digits 0-9 }
  { Each character is 8 bytes, 1 byte per row, MSB = leftmost pixel }
  font_8x8: array[65..90] of array[0..7] of byte = (
    { 'A' }  ($3C, $66, $66, $7E, $66, $66, $66, $00),
    { 'B' }  ($7C, $66, $66, $7C, $66, $66, $7C, $00),
    { 'C' }  ($3C, $66, $60, $60, $60, $66, $3C, $00),
    { 'D' }  ($78, $6C, $66, $66, $66, $6C, $78, $00),
    { 'E' }  ($7E, $60, $60, $7C, $60, $60, $7E, $00),
    { 'F' }  ($7E, $60, $60, $7C, $60, $60, $60, $00),
    { 'G' }  ($3C, $66, $60, $6E, $66, $66, $3C, $00),
    { 'H' }  ($66, $66, $66, $7E, $66, $66, $66, $00),
    { 'I' }  ($7E, $18, $18, $18, $18, $18, $7E, $00),
    { 'J' }  ($3E, $0C, $0C, $0C, $0C, $CC, $78, $00),
    { 'K' }  ($66, $6C, $78, $70, $78, $6C, $66, $00),
    { 'L' }  ($60, $60, $60, $60, $60, $60, $7E, $00),
    { 'M' }  ($63, $77, $7F, $7F, $6B, $63, $63, $00),
    { 'N' }  ($66, $76, $7E, $7E, $6E, $66, $66, $00),
    { 'O' }  ($3C, $66, $66, $66, $66, $66, $3C, $00),
    { 'P' }  ($7C, $66, $66, $7C, $60, $60, $60, $00),
    { 'Q' }  ($3C, $66, $66, $66, $66, $3C, $0E, $00),
    { 'R' }  ($7C, $66, $66, $7C, $78, $6C, $66, $00),
    { 'S' }  ($3C, $66, $60, $3C, $06, $66, $3C, $00),
    { 'T' }  ($7E, $18, $18, $18, $18, $18, $18, $00),
    { 'U' }  ($66, $66, $66, $66, $66, $66, $3C, $00),
    { 'V' }  ($66, $66, $66, $66, $66, $3C, $18, $00),
    { 'W' }  ($63, $63, $6B, $7F, $7F, $77, $63, $00),
    { 'X' }  ($66, $66, $3C, $18, $3C, $66, $66, $00),
    { 'Y' }  ($66, $66, $66, $3C, $18, $18, $18, $00),
    { 'Z' }  ($7E, $06, $0C, $18, $30, $60, $7E, $00)
  );

  font_digits: array[48..57] of array[0..7] of byte = (
    { '0' }  ($3C, $66, $6E, $76, $66, $66, $3C, $00),
    { '1' }  ($18, $38, $18, $18, $18, $18, $7E, $00),
    { '2' }  ($3C, $66, $06, $0C, $30, $60, $7E, $00),
    { '3' }  ($3C, $66, $06, $1C, $06, $66, $3C, $00),
    { '4' }  ($0C, $1C, $3C, $6C, $7E, $0C, $0C, $00),
    { '5' }  ($7E, $60, $7C, $06, $06, $66, $3C, $00),
    { '6' }  ($1C, $30, $60, $7C, $66, $66, $3C, $00),
    { '7' }  ($7E, $06, $0C, $18, $30, $30, $30, $00),
    { '8' }  ($3C, $66, $66, $3C, $66, $66, $3C, $00),
    { '9' }  ($3C, $66, $66, $3E, $06, $0C, $38, $00)
  );

  font_lowercase: array[97..122] of array[0..7] of byte = (
    { 'a' }  ($00, $00, $3C, $06, $3E, $66, $3E, $00),
    { 'b' }  ($60, $60, $7C, $66, $66, $66, $7C, $00),
    { 'c' }  ($00, $00, $3C, $60, $60, $60, $3C, $00),
    { 'd' }  ($06, $06, $3E, $66, $66, $66, $3E, $00),
    { 'e' }  ($00, $00, $3C, $66, $7E, $60, $3C, $00),
    { 'f' }  ($1C, $36, $30, $7C, $30, $30, $30, $00),
    { 'g' }  ($00, $00, $3E, $66, $66, $3E, $06, $3C),
    { 'h' }  ($60, $60, $7C, $66, $66, $66, $66, $00),
    { 'i' }  ($18, $00, $38, $18, $18, $18, $3C, $00),
    { 'j' }  ($0C, $00, $0C, $0C, $0C, $0C, $CC, $78),
    { 'k' }  ($60, $60, $6C, $78, $78, $6C, $66, $00),
    { 'l' }  ($38, $18, $18, $18, $18, $18, $3C, $00),
    { 'm' }  ($00, $00, $76, $7F, $6B, $63, $63, $00),
    { 'n' }  ($00, $00, $7C, $66, $66, $66, $66, $00),
    { 'o' }  ($00, $00, $3C, $66, $66, $66, $3C, $00),
    { 'p' }  ($00, $00, $7C, $66, $66, $7C, $60, $60),
    { 'q' }  ($00, $00, $3E, $66, $66, $3E, $06, $06),
    { 'r' }  ($00, $00, $7C, $66, $60, $60, $60, $00),
    { 's' }  ($00, $00, $3E, $60, $3C, $06, $7C, $00),
    { 't' }  ($18, $18, $7E, $18, $18, $18, $0E, $00),
    { 'u' }  ($00, $00, $66, $66, $66, $66, $3E, $00),
    { 'v' }  ($00, $00, $66, $66, $66, $3C, $18, $00),
    { 'w' }  ($00, $00, $63, $6B, $7F, $7F, $36, $00),
    { 'x' }  ($00, $00, $66, $3C, $18, $3C, $66, $00),
    { 'y' }  ($00, $00, $66, $66, $66, $3E, $06, $3C),
    { 'z' }  ($00, $00, $7E, $0C, $18, $30, $7E, $00)
  );

  font_special: array[32..47] of array[0..7] of byte = (
    { ' ' }  ($00, $00, $00, $00, $00, $00, $00, $00),
    { '!' }  ($18, $18, $18, $18, $00, $00, $18, $00),
    { '"' }  ($36, $36, $00, $00, $00, $00, $00, $00),
    { '#' }  ($36, $36, $7F, $36, $7F, $36, $36, $00),
    { '$' }  ($18, $3E, $60, $3C, $06, $7C, $18, $00),
    { '%' }  ($66, $66, $0C, $18, $30, $66, $66, $00),
    { '&' }  ($38, $6C, $38, $76, $DC, $CE, $7B, $00),
    { ''' }  ($06, $0C, $18, $00, $00, $00, $00, $00),
    { '(' }  ($18, $0C, $06, $06, $06, $0C, $18, $00),
    { ')' }  ($30, $18, $0C, $0C, $0C, $18, $30, $00),
    { '*' }  ($00, $66, $3C, $FF, $3C, $66, $00, $00),
    { '+' }  ($00, $18, $18, $7E, $18, $18, $00, $00),
    { ',' }  ($00, $00, $00, $00, $00, $18, $18, $30),
    { '-' }  ($00, $00, $00, $7E, $00, $00, $00, $00),
    { '.' }  ($00, $00, $00, $00, $00, $18, $18, $00),
    { '/' }  ($00, $60, $30, $18, $0C, $06, $03, $00)
  );

var
  char_idx, row, col: integer;
  char_byte: byte;
  char_data: array[0..7] of byte;
  color_rgba: longint;
  ch: char;

begin
  { Get the RGBA color for foreground }
  color_rgba := palette_to_rgba(fg);

  { For each character in the string }
  for char_idx := 1 to Length(text) do
  begin
    ch := text[char_idx];

    { Get font data for this character }
    FillChar(char_data, SizeOf(char_data), 0);

    if (ch >= 'A') and (ch <= 'Z') then
      char_data := font_8x8[Ord(ch)]
    else if (ch >= 'a') and (ch <= 'z') then
      char_data := font_lowercase[Ord(ch)]
    else if (ch >= '0') and (ch <= '9') then
      char_data := font_digits[Ord(ch)]
    else if (ch >= ' ') and (ch <= '/') then
      char_data := font_special[Ord(ch)]
    else
      continue; { Skip unsupported characters }

    { Draw the 8x8 character }
    for row := 0 to 7 do
    begin
      char_byte := char_data[row];
      for col := 0 to 7 do
      begin
        { Check if pixel should be drawn (MSB first) }
        if (char_byte and (128 shr col)) <> 0 then
          putpixel(bitmap, x + (char_idx-1)*8 + col, y + row, color_rgba);
      end;
    end;
  end;
end;

{ Set font data }
procedure SetFont(font_data: pointer; width, height: word);
begin
  { TODO: Store font data for use in print_normal }
  { For now, this is a no-op }
end;

{ Set starting character }
procedure setstartchar(start: byte);
begin
  { TODO: Store start character offset }
  { For now, this is a no-op }
end;

{ Load palette }
procedure load_palette(name: string; var pal: tpalette; start, num_colors: word; transparent: boolean);
var
  i: integer;
begin
  { TODO: Load palette from file }
  { For now, create a simple grayscale palette }
  for i := 0 to 255 do
  begin
    pal[i].r := i;
    pal[i].v := i;
    pal[i].b := i;
  end;
end;

{ Clear bitmap }
procedure clear_bitmap(bitmap: PImage);
var
  x, y: word;
begin
  if not Assigned(bitmap) then Exit;

  { Fill with opaque black (alpha = 255) }
  for y := 0 to bitmap^.height - 1 do
    for x := 0 to bitmap^.width - 1 do
      putpixel(bitmap, x, y, (255 shl 24) or (0 shl 16) or (0 shl 8) or 0);
end;

{ Draw image placeholder }
procedure draw_it(name: string; x, y: word; var pal: tpalette);
begin
  { TODO: Implement GIF drawing }
  { This will be implemented in BLOCKX }
end;

end.
