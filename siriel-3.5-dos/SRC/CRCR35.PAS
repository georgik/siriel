unit crcr35;
interface
uses geo2,crc,jxgraf,geo,jxmenu,aktiv35,load135;
function test_crc2(name:string;c:crc_typ):boolean;
function subor_crc2(name:string):byte;
procedure verify_crc(name:string);

implementation

{otestuje vstupne CRC udaje na subore}
function test_crc2(name:string;c:crc_typ):boolean;
 const
  BufSize = 32768;
type
  filex= Array[1..BufSize] Of Byte;
Var
  Crc32 : LongInt;
  InFile : File;
  InBuf :^filex;
  Len, Crc16, CrcArc, SaveCrc : Word;
  remaining,counter:longint;
  perc:real;
  perc2:byte;
  s:string;
begin
    test_crc2:=false;
    remaining:=subor_size(name);
    dec(remaining,11);
    perc:=100/remaining;
    counter:=0;
    if (remaining>0) and (memavail>bufsize) then begin
	  new(inbuf);
	  assign(infile,name);
	  reset(infile,1);
	  Crc16 := 0;            { "XModem" crc starts with zero.. }
	  CrcArc := 0;           { ..as does ARC crc }
	  Crc32 := $FFFFFFFF;    { 32 bit crc starts with all bits on }
	  Repeat
	    perc2:=round(perc*counter);
	    str(perc2,s);
	    rectangle2(screen,270+perc2,240,100-perc2,16,0);
	    rectangle2(screen,270,240,perc2,16,1);
	    printc(screen,240,s+' %',15,0);
	    BlockRead(InFile, InBuf^, BufSize, Len);
	    if remaining-bufsize>=0 then begin
		    dec(remaining,bufsize);
		    inc(counter,bufsize);
	    end
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
	     test_crc2:=true;
    end;
end;


{skontroluje CRC a vypise vysledok:
  0:CRC je OK
  1:neexistuje CRC udaj na konci suboru
  2:neexistuje subor
  3:CRC nesedi}
function subor_crc2(name:string):byte;
var c:crc_typ;
begin
  subor_crc2:=2;
  if subor_exist(name) then begin
     subor_crc2:=1;
     if crc_exist(name) then begin
	    subor_crc2:=3;
	    get_crc(name,c);
	    if test_crc2(name,c) then begin
		 subor_crc2:=0;
	    end;
     end;
  end;
end;
{over CRC v datadisku}
procedure verify_crc(name:string);
var stav:byte;
	  s:string;
	  m:^jxmenu_typ;
	  vysl:word;
begin
	  clear_bitmap(screen);
	  graphicswindow(250,230,140,36,14,0,'  '+tx[ja,9]);
	  stav:=subor_crc2(name);
	  s:='O.K.';
	  case stav of
		 1:s:=tx3[ja,10];
		 3:s:=tx3[ja,11];
	  end;
	  if stav>0 then clear_bitmap(screen);
	  printc(screen,280,s,14,0);
	  if stav>0 then begin
		    printc(screen,300,tx3[ja,12],12,0);
		    new(m);
			 init_jxmenu(270,110,15,12,0,' ? ',m^);
			 vloz_jxmenu2(tx[ja,23],m^,0);
			 vloz_jxmenu2(tx[ja,24],m^,0);
			 vyber_jxmenu(m^,vysl);
		    dispose(m);
		    if vysl<>1 then ending('CRC !');
	  end;
end;

begin
end.