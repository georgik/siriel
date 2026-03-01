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
  geo,
  sprite_anim,
  animing,
  raylib_helpers;

const
  max_menu = 64;
  TILE_SIZE = 16;
  GLIST_TILE_COUNT = 8;

type
  { RGBA tile buffer (still used for other purposes) }
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
procedure normal_jxmenu_all(var menx: jxmenu_typ);  { Draw all menu items }

{ Missing menu functions (from original JXMENU.PAS) }
procedure size_jxmenu(sirka, vyska: word; var menx: jxmenu_typ);
procedure draw_jxmenu3(var menx: jxmenu_typ);
procedure vyber_jxmenu(var menx: jxmenu_typ; var vyber: word; timeout_ms: uint64);
procedure old_frame;

{ GLIST decoration system }
procedure LoadGlistTiles;
procedure DrawMenuFrame(x, y, width_tiles, height_tiles: word; fill_col: byte);
procedure RenderMenuFrame(x, y, width_tiles, height_tiles: word);  { Call every frame in rendering loop }
procedure RenderMenuFrameBorderOnly(x, y, width_tiles, height_tiles: word);  { Border only, no fill }

{ Avatar animation system - using Raylib GPU rendering }
procedure LoadGzalTiles;
procedure UpdateAvatar;
procedure RenderAvatar;  { Render avatar at current position using Raylib texture }

{ Global GLIST tiles - using Raylib textures for GPU rendering }
var
  glist_textures: array[0..GLIST_TILE_COUNT - 1] of TRaylibTexture2D;
  glist_loaded: boolean;

implementation

{ Avatar animation state - using Raylib textures with GPU rendering }
var
  avatar_sheet: TSpritesheet;
  avatar_loaded: boolean;
  poloha: byte;  { Animation frame counter (0-35), mirrors original }
  avatar_textures: array[0..63] of TRaylibTexture2D;  { Raylib textures for each frame }
  avatar_frame_count: word;
  avatar_x, avatar_y: word;  { Current avatar position for rendering }

{ Fill the interior of menu with solid color using VGA palette }
procedure FillInterior(x, y, width_tiles, height_tiles: word; fill_col: byte);
var
  start_x, start_y, end_x, end_y, fill_x, fill_y: word;
  dst_idx: longint;
  color_rgba: longint;
begin
  start_x := x + TILE_SIZE;
  start_y := y + TILE_SIZE;
  end_x := x + (width_tiles - 1) * TILE_SIZE;
  end_y := y + (height_tiles - 1) * TILE_SIZE;

  { Convert palette index to RGBA using VGA palette }
  color_rgba := jxgraf.palette_to_rgba(fill_col);

  for fill_y := start_y to end_y - 1 do
  begin
    for fill_x := start_x to end_x - 1 do
    begin
      dst_idx := (fill_y * screen_width + fill_x) * 4;
      { Write RGBA in correct byte order }
      PLongWord(screen_image^.data + dst_idx)^ := color_rgba;
    end;
  end;
end;

{ Draw fancy menu frame using GLIST tiles }
{ Draw menu frame using GLIST tiles with Raylib textures
  This is called ONCE during menu setup to draw the background fill
  The actual tile rendering happens in RenderMenuFrame which is called every frame
}
procedure DrawMenuFrame(x, y, width_tiles, height_tiles: word; fill_col: byte);
begin
  { Just draw the interior fill - tiles are rendered every frame in RenderMenuFrame }
  FillInterior(x, y, width_tiles, height_tiles, fill_col);
end;

{ Render only the border tiles (no fill) - for drawing on top of text }
procedure RenderMenuFrameBorderOnly(x, y, width_tiles, height_tiles: word);
var
  tile_num: word;
  dst_x, dst_y: word;
begin
  if not glist_loaded then
    exit;

  { Top-left corner (tile 0) }
  DrawTexture(glist_textures[0], x, y, $FFFFFFFF);

  { Top edge (tile 1, repeated) }
  for tile_num := 1 to width_tiles - 2 do
  begin
    dst_x := x + tile_num * TILE_SIZE;
    DrawTexture(glist_textures[1], dst_x, y, $FFFFFFFF);
  end;

  { Top-right corner (tile 2) }
  dst_x := x + (width_tiles - 1) * TILE_SIZE;
  DrawTexture(glist_textures[2], dst_x, y, $FFFFFFFF);

  { Left edge (tile 3, repeated) }
  for tile_num := 1 to height_tiles - 2 do
  begin
    dst_y := y + tile_num * TILE_SIZE;
    DrawTexture(glist_textures[3], x, dst_y, $FFFFFFFF);
  end;

  { Right edge (tile 4, repeated) }
  dst_x := x + (width_tiles - 1) * TILE_SIZE;
  for tile_num := 1 to height_tiles - 2 do
  begin
    dst_y := y + tile_num * TILE_SIZE;
    DrawTexture(glist_textures[4], dst_x, dst_y, $FFFFFFFF);
  end;

  { Bottom-left corner (tile 5) }
  dst_y := y + (height_tiles - 1) * TILE_SIZE;
  DrawTexture(glist_textures[5], x, dst_y, $FFFFFFFF);

  { Bottom edge (tile 6, repeated) }
  for tile_num := 1 to width_tiles - 2 do
  begin
    dst_x := x + tile_num * TILE_SIZE;
    DrawTexture(glist_textures[6], dst_x, dst_y, $FFFFFFFF);
  end;

  { Bottom-right corner (tile 7) }
  dst_x := x + (width_tiles - 1) * TILE_SIZE;
  DrawTexture(glist_textures[7], dst_x, dst_y, $FFFFFFFF);
end;

{ Render GLIST tiles using Raylib textures - called every frame in rendering loop }
procedure RenderMenuFrame(x, y, width_tiles, height_tiles: word);
var
  tile_num: word;
  dst_x, dst_y: word;
  fill_x, fill_y, fill_width, fill_height: word;
  fill_color: longword;
begin
  if not glist_loaded then
    exit;

  { Draw filled background rectangle using Raylib }
  { Interior area: from (x+16, y+16) to (x + width*16 - 16, y + height*16 - 16) }
  fill_x := x + TILE_SIZE;
  fill_y := y + TILE_SIZE;
  fill_width := (width_tiles - 2) * TILE_SIZE;
  fill_height := (height_tiles - 2) * TILE_SIZE;

  { Use VGA palette color at index 128: #d0946c }
  { VGA palette: R=52, G=37, B=27 (6-bit) → RGB: R=208, G=148, B=108 }
  { Raylib uses 0xAABBGGRR format for 32-bit colors }
  { A=FF, B=6C, G=94, R=D0 }
  fill_color := $FF6C94D0;

  raylib_helpers.DrawRectangle(fill_x, fill_y, fill_width, fill_height, fill_color);

  { Top-left corner (tile 0) }
  DrawTexture(glist_textures[0], x, y, $FFFFFFFF);

  { Top edge (tile 1, repeated) }
  for tile_num := 1 to width_tiles - 2 do
  begin
    dst_x := x + tile_num * TILE_SIZE;
    DrawTexture(glist_textures[1], dst_x, y, $FFFFFFFF);
  end;

  { Top-right corner (tile 2) }
  dst_x := x + (width_tiles - 1) * TILE_SIZE;
  DrawTexture(glist_textures[2], dst_x, y, $FFFFFFFF);

  { Left edge (tile 3, repeated) }
  for tile_num := 1 to height_tiles - 2 do
  begin
    dst_y := y + tile_num * TILE_SIZE;
    DrawTexture(glist_textures[3], x, dst_y, $FFFFFFFF);
  end;

  { Right edge (tile 4, repeated) }
  dst_x := x + (width_tiles - 1) * TILE_SIZE;
  for tile_num := 1 to height_tiles - 2 do
  begin
    dst_y := y + tile_num * TILE_SIZE;
    DrawTexture(glist_textures[4], dst_x, dst_y, $FFFFFFFF);
  end;

  { Bottom-left corner (tile 5) }
  dst_y := y + (height_tiles - 1) * TILE_SIZE;
  DrawTexture(glist_textures[5], x, dst_y, $FFFFFFFF);

  { Bottom edge (tile 6, repeated) }
  for tile_num := 1 to width_tiles - 2 do
  begin
    dst_x := x + tile_num * TILE_SIZE;
    DrawTexture(glist_textures[6], dst_x, dst_y, $FFFFFFFF);
  end;

  { Bottom-right corner (tile 7) }
  dst_x := x + (width_tiles - 1) * TILE_SIZE;
  DrawTexture(glist_textures[7], dst_x, dst_y, $FFFFFFFF);
end;

{ Load GLIST tiles from MAIN.DAT using Raylib textures }
procedure LoadGlistTiles;
begin
  if glist_loaded then
    exit;

  writeln('[JXMENU] Loading GLIST tiles as textures...');

  { Use the same loading mechanism as avatar - Raylib handles palette correctly }
  if not blockx.load_gif_tiles_textures('data/MAIN.DAT', 'GLIST', TILE_SIZE, TILE_SIZE, GLIST_TILE_COUNT, glist_textures) then
  begin
    writeln('[JXMENU] Warning: Failed to load GLIST for menu decoration');
    glist_loaded := False;
    exit;
  end;

  writeln('[JXMENU] GLIST tiles loaded successfully as textures');
  glist_loaded := True;
end;

{ === MENU DRAWING FUNCTIONS === }

{ Load GZAL spritesheet and create Raylib textures }
procedure LoadGzalTiles;
begin
  if avatar_loaded then
    exit;

  { Load and create textures using Raylib - all in GPU memory! }
  if not blockx.load_gif_spritesheet_textures('data/MAIN.DAT', 'GZAL', 16, 16, avatar_textures, avatar_frame_count) then
  begin
    writeln('[JXMENU] Failed to load GZAL spritesheet textures');
    Exit;
  end;

  writeln('[JXMENU] GZAL loaded: ', avatar_frame_count, ' frames as Raylib textures');
  avatar_loaded := True;
end;

{ Draw avatar frame at specified position using Raylib texture }
{ Update avatar animation frame - mirrors original DOS panak procedure }
procedure UpdateAvatar;
begin
  { Increment animation frame counter }
  inc(poloha);

  { Cycle through frames 0-35 like original }
  if poloha > 35 then
    poloha := 0;
end;

{ Render avatar at stored position using Raylib texture }
procedure RenderAvatar;
var
  frame_num: word;
  tex: TRaylibTexture2D;
begin
  { Load textures on first use (after InitWindow) }
  if not avatar_loaded then
    LoadGzalTiles;

  if not avatar_loaded then
  begin
    writeln('[JXMENU] RenderAvatar: GZAL not loaded, skipping');
    Exit;
  end;

  frame_num := poloha mod 36;
  tex := avatar_textures[frame_num];

  writeln('[JXMENU] RenderAvatar: Drawing frame ', frame_num, ' at (', avatar_x, ', ', avatar_y, ')');

  { Draw directly to GPU back buffer - WHITE tint = no color modification }
  DrawTexture(tex, avatar_x, avatar_y, $FFFFFFFF);
end;

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
var
  prev_choice: byte;
begin
  writeln('[JXMENU] hi_jxmenu: called with f=', f, ' vybrane=', menx.vybrane);

  { Only redraw text if selection changed }
  if menx.vybrane <> f then
  begin
    prev_choice := menx.vybrane;
    if prev_choice > 0 then
    begin
      { Clear previous selection's text }
      writeln('[JXMENU] hi_jxmenu: Clearing previous choice ', prev_choice);
      print_normal(screen_image, menx.dat[prev_choice].x, menx.dat[prev_choice].y - menx.posuv * chardy,
                  menx.dat[prev_choice].meno, menx.col2, 0);
    end;

    { Draw new selection's text }
    writeln('[JXMENU] hi_jxmenu: Drawing new choice ', f, ' text at (', menx.dat[f].x, ',', menx.dat[f].y - menx.posuv * chardy, ')');
    print_normal(screen_image, menx.dat[f].x, menx.dat[f].y - menx.posuv * chardy,
                menx.dat[f].meno, menx.col1, 0);
  end;

  { Calculate and store avatar position for rendering }
  avatar_x := menx.dat[f].x - 20;
  avatar_y := menx.dat[f].y - menx.posuv * chardy;

  writeln('[JXMENU] hi_jxmenu: Avatar position set to (', avatar_x, ',', avatar_y, ')');
end;

procedure normal_jxmenu(f: byte; var menx: jxmenu_typ);
begin
  { Use col2 (white) for normal text }
  print_normal(screen_image, menx.dat[f].x, menx.dat[f].y - menx.posuv * chardy,
              menx.dat[f].meno, menx.col2, 0);
end;

{ Draw all menu items to screen_image }
procedure normal_jxmenu_all(var menx: jxmenu_typ);
var
  f: word;
  menu_left, menu_top, menu_right, menu_bottom: longint;
  pixel_ptr: PByte;
  x, y: longint;
  dst_idx: longint;
begin
  { Clear menu area to transparent (alpha=0) so decoration shows through }
  if menx.pocet > 0 then
  begin
    menu_left := menx.x;
    menu_top := menx.y;
    menu_right := menx.x + menx.x1;
    menu_bottom := menx.y + menx.y1;

    pixel_ptr := PByte(screen_image^.data);
    for y := menu_top to menu_bottom - 1 do
    begin
      for x := menu_left to menu_right - 1 do
      begin
        dst_idx := (y * screen_image^.width + x) * 4;
        { Set alpha to 0 (transparent) }
        pixel_ptr[dst_idx + 3] := 0;
      end;
    end;
  end;

  { Draw all menu items }
  for f := 1 to menx.pocet do
  begin
    { Use col2 (white) for all items }
    print_normal(screen_image, menx.dat[f].x, menx.dat[f].y - menx.posuv * chardy,
                menx.dat[f].meno, menx.col2, 0);
  end;
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

  { Load GZAL avatar if not already loaded }
  LoadGzalTiles;

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

  { REMOVED: Don't redraw menu items after graphicswindow - it overwrites the tiles! }
  { for f := 1 to menx.roll do
    normal_jxmenu(f, menx); }

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
    { Add margin for decorative frame if GLIST is loaded }
    { Need 4 characters (32 pixels) to clear the 16x16 corner tile + 16x16 edge tile }
    if glist_loaded then
      menx.dat[menx.pocet].x := menx.x + 4 * chardx
    else
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
  avatar_loaded := False;
  poloha := 0;  { Initialize animation frame counter }

  { Note: Texture loading deferred until after InitWindow() }
  { LoadGzalTiles will be called on first RenderAvatar }

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

procedure vyber_jxmenu(var menx: jxmenu_typ; var vyber: word; timeout_ms: uint64);
var
  f, k: word;
  menu_done: boolean;
  menu_start_time: uint64;
  current_time: uint64;
begin
  if menx.pocet > 0 then
  begin
    { Draw menu if not already drawn }
    if not menx.draw_menu then
      draw_jxmenu(menx);

    f := menx.first;
    menu_done := False;

    { Initialize start time for timeout checking }
    menu_start_time := SysUtils.GetTickCount64;

    repeat
      { Update avatar animation frame - mirrors original DOS panak procedure }
      UpdateAvatar;

      { Highlight current selection (draws avatar) }
      hi_jxmenu(f, menx);

      { Update keyboard }
      get_keyboard;

      { Check for window close }
      if WindowShouldClose() <> 0 then
      begin
        vyber := menx.pocet;  { Select last item (Back) }
        menu_done := True;
      end;

      { Check for timeout }
      if timeout_ms > 0 then
      begin
        current_time := SysUtils.GetTickCount64;
        if (current_time - menu_start_time) >= timeout_ms then
        begin
          writeln('[JXMENU] Level selector timeout reached, auto-selecting first level');
          vyber := 1;  { Auto-select first level }
          menu_done := True;
        end;
      end;

      { Handle keyboard input }
      if keypressed then
      begin
        k := kkey2;

        case k of
          kb_up:
            begin
              normal_jxmenu(f, menx);
              if f > 1 then
                dec(f);
            end;
          kb_down:
            begin
              normal_jxmenu(f, menx);
              if f < menx.pocet then
                inc(f);
            end;
          kb_enter, kb_space:
            menu_done := True;
          kb_esc:
            begin
              normal_jxmenu(f, menx);
              f := menx.pocet;  { Select last item (Back) }
              menu_done := True;
            end;
        end;
      end;

      { Render to window every frame }
      BeginDrawing();
      ClearBackground(0, 0, 0, 255);

      { 1. Draw decoration: fill color first, then all tiles (corners and edges) }
      if glist_loaded and (menx.x1 > 0) and (menx.y1 > 0) then
      begin
        RenderMenuFrame(menx.x, menx.y,
                       (menx.x1 + TILE_SIZE - 1) div TILE_SIZE,
                       (menx.y1 + TILE_SIZE - 1) div TILE_SIZE);
      end;

      { 2. Write menu text to screen_image (on CPU side) }
      normal_jxmenu_all(menx);

      { 3. Render screen_image (which now has text on top) to window/GPU }
      RenderScreenToWindow();

      EndDrawing();

      Sleep(16);
    until menu_done;

    vyber := f;
    menx.vybrane := f;
    menx.draw_menu := False;
  end
  else
    vyber := 0;
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
