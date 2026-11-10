{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit crcr35;
{Phase 1: CRC checksum protection removed - obsolete anti-floppy protection.}
interface
uses geo2,jxgraf,geo,jxmenu,aktiv35,load135;
function test_crc2(name:string;c:crc_typ):boolean;
function subor_crc2(name:string):byte;
procedure verify_crc(name:string);

implementation

{CRC verification disabled in Phase 1 - stored checksum is no longer checked}
function test_crc2(name:string;c:crc_typ):boolean;
begin
    test_crc2:=true;
end;

{CRC verification disabled in Phase 1 - an existing file is accepted}
function subor_crc2(name:string):byte;
begin
  if subor_exist(name) then subor_crc2:=0 else subor_crc2:=2;
end;
{over CRC v datadisku - now always reports OK in Phase 1}
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
