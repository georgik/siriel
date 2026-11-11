
procedure redraw2;
begin
   reset_pol;
   write_palette(blackx,0,256);
   vypni_charakter(si.oldx+px,si.oldy+py,si.buf,ar^);
  redraw(true);
   si.oldx:=si.x;
   si.oldy:=si.y;
   init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^);
   write_palette(palx,0,256);
end;
{znovu zaktivuje vsetky predmety}
{zhasne predmety}
procedure reaktivate(num:word);
begin
     vypni_charakter(si.oldx+px,si.oldy+py,si.buf,ar^);
	 si.oldx:=si.x;
	 si.oldy:=si.y;
	getseg(vec^[num].x,vec^[num].y,16,16,0,vec^[num].zas);
	putseg2xms(handles[4],vec^[num].x,vec^[num].y,resx,resy,vec^[num].obr,13);
	init_charakter(resx,resy,si.oldx+px,si.oldy+py,poloha,si.buf,ar^);
end;
