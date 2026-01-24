unit blockx;

{$mode objfpc}{$H+}

{ This unit handles block file access and resource loading from .DAT files }
{ Ported from original BLOCKX.PAS with modern FPC file I/O }

interface

uses
  Classes,
  SysUtils,
  dos_compat,
  jxgraf,
  jxfont_simple,
  raylib_helpers;

type
  TKey = array[1..8] of char;
  gbuf = array[0..767] of byte;

var
  ResourceFile: boolean;
  ResourceFilename: string;
  SoundSize: longint;
  files_counter: word;

{ Block file management }
function checkblock_info(sub, key: string): boolean;
function checkblock_header(filename: string): boolean;
procedure close_all_files;
function OpenblockFile(FileName: string): boolean;
procedure CloseblockFile;
procedure CloseblockFile_ext(var fil: file);
function GetBlockFile_ext(var fil: file; Key: string): boolean;

{ Block file access }
function MatchingKeys(a, b: TKey): boolean;
procedure GetBlockFile(Key: string);
function Min(a, b: LongInt): LongInt;
function Loadblock_array(sub, kluc: string; var xdata: array of byte): boolean;
function getblock_out(sub, kluc, vystup: string): boolean;

{ Resource loading }
function draw_gif_block(bitmap: pimage; file_name, kluc: string; fromx, fromy: word; var pal: tpalette): boolean;
procedure Font_Load_block(fmeno, kluc: string; var fx, fy: word);
procedure load_palette_block(sub, kluc: string; var palx: tpalette);

implementation

type
  TResource = record
    Key: TKey;
    Start: LongInt;
    Size: LongInt;
  end;

var
  SoundFile: file;
  t: TextFile;
  k: word;

{ Check if a key exists in a block file }
function checkblock_info(sub, key: string): boolean;
var
  NumSounds: Word;  { Changed from integer to Word for 16-bit Turbo Pascal compatibility }
  ResKey: TKey;
  ResHeader: TResource;
  Index: integer;
  i: integer;
  Found: boolean;
  fil: file;
begin
  Found := false;
  {$I-}
  if checkblock_header(sub) then
  begin
    for i := 1 to 8 do
      if i <= Length(key) then
        ResKey[i] := key[i]
      else
        ResKey[i] := #0;

    AssignFile(fil, sub);
    Reset(fil, 1);

    if IOResult <> 0 then
    begin
      write_error('Failed to open block file: ' + sub);
      checkblock_info := false;
      Exit;
    end;

    BlockRead(fil, NumSounds, SizeOf(NumSounds));

    if IOResult <> 0 then
    begin
      CloseFile(fil);
      write_error('Failed to read block count');
      checkblock_info := false;
      Exit;
    end;

    Index := 0;

    while not(Found) and (Index < NumSounds) do
    begin
      Index := Index + 1;
      BlockRead(fil, ResHeader, SizeOf(ResHeader));

      if IOResult <> 0 then
      begin
        CloseFile(fil);
        write_error('Failed to read block header at index ' + IntToStr(Index));
        checkblock_info := false;
        Exit;
      end;

      if MatchingKeys(ResHeader.Key, ResKey) then
        Found := true;
    end;
    CloseFile(fil);
  end;
  checkblock_info := found;
  {$I+}
end;

{ Check if file is a valid block file }
function checkblock_header(filename: string): boolean;
var
  ch: char;
  t: TextFile;
begin
  checkblock_header := false;
  AssignFile(t, filename);
  Reset(t);
  Read(t, ch);
  Read(t, ch);
  if ord(ch) = 0 then
    checkblock_header := true;
  CloseFile(t);
end;

{ Close all open files }
procedure close_all_files;
var
  fl: integer;
begin
  if files_counter < 0 then files_counter := 0;
  if files_counter > 0 then
  begin
    for fl := 1 to files_counter do
      Close(SoundFile);
    files_counter := 0;
  end;
end;

{ Open a block file }
function OpenblockFile(FileName: string): boolean;
begin
  ResourceFile := true;
  ResourceFilename := FileName;
  files_counter := 0;

  OpenblockFile := subor_exist(FileName);
end;

{ Close current block file }
procedure CloseblockFile;
begin
  ResourceFile := false;
  ResourceFilename := '';
  close_all_files;
end;

{ Close block file handle }
procedure CloseblockFile_ext(var fil: file);
begin
  ResourceFile := false;
  ResourceFilename := '';
  {$I-}
  CloseFile(fil);
  {$I+}
end;

{ Compare two keys }
function MatchingKeys(a, b: TKey): boolean;
var
  i: integer;
begin
  MatchingKeys := true;

  for i := 1 to 8 do
    if a[i] <> b[i] then
      MatchingKeys := false;
end;

{ Get block from file and position file pointer }
procedure GetBlockFile(Key: string);
var
  NumSounds: Word;  { Changed from integer to Word for 16-bit Turbo Pascal compatibility }
  ResKey: TKey;
  ResHeader: TResource;
  Index: integer;
  i: integer;
  Found: boolean;
begin
  if ResourceFile then
  begin
    {$I-}
    for i := 1 to 8 do
      if i <= Length(Key) then
        ResKey[i] := Key[i]
      else
        ResKey[i] := #0;

    AssignFile(SoundFile, ResourceFilename);
    Reset(SoundFile, 1);
    BlockRead(SoundFile, NumSounds, SizeOf(NumSounds));

    Found := false;
    Index := 0;

    while not(Found) and (Index < NumSounds) do
    begin
      Index := Index + 1;
      BlockRead(SoundFile, ResHeader, SizeOf(ResHeader));

      if MatchingKeys(ResHeader.Key, ResKey) then
        Found := true;
    end;

    if Found then
    begin
      Seek(SoundFile, ResHeader.Start);
      SoundSize := ResHeader.Size;
    end
    else
      SoundSize := 0;
    {$I+}
  end;
end;

{ Get block file using external file handle }
function GetBlockFile_ext(var fil: file; Key: string): boolean;
type
  TResource = record
    Key: TKey;
    Start: LongInt;
    Size: LongInt;
  end;
var
  NumSounds: Word;  { Changed from integer to Word for 16-bit Turbo Pascal compatibility }
  ResKey: TKey;
  ResHeader: TResource;
  Index: integer;
  i: integer;
  Found: boolean;
begin
  {$I-}
  for i := 1 to 8 do
    if i <= Length(Key) then
      ResKey[i] := Key[i]
    else
      ResKey[i] := #0;

  Reset(fil, 1);
  BlockRead(fil, NumSounds, SizeOf(NumSounds));

  Found := false;
  Index := 0;

  while not(Found) and (Index < NumSounds) do
  begin
    Index := Index + 1;
    BlockRead(fil, ResHeader, SizeOf(ResHeader));

    if MatchingKeys(ResHeader.Key, ResKey) then
      Found := true;
  end;

  if Found then
  begin
    Seek(fil, ResHeader.Start);
  end
  else
    write_error('Header not found: ' + key);
  {$I+}

  GetBlockFile_ext := found;
end;

{ Return minimum of two values }
function Min(a, b: LongInt): LongInt;
begin
  if a < b then
    Min := a
  else
    Min := b;
end;

{ Load block data into array }
function Loadblock_array(sub, kluc: string; var xdata: array of byte): boolean;
const
  loadchunksize = 256;
type
  dat_typ = array[1..loadchunksize] of byte;

var
  Size: LongInt;
  Remaining, par, ffl: LongInt;
  fl: word;
  dato: ^dat_typ;
begin
  if subor_exist(sub) then
  begin
    {$I-}
    openblockfile(sub);
    New(dato);
    upcased(kluc);
    Loadblock_array := false;
    GetblockFile(Kluc);

    if (SoundSize = 0) then
      Exit;

    Remaining := SoundSize;
    ffl := 0;
    repeat
      par := Min(Remaining, LoadChunkSize);
      BlockRead(SoundFile, dato^, par);
      for fl := 1 to par do
      begin
        xdata[ffl] := dato^[fl];
        inc(ffl);
      end;
      Dec(Remaining, par);
    until not(Remaining > 0);

    Close(SoundFile);

    Loadblock_array := true;
    {$I+}
    Dispose(dato);
  end
  else
    write_error('Block file does not exist !');
end;

{ Load block data to file }
function getblock_out(sub, kluc, vystup: string): boolean;
const
  loadchunksize = 256;
type
  dat_typ = array[1..loadchunksize] of byte;

var
  Size: LongInt;
  Remaining, par, ffl: LongInt;
  fl: word;
  dato: ^dat_typ;
begin
  {$I-}
  openblockfile(sub);
  New(dato);
  upcased(kluc);
  getblock_out := false;
  GetblockFile(Kluc);

  if (SoundSize = 0) then
    Exit;

  Remaining := SoundSize;
  ffl := 0;
  AssignFile(t, vystup);
  Rewrite(t);
  repeat
    par := Min(Remaining, LoadChunkSize);
    BlockRead(SoundFile, dato^, par);
    for fl := 1 to par do
    begin
      Write(t, chr(dato^[fl]));
    end;
    Dec(Remaining, par);
  until not(Remaining > 0);
  CloseFile(t);
  dec(files_counter);
  Close(SoundFile);

  getblock_out := true;
  {$I+}
  Dispose(dato);
end;

{ Font loading helpers }
procedure get_parax(var s: string; var vystup: string; var num: word);
begin
  vystup := '';
  repeat
    if (s[num] <> ' ') and (s[num] <> chr(0)) then
      vystup := vystup + s[num];
    inc(num);
  until (num > length(s)) or (s[num] = ' ') or (s[num] = chr(0));
end;

{ Load font from block file }
procedure Font_Load_block(fmeno, kluc: string; var fx, fy: word);
type
  flont = array[1..4107] of byte;
var
  flx: ^flont;
  st1, st2: string;
  num, f, fdlzka, ftransf: word;
begin
  New(flx);
  loadblock_array(fmeno, kluc, flx^);
  num := 1;
  st1 := '';
  repeat
    if flx^[num] <> 0 then
      st1 := st1 + chr(flx^[num]);
    inc(num);
  until flx^[num] = 0;
  num := 1;
  get_parax(st1, st2, num);
  Val(st2, fdlzka, fdlzka);
  get_parax(st1, st2, num);
  Val(st2, fx, fx);
  get_parax(st1, st2, num);
  Val(st2, fy, fy);
  get_parax(st1, st2, num);
  Val(st2, ftransf, ftransf);
  for f := 1 to fdlzka do
  begin
    fontik[f] := flx^[f + num];
  end;

  Dispose(flx);
  setstartchar(-ftransf);
  SetFont(@fontik, fx, fy);
end;

{ Load palette from block file }
procedure load_palette_block(sub, kluc: string; var palx: tpalette);
var
  f, c: word;
  buf: ^gbuf;
begin
  {$I-}
  New(buf);
  if kluc[1] = '>' then
  begin
    kluc := out_string(kluc);
    loadblock_array(sub, kluc, buf^);
    c := 0;
    for f := 0 to 767 do
    begin
      inc(c);
      if c > 3 then c := 1;
      case c of
        1: palx[f div 3].r := buf^[f + 1] shr 2;
        2: palx[f div 3].v := buf^[f + 1] shr 2;
        3: palx[f div 3].b := buf^[f + 1] shr 2;
      end;
    end;
  end
  else
    load_palette(kluc, palx, 0, 255, false);
  {$I+}
  Dispose(buf);
end;

{ Load GIF from block file using Raylib }
function draw_gif_block(bitmap: pimage; file_name, kluc: string; fromx, fromy: word; var pal: tpalette): boolean;
var
  NumSounds: Word;  { Changed from integer to Word for 16-bit Turbo Pascal compatibility }
  ResKey: TKey;
  ResHeader: TResource;
  Index: integer;
  i: integer;
  Found: boolean;
  fil: file;
  data: pointer;
  DataSize: longint;
  BytesRead: longint;
  raylib_img: TRaylibImage;
  x, y: integer;
  pixel_ptr: PByte;
  raw_data: PByte;
  r, g, b, a: byte;
begin
  draw_gif_block := false;
  gif_x := 0;
  gif_y := 0;

  if not subor_exist(file_name) then
  begin
    write_error('File not found: ' + file_name);
    Exit;
  end;

  { Prepare key }
  for i := 1 to 8 do
    if i <= Length(kluc) then
      ResKey[i] := kluc[i]
    else
      ResKey[i] := #0;

  upcased(kluc);

  { Open file and find block }
  AssignFile(fil, file_name);
  Reset(fil, 1);
  BlockRead(fil, NumSounds, SizeOf(NumSounds));

  Found := false;
  Index := 0;

  while not(Found) and (Index < NumSounds) do
  begin
    Index := Index + 1;
    BlockRead(fil, ResHeader, SizeOf(ResHeader));

    if MatchingKeys(ResHeader.Key, ResKey) then
      Found := true;
  end;

  if not Found then
  begin
    CloseFile(fil);
    write_error('Key not found in block file: ' + kluc);
    Exit;
  end;

  { Allocate memory for image data }
  DataSize := ResHeader.Size;
  GetMem(data, DataSize);

  { Seek to data and read it }
  Seek(fil, ResHeader.Start);
  BlockRead(fil, data^, DataSize, BytesRead);
  CloseFile(fil);

  if BytesRead <> DataSize then
  begin
    FreeMem(data);
    write_error('Failed to read complete block');
    Exit;
  end;

  { The data may have obfuscated signature "Jx19989" instead of "GIF89a" }
  { Check and fix if needed }
  if (DataSize >= 6) then
  begin
    { Check if it's the obfuscated "Jx1" format }
    raw_data := PByte(data);
    if (raw_data[0] = Ord('J')) and (raw_data[1] = Ord('x')) and (raw_data[2] = Ord('1')) then
    begin
      writeln('  Detected Jx1 format, converting to GIF89a');
      { Replace Jx19989 with GIF89a }
      raw_data[0] := Ord('G');
      raw_data[1] := Ord('I');
      raw_data[2] := Ord('F');
      raw_data[3] := Ord('8');
      raw_data[4] := Ord('9');
      raw_data[5] := Ord('a');
      writeln('  Signature fixed: GIF89a');
    end
    else
      writeln('  Standard GIF format detected');
  end;

  { Load image using Raylib's stb_image (supports GIF) }
  raylib_img := LoadImageFromMemory('.gif', data, DataSize);

  FreeMem(data);

  if raylib_img.data = nil then
  begin
    write_error('Failed to load GIF from memory');
    Exit;
  end;

  { Update global GIF dimensions }
  gif_x := raylib_img.width;
  gif_y := raylib_img.height;

  { Copy Raylib image to our bitmap format with transparency support }
  { Pink/magenta background (RGB 252,84,252 or similar) is transparent }
  pixel_ptr := PByte(raylib_img.data);

  for y := 0 to raylib_img.height - 1 do
  begin
    for x := 0 to raylib_img.width - 1 do
    begin
      { Read RGBA from Raylib }
      r := pixel_ptr^;
      Inc(pixel_ptr);
      g := pixel_ptr^;
      Inc(pixel_ptr);
      b := pixel_ptr^;
      Inc(pixel_ptr);
      a := pixel_ptr^;
      Inc(pixel_ptr);

      { Check for transparent pink/magenta background }
      { Pink range: R:250-255, G:0-100, B:250-255 }
      if (r >= 250) and (r <= 255) and (g >= 0) and (g <= 100) and (b >= 250) and (b <= 255) then
      begin
        { Skip transparent pixels - don't draw }
      end
      else if a = 0 then
      begin
        { Also skip if alpha is 0 }
      end
      else
      begin
        { Write opaque pixel to bitmap }
        putpixel(bitmap, fromx + x, fromy + y, (a shl 24) or (r shl 16) or (g shl 8) or b);
      end;
    end;
  end;

  { Unload Raylib image }
  UnloadImage(raylib_img);

  draw_gif_block := true;
end;

end.
