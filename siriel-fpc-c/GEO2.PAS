{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit geo2;
{GEORGESOFT -unitka urcena na kontrolu CRC  XX:-D}
{Phase 1: CRC checksum protection removed - obsolete anti-floppy protection.}
{Verification is bypassed so data files still load (see handover.md).}
interface

{udaje potrebne na definiciu CRC}
type crc_typ=record
	c16,ca:word;
	c32:longint;
    end;

function subor_size(name:string):longint; {zoberie velkost suboru}
function test_crc(name:string;c:crc_typ):boolean;
function  subor_crc(name:string):byte;
procedure write_crc(s:string);

procedure block_ctrl_break;
procedure enable_ctrl_break;

procedure engine_screen(version:string);

implementation

uses dos,crt,geo;

{zablokuje CTRL+BREAK}
procedure block_ctrl_break;
begin
end;
{povoli CTRL+BREAK}
procedure enable_ctrl_break;
begin
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

{CRC verification disabled in Phase 1 - stored checksum is no longer checked}
function test_crc(name:string;c:crc_typ):boolean;
begin
    test_crc:=true;
end;

{CRC verification disabled in Phase 1 - an existing file is accepted}
function subor_crc(name:string):byte;
begin
    if subor_exist(name) then subor_crc:=0 else subor_crc:=2;
end;

{CRC backup disabled in Phase 1 - no .dac copy is produced}
procedure write_crc(s:string);
begin
end;

{uklada CRC na koniec suboru s priponou DAC}
{CRC sa uklada na koniec suboru vo forme:
'C' - definicny znak
CRC16 - kontrolny 16bitowy sucet
CRC32 - kontrolny 32bitowy sucet
CRCARC - kontrola ARC}

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
