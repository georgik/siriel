unit jxxms;

{$mode objfpc}{$H+}

{ This unit provides XMS (Extended Memory Specification) compatibility }
{ Modern implementation uses dynamic memory allocation instead of XMS }

interface

uses
  SysUtils;

type
  { Handle type for XMS memory blocks }
  klucka = record
    used: boolean;
    data: pointer;
    size: longint;
  end;

{ Memory management }
procedure create_handle(var h: klucka; size: longint);
procedure kill_handle(var h: klucka);

{ Sprite operations }
procedure getsegxms(var handle: klucka; x, y, width, height, num: word);
function putseg2xms(var handle: klucka; x, y, width, height, num, col: word): word;
function putseg2xms_sizex(var handle: klucka; x, y, width, height, num, col: word): word;

implementation

uses
  jxgraf,
  animing;

{ Create a new memory handle }
procedure create_handle(var h: klucka; size: longint);
begin
  h.used := true;
  h.size := size;
  GetMem(h.data, size);
  FillChar(h.data^, size, 0);
end;

{ Free a memory handle }
procedure kill_handle(var h: klucka);
begin
  if h.used then
  begin
    if Assigned(h.data) then
      FreeMem(h.data);
    h.used := false;
    h.data := nil;
    h.size := 0;
  end;
end;

{ Read sprite from screen to XMS memory }
procedure getsegxms(var handle: klucka; x, y, width, height, num: word);
var
  offset: longint;
  ptr: PByte;
begin
  if not handle.used then Exit;
  if handle.size < (width * height * (num + 1)) then Exit;

  offset := (width * height) * num;
  ptr := PByte(handle.data);
  Inc(ptr, offset);

  { Read from screen using animing.getseg }
  getseg(x, y, width, height, num, PByte(ptr)^);
end;

{ Write sprite from XMS memory to screen }
function putseg2xms(var handle: klucka; x, y, width, height, num, col: word): word;
var
  offset: longint;
  ptr: PByte;
begin
  putseg2xms := 0;

  if not handle.used then Exit;
  if handle.size < (width * height * (num + 1)) then Exit;

  offset := (width * height) * num;
  ptr := PByte(handle.data);
  Inc(ptr, offset);

  { Write to screen using animing.putseg2 }
  putseg2(x, y, width, height, num, col, PByte(ptr)^);

  putseg2xms := width;
end;

{ Write sprite from XMS to screen and return width }
function putseg2xms_sizex(var handle: klucka; x, y, width, height, num, col: word): word;
begin
  putseg2xms_sizex := putseg2xms(handle, x, y, width, height, num, col);
end;

end.
