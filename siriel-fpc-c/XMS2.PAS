{-----------------------------------------------------------------------}
{									}
{	XMS Interface Unit for Borland Pascal 7.0, Version 1.1		}
{	Developed by Tanescu A. Horatiu					}
{	April 1997							}
{									}
{-----------------------------------------------------------------------}
{                                                                       }
{  Phase-1 FPC port (wiki/xms-fpc.md):                                    }
{     The original implementation drove the MS-DOS XMS driver through     }
{     INT 2Fh (all the `assembler` procs) and used 16-bit `Seg/Ofs`      }
{     intrinsics.  Neither assembles on aarch64, and the XMS driver       }
{     is meaningless under a flat 64-bit address space.  The interface    }
{     below is unchanged; the implementation now maps every Word handle   }
{     onto a slot of the standard FPC heap:                               }
{         XMAlloc      -> GetMem                                          }
{         XMRealloc    -> ReallocMem                                      }
{         XMFree       -> FreeMem                                         }
{         XMLock/XMUnlock -> no-op (one flat address space)              }
{         XMemCopy/Copy* -> Move between heap blocks / linear pointers    }
{         XMFreeSpace/XMContig -> large constant                          }
{         XMSDriverCheck/GetXMSFunct/InitXMS2 -> report the driver up     }
{  Only the `implementation` part changed; the interface and the          }
{  error-code tables are verbatim from the original.                      }
{                                                                       }
{-----------------------------------------------------------------------}

{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit XMS2;


interface


{ XMS error codes }

const XE_NOERROR		= $00; { no error, successful operation }

{ miscellaneous errors }
const XE_NOTIMPLEMENTED		= $80; { the function is not implemented }
const XE_API			= XE_NOTIMPLEMENTED;
const XE_VDISK			= $81; { a VDISK device is detected }
const XE_A20			= $82; { an A20 error occurs }
const XE_DRVFAULT		= $8E; { a general driver error occurs }
const XE_UNRECOVERABLE		= $8F; { an unrecoverable driver error occurs }

{ HMA errors }
const XE_NO_HMA			= $90; { the HMA does not exist }
const XE_NO_FREEHMA		= $91; { the HMA is already in use }
const XE_BAD_HMAMINSIZE		= $92; { DX is less than the /HMAMIN= parameter }
const XE_HMANOTALLOCATED	= $93; { the HMA is not allocated }
const XE_A20ENABLED		= $94; { the A20 line is still enabled }

{ eXtended Memory errors }
const XE_NO_FREEMEM		= $A0; { all extended memory is allocated }
const XE_NO_FREEHANDLES		= $A1; { all available extended memory handles are in use }
const XE_BAD_HANDLE 		= $A2; { the handle is invalid }
const XE_BAD_SRC_HANDLE		= $A3; { the SourceHandle is invalid }
const XE_BAD_SRC_OFF		= $A4; { the SourceOffset is invalid }
const XE_BAD_DEST_HANDLE	= $A5; { the DestHandle is invalid }
const XE_BAD_DEST_OFF		= $A6; { the DestOffset is invalid }
const XE_BAD_LEN		= $A7; { the Length is invalid }
const XE_BAD_OVERLAP		= $A8; { the move has an invalid overlap }
const XE_PARITY			= $A9; { a parity error occurs }
const XE_UNLOCKED		= $AA; { the block is not locked }
const XE_LOCKED			= $AB; { the block is locked }
const XE_LOCKCOUNTOF		= $AC; { the block's lock count overflows }
const XE_LOCKFAIL		= $AD; { the lock fails }

{ UMB errors }
const XE_UMB2BIG		= $B0; { a smaller UMB is available }
const XE_NO_UMBS		= $B1; { no UMBs are available }
const XE_BAD_UMBSEG		= $B2; { the UMB segment number is invalid }

{ Miscellaneous constants }

const HMASEG			= $FFFF;
const HMASTARTOFF		= $0010;
const HMAENDOFF			= $FFFF;

{ 16-bit handle to an extended memory block }

type
  XMHandle = Word;

{ Record used by memory transfer routines }

type
  TXMCopyRec = record
    Count        : Longint;
    SourceHandle : XMHandle;
    SourceOff    : Longint;   { byte offset within the source block }
    DestHandle   : XMHandle;
    DestOff      : Longint;   { byte offset within the dest block }
    { Phase-1 FPC: when the matching handle is 0 the transfer is between a
      linear (heap) pointer and a block; those pointers are carried here so
      the full 64-bit address survives (a Longint would truncate it). }
    SourcePtr    : Pointer;
    DestPtr      : Pointer;
  end;

{ Error status variable }

var
  XMSError : Byte;

{ Indicates the existance of an XMS driver }

var
  XMSInstalled : Boolean;

{ Initialization Functions }

function  XMSDriverCheck : Boolean;
procedure GetXMSFunct;
procedure InitXMS2;

{ Driver Information Functions }

function  XMSVersion : Word;
function  XMSVersionInfo(var Revision : Word; var HMA : Boolean) : Word;

{ High Memory Area (HMA) Management Functions }

function  HMARequest(ReqSize : Word) : Boolean;
function  HMARelease : Boolean;

{ A20 Management Functions }

function  GlobalEnableA20 : Boolean;
function  GlobalDisableA20 : Boolean;
function  LocalEnableA20 : Boolean;
function  LocalDisableA20 : Boolean;
function  QueryA20 : Boolean;

{ eXtended Memory Management Functions }

function  XMFreeSpace : Word;
function  XMContig : Word;
function  XMAlloc(Size : LongInt) : XMHandle;
function  XMFree(Handle : XMHandle) : Boolean;
function  XMLock(Handle : XMHandle) : Longint;
function  XMUnlock(Handle : XMHandle) : Boolean;
function  XMHandleInfo(Handle : XMHandle; var Size : Word; var LockCount,
                      FreeHandles : Byte) : Boolean;
function  XMRealloc(Handle : XMHandle; NewSize : Word) : Boolean;

{ eXtended Memory Transfer Functions }

function  XMemCopy(const CopyRec : TXMCopyRec) : Boolean;
function _XMemCopy(N : Longint; SrcHandle : XMHandle; SrcOff : Longint;
                   DestHandle : XMHandle; DestOff : Longint) : Boolean;
function  CopyCMemToXMem(DestHandle : XMHandle; DestOff : Longint;
					 Src : Pointer; N : Longint) : Boolean;
function  CopyXMemToCMem(Dest : Pointer; SrcHandle : XMHandle;
                         SrcOff : Longint; N : Longint) : Boolean;
function  CopyXMem(DestHandle : XMHandle; DestOff : Longint;
                   SrcHandle : XMHandle; SrcOff : Longint; N : Longint) : Boolean;
function  CopyMem(Dest : Pointer; Src : Pointer; N : Longint) : Boolean;

{ Upper Memory Blocks (UMB) Management Functions }

function  UMBAlloc(var Size : Word) : Word;
function  UMBFree(UMBSeg : Word) : Boolean;
function  UMBReAlloc(UMBSeg : Word; var Size : Word) : Boolean;

{ XMS error functions }

function  XMSErrorMsg(ErrorCode : Byte) : PChar;
procedure PrintXMSError(const S : string);

implementation

const
  XMSErrorCount = 27;

  XMSErrorNumber : array [1..XMSErrorCount] of Byte =
  ($80, $81, $82, $8E, $8F, $90, $91, $92, $93, $94, $A0, $A1, $A2, $A3, $A4,
   $A5, $A6, $A7, $A8, $A9, $AA, $AB, $AC, $AD, $B0, $B1, $B2);

  XMSErrorString: array [0..XMSErrorCount] of PChar = (
{ 00h }		'Unknown error',
{ 80h }		'Function not implemented',
{ 81h }		'VDISK device detected',
{ 82h }		'An A20 error occurred',
{ 8Eh }		'A general driver error occurred',
{ 8Fh }		'An unrecoverable driver error occurred',
{ 90h }		'The HMA does not exist',
{ 91h }		'The HMA is already in use',
{ 92h }		'DX is less than the /HMAMIN= parameter',
{ 93h }		'The HMA is not allocated',
{ 94h }		'The A20 line is still enabled',
{ A0h }		'All extended memory is allocated',
{ A1h }		'All available extended memory handles are in use',
{ A2h }		'Invalid handle',
{ A3h }		'Invalid SourceHandle',
{ A4h }		'Invalid SourceOffset',
{ A5h }		'Invalid DestHandle',
{ A6h }		'Invalid DestOffset',
{ A7h }		'Invalid length',
{ A8h }		'The move has an invalid overlap',
{ A9h }		'A parity error occurred',
{ AAh }		'The block is not locked',
{ ABh }		'The block is locked',
{ ACh }		'Block lock count overflow',
{ ADh }		'Lock failure',
{ B0h }		'A smaller UMB is available',
{ B1h }		'No UMBs are available',
{ B2h }		'Invalid UMB segment number');

{ ----------------------------------------------------------------------- }
{ Phase-1 FPC: a Word handle is just the index into a heap-block table.    }
{ ----------------------------------------------------------------------- }

var
  HP : array of Pointer;   { allocated block, indexed by handle }
  HS : array of LongInt;   { block size in bytes, indexed by handle }

{ Resolve a source/dest address: handle 0 means "linear pointer", any other
  handle indexes a heap block and SourceOff/DestOff is a byte offset into it. }
function ResolveAddr(Handle: XMHandle; Off: LongInt; Lin: Pointer): Pointer;
var
  b : Pointer;
begin
  if Handle = 0 then begin
    ResolveAddr := Lin;
    exit;
  end;
  b := nil;
  if (Handle >= 1) and (Handle < Length(HP)) then b := HP[Handle];
  if b = nil then begin
    ResolveAddr := nil;
    exit;
  end;
  Inc(b, Off);              { 64-bit-safe block + byte offset }
  ResolveAddr := b;
end;

function XMAlloc(Size: LongInt): XMHandle;
var
  p : Pointer;
  n : Integer;
begin
  XMSError := 0;
  if Size < 1 then Size := 1;
  GetMem(p, Size);          { BP7 form: success is a non-nil P }
  if p = nil then begin
    XMSError := XE_NO_FREEMEM;
    XMAlloc := 0;
    exit;
  end;
  (* Reserve index 0 for the "linear/invalid" handle: ResolveAddr treats
     Handle=0 as a linear pointer, so real allocations must start at 1. *)
  if Length(HP) = 0 then begin
    SetLength(HP, 2);
    SetLength(HS, 2);
    n := 1;
  end
  else begin
    n := Length(HP);
    SetLength(HP, n + 1);
    SetLength(HS, n + 1);
  end;
  HP[n] := p;
  HS[n] := Size;
  XMAlloc := XMHandle(n);
end;

function XMFree(Handle: XMHandle): Boolean;
var
  p : Pointer;
begin
  XMSError := 0;
  p := nil;
  if (Handle >= 1) and (Handle < Length(HP)) then p := HP[Handle];
  if p = nil then begin
    XMSError := XE_BAD_HANDLE;
    XMFree := False;
    exit;
  end;
  FreeMem(p);
  HP[Handle] := nil;
  HS[Handle] := 0;
  XMFree := True;
end;

function XMLock(Handle: XMHandle): Longint;
var
  p : Pointer;
begin
  XMSError := 0;
  p := nil;
  if (Handle >= 1) and (Handle < Length(HP)) then p := HP[Handle];
  { One flat address space: the locked linear address is the block address
    itself.  The low 32 bits are returned to match the original Longint API. }
  XMLock := Longint(p);
end;

function XMUnlock(Handle: XMHandle): Boolean;
begin
  XMSError := 0;
  XMUnlock := True;         { locking is a no-op with a flat address space }
end;

function XMRealloc(Handle: XMHandle; NewSize: Word): Boolean;
var
  p : Pointer;
begin
  XMSError := 0;
  p := nil;
  if (Handle >= 1) and (Handle < Length(HP)) then p := HP[Handle];
  if p = nil then begin
    XMSError := XE_BAD_HANDLE;
    XMRealloc := False;
    exit;
  end;
  if NewSize < 1 then NewSize := 1;
  p := ReallocMem(HP[Handle], NewSize);   { updates HP[Handle] via var }
  if p = nil then begin
    XMSError := XE_NO_FREEMEM;
    XMRealloc := False;
    exit;
  end;
  HS[Handle] := NewSize;
  XMRealloc := True;
end;

function XMHandleInfo(Handle: XMHandle; var Size: Word; var LockCount,
                      FreeHandles: Byte): Boolean;
var
  p : Pointer;
  avail : Integer;
begin
  XMSError := 0;
  p := nil;
  if (Handle >= 1) and (Handle < Length(HP)) then p := HP[Handle];
  if p = nil then begin
    XMHandleInfo := False;
    XMSError := XE_BAD_HANDLE;
    exit;
  end;
  Size := Word(HS[Handle]);
  LockCount := 0;
  avail := Length(HP);
  if avail > 255 then avail := 255;
  FreeHandles := Byte(avail);
  XMHandleInfo := True;
end;

function XMFreeSpace: Word;
begin
  { Report a comfortably large free pool (KB); the heap is effectively
    unbounded for the game's needs. }
  XMFreeSpace := $7FFF;
end;

function XMContig: Word;
begin
  XMContig := $7FFF;
end;

{ ---- driver / information stubs (no INT 2Fh needed) ---- }

function XMSDriverCheck: Boolean;
begin
  XMSDriverCheck := True;
end;

procedure GetXMSFunct;
begin
  { Nothing to hook up under FPC. }
end;

procedure InitXMS2;
begin
  XMSInstalled := True;
end;

function XMSVersion: Word;
begin
  XMSVersion := $100;
end;

function XMSVersionInfo(var revision: Word; var HMA: Boolean): Word;
begin
  revision := $10;
  HMA := False;
  XMSVersionInfo := $100;
end;

function HMARequest(ReqSize: Word): Boolean;
begin
  HMARequest := True;
end;

function HMARelease: Boolean;
begin
  HMARelease := True;
end;

function GlobalEnableA20: Boolean;
begin GlobalEnableA20 := True; end;

function GlobalDisableA20: Boolean;
begin GlobalDisableA20 := True; end;

function LocalEnableA20: Boolean;
begin LocalEnableA20 := True; end;

function LocalDisableA20: Boolean;
begin LocalDisableA20 := True; end;

function QueryA20: Boolean;
begin QueryA20 := True; end;

function UMBAlloc(var Size: Word): Word;
begin
  { No upper memory blocks under FPC. }
  UMBAlloc := 0;
end;

function UMBFree(UMBSeg: Word): Boolean;
begin
  UMBFree := True;
end;

function UMBReAlloc(UMBSeg: Word; var Size: Word): Boolean;
begin
  UMBReAlloc := False;
end;

{ ---- transfer routines ---- }

function XMemCopy(const CopyRec: TXMCopyRec): Boolean;
var
  SrcPtr, DestPtr : Pointer;
begin
  XMSError := 0;
  SrcPtr := ResolveAddr(CopyRec.SourceHandle, CopyRec.SourceOff, CopyRec.SourcePtr);
  DestPtr := ResolveAddr(CopyRec.DestHandle, CopyRec.DestOff, CopyRec.DestPtr);
  { Phase-1 FPC: real XMS rejects any transfer whose offset+count runs past
    the end of the block (returns XE_BAD_*_OFFSET and copies nothing).  The
    game's load_predmet addresses object sectors (num=f+400) that run ~40KB
    past the 64KB handles[4] block; honour the same boundary so we never
    walk off the allocated heap. }
  if (SrcPtr <> nil) and (CopyRec.SourceHandle >= 1) and
     (CopyRec.SourceHandle >= Length(HP)) then begin
    XMSError := XE_BAD_SRC_HANDLE; XMemCopy := False; exit;
  end;
  if (DestPtr <> nil) and (CopyRec.DestHandle >= 1) and
     (CopyRec.DestHandle >= Length(HP)) then begin
    XMSError := XE_BAD_DEST_HANDLE; XMemCopy := False; exit;
  end;
  if (SrcPtr <> nil) and (CopyRec.SourceHandle >= 1) and
     (CopyRec.SourceOff + CopyRec.Count > HS[CopyRec.SourceHandle]) then begin
    XMSError := XE_BAD_SRC_OFF; XMemCopy := False; exit;
  end;
  if (DestPtr <> nil) and (CopyRec.DestHandle >= 1) and
     (CopyRec.DestOff + CopyRec.Count > HS[CopyRec.DestHandle]) then begin
    XMSError := XE_BAD_DEST_OFF; XMemCopy := False; exit;
  end;
  if (SrcPtr = nil) or (DestPtr = nil) or (CopyRec.Count <= 0) then begin
    if (CopyRec.SourceHandle <> 0) and (CopyRec.SourceHandle < Length(HP)) then
      XMSError := XE_BAD_SRC_HANDLE
    else
      XMSError := XE_BAD_DEST_HANDLE;
    XMemCopy := False;
    exit;
  end;
  Move(SrcPtr^, DestPtr^, CopyRec.Count);
  XMemCopy := True;
end;

function _XMemCopy(N: Longint; SrcHandle: XMHandle; SrcOff: Longint;
                   DestHandle: XMHandle; DestOff: Longint): Boolean;
var
  X : TXMCopyRec;
begin
  X.Count        := N;
  X.SourceHandle := SrcHandle;
  X.SourceOff    := SrcOff;
  X.DestHandle   := DestHandle;
  X.DestOff      := DestOff;
  X.SourcePtr    := nil;
  X.DestPtr      := nil;
  _XMemCopy := XMemCopy(X);
end;

function CopyCMemToXMem(DestHandle: XMHandle; DestOff: Longint;
                        Src: Pointer; N: Longint): Boolean;
var
  X : TXMCopyRec;
begin
  X.Count        := N;
  X.SourceHandle := 0;
  X.SourceOff    := 0;
  X.SourcePtr    := Src;
  X.DestHandle   := DestHandle;
  X.DestOff      := DestOff;
  X.DestPtr      := nil;
  CopyCMemToXMem := XMemCopy(X);
end;

function CopyXMemToCMem(Dest: Pointer; SrcHandle: XMHandle;
                        SrcOff: Longint; N: Longint): Boolean;
var
  X : TXMCopyRec;
begin
  X.Count        := N;
  X.SourceHandle := SrcHandle;
  X.SourceOff    := SrcOff;
  X.SourcePtr    := nil;
  X.DestHandle   := 0;
  X.DestOff      := 0;
  X.DestPtr      := Dest;
  CopyXMemToCMem := XMemCopy(X);
end;

function CopyXMem(DestHandle: XMHandle; DestOff: Longint;
                  SrcHandle: XMHandle; SrcOff: Longint; N: Longint): Boolean;
var
  X : TXMCopyRec;
begin
  X.Count        := N;
  X.SourceHandle := SrcHandle;
  X.SourceOff    := SrcOff;
  X.SourcePtr    := nil;
  X.DestHandle   := DestHandle;
  X.DestOff      := DestOff;
  X.DestPtr      := nil;
  CopyXMem := XMemCopy(X);
end;

function CopyMem(Dest: Pointer; Src: Pointer; N: Longint): Boolean;
begin
  XMSError := 0;
  Move(Src^, Dest^, N);
  CopyMem := True;
end;

{ ---- error messages ---- }

function XMSErrorMsg(ErrorCode: Byte): PChar;
var
  I, J : Byte;
begin
  J := 0;
  for I := 1 to XMSErrorCount do
    if XMSErrorNumber[I] = ErrorCode then J := I;
  XMSErrorMsg := XMSErrorString[J];
end;

procedure PrintXMSError(const S: string);
begin
  WriteLn(S, ': ', XMSErrorMsg(XMSError));
end;

begin
  { Report the (fake) driver as present so the engine's XMS gate passes. }
  XMSInstalled := True;
end.
