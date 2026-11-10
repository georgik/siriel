{=======================================================================}
{ vid_png.pas  -  native PNG encoder for the Siriel 3 framebuffer       }
{                                                                       }
{ Standalone unit: reads JxGRAF's 8-bit VideoBuffer + the game palette  }
{ palx directly and writes an 8-bit, colour-type-2 (RGB) PNG. Uses FPC's }
{ static paszlib (zdeflate / zbase / adler) for DEFLATE. Kept in its    }
{ OWN unit so the paszlib symbols never collide with the vidif         }
{ dispatcher's SysUtils / shortstring code (which tripped the          }
{ inflate_codes_mode / copy error before).                             }
{                                                                       }
{ IMPORTANT: the engine builds in -Mtp mode where `Integer` is 16-bit.  }
{ Every variable that can hold a framebuffer-size value (>= 32768) or  }
{ a byte offset into the framebuffer MUST be `LongInt`, else it        }
{ silently wraps (e.g. rawlen 230640 -> -31504, which crashed deflate). }
{=======================================================================}
{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit vid_png;

interface

uses
  JxGRAF, JXVAR, zdeflate, zbase;

procedure vid_dump_png(name: string); {* capture the last VideoBuffer to a PNG *}

implementation

{ --- raw libc file IO (bypasses FPC BlockWrite free-space precheck) --- }
const
  O_WRONLY = 1; O_CREAT = 64; O_TRUNC = 512;
  PNGSIG: array[0..7] of Byte = ($89,$50,$4E,$47,$0D,$0A,$1A,$0A);
function c_open(path: PAnsiChar; flags, mode: Integer): Integer; cdecl; external 'libc' name 'open';
function c_write(fd: Integer; buf: Pointer; count: LongWord): Integer; cdecl; external 'libc' name 'write';
function c_close(fd: Integer): Integer; cdecl; external 'libc' name 'close';

{ --- CRC-32 (IEEE) lazy table + scratch. File scope (BSS, not stack)
       because the worst-case raw-deflate size (~922 KB for the 640x480
       frame) is far too large for a stack-local. }
var
  crc_ready: boolean;
  crc_table: array[0..255] of LongWord;
  compBuf:   array[0..1048575] of Byte;   { 1 MB: headroom for worst-case DEFLATE output of the 640x480 frame }
  chunktmp:  array[0..1048575] of Byte;   { >= compBuf: holds IDAT body + 4-byte chunk header }
  { large frame/scratch buffers at file scope (BSS), never on the stack:
    rawin = filtered framebuffer (1921*480 = 922080 B), obuf = deflate output. }
  rawin:   array[0..(640*3+1)*480-1] of Byte;  {* 640x480 framebuffer: 1921*480 = 922080 B *}
  obuf:    array[0..65535] of Byte;

procedure crc_init;
var ii, jj: Integer; cc: LongWord;
begin
  crc_table[0] := 0;
  for ii := 1 to 255 do begin
    cc := ii;
    for jj := 0 to 7 do
      if (cc and 1) <> 0 then cc := (cc shr 1) xor $EDB88320
      else cc := cc shr 1;
    crc_table[ii] := cc;
  end;
  crc_ready := true;
end;

function crc32c(crc: LongWord; buf: Pointer; n: LongWord): LongWord;
var x: LongWord; b: Byte; pc: PAnsiChar;
begin
  pc := PAnsiChar(buf);
  for x := 0 to n-1 do begin
    b := Ord(pc[x]);
    crc := crc_table[(crc xor b) and $FF] xor (crc shr 8);
  end;
  crc32c := crc;
end;

{ --- write the shared VideoBuffer + palx as an 8-bit RGB PNG. Reads the
       framebuffer directly (no FrameRGB / expand_frame needed). RAW
       DEFLATE from deflateInit/deflate is wrapped by hand with the 2-byte
       zlib header (78 9C) and the 4-byte adler32 trailer that PNG's IDAT
       requires. The whole (filtered) framebuffer is fed to deflate in one
       shot, which keeps the stream simple and well-formed. }
procedure vid_dump_png(name: string);
const
  FBW = 640;
  FBH = 480;   {* 640x480x8 VESA framebuffer (see find_best_mode Phase-2 fallback). *}
type
  TScan = array[0..(640*3)] of Byte;   { 1 filter byte + 640*3 RGB }
var
  namebuf: array[0..255] of AnsiChar;
  fd, i: Integer;
  ihdr: array[0..12] of Byte;
  name4: array[0..3] of Byte;
  len4: array[0..3] of Byte;
  rowbuf: TScan;
  compLen, r, produced, rawlen, idatlen: LongInt;
  x, y: LongInt;                 { index math must be 32-bit (see header) }
  idx: Byte;
  strm: z_stream;

  { write one PNG chunk: len(4) + type(4) + contiguous data(n) + crc(4) }
  procedure wchunk(dt: Pointer; nn: LongWord);
    { nn = total contiguous chunk bytes = 4-byte type + data payload.      
      Call sites lay "TYPE"+data contiguously and pass 4+datalen:          
      IHDR->17 (4+13), IDAT->4+idatlen, IEND->4 (4+0). }
    var c: LongWord; dl: LongWord;
    begin
      c := $FFFFFFFF;
      c := crc32c(c, dt, nn);                       { CRC over type+data }
      c := c xor $FFFFFFFF;
      dl := nn - 4;                                  { payload length }
      len4[0] := (dl shr 24) and $FF; len4[1] := (dl shr 16) and $FF;
      len4[2] := (dl shr 8) and $FF;   len4[3] := dl and $FF;
      c_write(fd, @len4[0], 4);
      c_write(fd, dt, nn);                           { type + data }
      len4[0] := c and $FF;    len4[1] := (c shr 8) and $FF;
      len4[2] := (c shr 16) and $FF;  len4[3] := (c shr 24) and $FF;
      c_write(fd, @len4[0], 4);
    end;
begin
  if not crc_ready then crc_init;

  { IHDR: width=640,height=480,bitdepth=8,colourtype=2(RGB),comp=0,filter=0,interlace=0 }
  ihdr[0] := (FBW shr 24) and $FF; ihdr[1] := (FBW shr 16) and $FF;
  ihdr[2] := (FBW shr 8) and $FF;  ihdr[3] := FBW and $FF;
  ihdr[4] := (FBH shr 24) and $FF; ihdr[5] := (FBH shr 16) and $FF;
  ihdr[6] := (FBH shr 8) and $FF;  ihdr[7] := FBH and $FF;
  ihdr[8] := 8;  ihdr[9] := 2;  ihdr[10] := 0;  ihdr[11] := 0;  ihdr[12] := 0;

  { --- build the filtered framebuffer: 1 filter byte (0=none) + RGB per row }
  rawlen := 0;
  for y := 0 to FBH-1 do begin
    rowbuf[0] := 0;                 { filter type 0 = none }
    for x := 0 to FBW-1 do begin
      idx := VideoBuffer[y*FBW + x];   { y*FBW reaches 76480 -> needs 32-bit }
      rowbuf[1 + x*3 + 0] := palx[idx].r;
      rowbuf[1 + x*3 + 1] := palx[idx].v;
      rowbuf[1 + x*3 + 2] := palx[idx].b;
    end;
    move(rowbuf[0], rawin[rawlen], FBW*3 + 1);
    rawlen := rawlen + FBW*3 + 1;
  end;

  { --- single-shot DEFLATE over the whole filtered framebuffer.
       NOTE: this paszlib build's deflate emits a full ZLIB stream
       (2-byte 78 9C header + raw-DEFLATE body + 4-byte adler32 trailer),
       so compBuf holds [hdr][body][adler]. PNG IDAT needs only the raw
       DEFLATE body = compBuf[2 .. compLen-5]. }
  FillChar(strm, sizeof(strm), 0);
  deflateInit(strm, Z_DEFAULT_COMPRESSION);
  compLen := 0;
  strm.next_in  := @rawin[0];
  strm.avail_in := rawlen;
  repeat
    strm.next_out := @obuf[0];
    strm.avail_out := sizeof(obuf);
    r := deflate(strm, Z_NO_FLUSH);
    produced := sizeof(obuf) - strm.avail_out;
    if (produced > 0) and (compLen + produced <= sizeof(compBuf)) then begin
      move(obuf[0], compBuf[compLen], produced);
      compLen := compLen + produced;
    end;
  until (r <> 0) or (strm.avail_in = 0);
  { flush buffered output + end marker }
  strm.next_in := nil; strm.avail_in := 0;
  repeat
    strm.next_out := @obuf[0];
    strm.avail_out := sizeof(obuf);
    r := deflate(strm, Z_FINISH);
    produced := sizeof(obuf) - strm.avail_out;
    if (produced > 0) and (compLen + produced <= sizeof(compBuf)) then begin
      move(obuf[0], compBuf[compLen], produced);
      compLen := compLen + produced;
    end;
  until (r = Z_STREAM_END) or (r < 0);
  deflateEnd(strm);

  { --- write signature + IHDR + IDAT(raw-DEFLATE body) + IEND }
  { path -> PAnsiChar }
  for i := 1 to length(name) do namebuf[i-1] := AnsiChar(name[i]);
  namebuf[length(name)] := #0;
  fd := c_open(@namebuf[0], O_WRONLY or O_CREAT or O_TRUNC, 644);
  if fd < 0 then exit;
  c_write(fd, @PNGSIG[0], 8);

  { IHDR: lay "IHDR"+13 bytes contiguously, then chunk it }
  name4[0] := Ord('I'); name4[1] := Ord('H'); name4[2] := Ord('D'); name4[3] := Ord('R');
  move(name4[0], chunktmp[0], 4);
  move(ihdr[0], chunktmp[4], 13);
  wchunk(@chunktmp[0], 17);

  { IDAT: raw DEFLATE body = compBuf[2 .. compLen-5] }
  idatlen := compLen - 6;
  name4[0] := Ord('I'); name4[1] := Ord('D'); name4[2] := Ord('A'); name4[3] := Ord('T');
  move(name4[0], chunktmp[0], 4);
  move(compBuf[2], chunktmp[4], idatlen);
  wchunk(@chunktmp[0], 4 + idatlen);

  { IEND }
  name4[0] := Ord('I'); name4[1] := Ord('E'); name4[2] := Ord('N'); name4[3] := Ord('D');
  move(name4[0], chunktmp[0], 4);
  wchunk(@chunktmp[0], 4);

  c_close(fd);
end;

end.
