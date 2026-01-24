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

{ Simple text rendering - draws text using small rectangles }
{ TODO: Implement proper bitmap font rendering }
procedure print_normal(bitmap: PImage; x, y: word; text: string; fg, bg: byte);
var
  i, j, k: integer;
  color: longint;
begin
  { For now, use very simple rendering - 8x8 pixels per character }
  { Convert palette color index to RGBA }
  for i := 1 to Length(text) do
  begin
    for j := 0 to 7 do
    begin
      for k := 0 to 7 do
      begin
        { Draw simple 8x8 blocks for each character }
        { This is just a placeholder - proper font rendering will come later }
        if (text[i] <> ' ') then
          putpixel(bitmap, x + (i-1)*8 + j, y + k, palette_to_rgba(fg));
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
