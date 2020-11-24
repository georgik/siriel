unit geo2;
{GEORGESOFT -unitka urcena na kontrolu CRC  XX:-D}
interface

{udaje potrebne na definiciu CRC}
type crc_typ=record
	c16,ca:word;
	c32:longint;
    end;

function subor_size(name:string):longint; {zoberie velkost suboru}
function test_crc(name:string;c:crc_typ):boolean;
function  crc_exist(name:string):boolean;
procedure get_crc(name:string;var c:crc_typ);
function  subor_crc(name:string):byte;
procedure write_crc(s:string);

procedure block_ctrl_break;
procedure enable_ctrl_break;

procedure engine_screen(version:string);

implementation

uses dos,crt,geo,crc;

{zablokuje CTRL+BREAK}
procedure block_ctrl_break;
begin
   asm
	 push ax
	 push dx
	 mov ah,$33
	 mov al,$1
	 mov dl,$0
	 int $21
	 pop ax
	 pop dx
   end;
end;
{povoli CTRL+BREAK}
procedure enable_ctrl_break;
begin
   asm
	 push ax
	 push dx
	 mov ah,$33
	 mov al,$1
	 mov dl,$1
	 int $21
	 pop ax
	 pop dx
   end;
end;


{vystupom je velkost suboru}
function subor_size(name:string):longint;
var f:file;
    sr:searchrec;
begin
    subor_size:=0;
    if subor_exist(name) then begin
	 findfirst(name,$3f,sr);
	 subor_size:=sr.size;
    end;
end;

{otestuje vstupne CRC udaje na subore}
function test_crc(name:string;c:crc_typ):boolean;
 const
  BufSize = 32768;
type
  filex= Array[1..BufSize] Of Byte;
Var
  Crc32 : LongInt;
  InFile : File;
  InBuf :^filex;
  Len, Crc16, CrcArc, SaveCrc : Word;
  remaining:longint;
begin
    test_crc:=false;
    remaining:=subor_size(name);
    dec(remaining,11);
    if (remaining>0) and (memavail>bufsize) then begin
	new(inbuf);
	assign(infile,name);
	reset(infile,1);
	Crc16 := 0;            { "XModem" crc starts with zero.. }
	CrcArc := 0;           { ..as does ARC crc }
	Crc32 := $FFFFFFFF;    { 32 bit crc starts with all bits on }
	Repeat
	  BlockRead(InFile, InBuf^, BufSize, Len);
	  if remaining-bufsize>=0 then dec(remaining,bufsize)
	    else begin
		dec(len,11);
		remaining:=0;
	    end;
	  Crc16 := UpdateCrc16(Crc16, InBuf^, Len);
	  CrcArc := UpdateCrcArc(CrcArc, InBuf^, Len);
	  Crc32 := UpdateCrc32(Crc32, InBuf^, Len);
	Until remaining=0;
	Close(InFile);
	SaveCrc := Crc16;      { Save near-complete XModem crc for test below }
	FillChar(InBuf^, 2, 0); { Finish XModem crc with two nulls }
	Crc16 := UpdateCrc16(Crc16, InBuf^, 2);
	Crc32 := Not(Crc32);   { Finish 32 bit crc by inverting all bits }
	dispose(inbuf);
	if (c.c16=crc16) and (c.c32=crc32) and (c.ca=crcarc) then
	   test_crc:=true;
    end;
end;

{funkcia zisti, ci existuje v subore CRC}
function crc_exist(name:string):boolean;
var f:file;
    sr:searchrec;
    s:string[3];
    ch:char;
    ff:byte;
begin
    crc_exist:=false;
    s:='';
    if subor_exist(name) then begin
     assign(f,name);
     reset(f,1);
     seek(f,subor_size(name)-11);
     for ff:=1 to 3 do begin
	blockread(f,ch,sizeof(ch));
	s:=s+ch;
     end;
     close(f);
	if s='CRC' then crc_exist:=true;
    end;
end;

{zoberie CRC definiciu z konca suboru}
procedure get_crc(name:string;var c:crc_typ);
var f:file;
    sr:searchrec;
begin
     if crc_exist(name) then begin
	findfirst(name,$3f,sr);
	dec(sr.size,8);
	assign(f,name);
	reset(f,1);
	{$I-}
	seek(f,sr.size);
	 blockread(f,c.c16,sizeof(c.c16));
	 blockread(f,c.c32,sizeof(c.c32));
	 blockread(f,c.ca,sizeof(c.ca));
	close(f);
     {$I+}
     end;
end;


{skontroluje CRC a vypise vysledok:
  0:CRC je OK
  1:neexistuje CRC udaj na konci suboru
  2:neexistuje subor
  3:CRC nesedi}
function subor_crc(name:string):byte;
var c:crc_typ;
begin
  subor_crc:=2;
  if subor_exist(name) then begin
     subor_crc:=1;
     if crc_exist(name) then begin
	  subor_crc:=3;
	  get_crc(name,c);
	  if test_crc(name,c) then begin
	     subor_crc:=0;
	  end;
     end;
  end;
end;


{uklada CRC na koniec suboru s priponou DAC}
{CRC sa uklada na koniec suboru vo forme:
'C' - definicny znak
CRC16 - kontrolny 16bitovy sucet
CRC32 - kontrolny 32bitovy sucet
CRCARC - kontrola ARC}

procedure write_crc(s:string);
Const
  BufSize = 32768;
Type
  Str2 = String[2];
  Str4 = String[4];
  Str8 = String[8];
  filex= Array[1..BufSize] Of Byte;
Var
  sub:file;
  Crc32 : LongInt;
  InFile,outfile : File;
  InBuf :^filex;
  Len, Crc16, CrcArc, SaveCrc : Word;
  ch:char;
  s2,s3:string;
  remaining:longint;
  sr:searchrec;
begin
    findfirst(s,$3f,sr);
    remaining:=sr.size;

    new(inbuf);
    s2:=s;
    s2[0]:=chr(length(s2)-3);
    s3:=s2;
    s2:=s2+'dac';
    Assign(InFile, s);
    Reset(InFile, 1);
    assign(outfile,s2);
    rewrite(outfile,1);
   {$I+}
    If IoResult = 0 Then Begin
	Crc16 := 0;            { "XModem" crc starts with zero.. }
	CrcArc := 0;           { ..as does ARC crc }
	Crc32 := $FFFFFFFF;    { 32 bit crc starts with all bits on }
	Repeat
	  BlockRead(InFile, InBuf^, BufSize, Len);
	 if remaining>bufsize then begin
	    blockwrite(outfile,inbuf^,bufsize);
	  end
	  else
	  blockwrite(outfile,inbuf^,remaining);
	  if remaining-bufsize>=0 then dec(remaining,bufsize);
	  Crc16 := UpdateCrc16(Crc16, InBuf^, Len);
	  CrcArc := UpdateCrcArc(CrcArc, InBuf^, Len);
	  Crc32 := UpdateCrc32(Crc32, InBuf^, Len);
	Until Eof(InFile);
	Close(InFile);
	SaveCrc := Crc16;      { Save near-complete XModem crc for test below }
	FillChar(InBuf^, 2, 0); { Finish XModem crc with two nulls }
	Crc16 := UpdateCrc16(Crc16, InBuf^, 2);
	Crc32 := Not(Crc32);   { Finish 32 bit crc by inverting all bits }
    ch:='C';
    blockwrite(outfile,ch,sizeof(ch));
    ch:='R';
    blockwrite(outfile,ch,sizeof(ch));
    ch:='C';
    blockwrite(outfile,ch,sizeof(ch));
  blockwrite(outfile,crc16,sizeof(crc16));
  blockwrite(outfile,crc32,sizeof(crc32));
  blockwrite(outfile,crcarc,sizeof(crcarc));
  close(outfile);
  end;
  dispose(inbuf);         {a nazaver premenuje zalohovacie subory}
  assign(infile,s);
  rename(infile,s3+'old');
  assign(infile,s2);
  rename(infile,s3+'dat');
end;

procedure engine_screen(version:string);
begin
   clrscr;
   textbackground(12);
    clreol;
    textcolor(15);
    gotoxy(35,1);
    writeln(version);
   textbackground(0);
end;

end.
