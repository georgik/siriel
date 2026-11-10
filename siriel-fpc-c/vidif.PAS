{=======================================================================}
{ vidif.pas  -  pluggable video-backend interface for Siriel 3 (FPC)    }
{                                                                       }
{ The engine (SI35.PAS) uses ONLY this unit. It owns the backend-     }
{agnostic API and a small dispatcher. Concrete backends live in their  }
{ own vid_backend_*.pas units with uniquely-named entry points, so     }
{ several backends can coexist and be selected at runtime via          }
{ VID_BACKEND (headless|sdl|raylib), or at build time via -d.          }
{                                                                       }
{ Shared data + env/tracing helpers live in vidbase.pas to avoid a     }
{ circular vidif<->backend dependency.                                  }
{=======================================================================}
{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit vidif;

interface

uses
  vidbase, JxGRAF, JXVAR;

{ --- engine-facing API (identical contract for every backend) --------- }
procedure vid_init;                       {* create the backend surface *}
procedure vid_present;                  {* present the last framebuffer *}
procedure vid_present_stop;             {* one-shot export + engine exit (ONE_FRAME) *}
procedure vid_dump_frame(name: string); {* capture the last frame to a PPM *}
procedure vid_dump_png(name: string); {* capture the last frame to a PNG *}
procedure vid_shutdown;                 {* release backend resources    *}
function  vid_backend_name: string;     {* "headless" | "sdl" | "raylib" *}

implementation

{ Concrete backends live in their own vid_backend_*.pas units with
  uniquely-named entry points. Only the backends whose libraries are
  present are compiled in (build.sh passes the -dVID_SDL / -dVID_RAYLIB
  defines), so a missing lib never breaks the link. The active one is
  chosen at run time by pick_backend() (VID_BACKEND env, else the richest
  compiled-in backend). Adding a backend means adding a unit, gating its
  uses + its two dispatcher cases, and linking its library. }
uses
  vid_backend_headless
  {$IFDEF VID_SDL}, vid_backend_sdl {$ENDIF}
  {$IFDEF VID_RAYLIB}, vid_backend_raylib {$ENDIF},
  vid_png,
  SysUtils;

{$I vid_dispatch.inc}

end.
