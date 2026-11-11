{=======================================================================}
{ vid_dispatch.inc  -  included at the end of vidif.pas implementation  }
{                                                                       }
{ Holds: the build-time default backend, the shared frame-expansion,    }
{ the SG_DUMPFILE one-shot capture, and the runtime dispatcher that     }
{ routes vid_init/present/shutdown/dump/name to the active backend.     }
{                                                                       }
{ Shared state (FrameRGB, vid_backend, have_backend, dumpfile_state,    }
{ dumped_once) lives in vidbase.pas. The raw libc externals must live  }
{ at implementation scope of vidif (FPC forbids 'external' locals),    }
{ so they are declared here at the top of this include.                }
{=======================================================================}

{ --- raw libc file IO (bypasses FPC BlockWrite, whose free-space       }
{ --- precheck is clobbered by the engine's out-of-bounds corruption).  }
const
  {$IFDEF LINUX}
  O_WRONLY = 1; O_CREAT = 64; O_TRUNC = 512; SEEK_SET = 0;  { Linux }
  {$ELSE}
  O_WRONLY = 1; O_CREAT = 512; O_TRUNC = 1024; SEEK_SET = 0; { macOS/Darwin }
  {$ENDIF}
function c_open(path: PAnsiChar; flags, mode: Integer): Integer; cdecl; external 'libc' name 'open';
function c_write(fd: Integer; buf: Pointer; count: Integer): Integer; cdecl; external 'libc' name 'write';
function c_close(fd: Integer): Integer; cdecl; external 'libc' name 'close';
function c_lseek(fd: Integer; offset: LongInt; whence: Integer): LongInt; cdecl; external 'libc' name 'lseek';

{ --- build-time default backend (override at runtime with VID_BACKEND) ---
{   Picks the richest backend that was compiled in. VID_BACKEND at run
    time can still choose among any compiled-in backend.                }
{$IFDEF VID_RAYLIB}
const DEF_BACKEND: TVidBackend = vbRaylib;
{$ELSE}
{$IFDEF VID_SDL}
const DEF_BACKEND: TVidBackend = vbSdl;
{$ELSE}
const DEF_BACKEND: TVidBackend = vbHeadless;
{$ENDIF}
{$ENDIF}

{ --- env->backend selection, case-insensitive -------------------------- }
function pick_backend: TVidBackend;
var s: string; i: byte; c: char; res: string;
begin
  s := env_val('VID_BACKEND');
  res := '';
  for i := 1 to length(s) do begin
    c := s[i];
    if (c >= 'a') and (c <= 'z') then c := chr(ord(c) - 32);
    res := res + c;
  end;
  if res = 'HEADLESS' then pick_backend := vbHeadless
  else begin
    if res = 'SDL' then pick_backend := vbSdl
    else begin
      if res = 'RAYLIB' then pick_backend := vbRaylib
      else pick_backend := DEF_BACKEND;
    end;
  end;
end;

{ --- expand JXGRAF 8-bit VideoBuffer + palx into 24-bit RGB ------------ }
procedure expand_frame;
var x, y: word; idx: byte; p: int64;
begin
  for y := 0 to FBH-1 do
    for x := 0 to FBW-1 do begin
      {* In -Mtp (Turbo-Pascal) mode 'integer' is 16-bit signed, so the byte
         offset (y*640+x)*3 OVERFLOWED for rows >= 18 (>=34560) and wrote
         FrameRGB at a wrapped/negative index -- leaving every row below 18
         black. Use int64 for the offset. *}
      idx  := VideoBuffer[y*FBW + x];   {* 640 stride (640x480x8 framebuffer) *}
      p    := (int64(y)*FBW + x)*3;
      FrameRGB[p+0] := palx[idx].r;
      FrameRGB[p+1] := palx[idx].v;
      FrameRGB[p+2] := palx[idx].b;
    end;
end;

{ --- write the shared FrameRGB to a PPM (P6). Uses raw libc write() so  }
{ --- the engine's OOB corruption cannot defeat the write precheck.    }
procedure dump_ppm(name: string);
const
  HEADER: array[0..14] of AnsiChar =
    ('P','6',Chr(10),'6','4','0',' ','4','8','0',Chr(10),'2','5','5',Chr(10));
var
  namebuf: array[0..255] of AnsiChar;
  fd, wpos, chunk: Integer;
begin
  StrPCopy(namebuf, name);
  fd := c_open(namebuf, O_WRONLY or O_CREAT or O_TRUNC, 644);
  if fd < 0 then exit;
  c_lseek(fd, 0, SEEK_SET);              { always overwrite, never append }
  c_write(fd, @HEADER[0], 15);
  wpos := 0;
  while wpos < FB_RGB do begin
    chunk := FB_RGB - wpos;
    if chunk > 2048 then chunk := 2048;
    c_write(fd, @FrameRGB[wpos], chunk);
    wpos := wpos + chunk;
  end;
  c_lseek(fd, FB_RGB + 15, SEEK_SET);
  c_write(fd, nil, 0);
  c_close(fd);
end;

{ --- engine-facing API: dispatcher ------------------------------------ }
procedure vid_init;
var de: string;
begin
  vid_backend := pick_backend;
  { optional one-shot capture path, from env SG_DUMPFILE (may be '=value') }
  de := env_val('SG_DUMPFILE');
  if (length(de) > 0) and (de[1] = '=') then de := copy(de, 2, length(de)-1)
  else de := '';
  dumpfile_state := de;
  dumped_once    := false;
  have_backend   := false;
  case vid_backend of
    vbHeadless: have_backend := headless_init;
    {$IFDEF VID_SDL}
    vbSdl:      have_backend := sdl_backend_init;
    {$ENDIF}
    {$IFDEF VID_RAYLIB}
    vbRaylib:   have_backend := raylib_init;
    {$ENDIF}
  end;
end;

{ --- one-shot raw 8-bit VideoBuffer dump (env RAWVID=1) for debugging the
       horizontal pitch. Writes FBW*FBH raw palette indices to a file.
       NOTE: in -Mtp 'Integer' is 16-bit signed, so any framebuffer-size
       offset/byte-count MUST be LongInt or it silently wraps (see vid_png). --- }
procedure dump_rawvid(name: string);
const
  {$IFDEF LINUX}
  O_CREAT = 64; O_TRUNC = 512;
  {$ELSE}
  O_CREAT = 512; O_TRUNC = 1024;
  {$ENDIF}
var
  namebuf: array[0..255] of AnsiChar;
  fd, chunk: LongInt;
  wpos: LongInt;
begin
  (* Phase 5: only announce RAWVID status when it is actually set. Previously
     this printed "env_on=FALSE" every frame (dump_rawvid runs each frame),
     flooding the log (~170 lines/run). *)
  if env_on('RAWVID') then writeln('[RAWVID] env_on=TRUE')
  else exit;
  StrPCopy(namebuf, name);
  fd := c_open(namebuf, O_WRONLY or O_CREAT or O_TRUNC, 644);
  writeln('[RAWVID] open fd=', fd);
  if fd < 0 then exit;
  wpos := 0;
  while wpos < FB_BYTES do begin
    chunk := FB_BYTES - wpos;
    if chunk > 2048 then chunk := 2048;
    c_write(fd, @VideoBuffer[wpos], chunk);
    wpos := wpos + chunk;
  end;
  c_close(fd);
  writeln('[RAWVID] done wrote ~', FB_BYTES, ' bytes');
end;

procedure vid_present;
begin
  expand_frame;
  dump_rawvid('/tmp/siriel_shm/raw_video.raw');
  case vid_backend of
    vbHeadless: begin
      headless_present;
    end;
    {$IFDEF VID_SDL}
    vbSdl:      sdl_present;
    {$ENDIF}
    {$IFDEF VID_RAYLIB}
    vbRaylib:   raylib_present;
    {$ENDIF}
  end;
  { one-shot SG_DUMPFILE capture (shared by every backend) }
  if (dumpfile_state <> '') and not dumped_once then begin
    dump_ppm(dumpfile_state);
    dumped_once := true;
  end;
end;

{ --- one-shot export hook (only acts when ONE_FRAME is set) -------------- }
{   Exports the current VideoBuffer into the shared frame file and then
     terminates the engine, so a host process can load the single frame.
     When ONE_FRAME is unset this is a pure no-op and normal runs are
     unaffected. Shared by every backend.                                            }
procedure vid_present_stop;
var lbk: TVidBackend;   { capture before the engine's OOB corruption clobbers vid_backend }
begin
  lbk := vid_backend;
  dbg('captured lbk');
  if not env_on('ONE_FRAME') then exit;
  expand_frame;
  if lbk = vbHeadless then begin
    dbg('calling headless_present_stop');
    headless_present_stop;
  end;
end;

procedure vid_dump_frame(name: string);
begin
  expand_frame;
  dump_ppm(name);
end;

procedure vid_dump_png(name: string);
begin
  expand_frame;
  vid_png.vid_dump_png(name);
end;

procedure vid_shutdown;
begin
  case vid_backend of
    vbHeadless: headless_shutdown;
    {$IFDEF VID_SDL}
    vbSdl:      sdl_shutdown;
    {$ENDIF}
    {$IFDEF VID_RAYLIB}
    vbRaylib:   raylib_shutdown;
    {$ENDIF}
  end;
  have_backend := false;
end;

function vid_backend_name: string;
begin
  case vid_backend of
    vbHeadless: vid_backend_name := 'headless';
    vbSdl:      vid_backend_name := 'sdl';
    vbRaylib:   vid_backend_name := 'raylib';
  end;
end;
