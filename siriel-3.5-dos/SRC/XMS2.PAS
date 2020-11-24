
{-----------------------------------------------------------------------}
{									}
{	XMS Interface Unit for Borland Pascal 7.0, Version 1.1		}
{	Developed by Tanescu A. Horatiu					}
{	April 1997							}
{									}
{-----------------------------------------------------------------------}

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
   SourceOff    : Longint;
   DestHandle   : XMHandle;
   DestOff      : Longint;
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
function  XMAlloc(Size : Word) : XMHandle;
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

{ Adress of the XMS driver control function }

var
  XMSControl : Pointer;

procedure XMSDefaultControl; far; assembler;
asm
	XOR	AX, AX
	MOV	BL, 80h
	MOV	XMSError, BL
end;

function XMSDriverCheck : Boolean; assembler;
asm
	MOV	AX, 4300h
	INT	2Fh
	SUB	AL, 80h
	NOT	AL
end;

procedure GetXMSFunct; assembler;
asm
	MOV	AX, 4310h
	INT	2Fh
	MOV	WORD PTR [XMSControl], BX
	MOV	WORD PTR [XMSControl+2], ES
end;

procedure InitXMS2;
begin
  XMSInstalled := XMSDriverCheck;
  if XMSInstalled then GetXmsFunct;
end;

function XMSVersionInfo(var revision : Word; var HMA : Boolean) : Word; assembler;
asm
	XOR	AH, AH
	CALL	[XMSControl]
	MOV	CX, AX
	MOV	AX, BX
	LES	DI, revision
	STOSW
	MOV	AL, DL
	LES	DI, HMA
	STOSB
	MOV	AX, CX
end;

function XMSVersion : Word; assembler;
asm
	XOR	AH, AH
	CALL	[XMSControl]
end;

function HMARequest(ReqSize : Word) : Boolean; assembler;
asm
	MOV	DX, ReqSize
	XOR	BL, BL
	MOV	AH, 01h
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function HMARelease : Boolean; assembler;
asm
	XOR	BL, BL
	MOV	AH, 02h
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function GlobalEnableA20 : Boolean; assembler;
asm
	XOR	BL, BL
	MOV	AH, 03h
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function GlobalDisableA20 : Boolean; assembler;
asm
	XOR	BL, BL
	MOV	AH, 04h
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function LocalEnableA20 : Boolean; assembler;
asm
	XOR	BL, BL
	MOV	AH, 05h
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function LocalDisableA20 : Boolean; assembler;
asm
	XOR	BL, BL
	MOV	AH, 06h
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function QueryA20 : Boolean; assembler;
asm
	XOR	BL, BL
	MOV	AH, 07h
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function XMFreeSpace : Word; assembler;
asm
	XOR	BL, BL
	MOV	AH, 08h
	CALL	[XMSControl]
	MOV	XMSError, BL
	MOV	AX, DX
end;

function XMContig : Word; assembler;
asm
	XOR	BL, BL
	MOV	AH, 08h
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function XMAlloc(Size : Word) : XMHandle; assembler;
label
  AllocFailed;
asm
	MOV	DX, Size
	XOR	BL, BL
	MOV	AH, 09h
	CALL	[XMSControl]
	MOV	XMSError, BL
	OR	AX, AX
	JE	AllocFailed
	MOV	AX, DX
AllocFailed:
end;

function XMFree(Handle : XMHandle) : Boolean; assembler;
asm
	MOV	DX, Handle
	XOR	BL, BL
	MOV	AH, 0Ah
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function XMLock(Handle : XMHandle) : Longint; assembler;
label
  LockFailed;
asm
	MOV	DX, Handle
	XOR	BL, BL
	MOV	AH, 0Ch
	CALL	[XMSControl]
	MOV	XMSError, BL
	OR	AX, AX
	JE	LockFailed
	MOV	AX, BX
	RET
LockFailed:
	XOR	DX, DX
end;

function XMUnlock(Handle : XMHandle) : Boolean; assembler;
asm
	MOV	DX, Handle
	XOR	BL, BL
	MOV	AH, 0Dh
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function XMHandleInfo(Handle : XMHandle; var Size : Word; var LockCount,
                      FreeHandles : Byte) : Boolean; assembler;
label
  InvalidHandle;
asm
	MOV	DX, Handle
	XOR	BL, BL
	MOV	AH, 0Eh
	CALL	[XMSControl]
	OR	AX, AX
	JE      InvalidHandle
	MOV	AX, DX
	LES	DI, Size
	STOSW
	MOV	AL, BH
	LES	DI, LockCount
	STOSB
	MOV	AL, BL
	LES	DI, FreeHandles
	STOSB
	MOV	XMSError, 0
	MOV	AL, 1
	RET
InvalidHandle:
	MOV	XMSError, BL
end;

function XMRealloc(Handle : XMHandle; NewSize : Word) : Boolean; assembler;
asm
	MOV	BX, NewSize
	MOV	DX, Handle
	XOR	BL, BL
	MOV	AH, 0Fh
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function XMemCopy(const CopyRec : TXMCopyRec) : Boolean;
var
  RSeg, ROfs : Word;
begin
  RSeg := Seg(CopyRec);
  ROfs := Ofs(CopyRec);

	asm
	PUSH	DS
	MOV	AX, DS
	MOV	ES, AX
	MOV	SI, ROfs
	MOV	AX, RSeg
        MOV	DS, AX
	XOR	BL, BL
	MOV	AH, 0Bh
	CALL	[ES:XMSControl]
        POP	DS
	MOV	XMSError, BL
	end;

end;

function _XMemCopy(N : Longint; SrcHandle : XMHandle; SrcOff : Longint;
                   DestHandle : XMHandle; DestOff : Longint) : Boolean;
var
  X : TXMCopyRec;
  RSeg, ROfs : Word;
begin
  X.Count        := N;
  X.SourceHandle := SrcHandle;
  X.SourceOff    := SrcOff;
  X.DestHandle   := DestHandle;
  X.DestOff      := DestOff;
  RSeg := Seg(X);
  ROfs := Ofs(X);

	asm
	PUSH	DS
	MOV	AX, DS
	MOV	ES, AX
	MOV	SI, ROfs
	MOV	AX, RSeg
        MOV	DS, AX
	XOR	BL, BL
	MOV	AH, 0Bh
	CALL	[ES:XMSControl]
        POP	DS
	MOV	XMSError, BL
	end;

end;

function CopyCMemToXMem(DestHandle : XMHandle; DestOff : Longint;
                        Src : Pointer; N : Longint) : Boolean;
var
  X : TXMCopyRec;
begin
  X.Count        := N;
  X.SourceHandle := 0;
  X.SourceOff    := Longint(Src);
  X.DestHandle   := DestHandle;
  X.DestOff      := DestOff;
  CopyCMemToXMem := XMemCopy(X);
end;

function CopyXMemToCMem(Dest : Pointer; SrcHandle : XMHandle;
			SrcOff : Longint; N : Longint) : Boolean;
var
  X : TXMCopyRec;
begin
  X.Count        := N;
  X.SourceHandle := SrcHandle;
  X.SourceOff    := SrcOff;
  X.DestHandle   := 0;
  X.DestOff      := Longint(Dest);
  CopyXMemToCMem := XMemCopy(X);
end;

function CopyXMem(DestHandle : XMHandle; DestOff : Longint;
			SrcHandle : XMHandle; SrcOff : Longint; N : Longint) : Boolean;
var
  X : TXMCopyRec;
begin
  X.Count        := N;
  X.SourceHandle := SrcHandle;
  X.SourceOff    := SrcOff;
  X.DestHandle   := DestHandle;
  X.DestOff      := DestOff;
  CopyXMem       := XMemCopy(X);
end;

function CopyMem(Dest : Pointer; Src : Pointer; N : Longint) : Boolean;
var
  X : TXMCopyRec;
begin
  X.Count        := N;
  X.SourceHandle := 0;
  X.SourceOff    := Longint(Src);
  X.DestHandle   := 0;
  X.DestOff      := Longint(Dest);
  CopyMem        := XMemCopy(X);
end;

function UMBAlloc(var Size : Word) : Word; assembler;
label
  UMBAllocFailed;
asm
	LES	DI, Size
	LODSW
	MOV	DX, AX
	XOR	BL, BL
	MOV	AH, 10h
	CALL	[XMSControl]
	MOV	AX, DX
	LES	DI, Size
	STOSW
	OR	AX, AX
	JE	UMBAllocFailed
	MOV	XMSError, 0
        MOV	AX, BX
	RET
UMBAllocFailed:
	MOV	XMSError, BL
end;

function UMBFree(UMBSeg : Word) : Boolean; assembler;
asm
	MOV	DX, UMBSeg
	XOR	BL, BL
	MOV	AH, 11h
	CALL	[XMSControl]
	MOV	XMSError, BL
end;

function UMBReAlloc(UMBSeg : Word; var Size : Word) : Boolean; assembler;
label
  UMBReAllocFailed;
asm
	LES	DI, Size
	LODSW
	MOV	BX, AX
	MOV	DX, UMBSeg
	MOV	AH, 12h
	CALL	[XMSControl]
	OR	AX, AX
	JE	UMBReAllocFailed
	MOV	XMSError, 0
        RET
UMBReAllocFailed:
	MOV	XMSError, BL
	MOV	AX, DX
	LES	DI, Size
	STOSW
        XOR	AL, AL
end;

function XMSErrorMsg(ErrorCode : Byte) : PChar;
var
  I, J : Byte;
begin
  J := 0;
  for I := 1 to XMSErrorCount do
    if XMSErrorNumber[I] = ErrorCode then J := I;
  XMSErrorMsg := XMSErrorString[J];
end;

procedure PrintXMSError(const S : string);
begin
  WriteLn(S, ': ', XMSErrorMsg(XMSError));
end;

begin
  XMSControl   := @XMSDefaultControl;
  InitXMS2;
end.