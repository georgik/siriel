unit editing;
interface

uses txt,geo,jxgraf,animing,aktiv35,load235,jxmenu,blockx,xms2,crt,dos,jxxms,
     mouse,jxvar,vare;

function ano_nie(s:string):boolean;
procedure select_map;
procedure print_predmet_edit;
procedure clear_file(filter:boolean);
procedure draw_grid;
procedure redraw_editor;
procedure show_ovocie;
procedure show(sh:byte);
procedure nogrid;
procedure reload2(tr:integer);
procedure sub_c;  {vlozi ciarku do suboru}
procedure save_file;
function animated:char;
function smrted:char;
function edit(hladaj:string;var fond:word):boolean;
function into(nadpis:string;var jadro:string;dlzka:byte):string;
procedure vloz_funk(fund:word;sd:string;var vstup:string);
procedure vloz_funkciu(sd:string;var vstup:string);
procedure select_target(napis:string;var xx,yy:word);
procedure special_choice;
procedure select_predmet(napis:string;var textur:word);
procedure zmaz_ovocie;
function get_speed:byte;
function get_speed2(num:byte):byte;
function get_smer:byte;
procedure select_texture(napis:string;var textur:word);
procedure select_function(var f:word);
procedure vloz_ovocie;
procedure supra_edit;
procedure zmenkurzor(pol:integer);
procedure reload;
procedure load_textx;
procedure load_textx2(num:byte);
procedure load_predmet_editor2;
procedure vloz_komentar;
procedure edit_it;

implementation

var filter:boolean;

function ano_nie(s:string):boolean;
var mass:^jxmenu_typ;
    f:word;
begin
    ano_nie:=false;
    new(mass);
     save_scr(handles[2],219,170,120,120);
     init_jxmenu(220,180,15,12,0,s,mass^);
     size_jxmenu(100,100,mass^);
     vloz_jxmenu2(tx[ja,23],mass^,0);
     vloz_jxmenu2(tx[ja,24],mass^,0);
     vyber_jxmenu(mass^,f);
     if f=1 then ano_nie:=true;
     draw_scr(handles[2],219,170,120,120);
     kill_handle(handles[2]);
    dispose(mass);
    clear_key_buffer;
    rewait;
end;

procedure select_map;
begin
		    init_jxmenu(10,10,15,12,1,'Vyber mapu',med^);
		for f:=1 to num_maps do begin
		    str(f,s);
		    if maps[f] then
		    vloz_jxmenu2(s,med^,0);
		end;
		    vyber_jxmenu(med^,vyb);
		 if vyb>0 then begin
		    save_map(aktual);
		    load_map(vyb);
		    aktual:=vyb;
		 end;
end;

{vykresli definicne ciary pre jednotlive dtuhy predmetov}
procedure print_predmet_edit;
var wq:word;
begin
   for wq:=1 to pocet_veci do begin
   if (not filter) or ((filter) and (vec^[wq].meno[4]=chr(miestnost))) then begin
    if vec^[wq].meno[3]='S' then
	 line(screen,vec^[wq].x*8+8,vec^[wq].y*8+24,vec^[wq].x*8+24,vec^[wq].y*8+24,110);

    if vec^[wq].meno[2]='A' then
	 line(screen,vec^[wq].x*8+8,vec^[wq].y*8+8,vec^[wq].x*8+24,vec^[wq].y*8+8,63)
	 else
    if vec^[wq].meno[1]='X' then
	 line(screen,vec^[wq].x*8+8,vec^[wq].y*8+8,vec^[wq].x*8+24,vec^[wq].y*8+24,72)
	 else
    if vec^[wq].meno[1]='Y' then
	 line(screen,vec^[wq].x*8+8,vec^[wq].y*8+24,vec^[wq].x*8+24,vec^[wq].y*8+8,80);

    if vec^[wq].meno[1]='W' then
	 line(screen,vec^[wq].x*8+8,vec^[wq].y*8+8,vec^[wq].x*8+24,vec^[wq].y*8+24,15);

   if vec^[wq].meno[1]<>' ' then begin
     putseg2xms(handles[4],vec^[wq].x*8+8,vec^[wq].y*8+8,resx,resy,vec^[wq].obr,13);
     if vec^[wq].meno[1]<>'Z' then
	   prints(screen,vec^[wq].x*8+16,vec^[wq].y*8+8,2,2,char(vec^[wq].funk+33),14,0,0);

     if (vec^[wq].mie<>1) and (vec^[wq].meno[1]='Z') then
	   prints(screen,vec^[wq].x*8+8,vec^[wq].y*8+8,2,2,chr(vec^[wq].mie),15,0,0);
     if (vec^[wq].meno[4]<>'A') and ((vec^[wq].meno[1]='X') or (vec^[wq].meno[1]='Y'))
	  and (length(vec^[wq].meno)>2) then
	   prints(screen,vec^[wq].x*8+8,vec^[wq].y*8+8,2,2,(vec^[wq].meno[4]),15,0,0);
   end;
    end;
   end;
end;

procedure clear_file(filter:boolean);
begin
		if filter then  begin
		    init_jxmenu(10,10,15,12,1,'Co zmazat ?',med^);
		    vloz_jxmenu2('Vsetko',med^,0);
		    vloz_jxmenu2('Ovocie',med^,0);
		    vloz_jxmenu2('Material',med^,0);
		    vyber_jxmenu(med^,vyb);
		end
		else vyb:=1;
 if (vyb=1) or (vyb=2) then
   for f:=1 to pocet_veci do begin
	vec^[f].meno:='          ';
	vec^[f].mie:=0;
	vec^[f].x:=0;
	vec^[f].y:=0;
	vec^[f].obr:=0;
	vec^[f].st:=0;
	vec^[f].inf1:=0;
	vec^[f].inf2:=0;
	vec^[f].inf3:=0;
	vec^[f].inf4:=0;
	vec^[f].inf5:=0;
	vec^[f].inf6:=0;
	vec^[f].inf7:=0;
   end;

 if (vyb=1) or (vyb=3) then begin
   for f:=0 to mie_x do
     for ff:=0 to mie_x do
	   st.mie[f,ff]:=0;
  end;
 if (vyb=1) then begin
   for f:=1 to 100 do
	   zal^[f]:='';
  end;

end;

procedure draw_grid;
var f,ff:word;
begin
 for f:=0 to mie_x do
  line(screen,f*16+8,0,f*16+8,480,7);
  for ff:=0 to mie_y do
  line(screen,0,ff*16,640,ff*16,7);
end;

procedure redraw_editor;
var fx,ffx:word;
begin;
  print_normal(screen,10,420,'Specialne funkcie:',15,0);
  print_normal(screen,10,435,'Anim: '+anix+'<  Smrt: '+smrt+'<',63,1);
 if ma then print_normal(screen,10,450,'Ovocie',63,1)
    else print_normal(screen,10,450,'Material',63,1);
  print_normal(screen,70,450,'Typ: '+variant+'<',63,1);
  print_normal(screen,200,420,'Ovladanie: F1 - TEST',15,0);
  print_normal(screen,200,435,'TAB - Prep. obraz, F2 - Save, F3 - Load, F4 - Siet',14,0);
  print_normal(screen,200,450,'F8 - Vycisti, F9 - Typ edit., L-mys - Vloz, P-mys - Zmaz',10,0);
  print_normal(screen,250,465,'F5 - Edit, F10 - Options, ESC - Koniec',12,0);
  for fx:=0 to mie_x do
   for ffx:=0 to mie_y do
	 putseg2(fx*16+8,ffx*16,resx,resy,st.mie[fx,ffx],13,te^);
  print_predmet_edit;
end;

procedure show_ovocie;
var f,ff:word;
begin
		 for ff:=0 to 11 do
		  for f:=0 to 19 do
		   putsegxms(handles[4],f*resx,ff*resy,resx,resy,f+ff*20);
		  for f:=0 to 14 do
		   putsegxms(handles[4],f*resx,12*resy,resx,resy,f+400);
end;

procedure show(sh:byte);
begin
 case sh of
	1:begin
	    if ma then
		 show_ovocie else
		  draw_it(textura,0,0);
	init_charakter(16,16,si.x,si.y,poloha,si.buf,ar^);
	end;
	2:begin
		 clear_bitmap(screen);
		 redraw_editor;
		 if not ng then draw_grid;
	init_charakter(16,16,si.x,si.y,poloha,si.buf,ar^);
	end;
 end;
end;

procedure nogrid;
begin
 if ng then ng:=false else ng:=true;
 show(obrazovka);
end;

procedure reload2(tr:integer);
begin
    texnum:=tr*256;
    num:=tr;
 if ma then begin
    for f:=0 to 255 do
	  CopyXMemToCMem( @ar^[2*256+f], handles[4].h, texnum+f, 256 );
	  end else begin
    for f:=1 to 256 do
	  ar^[2*256+f]:=te^[texnum+f];
 end;
end;

procedure sub_c;  {vlozi ciarku do suboru}
begin
  write(t,',');
end;

procedure save_file;
var sub:string;
    f,ff,fx:word;
begin
 save_map(aktual);
 assign(t,miestn);
 rewrite(t);
 for f:=1 to pocet_veci do begin
     if length(vec^[f].meno)>0 then begin
	  sub:=vec^[f].meno;
	  vec^[f].meno:=out_strings(sub,' ');
     end;
 end;

for f:=1 to data_count do
    if (zal^[f,1]<>' ') and (zal^[f,2]<>'X') and (length(zal^[f])>0)
	 and (zal^[f,2]<>'Y') then writeln(t,zal^[f]);

for f:=1 to pocet_priechodov do begin {priechody}
   if priechody^[f].mie1<>0 then begin
    write(t,'[',option[59],']=',f,',',priechody^[f].mie1,',',(priechody^[f].x1-8) div 8,',',(priechody^[f].y1-8) div 8,',',
		(priechody^[f].x2-8) div 8,',',(priechody^[f].y2-8) div 8,',',priechody^[f].mie2,',',(priechody^[f].cx-8) div 8,',',
		(priechody^[f].cy-8) div 8,',');
    if priechody^[f].used then writeln(t,yes) else writeln(t,no);
   end;
end;

for f:=1 to pocet_vytahov do begin {vytahy}
   if priechody^[f].mie1<>0 then begin
    write(t,'[',option[61],']=',f,',',lift^[f].mie,',',(lift^[f].x1-8) div 8,',',(lift^[f].y1-8) div 8,',',
		(lift^[f].x2-8) div 8,',',(lift^[f].y2-8) div 8,',',lift^[f].smer,',',lift^[f].rychlost,',');
    if lift^[f].used then writeln(t,yes) else writeln(t,no);
   end;
end;

for f:=1 to pocet_veci do begin
     if (vec^[f].meno[1]='Z')  then begin
	writeln(t,'[',vec^[f].meno,']=',vec^[f].obr,',',
		  vec^[f].x,',',vec^[f].y,',',vec^[f].mie,',',vec^[f].take,',',vec^[f].inf1);
     end;

     if (vec^[f].meno[1]='V')  then begin
	writeln(t,'[',vec^[f].meno,']=',vec^[f].obr,',',vec^[f].x,',',vec^[f].y
	,',',vec^[f].inf7);
     end;

{veci typu W}
     if (vec^[f].meno[1]='W')  then begin
	if vec^[f].st>127 then dec (vec^[f].st,126);
	write(t,'[',vec^[f].meno,']=',vec^[f].cislo,',',vec^[f].obr,',',
		  vec^[f].x,',',vec^[f].y,',',vec^[f].funk,',',vec^[f].x1,
		  ',',vec^[f].y1,',',vec^[f].x2,',',vec^[f].y2);
	 case vec^[f].funk of
		1:begin
		    sub_c;
		    write(t,vec^[f].inf1);
		  end;
		2:begin
		    sub_c;
		    write(t,vec^[f].inf1,',',vec^[f].inf2,',',vec^[f].inf3,
		     ',',vec^[f].inf4,',',vec^[f].inf5);
		  end;
		4:begin
		    sub_c;
		    write(t,vec^[f].inf1,',',vec^[f].inf2,',',vec^[f].inf3);
		  end;
	 end;
	 writeln(t,',',vec^[f].inf7,',',vec^[f].st);
     end;
 end;

    for f:=1 to pocet_veci do begin
		   if (vec^[f].meno[1]='Y') or (vec^[f].meno[1]='X')then begin
		 write(t,'[',vec^[f].meno,']=',vec^[f].obr,',',vec^[f].x,',',vec^[f].y,',',
			 vec^[f].funk);
					  case vec^[f].funk of
						 1,12,13:begin
							  write(t,',',vec^[f].inf1,',',vec^[f].inf2);
						 end;
						 15,16,17:begin
							  write(t,',',vec^[f].inf1,',',vec^[f].inf2,',',vec^[f].inf3,',',vec^[f].inf4);
						 end;
						 18:begin
							  write(t,',',vec^[f].inf1,',',vec^[f].inf2,',',vec^[f].inf3,',',vec^[f].inf4,',',vec^[f].z1,
							  ',',vec^[f].z2);
						 end;
						 19:begin {Mrazak}
							  write(t,',',vec^[f].inf1,',',vec^[f].inf2,',',vec^[f].z1,',',vec^[f].z2);
						 end;
						 2,3:begin
							  write(t,',',vec^[f].inf1,',',vec^[f].inf2
							  ,',',vec^[f].inf3,',',vec^[f].inf7);
						 end;
						 4,5:begin
							  write(t,',',vec^[f].inf1,',',vec^[f].inf7);
						 end;
						 6:begin
							  write(t,',',vec^[f].inf1,',',vec^[f].inf2
							  ,',',vec^[f].inf3,',',vec^[f].inf4,',',
							  vec^[f].inf5);
						 end;
						 7,8,9,10:begin
							  write(t,',',vec^[f].inf1);
						 end;
						 11:begin
							write(t,',',vec^[f].inf1);
							case vec^[f].inf1 of
							  2,3:write(t,',',vec^[f].inf2,',',vec^[f].inf3,
									',',vec^[f].inf4,',',vec^[f].inf5);
							end;
						 end;
						 14:begin
							  write(t,',',vec^[f].inf1,',',vec^[f].inf2,',',vec^[f].inf3);
						 end;

					  end;
					  writeln(t);
   end;    end;
for f:=1 to data_count do
    if (zal^[f,2]='X') then writeln(t,zal^[f]);
for f:=1 to data_count do
    if (zal^[f,2]='Y') then writeln(t,zal^[f]);


 writeln(t,'[MAPA]=');
 load_map(1);
 for ff:=0 to mie_y do begin
  for f:=0 to mie_x do begin
    ch:=chr(st.mie[f,ff]+posuv);
    write(t,ch);
  end;
 writeln(t);
 end;
 for fx:=2 to num_maps do
 if maps[fx] then begin
 load_map(fx);
 writeln(t,'[MAPX]=',fx);
 for ff:=0 to mie_y do begin
  for f:=0 to mie_x do begin
    ch:=chr(st.mie[f,ff]+posuv);
    write(t,ch);
  end;
 writeln(t);
 end;
 end;
 writeln(t);
 close(t);
end;

function animated:char;
begin
   animated:='N';
		    init_jxmenu(10,10,15,12,1,'ANIM',med^);
		    vloz_jxmenu2('Neanimovane',med^,0);
		    vloz_jxmenu2('Animovane',med^,0);
		    vyber_jxmenu(med^,vyb);
   if vyb=2 then animated:='A';
end;

function smrted:char;
begin
   smrted:='N';
		    init_jxmenu(10,10,15,12,1,'SMRT',med^);
		    vloz_jxmenu2('Nesmrtelne',med^,0);
		    vloz_jxmenu2('Smrtelne',med^,0);
		    vloz_jxmenu2('No God',med^,0);
		    vyber_jxmenu(med^,vyb);
   case vyb of
        2:smrted:='S';
        3:smrted:='D';
   end;
end;

function edit(hladaj:string;var fond:word):boolean;
var fund:word;
    ciels:string;
label skip;
begin
   edit:=false;
   for fund:=1 to 100 do begin
	 get_name(zal^[fund],ciels);
	 if ciels=hladaj then begin
	    edit:=true;
	    goto skip;
	 end;
   end;
   for fund:=1 to 100 do begin
	 if length(zal^[fund])=0 then begin
	    edit:=true;
	    goto skip;
	 end;
   end;
 skip:
 fond:=fund;
end;

function into(nadpis:string;var jadro:string;dlzka:byte):string;
var s:string;
begin
	    printat(screen,1,466,frees,15,0,0);
	    s:=jadro;
	    print_normal(screen,1,466,nadpis+':',15,0);
	    input_key(length(nadpis)*15,466,15,0,s,dlzka,'<');
	    into:=s;
end;

procedure vloz_funk(fund:word;sd:string;var vstup:string);
begin
   zal^[fund]:='['+sd+']='+vstup;
end;

procedure vloz_funkciu(sd:string;var vstup:string);
var f:word;
begin
  inc(data_count);
   zal^[data_count]:='['+sd+']='+vstup;
end;

procedure select_target(napis:string;var xx,yy:word);
begin
 show(2);
 print_normal(screen,10,10,napis,15,0);
 mouse_button:=0;
 repeat
  mousepos;
  if (mouse_posx<>si.x) or (mouse_posy<>si.y) then begin
     si.x:=mouse_posx;
     si.y:=mouse_posy;
     charakter(si.x,si.y,si.oldx,si.oldy,poloha,si.buf,ar^);
     putpixel(screen,si.x,si.y,14);
     si.oldx:=si.x;
     si.oldy:=si.y;
  end;
 until mouse_button=1;
 xx:=(si.x-8)div 8;
 yy:=(si.y-8)div 8;
 delay(100);
end;


procedure special_choice;
var x2,y2:word;
    s2:string[80];
    f,ff,fx:word;
begin
		    init_jxmenu(10,10,15,12,1,'Specialne',med^);
		    vloz_jxmenu2('Animacia',med^,0);
		    vloz_jxmenu2('Smrt',med^,0);
		    vloz_jxmenu2('Meno',med^,0);
		    vloz_jxmenu2('Obrazok',med^,0);
		    vloz_jxmenu2('Start X,Y',med^,0);
		    vloz_jxmenu2('Variant predmetu',med^,0);
		    vloz_jxmenu2('Zmena editoru',med^,0);
		    vloz_jxmenu2('Typ hry',med^,0);
		    vloz_jxmenu2('Cas',med^,0);
		    vloz_jxmenu2('Vyber mapu',med^,0);
		    vloz_jxmenu2('Nastav filter',med^,0);
		    vloz_jxmenu2('Vytvor priechod',med^,0);
		    vloz_jxmenu2('Vytah',med^,0);
		    vloz_jxmenu2('Spat',med^,0);
		    vyber_jxmenu(med^,vyb);
    case vyb of
     1:begin anix:=animated;  end;
     2:begin Smrt:=smrted;  end;
     3:if edit('MENO',fz) then begin
	    s:=into('Meno',s,15);
	    vloz_funk(fz,'MENO',s);
	 end;
     4:if edit('OBR',fz) then begin
	    s:=into('Obrazok',s,15);
	    vloz_funkciu('OBR',s);
	 end;
     5:if edit('START',fz) then begin
	    select_target('Zaciatocna pozicia Siriela:',x2,y2);
	    str(x2*8+8,s2);
	    s:=s2;
	    str(y2*8+8,s2);
	    s:=s+','+s2;
	    vloz_funk(fz,'START',s);
	 end;
	6:begin
	  s:=variant;
	  s:=into('Variant',s,1);
	  variant:=s[1];
	end;
	7:if ma then ma:=false else ma:=true;
	8:begin
		    init_jxmenu(10,10,15,12,1,'Typ hry',med^);
		    vloz_jxmenu2('Arcade',med^,0);
		    vloz_jxmenu2('Bludisko - tma',med^,0);
		    vloz_jxmenu2('Bludisko - svetlo',med^,0);
		    vloz_jxmenu2('Spat',med^,0);
		    vyber_jxmenu(med^,vyb);
	    if vyb<3 then begin
		  case vyb of
			 1:s:='1';
			 2:s:='2';
			 3:s:='3';
		  end;
		  vloz_funk(fz,'TYP',s);
	    end;
    end;
	9:begin
	  s:='60';
	  s:=into('Cas',s,1);
	  vloz_funk(fz,'TIMER',s);
	end;
	10:select_map;
	11:begin
	  s:=variant;
	  s:=into('Filter',s,1);
	  if s='' then filter:=false else
	    begin filter:=true; miestnost:=ord(s[1]); end;
	end;
	12:if pocet_priechodov<max_prechod then begin
	   inc(pocet_priechodov);
	   priechody^[pocet_priechodov].mie1:=aktual;
	   select_target('1. bod',priechody^[pocet_priechodov].x1,priechody^[pocet_priechodov].y1);
	   select_target('2. bod',priechody^[pocet_priechodov].x2,priechody^[pocet_priechodov].y2);
	   select_map;
	   priechody^[pocet_priechodov].mie2:=aktual;
	   select_target('Ciel',priechody^[pocet_priechodov].cx,priechody^[pocet_priechodov].cy);
	   init_jxmenu(10,10,15,12,1,'Reakcia po prechode',med^);
	   vloz_jxmenu2('X = 0',med^,0);
	   vloz_jxmenu2('Y = 0',med^,0);
	   vloz_jxmenu2('Nic',med^,0);
	   vyber_jxmenu(med^,vyb);
	   case vyb of
		  1: priechody^[pocet_priechodov].cx:=0;
		  2: priechody^[pocet_priechodov].cy:=0;
	   end;
	   nasob_priechody(pocet_priechodov);
	   {zmeni na mesnie}
	   if priechody^[pocet_priechodov].x1>priechody^[pocet_priechodov].x2 then
		swap(priechody^[pocet_priechodov].x1,priechody^[pocet_priechodov].x2);
	   if priechody^[pocet_priechodov].y1>priechody^[pocet_priechodov].y2 then
		swap(priechody^[pocet_priechodov].y1,priechody^[pocet_priechodov].y2);
	end;
	13:if pocet_vytahov<max_vytahy then begin        {vytahy}
	   inc(pocet_vytahov);
	   lift^[pocet_vytahov].mie:=aktual;
	   select_target('1. bod',lift^[pocet_vytahov].x1,lift^[pocet_vytahov].y1);
	   select_target('2. bod',lift^[pocet_vytahov].x2,lift^[pocet_vytahov].y2);
	   init_jxmenu(10,10,15,12,1,'Smer',med^);
	   vloz_jxmenu2('Hore',med^,0);
	   vloz_jxmenu2('Dole',med^,0);
	   vloz_jxmenu2('Vlavo',med^,0);
	   vloz_jxmenu2('Vpravo',med^,0);
	   vyber_jxmenu(med^,vyb);
	   lift^[pocet_vytahov].smer:=vyb;
	   nasob_vytahy(pocet_vytahov);
	   lift^[pocet_vytahov].rychlost:=get_speed;
	   if lift^[pocet_vytahov].x1>lift^[pocet_vytahov].x2 then
		swap(lift^[pocet_vytahov].x1,lift^[pocet_vytahov].x2);
	   if lift^[pocet_vytahov].y1>lift^[pocet_vytahov].y2 then
		swap(lift^[pocet_vytahov].y1,lift^[pocet_vytahov].y2);
	end;
    end;
    show(obrazovka);
end;

procedure select_predmet(napis:string;var textur:word);
begin
    {draw_gif(screen,veci,0,0,palx);}
    show_ovocie;
    repeat
	mousepos;
  if (mouse_posx<>si.x) or (mouse_posy<>si.y) then begin
     si.x:=mouse_posx;
     si.y:=mouse_posy;
     charakter(si.x,si.y,si.oldx,si.oldy,poloha,si.buf,ar^);
     putpixel(screen,si.x,si.y,14);
     si.oldx:=si.x;
     si.oldy:=si.y;
  end;
    until mouse_button=1;
    textur:=(si.x div 16)+(si.y div 16)*20;
end;

procedure zmaz_ovocie;
label skip;
begin
  for f:=1 to pocet_veci do begin
	if (vec^[f].meno<>'')and  (vec^[f].x=(si.x div 8)-1) and (vec^[f].y=(si.y div 8)-1) then
	     begin
	     if ano_nie('Zrusit ?') then begin
		  vec^[f].meno:='          ';
		  vec^[f].mie:=0;
		  vec^[f].obr:=0;
	     end;
	   goto skip;
	end;
  end;
skip:
end;

function get_speed:byte;
begin
		    init_jxmenu(10,10,15,12,1,'Rychlost pohybu',med^);
		    vloz_jxmenu2('1',med^,0);
		    vloz_jxmenu2('2',med^,0);
		    vloz_jxmenu2('3',med^,0);
		    vyber_jxmenu(med^,vyb);
		    get_speed:=vyb;
		    if vyb=0 then get_speed:=3;
end;

function get_speed2(num:byte):byte;
var st:string[2];
    f:word;
begin
		    init_jxmenu(10,10,15,12,1,'Param.',med^);
		   for f:=0 to num do begin
		    str(f,st);
		    vloz_jxmenu2(st,med^,0);
		   end;
		    vyber_jxmenu(med^,vyb);
		    get_speed2:=vyb-1;
		    if vyb=0 then get_speed2:=3;
end;

function get_speed3(num:byte;napis:string):byte;
var st:string[2];
    f:word;
begin
	init_jxmenu(10,10,15,12,1,napis,med^);
	for f:=0 to num do begin
	  str(f,st);
	  vloz_jxmenu2(st,med^,0);
	end;
	vyber_jxmenu(med^,vyb);
	get_speed3:=vyb-1;
end;

function get_smer:byte;
begin
		    init_jxmenu(10,10,15,12,1,'Smer pohybu',med^);
		    vloz_jxmenu2('Vlavo',med^,0);
		    vloz_jxmenu2('Vpravo',med^,0);
		    vyber_jxmenu(med^,vyb);
		    get_smer:=vyb-1;
end;


procedure select_texture(napis:string;var textur:word);
begin
{    draw_gif(screen,'textura.gif',0,0,palx);}
     draw_it(textura,0,0);
    repeat
	mousepos;
  if (mouse_posx<>si.x) or (mouse_posy<>si.y) then begin
     si.x:=mouse_posx;
     si.y:=mouse_posy;
     charakter(si.x,si.y,si.oldx,si.oldy,poloha,si.buf,ar^);
     putpixel(screen,si.x,si.y,14);
     si.oldx:=si.x;
     si.oldy:=si.y;
  end;
    until mouse_button=1;
    textur:=(si.x div 16)+(si.y div 16)*19;
end;

procedure select_function(var f:word);
const maxf=5;
	func:array[1..maxf] of string[15]=
	  ('Objav predmet','Objav texturu','Ukonci hru','Otvor dvere','Nic');
var fx,vyb:word;
begin
	  vec^[f].meno[1]:='W';
		    init_jxmenu(10,10,15,12,1,'VYBER',med^);
		  for fx:=1 to maxf do
		    vloz_jxmenu2(func[fx],med^,0);
		    vyber_jxmenu(med^,vyb);
		    vec^[f].funk:=vyb;
		    case vyb of
			 1:begin              {objavenie predmetu}
				 s:=variant;
				s:=into('Uroven',s,3);
				val(s,vec^[f].inf1,vec^[f].inf1);
			   end;
			 2:begin               {objavenie textury}
				 select_target('X,Y - 1',vec^[f].inf1,vec^[f].inf2);
				 select_target('X,Y - 2',vec^[f].inf3,vec^[f].inf4);
				 select_texture('Fill',vec^[f].inf5);
			   end;
			 4:begin             {otvori dvere}
				 select_target('Dvere',vec^[f].inf1,vec^[f].inf2);
				 vec^[f].inf1:=vec^[f].inf1 div 2;
				 vec^[f].inf2:=vec^[f].inf2 div 2;
				 select_texture('Fill',vec^[f].inf3);
			   end;
			  5:begin
			    vec^[f].funk:=0;
			  end;
		    end;
	   s:='';
	   s:=into('Popis',s,3);
	   val(s,vec^[f].cislo,vec^[f].cislo);
	   s:='';
	   s:=into('Zaciatocna udalost',s,3);
{	   val(s,vec^[f].inf6,vec^[f].inf6);
	   s:='';                           }
{	   s:=into(' udalosti',s,3);}
	   val(s,vec^[f].inf7,vec^[f].inf7);
    mouse_button:=0;
    delay(100);
end;

procedure vloz_ovocie;
label skip;
var fx:word;
    f:word;
begin
  for f:=1 to pocet_veci do begin
     s:=vec^[f].meno;
     vec^[f].meno:=out_strings(s,' ');
     if length(vec^[f].meno)=0 then vec^[f].meno:='     ';
     if (vec^[f].meno[1]=' ') and (f<=pocet_veci) then begin
		   vec^[f].x:=(si.x div 8)-1;
		   vec^[f].y:=(si.y div 8)-1;
		   vec^[f].take:=3;
		   vec^[f].obr:=num;
		   vec^[f].mie:=1;
		 if variant>'A' then vec^[f].mie:=ord(variant);
		   vec^[f].meno[2]:=anix;
		   vec^[f].meno[3]:=smrt;
		   vec^[f].meno[4]:=variant;
		    init_jxmenu(10,10,15,12,1,'PREDMET',med^);
		    vloz_jxmenu2('Typ Z - Zobrat',med^,0);
		    vloz_jxmenu2('Typ X,Y - Special',med^,0);
		    vloz_jxmenu2('Typ W - Pouzi',med^,0);
		    vloz_jxmenu2('Typ V - Kecaj',med^,0);
		    vyber_jxmenu(med^,typ);
	{  vec[f].meno[0]:=chr(4);}
	  case typ of
	  0:goto skip;
	  4:Begin
		vec^[f].meno[1]:='V';
		s:='';
		s:=into('Od',s,5);
{		val(s,vec^[f].inf6,vec^[f].inf6);
		s:='';
		s:=into('Kolko',s,5);}
		val(s,vec^[f].inf7,vec^[f].inf7);
		mouse_button:=0;
		pulz(2);
		goto skip;
	    end;
	  3:begin
	   s:='';
		s:=into('Cielova miestnost',s,3);
		val(s,vec^[f].st,vec^[f].st);
	   save_map(aktual);
	   aktual:=vec^[f].st;
	   load_map(aktual);
		  select_target('X,Y - 1',vec^[f].x1,vec^[f].y1);
		  select_target('X,Y - 2',vec^[f].x2,vec^[f].y2);
{		  s:='0';
		  input_key(1,1,15,0,s,2,'<');
		  str(vec^[f].cislo,s);}
		  select_function(f);
		  goto skip;
	    end;
	  1:begin
		   suma:=into('Cena',suma,5);
		   vec^[f].meno[1]:='Z';
		   if variant<>'A' then vec^[f].mie:=ord(variant);
		   val(suma,vec^[f].inf1,vec^[f].inf1);
	   goto skip;
	    end;
	   2:begin
		    init_jxmenu(10,10,15,12,1,'PREDMET',med^);
		    vloz_jxmenu2('Typ Y - okamzite',med^,0);
		    vloz_jxmenu2('Typ X - ENTER',med^,0);
		    vyber_jxmenu(med^,vyb);
		  case vyb of
			 0:goto skip;
			 1:vec^[f].meno[1]:='Y';
			 2:vec^[f].meno[1]:='X';
		  end;
		    init_jxmenu(10,10,15,12,1,'VYBER',med^);

		    for fx:=0 to maxmeno do
			  vloz_jxmenu2(meno[fx],med^,0);

		    vyber_jxmenu(med^,vyb);
		    if vyb=0 then goto skip;
		    vec^[f].funk:=vyb-1;
		    case vec^[f].funk of
			   1:begin
				select_target('Ciel teleportacie',vec^[f].inf1,vec^[f].inf2);
			     end;
			   2:begin
				select_target('Hranica posuvu',vec^[f].inf1,vec^[f].inf4);
				vec^[f].inf2:=vec^[f].x;
				if vec^[f].inf1<vec^[f].x then vec^[f].inf7:=1
				else vec^[f].inf7:=0;
				if vec^[f].inf1>vec^[f].inf2 then swap(vec^[f].inf1,vec^[f].inf2);
				vec^[f].inf3:=get_speed;
				end;
			   3:begin
				select_target('Hranica posuvu',vec^[f].inf4,vec^[f].inf2);
				vec^[f].inf1:=vec^[f].y;
				if vec^[f].inf2<vec^[f].y then vec^[f].inf7:=1
				else vec^[f].inf7:=0;
				if vec^[f].inf1>vec^[f].inf2 then swap(vec^[f].inf1,vec^[f].inf2);
				vec^[f].inf3:=get_speed;
			     end;
			   4,5:begin
				vec^[f].inf1:=get_speed;
				vec^[f].inf7:=get_smer;
			     end;
			  6:begin
				 select_target('X,Y - 1',vec^[f].inf1,vec^[f].inf2);
				 select_target('X,Y - 2',vec^[f].inf3,vec^[f].inf4);
				 select_texture('Fill',vec^[f].inf5);
			   end;
			   7,8:begin
				 s:=variant;
				 s:=into('Typ',s,1);
				 vec^[f].inf1:=ord(s[1]);
			    end;
			   9:begin
				 s:='1';
				 s:=into('Typ',s,2);
				 val(s,vec^[f].inf1,vec^[f].inf1);
				 vec^[f].meno[4]:='~';
			    end;
			   10:begin
				 s:='1';
				 s:=into('Pocet',s,2);
				 val(s,vec^[f].inf1,vec^[f].inf1);
			    end;
			   11:begin
				init_jxmenu(10,10,15,12,1,'Typ MAZERa',med^);
				vloz_jxmenu2('Zhasni vsetko',med^,0);
				vloz_jxmenu2('Rozsviet vsetko',med^,0);
				vloz_jxmenu2('Zhasni sektor',med^,0);
				vloz_jxmenu2('Rozsviet sektor',med^,0);
				vyber_jxmenu(med^,vyb);
				vec^[f].inf1:=vyb-1;
				case vyb of
				     3,4:begin
					select_target('X,Y - 1',vec^[f].inf2,vec^[f].inf3);
					vec^[f].inf2:=vec^[f].inf2 div 2;
					vec^[f].inf3:=vec^[f].inf3 div 2;
					select_target('X,Y - 2',vec^[f].inf4,vec^[f].inf5);
					vec^[f].inf4:=vec^[f].inf4 div 2;
					vec^[f].inf5:=vec^[f].inf5 div 2;
				     end;
				end;
			   end;
			   12:begin
				init_jxmenu(10,10,15,12,1,'Nahod. pohyb',med^);
				vloz_jxmenu2('Bez vsetkeho',med^,0);
				vloz_jxmenu2('Reakcia na textury',med^,0);
				vyber_jxmenu(med^,vyb);
				vec^[f].inf1:=vyb-1;
				vec^[f].inf2:=get_speed;
			   end;
			   13:begin
				 s:=variant;
				 s:=into('Tma',s,1);
				 vec^[f].inf1:=ord(s[1]);
				 if s[1]='A' then vec^[f].inf1:=1;
				 s:=variant;
				 s:=into('Svetlo',s,1);
				 vec^[f].inf2:=ord(s[1]);
				 if s[1]='A' then vec^[f].inf2:=1;
			   end;
			   14:begin
				 select_map;
				 vec^[f].inf1:=aktual;
				 show(obrazovka);
				select_target('Miesto zhmotnenia',vec^[f].inf2,vec^[f].inf3);
			   end;
			   15,18:begin
				init_jxmenu(10,10,15,12,1,'Smer',med^);
				vloz_jxmenu2('X+',med^,0);
				vloz_jxmenu2('X-',med^,0);
				vloz_jxmenu2('Y+',med^,0);
				vloz_jxmenu2('Y-',med^,0);
				vyber_jxmenu(med^,vyb);
				vec^[f].inf1:=vyb;
				select_target('Miesto narazu',vec^[f].inf4,vec^[f].inf5);
				case vec^[f].inf1 of
				     1,2:vec^[f].inf2:=vec^[f].inf4;
				     3,4:vec^[f].inf2:=vec^[f].inf5;
				end;
				vec^[f].inf3:=get_speed2(20);
				vec^[f].inf4:=get_speed2(50);
				if vec^[f].funk=18 then begin
				   vec^[f].z1:=get_speed3(8,'Zvuk1');
				   vec^[f].z2:=get_speed3(8,'Zvuk2');
				end;
			   end;
			   16:begin
				 vec^[f].inf1:=get_speed2(10);
				 vec^[f].inf2:=get_speed2(63);
				 vec^[f].inf3:=get_speed2(63);
				 select_predmet('Zlo',vec^[f].inf4);
			   end;
			   17:begin
				 vec^[f].inf1:=get_speed3(extra_snd,st_Zvuk);
				 vec^[f].inf2:=get_speed3(63,st_Cas);
				 vec^[f].inf3:=get_speed3(extra_snd,st_Zvuk);
				 vec^[f].inf4:=get_speed3(63,st_Cas);
			   end;
			   19:begin
				 vec^[f].inf2:=get_speed3(3,'1 Mraz, 2 God, 3 Mix');
				 vec^[f].inf1:=get_speed3(63,st_Cas);
				 vec^[f].z1:=get_speed3(extra_snd,st_Zvuk);
				 vec^[f].z2:=get_speed3(extra_snd,st_Zvuk);
			   end;
		    end;
		 goto skip;
	     end;
	  end;
	end;
  end;

skip:
 if vyb=0 then begin
    vec^[f].meno:='    ';
    vec^[f].mie:=1;
 end;

clear_key_buffer;
end;


procedure supra_edit;
var f:word;
begin
  for f:=1 to pocet_veci do begin
    if (vec^[f].meno<>'')and  (vec^[f].x=(si.x div 8)-1)
	 and (vec^[f].y=(si.y div 8)-1) then begin
		    str(f,s);
		    init_jxmenu(10,10,15,12,1,'Editacia '+s,med^);
		    vloz_jxmenu2('Suradnice',med^,0);
		    vloz_jxmenu2('Obrazok',med^,0);
		    vloz_jxmenu2('Funkcia',med^,0);
		    vloz_jxmenu2('Animacia',med^,0);
		    vloz_jxmenu2('Smrtelnost',med^,0);
		    vloz_jxmenu2('Typ miesta',med^,0);
		   if vec^[f].meno[1]='Z' then vloz_jxmenu2('Cena',med^,0)
		    else
		    case vec^[f].funk of
			1:vloz_jxmenu2('Ciel portu',med^,0);
			2:begin
				 vloz_jxmenu2('X2',med^,0);
				 vloz_jxmenu2('Rychlost',med^,0);
			end;
			3:begin
				 vloz_jxmenu2('Y2',med^,0);
				 vloz_jxmenu2('Rychlost',med^,0);
			end;
			4,5:begin
				 vloz_jxmenu2('Rychlost',med^,0);
				 vloz_jxmenu2('Smer',med^,0);
			end;
			6:begin
				 vloz_jxmenu2('X-Y 1',med^,0);
				 vloz_jxmenu2('X-Y 2',med^,0);
				 vloz_jxmenu2('Textura',med^,0);
			end;
			7,8,9:begin
				 vloz_jxmenu2('Typ',med^,0);
			end;
			10:begin
				 vloz_jxmenu2('Pocet',med^,0);
			end;
			11:begin
				vloz_jxmenu2('Zhasni vsetko',med^,0);
				vloz_jxmenu2('Rozsviet vsetko',med^,0);
				vloz_jxmenu2('Zhasni sektor',med^,0);
				vloz_jxmenu2('Rozsviet sektor',med^,0);
			end;
		     12:begin
				vloz_jxmenu2('Typ pohybu',med^,0);
				vloz_jxmenu2('Rychlost',med^,0);
		     end;
		     13:begin
				vloz_jxmenu2('Tma',med^,0);
				vloz_jxmenu2('Svetlo',med^,0);
		     end;
		     15:begin
				vloz_jxmenu2('Rychlost',med^,0);
				vloz_jxmenu2('Smer',med^,0);
		     end;
		    end;
		    vyber_jxmenu(med^,vyb);
		    case vyb of
			   1:select_target('Nove suradnice',vec^[f].x,vec^[f].y);
			   2:select_predmet('Nova textura',vec^[f].obr);
			   3:if vec^[f].meno[1]='W' then select_function(f) else begin
				  zmaz_ovocie;
				  vloz_ovocie;
				 end;
			   4:vec^[f].meno[2]:=animated;
			   5:vec^[f].meno[3]:=smrted;
			   6:begin
				     s:=vec^[f].meno[4];
				     s:=into('Variant',s,1);
				if s='A' then begin
				   vec^[f].mie:=1;
				   vec^[f].meno[4]:='A';
				end else begin
				     vec^[f].meno[4]:=s[1];
				     if vec^[f].meno[1]='Z' then vec^[f].mie:=ord(s[1]);
				end;
			   end;
			   7:if vec^[f].meno[1]='Z' then begin
				  str(vec^[f].inf1,s);
				  s:=into('Cena',s,5);
				  val(s,vec^[f].inf1,vec^[f].inf1);
			     end else
			     case (vec^[f].funk) of
				    1:select_target('Ciel teleportacie',vec^[f].inf1,vec^[f].inf2);
				    2:begin
					 select_target('Hranica posuvu',vec^[f].inf1,vec^[f].inf4);
					 vec^[f].inf2:=vec^[f].x;
					 if vec^[f].inf1<vec^[f].x then vec^[f].inf7:=1
					else vec^[f].inf7:=0;
					 if vec^[f].inf1>vec^[f].inf2 then swap(vec^[f].inf1,vec^[f].inf2);
					end;
				    3:begin
					 select_target('Hranica posuvu',vec^[f].inf4,vec^[f].inf2);
					 vec^[f].inf1:=vec^[f].y;
					 if vec^[f].inf2<vec^[f].y then vec^[f].inf7:=1
					 else vec^[f].inf7:=0;
					 if vec^[f].inf1>vec^[f].inf2 then swap(vec^[f].inf1,vec^[f].inf2);
				    end;
				    4,5:vec^[f].inf1:=get_speed;
				    6:select_target('X,Y - 1',vec^[f].inf1,vec^[f].inf2);
				    7,8:begin
						 s:=variant;
						 s:=into('Typ',s,1);
						 vec^[f].inf1:=ord(s[1]);
				    end;
				    9:begin
					     s:='1';
					     s:=into('Typ',s,2);
					     val(s,vec^[f].inf1,vec^[f].inf1);
					     vec^[f].meno[4]:='~';
				    end;
				    11:begin
					 vec^[f].inf1:=0;
				    end;
				    12:begin
					init_jxmenu(10,10,15,12,1,'Nahod. pohyb',med^);
					vloz_jxmenu2('Bez vsetkeho',med^,0);
					vloz_jxmenu2('Reakcia na textury',med^,0);
					vyber_jxmenu(med^,vyb);
					vec^[f].inf1:=vyb-1;
				    end;
				 13:begin
					s:=variant;
					s:=into('Tma',s,1);
					vec^[f].inf1:=ord(s[1]);
					if s[1]='A' then vec^[f].inf1:=1;
				 end;
				 15:vec^[f].inf2:=get_speed2(20);
			     end;
			   8:case vec^[f].funk of
				    2,3:vec^[f].inf3:=get_speed;
				    4,5:vec^[f].inf7:=get_smer;
				    6:select_target('X,Y - 2',vec^[f].inf3,vec^[f].inf4);
				    11:vec^[f].inf1:=1;
				    12:vec^[f].inf2:=get_speed;
				   13:begin
						s:=variant;
						s:=into('Svetlo',s,1);
						vec^[f].inf2:=ord(s[1]);
						if s[1]='A' then vec^[f].inf2:=1;
					 end;
			   end;
			   9:case vec^[f].funk of
				    6:select_texture('Fill',vec^[f].inf5);
				    11:begin
					 vec^[f].inf1:=2;
					select_target('X,Y - 1',vec^[f].inf2,vec^[f].inf3);
					select_target('X,Y - 2',vec^[f].inf4,vec^[f].inf5);
					vec^[f].inf4:=vec^[f].inf4 div 2;
					vec^[f].inf5:=vec^[f].inf5 div 2;
					vec^[f].inf2:=vec^[f].inf2 div 2;
					vec^[f].inf3:=vec^[f].inf3 div 2;
				    end;
			     end;
			   10:case vec^[f].funk of
				   11:begin
					 vec^[f].inf1:=3;
					select_target('X,Y - 1',vec^[f].inf2,vec^[f].inf3);
					select_target('X,Y - 2',vec^[f].inf4,vec^[f].inf5);
					vec^[f].inf4:=vec^[f].inf4 div 2;
					vec^[f].inf5:=vec^[f].inf5 div 2;
					vec^[f].inf2:=vec^[f].inf2 div 2;
					vec^[f].inf3:=vec^[f].inf3 div 2;
				   end;
			   end;
		    end;
	 end;
  end;
  show(obrazovka);
end;

procedure zmenkurzor(pol:integer);
begin
 poloha:=pol;
  vypni_charakter(si.x,si.y,si.buf,ar^);
  init_charakter(16,16,si.x,si.y,poloha,si.buf,ar^);
end;

procedure reload;
begin
 if ma then begin
    texnum:=(si.x div 16)*256+(si.y div 16)*20*256;
    num:=(si.x div 16)+(si.y div 16)*20;
    for f:=0 to 255 do
	  CopyXMemToCMem( @ar^[2*256+f], handles[4].h, texnum+f, 256 );
 end else begin
    texnum:=(si.x div 16)*256+(si.y div 16)*19*256;
    num:=(si.x div 16)+(si.y div 16)*19;
    for f:=1 to 256 do
	  ar^[2*256+f]:=te^[texnum+f];
 end;
end;

procedure load_textx;
var
    line,znak,mil:integer;
    bl:char;
    sax:string;
begin
   for line:=0 to mie_y do begin
  for znak:=0 to mie_x do begin
     read(t,ch);
     st.mie[znak,line]:=ord(ch)-posuv;
     if (ord(ch)=10) or (ord(ch)=13) then dec (znak);
   end;
  end;
  save_map(1);
end;

procedure load_textx2(num:byte);
var
    line,znak,mil:integer;
    bl:char;
    sax:string;
begin
   for line:=0 to mie_y do begin
  for znak:=0 to mie_x do begin
     read(t,ch);
     st.mie[znak,line]:=ord(ch)-posuv;
     if (ord(ch)=10) or (ord(ch)=13) then dec (znak);
   end;
  end;
  save_map(num);
end;

procedure load_predmet_editor2;
var count,m,f:word;
    s,sx,sc:string;
    cislo:word;
begin
     for f:=1 to num_maps do maps[f]:=false;
     assign(t,miestn);
     reset(t);
	f:=0;
	repeat
		readln(t,s);
		get_name_normal(s,sx);
		count:=1;
		if sx<>'' then begin
		 upcased(sx,sc);
		   m:=0;
		   if (sx[1]='Z') and (not defined(sx)) then begin
		    inc(f);
		    vec^[f].meno:=sx;
		    get_funk(s,sx);
		    mov_num(sx,vec^[f].obr,count);
		    mov_num(sx,vec^[f].x,count);
		    mov_num(sx,vec^[f].y,count);
		    mov_num(sx,vec^[f].mie,count);
		    mov_num(sx,vec^[f].take,count);
		    mov_num(sx,vec^[f].inf1,count);
		   end else
		   if (sx[1]='W') and (not defined(sx)) then begin
			pridaj2(s,f,false);
			vec^[f].take:=4;
		   end else
		   if (sx[1]='V') and (not defined(sx)) then begin
		    inc(f);
		    vec^[f].meno:=sx;
		    get_funk(s,sx);
		    mov_num(sx,vec^[f].obr,count);
		    mov_num(sx,vec^[f].x,count);
		    mov_num(sx,vec^[f].y,count);
		    mov_num(sx,vec^[f].inf7,count);
			if vec^[f].meno[4]<'B' then vec^[f].mie:=1;
			vec^[f].take:=4;
		   end else
		   if ((sx[1]='Y') or (sx[1]='X'))and (not defined(sx))then begin

		   inc(f);
		   vec^[f].meno:=sx;
		   get_funk(s,sx);
		   mov_num(sx,vec^[f].obr,count);
		   mov_num(sx,vec^[f].x,count);
		   mov_num(sx,vec^[f].y,count);
		   mov_num(sx,vec^[f].funk,count);
{                  vec[f].mie:=1;}
			vec^[f].take:=4;
					  case vec^[f].funk of
						 1,12,13:begin
							  mov_num(sx,vec^[f].inf1,count);
							  mov_num(sx,vec^[f].inf2,count);
						 end;
						 2,3:begin
							  mov_num(sx,vec^[f].inf1,count);
							  mov_num(sx,vec^[f].inf2,count);
							  mov_num(sx,vec^[f].inf3,count);
							  mov_num(sx,vec^[f].inf7,count);
						 end;
						 19:begin
							  mov_num(sx,vec^[f].inf1,count);
							  mov_num(sx,vec^[f].inf2,count);
							  mov_num2(sx,vec^[f].z1,count);
							  mov_num2(sx,vec^[f].z2,count);
						 end;
						 15,16,17,18:begin
							  mov_num(sx,vec^[f].inf1,count);
							  mov_num(sx,vec^[f].inf2,count);
							  mov_num(sx,vec^[f].inf3,count);
							  mov_num(sx,vec^[f].inf4,count);
							  if vec^[f].funk=18 then begin
								  mov_num2(sx,vec^[f].z1,count);
								  mov_num2(sx,vec^[f].z2,count);
							  end;
						 end;
						 4,5:begin
							  mov_num(sx,vec^[f].inf1,count);
							  mov_num(sx,vec^[f].inf7,count);
						 end;
						 6:begin
							  mov_num(sx,vec^[f].inf1,count);
							  mov_num(sx,vec^[f].inf2,count);
							  mov_num(sx,vec^[f].inf3,count);
							  mov_num(sx,vec^[f].inf4,count);
							  mov_num(sx,vec^[f].inf5,count);
						 end;
						 7,8,9,10:begin
							  mov_num(sx,vec^[f].inf1,count);
						 end;
						 11:begin
							  mov_num(sx,vec^[f].inf1,count);
							  case vec^[f].inf1 of
								2,3:begin
								  mov_num(sx,vec^[f].inf2,count);
								  mov_num(sx,vec^[f].inf3,count);
								  mov_num(sx,vec^[f].inf4,count);
								  mov_num(sx,vec^[f].inf5,count);
								end;
							  end;

						 end;
						 14:begin
							  mov_num(sx,vec^[f].inf1,count);
							  mov_num(sx,vec^[f].inf2,count);
							  mov_num(sx,vec^[f].inf3,count);
						 end;

					  end;

		end else
		 if sc='MAPA' then load_textx
		 else
		  if sc=option[49] then begin
			get_funk_normal(s,sx);
			mov_num(sx,cislo,count);
			load_textx2(cislo);
		  end
		  else
		   if sc=option[59] then begin
			get_funk_normal(s,sx);
			load_priechod(sx);
		   end
		 else
		 begin
			    inc(data_count);
			    zal^[data_count]:=s;
		end;
		end;
	until eof(t);
     close(t);
     load_map(1);
end;

procedure vloz_komentar;
var s:string;
    vyb:word;
begin
	init_jxmenu(10,10,15,12,1,'Komentar',med^);
	vloz_jxmenu2('Vec',med^,0);
	vloz_jxmenu2('Text',med^,0);
	vyber_jxmenu(med^,vyb);
 if vyb>0 then begin
  s:='';
  input_key(1,1,15,0,s,80,'<');
  if s<>'' then
   case vyb of
     1:vloz_funkciu('VEC',s);
     2:vloz_funkciu('TEXT',s);
   end;
  end;
  show(2);
end;

{==================EDITOR====================}
procedure edit_it;
var sr:searchrec;
    omx:word;
    sx:string;
label skip,reloading,hopla;
begin
 filter:=false;
 aktual:=1;
 new(zal);
 new(med);
 new(priechody);
 mouseinit(omx);
 mousespeed(12,12);
 mousesensitivity(50,50,1);
 data_count:=0;
 suma:='10';
 ng:=false;
 nogrid;
 reloading:
 ma:=true;
 clear_file(false);
 write_palette(palx,0,256);
if miestn='' then begin
 init_jxmenu(200,10,15,12,1,'Subor',med^);
	  findfirst('*.mie',$3f,sr);
	  repeat
		    vloz_jxmenu2(sr.name,med^,0);
		    findnext(sr);
	  until doserror<>0;
		    vyber_jxmenu(med^,vyb);
   if vyb=0 then miestn:='' else
    miestn:=med^.dat[vyb].meno;
    miestn:=out_strings(miestn,' ');
 end;
 if subor_exist(miestn) then begin
 load_predmet_editor2;
 define_zone(8, 1, 624, 464 );
 define_speed(8, 8 );
 clear_key_buffer;
 anix:='N';
 smrt:='N';
 variant:='A';
 typ:=1;
   si.x:=16;
   si.y:=16;
   si.oldx:=16;
   si.oldy:=16;
   poloha:=1;
   si.buf:=0;
   init_charakter(16,16,si.x,si.y,poloha,si.buf,ar^);
   obrazovka:=2;
show(2);
 repeat
 k:=0;
 if keypressed then begin
  k:=key;
  clear_key_buffer;
 end;
  case k of
	 $0f09:begin
			vypni_charakter(si.x,si.y,si.buf,ar^);
			inc(obrazovka);
			if obrazovka>2 then obrazovka:=1;
			show(obrazovka);
	 end;
	 $4E2B:begin
		  reload2(num+1);
			init_charakter(16,16,si.x,si.y,poloha,si.buf,ar^);
		  show(obrazovka);
	 end;
	 $4A2D:begin
		  reload2(num-1);
			init_charakter(16,16,si.x,si.y,poloha,si.buf,ar^);
		  show(obrazovka);
	 end;
	 $5300:begin
			  if poloha=2 then begin
			     st.mie[((si.x-8) div 16),((si.y) div 16)]:=0;
			  end;
			  show(2);
	 end;
	 $3d00:begin
			if ano_nie('Nahrat novy ?') then begin
			goto reloading;
			end;
		 end;
	 $3c00:begin save_file; load_map(aktual); end;
	 $4200:begin if ano_nie('Vycistit ?') then clear_file(true);
			 show(obrazovka); end;
	 $3e00:nogrid;
	 $4400:special_choice;
	 $4300:begin
			if ma then ma:=false else ma:=true;
			show(obrazovka);
		 end;
	 $3f00:supra_edit;
	 $3b00:begin
		     save_file;
		     test:=true;
		     goto hopla;
		 end;
	  $4100:vloz_komentar;
  end;
  mousepos;
  if mouse_button<>0 then begin
     case obrazovka of
	    1:begin
		if mouse_button=1 then begin
			reload;
			zmenkurzor(2);
			end;
		if mouse_button=2 then zmenkurzor(1);
		end;
	    2:begin
		 if mouse_button=1 then begin
			  if poloha=2 then begin
			     if ma then begin
				vloz_ovocie;
				show(2);
			     end
			     else   begin
			     vypni_charakter(si.x,si.y,si.buf,ar^);
			     st.mie[((si.x-8) div 16),((si.y) div 16)]:=num;
			     putseg2(((si.x-8) div 16)*16+8,((si.y) div 16)*16,resx,resy,num,13,te^);
			     init_charakter(resx,resy,si.x,si.y,poloha,si.buf,ar^);
			  end;
			  end;
		     end;
		  if mouse_button=2 then begin
			  if poloha=2 then begin
			     if ma then begin
					zmaz_ovocie;
					show(2);
			     end
			     else begin
			     vypni_charakter(si.x,si.y,si.buf,ar^);
			     st.mie[((si.x-8) div 16),((si.y) div 16)]:=0;
			     rectangle2(screen,((si.x-8) div 16)*16+8,((si.y) div 16)*16,resx,resy,0);
			     init_charakter(resx,resy,si.x,si.y,poloha,si.buf,ar^);
			     end;
			  end;
		  end;
	    end;
     end;
  end;
  if (mouse_posx<>si.x) or (mouse_posy<>si.y) then begin
     si.x:=mouse_posx;
     si.y:=mouse_posy;
     charakter(si.x,si.y,si.oldx,si.oldy,poloha,si.buf,ar^);
     putpixel(screen,si.x,si.y,14);
     si.oldx:=si.x;
     si.oldy:=si.y;
     if obrazovka=2 then begin
	if not ma then begin
	  str(st.mie[((si.x-8) div 16),((si.y) div 16)],s);
	  printat(screen,1,466,s+'  ',15,0,0)
	end
	else begin
	  printat(screen,1,466,frees,15,0,0);
	  for f:=1 to pocet_veci do begin
		if (vec^[f].meno[1]<>' ')and  ((vec^[f].x=(si.x div 8)-1) or (vec^[f].x=(si.x div 8)-2))
		   and ((vec^[f].y=(si.y div 8)-1) or (vec^[f].y=(si.y div 8)-2)) then
		   begin
		   sx:='';
		   if vec^[f].meno[3]='S' then sx:=sx+' Smrtelne'
			 else sx:=sx+' Neskodne';

		   if vec^[f].meno[1]='Z' then begin
		    str(vec^[f].inf1,s);
		    print_normal(screen,1,466,s+sx,15,0);
		   end else
		    print_normal(screen,1,466,meno[vec^[f].funk]+sx,15,0);
		   end;
	  end;
	end;
     end;
  end;
 skip:
 until k=$011b;
 if ano_nie('Ulozit :-? ') then save_file;
end;
hopla:
 dispose(med);
 dispose(zal);
 dispose(priechody);
 if not subor_exist(miestn) then begin
    textcolor(12);
    writeln('Subor nebol najdeny !-(');
 end;
end;

begin
end.