unit load235;
{$mode objfpc}{$H-}  { Use ShortString for compatibility with original }
{$J+}  { Allow for-loop variable modifications }
interface
uses SysUtils, Dos, aktiv35, geo, blockx, jxgraf, jxfont_simple, animing, jxmenu, jxvar, modern_mem, koder, raylib_helpers;

procedure set_old_pos;  {nastavi priserky na ich zaciatocnu suradnicu}
procedure pridaj2(var s:string;var l:word; update:boolean);
procedure save_map(num:byte);
procedure load_map(num:byte);
procedure prirad(sx:string;num:word;var l:word);
procedure load_anim_def;
procedure prehraj(num:word);
function check_lan(var ciel:string;zdroj:string):byte;
function check_lan2(var ciel:string;zdroj:string):byte;
procedure load_predmet2(sub:string);
procedure load_predmet;
procedure print_predmet;
procedure reprint_predmet(num:byte);
procedure print_predmet2;
procedure zisti_vec;
procedure load_texture;
procedure noline2;
procedure print_texture;
procedure RenderMapTiles;  { Render map tiles using Raylib GPU textures - called after ClearBackground }
procedure LoadObjectTextures;  { Load object sprites from VECI resource }
procedure DrawObject(idx: word; frame_counter: longint);  { Draw single object }
procedure DrawAllObjects(frame_counter: longint);  { Draw all objects in current room }

var
  map_tiles_loaded: boolean;  { True when map tiles are loaded as GPU textures }
  object_textures_loaded: boolean;  { True when object textures are loaded }
  static_object_textures_loaded: boolean;  { True when static object textures are loaded }
  animated_object_textures_loaded: boolean;  { True when animated object textures are loaded }
  object_textures: array[0..189] of TRaylibTexture2D;  { GPU textures for 190 object types (static from GVECI) }
  animated_object_textures: array[0..189] of TRaylibTexture2D;  { GPU textures for animated objects (from GANIM) }

function  vrat_nazov(f:byte):string;
procedure uloz_nazov(var s:string;f:byte);
function  vrat_text(f:byte):string;
procedure uloz_text(var s:string;f:byte);

procedure draw_it(name:string;x,y:word);
procedure use_vec(mov:word);    {pouzije vec}
procedure vypis_skore; {Vypise skore}
procedure accomplish;                 {zobrazi ukoncovac, ak uz su vyzbierane predmety}
procedure draw_lifes;
procedure rewait;           {nastavy cakaci cyklus na novy cas}
procedure zhasni_vec(var pr:predmet);   {zhasne vec}
procedure redraw(param:boolean);
procedure accomplished;       {hotovo, koniec miestnosti}
procedure zhasni;
procedure rozsviet;
procedure go_to_new_stage (mix,x,y:word);  {prepocitava 8x suradnice}
procedure go_to_new_stage2(mix:byte; x,y:word);  {neprepocitava 8x suradnice}
procedure transfer_to_new_stage(mix:byte;x,y:word;tr:boolean);
procedure strata_zivota;
procedure zobraz_vec(var pr:predmet);
procedure redraw_score;
procedure reset_pol;
procedure draw_inventar; {vykresli inventar}
procedure play_ani(vstup:string);
procedure insert_score;		{vlozi skore do tabulky}
procedure stop_all_sounds;
function  defined(var s:string):boolean;
procedure redraw3;
procedure check_visible(get_back:boolean);
procedure play_ball;
procedure set_font(s:string);
procedure odomkni_dvere(x,y:word);   {odomkne dvere vec}

procedure uloz_nazov_obrazku(f:byte; meno:string; n1,n2:word);
function  vrat_nazov_obrazku(f:byte):boolean;  {ak doslo k zmene obrazka}

procedure stage_image(num:word);	{vykresli obrazok v danej miestnosti}
procedure export_texture(nx,ny:word);
procedure aktivuj_texturu;

procedure load_priechod(sx:string);
procedure nasob_priechody(num:word);
procedure load_vytahy(sx:string);
procedure nasob_vytahy(num:word);
procedure pouzi_vytah(smer,rychlost:byte);

procedure pust_extra(num:byte);

procedure help_line1;                      {ciara pre mrazak}
procedure help_line2;

procedure set_def;
procedure rerun;
procedure load_level_list(meno:string;var pole:array of byte);
function ano_nie2(s:string):boolean;
function setup(fun:string):boolean;


const num_opt=66;
	option:array[1..num_opt] of string[15]=
	('MENO','OBR','START','MAPA','ZVUK','SNDCREDIT',
	 'SNDZOBER','GRAVITY','SND','ANIM','SNDPORT',
	 'STARTMIE','NEXTMIE','TYP','TEXTURA','INVISIBLE',
	 'VECI','ANIMDEF','SNDOBJAV','SNDSTART','SNDSTRATA',
	 'SNDKONIEC','SNDSUCCES','SNDACCES','SNDZMIZNI',
	 'SNDINTRO','INTROOBR','SNDAPPEAR','SNDEND','OUTROOBR',
	 'SNDSCORE','SNDZIVOT','SNDMAZE','FLISTART','FLIEND',
	 'MSG1','MSG2','MSG3','MSG4','MSG5','TIMER','ANIMS',
	 'LANGUAGE','SCROLL','VEC','TEXT','FLOOR','TEST',
	 'MAPX','FIRSTMAP','CRCCHECK','INITTIME','SNDFIREBALL',
	 'SNDFIR','JOYSTICK','FONT','SNDCHANGE','SCAN','PRE',
	 'SMARTJUMP','LIFT','SNDX','STARTSTAGE','SETFREEZ','SETGOD',
       'START_ACTION');
	{1.MENO      - NAZOV MAPY
	 2.OBR       - Cislo mapy,OBRAZOK, PRE POZADIE, X, Y
	 3.START     - STARTOVACIE POZICIE SIRIELA
	 4.MAPA      - MAPA TEXTUR
	 5.ZVUK      - MOZE SPUSTIT ZVUK YES/NO
	 6.SNDCREDIT - ZVUK PRI PRIPOCITAVANI BODOV
	 7.SNDZOBER  - ZVUK PRI ZOBRATI PREDMETU
	 8.GRAVITY   - GRAVITACIA
	 9.SND       - VSTUPNY SUBOR PRE ZVUKY
	10.ANIM      - Subor s animackami
	11.SNDPORT   - zvuk pri teleportacii
	12.STARTMIE  - prva miestnost      :(
	13.NEXTMIE   - miestnost, ktorou sa pokracuje
	14.TYP       - typ miestnosti
	15.TEXTURA   - obrazok, z ktoreho sa nacita textura
	16.INVISIBLE - od ktorej textury su neviditelne
	17.VECI      - subor z ktoreho sa nacita textura predmetov
	18.ANIMDEF   - subor definuje jednotlive animacie
	19.SNDOBJAV  - zvuk, ktory sa ozve pri objaveni textury
	20.SNDSTART  - zvuk po starte
	21.SNDSTRATA - zvuk pri strate zivota
	22.SNDKONIEC - zvuk pri skonceni hry
	23.SNDSUCCES - zvuk pre uspesne ukoncenie miestnosti
	24.SNDACCES  - zvuk pri ukazani vychodu
	25.SNDZMIZNI - zvuk pri zmiznuti
	26.SNDINTRO  - zvuk pri nastartovani
	27.INTOROOBR - obrazok pre intro
	28.SNDAPPEAR - zvuk pre objavenie ovocia
	29.SNDEND    - zvuk pre outro
	30.OUTROOBR  - obrazok pre outro
	31.SNDSCORE  - zvuk pri hi-score
	32.SNDZIVOT	 - zvuk pri zobrati zivota
	33.SNDMAZE   - zvuk pri objaveni/zmiznuti bludiska
	34.FLISTART  - animacia pri startovani
	35.FLIEND	 - animacia pri ukonceni
	36..40 MSGx  - sprava
	41.TIMER	 - cas, ktory na splnenie misie
	42.ANIMS	 - povoluje prehravanie animacii
	43.LANGUAGE  - jazyk, ktory sa pouziva
	44.SCROLL	 - scrolovy subor
	45.VEC	 - meno veci
	46.TEXT	 - vykonny text, pre vec
	47.FLOOR	 - podlaha - textura, ktora nie je kontrolovana
	48.TEST	 - spusta tester (Y/N)
	49.MAPX	 - udava cislo a mapu (do XMS)
	50.FIRSTMAP	 - nastavy X miestnost ako zaciatocnu
	51.CRCCHECK	 - sluzi na nastavenie kontorly CRC Y/N
	52.INITTIME	 - udava cas v sekundach potrebny na nastartovanie
	53.SNDFIREBALL- zvuk pri dopade fireballu
	54.SNDFIR	 - zvuk pri vystreleni fireballu
	55.JOYSTICK  - ci je mozne pouzit joystick
	56.FONT	 - zmena fontu
	57.SNDCHANGE - zvuk, ktory sa ozve pri zmene modu predmetu
	58.SCAN	 - nastavi rozsah skeneru v bludisku - x1,x2,y1,y2
	59.PRE	 - definuje prechody
	60.SMARTJUMP - skace s obmedzenim
	61.LIFT	 - nastavi vytah
	62.SNDX	 - zadefinuje zvuk pre specialne pouzitie - NUM,NAME
      63.STARTSTAGE- nastavi startovaciu miestnost
      64.SETFREEZ  - zmrazenie postav - CAS,UNzvuk
      65.SETGOD    - god mod - CAS,UNzvuk
      66.START_ACTION - nastavy startovaciu akciu miestnosti - cislo}

const num_anim_def_opt=1;
	anim_def_opt:array[1..num_anim_def_opt]of string[15]=
			 ('SUB');

implementation

var
  map_tile_textures: array[0..189] of TRaylibTexture2D;  { 190 map tiles (19x10) }
  { map_tiles_loaded is declared in interface section }

procedure transfer_to_new_stage(mix:byte;x,y:word;tr:boolean); {bool zabezpecuje typ priechodu}
begin
     decrease_palette(palx,10);
     clear_key_buffer;
     if tr then go_to_new_stage2(mix,x,y) else
	  go_to_new_stage(mix,x,y);
     clear_key_buffer;
     redraw3;
     clear_key_buffer;
     init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^);
     clear_key_buffer;
     increase_palette(blackx,palx,10);
     play_ball;
     clear_key_buffer;
     rewait;
end;

procedure nasob_priechody(num:word);
begin
	   priechody^[num].cx:=priechody^[num].cx*8+8;
	   priechody^[num].cy:=priechody^[num].cy*8+8;
	   priechody^[num].x1:=priechody^[num].x1*8+8;
	   priechody^[num].y1:=priechody^[num].y1*8+8;
	   priechody^[num].x2:=priechody^[num].x2*8+8;
	   priechody^[num].y2:=priechody^[num].y2*8+8;
end;

function ano_nie2(s:string):boolean;
var mass:^jxmenu_typ;
    f:word;
begin
    ano_nie2:=false;
    new(mass);
     save_scr(handles[2],269,170,120,120);
     init_jxmenu(270,180,0,15,0,s,mass^);
     size_jxmenu(100,100,mass^);
     vloz_jxmenu2(tx[ja,23],mass^,0);
     vloz_jxmenu2(tx[ja,24],mass^,0);
     old_frame_draw(270,180,3,3);
     size_jxmenu(64,48,mass^);
     draw_jxmenu3(mass^);
     vyber_jxmenu(mass^,f,0);  { No timeout - wait for user input }
     if f=1 then ano_nie2:=true;
     draw_scr(handles[2],269,170,120,120);
     kill_handle(handles[2]);
    dispose(mass);
    clear_key_buffer;
    rewait;
end;

procedure nasob_vytahy(num:word);
begin
	   lift^[num].x1:=lift^[num].x1*8+8;
	   lift^[num].y1:=lift^[num].y1*8+8;
	   lift^[num].x2:=lift^[num].x2*8+8;
	   lift^[num].y2:=lift^[num].y2*8+8;
end;

procedure load_priechod(sx:string);
var count	: word;
    cd	: byte;
    s2	: string;
begin
	count:=1;
	if (priechody<>nil) and (pocet_priechodov<max_prechod) then begin
	   mov_num2(sx,cd,count);
	   if cd>pocet_priechodov then pocet_priechodov:=cd;
	   mov_num2(sx,priechody^[cd].mie1,count);
	   mov_num(sx,priechody^[cd].x1,count);
	   mov_num(sx,priechody^[cd].y1,count);
	   mov_num(sx,priechody^[cd].x2,count);
	   mov_num(sx,priechody^[cd].y2,count);
	   mov_num2(sx,priechody^[cd].mie2,count);
	   mov_num(sx,priechody^[cd].cx,count);
	   mov_num(sx,priechody^[cd].cy,count);
	   mov_string(sx,s2,count);
	   if s2=yes then priechody^[cd].used:=true else
		priechody^[cd].used:=false;
	   nasob_priechody(cd);
	end;
end;

procedure load_vytahy(sx:string);
var count	: word;
    cd	: byte;
    s2	: string;
begin
	count:=1;
	if (lift<>nil) and (pocet_vytahov<max_vytahy) then begin
	   mov_num2(sx,cd,count);
	   if cd>pocet_vytahov then pocet_vytahov:=cd;
	   mov_num2(sx,lift^[cd].mie,count);
	   mov_num(sx,lift^[cd].x1,count);
	   mov_num(sx,lift^[cd].y1,count);
	   mov_num(sx,lift^[cd].x2,count);
	   mov_num(sx,lift^[cd].y2,count);
	   mov_num2(sx,lift^[cd].smer,count);
	   mov_num2(sx,lift^[cd].rychlost,count);
	   mov_string(sx,s2,count);
	   if s2=yes then lift^[cd].used:=true else
		lift^[cd].used:=false;
	   nasob_vytahy(cd);
	end;
end;

procedure pouzi_vytah(smer,rychlost:byte);
begin
	case smer of
	     1:sipka_fakex(dir_hore,rychlost,si.x,si.y);
	     2:sipka_fakex(dir_dole,rychlost,si.x,si.y);
	     3:sipka_fakex(dir_vlavo,rychlost,si.x,si.y);
	     4:sipka_fakex(dir_vpravo,rychlost,si.x,si.y);
	end;
end;

procedure play_ball;
var f:word;
begin
	if (snd_fir<>nos)  then begin
	   for f:=1 to nahrane_veci do begin
		if (vec^[f].funk=17) then begin
		  if (vec^[f].mie=miestnost) and (vec^[f].visible) then begin
		   vec^[f].inf5:=0;
		   vec^[f].inf6:=0;
		   if (freez_time=0) then pust(basic_snd+vec^[f].inf1-1) else
                  if (vec^[f].meno[3]<>'S')then pust(basic_snd+vec^[f].inf1-1)
		  end;
		end else
		if ((vec^[f].funk=15) or (vec^[f].funk=18)) and (vec^[f].mie=miestnost) and (vec^[f].visible) and
		    (vec^[f].x=vec^[f].oox) and (vec^[f].y=vec^[f].ooy)
		     then begin
			   case vec^[f].funk of
				  15:if (freez_time=0) then pust(6) else
                                if (vec^[f].meno[3]<>'S')then pust(6);
				  18:if (freez_time=0) then pust_extra(vec^[f].z1) else
                                if (vec^[f].meno[3]<>'S')then pust_extra(vec^[f].z1);
			   end;
		     end;
	   end;
	end;
end;

procedure draw_it(name:string;x,y:word);
var
  font_pal: jxfont_simple.tpalette;
begin
    if length(name)>0 then begin
     if name[1]='>' then begin
	    name:=out_string(name);
	    { Call blockx.draw_gif_block directly for DAT files }
	    { Convert palette type }
	    font_pal := jxfont_simple.tpalette(palx);
	    blockx.draw_gif_block(screen_image,zvukovy_subor,name,x,y,font_pal);
     end
     else draw_gif(screen,name,x,y,palx);
    end;
end;

procedure uloz_nazov(var s:string;f:byte);
begin
  if f>0 then
    CopyCMemToXMem( handles[3].h, (21*(f-1)) , @s, 20 );
end;

procedure uloz_nazov_obrazku(f:byte; meno:string; n1,n2:word);
var s:string;
    o1,o2:string[3];
begin
  str(n1,o1);
  str(n2,o2);
  s:=meno+','+o1+','+o2;
  if f>0 then
    CopyCMemToXMem( handles[3].h, (dlzka_textu*(f-1))+posuv_obr , @s, dlzka_obr );
end;

function vrat_text(f:byte):string;
var vystup:string;
begin
  if f>0 then begin
    CopyXMemToCMem( @vystup, handles[3].h, (dlzka_textu*(f-1))+posuv_textu, dlzka_textu );
    vrat_TEXT:=vystup;
  end
end;

function vrat_nazov_obrazku(f:byte):boolean;  {ak doslo k zmene obrazka}
var vystup:string;
    v2:string[13];
    c,n1,n2:word;
begin
  vrat_nazov_obrazku:=false;
  if f>0 then begin
    if not handles[3].used then begin
      writeln('WARNING: vrat_nazov_obrazku called but handles[3] not initialized');
      exit;
    end;

    { Check if handles[3] has been initialized with data }
    { If st.obr is empty, this is likely the first call and no images are loaded yet }
    if st.obr = '' then begin
      writeln('vrat_nazov_obrazku: st.obr is empty, assuming no background images loaded');
      exit;
    end;

    try
      CopyXMemToCMem( @vystup, handles[3].h, (dlzka_textu*(f-1))+posuv_obr, dlzka_obr );
      c:=1;
      mov_string(vystup,v2,c);
      mov_num(vystup,n1,c);
      mov_num(vystup,n2,c);
      if (v2<>st.obr) {or (n1<>obrazok_x) or (n2<>obrazok_y)} then begin
        { Defensive: Don't set st.obr to empty or whitespace-only string }
        if Trim(v2) <> '' then begin
          vrat_nazov_obrazku:=true;
          st.obr:=v2;
          { writeln('vrat_nazov_obrazku: Image changed to "', v2, '"'); }
        end else begin
          { writeln('vrat_nazov_obrazku: WARNING - v2 is empty/whitespace, keeping st.obr as "', st.obr, '"'); }
          vrat_nazov_obrazku:=false;
        end;
      end;
      obrazok_x:=n1;
      obrazok_y:=n2;
    except
      on E: Exception do begin
        writeln('vrat_nazov_obrazku: Exception reading handles[3] - ', E.Message);
        writeln('vrat_nazov_obrazku: Assuming no background image for level ', f);
        vrat_nazov_obrazku:=false;
      end;
    end;
  end;
end;

function vrat_nazov(f:byte):string;
var vystup:string;
begin
  if f>0 then begin
    CopyXMemToCMem( @vystup, handles[3].h, (21*(f-1)), 20 );
    vrat_nazov:=vystup;
  end
end;

procedure uloz_text(var s:string;f:byte);
begin
  if f>0 then
    CopyCMemToXMem( handles[3].h, (dlzka_textu*(f-1))+posuv_textu , @s, dlzka_textu );
end;


procedure pridaj2(var s:string;var l:word; update:boolean);
var ciel:string;                         {update - zaistuje vykonanie nasobenia}
begin                                 {W - veci, ktore sa daju brat}
   {zapis: [W???]=
    obr - obrazok
    x,y - suradnice
    funk - funkcia predmetu
    x1,y1,x2,y2 - sektor, v ktorom sa da predmet pouzit
    inf7 - odkial sa maju vykonavat prikazy
    st - cielova miestnost}
    count:=1;
   inc(l);
   nahrane_veci:=l;
   get_name_normal(s,ciel);
   vec^[l].meno:=ciel;
   get_funk_normal(s,ciel);
    mov_num(ciel,vec^[l].cislo,count);
    mov_num(ciel,vec^[l].obr,count);
    mov_num(ciel,vec^[l].x,count);
    mov_num(ciel,vec^[l].y,count);
    mov_num(ciel,vec^[l].funk,count);
    mov_num(ciel,vec^[l].x1,count);
    mov_num(ciel,vec^[l].y1,count);
    mov_num(ciel,vec^[l].x2,count);
    mov_num(ciel,vec^[l].y2,count);
   case vec^[l].funk of
	  1:mov_num(ciel,vec^[l].inf1,count);
	  2:begin
		mov_num(ciel,vec^[l].inf1,count);
		mov_num(ciel,vec^[l].inf2,count);
		mov_num(ciel,vec^[l].inf3,count);
		mov_num(ciel,vec^[l].inf4,count);
		mov_num(ciel,vec^[l].inf5,count);
	    end;
	  4:begin
		mov_num(ciel,vec^[l].inf1,count);
		mov_num(ciel,vec^[l].inf2,count);
		mov_num(ciel,vec^[l].inf3,count);
	    end;
   end;
    mov_num(ciel,vec^[l].inf7,count);
    mov_num(ciel,vec^[l].st,count);
    if vec^[l].st>1 then inc(vec^[l].st,126);
   if update then begin
    vec^[l].x:=vec^[l].x*8+8;
    vec^[l].y:=vec^[l].y*8+8;
    vec^[l].x1:=vec^[l].x1*8+8;
    vec^[l].y1:=vec^[l].y1*8+8;
    vec^[l].x2:=vec^[l].x2*8+8;
    vec^[l].y2:=vec^[l].y2*8+8;
    if vec^[l].meno[4]<'B' then vec^[l].mie:=1
     else vec^[l].mie:=ord(vec^[l].meno[4]);
    vec^[l].take:=4;
end;
   vec^[l].ox:=vec^[l].x;
   vec^[l].oy:=vec^[l].y;
end;

procedure save_map(num:byte);
var f,ff:word;
    s:array[0..39] of byte;
begin
  if num>0 then begin
    dec(num);
	for f:=0 to 26 do begin
	 for ff:=0 to 39 do begin
	 s[ff]:=st.mie[ff,f];
	end;
{	clear_key_buffer;}
	CopyCMemToXMem( handles[5].h, (40*27*num+40*(f)) , @s, 40 );
    end;
  maps[num+1]:=true;
  end;
end;

procedure load_map(num:byte);
var f,ff:word;
    s:array[0..39] of byte;
begin
  if num>0 then begin
    dec(num);
	for f:=0 to 26 do begin
{	 clear_key_buffer;}
	 CopyXMemToCMem( @s, handles[5].h, (40*27*num+40*(f)), 40 );
	 for ff:=0 to 39 do begin
	   st.mie[ff,f]:=s[ff];
	 end;
	end;
  end;
end;

procedure prirad(sx:string;num:word;var l:word);
var ciel:string;
begin
   inc(l);
   get_name_normal(sx,ciel);
   vec^[l].meno:=ciel;
   vec^[l].smer:=false;
   vec^[l].z1:=0;
   vec^[l].z2:=0;
					  get_funk(sx,ciel);
					  mov_num(ciel,vec^[l].obr,count);
					  mov_num(ciel,vec^[l].x,count);
					  vec^[l].x:=vec^[l].x*8+8;
					  mov_num(ciel,vec^[l].y,count);
					  vec^[l].y:=vec^[l].y*8+8;
					  mov_num(ciel,vec^[l].funk,count);
					  vec^[l].mie:=ord(vec^[l].meno[4]);
					  if vec^[l].meno[4]<'B' then vec^[l].mie:=1;
							 vec^[l].take:=4;
					  { Second character determines animation: 'A' = animated, 'N' = not animated }
					  vec^[l].useanim := (vec^[l].meno[2] = 'A');
					  vec^[l].visible:=false; { Initialize as invisible, will be set by check_visible }
					  writeln('[PARSE] X/Y-type object ', l, ': meno=', vec^[l].meno, ' x=', vec^[l].x, ' y=', vec^[l].y, ' mie=', vec^[l].mie, ' obr=', vec^[l].obr, ' funk=', vec^[l].funk, ' useanim=', vec^[l].useanim);
					  case vec^[l].funk of
						 0:; { useanim already set above }
						 1:begin
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf2,count);
						 end;
						 2,3:begin
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf2,count);
							  mov_num(ciel,vec^[l].inf3,count);
							  mov_num(ciel,vec^[l].inf7,count);
							  vec^[l].inf4:=0;
							  vec^[l].inf1:=vec^[l].inf1*8+8;
							  vec^[l].inf2:=vec^[l].inf2*8+8;
							  { useanim already set based on meno[2] above }
							  writeln('[PARSE] funk=', vec^[l].funk, ' patrol: inf1=', vec^[l].inf1, ' inf2=', vec^[l].inf2, ' inf3(speed)=', vec^[l].inf3, ' inf7=', vec^[l].inf7);
						 end;
						 4:begin
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf7,count);
							  if vec^[l].inf7=0 then vec^[l].smer:=true
							     else vec^[l].smer:=false;
							  vec^[l].inf5:=vec^[l].x;
							  vec^[l].inf6:=vec^[l].y;
							  { useanim already set based on meno[2] above }
							  writeln('[PARSE] funk=4 gravity platform: inf1=', vec^[l].inf1, ' inf7=', vec^[l].inf7, ' smer=', vec^[l].smer, ' respawn_x=', vec^[l].inf5, ' respawn_y=', vec^[l].inf6);
						 end;
						 5:begin
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf7,count);
							  if vec^[l].inf7=0 then vec^[l].smer:=true
							    else vec^[l].smer:=false;
							  vec^[l].inf5:=vec^[l].x;
							  vec^[l].inf6:=vec^[l].y;
							  { useanim already set based on meno[2] above }
							  writeln('[PARSE] funk=5 smart gravity platform: inf1=', vec^[l].inf1, ' inf7=', vec^[l].inf7, ' smer=', vec^[l].smer, ' respawn_x=', vec^[l].inf5, ' respawn_y=', vec^[l].inf6);
						 end;
						 6:begin
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf2,count);
							  mov_num(ciel,vec^[l].inf3,count);
							  mov_num(ciel,vec^[l].inf4,count);
							  mov_num(ciel,vec^[l].inf5,count);
							  vec^[l].useanim:=true;
						     end;
						 7,8,10:begin
							  mov_num(ciel,vec^[l].inf1,count);
							  vec^[l].useanim:=true;
						 end;
						 9:begin
							  mov_num(ciel,vec^[l].inf1,count);
							  vec^[l].useanim:=true;
							  completer:=vec^[l].inf1;
						 end;
						 11:begin
							  mov_num(ciel,vec^[l].inf1,count);
							  vec^[l].useanim:=false;
							  case vec^[l].inf1 of
								2,3:begin
								  mov_num(ciel,vec^[l].inf2,count);
								  mov_num(ciel,vec^[l].inf3,count);
								  mov_num(ciel,vec^[l].inf4,count);
								  mov_num(ciel,vec^[l].inf5,count);
								end;
							  end;
						 end;
						 12:begin
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf2,count);
							  vec^[l].useanim:=false;
						 end;
						 13:begin
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf2,count);
							  vec^[l].inf3:=vec^[l].mie;
							  vec^[l].useanim:=false;
						 end;
						 14:begin  {presuva na dalsiu mapu cislo,x,y}
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf2,count);
							  mov_num(ciel,vec^[l].inf3,count);
							  vec^[l].useanim:=true;
						 end;
						 15:begin  {FIREBALL}
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf2,count);
							  vec^[l].inf2:=vec^[l].inf2*8+8;
							  mov_num(ciel,vec^[l].inf3,count);
							  mov_num(ciel,vec^[l].inf4,count);
							  vec^[l].useanim:=true;
						 end;
						 16,17:begin                {17 - zvuk vydacajuci predmet}
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf2,count);
							  mov_num(ciel,vec^[l].inf3,count);
							  mov_num(ciel,vec^[l].inf4,count);
							  vec^[l].useanim:=false;
							  if vec^[l].funk=17 then vec^[l].useanim:=true;
							  if vec^[l].inf2=0 then vec^[l].inf5:=1;
							  {ak nema byt postava dobra, okamzite je zmeni na zlu}
						 end;
						 18:begin  {FIREBALL2}
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf2,count);
							  vec^[l].inf2:=vec^[l].inf2*8+8;
							  mov_num(ciel,vec^[l].inf3,count);
							  mov_num(ciel,vec^[l].inf4,count);
							  vec^[l].useanim:=true;
							  mov_num2(ciel,vec^[l].z1,count);
							  mov_num2(ciel,vec^[l].z2,count);
						 end;
						 19:begin  {MRAZAK 1 ; GOD 2}
							  mov_num(ciel,vec^[l].inf1,count);
							  mov_num(ciel,vec^[l].inf2,count);
							  mov_num2(ciel,vec^[l].z1,count);
							  mov_num2(ciel,vec^[l].z2,count);
							  vec^[l].useanim:=true;
						 end;
					  end;
					  vec^[l].ox:=vec^[l].x;
					  vec^[l].oy:=vec^[l].y;
					  vec^[l].oox:=vec^[l].x;
					  vec^[l].ooy:=vec^[l].y;
end;


procedure load_anim_def;
var fm:word;
begin
    for fm:=0 to anim_nums do anx[fm]:=fm*4;
end;

procedure prehraj(num:word);
begin
     reload_sound(num,zvukovy_subor,zvuky[num+1]);
end;

function check_lan(var ciel:string;zdroj:string):byte;
var s:string;
    f:byte;
begin
    check_lan:=0;
    if (length(zdroj) > 0) and (zdroj[1]='~') then begin
	s:='';
	for f:=2 to 4 do
	 s:=s+zdroj[f];
	check_lan:=1;
	if language[ja]=s then begin
		check_lan:=2;
	   ciel:=zdroj;
	   for f:=1 to 5 do
	   ciel:=out_string(ciel);
	end;
    end
    else ciel:=zdroj;
end;

function check_lan2(var ciel:string;zdroj:string):byte;
var s:string;
    f:byte;
begin
    check_lan2:=0;
    if (length(zdroj) > 0) and (zdroj[1]='~') then begin
	s:='';
	for f:=2 to 4 do
	 s:=s+zdroj[f];
	check_lan2:=1;
	if language[ja]=s then begin
		check_lan2:=2;
	   ciel:=zdroj;
	   for f:=1 to 5 do
	   ciel:=out_string(ciel);
	end
	else ciel:='';
    end
    else ciel:=zdroj;
end;


function defined(var s:string):boolean;
var f:word;
begin
	defined:=false;
	for f:=1 to num_opt do
		if option[f]=s then begin
		   defined:=true;
		   break;
		end;
end;

procedure load_predmet2(sub:string);
const maxbuf=32767;
	posuv=15;
type arm             = array[0..maxbuf] of byte;
var m,fm,l           : word;
    s,sx,sc          : string;
    bl,stop,reloaded : boolean;
    arr              : ^arm;
    cxa              : longint;
    linex,znak       : integer;
    zx_write         : integer;
    sax              : string;
    t                : TextFile;
    ch               : char;
begin
    aktual:=1;
    cxa:=0;
    start_action:=0;
     st.obr:=none;
     if priechody<>nil then for fm:=1 to max_prechod do priechody^[fm].mie1:=0;
     if lift<>nil then for fm:=1 to max_vytahy do lift^[fm].mie:=0;
     pocet_priechodov	:=0;
     pocet_vytahov	:=0;
     for fm:=1 to num_maps do	maps[fm]:=false;
     for fm:=1 to pocet_obr do uloz_nazov_obrazku(fm,st.obr,obrazok_x,obrazok_y);
     for fm:=1 to pocet_textov do begin
	dej[fm]:=0;
     end;
     stop:=false;
     reloaded:=false;
     l:=0;
     if sub[1]='>' then bl:=true else bl:=false;
     if (subor_exist(sub)) or (bl) then begin
     if not bl then begin
	assign(t,sub);
	reset(t);
     end
     else begin
	 new(arr);
	 for fm:=1 to maxbuf do arr^[fm]:=0;
	 sub:=out_string(sub);
	 loadblock_array(zvukovy_subor,sub,arr^);
	 for cxa:=0 to maxbuf do begin
	     if arr^[cxa]<>0 then inc(arr^[cxa],2);
	 end;
	 cxa:=0;
     end;
	  repeat
		   count:=1;
	    if not bl then begin
	       readln(t,s);
	    end
	    else begin
		   s:='';
		   repeat
		    s:=s+chr(arr^[cxa]);
		    inc(cxa);
		   until (cxa>maxbuf) or (arr^[cxa]=13) or (arr^[cxa]=10)
			   or (arr^[cxa]=0);
		   { Skip line ending characters (handle both CRLF and LF) }
		   if (cxa<=maxbuf) and (arr^[cxa]=13) then inc(cxa);  { Skip CR }
		   if (cxa<=maxbuf) and (arr^[cxa]=10) then inc(cxa);  { Skip LF }

		   { Fix for map data: lines are 40 bytes but we only need 39 }
		   { The 40th character is margin and causes cumulative shift if included }
		   if (Length(s) = 40) and (cxa <= maxbuf) then begin
		     { Check if first character is non-printable (map data) }
		     if (ord(s[1]) < 32) or (ord(s[1]) > 127) then begin
		       s := copy(s, 1, 39);  { Truncate to 39 characters }
		     end;
		   end;
	    end;

		get_name_normal(s,sx);

		if sx<>'' then begin
		 upcased(sx,sc);
		   m:=0;
		 if (sx[1]='Z') and (not defined(sx)) then begin
		   inc(l);
		   nahrane_veci:=l;
{               sx:=out_string(sx);}
		   val(sx,vec^[l].inf1,vec^[l].inf1);
		   vec^[l].meno:=sx;
		   get_funk(s,sx);
		   count:=1;
		   mov_num(sx,vec^[l].obr,count);
		   mov_num(sx,vec^[l].x,count);
		   mov_num(sx,vec^[l].y,count);
			vec^[l].x:=vec^[l].x*8+8;
			vec^[l].y:=vec^[l].y*8+8;
		   mov_num(sx,vec^[l].mie,count);
		   if vec^[l].meno[4]<'A' then vec^[l].mie:=1;
		   mov_num(sx,vec^[l].take,count);
		   mov_num(sx,vec^[l].inf1,count);
		   vec^[l].funk:=0;
		   { Second character determines animation: 'A' = animated, 'N' = not animated }
		   vec^[l].useanim := (vec^[l].meno[2] = 'A');
		   vec^[l].visible:=false; { Initialize as invisible, will be set by check_visible }
					  vec^[l].ox:=vec^[l].x;
					  vec^[l].oy:=vec^[l].y;
		   writeln('[PARSE] Z-type object ', l, ': meno=', vec^[l].meno, ' x=', vec^[l].x, ' y=', vec^[l].y, ' mie=', vec^[l].mie, ' obr=', vec^[l].obr, ' useanim=', vec^[l].useanim);
		end else
		if ((sx[1]='X') or (sx[1]='Y')) and (not defined(sx))then begin

		  prirad(s,2,l);
		   nahrane_veci:=l;

		end else
		if (sx[1]='W') and (not defined(sx))then begin
		   pridaj2(s,l,true);
		   nahrane_veci:=l;
		end else
		if (sx[1]='V') and (not defined(sx))then begin
		   inc(l);
		   nahrane_veci:=l;
		   vec^[l].meno:=sx;
		   get_funk(s,sx);
		   mov_num(sx,vec^[l].obr,count);
		   mov_num(sx,vec^[l].x,count);
		   mov_num(sx,vec^[l].y,count);
		   mov_num(sx,vec^[l].inf7,count);
		   vec^[l].x:=vec^[l].x*8+8;
		   vec^[l].y:=vec^[l].y*8+8;
		   vec^[l].funk:=0;
		   { Second character determines animation: 'A' = animated, 'N' = not animated }
		   vec^[l].useanim := (vec^[l].meno[2] = 'A');
		   vec^[l].ox:=vec^[l].x;
		   vec^[l].oy:=vec^[l].y;
		   vec^[l].mie:=ord(vec^[l].meno[4]);
		   if vec^[l].meno[4]<'B' then vec^[l].mie:=1;
		   vec^[l].take:=4;
		   vec^[l].visible:=false; { Initialize as invisible, will be set by check_visible }
		   writeln('[PARSE] V-type object ', l, ': meno=', vec^[l].meno, ' x=', vec^[l].x, ' y=', vec^[l].y, ' mie=', vec^[l].mie, ' obr=', vec^[l].obr, ' useanim=', vec^[l].useanim);
		end else
            FOR fm:=1 to num_opt do begin
		     if sc=option[fm] then begin
			  get_funk_normal(s,sx);
			  case fm of
				 1:begin
					   check_lan(st.meno,sx);
				   end;
				 2:begin
					   mov_num(sx,m,count);
					   mov_string(sx,sc,count);
					   check_lan(st.obr,sc);
					   mov_num(sx,obrazok_x,count);
					   mov_num(sx,obrazok_y,count);
					   uloz_nazov_obrazku(m,st.obr,obrazok_x,obrazok_y);
				   end;
				 3:begin
					  mov_num(sx,m,count);
					  si.x:=m;
					  mov_num(sx,m,count);
					  si.y:=m;
					  si.oldx:=si.x;
					  si.oldy:=si.y;
					  startx:=si.x;
					  starty:=si.y;
				   end;
				 4:begin
					  for linex:=0 to mie_y do begin
					    zx_write := 0;
					    while zx_write <= mie_x do begin
					      if bl then begin
					        ch:=char(arr^[cxa]);
					        inc(cxa);
					      end else
					        read(t,ch);
					      if (ord(ch)<>10) and (ord(ch)<>13) then begin
					        st.mie[zx_write,linex]:=ord(ch)-posuv;
					        inc(zx_write);
					      end;
					    end;
					  end;
					  save_map(1);
				 end;
				 6:check_lan(snd_credit,sx);
				 7:check_lan(snd_zober,sx);
				 8:begin
					  val(sx,m,m);
					  gravity:=(m div 3)+7;
					  ROLLING:=m;
				   end;
				 9:{check_lan(zvukovy_subor,sx)};
				10:{check_lan(anim_file,sx)};
				11:{check_lan(snd_port,sx)};
				13:{check_lan(next_miestnost,sx)};
				14:begin
					  val(sx,m,m);
					  st.stav:=m;
				   end;
				15:textura:=sx;
				16:begin
					  val(sx,m,m);
					  if m=0 then m:=def_invisible;
					  invisible:=m;
				   end;
				17:check_lan(veci,sx);
				18:check_lan(anim_def,sx);
				19:check_lan(snd_objav,sx);
				20:check_lan(snd_start,sx);
				21:check_lan(snd_strata,sx);
				22:check_lan(snd_koniec,sx);
				23:check_lan(snd_succes,sx);
				24:check_lan(snd_acces,sx);
				25:check_lan(snd_zmizni,sx);
				26:check_lan(SND_INTRO,SX);
				27:check_lan(intro_obr,sx);
				28:check_lan(snd_appear,sx);
				29:check_lan(snd_theend,sx);
				30:check_lan(outro_obr,sx);
				31:check_lan(snd_score,sx);
				32:check_lan(snd_zivot,sx);
				33:check_lan(snd_maze,sx);
				34:check_lan(flik_start,sx);
				35:check_lan(flik_end,sx);
				36:check_lan(msg[1],sx);
				37:check_lan(msg[2],sx);
				38:check_lan(msg[3],sx);
				39:check_lan(msg[4],sx);
				40:check_lan(msg[5],sx);
				41:val(sx,timer,timer);
				42:if sx=yes then fli_abile:=true else fli_abile:=false;
				43:begin
					for ja:=1 to num_lang do begin
					  if sx=language[ja] then break;
					end;
				   end;
				 44:check_lan(scroll_sub,sx);
				 45:begin
							count:=1;
					  mov_num(sx,m,count);
					    s:=kill_strings(sx,',');
					  check_lan2(sc,s);
					  if sc<>'' then uloz_nazov(sc,m);
				    end;
{zapis pre TEXT - <PRIKAZ>;TEXT;}
				 46:begin
					  mov_num(sx,m,count);
					    s:=kill_strings(sx,',');
					  check_lan2(sc,s);
					  if sc<>'' then uloz_text(sc,m);
				    end;
				47:val(sx,inusable,inusable);
				49:begin
				    val(sx,m,m);
					  for linex:=0 to mie_y do begin
					    zx_write := 0;
					   while zx_write <= mie_x do begin
					     if bl then begin
						  ch:=char(arr^[cxa]);
						  inc(cxa);
					     end else
						read(t,ch);
					     if (ord(ch)<>10) and (ord(ch)<>13) then begin
					       st.mie[zx_write,linex]:=ord(ch)-posuv;
					       inc(zx_write);
					     end;
					   end;
					 end;
					 save_map(m);
					 reloaded:=true;
				    end;
				  50:begin
				    val(sx,m,m);
				    aktual:=m;
				  end;
				 51:if sx=yes then crc_checking:=true else crc_checking:=false;
				 53:check_lan(snd_fireball,sx);
				 54:check_lan(snd_fir,sx);
				 57:check_lan(snd_change,sx);
				 58:begin
					  mov_num2(sx,scan_x1,count);
					  mov_num2(sx,scan_x2,count);
					  mov_num2(sx,scan_y1,count);
					  mov_num2(sx,scan_y2,count);
				   end;
				  59:load_priechod(sx);
				  60:if sx=yes then smart_jump:=true
				     else smart_jump:=false;
				  61:load_vytahy(sx);
{SNDX}			  62:begin
					 mov_num(sx,m,count);
					 mov_string(sx,sc,count);
					 zvuky[m+basic_snd]:=sc;
					if zvuk_loaded then
					 reload_sound(m+basic_snd-1,zvukovy_subor,zvuky[m+basic_snd]);
				  end;
                          63:begin
                                  val(sx,m,m);
                                  start_stage:=m;
                             end;
                          64:begin         {SETFREEZ}
                                  begin
                                    val(sx, m, m);
                                    freez_time := m;
                                    mov_num2(sx,unfreez_sound,count);
                                  end;
                             end;
                           65:begin         {SETGOD}
                                  begin
                                    val(sx, m, m);
                                    god_time := m;
                                    mov_num2(sx,ungod_sound,count);
                                  end;
                              end;
                           66:start_action:=value(sx);
			  end; end; end;

		     end else begin
  end;
   if bl then begin
	if (cxa>maxbuf) or (arr^[cxa]=0) then stop:=true;
   end
   else
	if eof(t) then stop:=true;
	until stop;
   if not bl then close(t)
   else begin
     dispose(arr);
   end;
  end;
   if reloaded then load_map(aktual);
   if aktual>1 then miestnost:=aktual+126 else miestnost:=1;
end;

procedure load_predmet;
begin
{     if not handles[2].used then create_handle(handles[2],vec_count*256);}
     draw_it(veci,0,0);
 for ff:=0 to 11 do begin
  for f:=0 to 19 do begin
	getsegxms(handles[4],f*resx,ff*resy,resx,resy,f+ff*20);
  end;
 end;
  for f:=0 to 14 do
	getsegxms(handles[4],f*resx,ff*resy,resx,resy,f+400);
end;

procedure print_predmet;
var wq:word;
begin
   for wq:=1 to nahrane_veci do begin
	if vec^[wq].meno[2]='N' then begin
	  getseg(vec^[wq].x,vec^[wq].y,16,16,0,vec^[wq].zas);
	  vec^[wq].ox:=vec^[wq].x;
	  vec^[wq].oy:=vec^[wq].y;
	end;
   end;
	clear_key_buffer;
   for wq:=1 to nahrane_veci do begin
     if (vec^[wq].meno[2]='N') and (vec^[wq].visible) and (vec^[wq].mie=miestnost) then
	  putseg2xms(handles[4],vec^[wq].x,vec^[wq].y,resx,resy,vec^[wq].obr,13);
    end;
	clear_key_buffer;
   for wq:=1 to nahrane_veci do begin
	if vec^[wq].meno[2]='A' then begin
	  getseg(vec^[wq].x,vec^[wq].y,16,16,0,vec^[wq].zas);
	  vec^[wq].ox:=vec^[wq].x;
	  vec^[wq].oy:=vec^[wq].y;
	end;
   end;
   for wq:=1 to nahrane_veci do begin
     if (vec^[wq].meno[2]='A') and (vec^[wq].visible) and (vec^[wq].mie=miestnost) then
	  putseg2xms(handles[4],vec^[wq].x,vec^[wq].y,resx,resy,vec^[wq].obr,13);
    end;
end;

procedure reprint_predmet(num:byte);
var f,ff:byte;
begin
     vypni_charakter(si.oldx+px,si.oldy+py,si.buf,ar^);
	for f:=nahrane_veci downto 1 do begin
	clear_key_buffer;
	  if (vec^[f].visible) and (vec^[f].mie=miestnost) and (f<>num) then
		putseg(vec^[f].x,vec^[f].y,resx,resy,0,vec^[f].zas);
	  end;
     vypni_charakter(si.oldx+px,si.oldy+py,si.buf,ar^);
	print_predmet;
	 si.oldx:=si.x;
	 si.oldy:=si.y;
	init_charakter(resx,resy,si.oldx+px,si.oldy+py,poloha,si.buf,ar^);
end;

procedure print_predmet2;
var wq:integer;
begin
{   check_visible2;}
   for wq:=1 to nahrane_veci do begin
	clear_key_buffer;
     if (vec^[wq].mie=miestnost) and (vec^[wq].visible) then
	  putseg2xms(handles[4],vec^[wq].x,vec^[wq].y,resx,resy,vec^[wq].obr,13);
   end;
end;


procedure zisti_vec;
var vecicka		: boolean;
    counx		: integer;
    sco,nux,ff	: word;
    najdene,use_lift : boolean;
    xx,yy         : word;
label skip;
begin
   najdene:=true;
   vecicka:=false;
   if si.y+py>14 then yy:=si.y+py-14 else yy:=0;
   if si.x+px>14 then xx:=si.x+px-14 else xx:=0;
   for f:=1 to nahrane_veci do begin
	 if (vec^[f].mie=miestnost) and (si.x+px16 >= vec^[f].x) and (xx <= vec^[f].x)
	    and (yy <= vec^[f].y) and (si.y+py16 >= vec^[f].y) then begin
	    vecicka:=true;
	    clr:=true;
	    mov:=f;
	    goto skip;
	 end
	 else mov:=0;
   end;

skip:
   if (not vecicka) and (clr) then begin
    {  noline;}
	clr:=false;
	mov:=0; oldmov:=0;
   end;
	    if (oldmov<>mov) and (clr)then begin
		 oldmov:=mov;
		clr:=false;
	    end;

{zistuje ci sa tam nachadza zobratelna vec}
   if (vec^[mov].meno[1]='Y') then begin
	 use_vec(mov);
   end;

   if (vec^[mov].take=3) and (not the_koniec) then
   begin
   vypni_charakter(si.x+px,si.y+py,si.buf,ar^);

   for ff:=1 to nahrane_veci do begin
	 if (ff<>mov)and(vec^[ff].meno[2]='A') and (vec^[ff].visible) and (vec^[ff].mie=miestnost)
	    and (vec^[mov].x>vec^[ff].ox-resx)
	    and (vec^[mov].x<vec^[ff].ox+resx) and (vec^[mov].y>vec^[ff].oy-resy)
	    and (vec^[mov].y<vec^[ff].oy+resy) then    begin
	    putseg(vec^[ff].ox,vec^[ff].oy,resx,resy,0,vec^[ff].zas);
	    end;
   end;

   putseg(vec^[mov].x,vec^[mov].y,16,16,0,vec^[mov].zas);
   for ff:=1 to nahrane_veci do begin
	 if (ff<>mov)and (vec^[ff].meno[2]='A') and (vec^[ff].visible) and (vec^[ff].mie=miestnost)
	    and (vec^[mov].x>vec^[ff].ox-resx)
	    and (vec^[mov].x<vec^[ff].ox+resx) and (vec^[mov].y>vec^[ff].oy-resy)
	    and (vec^[mov].y<vec^[ff].oy+resy) then begin
	    getseg(vec^[ff].ox,vec^[ff].oy,resx,resy,0,vec^[ff].zas);
	    putseg2(vec^[ff].x,vec^[ff].y,resx,resy,anic+anx[vec^[ff].obr],13,anim^);
	 end;
   end;
	  sco:=vec^[mov].inf1;
	  score:=score+sco;
	  vypis_skore;
	  vec^[mov].mie:=2;
	  mov:=0;
	if not ok then begin
	  case completer of
		 0:najdene:=false;
		 1:for nux:=1 to nahrane_veci do begin
			 if (vec^[nux].meno[1]='Z') and
			    ((vec^[nux].mie<>0) and (vec^[nux].mie<>2)) then
			 najdene:=false;
		 end;
		 2:for nux:=1 to nahrane_veci do begin
			 if (vec^[nux].meno[1]='Z') and
			    ((vec^[nux].mie<>0) and (vec^[nux].mie<>2))
			     and((vec^[nux].meno[4]>='A') and (vec^[nux].meno[4]<='Z'))
				  then
			 najdene:=false;
		 end;
	  end;
	end;
 init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^);

   if  najdene and not ok then
	begin accomplish;
		ok:=true;
	end
   else
   pust(1);
 end;


 for f:=1 to pocet_priechodov do begin {kontorluje priechody}
     if (priechody^[f].mie1=aktual) and (priechody^[f].used) then begin
	  if (priechody^[f].x1<si.x) and (priechody^[f].x2>si.x) and
	     (priechody^[f].y1<si.y) and (priechody^[f].y2>si.y) then begin
		 transfer_to_new_stage(priechody^[f].mie2,priechody^[f].cx,priechody^[f].cy,true);
		 break;
	     end;
     end;
 end;

 lifting:=false;  {vypne vytah - reaguje na gravitaciu}
 use_lift:=false;

 for f:=1 to pocet_vytahov do begin {kontorluje vytahy}
     if (lift^[f].mie=aktual) and (lift^[f].used) then begin
	  if (lift^[f].x1<si.x) and (lift^[f].x2>si.x) and
	     (lift^[f].y1<si.y) and (lift^[f].y2>si.y) then begin
		   case lift^[f].smer of
			  1:if lift^[f].y1+lift^[f].rychlost<si.y then use_lift:=true;
			  2:if lift^[f].y2-lift^[f].rychlost>si.y then use_lift:=true;
			  3:if lift^[f].x1+lift^[f].rychlost<si.x then use_lift:=true;
			  4:if lift^[f].x2-lift^[f].rychlost>si.x then use_lift:=true;
		   end;
		   if use_lift then pouzi_vytah(lift^[f].smer,lift^[f].rychlost);
		     lifting:=true;
	     end;
     end;
 end;
end;

procedure load_texture;
var
  resolved_name: string;
begin
  writeln('[MAP_TILES] Loading map tiles as GPU textures...');
  writeln('[MAP_TILES] Starting with textura="', textura, '"');

  { Resolve variable reference if textura starts with '>' }
  resolved_name := textura;
  if (length(textura) > 0) and (textura[1] = '>') then
  begin
    resolved_name := out_string(textura);
    writeln('[MAP_TILES] Resolved textura "', textura, '" to "', resolved_name, '"');
  end;

  { Load tiles as GPU textures using Raylib (same method as GLIST and avatar) }
  if not blockx.load_map_tiles_textures(zvukovy_subor, resolved_name, 16, 16, 190, map_tile_textures) then
  begin
    writeln('[MAP_TILES] ERROR: Failed to load map tiles');
    map_tiles_loaded := False;
    exit;
  end;

  writeln('[MAP_TILES] Successfully loaded 190 map tile textures');
  map_tiles_loaded := True;
  writeln('[MAP_TILES] Complete!');

  { Load object textures after map tiles }
  LoadObjectTextures;
end;

procedure noline2;
begin
   printx2(screen,vypisx,vypisy,cl+'    ',62,1,1,1,0);
end;

procedure print_texture;
var pes:integer;
    s:string;
begin
 { CPU rendering only - GPU rendering happens in RenderMapTiles() called from game loop }
 if te = nil then begin
   writeln('WARNING: print_texture called with nil te array');
   Exit;
 end;

 case st.stav of
  1,3,5:begin
   for f:=0 to mie_x do begin
    clear_key_buffer;
    for ff:=0 to mie_y do begin
      if (st.mie[f,ff]<invisible) then
       putseg2(f*16,ff*16,resx,resy,st.mie[f,ff],0,te^);
      if bl<>nil then bl^[f,ff]:=true;
    end;
   end;
   if (bl<>nil) and (st.stav=3) then st.stav:=2;
  end;
  2,4:begin
   if bl<>nil then begin
     for f:=0 to mie_x do begin
      for ff:=0 to mie_y do begin
       if (bl^[f,ff]) and (st.mie[f,ff]<invisible) then
         putseg2(f*16,ff*16,resx,resy,st.mie[f,ff],0,te^);
      end;
     end;
   end;
  end;
 end;

 { noline2;}
 if st.meno[1]='>' then begin
    s:=st.meno;
    st.meno:=out_string(s);
 end;
 pes:=70-(length(st.meno)*4);
 s:=tx[ja,20]+st.meno;
 printc(screen,vypisy-9,s,15,0);
 printc(screen,vypisy-27,sprava,60,1);
 draw_lifes;
end;

{ Render map tiles using Raylib GPU textures
  This must be called AFTER ClearBackground() in the rendering loop
  Same approach as RenderMenuFrame() for GLIST tiles
}
procedure RenderMapTiles;
var
  tile_idx: integer;
begin
  if not map_tiles_loaded then
    exit;

  { Render tiles based on game state }
  { Original DOS game had 8px horizontal offset for CRT border compensation }
  case st.stav of
    1,3,5:begin
      for f:=0 to mie_x do begin
        for ff:=0 to mie_y do begin
          tile_idx := st.mie[f,ff];
          if (tile_idx < invisible) and (tile_idx >= 0) and (tile_idx < 190) then
            DrawTexture(map_tile_textures[tile_idx], f*16 + 8, ff*16, $FFFFFFFF);
          if bl<>nil then bl^[f,ff]:=true;
        end;
      end;
      if (bl<>nil) and (st.stav=3) then st.stav:=2;
    end;
    2,4:begin
      if bl<>nil then begin
        for f:=0 to mie_x do begin
          for ff:=0 to mie_y do begin
            tile_idx := st.mie[f,ff];
            if (bl^[f,ff]) and (tile_idx < invisible) and (tile_idx >= 0) and (tile_idx < 190) then
              DrawTexture(map_tile_textures[tile_idx], f*16 + 8, ff*16, $FFFFFFFF);
          end;
        end;
      end;
    end;
  end;
end;

{ ========================================
   OBJECT TEXTURE LOADING AND RENDERING
   ======================================== }

procedure LoadObjectTextures;
var
  success: boolean;
  frame_count: word;
begin
  writeln('[OBJECT] Loading object textures...');

  { Initialize all textures to invalid state }
  object_textures_loaded := false;
  static_object_textures_loaded := false;
  animated_object_textures_loaded := false;

  { Load static object spritesheet from GVECI }
  writeln('[OBJECT] Loading static objects from GVECI resource...');
  success := load_gif_spritesheet_textures(zvukovy_subor, 'GVECI', 16, 16,
                                           object_textures, frame_count);

  if success then
  begin
    static_object_textures_loaded := true;
    writeln('[OBJECT] Successfully loaded ', frame_count, ' static object textures from GVECI');
  end
  else
  begin
    writeln('[OBJECT] WARNING: Failed to load static object textures from GVECI');
  end;

  { Load animated object spritesheet from GANIM }
  writeln('[OBJECT] Loading animated objects from GANIM resource...');
  success := load_gif_spritesheet_textures(zvukovy_subor, 'GANIM', 16, 16,
                                           animated_object_textures, frame_count);

  if success then
  begin
    animated_object_textures_loaded := true;
    writeln('[OBJECT] Successfully loaded ', frame_count, ' animated object textures from GANIM');
  end
  else
  begin
    writeln('[OBJECT] WARNING: Failed to load animated object textures from GANIM');
  end;

  { Set overall loaded flag if at least one type loaded }
  object_textures_loaded := static_object_textures_loaded or animated_object_textures_loaded;
end;

procedure DrawObject(idx: word; frame_counter: longint);
var
  sprite_idx: word;
  texture: TRaylibTexture2D;
  anim_frame: byte;
  final_sprite_idx: word;
  dest_x, dest_y: single;
  use_animated_textures: boolean;
begin
  { Debug: Log all objects on frame 60 (once at startup) }
  if (frame_counter = 60) then
    writeln('[OBJECT] idx=', idx, ' visible=', vec^[idx].visible, ' mie=', vec^[idx].mie,
            ' current_room=', miestnost, ' obr=', vec^[idx].obr, ' useanim=', vec^[idx].useanim);

  { Skip invisible objects }
  if not vec^[idx].visible then
    exit;

  { Check room - only show objects in current room }
  if vec^[idx].mie <> miestnost then
    exit;

  { Get base texture index (object ID) }
  sprite_idx := vec^[idx].obr;

  { Determine which texture array to use }
  use_animated_textures := vec^[idx].useanim and animated_object_textures_loaded;

  { Calculate animation frame }
  if vec^[idx].useanim and animated_object_textures_loaded then
  begin
    { Animation cycles through 4 frames: (sprite_idx * 4) to (sprite_idx * 4 + 3) }
    { Example: object ID 6 → frames 24, 25, 26, 27 }
    anim_frame := (frame_counter div 6) mod 4;  { Slower: div 6 instead of div 3 }
    final_sprite_idx := (sprite_idx * 4) + anim_frame;

    { Check if animation frame is available }
    if (final_sprite_idx >= 190) then
    begin
      { Animation frames not available, fall back to static }
      final_sprite_idx := sprite_idx;
      use_animated_textures := false;
      if (frame_counter = 60) then
        writeln('[OBJECT] idx=', idx, ' Animation frame ', anim_frame, ' (sprite_idx*4+', anim_frame, ' = ', final_sprite_idx, ') not available, using static texture');
    end;
  end
  else
  begin
    anim_frame := 0;
    final_sprite_idx := sprite_idx;
  end;

  { Validate sprite index }
  if (sprite_idx >= 190) or (not object_textures_loaded) then
  begin
    if (frame_counter = 60) then
      writeln('[OBJECT] Skipping idx=', idx, ' invalid sprite_idx=', sprite_idx,
              ' textures_loaded=', object_textures_loaded);
    exit;
  end;

  { Get texture from appropriate array }
  if use_animated_textures then
    texture := animated_object_textures[final_sprite_idx]
  else if static_object_textures_loaded then
    texture := object_textures[final_sprite_idx]
  else
  begin
    if (frame_counter = 60) then
      writeln('[OBJECT] Skipping idx=', idx, ' no textures loaded');
    exit;
  end;

  { Destination position - vec^.x and vec^.y are already in pixel coordinates }
  dest_x := vec^[idx].x;
  dest_y := vec^[idx].y;

  { Debug log when actually drawing }
  if (frame_counter = 60) then
  begin
    write('[OBJECT] Drawing idx=', idx, ' at (', trunc(dest_x), ', ', trunc(dest_y),
            ') sprite_idx=', sprite_idx, ' anim_frame=', anim_frame, ' final_sprite=', final_sprite_idx,
            ' texture_type=');
    if use_animated_textures then
      writeln('ANIMATED (sprite_idx*4+', anim_frame, ')')
    else
      writeln('STATIC');
  end;

  { Draw using Raylib - use entire texture (16x16) }
  DrawTexture(texture, trunc(dest_x), trunc(dest_y), $FFFFFFFF);
end;

procedure DrawAllObjects(frame_counter: longint);
var
  i: word;
begin
  if not object_textures_loaded then
  begin
    { Debug: Log once per second (every 60 frames) }
    if (frame_counter mod 60) = 0 then
      writeln('[OBJECT] Textures not loaded, skipping object render');
    exit;
  end;

  { Draw all loaded objects }
  for i := 1 to nahrane_veci do
  begin
    DrawObject(i, frame_counter);
  end;
end;

procedure set_freez(var vec:predmet);
begin
           if freez_time+vec.inf1<255 then inc(freez_time,vec.inf1) else
              freez_time:=254;
           unfreez_sound:=vec.z2;
end;

procedure set_god(var vec:predmet);
begin
           if god_time+vec.inf1<255 then inc(god_time,vec.inf1) else
              god_time:=254;
           ungod_sound:=vec.z2;
end;

procedure use_vec(mov:word);    {pouzije vec}
begin
  case vec^[mov].funk of
    1:begin 		{TELEPORT}
	  vypni_charakter(si.oldx+px,si.oldy+py,si.buf,ar^);
	  PUST(2);
	  decrease_palette(palx,20);
	  increase_palette(blackx,palx,20);
	  si.x:=vec^[mov].inf1*8+8;
	  si.y:=vec^[mov].inf2*8+8;
	  rewait;
     end;
    6:begin			{objavenie/zmiznutie textury}
	    zhasni;
	    zhasni_vec(vec^[mov]);
	    vec^[mov].mie:=2;
	    for f:=(vec^[mov].inf1 div 2) to (vec^[mov].inf3 div 2)do begin
		for ff:=(vec^[mov].inf2 div 2) to (vec^[mov].inf4 div 2)do begin
		    st.mie[f,ff+1]:=vec^[mov].inf5;
		end;
	    end;
	    redraw(true);
	    reload_sound(3,zvukovy_subor,snd_objav);
	    PUST(3);
	    rozsviet;
	    rewait;
	end;
    7:begin            {objavenie predmetov}
	    zhasni;
	    zhasni_vec(vec^[mov]);
	    vec^[mov].mie:=2;
	    for f:=1 to nahrane_veci do begin
		if vec^[f].meno[4]=char(vec^[mov].inf1) then begin
		  vec^[f].mie:=miestnost;
		end;
	    end;
	    redraw(true);
{	    reprint_predmet(0);}
	    reload_sound(3,zvukovy_subor,snd_appear);
	    PUST(3);
	    rozsviet;
	    rewait;
	end;
    8:begin              {zmiznu veci}
	  zhasni;
	  zhasni_vec(vec^[mov]);
	  vec^[mov].mie:=2;
	  for f:=1 to nahrane_veci do begin
	    if vec^[f].meno[4]=char(vec^[mov].inf1) then begin
		 vec^[f].mie:=2;
	    end;
	 end;
	 redraw(true);
{	 reprint_predmet(0);}
	 reload_sound(3,zvukovy_subor,snd_appear);
	 PUST(3);
	 rozsviet;
	 rewait;
	end;
    9:accomplished;     {hotovo}
    10:begin            {prida zivot}
	    zhasni_vec(vec^[mov]);
	    inc(zivoty,vec^[mov].inf1);
	    vec^[mov].mie:=2;
	    draw_lifes;
	    reload_sound(3,zvukovy_subor,snd_zivot);
	    PUST(3);
	    rewait;
	  end;
     11:if bl<>nil then begin {zobrazuje casti bludiska}
	    zhasni_vec(vec^[mov]);
	    vec^[mov].mie:=2;
	    case vec^[mov].inf1 of
		 0:begin
			for f:=0 to mie_x do
			  for ff:=0 to mie_x do
				  bl^[f,ff]:=false;
		   end;
		 1:begin
		     for f:=0 to mie_x do
			  for ff:=0 to mie_x do
			    bl^[f,ff]:=true;
		   end;
		 2:begin
		    for f:=vec^[mov].inf2 to vec^[mov].inf4 do
			for ff:=vec^[mov].inf3 to vec^[mov].inf5 do
			  bl^[f,ff]:=false;
		   end;
		 3:begin
		    for f:=vec^[mov].inf2 to vec^[mov].inf4 do
			for ff:=vec^[mov].inf3 to vec^[mov].inf5 do
			  bl^[f,ff]:=true;
		   end;
		 end;
		reload_sound(3,zvukovy_subor,snd_maze);
		PUST(3);
		decrease_palette(palx,10);
		redraw(true);
		for f:=1 to nahrane_veci do begin
		    vec^[f].visible:=false;
		end;
		increase_palette(blackx,palx,10);
		rewait;
	    end;
    13:begin            {zhanse jednu uroven, rozsvieti druhu}
	    zhasni;
	    zhasni_vec(vec^[mov]);
	    for f:=1 to nahrane_veci do begin
		if vec^[f].meno[4]=char(vec^[mov].inf1) then begin
		  vec^[f].mie:=2;
		end;
	    end;
	    for f:=1 to nahrane_veci do begin
		if vec^[f].meno[4]=char(vec^[mov].inf2) then begin
		  vec^[f].mie:=miestnost;
		end;
	    end;
	    vec^[mov].mie:=2;
	    redraw(true);
	    reprint_predmet(0);
	    reload_sound(3,zvukovy_subor,snd_appear);
	    PUST(3);
	    rozsviet;
	    rewait;
	 end;
	14:begin           {prechod do druhej miestnosti}
	    transfer_to_new_stage(vec^[f].inf1,vec^[f].inf2,vec^[f].inf3,false);
	end;
     19:begin            {MRAZAK 1; god 2; mix 3}
	    zhasni_vec(vec^[mov]);
          efekt_count:=0;
          pust_extra(vec^[f].z1);
          case vec^[f].inf2 of
            1: set_freez(vec^[f]);
            2: set_god(vec^[f]);
            3: begin
                    set_freez(vec^[f]);
                    set_god(vec^[f]);
                    if freez_time=god_time then unfreez_sound:=0;
               end;
            end;
          vec^[f].mie:=2;
	 end;
    end;
  if ((vec^[mov].meno[3]='D') or ((vec^[mov].meno[3]='S') and (god_time=0)))
     and (not the_koniec) then strata_zivota;
end;


procedure vypis_skore; {Vypise skore}
var sco:string;
    rozdiel:word;
begin
 if (basic_score<>score) and (not soundplaying(0)) then begin
    rozdiel:=(score-basic_score) div 5;
    if rozdiel=0 then rozdiel:=1;
    inc(basic_score,rozdiel);
    str(basic_score,sco);
    okno(498,vypisy-26,64,16,0);
    pust(0);
  print_normal(screen_image,498,vypisy-26,sco,69,1);
 end;
end;

procedure accomplish;                 {zobrazi ukoncovac, ak uz su vyzbierane predmety}
begin
     reload_sound(3,zvukovy_subor,snd_acces);
     for f:=1 to nahrane_veci do
		 if vec^[f].meno[4]='~' then begin
		    vec^[f].mie:=1;
		    zobraz_vec(vec^[f]);
		     end;
     pust(3);
     rewait;
end;

procedure draw_lifes;
var f,zn:byte;
begin
 { writeln('draw_lifes: Drawing ', zivoty, ' lives'); }
 try
  { str(zivoty,s); }
  { rectangle2(screen_image,450,vypisy-9,120,16,0); }
  { print_normal(screen_image,450,vypisy-9,tx[ja,8]+s,63,1); }
  if zivoty<5 then zn:=zivoty else zn:=5;
  { writeln('draw_lifes: Drawing ', zn, ' life icons (skipped rectangle2 and print_normal)'); }
  for f:=1 to zn do begin
    { writeln('  draw_lifes: Life ', f, ' at x=', 508+f*16); }
    putseg2(508+f*16,vypisy-9,resx,resy,f-1,13,ar^);
  end;
  { writeln('draw_lifes: Complete'); }
 except
  on E: Exception do begin
    writeln('ERROR in draw_lifes: ', E.Message);
    writeln('  Exception at f=',f);
    raise;
  end;
 end;
end;

procedure rewait;           {nastavy cakaci cyklus na novy cas}
begin
     time:=getclock+wait_point;
end;

procedure odomkni_dvere(x,y:word);   {odomkne dvere vec}
var f,o:word;
begin
   vypni_charakter(si.oldx+px,si.oldy+py,si.buf,ar^);
	for f:=1 to nahrane_veci do begin
	  if (vec^[f].visible) and (vec^[f].mie=miestnost) then
		putseg(vec^[f].x,vec^[f].y,resx,resy,0,vec^[f].zas);
	  end;
    if st.mie[x,y]=0 then
	 rectangle2(screen_image,x*16+8,y*16,resx,resy,0);
    putseg2(x*16+8,y*16,resx,resy,st.mie[x,y],13,te^);
	for f:=1 to nahrane_veci do begin
	  if (vec^[f].visible) and (vec^[f].mie=miestnost) then
		getseg(vec^[f].x,vec^[f].y,resx,resy,0,vec^[f].zas);
	  end;
     print_predmet2;
   si.oldx:=si.x;
   si.oldy:=si.y;
   init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^);
end;

procedure zhasni_vec(var pr:predmet);   {zhasne vec}
var f,o:word;
begin
   vypni_charakter(si.oldx+px,si.oldy+py,si.buf,ar^);
	for f:=nahrane_veci downto 1 do begin
	  if (vec^[f].meno[1]<>'Z') and (vec^[f].visible) and (vec^[f].mie=miestnost) then
		putseg(vec^[f].x,vec^[f].y,resx,resy,0,vec^[f].zas);
	  end;
    putseg(pr.x,pr.y,16,16,0,pr.zas);
    o:=pr.mie;
    pr.mie:=2;
	for f:=1 to nahrane_veci do begin
	  if (vec^[f].meno[1]<>'Z') and (vec^[f].visible) and (vec^[f].mie=miestnost) then
		getseg(vec^[f].x,vec^[f].y,resx,resy,0,vec^[f].zas);
	  end;
     print_predmet2;
     pr.mie:=o;
   si.oldx:=si.x;
   si.oldy:=si.y;
   init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^);
end;

procedure check_visible(get_back:boolean);
var f:word;
begin
 {skontroluje, ci je dany predmet vidiet}
 writeln('[CHECK_VISIBLE] Starting visibility check for ', nahrane_veci, ' objects, st.stav=', st.stav);
 case st.stav of
{ if (st[1].stav=2) and (bl<>nil) then}
	2,4:begin
	    for f:=1 to nahrane_veci do begin
		    if (bl^[(vec^[f].x-8) div 16,vec^[f].y div 16]) or
			   ((vec^[f].funk=9) and (vec^[f].inf1=1) and
			   (vec^[f].mie=miestnost)) then begin
			  if (not vec^[f].visible) then begin
				  if (vec^[f].meno[2]='N') and (get_back) then
					  getseg(vec^[f].x,vec^[f].y,16,16,0,vec^[f].zas);
				  vec^[f].change:=true;
			  end;
			  vec^[f].visible:=true;
			  end
			  else begin
			   if vec^[f].visible then vec^[f].change:=true;
			   vec^[f].visible:=false;
			  end;
	    end;
	    writeln('[CHECK_VISIBLE] Maze mode: Processed visibility for ', nahrane_veci, ' objects');
	end;
	1,3,5:begin
	    { Platformer mode - make all objects in current room visible }
	    for f:=1 to nahrane_veci do begin
		    if vec^[f].mie = miestnost then begin
			    vec^[f].visible := true;
			    writeln('[CHECK_VISIBLE] Platformer mode: Object ', f, ' (', vec^[f].meno, ') in room ', miestnost, ' set to VISIBLE');
		    end;
	    end;
	    writeln('[CHECK_VISIBLE] Platformer mode: Made objects in room ', miestnost, ' visible');
	end;
 end;
end;

procedure set_old_pos;  {nastavi priserky na ich zaciatocnu suradnicu}
var f:word;
begin
	for f:=1 to nahrane_veci do begin
		if (vec^[f].mie=miestnost) and (vec^[f].meno[3]='S') then begin
		  vec^[f].x:=vec^[f].oox;
		  vec^[f].y:=vec^[f].ooy;
		  vec^[f].ox:=vec^[f].oox;
		  vec^[f].oy:=vec^[f].ooy;
		  if bl<>nil then begin
			check_visible(false);
		  end;
		end;
	end;
end;

procedure get_gif;
begin
    if st.obr<>none then begin
        writeln('get_gif: Loading "', st.obr, '" at (', obrazok_x, ',', obrazok_y, ')');
        { Defensive: Check if st.obr is empty }
        if st.obr = '' then begin
            writeln('get_gif: ERROR - st.obr is empty string!');
            Exit;
        end;
        draw_it(st.obr,obrazok_x,obrazok_y);
        obrazok_dx:=gif_x;
        obrazok_dy:=gif_y;
        kill_handle(handles[6]);
        if (gif_x>0) and (gif_y>0) then
           create_handle(handles[6],gif_x*gif_y);
        getsegxms(handles[6],obrazok_x,obrazok_y,obrazok_dx,obrazok_dy,0);
    end else
        writeln('get_gif: st.obr is NONE, skipping');
end;

procedure stage_image(num:word);	{vykresli obrazok v danej miestnosti}
begin
    { writeln('stage_image: Starting for num=', num); }
    { writeln('stage_image: st.obr="', st.obr, '"'); }

    { Defensive: Skip if st.obr is empty }
    if (st.obr = '') then begin
      writeln('stage_image: WARNING - st.obr is empty string!');
      writeln('stage_image: Setting to NONE and skipping');
      st.obr := none;
      clear_key_buffer;
      { writeln('stage_image: Complete'); }
      Exit;
    end;

    {ak doslo k zmene obrazka}
    { writeln('stage_image: Checking if image changed...'); }

    { Skip background image loading if handles[3] not initialized with data }
    { This happens when no background images are loaded yet }
    try
      if vrat_nazov_obrazku(num) then begin
        { writeln('stage_image: Image changed, calling get_gif...'); }
        get_gif
      end
      else begin
        { writeln('stage_image: Image not changed, checking handles[6]...'); }
        if not handles[6].used then begin
          { writeln('stage_image: handles[6] not used, calling get_gif...'); }
          get_gif
        end
        else begin
          { writeln('stage_image: handles[6] used, checking st.obr...'); }
          if st.obr<>none then begin
            { writeln('stage_image: Calling putsegxms for background image...'); }
            putsegxms(handles[6],obrazok_x,obrazok_y,obrazok_dx,obrazok_dy,0);
          end
          { else writeln('stage_image: st.obr is none, skipping'); }
        end;
      end;
    except
      on E: Exception do begin
        writeln('stage_image: Exception - ', E.Message, ' (', E.ClassName, ')');
        writeln('stage_image: Continuing without background image');
      end;
    end;

    clear_key_buffer;
    { writeln('stage_image: Complete'); }
end;

procedure help_line1;
var f     : byte;
begin
   for f:=1 to 3 do
    write_linepos(screen_image,lajna,40,428+f,250);
end;

procedure help_line2;
var f     : byte;
begin
   for f:=1 to 3 do
    write_linepos(screen_image,lajna,350,428+f,250);
end;

procedure redraw(param:boolean);
begin
 { writeln('redraw: Starting...'); }
 if param then begin
   { writeln('redraw: Clearing screen...'); }
   clear_bitmap(screen_image);
 end;
   clear_key_buffer;
    { writeln('redraw: Drawing stvorec2...'); }
    stvorec2(screen,0,416,639,62,20,0);
    { writeln('redraw: Setting lajna array (1)...'); }
    for f:=0 to 250 do lajna[f]:=1;
    { writeln('redraw: Calling help_line1...'); }
    help_line1;
    { writeln('redraw: Setting lajna array (197)...'); }
    for f:=0 to 250 do lajna[f]:=197;
    { writeln('redraw: Calling help_line2...'); }
    help_line2;
   { writeln('redraw: Calling stage_image...'); }
   stage_image(aktual);
   { writeln('redraw: Calling print_texture...'); }
   { Skip print_texture when using GPU rendering - tiles rendered by RenderMapTiles() instead }
   if not map_tiles_loaded then
     print_texture;
   clear_key_buffer;
  if param then begin
   { writeln('redraw: Calling print_predmet...'); }
   print_predmet
  end
  else begin
   { writeln('redraw: Calling print_predmet2...'); }
   print_predmet2;
  end;
   clear_key_buffer;
   { writeln('redraw: Calling redraw_score...'); }
   redraw_score;
   clear_key_buffer;
   { writeln('redraw: Calling vypis_skore...'); }
   vypis_skore;
   clear_key_buffer;
   { writeln('redraw: Calling reset_pol...'); }
   reset_pol;
   clear_key_buffer;
   { writeln('redraw: Calling draw_inventar...'); }
   draw_inventar;
   clear_key_buffer;
   { writeln('redraw: Calling getseg for player...'); }
   getseg(si.x+px,si.y+py,resx,resy,si.buf,ar^);
   { writeln('redraw: Complete!'); }
end;

procedure redraw3;
begin
 rectangle2(screen_image,0,0,640,416,0);
{    if st.obr<>'' then
     draw_gif(screen,st.obr,obrazok_x,obrazok_y,palx);}
   stage_image(aktual);
   { Skip print_texture when using GPU rendering - tiles rendered by RenderMapTiles() instead }
   if not map_tiles_loaded then
     print_texture;
   clear_key_buffer;
   print_predmet;
   clear_key_buffer;
   reset_pol;
   clear_key_buffer;
end;

procedure accomplished;       {hotovo, koniec miestnosti}
var pass,s,aniold:string;
    palz:^tpalette;
begin
    sace:=true;
    stop_all_sounds;
    if vybrane<levely^.pocet then begin
		 aniold:=flik_end;
		 load_predmet2(levely^.lev[vybrane+1].subor);
		 flik_end:=aniold;
	     s:=st.meno;
	     if s[1]='>' then s:=out_string(s);
		 pass:=s;
    old_frame_draw(265,190,5,2);
    napis_print(0,200,tx[ja,3]);
    napis2_print(0,218,pass);
    reload_sound(3,zvukovy_subor,snd_succes);
    stop_all_sounds;
    pust(3);
    pulzx(10);
    clear_key_buffer;
    kkey;
		 load_predmet2(levely^.lev[vybrane].subor);
    stop_all_sounds;
    play_ani(flik_end);
    end
     else
     begin
    old_frame_draw(250,190,7,2);
    napis_print(0,200,tx[ja,4]);
    pass:=tx2[ja,1];
    napis2_print(0,218,pass);
    reload_sound(3,zvukovy_subor,snd_succes);
    pust(3);
    pulzx(10);
    kkey;
    decrease_palette(palx,150);
	  play_ani(flik_end);
	  write_palette(blackx,0,256);
	  reload_sound(3,zvukovy_subor,snd_theend);
		    if outro_obr[1]='>' then begin
			   s:=outro_obr;
			   outro_obr:=out_string(s);
		    end;
		    blockx.draw_gif_block(screen_image,zvukovy_subor,outro_obr,0,0,jxfont_simple.tpalette(palx));
    pust(3);
    sace:=false;
    menu_pointer:=levely^.pocet+1; {nastavy ukazovatel na Spat}
    increase_palette(blackx,palx,150);
    clear_key_buffer;
    kkey;
    decrease_palette(palx,150);
    clear_bitmap(screen_image);
    increase_palette(blackx,palx,50);
    insert_score;
    score:=0;
     end;
    the_koniec:=true;
end;

procedure zhasni;
begin
	 decrease_palette(palx,20);
end;

procedure rozsviet;
begin
	increase_palette(blackx,palx,20);
end;

procedure go_to_new_stage(mix,x,y:word);
begin
		save_map(aktual);
		load_map(mix);
		si.x:=x*8;
		si.y:=y*8+4;
		si.oldx:=si.x;
		si.oldy:=si.y;
		startx:=si.x;
		starty:=si.y;
		aktual:=mix;
		if mix>1 then miestnost:=126+mix
		else miestnost:=1;
		set_old_pos;
end;

procedure go_to_new_stage2(mix:byte;x,y:word);
begin
		if x>8 then si.x:=x;
		if y>8 then si.y:=y;
		si.oldx:=si.x;
		si.oldy:=si.y;
		startx:=si.x;
		starty:=si.y;
		save_map(aktual);
		load_map(mix);
		aktual:=mix;
		if mix>1 then miestnost:=126+mix
		else miestnost:=1;
		set_old_pos;
end;

procedure strata_zivota;
begin
non_key := False;
   freez_time := def_freez_time;
   god_time   := def_god_time;
   unfreez_sound := 0;
   ungod_sound   := 0;
   set_old_pos;
   if zivoty=0 then begin
	    the_koniec:=true;
	    restart:=true;
          old_frame_draw(250,190,7,2);
          napis_print(0,200,tx[ja,5]);
          napis2_print(0,218,'R. I. P.');
	    reload_sound(3,zvukovy_subor,snd_koniec);
	    pust(3);
	    pulzx(10);
	    kkey;
   end
   else begin
	    reload_sound(3,zvukovy_subor,snd_strata);
		pust2(3);
		    dec(zivoty);
		    si.x:=startx;
		    si.y:=starty;
		    si.oldx:=si.x;
		si.oldy:=si.y;
		 { load_predmet2;}
		rollup:=0;
		    decrease_palette(palx,10);
		    redraw(true);
		    increase_palette(blackx,palx,10);
		    play_ball;
		    init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^);
		rewait;
   end;  { end;}
end;

procedure zobraz_vec(var pr:predmet);
begin
   vypni_charakter(si.oldx+px,si.oldy+py,si.buf,ar^);
    getseg(pr.x,pr.y,16,16,0,pr.zas);
    putseg2xms(handles[4],pr.x,pr.y,16,16,pr.obr,13);
   si.oldx:=si.x;
   si.oldy:=si.y;
   init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^);
end;

procedure redraw_score;
var scoro:string;
begin
  str(basic_score,scoro);
  printx(screen,450,vypisy-26,tx[ja,21]+scoro,62,1);
end;


procedure reset_pol;
begin
	pad_pol:=0;
end;

procedure draw_inventar; {vykresli inventar}
var f:byte;
begin
    { writeln('draw_inventar: Drawing inventory'); }
    try
      { writeln('draw_inventar: Calling rectangle2...'); }
      rectangle2(screen_image,115,vypisy-9,3*35,resy,0);
      { writeln('draw_inventar: rectangle2 complete'); }
      { print_normal(screen_image,40,vypisy-9,tx[ja,27],15,0); }
      { writeln('draw_inventar: Drawing ', nahrane_veci, ' inventory items'); }
      for f:=1 to 3 do begin
        { writeln('draw_inventar: Slot ', f, ' own=', own[f]); }
        if own[f]=0 then begin
          { writeln('  Drawing from ar^, tile 45'); }
          putseg2(80+f*35,vypisy-9,resx,resy,45,13,ar^)
        end else begin
          { writeln('  Drawing from vec^[', own[f], '], obr=', vec^[own[f]].obr); }
          putseg2xms(handles[4],80+f*35,vypisy-9,resx,resy,vec^[own[f]].obr,13)
        end;
      end;
      { writeln('draw_inventar: Complete'); }
    except
      on E: Exception do begin
        writeln('ERROR in draw_inventar: ', E.Message);
        writeln('  Exception at f=',f);
        writeln('  own[1]=',own[1],' own[2]=',own[2],' own[3]=',own[3]);
        writeln('  ar allocated: ', ar<>nil);
        writeln('  handles[4] used: ', handles[4].used);
        raise;
      end;
    end;
end;

procedure play_ani(vstup:string);
var s,ss:string;
    fx,fy,f:word;
begin
if (length(vstup)>0) and (fli_abile) then begin
  create_handle(handles[6],resx*resy*textured+2+sir_nums*256);
  CopyCMemToXMem( handles[6].h, 0 , te, resx*resy*textured );
  CopyCMemToXMem( handles[6].h,  resx*resy*textured+1, ar, sir_nums*256 );
  dispose(te);
  dispose(ar);
  stop_all_sounds;
   count:=1;
   mov_string(vstup,s,count);
   mov_string(vstup,ss,count);
   if length(s)>0 then begin
    grafika_init(320,200,8);
tma := True;
    write_palette(blackx,0,256);
     setfont(@fontik,8,16);
    printc(screen,90,tx[ja,9],64,1);
    increase_palette(blackx,palx,20);
    pulz(18);
    decrease_palette(palx,10);
    clear_bitmap(screen_image);
    if (ss<>nos) then begin
	reload_sound(3,zvukovy_subor,ss);
	pust(3);
     end;
    aaplay(zvukovy_subor+','+s);
   stop_all_sounds;
   grafika_init(scrx,scry,8);
{   setfont(@fontik,8,16);}
    write_palette(blackx,0,256);
    set_font(def_font);
  end;
   new(te);
   new(ar);
   CopyXMemToCMem( te, handles[6].h, 0, 256*textured );
   CopyXMemToCMem( ar, handles[6].h, resx*resy*textured+1, sir_nums*256 );
   kill_handle(handles[6]);
 end;
end;

procedure insert_score;		{vlozi skore do tabulky}
var f,ff:word;
    fil:file;
    s:string;
begin
    for f:=1 to 10 do begin
		if score>hraci^[f].score then begin
		     reload_sound(3,zvukovy_subor,snd_score);
		     pust(3);
                 old_frame_draw(240,140,8,5);
                 napis_print(0,150,tx[ja,21]);
		     str(score,s);
                 napis2_print(0,170,s);
                 napis_print(250,200,tx[ja,2]);
		     s:=napis_input(0,220,11);
		     for ff:=10 downto f+1 do begin
			   hraci^[ff].meno:=hraci^[ff-1].meno;
			   hraci^[ff].score:=hraci^[ff-1].score;
		     end;
		     hraci^[f].meno:=s;
		     hraci^[f].score:=score;
		     break;
		    end;
    end;
    assign(fil,score_sub);
    rewrite(fil,1);
    for f:=1 to 10 do begin
		blockwrite(fil,hraci^[f],sizeof(hraci^[f]));
    end;
    close(fil);
end;

procedure stop_all_sounds;
begin
	for f:=0 to num_snd-1 do begin
		if geo.soundplaying(f) then geo.stopsound(f);
	end;
end;

procedure set_font(s:string);
begin
    if (s=def_font) or (s=def_font2) then begin
	 font_load_block(input_file,s,fx,fy)
    end
    else begin
	 font_load_block(zvukovy_subor,s,fx,fy)
    end;
end;

procedure export_texture(nx,ny:word);
var f:word;
begin
 if (not bl^[nx,ny]) and (st.mie[nx,ny]<invisible) then begin
  vypni_charakter(si.oldx+px,si.oldy+py,si.buf,ar^);
		putseg2(nx*16+8,ny*16,resx,resy,st.mie[nx,ny],13,te^);
  init_charakter(resx,resy,si.oldx+px,si.oldy+py,poloha,si.buf,ar^);
  bl^[nx,ny]:=true;
 end;
end;

procedure aktivuj_texturu;
var a,b,c,d,e,f:integer;
    x:word;
begin
 case st.stav of
  2,4: begin
    a:=(si.x-8) div 16;
    b:=(si.y+8)div 16;
    if (a-scan_x1)<0 then a:=scan_x1;
    if (b-scan_y1)<0 then b:=scan_y1;
    e:=a+scan_x2;
    f:=b+scan_y2;
    if e>mie_x then e:=mie_x;
    if f>mie_y then f:=mie_y;
  for c:=a-scan_x1 to e do begin {1,2}
   clear_key_buffer;
   for d:=b-scan_y1 to f do begin {1,1}
    if not bl^[c,d] then
	export_texture(c,d);
    end;
  end;
 end;
 end;
end;

procedure pust_extra(num:byte);
begin
    if num>0 then pust(basic_snd+num-1);
end;

procedure set_def;
var f:word;
begin
   freez_time     :=def_freez_time;
   god_time       :=def_god_time;
   outro_obr	:=def_outro_obr;
   snd_fir		:=def_snd_fir;
   snd_fireball	:=def_snd_fireball;
   invisible	:=def_invisible;
   snd_objav	:=def_snd_objav;
   typ_miestnost	:=1;
   snd_start	:=def_snd_start;
   snd_strata	:=def_snd_strata;
   snd_koniec	:=def_snd_koniec;
   snd_credit	:=def_snd_credit;
   snd_zober	:=def_snd_zober;
   snd_port		:=def_snd_port;
   snd_succes	:=def_snd_succes;
   snd_acces	:=def_snd_acces;
   snd_zmizni	:=def_snd_zmizni;
   snd_zivot	:=def_snd_zivot;
   snd_score	:=def_snd_score;
   snd_appear	:=def_snd_appear;
   snd_theend	:=def_snd_theend;
   completer	:=def_completer;
   intro_obr	:=def_intro_obr;
   outro_obr	:=def_outro_obr;
   snd_intro	:=def_snd_intro;
   snd_maze		:=def_snd_maze;
   snd_change	:=def_snd_change;
   scan_x1		:=dscan_x1;
   scan_x2		:=dscan_x2;
   scan_y1		:=dscan_y1;
   scan_y2		:=dscan_y2;
   flik_start	:='';
   flik_end		:='';
   timer		:=0;
   ok			:=false;
   st.stav		:=1;
   pohyby		:=def_pohyby;
   middle		:=true;
   anic		:=0;
   rerun;
   load_anim_def;
   inusable:=0;
   for f:=1 to 5 do
	msg[f]:='';
   for f:=1 to 3 do
	own[f]:=0;
end;

procedure rerun;
var fm:word;
begin
   krok:=5;
{   scroll_sub:=scroll_subor;}
   poloha:=0;
   si.buf:=sir_buf;
   rollup:=0;
   klast:=0;
   rx:=8;
   ry:=4;
   rp:=4;
   pom:=0;
   rolldown:=false;
   truth:=false;
   miestnost:=start;
   clr:=false;
   ani:=0;
   death:=false;
{   load_predmet2;}
   non:=false;
   st.stav:=0;
   oldmov:=0;
   cl:='     ';
   okraj:=false;
   non_key := False;

   { EXACT PORT from original LOAD235.PAS:703 }
   { Initialize handles[3] with default values for all levels }
   st.obr:=none;
   obrazok_x:=0;
   obrazok_y:=0;
   for fm:=1 to pocet_obr do
     uloz_nazov_obrazku(fm,st.obr,obrazok_x,obrazok_y);
   writeln('rerun: Initialized handles[3] for ', pocet_obr, ' levels with default "NONE"');
end;

procedure load_level_list(meno:string;var pole:array of byte);
var f,countx:word;
    s,sx,sd:string;
begin
					   for f:=0 to maxlen do pole[f]:=0;
					  openblockfile(meno);
					   loadblock_array(meno,def_config,pole);
					  closeblockfile;
					   for f:=0 to maxlen do begin
							if pole[f]<>0 then koder.dekoduj(1,pole[f]);
					   end;
					    countx:=0;
					    levely^.pocet:=0;
					    s:='';
					    repeat
							if pole[countx]>15 then begin
							   s:=s+chr(pole[countx]);
							end
							else if pole[countx]=13 then begin
									  get_name_normal(s,sx);
									  if sx='MENO' then begin
											  get_funk_normal(s,sx);
											  check_lan(data_disks^[num_disks].meno,sx);
									  end
									  else if (length(s)>0) and(s[1]='[') then begin
										     if not setup(s) then begin
											sd:='';
											if check_lan(sd,sx)=0 then
											  inc(levely^.pocet);
											  check_lan(levely^.lev[levely^.pocet].meno,sx);
											  get_funk_normal(s,sx);
											  check_lan(levely^.lev[levely^.pocet].subor,sx);
										     end;
									  end;
									  s:='';
					  end;
							inc(countx);
					    until (countx>maxlen) or (pole[countx]=0);
end;

function setup(fun:string):boolean;
var f,m	: word;
    funx	: string;
    sc	: string;
begin
			   setup:=false;
			   get_name(fun,funx);
		     for f:=1 to num_opt do begin
					   if funx=option[f] then begin
					   setup:=true;
				 get_funk(fun,funx);
					  case f of
						 5:if funx=yes then {zvuk:=true} {stub - sound enabled};
						 6:SND_CREDIT:=funx;
						 7:snd_zober:=funx;
						 9:zvukovy_subor:=funx;
						10:anim_file:=funx;
						11:snd_port:=funx;
						12:start_miestnost:=funx;
						15:textura:=funx;
						17:veci:=funx;
						18:anim_def:=funx;
						19:snd_objav:=funx;
						20:snd_start:=funx;
						21:snd_strata:=funx;
						22:snd_koniec:=funx;
						23:snd_succes:=funx;
						24:snd_acces:=funx;
						25:snd_zmizni:=funx;
						26:snd_intro:=funx;
						27:intro_obr:=funx;
						28:snd_appear:=funx;
						29:snd_theend:=funx;
						30:outro_obr:=funx;
						31:snd_score:=funx;
						32:snd_zivot:=funx;
						33:snd_maze:=funx;
						34:flik_start:=funx;
						35:flik_end:=funx;
						36:check_lan(msg[1],funx);
						37:check_lan(msg[2],funx);
						38:check_lan(msg[3],funx);
						39:check_lan(msg[4],funx);
						40:check_lan(msg[5],funx);
						41:val(funx,timer,timer);
						42:if funx=yes then fli_abile:=true else fli_abile:=false;
						43:begin
						     for ja:=1 to num_lang do begin
							if funx=language[ja] then break;
						     end;
						    end;
						 44:check_lan(scroll_sub,funx);
						 48:if funx=yes then test:=true else test:=false;
						 51:if funx=yes then crc_checking:=true else crc_checking:=false;
						 52:val(funx,inicializacna_pauza,inicializacna_pauza);
						 53:check_lan(snd_fireball,funx);
						 54:check_lan(snd_fir,funx);
						 55:if funx=yes then use_joystick:=true else use_joystick:=false;
						 56:begin
							check_lan(font,funx);
							set_font(font);
						    end;
						 57:check_lan(snd_change,funx);
						 58:begin
							mov_num2(funx,scan_x1,count);
							mov_num2(funx,scan_x2,count);
							mov_num2(funx,scan_y1,count);
							mov_num2(funx,scan_y2,count);
						 end;
						60:if funx=yes then smart_jump:=true
							else smart_jump:=false;
{SNDX}			            62:begin
							 mov_num(funx,m,count);
							 mov_string(funx,sc,count);
							 zvuky[m+basic_snd]:=sc;
							if zvuk_loaded then
							    reload_sound(m+basic_snd-1,zvukovy_subor,zvuky[m+basic_snd]);
						end;
                          63:begin
                                  val(funx,m,m);
                                  start_stage:=m;
                             end;
                          64:begin         {SETFREEZ}
                                  begin
                                    val(funx, m, m);
                                    freez_time := m;
                                    mov_num2(funx,unfreez_sound,count);
                                  end;
                             end;
                           65:begin         {SETGOD}
                                  begin
                                    val(funx, m, m);
                                    god_time := m;
                                    mov_num2(funx,ungod_sound,count);
                                  end;
                              end;

					  end;
					  break;
				 end;
		     end;
end;

begin
end.