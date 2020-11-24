var
    palette_speed	: byte; {definuje rychlost rozsvecovania a zhasinania}
    text_y		: word; {suradnice textu}
    text_x		: word; {suradnice textu}
    No_line		: word; {medzera medzi dvoma riadkami}
    text_col	: word; {farba textu}
    automatic	: boolean;  {automaticky reset default hodnot}
    center		: boolean;     {vypisuje do stredu}
    pic_x,pic_y	: word;   {suradnice obrazkov}
    lajn		: word;
 {DEFAULT HODNOTY}

procedure wait_for_key;        {caka na klaves}
begin
	   clear_key_buffer;
	   kkey;
end;

procedure new_screen;
begin
			 decrease_palette(palx,palette_speed);
			 redraw(true);
			 increase_palette(blackx,palx,palette_speed);
end;


procedure set_defaults;
begin
  palette_speed	:= 30;
  text_y		:= 150;
  no_line		:= 32;
  automatic		:= true;
  text_x		:= 100;
  pic_x		:= 50;
  pic_y		:= 50;
end;

procedure cls;
begin
  decrease_palette(palx,palette_speed);
  clear_bitmap(screen);
  lajn:=0;
end;

function pouzi_predmet(num:word;typ:boolean):boolean;
const num_prikazy=73;
	  prikazy:array[1..num_prikazy] of string[10]=
	  ('SOUND','ANIM','CLS','SCROFF','SCRON','REDRAW','ANIMONLY',
	   'DRAWINTRO','KEY','SETDEF','AUTODEF','TEXT_Y','NO_LINE',
	   'TEXTCOL','REINIT','P','TEXT_X','CENTER','STAGE',
	   'SHOWSIR','SHOWCHAT','SETPIC','NEWSCR','PIC','UNHIDE',
	   'SCORE','END','GOTO','SETNEW','RESET','SETOTNEW',
	   'NEWTEX','LOADMAP','SAVEMAP','SIRXY','HIDE','GOMAP',
	   'IFPOCKET','TAKEPOCKET','GIVEPOCKET','SETEVENT',
	   'INCEVENT','DECEVENT','IFEVENT','LOEVENT','HIEVENT',
	   'DONTUSE','USE','DRAWGIF','THEEND','LOSELIFE','GAINLIFE',
	   'FONT','DEFFONT','SETBACKGIF','DRAWGIFNUM','SCAN',
	   'SETWAY','SETLIFT','SPEEDLIFT','WAYLIFT','SETANIM',
	   'SETOBR','PULZX','FASTDRAW','SETFREEZ','SETGOD',
         'SHADOW','SHADOWCOL','FRAME','FRAME2','FRAMEPIC',
         'REINIT2');
	  {1.SOUND                - prehra zvuk
	   2.ANIM                 - prehra animaciu a nakresli znova miestnost
	   3.CLS                  - zhasne a zmaze obrazovku
	   4.SCROFF               - zhasne obrazovku
	   5.SCRON                - rozsvieti obrazovku
	   6.REDRAW               - prekresli obrazovku
	   7.ANIMONLY             - prehra animaciu
	   8.DRAWINTRO            - vykresli introobrazovku
	   9.KEY                  - caka na klaves
	  10.SETDEF               - nastavy default hodnoty
	  11.AUTODEF              - zapne/vypne automaticky reset hodnot (Y/N)
	  12.TEXT_Y               - zaciatocna suradnica vypisu textu
	  13.NO_LINE              - prazdny priestor medzi riadkami
	  14.TEXTCOL              - nova farba textu
	  15.REINIT               - caka na klaves a prekresli obrazovku
	  16.P                    - novy riadok
	  17.TEXT_X               - suradnica textu
	  18.CENTER               - centruje text (Y/N)
	  19.STAGE                - presunie do novej miestnosti (CISLO,X,Y)
	  20.SHOWSIR              - ukaze SIRIELA
	  21.SHOWCHAT             - ukaze Chater (kecajuceho)
	  22.SETPIC               - nastavy suradnica, kde sa budu obazaky objavovat(X,Y)
	  23.NEWSCR               - caka na klaves a prevedie CLS
	  24.PIC                  - vykresli na aktualnu suradnicu obrazok z VECI
	  25.UNHIDE               - odkryje vec v urcenej miestnosti (KDE/UROVEN)
	  26.SCORE                - prida urceny pocet bodov
	  27.END                  - koniec prikazoveho modu
	  28.GOTO                 - skok na cislo textu
	  29.SETNEW               - nastavy inf7 na nove miesto
	  30.RESET                - nastavy novy inf7 a preskoci nan
	  31.SETOTNEW             - nastavy veci majuce meno[5] zhodne s pozadovanym
					    na dany parameter
	  32.NEWTEXT              - nastavy novu texturu v (X1,Y1,X2,Y2,TEX)
	  33.LOADMAP              - namiesto aktualnej mapy nahra (NUM) a ulozi
	  34.SAVEMAP              - ulozi aktualnu mapu na (NUM)
	  35.SIRXY                - nastavy suranice siriela
	  36.HIDE         	  - skryje predmet do miestnosti, ak ma na 5 znaku rovnake
	  37.GOMAP                - skoci na novu mapu pricom staru ulozi
	  38.IFPOCKET		  - ak ma vo vrecku vec s popisnym cislom, skoci na inu urovnem
	  39.TAKEPOCKET		  - ak ma vo vrecku predmet s popisnym cielom, presunie ho do cielovej miestnosti
	  40.GIVEPOCKET		  - vlozi do vrecka predmet s popisnym cislom
	  41.SETEVENT		  - nastavy poz. dej na hodnotu
	  42.INCEVENT		  - zvacsi poz. dej
	  43.DECEVENT		  - zmensi poz. dej
	  44.IFEVENT		  - ak ma poz. dej hodnotu, skoci na text (D,H,T)
	  45.LOEVENT		  - ak ma poz. dej mensiu hodnotu -//-
	  46.HIEVENT		  - ak ma poz. dej vacsiu hodnotu -//-
	  47.DONTUSE		  - nepokladaj predmet
	  48.USE			  - polozi predmet (nastavene ako DEFAULT)
	  49.DRAWGIF		  - vykresli GIF na suradnice X,y
	  50.THEEND			  - ukonci level
	  51.LOSELIFE		  - strati zivot
	  52.GAINLIFE		  - prida zivot   (N)
	  53.FONT			  - nastavi novy font
	  54.DEFFONT		  - vrati povodny font
	  55.SETBACKGIF		  - nastavi v miestnosti nove pozadie - MIESTN, MENO, X, Y
	  56.DRAWGIFNUM		  - nakresli obrazok zadefinovany ako OBR - CISLO OBR
	  57.SCAN			  - nastavi novy sken rozsah - X1,X2,Y1,Y2
	  58.SETWAY			  - nastavy ci ma priechod pouzit - NUM,Y/N
	  59.SETLIFT		  - nastavy existenciu vytahu - NUM,Y/N
	  60.SPEEDLIFT		  - rychlost vytahu
	  61.WAYLIFT		  - smer vytahu
	  62.SETANIM		  - nastavi animaciu - ZNAK,Y/N
	  63.SETOBR			  - nastavi obrazok predmetu - ZNAK,PICNUM
	  64.PULZX                - caka 2 pulzy
	  65.FASTDRAW		  - rychle presli obrazovky
        66.SETFREEZ             - zmrazenie postav - CAS,UNzvuk
        67.SETGOD               - god mod - CAS,UNzvuk
        68.SHADOW               - nastavy tien - YES
        69.SHADOWCOL            - nastavy farbu tiena - COL
        70.FRAME                - nakresli okno
        71.FRAME2               - vypise okno - NADPIS
        72.FRAMEPIC             - vykresli obrazok do okna - NUM
        73.REINIT2              - reinicializacia vzhladom na framy}

var ff,f,cis,por,count,za    : word;
    s,sx,sc,zal              : string;
    xx                       : byte;
    a,b,c,d,e                : word;
    found,breaker,sys        : boolean;    {found - ak bol najdeny prikaz}
						    {breaker - syntax END}
    napis3                   : TPrint;
    new_frame                : TFrame;
    pic_frame                : TFrame;
begin
    napis3.init(2,2,15,0,0,true,false);
    new_frame.init(old_frame.ha_frame,'','',true);
    new_frame.set_params(old_frame);
    pic_frame.init(old_frame.ha_frame,'','',true);
    pic_frame.set_params(old_frame);
    pouzi_predmet:=true;
    if typ then begin
     za:=own[num];
     own[num]:=0;
     num:=za;
    end;
     {vykona funkciu}
   if typ then
     case vec^[num].funk of
		1:begin            {zobrazi ovocie}
			   for f:=1 to nahrane_veci do
				  if vec^[f].mie=vec^[num].inf1 then begin
					  vec^[f].mie:=miestnost;
					  reprint_predmet(num);
				  end;
				new_screen;
		    end;
		 2:begin
			   for f:=vec^[num].inf1 to vec^[num].inf3 do
				for ff:=vec^[num].inf2 to vec^[num].inf4 do
				 st.mie[f,ff]:=vec^[num].inf5;
		     end;
		 4:begin                       {premeni texturu na danom mieste}
				 st.mie[vec^[num].inf1,vec^[num].inf2]:=vec^[num].inf3;
				 odomkni_dvere(vec^[num].inf1,vec^[num].inf2);
		     end;
     end;
    breaker:=false;
     lajn:=0;
     if (start_action<>0) or (vec^[num].inf7>0) then begin {vypise komentar k veci}
	  if automatic then set_defaults;
	  if start_action=0 then xx:=vec^[num].inf7
           else xx:=start_action;
        start_action:=0;
	  repeat
			s:=vrat_text(xx);
			count:=1;
			repeat
			  por:=1;
			  mov_command(s,sx,count);       {! nepouzivaj count, ale por}
			  if is_command(sx,sx) then begin
			   mov_part(sx,sc,por);
			   found:=false;
			   for cis:=1 to num_prikazy do
				if prikazy[cis]=sc then begin
				 found:=true; {ci bol najdeny prikaz}
				 mov_part(sx,sc,por);
				 case cis of
				   1:begin
						    reload_sound(3,zvukovy_subor,sc);
						    pust(3);
				     end;
				   2:begin
						    play_ani('>'+sc);
						    write_palette(blackx,0,256);
						    tma:=true;
						    redraw(true);
						    increase_palette(blackx,palx,palette_speed);
				     end;
				    3:cls;
				    4:decrease_palette(palx,palette_speed);
				    5:increase_palette(blackx,palx,palette_speed);
				    6:redraw(true);
				    7:begin
						play_ani('>'+sc);
						write_palette(blackx,0,256);
						tma:=true;
					  end;
				     8:if handles[1].used then draw_scr(handles[1],0,0,640,480);
				     9:wait_for_key;
				     10:set_def;
				     11:if sc=YES then automatic:=true else automatic:=false;
				     12:val(sc,text_y,text_y);
				     13:val(sc,no_line,no_line);
				     14:napis3.set_color(value(sc));
				     15:begin
						     increase_palette(blackx,palx,palette_speed);
						     wait_for_key;
                                         new_frame.kill_back;
                                         pic_frame.kill_back;
						     new_screen;
					    end;
				     16:begin
						    inc(lajn);
						    if not center then text_x:=100;
					    end;
				     17:val(sc,text_x,text_x);
				     18:if sc=YES then napis3.set_center(true)
                                   else napis3.set_center(false);
				     19:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    mov_part_num(sx,c,por);
					    go_to_new_stage(a,b,c);
				     end;
				    20:putseg2(pic_x,pic_y,resx,resy,0,13,ar^);
				    21:putseg2xms(handles[4],pic_x,pic_y,resx,resy,vec^[num].obr,13);
				    22:begin
					    val(sc,pic_x,pic_x);
					    mov_part_num(sx,pic_y,por);
					   end;
				     23:begin
						increase_palette(blackx,palx,palette_speed);
						wait_for_key;
						cls;
				     end;
				    24:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    mov_part_num(sx,c,por);
					   if (b>0) and (c>0) then
						    putseg2xms(handles[4],b,c,resx,resy,a,13)
					   else
						    putseg2xms(handles[4],text_x,text_y+lajn*no_line,resx,resy,a,13);
				    end;
				    25:begin
					    val(sc,a,a);
					    mov_part(sx,sc,por);
					    if a>1 then inc(a,126);
					    for f:=1 to nahrane_veci do
						    if vec^[f].mie=ord(sc[1]) then vec^[f].mie:=a;
				    end;
				    26:begin
					    val(sc,a,a);
					  if not scored[xx] then
					    inc(score,a);
					  scored[xx]:=true;
				    end;
				    27:breaker:=true;
				    28:begin
					    val(sc,a,a);
					    xx:=a-1;
				    end;
				    29:begin
					    val(sc,a,a);
					    vec^[num].inf7:=a;
				    end;
				    30:begin
					    val(sc,a,a);
					    vec^[num].inf7:=a;
					    xx:=a-1;
				    end;
				    31:begin
					    val(sc,a,a);
					    mov_part(sx,sc,por);
					    for f:=1 to nahrane_veci do
						    if (length(vec^[f].meno)=5) and (vec^[f].meno[5]=sc[1]) then
								vec^[f].inf7:=a;
				    end;
				     32:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    mov_part_num(sx,c,por);
					    mov_part_num(sx,d,por);
					    mov_part_num(sx,e,por);
					    for f:=a to c+a do
						    for ff:=b to b+d do
							st.mie[f,ff]:=e;
				   end;
				   33:begin
					    val(sc,a,a);
					    load_map(a);
					    save_map(aktual);
				   end;
				   34:begin
					    val(sc,a,a);
					    save_map(a);
				   end;
				   35:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    si.x:=a*8+8;
					    si.y:=b*8+8;
					    si.oldx:=si.x;
					    si.oldy:=si.y;
				   end;
				    36:begin
					    val(sc,a,a);
					    mov_part(sx,sc,por);
					    for f:=1 to nahrane_veci do
						    if (length(vec^[f].meno)=5) and
							(vec^[f].meno[5]=sc[1]) then begin
								vec^[f].mie:=a;
								vec^[f].meno[4]:=chr(a);
							end;
				    end;
				   37:begin
					    val(sc,a,a);
					    save_map(aktual);
					    load_map(a);
					    if a>1 then miestnost:=a+126 else a:=1;
				   end;
				   38:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    for f:=1 to 3 do begin
						if vec^[own[f]].cislo=a then begin
							xx:=b-1;
							sx:='';
							BREAK;
						end;
					    end;
				   end;
				   39:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    for f:=1 to 3 do begin
						if vec^[own[f]].cislo=a then begin
							vec^[own[f]].mie:=b;
							own[f]:=0;
							BREAK;
						end;
					    end;
				   end;
				   40:begin
					    sys:=false;
					    val(sc,a,a);
					    for f:=1 to 3 do begin
						if own[f]=0 then begin
						   sys:=true;
						    for ff:=1 to nahrane_veci do begin
							 if vec^[ff].cislo=a then begin
							    vec^[ff].mie:=2;
							    own[f]:=ff;
							    break;
							 end;
						    end;
						 BREAK;
					    end;
					    end;
					    if not sys then begin
						    for ff:=1 to nahrane_veci do begin
							 if vec^[ff].cislo=a then begin
							    vec^[ff].mie:=miestnost;
							    vec^[ff].x:=si.x;
							    vec^[ff].y:=si.y;
							    vec^[ff].ox:=si.x;
							    vec^[ff].oy:=si.y;
							    break;
							 end;
					    end;
				     end;

				   end;
				   41:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    dej[a]:=b;
				   end;
				   42:begin
					    val(sc,a,a);
					    inc(dej[a]);
				   end;
				   43:begin
					    val(sc,a,a);
					    dec(dej[a]);
				   end;
				   44:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    mov_part_num(sx,c,por);
					    if (dej[a])=b then begin
						 xx:=c-1;
						 sx:='';
					    end;
				   end;
				   45:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    mov_part_num(sx,c,por);
					    if (dej[a])<b then begin
						 xx:=c-1;
						 sx:='';
					    end;
				   end;
				   46:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    mov_part_num(sx,c,por);
					    if (dej[a])>b then begin
						 xx:=c-1;
						 sx:='';
					    end;
				   end;
				   47:pouzi_predmet:=false;
				   48:pouzi_predmet:=true;
				   49:begin
					   zal:=sc;
					    mov_part_num(sx,b,por);
					    mov_part_num(sx,c,por);
					   draw_it(zal,b,c);
				   end;
				   50:begin
					accomplished;
				   end;
				   51:strata_zivota;
				   52:begin
					    val(sc,b,b);
					    inc(zivoty,b);
				   end;
				   53:set_font(sc);
				   54:set_font(font);
				   55:begin
					    mov_part_num(sx,a,por);
					    mov_part(sx,zal,por);
					    mov_part_num(sx,b,por);
					    mov_part_num(sx,c,por);
					    uloz_nazov_obrazku(a,zal,b,c);
					end;
				     56:begin
					    val(sc,b,b);
					    stage_image(b);
					end;
				    57:begin
					    val(sc,a,a);
					    scan_x1:=a;
					    mov_part_num(sx,a,por);
					    scan_x2:=a;
					    mov_part_num(sx,a,por);
					    scan_y1:=a;
					    mov_part_num(sx,a,por);
					    scan_y2:=a;
					end;
					58:begin
					    val(sc,a,a);
					    mov_part(sx,sc,por);
					    if sc=yes then priechody^[a].used:=true
						 else priechody^[a].used:=false;
					end;
					59:begin
					    val(sc,a,a);
					    mov_part(sx,sc,por);
					    if sc=yes then lift^[a].used:=true
						 else lift^[a].used:=false;
					end;
					60:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    lift^[a].rychlost:=b;
					end;
					61:begin
					    val(sc,a,a);
					    mov_part_num(sx,b,por);
					    lift^[a].smer:=b;
					end;
					62:begin               {SETANIM}
					    mov_part(sx,zal,por);
					    for a:=1 to nahrane_veci do begin
						  if (length(vec^[a].meno)>4) and (vec^[a].meno[5]=sc[1]) then begin
							if zal=yes then vec^[a].meno[2]:='A' else
							    vec^[a].meno[2]:='N';
						  end;
					    end;
					end;
					63:begin               {SETOBR}
					    mov_part_num(sx,b,por);
					    for a:=1 to nahrane_veci do begin
						  if (length(vec^[a].meno)>4) and (vec^[a].meno[5]=sc[1]) then begin
						     vec^[a].obr:=b;
						     if not tma then begin
							zhasni_vec(vec^[a]);
							reprint_predmet(a);
						     end;
						  end;
					    end;
					end;
					64:pulzx(2);
					65:begin
					     decrease_palette(palx,1);
					     redraw3;
					     increase_palette(blackx,palx,1);
					end;
                              66:begin         {SETFREEZ}
                                   val(sc,a,a);
                                   freez_time:=a;
                                   mov_part_num2(sx,unfreez_sound,por);
                                 end;
                              67:begin         {SETGOD}
                                   a:=Value(sc);
                                   god_time:=a;
                                   mov_part_num2(sx,ungod_sound,por);
                                 end;
                              68:if sc=YES then napis3.set_shadow(true) {SHADOW}
                                     else napis3.set_shadow(false);
                              69:napis3.set_shadow_color(value(sc));    {SHADOW COLOR}
                              70:begin                                  {FRAME}
                                   a:=value(sc);
                                   mov_part_num(sx,b,por);
                                   mov_part_num(sx,c,por);
                                   mov_part_num(sx,d,por);
                                   old_frame.draw(a,b,c,d);
                                 end;
                              71:begin                                  {FRAME2}
                                   text_x:=110;
                                   text_y:=110;
                                   new_frame.draw(100,100,25,15);
                                   napis3.print_shad(text_x,text_y,sc,true);
                                   inc(text_y,chardy*2);
                                   no_line:=chardy;
                                 end;
                              72:begin                                  {FRAMEPIC}
                                   pic_frame.draw(35,35,1,1);
                                   a:=value(sc);
                                   putseg2xms(handles[4],50,50,resx,resy,a,13);
                                 end;
                              73:begin                                  {REINIT2}
                                   rozsviet;
                                   wait_for_key;
                                   new_frame.put_back;
                                   pic_frame.put_back;
                                 end;
				 end;
			   break;
			  end;
			  if not found then write_error(sx);
			  end
			 else begin
			   if center then  begin      {zarovnany vypis}
				 if sx<>'' then begin
				  napis3.print(text_x,text_y+lajn*no_line,sx);
{				  inc(lajn);
                          text_x:=100;}
				 end;
			   end
			   else begin         {obycajny vypis}
				  napis3.print(text_x,text_y+lajn*no_line,sx);
				  inc(text_x,length(sx)*chardx);
                          text_x:=100;
                          inc(lajn);
			   end;
			end;
	  until (count>=length(s)) or (sx='');
	  inc(xx);        {prejde na dalsi prikaz}
     until (xx>255) or (s='') or (breaker);{ak su tieto podmienky splnene,
									    ukonci prikzovy mod}
   end;
 non_key;
 napis3.done;
 new_frame.done;
 pic_frame.done;
 rewait;
end;

procedure menu;
const max_menu=4;
var mass:^jxmenu_typ;
   f,u,z:word;
   status,zobral,tester:boolean;
   s:string;
begin
  zobral    := false;
  menux     := 4;
  k         := 0;
  u         := 1;
  if (mov>0) and (vec^[mov].meno[1]='V') then begin
	pouzi_predmet(mov,false);
  end
  else
  if (mov>0) and (vec^[mov].meno[1]<>'W') then use_vec(mov)
  else begin
    new(mass);
    init_jxmenu(200,170,0,15,0,tx[ja,25],mass^);
    size_jxmenu(249,149,mass^);
    first_jxmenu(4,mass^);
   if mov>0 then begin
    status:=false;
    zobral:=true;
    for f:=1 to 3 do begin
	    if own[f]=0 then begin
		 own[f]:=mov;
		 vec^[mov].mie:=2;
		 zhasni_vec(vec^[mov]);
		 status:=true;
		 break;
	    end;
    end;
    if not status then begin
	   zhasni_vec(vec^[mov]);
	   vec^[mov].mie:=2;
	   z:=own[1];
	   vec^[own[1]].x:=si.x+px;
	   vec^[own[1]].y:=si.y+py;
	   vec^[own[1]].ox:=si.x+px;
	   vec^[own[1]].oy:=si.y+py;
	   vec^[own[1]].mie:=miestnost;
	   own[1]:=own[2];
	   own[2]:=own[3];
	   own[3]:=mov;
	   reprint_predmet(z);
    end;
   end;

    save_scr(handles[2],200,170,256,160);
    for f:=1 to max_menu-1 do begin
	    if own[f]=0 then
	     vloz_jxmenu(260,f*30+170,tx[ja,26],mass^,0)
	    else
	     vloz_jxmenu(260,f*30+170,vrat_nazov(vec^[own[f]].cislo),mass^,0)
    end;
	     vloz_jxmenu(260,290,tx[ja,22],mass^,0);
   old_frame.draw(200,170,14,8);
   draw_jxmenu3(mass^);

   for f:=1 to 3 do
	  if own[f]=0 then
	     putseg2(mass^.dat[f].x-30,mass^.dat[f].y,resx,resy,45,13,ar^)
	  else
	     putseg2xms(handles[4],mass^.dat[f].x-30,mass^.dat[f].y,resx,resy,vec^[own[f]].obr,13);

	     putseg2(mass^.dat[4].x-30,mass^.dat[4].y,resx,resy,44,13,ar^);
   draw_inventar;
   if not zobral then first_jxmenu(1,mass^);
   vyber_jxmenu(mass^,f);
  draw_scr(handles[2],200,170,256,160);

  kill_handle(handles[2]);
   if (f>0) and (f<4) and (own[f]<>0) then begin
	   vec^[own[f]].x:=si.x+px;
	   vec^[own[f]].y:=si.y+py;
	   vec^[own[f]].ox:=si.x+px;
	   vec^[own[f]].oy:=si.y+py;
     if (vec^[own[f]].x>vec^[own[f]].x1) and (vec^[own[f]].y>vec^[own[f]].y1) and
	    (vec^[own[f]].x<vec^[own[f]].x2) and (vec^[own[f]].y<vec^[own[f]].y2)
	    and (vec^[own[f]].st=miestnost) then begin
	    z:=own[f];
	    if not pouzi_predmet(f,true) then  begin
		 vec^[z].mie:=miestnost;
	   {	 reprint_predmet(own[f]);}
	 {	   own[f]:=0;}
{		 if (own[1]=0) and (own[2]>0) then begin own[1]:=own[2]; own[2]:=0; end;
		 if (own[2]=0) and (own[3]>0) then begin own[2]:=own[3]; own[3]:=0; end;}
	    end;
     end
     else begin
	  tester:=false;
	  for u:=1 to 3 do if own[f]=0 then tester:=true;
	  zisti_vec;
	  if mov=0 then tester:=true;
	  if tester then begin
	   vec^[own[f]].mie:=miestnost;
	   own[f]:=0;
	   end else
	   zhasni_vec(vec^[mov]);

    end;
	    if (own[1]=0) and (own[2]>0) then begin own[1]:=own[2]; own[2]:=0; end;
	    if (own[2]=0) and (own[3]>0) then begin own[2]:=own[3]; own[3]:=0; end;
	if not tma then begin
         reprint_predmet(own[f]);
	   draw_inventar;
      end else begin
         redraw(true);
         increase_palette(blackx,palx,10);
      end;
   end;
  dispose(mass);
 pulz(2);
 end;
  draw_inventar;
  clear_key_buffer;
  rewait;
end;
