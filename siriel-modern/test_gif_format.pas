program test_gif_format;

{$mode objfpc}{$H+}

{ Diagnostic test to check GIF pixel format from Raylib
  Samples pixel data to understand byte order
}

uses
  ctypes,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  blockx,
  dos_compat,
  SysUtils;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  palette: tpalette;
  gif_loaded: boolean;
  raylib_img: TRaylibImage;
  data: pointer;
  DataSize: longint;
  NumSounds: Word;
  ResKey: TKey;
  ResHeader: TResource;
  Index: integer;
  i: integer;
  Found: boolean;
  fil: file;
  BytesRead: longint;
  pixel_ptr: PByte;
  r, g, b, a: byte;
  x, y: integer;
  sample_count: integer;

begin
  writeln('=== GIF Pixel Format Diagnostic ===');
  writeln('');

  { Initialize Raylib }
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'GIF Format Test');
  SetTargetFPS(60);

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  jxgraf.fill_palette_default;

  { Load GTREEP from SIRIEL35.DAT }
  writeln('[1] Loading GTREEP GIF...');

  { Prepare key }
  for i := 1 to 8 do
    if i <= Length('GTREEP') then
      ResKey[i] := 'GTREEP'[i]
    else
      ResKey[i] := #0;

  { Open file and find block }
  AssignFile(fil, 'data/SIRIEL35.DAT');
  Reset(fil, 1);
  BlockRead(fil, NumSounds, SizeOf(NumSounds));

  Found := false;
  Index := 0;

  while not(Found) and (Index < NumSounds) do
  begin
    Inc(Index);
    BlockRead(fil, ResHeader, SizeOf(ResHeader));

    if MatchingKeys(ResHeader.Key, ResKey) then
      Found := true;
  end;

  if not Found then
  begin
    writeln('ERROR: GTREEP not found');
    CloseWindow;
    Exit;
  end;

  { Read GIF data }
  DataSize := ResHeader.Size;
  GetMem(data, DataSize);
  Seek(fil, ResHeader.Start);
  BlockRead(fil, data^, DataSize, BytesRead);
  CloseFile(fil);

  { Fix Jx1 signature if needed }
  if (DataSize >= 6) then
  begin
    pixel_ptr := PByte(data);
    if (pixel_ptr[0] = Ord('J')) and (pixel_ptr[1] = Ord('x')) and (pixel_ptr[2] = Ord('1')) then
    begin
      pixel_ptr[0] := Ord('G');
      pixel_ptr[1] := Ord('I');
      pixel_ptr[2] := Ord('F');
      pixel_ptr[3] := Ord('8');
      pixel_ptr[4] := Ord('9');
      pixel_ptr[5] := Ord('a');
    end;
  end;

  { Load with Raylib }
  raylib_img := LoadImageFromMemory('.gif', data, DataSize);
  FreeMem(data);

  if raylib_img.data = nil then
  begin
    writeln('ERROR: Failed to load GIF');
    CloseWindow;
    Exit;
  end;

  writeln('  Loaded: ', raylib_img.width, 'x', raylib_img.height);
  writeln('  Format: ', raylib_img.format);
  writeln('  PIXELFORMAT_UNCOMPRESSED_R8G8B8A8 = ', PIXELFORMAT_UNCOMPRESSED_R8G8B8A8);
  writeln('');

  { Sample pixels at different locations }
  writeln('[2] Sampling pixel data (first 10 pixels):');
  writeln('');

  pixel_ptr := PByte(raylib_img.data);
  sample_count := 0;

  for y := 0 to 0 do
  begin
    for x := 0 to 9 do
    begin
      { Read as stored by Raylib }
      r := pixel_ptr^; Inc(pixel_ptr);
      g := pixel_ptr^; Inc(pixel_ptr);
      b := pixel_ptr^; Inc(pixel_ptr);
      a := pixel_ptr^; Inc(pixel_ptr);

      writeln('  Pixel[', sample_count, '] at (', x, ',', y, '):');
      writeln('    Byte0=', r, ' Byte1=', g, ' Byte2=', b, ' Byte3=', a);
      writeln('    If R-G-B-A: R=', r, ' G=', g, ' B=', b, ' A=', a);
      writeln('    If B-G-R-A: R=', b, ' G=', g, ' B=', r, ' A=', a);

      { Check which makes more sense }
      if (r > 200) and (g < 50) and (b < 50) then
        writeln('    -> Red pixel (if R-G-B-A)')
      else if (b > 200) and (g < 50) and (r < 50) then
        writeln('    -> Blue pixel (if R-G-B-A)')
      else if (r > 200) and (g < 50) and (b < 50) then
        writeln('    -> Blue pixel (if B-G-R-A)')
      else if (b > 200) and (g < 50) and (r < 50) then
        writeln('    -> Red pixel (if B-G-R-A)');

      inc(sample_count);
      writeln('');
    end;
  end;

  UnloadImage(raylib_img);
  CloseWindow;
  writeln('');
  writeln('=== Analysis Complete ===');
  writeln('');
  writeln('This shows us the actual byte order in Raylib pixel data.');
  writeln('If byte 0 has high values where we expect blue, then format is B-G-R-A');
  writeln('If byte 0 has high values where we expect red, then format is R-G-B-A');
  writeln('');
end.
