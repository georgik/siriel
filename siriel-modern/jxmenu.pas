unit jxmenu;

{$mode objfpc}{$H+}

{ Modern menu system using GLIST tiles for decoration
  Replaces original JXMENU.PAS with Raylib-based rendering
  Focus: GLIST menu decoration for Step 5.5
}

interface

uses
  SysUtils,
  jxgraf,
  jxfont_simple,
  blockx,
  geo;

const
  max_menu = 64;
  TILE_SIZE = 16;
  GLIST_TILE_COUNT = 8;

type
  { RGBA tile buffer }
  TTileBuffer = array[0..TILE_SIZE * TILE_SIZE * 4 - 1] of byte;

  polozka_typ = record
    meno: string[64];
    x, y: word;
    k: word;
  end;

  jxmenu_typ = record
    dat: array[1..64] of polozka_typ;
    pocet, first, vybrane, roll, posuv: byte;
    x, y, x1, y1, col1, col2, col3: word;
    meno: string[64];
    draw_menu: boolean;
  end;

{ Core menu functions - simplified for Step 5.5 }
procedure init_jxmenu(x, y, col1, col2, col3: word; meno: string; var menx: jxmenu_typ);
procedure vloz_jxmenu2(meno: string; var menx: jxmenu_typ; k: word);
procedure vloz_jxmenu_pos(x, y: word; meno: string; var menx: jxmenu_typ; k: word);
procedure draw_jxmenu(var menx: jxmenu_typ);
procedure hi_jxmenu(f: byte; var menx: jxmenu_typ);
procedure normal_jxmenu(f: byte; var menx: jxmenu_typ);

{ Missing menu functions (from original JXMENU.PAS) }
procedure size_jxmenu(sirka, vyska: word; var menx: jxmenu_typ);
procedure draw_jxmenu3(var menx: jxmenu_typ);
procedure vyber_jxmenu(var menx: jxmenu_typ; var vyber: word);
procedure old_frame;

{ GLIST decoration system }
procedure LoadGlistTiles;
procedure DrawMenuFrame(x, y, width_tiles, height_tiles: word; fill_col: byte);

{ Global GLIST tiles }
var
  glist_tiles: array[0..GLIST_TILE_COUNT - 1] of TTileBuffer;
  glist_loaded: boolean;

implementation

{ Extract a single 16x16 tile from screen buffer }
procedure ExtractTile(src_x, src_y: word; var tile: TTileBuffer);
var
  local_x, local_y: word;
  src_idx, dst_idx: longint;
begin
  for local_y := 0 to TILE_SIZE - 1 do
  begin
    for local_x := 0 to TILE_SIZE - 1 do
    begin
      src_idx := ((src_y + local_y) * screen_width + (src_x + local_x)) * 4;
      dst_idx := (local_y * TILE_SIZE + local_x) * 4;

      tile[dst_idx] := PByte(screen_image^.data + src_idx)^;
      tile[dst_idx + 1] := PByte(screen_image^.data + src_idx + 1)^;
      tile[dst_idx + 2] := PByte(screen_image^.data + src_idx + 2)^;
      tile[dst_idx + 3] := PByte(screen_image^.data + src_idx + 3)^;
    end;
  end;
end;

{ Draw a single tile to screen buffer with transparency }
procedure DrawTile(var tile: TTileBuffer; dst_x, dst_y: word);
var
  local_x, local_y: word;
  src_idx, dst_idx: longint;
  r, g, b, a: byte;
begin
  for local_y := 0 to TILE_SIZE - 1 do
  begin
    for local_x := 0 to TILE_SIZE - 1 do
    begin
      src_idx := (local_y * TILE_SIZE + local_x) * 4;
      r := tile[src_idx];
      g := tile[src_idx + 1];
      b := tile[src_idx + 2];
      a := tile[src_idx + 3];

      { Check for magenta transparency (RGB: 255, 0, 255) }
      if (r > 250) and (g < 10) and (b > 250) then
        continue;

      dst_idx := ((dst_y + local_y) * screen_width + (dst_x + local_x)) * 4;
      PByte(screen_image^.data + dst_idx)^ := r;
      PByte(screen_image^.data + dst_idx + 1)^ := g;
      PByte(screen_image^.data + dst_idx + 2)^ := b;
      PByte(screen_image^.data + dst_idx + 3)^ := 255;
    end;
  end;
end;

{ Fill the interior of menu with solid color }
procedure FillInterior(x, y, width_tiles, height_tiles: word; fill_col: byte);
var
  start_x, start_y, end_x, end_y, fill_x, fill_y: word;
  dst_idx: longint;
begin
  start_x := x + TILE_SIZE;
  start_y := y + TILE_SIZE;
  end_x := x + (width_tiles - 1) * TILE_SIZE;
  end_y := y + (height_tiles - 1) * TILE_SIZE;

  for fill_y := start_y to end_y - 1 do
  begin
    for fill_x := start_x to end_x - 1 do
    begin
      dst_idx := (fill_y * screen_width + fill_x) * 4;
      PByte(screen_image^.data + dst_idx)^ := fill_col;
      PByte(screen_image^.data + dst_idx + 1)^ := fill_col;
      PByte(screen_image^.data + dst_idx + 2)^ := fill_col;
      PByte(screen_image^.data + dst_idx + 3)^ := 255;
    end;
  end;
end;

{ Draw fancy menu frame using GLIST tiles }
procedure DrawMenuFrame(x, y, width_tiles, height_tiles: word; fill_col: byte);
var
  tile_num: word;
begin
  FillInterior(x, y, width_tiles, height_tiles, fill_col);

  { Top-left corner (tile 0) }
  DrawTile(glist_tiles[0], x, y);

  { Top edge (tile 1, repeated) }
  for tile_num := 1 to width_tiles - 2 do
    DrawTile(glist_tiles[1], x + tile_num * TILE_SIZE, y);

  { Top-right corner (tile 2) }
  DrawTile(glist_tiles[2], x + (width_tiles - 1) * TILE_SIZE, y);

  { Left edge (tile 3, repeated) }
  for tile_num := 1 to height_tiles - 2 do
    DrawTile(glist_tiles[3], x, y + tile_num * TILE_SIZE);

  { Right edge (tile 4, repeated) }
  for tile_num := 1 to height_tiles - 2 do
    DrawTile(glist_tiles[4], x + (width_tiles - 1) * TILE_SIZE, y + tile_num * TILE_SIZE);

  { Bottom-left corner (tile 5) }
  DrawTile(glist_tiles[5], x, y + (height_tiles - 1) * TILE_SIZE);

  { Bottom edge (tile 6, repeated) }
  for tile_num := 1 to width_tiles - 2 do
    DrawTile(glist_tiles[6], x + tile_num * TILE_SIZE, y + (height_tiles - 1) * TILE_SIZE);

  { Bottom-right corner (tile 7) }
  DrawTile(glist_tiles[7], x + (width_tiles - 1) * TILE_SIZE, y + (height_tiles - 1) * TILE_SIZE);
end;

{ Load GLIST tiles from MAIN.DAT }
procedure LoadGlistTiles;
var
  palette: jxfont_simple.tpalette;
  glist_x, glist_y, tile_idx: word;
  glist_width, glist_height: word;
begin
  if glist_loaded then
    exit;

  { Load GLIST to temporary location }
  glist_x := 0;
  glist_y := 0;

  if not draw_gif_block(screen_image, 'data/MAIN.DAT', 'GLIST', glist_x, glist_y, palette) then
  begin
    writeln('Warning: Failed to load GLIST for menu decoration');
    glist_loaded := False;
    exit;
  end;

  { Get GLIST dimensions }
  glist_width := blockx.gif_x;
  glist_height := blockx.gif_y;

  { Extract all 8 tiles }
  for tile_idx := 0 to GLIST_TILE_COUNT - 1 do
    ExtractTile(glist_x + tile_idx * TILE_SIZE, glist_y, glist_tiles[tile_idx]);

  { Clear only the GLIST area, NOT the entire screen }
  FillChar(PByte(screen_image^.data + (glist_y * screen_width + glist_x) * 4)^,
         glist_width * glist_height * 4, 0);

  glist_loaded := True;
end;

{ === MENU DRAWING FUNCTIONS === }

procedure graphicswindow(x, y, x1, y1, col1, col2: word; napis: string);
var
  width_tiles, height_tiles: word;
  fill_col: byte;
begin
  if glist_loaded then
  begin
    { Use GLIST tiles for fancy decoration }
    width_tiles := (x1 div TILE_SIZE) + 2;
    height_tiles := (y1 div TILE_SIZE) + 2;

    { Calculate fill color from col2 }
    fill_col := col2 and $FF;

    DrawMenuFrame(x, y, width_tiles, height_tiles, fill_col);
  end
  else
  begin
    { Fallback: simple rectangle }
    rectangle2(screen_image, x, y, x + x1, y + y1, col2);
    line(x, y, x + x1, y, col1);
    line(x, y, x, y + y1, col1);
    line(x + x1, y, x + x1, y + y1, col1);
    line(x, y + y1, x + x1, y + y1, col1);
  end;

  { Draw title }
  if napis <> '' then
    print_normal(screen_image, x + (x1 div 2) - (chardx * length(napis) div 2),
                y + (chardy div 2), napis, col1, 0);
end;

procedure hi_jxmenu(f: byte; var menx: jxmenu_typ);
begin
  { Highlighted item: draw text with highlight color (col1) }
  { Original DOS version just changes the text color, no background }
  print_normal(screen_image, menx.dat[f].x, menx.dat[f].y - menx.posuv * chardy,
              menx.dat[f].meno, menx.col1, 0);
end;

procedure normal_jxmenu(f: byte; var menx: jxmenu_typ);
begin
  { Use col2 (white) for normal text }
  print_normal(screen_image, menx.dat[f].x, menx.dat[f].y - menx.posuv * chardy,
              menx.dat[f].meno, menx.col2, 0);
end;

procedure vloz_medzery(var s: string; len: byte);
var
  i: byte;
begin
  i := length(s);
  while i < len do
  begin
    s := s + ' ';
    inc(i);
  end;
end;

procedure draw_jxmenu(var menx: jxmenu_typ);
var
  f, max: byte;
  temp_meno: string;
begin
  { Load GLIST tiles if not already loaded }
  LoadGlistTiles;

  if menx.pocet < menx.roll then
    menx.roll := menx.pocet;

  max := length(menx.meno);
  for f := 1 to menx.roll do
  begin
    if length(menx.dat[f].meno) > max then
      max := length(menx.dat[f].meno);
  end;

  for f := 1 to menx.roll do
  begin
    temp_meno := menx.dat[f].meno;
    vloz_medzery(temp_meno, max);
    menx.dat[f].meno := temp_meno;
    normal_jxmenu(f, menx);
  end;

  if (menx.x1 = 0) and (menx.y1 = 0) then
  begin
    graphicswindow(menx.x, menx.y, (max + 5) * chardx, (menx.roll + 4) * chardy,
                   menx.col1, menx.col3, ' ' + menx.meno + ' ');
    menx.x1 := (max + 5) * chardx;
    menx.y1 := (menx.roll + 4) * chardy;
  end
  else
    graphicswindow(menx.x, menx.y, menx.x1, menx.y1, menx.col1, menx.col3,
                   ' ' + menx.meno + ' ');

  for f := 1 to menx.roll do
    normal_jxmenu(f, menx);

  menx.draw_menu := True;
end;

{ === MENU INITIALIZATION === }

procedure init_jxmenu(x, y, col1, col2, col3: word; meno: string; var menx: jxmenu_typ);
begin
  menx.vybrane := 0;
  menx.x1 := 0;
  menx.y1 := 0;
  menx.roll := 20;
  menx.posuv := 0;
  menx.x := x;
  menx.y := y;
  menx.pocet := 0;
  menx.col1 := col1;
  menx.col2 := col2;
  menx.col3 := col3;
  menx.meno := meno;
  menx.draw_menu := False;
  menx.first := 1;

  { Ensure GLIST tiles are loaded }
  LoadGlistTiles;
end;

procedure vloz_jxmenu2(meno: string; var menx: jxmenu_typ; k: word);
begin
  if menx.pocet < max_menu then
  begin
    inc(menx.pocet);
    menx.dat[menx.pocet].x := menx.x + 2 * chardx;
    menx.dat[menx.pocet].y := menx.y + chardy + menx.pocet * chardy;
    menx.dat[menx.pocet].meno := ' ' + meno + ' ';
    menx.dat[menx.pocet].k := k;
  end;
end;

{ Add menu item at specific position (from original DOS version) }
procedure vloz_jxmenu_pos(x, y: word; meno: string; var menx: jxmenu_typ; k: word);
begin
  if menx.pocet < max_menu then
  begin
    inc(menx.pocet);
    menx.dat[menx.pocet].x := x;
    menx.dat[menx.pocet].y := y;
    menx.dat[menx.pocet].meno := ' ' + meno + ' ';
    menx.dat[menx.pocet].k := k;
  end;
end;

{ === INITIALIZATION === }

var
  initialization_done: boolean = False;

procedure InitJxmenu;
begin
  if initialization_done then
    exit;

  glist_loaded := False;
  initialization_done := True;
end;

{ ========================================
   MISSING MENU FUNCTIONS (from JXMENU.PAS)
   ======================================== }

procedure size_jxmenu(sirka, vyska: word; var menx: jxmenu_typ);
begin
  { Set menu size }
  menx.x1 := sirka;
  menx.y1 := vyska;
end;

procedure draw_jxmenu3(var menx: jxmenu_typ);
begin
  { Draw menu with alternative style }
  { For now, just call regular draw }
  draw_jxmenu(menx);
end;

procedure vyber_jxmenu(var menx: jxmenu_typ; var vyber: word);
begin
  { Wait for user selection from menu }
  { TODO: Implement proper menu selection logic }
  { For now, this is a stub }
  vyber := 1;
end;

procedure old_frame;
begin
  { Save current screen state }
  { TODO: Implement screen save }
  { For now, this is a stub }
end;

initialization
  InitJxmenu;

finalization
  { Cleanup if needed }

end.
