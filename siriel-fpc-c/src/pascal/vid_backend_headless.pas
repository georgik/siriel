{=======================================================================}
{ vid_backend_headless.pas  -  no-display backend + optional frame export}
{                                                                       }
{ Renders nothing to a screen. The engine still draws into JxGRAF's    }
{ VideoBuffer; this backend just discards the expanded frame.           }
{                                                                       }
{ Optional frame export: when env SHMEM is set, the expanded 24-bit    }
{ framebuffer is written every frame into a plain temp file that an    }
{ external (Swift/Cocoa) host can mmap and display. We use a plain file }
{ instead of POSIX shm because macOS has no /dev/shm, so shm_open     }
{ fails here. This keeps ALL AppKit off the FPC main thread -> no     }
{ SIGILL. Layout of the file:                                           }
{   off 0         : UInt32 generation index (0 or 1) = "fresh" buffer  }
{   off 4         : buffer[0] : FB_RGB bytes                           }
{   off 4+FB_RGB  : buffer[1] : FB_RGB bytes                           }
{ A consumer reads gen, then reads buffer[gen]. Double buffering       }
{ avoids reading a half-written frame.                                }
{=======================================================================}
unit vid_backend_headless;

interface

uses vidbase;

function  headless_name: string;
function  headless_init: boolean;
procedure headless_present;
{ --- one-shot export hook: export current frame, then terminate engine --- }
procedure headless_present_stop;
procedure headless_shutdown;

implementation

uses
  SysUtils;

var
  frame_count: int64;
  { --- frame-export file state --- }
  fd: LongInt;
  { --- gen/curbuf now live in vidbase (shared, C-readable) --- }
  fpath: array[0..127] of AnsiChar;

{ --- libc direct IO (bypasses FPC BlockWrite, whose free-space       ---
{ --- precheck is clobbered by the engine's out-of-bounds corruption). ---
{ NOTE: this binary is built with -Mtp (Turbo-Pascal mode), where
{   'Integer' is a 16-bit signed type (== SmallInt), NOT 32-bit. Any
{   value that can exceed 32767 (byte counts, file offsets, sizes)
{   MUST use 'LongInt' (32-bit) or 'int64' or it silently wraps.      }
const
  {$IFDEF LINUX}
  O_WRONLY = 1;    { 0x0001 }
  O_CREAT  = 64;   { 0x0040  Linux }
  O_TRUNC  = 512;  { 0x0200  Linux }
  {$ELSE}
  O_WRONLY = 1;   { 0x0001 }
  O_CREAT  = 512; { 0x00000200  macOS/Darwin }
  O_TRUNC  = 1024;{ 0x00000400  macOS/Darwin }
  {$ENDIF}
  MODE_644 = 420; { 0o644 }
  GEN_SIZE = 4;
  TOTAL    = GEN_SIZE + 2*FB_RGB;

function c_open(path: Pointer; flags, mode: Integer): LongInt; cdecl; external 'libc' name 'open';
function c_write(fd: LongInt; buf: Pointer; count: LongInt): LongInt; cdecl; external 'libc' name 'write';
function c_lseek(fd: LongInt; offset: LongInt; whence: Integer): LongInt; cdecl; external 'libc' name 'lseek';
function ftruncate(fd: LongInt; length: int64): LongInt; cdecl; external 'libc' name 'ftruncate';
function c_close(fd: LongInt): LongInt; cdecl; external 'libc' name 'close';
{ --- hard exit (no FPC cleanup, no buffering flush) after one-shot export --- }
procedure c_exit(code: Integer); cdecl; external 'libc' name '_exit';

procedure fput(fd: LongInt; buf: Pointer; count: LongInt; off: LongInt);
var
  p: Pointer; n: LongInt; w: LongInt;
begin
  w := c_lseek(fd, off, 0);
  dbg('fput off=' + IntToStr(off) + ' count=' + IntToStr(count) + ' counthex=' + IntToStr($10000 + (count and $FFFF)));
  dbg('fput FB_RGB_fresh=' + IntToStr(FB_RGB));
  p := buf; n := count;
  while n > 0 do begin
    n := n - c_write(fd, p, n);
    dbg('   write_rem=' + IntToStr(n) + ' adv=' + IntToStr(count - n));
    if n < 0 then exit;              { write error }
    inc(p, count - n);
  end;
end;

procedure frame_init;
var
  s: string;
begin
  fd := -1;
  curbuf := 0;
  gen := 0;
  if not env_on('SHMEM') then begin
    exit;
  end;
  s := env_val('SHMEM_PATH');
  if s = '' then s := '/tmp/siriel_frame';
  StrPCopy(fpath, s);
  fd := c_open(@fpath[0], O_WRONLY or O_CREAT or O_TRUNC, MODE_644);
  if fd < 0 then begin
    dbg('frame export OFF (open failed)');
    exit;
  end;
  ftruncate(fd, TOTAL);
  { seed empty buffers + gen so a host sees a valid frame immediately }
  fput(fd, @FrameRGB[0], FB_RGB, GEN_SIZE);
  fput(fd, @gen, 4, 0);
  dbg('frame export ON ' + s + ' fd=' + IntToStr(fd));
end;

procedure frame_present;
var
  buf: Integer;
  off: LongInt;
begin
  buf := 1 - curbuf;
  off := GEN_SIZE + int64(buf)*FB_RGB;
  fput(fd, @FrameRGB[0], FB_RGB, off);
  curbuf := buf;
  gen := UInt32(buf);
  fput(fd, @gen, 4, 0);
end;

function headless_name: string;
begin headless_name := 'headless'; end;

function headless_init: boolean;
begin
  dbg('init (no display; frames discarded) FB_RGB=' + IntToStr(FB_RGB));
  frame_init;
  headless_init := true;
end;

procedure headless_present;
var srgb: int64; j: LongInt;
begin
  inc(frame_count);
  { --- C-owns-the-window mode (env C_DISPLAY=1): the C host uploads
     FrameRGB into its own window and presents. This Pascal backend is
     then a pure no-op — skip the srgb accounting and any SHMEM export,
     since C is responsible for display. expand_frame (in vid_present) still
     runs and keeps FrameRGB fresh for the C host to read. --- }
  if env_on('C_DISPLAY') then exit;
  srgb := 0;
  for j := 0 to FB_RGB-1 do srgb := srgb + ord(FrameRGB[j]);
  dbg('headless_present #' + IntToStr(frame_count) + ' framergb=' + IntToStr(srgb) + ' fd=' + IntToStr(fd));
  { --- guard on the ENV, not the clobberable fd: the engine's OOB writes
     can flip the 'fd' global from -1 to 0 (or anything else), so trusting
     it makes headless_present try to export into a bogus fd. Export is
     opt-in via SHMEM, so only export when SHMEM is actually set AND fd is
     still a valid descriptor. In no-shmem mode we simply discard. --- }
  if env_on('SHMEM') and (fd >= 0) then begin
    frame_present;
  end;
  dbg_num(frame_count);
end;

{ --- one-shot: write the current frame, then terminate the engine ---
{   When SHMEM_NOEXIT is set the frame is still exported, but the process is
   left alive (no c_exit), so a host that dlopened the engine can read the
   frame from the same process and keep running. Without it, ONE_FRAME exits
   the process (as before).                                            }
procedure headless_present_stop;
begin
  dbg('HPS ENTER');
  inc(frame_count);
  { --- same env-guard as headless_present (fd is clobberable) --- }
  if env_on('SHMEM') and (fd >= 0) then frame_present;
  dbg_num(frame_count);
  dbg('ONE_FRAME env=[' + env_val('ONE_FRAME') + ']');
  if env_on('ONE_FRAME') then begin
    if fd >= 0 then c_close(fd);
    if not env_on('SHMEM_NOEXIT') then c_exit(0);
  end;
end;

procedure headless_shutdown;
begin
  dbg('shutdown');
  if fd >= 0 then begin
    dbg_num(frame_count);
    c_close(fd);
  end;
end;

end.
