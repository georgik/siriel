{$m 16384,0,120000}
{This program is uder (de)construction}
{puzlik - 15}
{velkost jedneho 64x64}
{posuv x+20,y+20}
program puzlik;
uses txt,dos,crt,jxgraf,jxmenu,jxxms,animing,geo,blockx,xms2,mouse,jxgmouse,
     jxzvuk,geo2;

procedure vykresli_plochu;forward;
procedure mouse_button_press;forward;

{$I AKTIVPU.INC}

const pic_file='>GOBR';
	dat_file='PUZLIK.DAT';

	max_handles=4;          {pocet kluciek}
					{1-obrazky puzzle}
					{2-podklady tlacitok}
					{3-zalozne okno}
					{4-druhy typ tlacitok}

{      mpic_x=24;
	mpic_y=24;}
{      mnum=6;
	wait_mys=70;}

	dmax_x=7;
	dmax_y=7;
	dpic_x=64;
	dpic_y=64;

	but_x=108;
	but_y=31;
	but2_x=50;
	but2_y=50;
	max_num_but=9;
	num_but_pic=4;
	num_but2_pic=8;
	but_file='>GBUT';
	but2_file='>GBUT2';

	posuv_obr_x=21;
	posuv_obr_y=21;

	rychlost_posuvu=8;

	prazdne_pole=1;

	hore=1;
	dole=2;
	vlavo=3;
	vpravo=4;

	main_data='PUZLIK.DAT';
	font_file='FMOD';
	m_file='>GMYS';

	version='PUZLIK        0.99';
	xmsRequired = 3500;

	{Game Types}
	klasik=1;
	{1 - klasicky stvorcovy puzlik}
	expedicia=2;
	{2 - typ expedicia}
	locomotion=3;
	{3 - typ locomotion}

type
    bod=record
		  x,y:byte;
    end;

var f:word;
    palx,blackx:tpalette;
    handles:array[1..max_handles] of klucka;
    poradie:array[1..dmax_x+1,1..dmax_y+1] of word;
    kurz:bod;
    the_end:boolean;
    k:word;
    max_x,max_y,pic_x,pic_y,pic_num:longint;
    buttons:array[1..max_num_but] of tlac;
    mys:myska;
    odpoved,vysledok,restartuj,graph_ok:boolean;
    game_type:byte;		{typ hry}
    crc:crc_typ;

procedure draw_it(name:string;x,y:word);
begin
    if length(name)>0 then begin
     if name[1]='>' then begin
	    name:=out_string(name);
	    draw_gif_block(screen,dat_file,name,x,y,palx,256);
     end
     else draw_gif(screen,name,x,y,palx);
    end;
end;

procedure swap_byte(var a,b:byte);
var c:byte;
begin
    c:=a;
    a:=b;
    b:=c;
end;

function ano_nie(num:byte):boolean;
const an_x=200;
	an_y=160;
	an_dx=258;
	an_dy=72;
var ano:boolean;
begin
   create_handle(handles[3],an_dx*an_dy);
   getsegxms(handles[3],an_x,an_y,an_dx,an_dy,0);
   active_floor(buttons,2);
   ano:=true;
   buttons[3].pic:=0;
   buttons[4].pic:=3;
   odpoved:=false;
   print_buttons(buttons,mys);
   repeat
    k:=kkey2;
    if k>0 then begin
	 case k of
	   $4800,$4b00,$4d00,$5000:begin
		if ano then ano:=false else ano:=true;
		swap_byte(buttons[3].pic,buttons[4].pic);
		print_buttons(buttons,mys);
	   end;
	 end;
    end;
    print_mouse(buttons,mys);
    mouse_button_press;
   until (odpoved) or (k=$011b) or (k=$1c0d);
   active_floor(buttons,1);
   print_buttons(buttons,mys);
   putsegxms(handles[3],an_x,an_y,an_dx,an_dy,0);
   kill_handle(handles[3]);
   ano_nie:=vysledok;
   case k of
	  $1c0d:ano_nie:=ano;
	  $011b:ano_nie:=false;
   end;
end;

procedure execute_button(num:word);
{1 - ukonci program}
{2 - restartuj}
{3 - odpoved Ano}
{4 - odpoved Nie}
{7-9 - posuv}
begin
     case num of
	    1:if ano_nie(1) then the_end:=true;
	    2:restartuj:=true;
	    3:begin
		    vysledok:=true;
		    odpoved:=true;
	    end;
	    4:begin
		    vysledok:=false;
		    odpoved:=true;
	    end;
	    6:fake_key($4800);
	    7:fake_key($5000);
	    8:fake_key($4b00);
	    9:fake_key($4d00);
     end;
end;

procedure mouse_button_press;
var f,k1,k2:word;
    none:boolean;
begin
    none:=true;
    mousepos;
    if (mouse_button=1) then begin
     for f:=1 to num_but do
	 if (buttons[f].visible) and (buttons[f].stav) then begin
	    none:=false;
	    execute_button(f);
	 end;
   if none then begin         {kontrolu mysky na poli, ma vyznam prevadzat, iba,
					 ak tam nie je tlacitko}
    k1:=((mouse_posx-posuv_obr_x) div pic_x);
    k2:=((mouse_posy-posuv_obr_y) div pic_y);
    if (k1=kurz.x-1) and (k2=kurz.y-2)then fake_key($5000);
    if (k1=kurz.x-1) and (k2=kurz.y)then fake_key($4800);
    if (k1=kurz.x-2) and (k2=kurz.y-1)then fake_key($4d00);
    if (k1=kurz.x) and (k2=kurz.y-1)then fake_key($4b00);
   end;
{    pripis_to(k1);
    pripis_to(k2);}
  end;
end;

procedure slow_scroll(smer:byte);
var f,p:word;
begin
    case smer of
	   hore,dole:p:=pic_y div rychlost_posuvu;
	   vlavo,vpravo:p:=pic_x div rychlost_posuvu;
    end;
    for f:=1 to p do begin
	  case smer of
		 dole:begin
			    putsegxms(handles[1],(kurz.x-1)*pic_x+posuv_obr_x,
				  (kurz.y-2)*pic_y+posuv_obr_y+(f)*rychlost_posuvu,
				  pic_x,pic_y,poradie[kurz.x,kurz.y-1]-1);
			    rectangle2(screen,(kurz.x-1)*pic_x+posuv_obr_x,
				  (kurz.y-2)*pic_y+posuv_obr_y+(f-1)*rychlost_posuvu,
				  pic_x,rychlost_posuvu,prazdne_pole);
			 end;
		 hore:begin
			    putsegxms(handles[1],(kurz.x-1)*pic_x+posuv_obr_x,
				  (kurz.y-1)*pic_y+posuv_obr_y-f*rychlost_posuvu,
				  pic_x,pic_y,poradie[kurz.x,kurz.y-1]-1);
			    rectangle2(screen,(kurz.x-1)*pic_x+posuv_obr_x,
				  (kurz.y)*pic_y+posuv_obr_y-f*rychlost_posuvu,
				  pic_x,rychlost_posuvu,prazdne_pole);
			 end;
		 vpravo:begin
			    putsegxms(handles[1],(kurz.x-1)*pic_x+posuv_obr_x+f*rychlost_posuvu,
				  (kurz.y-1)*pic_y+posuv_obr_y,
				  pic_x,pic_y,poradie[kurz.x+1,kurz.y]-1);
			    rectangle2(screen,(kurz.x-1)*pic_x+posuv_obr_x+(f-1)*rychlost_posuvu,
				  (kurz.y-1)*pic_y+posuv_obr_y,
				  rychlost_posuvu,pic_y,prazdne_pole);
			 end;
		 vlavo:begin
			    putsegxms(handles[1],(kurz.x-1)*pic_x+posuv_obr_x-f*rychlost_posuvu,
				  (kurz.y-1)*pic_y+posuv_obr_y,
				  pic_x,pic_y,poradie[kurz.x-1,kurz.y]-1);
			    rectangle2(screen,(kurz.x)*pic_x+posuv_obr_x-f*rychlost_posuvu,
				  (kurz.y-1)*pic_y+posuv_obr_y,
				  rychlost_posuvu,pic_y,prazdne_pole);
			 end;
	  end;
	  delay(10);
	  clear_key_buffer;
    end;
end;

procedure posuv(smer:byte;visible:boolean);
var p1,p2:longint;
begin
     p1:=(kurz.x-1)*pic_x+posuv_obr_x;
     p2:=(kurz.y-1)*pic_y+posuv_obr_y;
     case smer of
	    vpravo:if kurz.x>1 then begin
		     if (p1-pic_x-mpic_x<mouse_posx) and ((p1+pic_x+mpic_x)>mouse_posx)
			and (p2-mpic_y<mouse_posy) and ((p2+pic_y)>mouse_posy)
			 then begin
			    zhasni_mys(mys);
			    under_mouse:=true;
			 end;
			dec(kurz.x);
			swap(poradie[kurz.x+1,kurz.y],poradie[kurz.x,kurz.y]);
			if visible then slow_scroll(vpravo);
		   end;
	    vlavo:if kurz.x<max_x then begin
		     if (p1-mpic_x<mouse_posx) and ((p1+2*pic_x+mpic_x)>mouse_posx)
			and (p2-mpic_y<mouse_posy) and ((p2+pic_y)>mouse_posy)
			 then begin
			    zhasni_mys(mys);
			    under_mouse:=true;
			 end;
			swap(poradie[kurz.x,kurz.y],poradie[kurz.x+1,kurz.y]);
			inc(kurz.x);
			if visible then slow_scroll(vlavo);
		   end;
	    dole:if kurz.y>1 then begin
		     if (p1-mpic_x<mouse_posx) and ((p1+pic_x)>mouse_posx)
			and (p2-pic_y-mpic_y<mouse_posy) and ((p2+mpic_y+pic_y)>mouse_posy)
			 then begin
			    zhasni_mys(mys);
			    under_mouse:=true;
			 end;
			if visible then slow_scroll(dole);
			dec(kurz.y);
			swap(poradie[kurz.x,kurz.y+1],poradie[kurz.x,kurz.y]);
		   end;
	    hore:if kurz.y<max_y then begin
		     if (p1-mpic_x<mouse_posx) and ((p1+pic_x)>mouse_posx)
			and (p2-mpic_y<mouse_posy) and ((p2+2*pic_y+mpic_y)>mouse_posy)
			 then begin
			    zhasni_mys(mys);
			    under_mouse:=true;
			 end;
			swap(poradie[kurz.x,kurz.y],poradie[kurz.x,kurz.y+1]);
			inc(kurz.y);
			if visible then slow_scroll(hore);
		   end;
     end;
end;


procedure miesaj(num:word);
var f:word;
begin
   for f:=1 to num do begin
{       key;}
	 posuv(random(4)+1,false);
{       vykresli_plochu;}
   end;
end;

procedure load_puzzle;
var f,ff:longint;
begin
     pic_num:=max_x*max_y;
     create_handle(handles[1],pic_x*pic_y*pic_num);
     write_palette(blackx,0,256);
     clear_bitmap(screen);
     draw_it(pic_file,1,1);
{     for f:=0 to max_x-1 do begin
	 for ff:=0 to max_y-1 do begin
	     print_normal(screen,posuv_obr_x+f*pic_x,posuv_obr_y+ff*pic_y,chr(f+ff*3+33),15,0);
	 end;
     end;       }
end;

procedure load_buttons;
var f:word;
begin
     create_handle(handles[2],but_x*but_y*num_but_pic);
     create_handle(handles[4],but2_x*but2_y*num_but2_pic);
{     init_grmouse(handles[2]);}
     draw_it(but_file,1,1);
    for f:=0 to num_but_pic-1 do
     getsegxms(handles[2],1,1+but_y*f,but_x,but_y,f);
     draw_it(but2_file,1,1);
    for f:=0 to (num_but2_pic div 2) do begin
     getsegxms(handles[4],but2_x*f+1,1,but2_x,but2_y,f*2);
     getsegxms(handles[4],but2_x*f+1,1+but2_y,but2_x,but2_y,f*2+1);
    end;
end;

procedure load_mys;
var f:word;
begin
     draw_it(m_file,1,1);
     f:=0;
     getseg(1+mpic_y*f,1,mpic_x,mpic_y,f,mys.obr);
end;

procedure init_buttons;
var f,ff:word;
begin
{1}     insert_button(buttons,520,400,but_x,but_y,'Koniec',3,2,15,handles[2],true,1,0);
{2}     insert_button(buttons,520,100,but_x,but_y,'Start',3,2,15,handles[2],true,1,$1f73);
{3}     insert_button(buttons,200,200,but_x,but_y,'Ano',0,2,15,handles[2],true,2,0);
{4}     insert_button(buttons,350,200,but_x,but_y,'Nie',3,2,15,handles[2],true,2,0);
{5}     insert_button(buttons,266,160,but_x,but_y,'Ukoncit ?',1,2,15,handles[2],false,2,0);

{6}     insert_button(buttons,540,200,but2_x,but2_y,'',0,1,15,handles[4],true,1,0);
{7}     insert_button(buttons,540,300,but2_x,but2_y,'',4,5,15,handles[4],true,1,0);
{8}     insert_button(buttons,490,250,but2_x,but2_y,'',6,7,15,handles[4],true,1,0);
{9}     insert_button(buttons,590,250,but2_x,but2_y,'',2,3,15,handles[4],true,1,0);
	  active_floor(buttons,1);
end;

procedure vykresli_plochu;
var f,ff:byte;
begin
     if mys.x<(posuv_obr_x+pic_x*max_x) then begin
	 zhasni_mys(mys);
	 under_mouse:=true;
     end;
     for f:=0 to max_x-1 do begin
	 for ff:=0 to max_y-1 do begin
	   if poradie[f+1,ff+1]<pic_num then putsegxms(handles[1],f*pic_x+posuv_obr_x,ff*pic_y+posuv_obr_y,
								     pic_x,pic_y,poradie[f+1,ff+1]-1)
	   else rectangle2(screen,f*pic_x+posuv_obr_x,ff*pic_y+posuv_obr_y,pic_x,pic_y,prazdne_pole);
	 end;
    clear_key_buffer;
     end;
    print_mouse(buttons,mys);
end;

procedure set_basic_puzzle;
var f,ff:word;
begin
     {vytvori nove poradie}
     for f:=1 to max_x do
	for ff:=1 to max_y do
	   poradie[f,ff]:=ff+(f-1)*max_x;
     kurz.x:=max_x; {nastavi zakladne suradnice}
     kurz.y:=max_y;
end;

procedure init;
var f,ff,fx,fy:word;
    m:word;
begin
     under_mouse:=false;
     keyboard_speed(0,0);
     max_x:=dmax_x;
     max_y:=dmax_y;
     pic_x:=dpic_x;
     pic_y:=dpic_y;
     init_handles(max_handles,handles);
     clear_bitmap(screen);
     fill_palette_black(blackx);
     write_palette(blackx,0,256);
     load_buttons;
     init_buttons;
     load_mys;
     tma:=true;
     font_load_block(main_data,font_file,fx,fy);
     load_puzzle;
{     key;}
     for f:=0 to max_x-1 do begin
	 for ff:=0 to max_y-1 do begin
	     getsegxms(handles[1],ff*pic_x+posuv_obr_x,f*pic_y+posuv_obr_y,pic_x,pic_y,ff*max_x+f);
	 end;
     end;
     clear_bitmap(screen);
     set_basic_puzzle;
     vykresli_plochu;
     write_palette(palx,0,256);
{     key;}
     write_palette(palx,0,256);
{   for f:=1 to 500 do begin}
{     miesaj(2); {zamiesa pozicie}
     restartuj:=false;
     mouseinit(m);
     mousespeed(12,12);
     mousesensitivity(50,50,1);
     mouserange(1,640-mpic_x,1,480-mpic_y);
     mousesetpos(320,240);
     vykresli_plochu;
     print_buttons(buttons,mys);
     mousepos;
     mys.x:=mouse_posx;
     mys.y:=mouse_posy;
     mys.oy:=mys.y;
     mys.ox:=mys.x;
     getseg(mys.x,mys.y,mpic_x,mpic_y,0,mys.poz);
     under_mouse:=true;
{     draw_gif(screen,'red.gif',1,1,palx);}
{   end;}
end;

procedure ending(s:string);
begin
     if xmsinstalled then done_handles(handles);
     if graph_ok then done_graf;
     credits('Puzlik - uder construction');
     if s<>'' then begin
	   textcolor(12);
	   writeln(s);
	   warning;
	   write_error(s);
	   halt(1);
     end
     else halt(0);
end;

procedure run;
var f:word;
begin
  the_end:=false;
  repeat
    print_mouse(buttons,mys);
    mouse_button_press;
     k:=kkey2;
     if k>0 then begin
	 for f:=1 to num_but do
	     if (buttons[f].visible) and (buttons[f].kl=k) then begin
			  if not buttons[f].stav then begin
			   swap_byte(buttons[f].pic,buttons[f].pic2);
			   print_button(buttons,mys,f);
			  end;
			   execute_button(f);
			  if not buttons[f].stav then begin
			   swap_byte(buttons[f].pic,buttons[f].pic2);
			   print_button(buttons,mys,f);
			  end;
	     end;

	 case k of
	    $4800:begin
			  if not buttons[6].stav then begin
			   buttons[6].pic:=1;
			   print_button(buttons,mys,6);
			   posuv(hore,true);
			   buttons[6].pic:=0;
			   print_button(buttons,mys,6);
			  end
			   else posuv(hore,true);
			  end;
	    $4b00:begin
			  if not buttons[8].stav then begin
			   buttons[8].pic:=7;
			   print_button(buttons,mys,8);
			   posuv(vlavo,true);
			   buttons[8].pic:=6;
			   print_button(buttons,mys,8);
			  end
			   else posuv(vlavo,true);
		    end;
	    $4d00:begin
			  if not buttons[9].stav then begin
			   buttons[9].pic:=3;
			   print_button(buttons,mys,9);
			   posuv(vpravo,true);
			   buttons[9].pic:=2;
			   print_button(buttons,mys,9);
			  end
			   else posuv(vpravo,true);
		    end;
	    $5000:begin
			  if not buttons[7].stav then begin
			   buttons[7].pic:=5;
			   print_button(buttons,mys,7);
			   posuv(dole,true);
			   buttons[7].pic:=4;
			   print_button(buttons,mys,7);
			  end
			   else posuv(dole,true);
		    end;
	    $011b:if ano_nie(1) then the_end:=true;
	 end;
     end;
    if restartuj then begin
	 set_basic_puzzle;
     for f:=1 to 10 do begin
	 miesaj(50);
	 vykresli_plochu;
     end;
	 restartuj:=false;
    end;
  until (the_end);
end;

begin
     graph_ok:=false;
     engine_screen(version);
     writeln('Init...');
     for f:=1 to 5 do handles[f].used:=false;
     initclock;
     mys.cas:=getclock;
     write('XMS...');
     if xmsinstalled then begin
		  write_ok;
		  writeln('Version:',xmsversion);
		  writeln('XMS free:',xmfreespace);
		  writeln('XMS contig:',xmcontig);
		  xms_memory:=xmsrequired;
	 {  initxms2;}
		  init_handles(max_handles,handles);
		  XMSDriverCheck;
		  GetXMSFunct;
   end
   else begin
{	writeln(tx[1,24]);}
	ending(tx1[1]);
   end;
     write(dat_file+'..');
     if not subor_exist(main_data) then ending(tx1[2]);
     write_bodka;
     if test_crc(main_data,crc) then ending(tx1[3]);
     write_ok;
     writeln('Graphic...');
     readkey;
     randomize;
     grafika_init(640,480,8);
     graph_ok:=true;
     init;
     clear_key_buffer;
     run;
     ending('');
end.