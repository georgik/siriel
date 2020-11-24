{$m 16384,0,350000}
{$N+,E+,G+,V-}     {qm,pm}
program siriel3;
uses geo,jxgraf,txt,crt,dos,smix,animing,blockx,jxmenu,koder,mouse,
     flik,geo2,crc,jxxms,xms2,aktiv35,jxzvuk,load135,crcr35,jxefekt,
     load235,process,jxvar;

procedure info;forward;
procedure briefing;forward;

{$I POCHECK3.INC}

procedure incsx(plus:word;var pr:predmet;speed:word);
begin
    case plus of
     0:sipka_fake2($4b00,pr.x,pr.y,speed);
     1:sipka_fake2($4d00,pr.x,pr.y,speed);
     2:sipka_fake2($4800,pr.x,pr.y,speed);
     3:sipka_fake2($5000,pr.x,pr.y,speed);
    end;
end;
function gravitacia(var pr:predmet):boolean;
begin
     gravitacia:=false;
     if po3(pr.x+4,pr.y) and po3(pr.x-12,pr.y) then begin
		incsx(3,pr,pr.inf1);
		gravitacia:=true;
     end;
end;

procedure move_to(var pr:predmet);
begin
   if (pr.x<>pr.ox) or (pr.y<>pr.oy) then begin
     putseg(pr.ox,pr.oy,16,16,0,pr.zas);
     getseg(pr.x,pr.y,16,16,0,pr.zas);
     putseg2xms(handles[4],pr.x,pr.y,16,16,pr.obr,13);
   pr.ox:=pr.x;
   pr.oy:=pr.y;
   end;
end;

procedure time_out; {odpocitava cas}
var s:string[20];
    c:byte;
begin
    if timer>0 then begin
	    gettime(tim.h,tim.m,tim.s,tim.o);
	    if (tim.h<>tim2.h) or (tim.m<>tim2.m) or (tim.s<>tim2.s) then begin
			  tim2.h:=tim.h;
			  tim2.m:=tim.m;
			  tim2.s:=tim.s;
			  dec(timer);
			  rectangle2(screen,70,vypisy-26,50,16,0);
			  s:='';
			  str(timer,s);
			  s:=tx[ja,1]+s;
			  if timer<30 then c:=12 else c:=15;
			  print_normal(screen,40,vypisy-26,s,c,0);
			  if timer=0 then begin
					  zivoty:=0;
					  strata_zivota;
			  end;
	    end
    end;
end;

function smeruj(num:word;var step,x,y:word;test_texture:boolean):boolean;    {TRUE ak moze prejst}
var b:boolean;
    x1,y1,x2,y2,x3,y3:word;
begin
     x1:=x;
     y1:=y;
     b:=sipka_fakex(num,step,x1,y1);
     if (not b) and (test_texture) then begin
	 x2:=(x1-6) div 16;
	 y2:=(y1+6) div 16;
	 x3:=(x1+6) div 16;
	 y3:=(y1 div 16)+1;
	 if (st.mie[x2,y2]>inusable) or
	    (st.mie[x2,y3]>inusable) or
	    (st.mie[x3,y2]>inusable) or
	    (st.mie[x3,y3]>inusable) then begin
		    b:=true;
	 end;
     end;
	if not b then begin
		    x:=x1;
		    y:=y1;
	 end;
     smeruj:=b;
end;

procedure zmen_obrazok(f:word);
begin
	vec^[f].inf7:=vec^[f].obr; {zmena obrazka}
	vec^[f].obr:=vec^[f].inf4;
	vec^[f].inf4:=vec^[f].inf7;
	vec^[f].inf7:=0; {anuluj smerovnik}
	if snd_change<>nos then pust(7);
end;

procedure movement(f:byte;var change,from:word); {strelba fireballov}
begin
	 if vec^[f].visible then begin          {dopad fireballu}
		case vec^[f].funk of
		     15:if (snd_fireball<>nos) then pust(4);
		     18:if vec^[f].z2>0 then pust(basic_snd+vec^[f].z2-1);
		end;
{		if ((vec^[f].funk=15) and (snd_fireball<>nos)) then pust(4);}
		putseg(vec^[f].x,vec^[f].y,resx,resy,0,vec^[f].zas);
		vec^[f].visible:=false;
            vec^[f].change:=true;
		inc(vec^[f].x);
		vec^[f].x:=640;
	 end;
	 inc(vec^[f].inf5);                       {vystrel fireballu}
	 if vec^[f].inf5>=vec^[f].inf4 then begin
		case vec^[f].funk of
		     15:if (snd_fir<>nos) then pust(6);
		     18:pust_extra(vec^[f].z1);
		end;
{		if (vec^[f].funk=15) and (snd_fir<>nos) then pust(6);}
	    vec^[f].inf5:=0;
	    change:=from;
	    vec^[f].visible:=true;
	    vec^[f].x:=vec^[f].oox;
	    vec^[f].y:=vec^[f].ooy;
	    vec^[f].ox:=vec^[f].x;
	    vec^[f].oy:=vec^[f].y;
	    getseg(vec^[f].x,vec^[f].y,resx,resy,0,vec^[f].zas);
	end;
end;

procedure freezing; {kontroluje mrazak}
var f     : word;
begin
   if (freez_time>0) and (freez_time<255) then begin
      dec(freez_time);
      if freez_time=0 then pust_extra(unfreez_sound) else begin
         for f:=0 to freez_time do lajna[f]:=149+(f mod 10);
         for f:=freez_time to 250 do lajna[f]:=1;
         help_line1;
      end;
   end;
   if (god_time>0) and (god_time<255) then begin
      dec(god_time);
      if god_time=0  then pust_extra(ungod_sound) else begin
         for f:=250 downto 250-god_time do lajna[f]:=198+(f mod 10);
         for f:=250-god_time downto 0 do lajna[f]:=197;
         help_line2;
      end;
   end;
end;

procedure panak;    {jadro osetujuce pohyby priser}
begin
 shut_down_siriel:=false;
 time_out;
 inc(anim_count);
 charakter(si.x+px,si.y+py,si.oldx+px,si.oldy+py,poloha,si.buf,ar^);

 if (anim_count=4) or (anim_count=2)then begin
    freezing;
    inc(bloing);
    if bloing>=4 then bloing:=0;
    if (anim_count=4) then begin anim_count:=0;
	 inc(anic);
	 if (anim_count=0) then
	    if anic>=4 then anic:=0;
    end;

    for f:=1 to nahrane_veci do begin
     if (vec^[f].mie=miestnost) and ((freez_time=0) or
        ((freez_time>0) and (vec^[f].meno[3]<>'S')))then begin
	 if (vec^[f].meno[2]='A') or (((vec^[f].meno[1]<>'W') and(vec^[f].meno[1]<>'V'))
	    and (vec^[f].funk>0)) then begin
	    case vec^[f].funk of
		17: begin      {zvukar}
		    inc(vec^[f].inf5);
		    if vec^[f].inf6=0 then begin
			 if vec^[f].inf5>vec^[f].inf2 then begin
			{    if (freez_time=0) or
                       ((freez_time>0) and (vec^[f].meno[3]<>'S')) then }pust_extra(vec^[f].inf1);
			    vec^[f].inf6:=1;
			    vec^[f].inf5:=0;
			 end;
		    end else begin
			 if vec^[f].inf5>vec^[f].inf4 then begin
		     {	    if (freez_time=0) or
                       ((freez_time>0) and (vec^[f].meno[3]<>'S')) then }pust_extra(vec^[f].inf3);
			    vec^[f].inf6:=0;
			    vec^[f].inf5:=0;
			 end;
		    end;
		end;
		16:begin  {nahanacka}
			inc(vec^[f].inf6);
			if vec^[f].inf5=0 then begin {pasivny mod}
			   if (vec^[f].inf6>=vec^[f].inf2) and (vec^[f].inf3>0) then begin   {doslo k zmene}
				vec^[f].inf5:=1;
				vec^[f].inf6:=0;
				zmen_obrazok(f);
			   end else begin 	{ak nedoslo k zmene na aktivny mod}
				if vec^[f].inf7=0 then vec^[f].inf7:=random(4)+1;
				case vec^[f].inf7 of  {testuje posuv}
				   1:if smeruj(hore,vec^[f].inf1,vec^[f].x,vec^[f].y,true) then vec^[f].inf7:=0;
				   2:if smeruj(dole,vec^[f].inf1,vec^[f].x,vec^[f].y,true) then vec^[f].inf7:=0;
				   3:begin vec^[f].smer:=true; if smeruj(vlavo,vec^[f].inf1,vec^[f].x,vec^[f].y,true) then vec^[f].inf7:=0; end;
				   4:begin vec^[f].smer:=false; if smeruj(vpravo,vec^[f].inf1,vec^[f].x,vec^[f].y,true) then vec^[f].inf7:=0; end;
				end;
			   end;
			end else begin  {aktivny mod inf5=1}
			   if (vec^[f].inf6>=vec^[f].inf3) and (vec^[f].inf2>0) then begin   {doslo k zmene}
				vec^[f].inf5:=0;
				vec^[f].inf6:=0;
				zmen_obrazok(f);
			   end else begin 	{ak nedoslo k zmene na pasivny mod}
				if vec^[f].x>si.x then begin vec^[f].smer:=true; smeruj(vlavo,vec^[f].inf1,vec^[f].x,vec^[f].y,true); end;
				if vec^[f].y>si.y then smeruj(hore,vec^[f].inf1,vec^[f].x,vec^[f].y,true);
				if vec^[f].x<si.x then begin vec^[f].smer:=false; smeruj(vpravo,vec^[f].inf1,vec^[f].x,vec^[f].y,true); end;
				if vec^[f].y<si.y then smeruj(dole,vec^[f].inf1,vec^[f].x,vec^[f].y,true);
			   end;
			end;
		end;
		12:begin       {nahodne pohyblivy}
		   case vec^[f].inf3 of  {zabezpecuje pohyb}
			0:begin  {vlavo}
			  sipka_fakex($4b00,vec^[f].inf2,vec^[f].x,vec^[f].y);
			  vec^[f].smer:=true;
			  {vec^[f].inf7:=0;    {riadi otocenie priserky}
			end;
			1:begin  {vpravo}       {reakcia na textury}
			  sipka_fakex($4D00,vec^[f].inf2,vec^[f].x,vec^[f].y);
			  vec^[f].smer:=false;
			  {vec^[f].inf7:=1;    {riadi otocenie priserky}
			end;
			2:sipka_fakex($5000,vec^[f].inf2,vec^[f].x,vec^[f].y); {dole}
			3:sipka_fakex($4800,vec^[f].inf2,vec^[f].x,vec^[f].y); {hore}
		   end;
		   dec(vec^[f].inf4,vec^[f].inf2);
		   case vec^[f].inf1 of
		     0:if (vec^[f].x>598) or (vec^[f].x<10) or
			    (vec^[f].y<10)  or (vec^[f].y>392) or
			    (vec^[f].inf4<4) then begin
				if vec^[f].x>598 then vec^[f].x:=598;
				if vec^[f].x<10 then vec^[f].x:=10;
				if vec^[f].y>392 then vec^[f].y:=392;
				if vec^[f].y<10 then vec^[f].y:=10;
				vec^[f].inf3:=random(4);
				vec^[f].inf4:=random(200)+20;
			  end;
		     1:if (vec^[f].x>598) or (vec^[f].x<10) or
			    (vec^[f].y<10)  or (vec^[f].y>392) or
			    (vec^[f].inf4<4) or
			    (st.mie[((vec^[f].x-6) div 16),((vec^[f].y) div 16)]>inusable) or
			    (st.mie[((vec^[f].x+6) div 16),((vec^[f].y+13) div 16)]>inusable)
			    then begin
				case vec^[f].inf3 of
				  0:begin
				     inc(vec^[f].x);
				     sipka_fakex($4D00,vec^[f].inf2,vec^[f].x,vec^[f].y);
				  end;
				  1:begin
				     dec(vec^[f].x);
				     sipka_fakex($4B00,vec^[f].inf2,vec^[f].x,vec^[f].y);
				  end;
				  2:begin
				     dec(vec^[f].y);
				     sipka_fakex($4800,vec^[f].inf2,vec^[f].x,vec^[f].y);
				  end;
				  3:begin
				     inc(vec^[f].y);
				     sipka_fakex($5000,vec^[f].inf2,vec^[f].x,vec^[f].y);
				  end;
				end;
				vec^[f].inf5:=vec^[f].inf3;
				repeat
				  vec^[f].inf3:=random(4);
				until (vec^[f].inf3<>vec^[f].inf5);
				vec^[f].inf4:=random(200);
			 end; {koniec 1}
		    end; 	{koniec case}
		  end;      {koniec 12}
		  2:begin
		     if vec^[f].inf1>vec^[f].x then vec^[f].smer:=false;{vec^[f].inf7:=1;}
		     if vec^[f].inf2<vec^[f].x then vec^[f].smer:=true;{vec^[f].inf7:=0;}
		     if vec^[f].smer then incsx({vec^[f].inf7}0,vec^[f],vec^[f].inf3) else
			  incsx({vec^[f].inf7}1,vec^[f],vec^[f].inf3);
		  end;
		  3:begin
		     if vec^[f].inf1>vec^[f].y then {vec^[f].smer:=false;}vec^[f].inf7:=1;
		     if vec^[f].inf2<vec^[f].y then {vec^[f].smer:=true;}vec^[f].inf7:=0;
		     incsx(vec^[f].inf7+2,vec^[f],vec^[f].inf3);
{		     if vec^[f].smer then incsx(vec^[f].inf70,vec^[f],vec^[f].inf3) else
			  incsx({vec^[f].inf71,vec^[f],vec^[f].inf3);}
		  end;
		  4:begin
		     if not gravitacia(vec^[f]) then begin
			  if (po3(vec^[f].x+4,vec^[f].y-12)) and
			     (po3(vec^[f].x-12,vec^[f].y-12)) then begin
				 if vec^[f].smer then sipx:=vlavo else sipx:=vpravo;
				 if not sipka_fake2(sipx,vec^[f].x,vec^[f].y,vec^[f].inf1) then begin
				    vec^[f].x:=vec^[f].inf5;
				    vec^[f].y:=vec^[f].inf6;
				 end else gravitacia(vec^[f])
			  end else begin
			    vec^[f].x:=vec^[f].inf5;
			    vec^[f].y:=vec^[f].inf6;
			  end;
		     end;
		  end;
		  5:begin
		     if not gravitacia(vec^[f]) then begin
			  if not(po3(vec^[f].x-11,vec^[f].y-3)) then vec^[f].smer:=false{vec^[f].inf7:=1} else
			   if not(po3(vec^[f].x+3,vec^[f].y-3)) then vec^[f].smer:=true;{vec^[f].inf7:=0;}
			  if vec^[f].smer then sipx:=vlavo else sipx:=vpravo;
			  if not sipka_fake2(sipx,vec^[f].x,vec^[f].y,vec^[f].inf1) then begin
			     vec^[f].x:=vec^[f].inf5;
			     vec^[f].y:=vec^[f].inf6;
			  end else gravitacia(vec^[f]);
		     end;
		  end;
		  15,18:begin   {FIREBALL}
			case vec^[f].inf1 of
			  1:if vec^[f].x<vec^[f].inf2 then inc(vec^[f].x,vec^[f].inf3)
			     else begin
				 movement(f,vec^[f].x,vec^[f].oox);
			     end;
			  2:if vec^[f].x>vec^[f].inf2 then dec(vec^[f].x,vec^[f].inf3)
			     else begin
				 movement(f,vec^[f].x,vec^[f].oox);
			     end;
			  3:if vec^[f].y<vec^[f].inf2 then inc(vec^[f].y,vec^[f].inf3)
			     else begin
				 movement(f,vec^[f].y,vec^[f].ooy);
			     end;
			  4:if vec^[f].y>vec^[f].inf2 then dec(vec^[f].y,vec^[f].inf3)
			     else begin
				 movement(f,vec^[f].y,vec^[f].ooy);
			     end;
			end;
		  end;
	    end;
	  end;
     end;
  end;
end;

 if ((anim_count=0) or (anim_count=2)){ and ((vec^[f].meno[2]='A') or (vec^[f].meno[1]='Z'))}
    then begin

    {skontroluje, ci doslo k zmene}
    for f:=1 to nahrane_veci do
     if ((vec^[f].ox<>vec^[f].x) or (vec^[f].oy<>vec^[f].y))
	 {  and (vec^[f].visible)} then
	   vec^[f].change:=true else vec^[f].change:=false;

    check_visible(true);

   for f:=1 to nahrane_veci do begin {zisti, ci sa v okoli Siriela nachaddza
							predmet s ktorym sa prektyva}
    if (vec^[f].mie=miestnost) and
        ((vec^[f].change) or (vec^[f].meno[2]='A'))
	  and (vec^[f].x>si.x-24) and (vec^[f].x<si.x+36)
	  and (vec^[f].y>si.y-24) and (vec^[f].y<si.y+36) then begin
	   shut_down_siriel:=true;
	   vypni_charakter(si.x+px,si.y+py,si.buf,ar^);
	   break;
    end;
   end;
   if freez_time=0 then process_all(shut_down_siriel)
      else process_all2(shut_down_siriel);
  end;
       if (god_time>0) then begin
           putseg2(si.x+px,si.y+py,resx,resy,47+efekt_count,13,ar^);
           case anim_count of
            1: begin
                  inc(efekt_count);
                  if efekt_count>3 then efekt_count:=0;
            end;
           end;
       end;
end;

procedure reinit(miest:integer);
begin
     clear_key_buffer;
     ani:=0;
end;

{$I DRAW35.INC}

procedure smer(miex:integer);
begin
	    redraw2;
		reinit(miestnost);
end;

function chuck:boolean;
begin
 chuck:=true;
 if mov>0 then
    if vec^[mov].take<>1 then chuck:=false;
end;

function chuck2:boolean;
begin
 chuck2:=true;
 if mov>0 then begin
    if vec^[mov].take>1 then chuck2:=false;
 end;
end;

var cool:integer;


{-----------------}
{$I MENU35.INC}

{$I PREMEN35.INC}


{Jadro programu !!! Waranty void if removed !!!}
{$I GAME.INC}



{vyber datadisk}
procedure select_datadisk;
var mex:^jxmenu_typ;
    f,vybr,fl,ff:word;
    fatal:boolean;
label znovku;
begin
   fatal:=false;
   write_palette(blackx,0,256);
   clear_bitmap(screen);
   new(mex);
znovku:
   clear_bitmap(screen);
    init_jxmenu(200,40,0,15,0,tx2[ja,2],mex^);
    for f:=1 to num_disks do begin
	    diskd.meno:='';
	    for ff:=f to num_disks do begin
		    if diskd.meno<data_disks^[ff].meno then begin
			  diskd.meno:=data_disks^[ff].meno;
			  fl:=ff;
		    end;
	    end;
			  diskd:=data_disks^[f];
			  data_disks^[f]:=data_disks^[fl];
			  data_disks^[fl]:=diskd;
    end;
    {swapne to}
    for f:=1 to num_disks div 2 do begin
			  diskd:=data_disks^[f];
			  data_disks^[f]:=data_disks^[num_disks-f+1];
			  data_disks^[num_disks-f+1]:=diskd;
    end;
    for f:=1 to num_disks do begin
		    if data_disks<>nil then
		     vloz_jxmenu2(data_disks^[f].meno,mex^,0);
    end;
     vloz_jxmenu2(tx[ja,6],mex^,0);
  if num_disks>1 then begin
{     increase_palette(blackx,palx,10);}
     old_frame.draw(200,40,12,2+num_disks);
     size_jxmenu(192,288,mex^);
     draw_jxmenu3(mex^);
     write_palette(palx,0,256);
     vyber_jxmenu(mex^,vybr);
  end
  else vybr:=1;
    if (vybr=mex^.pocet) or (vybr=0) then ending('')
    else
    if vybr<mex^.pocet then begin
		zvukovy_subor:=data_disks^[vybr].subor;
		meno_disku:=data_disks^[vybr].meno;
    end;
   if data_disks^[vybr].verzia>ver then begin
	    printc(screen,440,tx3[ja,1],12,0);
	    clear_key_buffer;
	    kkey;
     if num_disks=1 then fatal:=true else
	    goto znovku
   end;
   dispose(mex);
   if fatal then ending('');
end;

{nacita zoznam datadiskov}
procedure load_basic_config;
type polo=array[0..maxlen] of byte;
var pole:^polo;
    f,countx:word;
begin
     set_def;
     new(pole);
     new(data_disks);
		for f:=1 to maxlen do pole^[f]:=0;
		num_disks:=0;
		findfirst('*.dat',$3f,sr);
		repeat
				  if (doserror=0) and (checkblock_info(sr.name,hlavicka)) then begin
					   loadblock_array(sr.name,hlavicka,block_ver);
					   inc(num_disks);
					   for f:=0 to 2 do block_ver[f]:=block_ver[f]-48;
					   data_disks^[num_disks].verzia:=block_ver[0]*100+
								 block_ver[1]*10+block_ver[2];

					   data_disks^[num_disks].subor:=sr.name;
					   data_disks^[num_disks].meno:='';
					   load_level_list(sr.name,pole^);
				  end;
				  findnext(sr);
		until (doserror<>0) or (num_disks>19);
		 if num_disks=0 then errormes(3);
		 select_datadisk;
		 load_level_list(zvukovy_subor,pole^);
		 load_defaults;
     dispose(data_disks);
     dispose(pole);
     if crc_checking then verify_crc(zvukovy_subor);
end;

procedure ppoint;
begin
 write('.');
end;

procedure load_pohyby;
begin
   draw_gif_block(screen,input_file,pohyby,0,0,palx);
    for f:=0 to 11 do
		    getseg(f*resx,0,resx,resy,f,ar^);
    for f:=0 to 7 do begin
		getseg(f*resx,16,resx,resy,f+12,ar^);
		getseg(f*resx,32,resx,resy,f+20,ar^);
		getseg(f*resx,48,resx,resy,f+28,ar^);
    end;
    for f:=0 to 2 do begin
		getseg(f*resx+128,16,resx,resy,f+36,ar^);
    end;
    for f:=0 to 3 do begin
		getseg(f*resx+128,32,resx,resy,f+40,ar^);
    end;
    for f:=0 to 1 do begin
		getseg(f*resx+128,48,resx,resy,f+44,ar^);
    end;
    for f:=0 to 3 do begin
		getseg(f*resx+160,48,resx,resy,f+47,ar^);
    end;
end;

{skontroluje crc v subore MAIN.DAT}
procedure check_crc;
begin
    if subor_crc(input_file)>0 then
    errormes(1);
end;

{------ inicializacia premennych a menu -----}
var fil:file;
    bolx:boolean;
    fl:word;
    test_menu:^jxmenu_typ;

label skip,fatal_restart,reskip;

begin
   inicializacna_pauza:=inicializacny_cas;
   clrscr;
   textbackground(12);
    clreol;
    textcolor(15);
    gotoxy(35,1);
    writeln(version);
   textbackground(0);
   if not subor_exist(cfg_file) then ending(tx3[1,9]);
   ja:=1;
   test:=false;
   miestn:='';
 if paramcount>0 then begin
    s:='';
    for fl:=1 to paramcount do s:=s+paramstr(fl);
    upcased(s,s);
    if s[1]='/' then begin
	     case s[2] of
			  'T':test:=true;
	     end;
    end;
 if (s<>'/T') then writeln(tx2[ja,3]);
 end;

if not subor_exist(input_file) then ending(tx3[ja,2]);
if memavail>minimummem then begin
   writeln;
   writeln('Init...');
     use_joystick:=false;
     initclock;
     randomize;
     init_keyboard(0);
     keyboard_speed(0,0);
     set_def;
     zvuk_loaded:=false;
     crc_checking:=true;
     set_defaults;  {nastavi zakladne parametre prikazoveho modu W}
     scrx:=640;
     scry:=480;
     resx:=16;
     resy:=16;
   check_crc;      {kontorla CRC pre MIAN.DAT}
   new(hraci);
   for f:=1 to 10 do begin
		 hraci^[f].meno:=anonymous;
		 hraci^[f].score:=0;
   end;
   if subor_exist(score_sub) then begin
		assign(fil,score_sub);
		reset(fil,1);
		for f:=1 to 10 do begin
			  blockread(fil,hraci^[f],sizeof(hraci^[f]));
		end;
		close(fil);
   end;
   write('XMS...');
   if xmsinstalled then begin
	  writeln(tx[1,23]);
	  writeln('Version:',xmsversion);
	  writeln('XMS free:',xmfreespace);
	  writeln('XMS contig:',xmcontig);
	  xms_memory:=xmsrequired;
	  init_handles(max_handles,handles);
	    XMSDriverCheck;
	    GetXMSFunct;
   end
   else begin
	writeln(tx[1,24]);
	ending('Use HIMEM.SYS or other memory drivers !');
   end;
   write('Checking access...');
     block_ctrl_break;
   writeln('O.K.');
   write('Locating memory:');
   priechody	:=nil;
   lift		:=nil;
   ppoint;
   new(ar);
   ppoint;
   new(te);
   ppoint;
   new(vec);
   ppoint;
   new(anim);
   ppoint;
   new(levely);
   ppoint;
{   if handles[1].used then warning;}
   create_handle(handles[3],21*pocet_veci+pocet_textov*dlzka_textu
			 +pocet_obr*dlzka_obr);
   ppoint;
   create_handle(handles[4],256*vec_count);
   ppoint;
   create_handle(handles[5],map_size);
   writeln('O.K.');
    automatic:=true;
    sounds_loaded:=false;
   write('Reading siriel3.cfg...');
    load_config;
    scrx:=2;
   writeln(' O.K.');
  if zvuk then begin
   write('Please wait, initializing SFX...');
   time:=getclock+inicializacna_pauza;
   repeat
   until getclock>time;
   write_ok;
  end;
  if zvuk then Initsbx;
   grafika_init(scrx,scry,8);
    write_palette(blackx,0,256);
    old_frame.init(no_handle,input_file,frame_gif,false);
    napis.init(2,2,15,0,0,true,true);
    napis2.init(2,2,15,0,0,true,false);
    aktivita_snd:=false;
    animabl:=false;
    check_sound:=false;
    set_font(def_font);
{    out_sounds_to_def;
   zvuk_loaded:=false;}

  fatal_restart:
    set_numsounds(num_snd);
    font:=def_font;
    out_sounds_to_def;
    load_defaults;
    set_def;
    bolx:=false;
    smart_jump:=true;              {SKOK}
   write_palette(blackx,0,256);
   load_pohyby;
   load_basic_config;
   if (zvuk) and (not zvuk_loaded) then begin
    LoadSounds;
    Stop := false;
    Rate := 11111;
    sounds_loaded:=true;
    setsamplingrate(rate);
    zvuk_loaded:=true;
   end;
   zvuky[1]:=snd_credit;
   zvuky[2]:=snd_zober;
   zvuky[3]:=snd_port;
   zvuky[4]:=nos;    {aktivne medzi efekty}
   zvuky[5]:=snd_fireball;
   zvuky[6]:=nos;    {hudba na zaciatku}
   zvuky[7]:=snd_fir;
   zvuky[8]:=snd_change;
   if zvuk_loaded then begin
	for f:=1 to num_snd do
	    reload_sound(f-1,zvukovy_subor,zvuky[f]);
   end;
   rerun;
   write_palette(blackx,0,256);
   tma:=true;

{nahra animovane obrazky}
draw_it(anim_file,0,0);
for ff:=0 to 3 do
 for f:=0 to 19 do begin
   getseg(16*f,ff*16,16,16,f+ff*20,anim^);
 end;

   score:=0;
   basic_score:=0;
   gravity:=20;
   rolling:=30;
   write_palette(blackx,0,256);
   restart:=false;
   load_predmet;
   load_anim_def;
   load_texture;
   clear_bitmap(screen);

{   editor:=true;}
{    test:=true;}

  if aktivita_snd then begin
   sounds_loaded:=true;
  end;
   sipka_limit(8,9,612,398,4,use_joystick,5,false,false,true,true);
   if use_joystick then joystick_kaliber;
   oldpol:=poloha;
{   write_palette(palx,0,256);}
reskip:

if not test then begin
   zivoty:=0;
   selector:=0;
 skip:
   set_def;
   new(me);
   show_intro_page;
   reload_sound(5,zvukovy_subor,snd_intro);
   pust(5);
   increase_palette(blackx,palx,50);
   selector:=choice;
   dispose(me);
   case selector of
		    0,5:ending('');
		    1:begin menu_pointer:=1; select_level; goto skip; end;
		    2:begin info; goto skip; end;
		    3:begin show_hi_score; goto skip; end;
		    4:if num_disks=1 then ending('')
				 else begin
					stop_all_sounds;
					kill_handle(handles[1]);
					goto fatal_restart;
				 end;
   end;
   if (selector<>0) and (selector<>4) then begin goto skip; end;
end
 else begin           {TESTOVANIE LEVELOV}
	    findfirst('*.mie',$3f,sr);
     if doserror=0 then begin
	    levely^.pocet:=0;
	    new(test_menu);
   increase_palette(blackx,palx,10);
   init_jxmenu(200,40,15,12,0,'Testing',test_menu^);
     repeat
		inc(levely^.pocet);
		levely^.lev[levely^.pocet].subor:=sr.name;
		vloz_jxmenu2(sr.name,test_menu^,0);
		findnext(sr);
	    until doserror<>0;
	    vyber_jxmenu(test_menu^,old_level);
	    dispose(test_menu);
	    if old_level>0 then hra;
   end;
	    ending('');
 end;
end
else begin           {CHYBOVE HLASENIE PRI NEDOSTATKU PAMATE}
     write_error('Not enought memory.');
     writeln;
     writeln('There are only ',memavail,' b of memory free ! I need ',minimummem,' b ! :-(');
     textcolor(143);
     gotoxy(10,10);
     writeln('>> Press any key <<');
     textcolor(7);
     kkey;
     credits(version);
end;
end.
