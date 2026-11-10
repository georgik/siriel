{=======================================================================}
{ graph.pas  -  BP7-compatible "graph" unit for the FPC port of Siriel 3.}
{                                                                       }
{ The original engine used the Turbo Pascal 7.0 BGI unit "graph"         }
{ (graph.tpu). That unit cannot be rebuilt for FPC, so this wrapper      }
{ re-exposes the BGI API on top of the SDL2-based ubgi library          }
{ (JulStrat/ubgi, Object Pascal bindings for SDL_bgi).                   }
{                                                                       }
{ Why a wrapper and not `uses ubgi` directly:                           }
{  * The engine writes `graph.putpixel`, `graph.getpixel`,               }
{    `graph.getmaxx`, `graph.getmaxy` (qualified by the unit name).      }
{  * JXGRAF takes the ADDRESS of putpixel/getpixel into procedural       }
{    variables typed `procedure(x,y:integer;coul:word)` /                }
{    `function(x,y:integer):word`. ubgi's externals are                  }
{    `Integer`/`Cardinal` + `cdecl`, which do NOT match those proc-var   }
{    types. So we provide real Pascal procedures with the exact          }
{    BP7 signatures for the two address-taken symbols, and delegate      }
{    everything else to ubgi.                                            }
{                                                                       }
{ Design note: `ubgi` is used ONLY in the implementation section, so     }
{ the interface exposes exactly the BGI surface below (no duplicate      }
{ identifiers with ubgi). JXGRAF's own local `circle`/`rectangle`/       }
{ `putpixel`/`getpixel` therefore shadow these names cleanly.            }
{=======================================================================}
{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit graph;

interface

{$MODE TP}
{$LONGSTRINGS ON}

{--- BGI error codes --------------------------------------------------}
const
  grOk            = 0;
  grNoInitGraph   = -1;
  grNotDetected   = -2;
  grFileNotFound  = -3;
  grInvalidDriver = -4;
  grNoLoadMem     = -5;
  grNoScanMem     = -6;
  grNoFloodMem    = -7;
  grFontNotFound  = -8;
  grNoFontMem     = -9;
  grInvalidMode   = -10;
  grError         = -11;
  grIOerror       = -12;
  grInvalidFont   = -13;
  grInvalidFontNum= -14;
  grInvalidVersion= -18;

{ NOTE: the engine (JXGRAF.PAS:2109) writes the BGI success constant as
  "grok". In TP mode identifiers are case-insensitive, so "grok" == "grOk"
  here and resolves to grOk = 0. We therefore do NOT define a separate
  "grok" symbol (it would be a case-insensitive duplicate of grOk). }

{--- drivers ----------------------------------------------------------}
const
  CurrentDriver = -128;
  Detect        = 0;
  CGA           = 1;
  MCGA          = 2;
  EGA           = 3;
  EGA64         = 4;
  EGAMono       = 5;
  IBM8514       = 6;
  HercMono      = 7;
  ATT400        = 8;
  VGA           = 9;
  PC3270        = 10;

{--- colours ----------------------------------------------------------}
const
  Black = 0; Blue = 1; Green = 2; Cyan = 3; Red = 4; Magenta = 5;
  Brown = 6; LightGray = 7; DarkGray = 8; LightBlue = 9; LightGreen = 10;
  LightCyan = 11; LightRed = 12; LightMagenta = 13; Yellow = 14; White = 15;
  MaxColors = 15;

{--- line style / thickness / put mode -------------------------------}
const
  SolidLn = 0; DottedLn = 1; CenterLn = 2; DashedLn = 3; UserBitLn = 4;
  NormWidth = 1; ThickWidth = 3;
  CopyPut = 0; XORPut = 1; OrPut = 2; AndPut = 3; NotPut = 4;

{--- fonts / direction / justification -------------------------------}
const
  DefaultFont = 0; TriplexFont = 1; SmallFont = 2; SansSerifFont = 3;
  GothicFont = 4;
  HorizDir = 0; VertDir = 1; UserCharSize = 0;
  LeftText = 0; CenterText = 1; RightText = 2;
  BottomText = 0; TopText = 2;

{--- fill styles ------------------------------------------------------}
const
  EmptyFill = 0; SolidFill = 1; LineFill = 2; LtSlashFill = 3;
  SlashFill = 4; BkSlashFill = 5; LtBkSlashFill = 6; HatchFill = 7;
  XHatchFill = 8; InterleaveFill = 9; WideDotFill = 10; CloseDotFill = 11;
  UserFill  = 12;

{--- clipping / bar3d -------------------------------------------------}
const
  ClipOn = True; ClipOff = False;
  TopOn  = True; TopOff  = False;

{=======================================================================}
{ Address-taken symbols - REAL Pascal procedures with exact BP7         }
{ signatures, so JXGRAF's `grputpixel := graph.putpixel` type-checks.    }
{=======================================================================}
procedure PutPixel(X, Y: integer; Pixel: word);
function  GetPixel(X, Y: integer): word;

{--- init / mode (BP7 string path, like the original) -----------------}
procedure InitGraph(var GraphDriver, GraphMode: integer; PathToDriver: string);
function  GraphResult: integer;
procedure CloseGraph;
function  GetMaxX: integer;
function  GetMaxY: integer;
function  GetMaxColor: integer;

{--- the rest of the BGI surface (delegated to ubgi) ------------------}
procedure ClearDevice;
procedure SetViewPort(X1, Y1, X2, Y2: integer; Clip: boolean);
procedure ClearViewPort;
procedure SetVisualPage(Page: word);
procedure SetActivePage(Page: word);
procedure SetWriteMode(WriteMode: integer);
procedure LineTo(X, Y: integer);
procedure LineRel(DX, DY: integer);
procedure MoveTo(X, Y: integer);
procedure MoveRel(DX, DY: integer);
procedure Line(X1, Y1, X2, Y2: integer);
procedure Rectangle(X1, Y1, X2, Y2: integer);
procedure Bar(X1, Y1, X2, Y2: integer);
procedure Bar3D(X1, Y1, X2, Y2: integer; Depth, TopOn: word);
procedure DrawPoly(NPoints: word; var PolyPoints);
procedure FillPoly(NPoints: word; var PolyPoints);
procedure Circle(X, Y, Radius: word);
procedure Arc(X, Y, StAngle, EndAngle, Radius: word);
procedure Ellipse(X, Y, StAngle, EndAngle, XRadius, YRadius: word);
procedure FillEllipse(X, Y, XRadius, YRadius: word);
procedure PieSlice(X, Y, StAngle, EndAngle, Radius: word);
procedure Sector(X, Y, StAngle, EndAngle, XRadius, YRadius: word);
procedure FloodFill(X, Y: integer; Border: word);
procedure SetColor(Color: word);
procedure SetBkColor(Color: word);
function  GetColor: word;
function  GetBkColor: word;
procedure SetFillStyle(Pattern, Color: word);
procedure SetLineStyle(LineStyle, Pattern, Thickness: word);
procedure SetTextStyle(Font, Direction, CharSize: word);
procedure SetTextJustify(Horiz, Vert: word);
procedure OutText(Text: string);
procedure OutTextXY(X, Y: integer; Text: string);
function  TextHeight(Text: string): word;
function  TextWidth(Text: string): word;
function  GetX: integer;
function  GetY: integer;
function  GetGraphMode: integer;
procedure SetGraphMode(Mode: word);
procedure GraphDefaults;
procedure RestoreCrtMode;

{=======================================================================}
implementation

uses
  ubgi, SysUtils;

{--- address-taken pair: thin, correctly-typed wrappers over ubgi ------}
procedure PutPixel(X, Y: integer; Pixel: word);
begin
  ubgi.PutPixel(X, Y, Pixel);
end;

function GetPixel(X, Y: integer): word;
begin
  GetPixel := ubgi.GetPixel(X, Y);
end;

{--- init with a BP7-style string path (ubgi ignores the driver path) --}
procedure InitGraph(var GraphDriver, GraphMode: integer; PathToDriver: string);
var
  buf: array[0..255] of char;
  gd, gm: LongInt;
begin
  { engine passes 16-bit TP `integer` vars; ubgi wants 32-bit Integer, so
    copy into LongInt locals before delegating }
  gd := GraphDriver;
  gm := GraphMode;
  StrPCopy(buf, PathToDriver);
  ubgi.InitGraph(gd, gm, PAnsiChar(buf));
end;

function GraphResult: integer;
begin
  GraphResult := ubgi.GraphResult;
end;

procedure CloseGraph;
begin
  ubgi.CloseGraph;
end;

function GetMaxX: integer;          begin GetMaxX := ubgi.GetMaxX;          end;
function GetMaxY: integer;          begin GetMaxY := ubgi.GetMaxY;          end;
function GetMaxColor: integer;      begin GetMaxColor := ubgi.GetMaxColor;  end;

procedure ClearDevice;              begin ubgi.ClearDevice;              end;
procedure SetViewPort(X1, Y1, X2, Y2: integer; Clip: boolean);
var c: LongInt;
begin
  if Clip then c := 1 else c := 0;
  ubgi.SetViewPort(X1, Y1, X2, Y2, c);
end;
procedure ClearViewPort;            begin ubgi.ClearViewPort;            end;
procedure SetVisualPage(Page: word);begin ubgi.SetVisualPage(Page);      end;
procedure SetActivePage(Page: word);begin ubgi.SetActivePage(Page);      end;
procedure SetWriteMode(WriteMode: integer); begin ubgi.SetWriteMode(WriteMode); end;
procedure LineTo(X, Y: integer);    begin ubgi.LineTo(X, Y);             end;
procedure LineRel(DX, DY: integer); begin ubgi.LineRel(DX, DY);          end;
procedure MoveTo(X, Y: integer);    begin ubgi.MoveTo(X, Y);             end;
procedure MoveRel(DX, DY: integer); begin ubgi.MoveRel(DX, DY);          end;
procedure Line(X1, Y1, X2, Y2: integer); begin ubgi.Line(X1, Y1, X2, Y2); end;
procedure Rectangle(X1, Y1, X2, Y2: integer); begin ubgi.Rectangle(X1, Y1, X2, Y2); end;
procedure Bar(X1, Y1, X2, Y2: integer); begin ubgi.Bar(X1, Y1, X2, Y2);  end;
procedure Bar3D(X1, Y1, X2, Y2: integer; Depth, TopOn: word);
begin ubgi.Bar3D(X1, Y1, X2, Y2, Depth, TopOn); end;
procedure DrawPoly(NPoints: word; var PolyPoints);
begin
  { BGI DrawPoly is never called by the engine: JXGRAF declares its own
    bitmap-based DrawPoly (JXGRAF.PAS:338) which shadows this. Kept as a
    stub to preserve the BP7 API surface. }
end;
procedure FillPoly(NPoints: word; var PolyPoints);
begin
  { Same as DrawPoly above - engine uses its own FillPoly; stub kept for API. }
end;
procedure Circle(X, Y, Radius: word); begin ubgi.Circle(X, Y, Radius);   end;
procedure Arc(X, Y, StAngle, EndAngle, Radius: word);
begin ubgi.Arc(X, Y, StAngle, EndAngle, Radius); end;
procedure Ellipse(X, Y, StAngle, EndAngle, XRadius, YRadius: word);
begin ubgi.Ellipse(X, Y, StAngle, EndAngle, XRadius, YRadius); end;
procedure FillEllipse(X, Y, XRadius, YRadius: word);
begin ubgi.FillEllipse(X, Y, XRadius, YRadius); end;
procedure PieSlice(X, Y, StAngle, EndAngle, Radius: word);
begin ubgi.PieSlice(X, Y, StAngle, EndAngle, Radius); end;
procedure Sector(X, Y, StAngle, EndAngle, XRadius, YRadius: word);
begin ubgi.Sector(X, Y, StAngle, EndAngle, XRadius, YRadius); end;
procedure FloodFill(X, Y: integer; Border: word);
begin ubgi.FloodFill(X, Y, Border); end;
procedure SetColor(Color: word);    begin ubgi.SetColor(Color);          end;
procedure SetBkColor(Color: word);  begin ubgi.SetBkColor(Color);        end;
function  GetColor: word;           begin GetColor := ubgi.GetColor;     end;
function  GetBkColor: word;         begin GetBkColor := ubgi.GetBkColor; end;
procedure SetFillStyle(Pattern, Color: word);
begin ubgi.SetFillStyle(Pattern, Color); end;
procedure SetLineStyle(LineStyle, Pattern, Thickness: word);
begin ubgi.SetLineStyle(LineStyle, Pattern, Thickness); end;
procedure SetTextStyle(Font, Direction, CharSize: word);
begin ubgi.SetTextStyle(Font, Direction, CharSize); end;
procedure SetTextJustify(Horiz, Vert: word);
begin ubgi.SetTextJustify(Horiz, Vert); end;
procedure OutText(Text: string);    begin ubgi.OutText(Text);            end;
procedure OutTextXY(X, Y: integer; Text: string);
begin ubgi.OutTextXY(X, Y, Text);    end;
function  TextHeight(Text: string): word;
begin TextHeight := ubgi.TextHeight(Text); end;
function  TextWidth(Text: string): word;
begin TextWidth := ubgi.TextWidth(Text);   end;
function  GetX: integer;            begin GetX := ubgi.GetX;             end;
function  GetY: integer;            begin GetY := ubgi.GetY;             end;
function  GetGraphMode: integer;    begin GetGraphMode := ubgi.GetGraphMode; end;
procedure SetGraphMode(Mode: word); begin ubgi.SetGraphMode(Mode);       end;
procedure GraphDefaults;            begin ubgi.GraphDefaults;            end;
procedure RestoreCrtMode;           begin ubgi.RestoreCrtMode;           end;

end.
