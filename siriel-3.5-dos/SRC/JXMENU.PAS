{created by GEORGESOFT  - for special using of JXGRAF}
{$V-}
unit jxmenu;

interface

uses txt,jxgraf,geo,jxefekt,jxvar;

const max_menu=64;
type
    polozka_typ=record
	   meno:string[64];
	   x,y:word;
	   k:word;
    end;
    jxmenu_typ=record
	   dat:array[1..64] of polozka_typ;
	   pocet,first,vybrane,roll,posuv:byte;
	   x,y,x1,y1,col1,col2,col3:word;
	   meno:string[64];
	   draw_menu:boolean;
     end;


procedure graphicswindow(x,y,x1,y1,col1,col2:word;napis:string);
procedure stvorec(x,y,x1,y1,col1,col2:word);
procedure stvorec2(x,y,x1,y1,col1,col2,num:word);
procedure input_key2(x,y,col1,col2:word;napis:string; var odpis:string;dlzka:word);

procedure init_jxmenu(x,y,col1,col2,col3:word; meno:string;var menx:jxmenu_typ);
procedure vloz_jxmenu(x,y:word;meno:string; var menx:jxmenu_typ;k:word);
procedure vloz_jxmenu2(meno:string;var menx:jxmenu_typ;k:word);

procedure vyber_jxmenu(var menx:jxmenu_typ;var num:word);
procedure vyber_jxmenu2(var menx:jxmenu_typ);
function vyber_jxmenu3(var menx:jxmenu_typ):byte;

procedure size_jxmenu(x,y:word; var menx:jxmenu_typ);
procedure draw_jxmenu(var menx:jxmenu_typ);
procedure draw_jxmenu2(var menx:jxmenu_typ;sub,back:string);
procedure draw_jxmenu3(var menx:jxmenu_typ);
procedure first_jxmenu(num:byte;var menx:jxmenu_typ);
procedure setrolll_jxmenu(num:byte;var menx:jxmenu_typ);
{procedure pos_jxmenu(xpos,ypos:word;var menx:jxmenu_typ);
procedure sizepos_jxmenu(x,y,xpos,ypos:word;var menx:jxmenu_typ);}


implementation

var k:word;

procedure stvorec(x,y,x1,y1,col1,col2:word);
begin
   rectangle2(screen,x,y,x1,y1,col2);
   line(screen,x,y,x1+x,y,col1);
   line(screen,x,y,x,y+y1,col1);
   line(screen,x1+x,y,x1+x,y+y1,col1);
   line(screen,x,y1+y,x1+x,y+y1,col1);
end;

procedure stvorec2(x,y,x1,y1,col1,col2,num:word);
var f:word;
begin
    for f:=0 to  num-1 do begin
      line(screen,x+f,y+f,x1+x-f,y+f,col1+f);
      line(screen,x+f,y+f,x+f,y+y1-f,col1+f);
      line(screen,x1+x-f,y+f,x1+x-f,y+y1-f,col1+f);
      line(screen,x+f,y1+y-f,x1+x-f,y+y1-f,col1+f);
    end;
   rectangle2(screen,x+f,y+f,x1-f*2,y1-f*2,col2);
end;

procedure graphicswindow(x,y,x1,y1,col1,col2:word;napis:string);
begin
   stvorec(x,y,x1,y1,col1,col2);
{   rectangle2(screen,x+((x1) div 2)-(chardx*length(napis)div 2),y-(chardy div 2),
		  (chardx*length(napis)),(chardy div 2),col2);}
   stvorec(x+((x1) div 2)-(chardx*length(napis)div 2),y-(chardy div 2),
		  (chardx*length(napis)),chardy ,col1,col2);
   print_normal(screen,x+((x1) div 2)-(chardx*length(napis)div 2),y-(chardy div 2),napis,col1,0);
end;

procedure init_jxmenu(x,y,col1,col2,col3:word; meno:string;var menx:jxmenu_typ);
begin
    menx.vybrane:=0;
    menx.x1:=0;
    menx.y1:=0;
    menx.roll:=20;
    menx.posuv:=0;
    menx.x:=x;
    menx.y:=y;
    menx.pocet:=0;
    menx.col1:=col1;
    menx.col2:=col2;
    menx.col3:=col3;
    menx.meno:=meno;
    menx.draw_menu:=false;
    menx.first:=1;
end;

procedure first_jxmenu(num:byte;var menx:jxmenu_typ);
begin
    menx.first:=num;
end;

procedure vloz_jxmenu(x,y:word;meno:string; var menx:jxmenu_typ;k:word);
begin
    if menx.pocet<max_menu then begin
     inc(menx.pocet);
     menx.dat[menx.pocet].x:=x;
     menx.dat[menx.pocet].y:=y;
     menx.dat[menx.pocet].meno:=' '+meno+' ';
     menx.dat[menx.pocet].k:=k;
    end;
end;

procedure vloz_jxmenu2(meno:string;var menx:jxmenu_typ;k:word);
begin
    if menx.pocet<max_menu then begin
     inc(menx.pocet);
     menx.dat[menx.pocet].x:=menx.x+2*chardx;
     menx.dat[menx.pocet].y:=menx.y+chardy+menx.pocet*chardy;
     menx.dat[menx.pocet].meno:=' '+meno+' ';
     menx.dat[menx.pocet].k:=k;
    end;
end;

procedure size_jxmenu(x,y:word; var menx:jxmenu_typ);
begin
     menx.x1:=x;
     menx.y1:=y;
end;

{procedure pos_jxmenu(xpos,ypos:word;var menx:jxmenu_typ);
begin
     menx.posx:=xpos;
     menx.posy:=ypos;
end;

procedure sizepos_jxmenu(x,y,xpos,ypos:word;var menx:jxmenu_typ);
begin
     size_jxmenu(x,y,menx);
     pos_jxmenu(xpos,ypos,menx);
end;
}
procedure hi_jxmenu(f:byte;var menx:jxmenu_typ);
begin
	print_normal(screen,menx.dat[f].x,menx.dat[f].y-menx.posuv*chardy,menx.dat[f].meno,menx.col2,0);
end;

procedure normal_jxmenu(f:byte;var menx:jxmenu_typ);
begin
{      printat(screen,menx.dat[f].x,menx.dat[f].y,menx.dat[f].meno,menx.col1,menx.col3,0);}
	print_normal(screen,menx.dat[f].x,menx.dat[f].y-menx.posuv*chardy,menx.dat[f].meno,menx.col1,0);
end;


{vypisuje podavacie ukazatele}
procedure down_abl(var menx:jxmenu_typ;typ:boolean);
begin
    if typ then print_normal(screen,menx.x+6,menx.y+menx.y1-2*chardy,#31,menx.col1,0)
    else
    print_normal(screen,menx.x+6,menx.y+menx.y1-2*chardy,#31,menx.col3,0);
end;

procedure up_abl(var menx:jxmenu_typ;typ:boolean);
begin
    if typ then print_normal(screen,menx.x+6,menx.y+chardy,#30,menx.col1,0)
    else
    print_normal(screen,menx.x+6,menx.y+chardy,#30,menx.col3,0);
end;


procedure draw_jxmenu3(var menx:jxmenu_typ);
var ff,f,max:byte;
begin
    if menx.pocet>menx.roll then normal_jxmenu(menx.roll+1,menx);
    if menx.pocet<menx.roll then menx.roll:=menx.pocet;
    max:=length(menx.meno);
    for f:=1 to menx.roll do begin
	  if length(menx.dat[f].meno)>max then max:=length(menx.dat[f].meno);
    end;

    for f:=1 to menx.roll do begin
	vloz_medzery(menx.dat[f].meno,max);
	normal_jxmenu(f,menx);
    end;

    print_normal(screen,menx.x+(menx.x1 div 2)-(chardx*length(menx.meno) div 2),menx.y+(chardy div 2),
                 ' '+menx.meno+' ',menx.col2,0);

    for f:=1 to menx.roll do
	  normal_jxmenu(f,menx);
    if menx.pocet>menx.roll then begin
       normal_jxmenu(menx.roll+1,menx);
       down_abl(menx,true);
    end;
    menx.draw_menu:=true;
end;

procedure draw_jxmenu2(var menx:jxmenu_typ;sub,back:string);
var ff,f,max:byte;
begin
    if menx.pocet>menx.roll then normal_jxmenu(menx.roll+1,menx);
    if menx.pocet<menx.roll then menx.roll:=menx.pocet;
    max:=length(menx.meno);
    for f:=1 to menx.roll do begin
	  if length(menx.dat[f].meno)>max then max:=length(menx.dat[f].meno);
    end;

    for f:=1 to menx.roll do begin
	vloz_medzery(menx.dat[f].meno,max);
	normal_jxmenu(f,menx);
    end;

    if back<>'' then draw_it2(sub,back,menx.x,menx.y,palx);
    print_normal(screen,menx.x+(gif_x div 2)-(chardx*length(menx.meno) div 2),menx.y+(chardy div 2),
                 ' '+menx.meno+' ',menx.col2,0);

    for f:=1 to menx.roll do
	  normal_jxmenu(f,menx);
    if menx.pocet>menx.roll then begin
       normal_jxmenu(menx.roll+1,menx);
       down_abl(menx,true);
    end;
    menx.draw_menu:=true;
end;

procedure draw_jxmenu(var menx:jxmenu_typ);
var ff,f,max:byte;
begin
    if menx.pocet>menx.roll then normal_jxmenu(menx.roll+1,menx);
    if menx.pocet<menx.roll then menx.roll:=menx.pocet;
    max:=length(menx.meno);
    for f:=1 to menx.roll do begin
	  if length(menx.dat[f].meno)>max then max:=length(menx.dat[f].meno);
    end;

    for f:=1 to menx.roll do begin
	vloz_medzery(menx.dat[f].meno,max);
	normal_jxmenu(f,menx);
    end;

    if (menx.x1=0) and (menx.y1=0) then begin
     graphicswindow(menx.x,menx.y,(max+5)*chardx,(menx.roll+4)*chardy,menx.col1,menx.col3,' '+menx.meno+' ');
     menx.x1:=(max+5)*chardx;
     menx.y1:=(menx.roll+4)*chardy;
    end
    else
     graphicswindow(menx.x,menx.y,menx.x1,menx.y1,menx.col1,menx.col3,' '+menx.meno+' ');

    for f:=1 to menx.roll do
	  normal_jxmenu(f,menx);
    if menx.pocet>menx.roll then begin
       normal_jxmenu(menx.roll+1,menx);
       down_abl(menx,true);
    end;
    menx.draw_menu:=true;
end;

procedure roll_menu_up(var menx:jxmenu_typ);
var mer:^tline;
    f,ff:word;
begin
  inc(menx.posuv);
  new(mer);
 for ff:=1 to chardy div 4 do begin
  for f:=menx.y+chardy+4 to menx.y1+menx.y-chardy+2 do begin
      read_linepos(screen,mer^,menx.x+6+chardx,f,menx.x1-8-2*chardx);
      write_linepos(screen,mer^,menx.x+6+chardx,f-4,menx.x1-8-2*chardx);
  end;
  clear_key_buffer;
 end;
  dispose(mer);
end;

procedure roll_menu_down(var menx:jxmenu_typ);
var mer:^tline;
    f,ff:word;
begin
  dec(menx.posuv);
  new(mer);
 for ff:=1 to chardy div 4 do begin
  for f:=menx.y1+menx.y-chardy-4 downto menx.y+chardy-4  do begin
      read_linepos(screen,mer^,menx.x+6+chardx,f,menx.x1-8-2*chardx);
      write_linepos(screen,mer^,menx.x+6+chardx,f+4,menx.x1-8-2*chardx);
  end;
  clear_key_buffer;
 end;
  dispose(mer);
end;

procedure vyber_jxmenu(var menx:jxmenu_typ;var num:word);
var f,ff,k:word;
    l1,l2:boolean;
begin
   if menx.pocet>0 then begin
   if menx.pocet<menx.roll then menx.roll:=menx.pocet;

  if not menx.draw_menu then draw_jxmenu(menx);
{    if joystick_able then joystick_kaliber;}
    f:=menx.first;
    l1:=false;
    l2:=false;
    if menx.posuv>0 then up_abl(menx,true);
    if menx.posuv+menx.roll<menx.pocet then down_abl(menx,true);
    repeat
       {vypise posuvne znacky}

	hi_jxmenu(f,menx);
{    k:=0;}
    if joystick_able then sipka_joystick;
    if keypressed then begin
       if menx.posuv>0 then begin
          up_abl(menx,true);
          l1:=true
       end
          else if l1 then begin
               up_abl(menx,false);
               l1:=false;
       end;
       if menx.posuv+menx.roll<menx.pocet then begin
          down_abl(menx,true);
          l2:=true;
       end
          else if l2 then begin
               down_abl(menx,false);
               l2:=false;
        end;
        k:=key;
        clear_key_buffer;
	normal_jxmenu(f,menx);
	for ff:=1 to menx.roll do begin
	    if menx.dat[ff].k=k then f:=ff;
	end;
	case k of
	     $4800,$4b00,$4838,$4b34,$4a2d:if f>1 then begin
                            dec(f);
                            if f-1<menx.posuv then begin
                               roll_menu_down(menx);
                               if f>1 then begin
                                  normal_jxmenu(f-1,menx);
                               end;
                            end;
                         end  else if menx.pocet<=menx.roll then f:=menx.pocet;
	     $5000,$4d00,$5032,$4d36,$4e2b:if f<menx.pocet then begin
                            inc(f);
                            if f>menx.posuv+menx.roll then begin
                               roll_menu_up(menx);
                               if menx.pocet>f then begin
                                  normal_jxmenu(f+1,menx);
                               end;
                            end;
                         end
                         else if menx.pocet<=menx.roll then f:=1;
	     $4700,$4900:if menx.pocet<menx.roll then f:=1
                            else f:=menx.posuv+1;
	     $4f00,$5100:if menx.pocet<menx.roll then f:=menx.pocet
                            else f:=menx.posuv+menx.roll;
	end;
    end;
    until (k=$1c0d) or (k=$011b) or (k=$3920) or (k=$4c35);
    if k=$011b then num:=0 else num:=f;
   end;
   clear_key_buffer;
   menx.vybrane:=num;
end;

procedure vyber_jxmenu2(var menx:jxmenu_typ);
var v:word;
begin
 vyber_jxmenu(menx,v);
end;

function vyber_jxmenu3(var menx:jxmenu_typ):byte;
var v:word;
begin
 vyber_jxmenu(menx,v);
 vyber_jxmenu3:=menx.vybrane;
end;

procedure setrolll_jxmenu(num:byte;var menx:jxmenu_typ);
begin
     menx.roll:=num;
end;

procedure input_key2(x,y,col1,col2:word;napis:string; var odpis:string;dlzka:word);
begin
    graphicswindow(x,y,chardx*(4+dlzka),chardy*2,col1,col2,napis);
    input_key(x+chardx,y+(chardy div 2),col1,0,odpis,dlzka,'<');
end;

end.
