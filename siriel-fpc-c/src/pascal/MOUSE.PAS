{ ------------------------------------------------------------------- }
{  MOUSE.PAS  -  drop-in replacement for the sourceless MOUSE.TPU    }
{                                                                     }
{  Headless stub for Phase 1 (DOS / Turbo Pascal 7.0).                }
{  The original MOUSE.TPU is a real-time INT 33h mouse driver. This   }
{  stub exports the exact same interface (recovered from the .TPU     }
{  symbol table + every call site) but performs no hardware I/O.      }
{  Cursor position is owned by JXGRAF (its mouse_posx/posy, updated    }
{  from raw INT 33h registers), so the driver state here is inert.    }
{  Phase 2 (FPC) backs this with a real mouse behind the same API.    }
{ ------------------------------------------------------------------- }

{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit mouse;

interface

  var
    mousebuttons: Word;        (* button bitmap: bit0=left, bit1=right, bit2=middle *)
    mousepresscount: Word;     (* number of button presses *)
    mousereleasecount: Word;   (* number of button releases *)
    mouserelposchange: Word;   (* release position change counter *)

  (* called by the codebase - signatures pinned by call sites *)
  procedure mouseinit(var p: Word);           (* EDITING:1368, JXGMOUSE:686, PUZLIK:430 *)
  procedure mousespeed(x, y: Word);           (* 12,12 *)
  procedure mousesensitivity(x, y, z: Word);  (* 50,50,1 *)
  procedure mouserange(a, b, c, d: Word);     (* JXGMOUSE:694, PUZLIK:433 *)
  procedure mousesetpos(x, y: Word);          (* JXGMOUSE:695, PUZLIK:434 *)

  (* present in MOUSE.TPU, not referenced by the game - kept for API parity *)
  procedure mouseon;
  procedure mouseoff;
  procedure mousestatus(var button: Word; var x, y: Word);
  procedure mousehandleevent;
  procedure mousereset;
  procedure mousesetsoftcursor;
  procedure mousesethardcursor;
  procedure mousesetgrcursor;

implementation

procedure mouseinit(var p: Word);
begin
  p := 0;
end;

procedure mouseon;
begin
  { headless: cursor is drawn by JXGRAF }
end;

procedure mouseoff;
begin
end;

procedure mousestatus(var button: Word; var x, y: Word);
begin
  button := mousebuttons;
  x := 0;
  y := 0;
end;

procedure mousehandleevent;
begin
end;

procedure mousereset;
begin
end;

procedure mousespeed(x, y: Word);
begin
end;

procedure mousesensitivity(x, y, z: Word);
begin
end;

procedure mouserange(a, b, c, d: Word);
begin
end;

procedure mousesetpos(x, y: Word);
begin
end;

procedure mousesetsoftcursor;
begin
end;

procedure mousesethardcursor;
begin
end;

procedure mousesetgrcursor;
begin
end;

end.
