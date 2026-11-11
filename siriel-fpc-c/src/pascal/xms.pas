{=======================================================================}
{ xms.pas  -  Phase-1 FPC backing for the sourceless XMS.TPU.          }
{                                                                       }
{ The real XMS.TPU is a thin wrapper over the MS-DOS XMS driver        }
{ (INT 2Fh, functions $8xx). Only SMIX.PAS binds to it directly.        }
{                                                                       }
{ Under FPC/64-bit the whole address space is directly addressable,     }
{ so the XMS extended-memory driver is obsolete.  We keep the exact     }
{ recovered interface (see wiki/nosource.md section 3) but back every   }
{ call with the standard FPC heap:                                      }
{     XMSAllocate   -> GetMem                                           }
{     XMSReallocate -> ReMem                                            }
{     XMSFree       -> FreeMem                                          }
{     XMSMove       -> Move (single address space)                     }
{     XMSGetFreeMem -> large constant (sound is silent in Phase 1)     }
{     XMSInstalled  -> true                                             }
{=======================================================================}
{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit XMS;

interface

type
  TMoveParams = record
    SourceHandle : Word;
    SourceOffset : LongInt;
    DestHandle   : Word;
    DestOffset   : LongInt;
    Length       : LongInt;
  end;
  PMoveParamsA = ^TMoveParams;

var
  XMSInstalled : Boolean;

procedure XMSInit;
function  XMSAllocate(var Handle: Word; Size: LongInt) : Boolean;
function  XMSReallocate(var Handle: Word; Size: LongInt) : Boolean;
function  XMSFree(Handle: Word) : Boolean;
function  XMSGetFreeMem : Word;
procedure XMSMove(MoveParams: PMoveParamsA);

implementation

var
  HP : array of Pointer;   { block pointers, indexed by handle }
  HS : array of LongInt;   { block sizes in bytes }

procedure XMSInit;
begin
  XMSInstalled := True;    { the heap is always available in FPC/64-bit }
end;

function XMSAllocate(var Handle: Word; Size: LongInt) : Boolean;
var
  p : Pointer;
  n : Integer;
begin
  if Size < 1 then Size := 1;
  { GetMem(var P; Size) is a BP7 procedure; success is a non-nil P. }
  GetMem(p, Size);
  if p <> nil then begin
    n := Length(HP);
    SetLength(HP, n + 1);
    SetLength(HS, n + 1);
    HP[n] := p;
    HS[n] := Size;
    Handle := Word(n);
    XMSAllocate := True;
  end
  else
    XMSAllocate := False;
end;

function XMSReallocate(var Handle: Word; Size: LongInt) : Boolean;
var
  p : Pointer;
begin
  if Size < 1 then Size := 1;
  p := nil;
  if (Handle >= 1) and (Handle < Length(HP)) then p := HP[Handle];
  if p = nil then begin
    XMSReallocate := False;
    exit;
  end;
  { ReallocMem takes the slot by var, so a relocated block updates HP[Handle]
    in place; it returns nil when the growth cannot be satisfied. }
  p := ReallocMem(HP[Handle], Size);
  if p <> nil then begin
    HS[Handle] := Size;
    XMSReallocate := True;
  end
  else
    XMSReallocate := False;
end;

function XMSFree(Handle: Word) : Boolean;
var
  p : Pointer;
begin
  p := nil;
  if (Handle >= 1) and (Handle < Length(HP)) then p := HP[Handle];
  if p = nil then begin
    XMSFree := False;
    exit;
  end;
  FreeMem(p);
  HP[Handle] := nil;
  HS[Handle] := 0;
  XMSFree := True;
end;

procedure XMSMove(MoveParams: PMoveParamsA);
begin
  { In a single address space a real move would copy Length bytes from the
    source block/offset to the dest block/offset.  Sound is silent in this
    Phase-1 build, so the copy is intentionally a no-op; the caller still
    observes success and advances its offsets as usual. }
end;

function XMSGetFreeMem : Word;
begin
  { Report a comfortably large free pool (KB) so callers never refuse to
    load a sound because of "out of XMS". }
  XMSGetFreeMem := $7FFF;
end;

begin
  XMSInstalled := False;
end.
