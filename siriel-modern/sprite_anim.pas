unit sprite_anim;

{$mode objfpc}{$H+}

{ Animation and spritesheet system for Siriel Modern
  Port of DOS ANIMING.PAS with modern Raylib integration
  Handles 16x16 tile extraction and frame-based animation
}

interface

uses
  SysUtils,
  ctypes,
  raylib_helpers,
  blockx,
  dos_compat,
  animing,
  jxgraf,
  geo,
  jxfont_simple;

const
  TILE_WIDTH = 16;
  TILE_HEIGHT = 16;
  MAX_FRAMES = 80;
  TRANSPARENT_COLOR_INDEX = 13;  { DOS palette index for transparency }

type
  { Single frame buffer (16x16 = 256 bytes for palette indices) }
  PFrame = ^TFrame;
  TFrame = array[0..TILE_WIDTH * TILE_HEIGHT - 1] of byte;

  { Animation state }
  TAnimation = record
    frames: array[0..MAX_FRAMES-1] of PFrame;
    frame_count: word;
    current_frame: word;
    frame_delay_ms: longint;
    last_frame_time: longint;
    looping: boolean;
    playing: boolean;
    x, y: word;  { Screen position }
  end;

  { Spritesheet definition }
  TSpritesheet = record
    source_dat: string;     { DAT file path }
    source_block: string;   { Block key (e.g., 'GLIST', 'GANIM') }
    frame_width: word;
    frame_height: word;
    columns: word;
    rows: word;
    total_frames: word;
    frames: array[0..MAX_FRAMES-1] of PFrame;
    palette: jxfont_simple.tpalette;  { Palette for color conversion }
    loaded: boolean;
  end;

{ Spritesheet loading and extraction }
function LoadSpritesheet(dat_name, block_key: string; frame_w, frame_h: word): TSpritesheet;
procedure FreeSpritesheet(var sheet: TSpritesheet);
procedure ExtractFramesFromGIF(var sheet: TSpritesheet);
function GetFrame(sheet: TSpritesheet; frame_num: word): PFrame;

{ Animation management }
procedure InitAnimation(var anim: TAnimation; var sheet: TSpritesheet; delay_ms: longint);
procedure FreeAnimation(var anim: TAnimation);
procedure UpdateAnimation(var anim: TAnimation; current_time: longint);
procedure DrawAnimationFrame(anim: TAnimation; x, y: word);
procedure DrawFrame(frame: PFrame; x, y: word);
procedure SetAnimationFrame(var anim: TAnimation; frame: word);
procedure PlayAnimation(var anim: TAnimation);
procedure StopAnimation(var anim: TAnimation);
procedure ResetAnimation(var anim: TAnimation);

{ Utility functions }
function GetAnimationTime: longint;
function CreateFrame: PFrame;
procedure FreeFrame(f: PFrame);

implementation

{ Get current time in milliseconds }
function GetAnimationTime: longint;
begin
  GetAnimationTime := GetClock();
end;

{ Allocate a new frame buffer }
function CreateFrame: PFrame;
begin
  New(Result);
end;

{ Free a frame buffer }
procedure FreeFrame(f: PFrame);
begin
  if f <> nil then
    Dispose(f);
end;

{ Load spritesheet from DAT file }
function LoadSpritesheet(dat_name, block_key: string; frame_w, frame_h: word): TSpritesheet;
var
  i: word;
  palette: jxfont_simple.tpalette;
begin
  { Initialize spritesheet }
  Result.source_dat := dat_name;
  Result.source_block := block_key;
  Result.frame_width := frame_w;
  Result.frame_height := frame_h;
  Result.columns := 0;
  Result.rows := 0;
  Result.total_frames := 0;
  Result.loaded := false;

  { Initialize all frame pointers to nil }
  for i := 0 to MAX_FRAMES - 1 do
    Result.frames[i] := nil;

  writeln('[SPRITE] Loading spritesheet: ', block_key, ' from ', dat_name);
  writeln('[SPRITE] Frame size: ', frame_w, 'x', frame_h);

  { Load GIF to determine dimensions }
  writeln('[SPRITE] Calling draw_gif_block...');
  if not blockx.draw_gif_block(screen_image, dat_name, block_key, 0, 0, palette) then
  begin
    writeln('[SPRITE] ERROR: Failed to load GIF block: ', block_key);
    writeln('[SPRITE] Debug: screen_image=', PtrUInt(screen_image), ' file=', dat_name, ' key=', block_key);
    Exit;
  end;

  { Store the palette for use in extraction }
  Result.palette := palette;

  writeln('[SPRITE] GIF loaded: gif_x=', blockx.gif_x, ' gif_y=', blockx.gif_y);

  { Calculate grid dimensions }
  writeln('[SPRITE] Checking dimensions: gif_x>0 = ', blockx.gif_x > 0, ' gif_y>0 = ', blockx.gif_y > 0);
  if (blockx.gif_x > 0) and (blockx.gif_y > 0) then
  begin
    Result.columns := blockx.gif_x div frame_w;
    Result.rows := blockx.gif_y div frame_h;
    Result.total_frames := Result.columns * Result.rows;

    writeln('[SPRITE] Grid: ', Result.columns, ' columns x ', Result.rows, ' rows');
    writeln('[SPRITE] Total frames: ', Result.total_frames);

    if Result.total_frames > MAX_FRAMES then
    begin
      writeln('[SPRITE] WARNING: Too many frames (', Result.total_frames, ' > ', MAX_FRAMES, ')');
      Result.total_frames := MAX_FRAMES;
    end;
  end
  else
  begin
    writeln('[SPRITE] ERROR: Invalid GIF dimensions');
    Exit;
  end;

  { Extract frames }
  ExtractFramesFromGIF(Result);

  Result.loaded := true;
  writeln('[SPRITE] Spritesheet loaded successfully');
end;

{ Extract frames from loaded GIF }
procedure ExtractFramesFromGIF(var sheet: TSpritesheet);
var
  frame, row, col: word;
  src_x, src_y: word;
  frame_data: PFrame;
  local_x, local_y: word;
  src_idx, dst_idx: longint;
  r, g, b: byte;
  best_idx, best_dist: word;
  i, dist: word;
  non_zero_count: word;
begin
  writeln('[SPRITE] Extracting frames from RGBA data...');

  { NOTE: GIF is already loaded from LoadSpritesheet in RGBA format }
  { The screen_image still contains the GIF data from LoadSpritesheet }

  { DEBUG: Print first few pixels of first frame }
  if sheet.total_frames > 0 then
  begin
    writeln('[SPRITE] DEBUG: First frame at (0,0), screen_width=', screen_width, ' screen_height=', screen_height);
    writeln('[SPRITE] DEBUG: Reading from offset 0, 16, 32...');
    for local_y := 0 to 1 do
      for local_x := 0 to 1 do
      begin
        src_idx := (local_y * screen_width + local_x) * 4;
        r := PByte(screen_image^.data + src_idx)^;
        g := PByte(screen_image^.data + src_idx + 1)^;
        b := PByte(screen_image^.data + src_idx + 2)^;
        writeln('[SPRITE] DEBUG: Pixel (', local_x, ',', local_y, ') = RGB(', r, ',', g, ',', b, ')');
      end;
  end;

  { Extract each frame }
  for frame := 0 to sheet.total_frames - 1 do
  begin
    { Calculate grid position }
    col := frame mod sheet.columns;
    row := frame div sheet.columns;
    src_x := col * sheet.frame_width;
    src_y := row * sheet.frame_height;

    { Allocate frame buffer }
    New(frame_data);
    sheet.frames[frame] := frame_data;

    non_zero_count := 0;

    { Extract pixels directly from RGBA data }
    for local_y := 0 to sheet.frame_height - 1 do
    begin
      for local_x := 0 to sheet.frame_width - 1 do
      begin
        { Read RGBA pixel from screen - use screen_width for correct stride }
        src_idx := ((src_y + local_y) * screen_width + (src_x + local_x)) * 4;
        if src_idx + 3 < (screen_width * screen_height * 4) then
        begin
          r := PByte(screen_image^.data + src_idx)^;
          g := PByte(screen_image^.data + src_idx + 1)^;
          b := PByte(screen_image^.data + src_idx + 2)^;

          { Find nearest palette color using stored palette }
          best_idx := 0;
          best_dist := $7FFFFFFF;
          for i := 0 to 255 do
          begin
            dist := abs(r - (sheet.palette[i].r shl 2)) +
                    abs(g - (sheet.palette[i].v shl 2)) +
                    abs(b - (sheet.palette[i].b shl 2));
            if dist < best_dist then
            begin
              best_dist := dist;
              best_idx := i;
            end;
          end;

          { Store palette index }
          frame_data^[local_y * 16 + local_x] := best_idx;

          { Count non-zero pixels for debugging }
          if best_idx > 0 then
            inc(non_zero_count);
        end;
      end;
    end;

    if (frame mod 10 = 0) then
      writeln('[SPRITE]   Extracted frame ', frame, ' at (', src_x, ',', src_y, ') - ', non_zero_count, ' non-zero pixels');
  end;

  writeln('[SPRITE] Extracted ', sheet.total_frames, ' frames successfully');
end;

{ Get frame from spritesheet }
function GetFrame(sheet: TSpritesheet; frame_num: word): PFrame;
begin
  if frame_num < sheet.total_frames then
    Result := sheet.frames[frame_num]
  else
    Result := nil;
end;

{ Free spritesheet memory }
procedure FreeSpritesheet(var sheet: TSpritesheet);
var
  i: word;
begin
  writeln('[SPRITE] Freeing spritesheet: ', sheet.source_block);

  for i := 0 to MAX_FRAMES - 1 do
  begin
    if sheet.frames[i] <> nil then
    begin
      Dispose(sheet.frames[i]);
      sheet.frames[i] := nil;
    end;
  end;

  sheet.loaded := false;
  writeln('[SPRITE] Spritesheet freed');
end;

{ Initialize animation from spritesheet }
procedure InitAnimation(var anim: TAnimation; var sheet: TSpritesheet; delay_ms: longint);
var
  i: word;
begin
  writeln('[ANIM] Initializing animation (', sheet.total_frames, ' frames, ', delay_ms, 'ms delay)');

  { Copy frame pointers }
  for i := 0 to sheet.total_frames - 1 do
    anim.frames[i] := sheet.frames[i];

  anim.frame_count := sheet.total_frames;
  anim.current_frame := 0;
  anim.frame_delay_ms := delay_ms;
  anim.last_frame_time := GetAnimationTime();
  anim.looping := true;
  anim.playing := false;
  anim.x := 0;
  anim.y := 0;

  writeln('[ANIM] Animation initialized');
end;

{ Free animation (doesn't free frames, those belong to spritesheet) }
procedure FreeAnimation(var anim: TAnimation);
begin
  anim.frame_count := 0;
  anim.playing := false;
  writeln('[ANIM] Animation freed');
end;

{ Update animation frame based on time }
procedure UpdateAnimation(var anim: TAnimation; current_time: longint);
begin
  if not anim.playing then
    Exit;

  { Check if it's time for next frame }
  if current_time - anim.last_frame_time >= anim.frame_delay_ms then
  begin
    { Advance to next frame }
    inc(anim.current_frame);

    { Handle loop or stop }
    if anim.current_frame >= anim.frame_count then
    begin
      if anim.looping then
        anim.current_frame := 0
      else
      begin
        anim.current_frame := anim.frame_count - 1;
        anim.playing := false;
      end;
    end;

    anim.last_frame_time := current_time;
  end;
end;

{ Draw animation frame at position }
procedure DrawAnimationFrame(anim: TAnimation; x, y: word);
begin
  if anim.current_frame < anim.frame_count then
    DrawFrame(anim.frames[anim.current_frame], x, y)
  else
    writeln('[ANIM] WARNING: Invalid frame index ', anim.current_frame);
end;

{ Draw single frame using putseg2 (with transparency) }
procedure DrawFrame(frame: PFrame; x, y: word);
begin
  if frame <> nil then
    putseg2(x, y, TILE_WIDTH, TILE_HEIGHT, 0, TRANSPARENT_COLOR_INDEX, frame^);
end;

{ Set specific animation frame }
procedure SetAnimationFrame(var anim: TAnimation; frame: word);
begin
  if frame < anim.frame_count then
  begin
    anim.current_frame := frame;
    anim.last_frame_time := GetAnimationTime();
  end;
end;

{ Start playing animation }
procedure PlayAnimation(var anim: TAnimation);
begin
  anim.playing := true;
  anim.last_frame_time := GetAnimationTime();
  writeln('[ANIM] Playing animation');
end;

{ Stop animation }
procedure StopAnimation(var anim: TAnimation);
begin
  anim.playing := false;
  writeln('[ANIM] Animation stopped');
end;

{ Reset animation to first frame }
procedure ResetAnimation(var anim: TAnimation);
begin
  anim.current_frame := 0;
  anim.last_frame_time := GetAnimationTime();
  writeln('[ANIM] Animation reset');
end;

end.
