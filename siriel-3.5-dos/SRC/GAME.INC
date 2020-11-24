procedure pauza;
var f:byte;
begin
   clear_key_buffer;
   f:=15;
   repeat
	inc(f);
	printc(screen,230,tx[ja,7],f,0);
	if f=255 then f:=15;
	repeat
	until getclock>=time;
	time:=time+wait_point+50;
   until keypressed;
   redraw(true);
   k:=0;
end;

procedure padak_init;
begin
 init_charakter(resx,resy,si.x+2,si.y-14,36,39,ar^);
end;

procedure padak_done;
begin
  vypni_charakter(si.x+px,si.y+py,si.buf,ar^);
  vypni_charakter(si.oldx+2,si.oldy-14,39,ar^);
  init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^);
end;

procedure padak(num:word);
begin
  charakter(si.x+2,si.y-14,si.oldx+2,si.oldy-14,36+num,39,ar^);
end;

procedure padak_check;
begin
	if si.y>si.oldy then begin
	    if pad_pol<20 then begin
		inc(pad_pol);
		case pad_pol of
		     19:padak_init;
		     20:padak(1);
		end;
	    end else begin
		padak(2);
	    end;
	end else begin
		if pad_pol>0 then begin
			if pad_pol>18 then padak_done;
			pad_pol:=0;
		end;
	end;
end;

procedure help_in_game;
begin
	decrease_palette(palx,20);
	info;
	decrease_palette(palx,20);
	redraw(true);
	increase_palette(blackx,palx,20);
end;


procedure briefing_in_game;
begin
   if (msg[1]<>'') or (msg[2]<>'') or (msg[3]<>'') or (msg[4]<>'')
	or (msg[5]<>'') then begin
     zhasni;
     briefing;
     zhasni;
     redraw(true);
     rozsviet;
     rewait;
   end;
end;

procedure arcade;
label retry,gotta;
var k2,b,c        : word;
    old5,old7     : boolean;
begin
   same:=0;
   rewait;
   repeat
     retry:
	  if rollup=0 then oldkey:=0;
	k:=0;
	  vypis_skore;
  repeat
  until getclock>=time;
  time:=time+wait_point;
{  k2:=kkey2;}
  sipka_joystick2;
  if keypressed then begin
	k:=key;
      get_keyboard;
	k2:=0;
	case k of
	    $3920,$1c0d:if ((not truth) or(not rolldown)) then begin
				menu;
				if sace then goto gotta;
	    end;
	    $3b00,$2368,$2348:begin
					help_in_game;
					rewait;
		end;
		$3e00,$1970,$1950:begin
					pauza;
		end;
	     $011b:restart:=ano_nie2(tx[ja,13]);
	     $3f00,3062:briefing_in_game;
	     $4800,$4b00,$4d00,$5000,$4700,$4900,$5100,$4f00:k2:=k;
	end;
	k:=0;
    if joystick_able then begin
	 if k2>0 then k:=k2;
	 case k of
		$5000:non_key;
		$4900:begin
			if (rollup=0) and (not rolldown)then rollup:=rolling;
			k:=$4d00;
		end;
		$4700:begin
			if (rollup=0) and (not rolldown)then rollup:=rolling;
			k:=$4b00;
		end;
		$4f00:k:=$4b00;
		$5100:k:=$4d00;
		$4800:begin if (rollup=0) and (not rolldown)then rollup:=rolling;
			k:=0;
		end;
	 end;
	 k2:=0;
    end;
  end;
        old5:=zmack(75);
        old7:=zmack(77);
	  get_keyboard;
	if zmack(75) then begin k:=$4b00; if old7 then key_swap(77,false); end;
	if zmack(77) then begin k:=$4d00; if old5 then key_swap(75,false); end;
	if zmack(80) or zmack(28) or zmack(57)then begin k:=$5000; non_key;end;
	if zmack(60) then k:=$3c00;
	if zmack(61) then k:=$3d00;

    if k>0 then  sipka_fake(k,si.x,si.y);
	  if (zmack(72)) and (rollup=0) and (not rolldown)then begin

	   rollup:=rolling;{k:=$4800;
	   {key_swap(72,false);} end;
	   case k of
	    $4b00:begin if rollup=0 then pl(2) else oldkey:=5; end;
	    $4d00:begin if rollup=0 then pl(3) else oldkey:=6; end;
	    $4b34:oldkey:=5;
	    $7d36:oldkey:=6;
	   end;

     if (rollup>0) then begin
	    dec(rollup);
	    if rollup>gravity then sipka_fake(hore,si.x,si.y);
	  if (smart_jump) and ((rollup<gravity) and (si.y<=si.oldy)) then begin
	     inc(same);
	     if same=1 then begin
		rollup:=0;
		same:=0;
	     end;
	  end;
	  if oldkey<5 then pl(4)
	  else pl(oldkey);
        begin
     	    if si.x<3 then b:=1 else b:=si.x-2;
          if si.y<15 then c:=3 else c:=si.y-14;
          if ((not po3(b,c))or (not po3(si.x+3,c))) then rollup:=0;
        end;
	   {tato cast je doplnena}
     end else same:=0;

     {gravitacia}
     if (po(si.x,si.y)) then truth:=true
     else truth:=false;

     if (truth) and (rollup<gravity-5) and (not lifting) then begin
	 sipka_fake($5000,si.x,si.y);
     end;

     if (po(si.x,si.y)) then rolldown:=true
     else rolldown:=false;

     if (not rolldown) then sipka_fake($4800,si.x,si.y);
     if  (rollup>0) and (k=0) then
	  case oldkey of
		 5:sipka_fake($4b00,si.x,si.y);
		 6:sipka_fake($4d00,si.x,si.y);
	    end;
     if (not po3(si.x-5,si.y-12)) then sipka_fake($4d00,si.x,si.y);
     if (not po3(si.x+6,si.y-12)) then sipka_fake($4b00,si.x,si.y);

  if (rollup=0) and ((not truth) or(not rolldown))
	  and ((k=$4800) or (k=$4b34) or (k=$4d36))then begin
	    rollup:=rolling;
     end;


  if rollup=0 then begin
	   if k=0 then inc(pom)
	   else pom:=0;
	if pom>3 then begin pom:=0; pl(1); end;
  end;
	  if rollup=1 then  begin
	   pom:=4;
	   key_swap(72,false);
	  end;

	   panak;
	   padak_check;
	   si.oldx:=si.x;
	   si.oldy:=si.y;
	   oldpol:=poloha;
	   zisti_vec;
   gotta:
   until (the_koniec) or (restart);
end;

var movx,movy,mova,mavb:word;

procedure maze;
label retry,gotta;
begin
    new(bl);
    ds:=0;
    for f:=0 to mie_x do
	for ff:=0 to mie_y do
		bl^[f,ff]:=false;
    aktivuj_texturu;
    rewait;
    repeat
     retry:
	  if rollup=0 then oldkey:=0;
	k:=0;
	  vypis_skore;
  repeat
  until getclock>=time;
  time:=time+wait_point;
	sipka_joystick;
	if keypressed then begin
		k:=key;
		clear_key_buffer;
	   case k of
	    $4b00:begin pl(2); sipka_fake(k,si.x,si.y); end;
	    $4d00:begin pl(3); sipka_fake(k,si.x,si.y); end;
	    $4800:begin pl(7); sipka_fake(k,si.x,si.y); end;
	    $5000:begin pl(1); sipka_fake(k,si.x,si.y); end;
	    $3b00,$2368:begin help_in_game; rewait; end;
	    $3e00,$1970:pauza;
	    $011b:restart:=ano_nie2(tx[ja,13]);
	    $1c0d,$3920:begin menu; if sace then goto gotta; end;
	    $3f00,3062:briefing_in_game;
	   end;

     if (not po3(si.x-movx,si.y-movy))  or
	  (not po3(si.x+mova,si.y-movy)) or
	  (not po3(si.x-movx,si.y))     or
	  (not po3(si.x+mova,si.y))
	  then sipka_spat(si.x,si.y);

	   aktivuj_texturu;
  end;
	   panak;
	   si.oldx:=si.x;
	   si.oldy:=si.y;
	   oldpol:=poloha;
	   zisti_vec;
   gotta:
   until (the_koniec) or (restart);
   dispose(bl);
   bl:=nil;
end;



procedure briefing;
begin
   if (msg[1]<>'') or (msg[2]<>'') or (msg[3]<>'') or (msg[4]<>'')
	or (msg[5]<>'') then begin
		zhasni;
		clear_bitmap(screen);
		for f:=1 to 5 do
			printc(screen,f*(chardy*2)+150,msg[f],15,0);
		rozsviet;
		clear_key_buffer;
		kkey;
	end;
end;

procedure hra;
label skop,retry;
begin
   if priechody	= nil then new(priechody);
   if lift		= nil then new(lift);
   lifting		  := false;
   pocet_priechodov := 0;
   pocet_vytahov    := 0;
   start_stage      := 1;
   unfreez_sound    := 0;
   ungod_sound      := 0;
   efekt_count      := 0;
   set_def;
   pad_pol:=0;
   clear_all_data;
   start_miestnost:=levely^.lev[old_level].subor;
   st.stav:=1;
   load_predmet2(start_miestnost);
  case st.stav of
	1,3,5:begin
		for f:=1 to nahrane_veci do begin
			    vec^[f].visible:=true;
		end;
	end;
	2,4:begin
		for f:=1 to nahrane_veci do begin
			    vec^[f].visible:=false;
		end;
	end;
  end;

  case st.stav of
	2,3:begin
		 movx:=6;
		 movy:=12;
		 mova:=8;
	    end;
	4,5:begin
		 movx:=6;
		 movy:=6;
		 mova:=0;
	    end;
  end;
   briefing;
   play_ani(flik_start);
   if start_stage>1 then begin
      load_map(start_stage);
      miestnost:=start_stage+126;
   end;
  basic_score:=score;
 if not sace then zivoty:=def_zivoty;
  sace:=false;
  the_koniec:=false;
  restart:=false;
  sprava:=levely^.lev[old_level].meno;
  poloha:=0;
  bloing:=0;
  rollup:=0;
  rolldown:=false;
{  non_key;}
  anim_count:=0;
  decrease_palette(palx,30);
  if start_action>0 then begin
     clear_bitmap(screen);
     pouzi_predmet(0,false);
{     tma:=true;}
{     decrease_palette(palx,30);}
  end else redraw(true);
  init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^);
  redraw_score;
  anim_count:=0;
  reinit(miestnost);
  for f:=1 to pocet_veci do vec^[f].anim:=0;
  reload_sound(5,zvukovy_subor,snd_start);
  pust(5);
  increase_palette(blackx,palx,50);
  play_ball;
  time:=getclock;
  dlzka_padu:=0;
  {tu zacina cyklus -------------------------}
  case st.stav of
	 1:arcade;
	 2,3,4,5:maze;
  end;
	   if (not sace) then begin
		insert_score;
	    decrease_palette(palx,20);
	 end else inc(menu_pointer);
	    if (k=$011b) or (restart) then score:=0;

   if priechody	<> nil then dispose(priechody);
   if lift		<> nil then dispose(lift);
   priechody	:= nil;
   lift		:= nil;
end;

procedure hi_it(var mex:polozk_typ);
begin
   print_zoom_shadow(screen,mex.x,mex.y,mex.meno,12,2,2,3,3,0);
end;

procedure norm_it(var mex:polozk_typ);
begin
   print_zoom_shadow(screen,mex.x,mex.y,mex.meno,9,2,2,3,3,0);
end;


procedure show_intro_page;
var x,y:word;
begin
	    if not handles[1].used then begin
	    clear_bitmap(screen);
		draw_it(intro_obr,0,0);
            set_death_color(13);
		draw_gif_block(screen,input_file,'GLOGO',460,100,palx);
            set_death_color(256);
		save_scr(handles[1],0,0,640,480);
	    end
	    else
		draw_scr(handles[1],0,0,640,480);
	    print_zoom_shadow(screen,250,20,version,14,2,2,3,3,0);
	    print_zoom_shadow(screen,230,60,'DISK: '+meno_disku,11,1,2,3,3,0);

	    me^.pocet:=1;

	with me^.dat[me^.pocet] do begin
	    meno:=tx[ja,10];
	    x:=270;
	    y:=150;
	  k:=$2267;
	  inc(me^.pocet);
	end;
	with me^.dat[me^.pocet] do begin
	  meno:=tx[ja,11];
	  x:=270;
	    y:=185;
	    k:=$1769;
	  inc(me^.pocet);
	end;
	  with me^.dat[me^.pocet] do begin
	    meno:=tx[ja,12];
	  x:=270;
	  y:=220;
	    k:=$2368;
	  inc(me^.pocet);
	end;
 if num_disks>1 then begin
	  with me^.dat[me^.pocet] do begin
	    meno:='DATADISK';
	  x:=270;
	  y:=255;
	    k:=$2064;
	  inc(me^.pocet);
	end;
 end;
	with me^.dat[me^.pocet] do begin
	  meno:=tx[ja,13];
	    x:=280;
	    y:=300;
	  k:=$1071;
	  end;
   for f:=1 to me^.pocet do begin
		norm_it(me^.dat[f]);
	   end;
end;

procedure linew;
var px:byte;
begin
  for px:=0 to 32 do begin
  printx2(screen,31+px*fx,199,' ',0,2,2,1,0);
  printx2(screen,31+px*fx,212,' ',0,2,2,1,0);
  end;
end;

procedure linew2(var posuv,poloha:byte);
begin
  printx2(screen,31,200+posuv,chr(poloha),15,2,2,0,0);
end;

procedure scroll_text;
type ploch=array[0..maxlen] of byte;
var counter,inter,smer:integer;
    plocha:^ploch;
    pch:string;
    sr:searchrec;
    size,f:word;
    posuv,poloha:byte;
begin
 set_font(def_font2);
 linew;
 posuv:=0;
 smer:=1;
 poloha:=1;
  counter:=0;
  new(plocha);
  for f:=0 to maxlen do plocha^[f]:=0;
  if not checkblock_info(zvukovy_subor,scroll_sub) then scroll_sub:=scroll_subor;
  if checkblock_info(zvukovy_subor,scroll_sub) then
     begin
	loadblock_array(zvukovy_subor,scroll_sub,plocha^);
  f:=0;
  repeat
     if plocha^[f]>0 then plocha^[f]:=ord(plocha^[f])+2;
     inc(f);
  until (plocha^[f]=0) or (f>maxlen);
  end
  else begin
	 pch:=tx[ja,14];
	 for f:=0 to length(pch)-1 do begin
	     plocha^[f]:=ord(pch[f+1]);
	 end;
	 size:=length(pch);
  end;
  size:=f;
 if size<maxlen-60 then begin
  for f:=size downto 0 do begin
	plocha^[f+32]:=plocha^[f];
  end;
  inc(size,33);
  for f:=0 to 31 do begin
	plocha^[f]:=ord(' ');
	plocha^[f+size]:=ord(' ');
  end;
  inc(size,32);
 end;
  inter:=0;
  repeat
  pulz(2);
  inc(inter);
  if inter=4 then begin inter:=0; inc(counter);end;
  if counter>size-30 then counter:=0;
  pch:='';
  for f:=1 to 30 do pch:=pch+chr(plocha^[counter+f]);

  posuv:=posuv+smer;
  if (posuv=10) or (posuv=0) then begin
     smer:=-smer;
     inc(poloha);
     if poloha=7 then poloha:=1;
  end;
  printx2(screen,40-inter*2,200+posuv,pch+' ',64,2,2,1,0);
  linew2(posuv,poloha);
   sipka_joystick;
  until keypressed;
{key;}
  clear_key_buffer;
  dispose(plocha);
  set_font(def_font);
end;


procedure info;
begin
  draw_scr(handles[1],0,0,640,480);
  old_frame.draw(125,2,21,6);
  old_frame.draw(125,150,21,6);
  napis.print_col(0,10,tx[ja,15],14);
  napis2.print(0,30,tx3[ja,3]);
  napis2.print(0,50,tx3[ja,4]);
  napis2.print(0,70,tx3[ja,5]);
  napis2.print(0,90,tx3[ja,6]);
  napis.print_col(0,160,'Info:',14);
  napis2.print_col(0,180,'Juraj Mich lek',14);
  napis2.print_col(0,200,'e-mail: georgi@post.sk',9);
  napis2.print_col(0,220,'http://www.geocities.com/Area51/Stargate/3929',11);
  napis2.print(0,235,'Greetings: #o0Zy, RAMbo, TRAMP, Misu, Expa');
  napis2.print(0,248,'Paradion, Mumo, K ');
  set_death_color(13);
  draw_gif_block(screen,input_file,'GLOGO',375,160,palx);
  set_death_color(256);
 reload_sound(3,zvukovy_subor,snd_acces);
  pust(3);
 linew;
 increase_palette(blackx,palx,20);
  clear_key_buffer;
  scroll_text;
  pust(3);
end;


function choice:byte;
var sel:byte;
    first:boolean;
begin
     k:=0;
     si.buf:=sir_buf;
     poloha:=0;
     sel:=1;
     si.x:=me^.dat[sel].x-25;
     si.y:=me^.dat[sel].y+8;
     si.oldx:=si.x;
     si.oldy:=si.y;
     init_charakter(resx,resy,si.x,si.y,0,si.buf,ar^);
     rewait;
 {    putseg2(me^.dat[1].x-10,me^.dat[1].y,16,16,0,13,ar^);}
     first:=false;
     repeat
     si.oldx:=si.x;
     si.oldy:=si.y;
     si.x:=me^.dat[sel].x-25;
     si.y:=me^.dat[sel].y+8;
     clear_key_buffer;
{     repeat}
	     repeat
	     until getclock>=time;
		 time:=getclock+600;
	   inc(poloha);
	 if poloha>35 then poloha:=0;
	 charakter(si.x,si.y,si.oldx,si.oldy,poloha,si.buf,ar^);
	  if not first then begin
		si.oldx:=si.x;
	    si.oldy:=si.y;
	    first:=true;
	    hi_it(me^.dat[sel]);
	  end;
{     until keypressed;}
{       vypni_charakter(si.oldx,si.oldy,si.buf,ar^);}
{  if keypressed then begin}
	  k:=kkey2;
     if k<>0 then begin
     first:=false;
	  clear_key_buffer;
	  norm_it(me^.dat[sel]);
	  case k of
		 $4800,$4b00:if sel>1 then begin pust(0);dec(sel); end;
		 $4d00,$5000:if sel<me^.pocet then begin pust(0);inc(sel); end;
	    end;
		  for f:=1 to me^.pocet do begin {zistuje, ci danemu menu existuje klavesa}
		    if k=me^.dat[f].k then begin
			 sel:=f;
			 k:=$1c0d;
		end;
	    end;
  end;
     until (k=$011b) or (k=$1c0d) or (k=$3920);
  choice:=sel;
  if k=$011b then choice:=0;
  pust(1);
end;

function insert_password(heslo:string):boolean;
var pass:string;
begin
     napis.print(0,400,tx[ja,17]+tx[ja,16]+':');
     napis2.set_color(14);
     pass:=napis2.input(0,420,0,10);
     napis2.set_color(15);
     upcased(pass,pass);
     upcased(heslo,heslo);
     if pass=heslo then begin
	    insert_password:=true;
	    napis2.print_col(0,440,tx[ja,18]+tx[ja,16]+' !',12);
	    pust(0);
          clear_key_buffer;
          pulzx(10);
     end
     else begin
	   insert_password:=false;
	   napis2.print_col(0,440,tx[ja,19]+tx[ja,16]+' !',12);
	   reload_sound(3,zvukovy_subor,snd_strata);
	   pust(3);
          clear_key_buffer;
          pulzx(10);
          key;
     end;
end;


function select_level:byte;
var me2:^jxmenu_typ;
    f:word;
    s:string;
label skup,a_znovu,b_znovu;
begin
   set_defaults;
   skup:
    decrease_palette(palx,10);
   set_def;
   clear_all_data;
   clear_bitmap(screen);
    print_normal(screen,160,380,tx3[ja,7],14,0);
    new(me2);
    init_jxmenu(200,40,0,15,0,'Level',me2^);
     for f:=1 to levely^.pocet do
	     vloz_jxmenu2(levely^.lev[f].meno,me2^,0);

    vloz_jxmenu2('   '+tx[ja,22],me2^,0);
    first_jxmenu(menu_pointer,me2^);
    old_frame.draw(200,40,12,18);
    size_jxmenu(192,288,me2^);
    draw_jxmenu3(me2^);
    increase_palette(blackx,palx,10);
    vyber_jxmenu(me2^,f);
    vybrane:=f;
    menu_pointer:=f;
    old_level:=f;
    dispose(me2);
	     start_miestnost:=levely^.lev[f].subor;
	    if (f<levely^.pocet+1) and (f<>0) then begin
	     load_predmet2(start_miestnost);
		if st.meno[1]='>' then begin
		     s:=st.meno;
		     s:=out_string(s);
		     if insert_password(s) then begin
			  b_znovu:
				 hra;
				  if (sace) and (old_level<>levely^.pocet) then begin
				     inc(old_level);
				     vybrane:=old_level;
				     goto b_znovu;
				  end;
				 goto skup;
		     end
		else begin
		   goto skup;
		end;
	    end  else begin
			 a_znovu:
				  hra;
				  if (sace) and (old_level<>levely^.pocet) then begin
				     inc(old_level);
				     vybrane:=old_level;
				     goto a_znovu;
				  end;
				  goto skup;
			 end;
	     end;
   decrease_palette(palx,20);
	  if sace then begin
	    clear_bitmap(screen);
	    increase_palette(blackx,palx,20);
	     insert_score;
	    select_level:=vybrane;
	   decrease_palette(palx,20);
     end;
	 stop_all_sounds;
end;

procedure out_sounds_to_def;
var f	    : word;
begin
   god_time       :=0;
   freez_time     :=0;
   scan_x1		:=1;
   scan_x2		:=2;
   scan_y1		:=1;
   scan_y2		:=1;
   snd_objav	:=nos;
   snd_start	:=nos;
   snd_strata	:=nos;
   snd_koniec	:=nos;
   snd_credit	:=nos;
   snd_zober	:=nos;
   snd_port		:=nos;
   snd_succes	:=nos;
   snd_acces	:=nos;
   snd_zmizni	:=nos;
   snd_zivot	:=nos;
   snd_score	:=nos;
   snd_appear	:=nos;
   snd_theend	:=nos;
   snd_intro	:=nos;
   snd_fireball	:=nos;
   snd_maze		:=nos;
   snd_fir		:=nos;
   snd_change	:=nos;
   flik_start	:='';
   flik_end		:='';
end;

procedure load_defaults;
begin
   def_freez_time :=freez_time;
   def_god_time   :=god_time;
   dscan_x1		:=scan_x1;
   dscan_x2		:=scan_x2;
   dscan_y1		:=scan_y1;
   dscan_y2		:=scan_y2;
   def_outro_obr	:=outro_obr;
   DEF_POHYBY	:='GZAL';
   def_textura	:=textura;
   def_veci		:=veci;
   def_snd_objav	:=snd_objav;
   def_anim_file	:=anim_file;
   def_snd_start	:=snd_start;
   def_snd_strata	:=snd_strata;
   def_snd_koniec	:=snd_koniec;
   def_snd_credit	:=snd_credit;
   def_snd_zober	:=snd_zober;
   def_snd_port	:=snd_port;
   def_snd_succes	:=snd_succes;
   def_snd_acces	:=snd_acces;
   def_snd_zmizni	:=snd_zmizni;
   def_snd_zivot	:=snd_zivot;
   def_snd_score	:=snd_score;
   def_snd_appear	:=snd_appear;
   def_snd_theend	:=snd_theend;
   def_intro_obr	:=intro_obr;
   def_snd_intro	:=snd_intro;
   def_outro_obr	:=outro_obr;
   def_snd_maze	:=snd_maze;
   def_snd_fireball:=snd_fireball;
   def_snd_fir	:=snd_fir;
   def_snd_change	:=snd_change;
end;

procedure show_hi_score;
var f:word;
    s:string;
begin
 old_frame.draw(180,140,14,10);
 printc(screen,145,tx[ja,12],15,0);
 for f:=1 to 10 do begin
  str(f,s);
  prints(screen,200,143+f*16,2,2,s+'. '+hraci^[f].meno,65+f,0,0);
  str(hraci^[f].score,s);
  prints(screen,350,143+f*16,2,2,s,65+f,0,0);
 end;
 reload_sound(3,zvukovy_subor,snd_acces);
  pust(3);
  clear_key_buffer;
  kkey;
  pust(3);
end;