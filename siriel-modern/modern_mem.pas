unit modern_mem;

{$mode objfpc}{$H+}

{ Modern memory management unit
  Replaces XMS (Extended Memory Specification) with standard FPC heap
  Maintains exact API compatibility with original JXXMS.PAS
  Author: Siriel Modern Migration
  Date: January 25, 2026
}

interface

type
  { Handle type - compatible with original klucka }
  klucka = record
    h: word;           { Handle identifier }
    used: boolean;     { Whether handle is in use }
    ptr: Pointer;      { Actual memory pointer (modern addition) }
    size: LongInt;     { Size in bytes (for debugging) }
  end;

  helpline = array[0..639] of byte;  { For screen-to-memory transfer }

var
  num_handles: word;    { Total number of handles available }
  no_handle: klucka;    { Empty/invalid handle }
  handles_ptr: pointer; { Pointer to global handles array (set by aktiv35) }

{ Initialize array of handles }
procedure init_handles(num: word; var handles: array of klucka);

{ Cleanup all handles }
procedure done_handles(var handles: array of klucka);

{ Free memory for a handle }
function kill_handle(var kluka: klucka): boolean;

{ Allocate memory for a handle }
function create_handle(var kluka: klucka; size: longint): boolean;

{ Screen save/restore functions (for compatibility) }
procedure Save_scr(var kluka: klucka; X, Y, SX, SY: longint);
procedure draw_scr(var kluka: klucka; X, Y, SX, SY: longint);

{ Memory copy functions (XMS compatibility) }
procedure CopyCMemToXMem(h: word; offset: longint; src: Pointer; size: longint);
procedure CopyXMemToCMem(dst: Pointer; h: word; offset: longint; size: longint);

implementation

uses
  jxgraf;  { For screen_image access }

{ Initialize all handles to unused state }
procedure init_handles(num: word; var handles: array of klucka);
var
  f: word;
begin
  num_handles := num;
  for f := 0 to num_handles - 1 do
  begin
    handles[f].used := False;
    handles[f].ptr := nil;
    handles[f].size := 0;
    handles[f].h := f;
  end;
end;

{ Cleanup all handles in array }
procedure done_handles(var handles: array of klucka);
var
  f: word;
begin
  if num_handles > 0 then
    for f := 0 to num_handles - 1 do
      kill_handle(handles[f]);
  num_handles := 0;
end;

{ Free memory allocated to a handle }
function kill_handle(var kluka: klucka): boolean;
begin
  kill_handle := False;

  if kluka.used then
  begin
    if kluka.ptr <> nil then
    begin
      FreeMem(kluka.ptr);
      kluka.ptr := nil;
    end;

    kluka.used := False;
    kluka.size := 0;
    kill_handle := True;
  end;
end;

{ Allocate memory for a handle }
function create_handle(var kluka: klucka; size: longint): boolean;
begin
  create_handle := False;

  { Round up to even number (original XMS behavior) }
  if size mod 2 = 1 then
    Inc(size);

  if not kluka.used then
  begin
    { New allocation }
    GetMem(kluka.ptr, size);
    if kluka.ptr <> nil then
    begin
      kluka.used := True;
      kluka.size := size;
      kluka.h := 0;  { Handle identifier (0 = unused) }
      create_handle := True;
    end;
  end
  else
  begin
    { Reallocation - resize existing block }
    ReAllocMem(kluka.ptr, size);
    if kluka.ptr <> nil then
    begin
      kluka.size := size;
      create_handle := True;
    end;
  end;
end;

{ Save screen region to memory }
procedure Save_scr(var kluka: klucka; X, Y, SX, SY: longint);
var
  src_y, src_x: word;
  src_idx: longint;
  dst_ptr: PByte;
begin
  { Ensure handle has enough memory allocated }
  if not kluka.used then
    create_handle(kluka, SX * SY);

  if kluka.used and (kluka.ptr <> nil) then
  begin
    dst_ptr := PByte(kluka.ptr);

    { Copy screen region row by row }
    for src_y := 0 to SY - 1 do
    begin
      for src_x := 0 to SX - 1 do
      begin
        { Calculate source index in screen buffer (RGBA) }
        src_idx := ((Y + src_y) * 640 + (X + src_x)) * 4;

        { Copy only the R channel (original was palette-indexed) }
        dst_ptr^ := PByte(screen_image^.data + src_idx)^;
        Inc(dst_ptr);
      end;
    end;
  end;
end;

{ Restore screen region from memory }
procedure draw_scr(var kluka: klucka; X, Y, SX, SY: longint);
var
  dst_y, dst_x: word;
  dst_idx: longint;
  src_ptr: PByte;
  r, g, b, a: byte;
begin
  if kluka.used and (kluka.ptr <> nil) then
  begin
    src_ptr := PByte(kluka.ptr);

    { Copy memory to screen region row by row }
    for dst_y := 0 to SY - 1 do
    begin
      for dst_x := 0 to SX - 1 do
      begin
        { Calculate destination index in screen buffer (RGBA) }
        dst_idx := ((Y + dst_y) * 640 + (X + dst_x)) * 4;

        { Read palette value and convert to grayscale RGB }
        r := src_ptr^;
        g := r;
        b := r;
        a := 255;

        { Write to screen }
        PByte(screen_image^.data + dst_idx)^ := r;
        PByte(screen_image^.data + dst_idx + 1)^ := g;
        PByte(screen_image^.data + dst_idx + 2)^ := b;
        PByte(screen_image^.data + dst_idx + 3)^ := a;

        Inc(src_ptr);
      end;
    end;
  end;
end;

{ ========================================
   MEMORY COPY FUNCTIONS (XMS Compatibility)
   ======================================== }

procedure CopyCMemToXMem(h: word; offset: longint; src: Pointer; size: longint);
var
  handles_array: array of klucka absolute handles_ptr;
  dst_ptr: PByte;
  src_ptr: PByte;
  i: longint;
begin
  if handles_ptr = nil then
    exit;

  if h > 0 then
  begin
    src_ptr := PByte(src);
    dst_ptr := PByte(handles_array[h].ptr) + offset;

    { Copy data }
    for i := 0 to size - 1 do
    begin
      dst_ptr^ := src_ptr^;
      Inc(dst_ptr);
      Inc(src_ptr);
    end;
  end;
end;

procedure CopyXMemToCMem(dst: Pointer; h: word; offset: longint; size: longint);
var
  handles_array: array of klucka absolute handles_ptr;
  src_ptr: PByte;
  dst_ptr: PByte;
  i: longint;
begin
  if handles_ptr = nil then
    exit;

  if h > 0 then
  begin
    src_ptr := PByte(handles_array[h].ptr) + offset;
    dst_ptr := PByte(dst);

    { Copy data }
    for i := 0 to size - 1 do
    begin
      dst_ptr^ := src_ptr^;
      Inc(dst_ptr);
      Inc(src_ptr);
    end;
  end;
end;

initialization
  { Initialize no_handle as invalid }
  no_handle.h := 0;
  no_handle.used := False;
  no_handle.ptr := nil;
  no_handle.size := 0;
  num_handles := 0;
  handles_ptr := nil;

end.
