{=======================================================================}
{ vidbase.pas  -  shared data + helpers for the pluggable video system  }
{                                                                       }
{ This is the ONLY unit the concrete backends depend on. Keeping the    }
{ frame buffer, the backend selector, and the env/tracing helpers here  }
{ (instead of in vidif.pas) breaks the vidif<->backend circular use    }
{ that otherwise collides on shared units like Dos. The engine itself  }
{ uses vidif.pas, not vidbase.                                          }
{=======================================================================}
{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit vidbase;

interface

uses
  JXGRAF, JXVAR;

const
  FBW = 640;                 {* engine framebuffer width  (640x480x8 VESA) *}
  FBH = 480;                 {* engine framebuffer height (640x480x8 VESA) *}
  FB_BYTES = FBW*FBH;        {* 8-bit framebuffer size              *}
  FB_RGB = FBW*FBH*3;        {* expanded 24-bit RGB size            *}
  WIN_SCALE = 2;             {* default display scale factor        *}
  WINW = FBW*WIN_SCALE;
  WINH = FBH*WIN_SCALE;

type
  TVidBackend = (vbHeadless, vbSdl, vbRaylib);

{ --- active backend + "is a display backend up" flag ------------------ }
var
  vid_backend: TVidBackend;
  have_backend: boolean;

{ --- shared frame the backends draw from: 24-bit RGB expanded from    }
{     JXGRAF's 8-bit VideoBuffer through the game palette palx.        }
var
  FrameRGB: array[0..FB_RGB-1] of Byte;

{ --- SHMEM double-buffer generation state (headless backend writes these;
       C host reads gen from SHMEM off 0, and engine_generation() exposes it) ---}
var
  curbuf: Integer;
  gen: UInt32;

{ --- one-shot SG_DUMPFILE capture state ------------------------------- }
var
  dumpfile_state: string;
  dumped_once: boolean;

{ --- env helpers (implemented against Dos/SysUtils inside this unit) -- }
function env_on(name: string): boolean;   { true when env var is set }
function env_val(name: string): string;   { value of env var (possibly '' ) }
procedure dbg(msg: string);               { writeln only when VID_DEBUG set }
procedure dbg_num(num: int64);            { prints a frame counter, if debug }

implementation

uses
  Dos, SysUtils;

function env_on(name: string): boolean;
begin env_on := (GetEnv(name) <> ''); end;

function env_val(name: string): string;
begin env_val := GetEnv(name); end;

procedure dbg(msg: string);
begin
  if GetEnv('VID_DEBUG') <> '' then begin
    writeln('[vb] ' + msg);
    flush(output);
  end;
end;

procedure dbg_num(num: int64);
begin
  if GetEnv('VID_DEBUG') <> '' then begin
    writeln('[vb] ' + IntToStr(num));
    flush(output);
  end;
end;

end.
