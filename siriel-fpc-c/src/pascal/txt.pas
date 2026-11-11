{=======================================================================}
{ txt.pas  -  Phase-1 stub for the sourceless TXT.TPU (Turbo Pascal 7).  }
{                                                                       }
{ TXT.TPU is the JX text/font engine: the low-level text-rendering and  }
{ on-screen window layer that JXGRAF and GEO wrap with their higher     }
{ level bitmap print_* helpers. It is the single most-depended-upon     }
{ unit in the engine (see wiki/nosource.md section 2).                  }
{                                                                       }
{ The real unit renders glyphs from embedded fonts into a 640x480x8     }
{ framebuffer and manages on-screen text windows. Recovering the exact  }
{ glyph metrics requires the original .FON data, so for Phase 1 this     }
{ stub provides the full recovered API surface with permissive,         }
{ compile-passing bodies. Phase 2 (or a data-backed reimplementation)   }
{ can back each call with real rendering.                               }
{=======================================================================}
{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit TXT;

interface

(* --- low-level text drawing *)
procedure PrintChar(X, Y: integer; C: char; Col, Back: integer);
procedure PrintNum(X, Y: integer; N: longint; Width, Col: integer);
procedure PrintText(X, Y, Color: integer; S: string);
procedure PutText(Dest: Pointer; X, Y: integer; S: string);
procedure PrintBig(X, Y: integer; S: string);
procedure PrintBig2(X, Y: integer; S: string);
function  TextWidth(S: string): integer;

(* --- windows / boxes *)
procedure TextBar(X1, Y1, X2, Y2: integer; Col: integer; S: string);
procedure TextBox(X1, Y1, X2, Y2, Col, Back: integer; S: string);
procedure TextShadow(X, Y: integer; S: string);
procedure TextWindow1(X1, Y1, X2, Y2, Col, BCol, FCol: integer; S: string);
procedure SetCurShape(Shape, Subshape: word);
procedure TextWindow2(X1, Y1, X2, Y2, Col, BCol, FCol: integer; S: string);
procedure TextMem(OnOff: boolean);

(* --- scrolling / input *)
procedure ScrollText(FromX, FromY, ToX, ToY, Lines: integer);
function  InputText(X, Y, MaxLen: integer; DefStr: string): byte;
function  GetText(X, Y, MaxLen: integer): string;
function  GetChar(X, Y: integer): char;

(* --- fonts *)
procedure SetTextFont(FontPtr: Pointer);
function  GetFontAddr: Pointer;

(* --- keyboard helpers not in CRT *)
function  SpeedKey: boolean;

(* --- Phase 2: headless auto-input state (shared with JXGRAF.keypressed) --- *)
var
  auto_input_enabled : boolean;  (* set by SI35.PAS to auto-advance keys        *)
  auto_key_pending   : word;     (* next key to report via keypressed/key      *)
  auto_key_frames    : integer;  (* countdown frames until the next key        *)

(* --- keyboard / file helpers recovered from TXT.TPU (Phase-1 stubs) --- *)
function key: word;
procedure fileread(filename: string; a, b, c: longint; var buf);

(* --- palette *)
procedure SetPalette(Num, Col: byte);
procedure SetPalette17(var Pal);

{ --------------------------------------------------------------------- }
{ The following names also exist in the real TXT.TPU symbol table. They }
{ are declared here so any call site in the engine resolves; bodies are }
{ Phase-1 stubs.                                                          }
{ --------------------------------------------------------------------- }
procedure Sound(Freq, Duration: integer);
procedure NoSound;
procedure Delay(ms: word);

implementation

{ --- text drawing: no-op stubs (Phase 1) --- }
procedure PrintChar(X, Y: integer; C: char; Col, Back: integer);
begin end;
procedure PrintNum(X, Y: integer; N: longint; Width, Col: integer);
begin end;
procedure PrintText(X, Y, Color: integer; S: string);
begin end;
procedure PutText(Dest: Pointer; X, Y: integer; S: string);
begin end;
procedure PrintBig(X, Y: integer; S: string);
begin end;
procedure PrintBig2(X, Y: integer; S: string);
begin end;
function  TextWidth(S: string): integer;
begin TextWidth := Length(S) * 8; end;

{ --- windows / boxes --- }
procedure TextBar(X1, Y1, X2, Y2: integer; Col: integer; S: string);
begin end;
procedure TextBox(X1, Y1, X2, Y2, Col, Back: integer; S: string);
begin end;
procedure TextShadow(X, Y: integer; S: string);
begin end;
procedure TextWindow1(X1, Y1, X2, Y2, Col, BCol, FCol: integer; S: string);
begin end;
procedure SetCurShape(Shape, Subshape: word);
begin end;
procedure TextWindow2(X1, Y1, X2, Y2, Col, BCol, FCol: integer; S: string);
begin end;
procedure TextMem(OnOff: boolean);
begin end;

{ --- scrolling / input --- }
procedure ScrollText(FromX, FromY, ToX, ToY, Lines: integer);
begin end;
function  InputText(X, Y, MaxLen: integer; DefStr: string): byte;
begin InputText := 1; end;
function  GetText(X, Y, MaxLen: integer): string;
begin GetText := ''; end;
function  GetChar(X, Y: integer): char;
begin GetChar := ' '; end;

{ --- fonts --- }
procedure SetTextFont(FontPtr: Pointer);
begin end;
function  GetFontAddr: Pointer;
begin GetFontAddr := nil; end;

{ --- keyboard / palette stubs --- }
function  SpeedKey: boolean;
begin SpeedKey := False; end;

(* --- keyboard / file stubs --- *)
function key: word;
begin
   (* Phase 2: deliver the auto-injected key (from JXGRAF.keypressed), consumed
      once so the engine sees a discrete keypress rather than a held key. *)
   key := auto_key_pending;
   auto_key_pending := 0;
end;
procedure fileread(filename: string; a, b, c: longint; var buf);
begin end;

procedure SetPalette(Num, Col: byte);
begin end;
procedure SetPalette17(var Pal);
begin end;

procedure Sound(Freq, Duration: integer);
begin end;
procedure NoSound;
begin end;
procedure Delay(ms: word);
begin end;

end.
