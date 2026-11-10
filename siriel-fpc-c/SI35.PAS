{$MAINLESS}
{$m 16384,0,350000}
{$SETSTACKSIZE 67108864}
{$N+,E+,G+,V-}     {qm,pm}
{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
program siriel3;
uses {$IFDEF Darwin} LineInfo, {$ENDIF}
     geo,jxgraf,txt,crt,dos,dosio,smix,animing,blockx,jxmenu,koder,mouse,
     flik,geo2,jxxms,xms2,aktiv35,jxzvuk,load135,crcr35,jxefekt,
     load235,process,jxvar,vidif,vidbase;

procedure info;forward;
procedure briefing;forward;

{ The C host provides host_main() (formerly "main").  The Pascal program body
  is now the FPC entry point (_main) and drives the engine by calling it, so
  there is no duplicate _main when FPC links host_cdrv.o in. }
procedure host_main; cdecl; external;

{ Re-install the C crash handler from the program body. FPC installs its own
  SIGSEGV handler during System init (before the program body), so installing
  here makes OUR handler win: on fault it prints a symbolized backtrace and
  re-raises so macOS ReportCrash emits a fully symbolized .ips report. }
{$IFDEF Darwin}
procedure install_crash_handler; cdecl; external;
{$ENDIF}

var g_sp: nativeint;
   dbg_scr_bytes: array[0..63] of byte;
   dbg_ptr: pointer;
function stackdepth: longint;
var probe: array[0..7] of byte;
begin
  stackdepth := longint(@probe[0]);
end;

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
   writeln('[SD] enter');
   dump_font_globals;
   writeln('[SP] SD enter stack=', stackdepth);
   { dump all_disks[1] record to see if disk loading populated it }
   move(data_disks^[1], dbg_scr_bytes, 42);
   writeln('[SP] adisk1: meno.len=', ord(dbg_scr_bytes[0]),
     ' sub.len=', ord(dbg_scr_bytes[26]),
     ' verzia=', ord(dbg_scr_bytes[39]) or (ord(dbg_scr_bytes[40]) shl 8)); flush(output);
   g_sp := stackdepth;
   fatal:=false;
   write_palette(blackx,0,256);
   dump_font_globals;
   writeln('[SD] after write_palette');
   clear_bitmap(screen);
   writeln('[SP] SD after clear_bitmap 1 stack=', stackdepth);
   writeln('[SD] after clear_bitmap 1');
   dump_font_globals;
   new(mex);
   dump_font_globals;
   writeln('[SD] after new(mex)');
znovku:
   clear_bitmap(screen);
   writeln('[SP] SD znovku clear_bitmap stack=', stackdepth);
   writeln('[SD] znovku clear_bitmap');
   dump_font_globals;
   init_jxmenu(200,40,0,15,0,tx2[ja,2],mex^);
   dump_font_globals;
   writeln('[SP] SD after init_jxmenu stack=', stackdepth);
   writeln('[SD] after init_jxmenu');
    writeln('[SD] post-init marker');
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
    writeln('[SD] after sort loop');
    dbg_ptr := @data_disks; move(dbg_ptr, dbg_scr_bytes, 8);
    writeln('[SP] sort: data_disks=',
      ord(dbg_scr_bytes[0]) or (ord(dbg_scr_bytes[1]) shl 8) or (ord(dbg_scr_bytes[2]) shl 16) or (ord(dbg_scr_bytes[3]) shl 24), ' addr=');
    {swapne to}
    for f:=1 to num_disks div 2 do begin
			  diskd:=data_disks^[f];
			  data_disks^[f]:=data_disks^[num_disks-f+1];
			  data_disks^[num_disks-f+1]:=diskd;
    end;
    writeln('[SD] after swap loop');
    dbg_ptr := @data_disks; move(dbg_ptr, dbg_scr_bytes, 8);
    writeln('[SP] swap: data_disks=',
      ord(dbg_scr_bytes[0]) or (ord(dbg_scr_bytes[1]) shl 8) or (ord(dbg_scr_bytes[2]) shl 16) or (ord(dbg_scr_bytes[3]) shl 24), ' addr=');
    for f:=1 to num_disks do begin
		    if data_disks<>nil then begin
		      writeln('[SD] about vloz_jxmenu2 iter', f);
		      vloz_jxmenu2(data_disks^[f].meno,mex^,0);
		      writeln('[SD] after vloz_jxmenu2 iter', f);
		    end;
    end;
     vloz_jxmenu2(tx[ja,6],mex^,0);
    writeln('[SD] after last vloz_jxmenu2');
    dbg_ptr := @data_disks; move(dbg_ptr, dbg_scr_bytes, 8);
    writeln('[SP] vloz: data_disks=',
      ord(dbg_scr_bytes[0]) or (ord(dbg_scr_bytes[1]) shl 8) or (ord(dbg_scr_bytes[2]) shl 16) or (ord(dbg_scr_bytes[3]) shl 24), ' addr=');
   if num_disks>1 then begin
{     increase_palette(blackx,palx,10);}
     writeln('[SD] about old_frame.draw');
     old_frame.draw(200,40,12,2+num_disks);
     writeln('[SD] after old_frame.draw');
     move(data_disks^[1], dbg_scr_bytes, 42);
     writeln('[SP] afterdraw: meno.len=', ord(dbg_scr_bytes[0]), ' sub.len=', ord(dbg_scr_bytes[26]), ' verzia=', ord(dbg_scr_bytes[39]) or (ord(dbg_scr_bytes[40]) shl 8)); flush(output);
    dbg_ptr := @data_disks; move(dbg_ptr, dbg_scr_bytes, 8);
    writeln('[SP] frame: data_disks=',
      ord(dbg_scr_bytes[0]) or (ord(dbg_scr_bytes[1]) shl 8) or (ord(dbg_scr_bytes[2]) shl 16) or (ord(dbg_scr_bytes[3]) shl 24), ' addr=');
     size_jxmenu(192,288,mex^);
     writeln('[SD] after size_jxmenu');
     draw_jxmenu3(mex^);
     dump_font_globals;
     writeln('[SD] after draw_jxmenu3');
    dbg_ptr := @data_disks; move(dbg_ptr, dbg_scr_bytes, 8);
    writeln('[SP] drawmenu: data_disks=',
      ord(dbg_scr_bytes[0]) or (ord(dbg_scr_bytes[1]) shl 8) or (ord(dbg_scr_bytes[2]) shl 16) or (ord(dbg_scr_bytes[3]) shl 24), ' addr=');
     write_palette(palx,0,256);
     writeln('[SD] after write_palette (menu)');
    dbg_ptr := @data_disks; move(dbg_ptr, dbg_scr_bytes, 8);
    writeln('[SP] palette: data_disks=',
      ord(dbg_scr_bytes[0]) or (ord(dbg_scr_bytes[1]) shl 8) or (ord(dbg_scr_bytes[2]) shl 16) or (ord(dbg_scr_bytes[3]) shl 24), ' addr=');
     (* Phase 2 validation hook: the menu is fully painted into VideoBuffer
        here (before vyber_jxmenu blocks for input). Presenting now triggers
        the one-shot SG_DUMPFILE PPM capture so we can validate the engine
        actually renders. *)
     vid_present;
     writeln('[SD] pre-vyber vid_present done');
    { --- Phase 2 capture hook: write the painted menu frame to a PPM so the
         C host (or a later step) can read a real engine-rendered image even
         though select_datadisk/vyber_jxmenu block below. --- }
    (* screenshot is captured by the C driver's dump_ppm (P6 PNM) from FrameRGB;
       the engine does not write its own image file. *)
    dbg_ptr := @data_disks; move(dbg_ptr, dbg_scr_bytes, 8);
    writeln('[SP] afterpresent: data_disks=',
      (ord(dbg_scr_bytes[0]) shl 0) or (ord(dbg_scr_bytes[1]) shl 8) or (ord(dbg_scr_bytes[2]) shl 16) or (ord(dbg_scr_bytes[3]) shl 24));
     vyber_jxmenu(mex^,vybr);
     writeln('[SD] after vyber_jxmenu');
     writeln('[SP] A aftervyber st=',stackdepth,' dis=',integer(data_disks)); flush(output);
     dbg_ptr := @data_disks; move(dbg_ptr, dbg_scr_bytes, 8);
     writeln('[SP] A2 disfull=',
       (ord(dbg_scr_bytes[7]) shl 56) or (ord(dbg_scr_bytes[6]) shl 48) or (ord(dbg_scr_bytes[5]) shl 40) or (ord(dbg_scr_bytes[4]) shl 32) or
       (ord(dbg_scr_bytes[3]) shl 24) or (ord(dbg_scr_bytes[2]) shl 16) or (ord(dbg_scr_bytes[1]) shl 8) or (ord(dbg_scr_bytes[0]) shl 0), ' hex='); flush(output);
    dbg_ptr := @data_disks; move(dbg_ptr, dbg_scr_bytes, 8);
     writeln('[SP] B disbytes=',
       (ord(dbg_scr_bytes[0]) shl 0) or (ord(dbg_scr_bytes[1]) shl 8) or (ord(dbg_scr_bytes[2]) shl 16) or (ord(dbg_scr_bytes[3]) shl 24),' st=',stackdepth);
     move(screen, dbg_scr_bytes, 8);
     writeln('[SP] C screenbytes st=',stackdepth); flush(output);
     writeln('[SP] D addrs st=',stackdepth,' dis_lo=',integer(data_disks)); flush(output);
     writeln('[SP] E postmenu st=',stackdepth,' sw=',screen^.width,' sh=',screen^.height); flush(output);
     move(data_disks^[1], dbg_scr_bytes, 42);
     writeln('[SP] postE2: meno.len=', ord(dbg_scr_bytes[0]), ' sub.len=', ord(dbg_scr_bytes[26]), ' verzia=', ord(dbg_scr_bytes[39]) or (ord(dbg_scr_bytes[40]) shl 8)); flush(output);
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

  {* Scan one filename pattern and append every file that passes the game
     block-header check into the global data_disks/num_disks tables.  Called
     once for the lowercase and once for the uppercase extension so the port
     finds the shipped *.DAT data files on case-sensitive host filesystems
     (the original DOS match was case-insensitive and used only '*.dat'). *}
  procedure scan_disks(pat: string);
  var g,n,h:word; dup:boolean;
  begin
     findfirst(pat,$3f,sr);
     repeat
        n:=num_disks;   (* capture count: num_disks is modified inside the loop,
                           so it cannot be used directly as the FOR bound *)
        if (doserror=0) and (checkblock_info(sr.name,hlavicka)) then begin
           (* guard against the same name surfacing under both patterns *)
           dup:=false;
           for g:=1 to n do
              if data_disks^[g].subor=sr.name then dup:=true;
           if not dup then begin
              loadblock_array(sr.name,hlavicka,block_ver);
              inc(num_disks);
              for h:=0 to 2 do block_ver[h]:=block_ver[h]-48;
              data_disks^[num_disks].verzia:=block_ver[0]*100+
                        block_ver[1]*10+block_ver[2];
              data_disks^[num_disks].subor:=sr.name;
              data_disks^[num_disks].meno:='';
              load_level_list(sr.name,pole^);
           end;
        end;
        findnext(sr);
     until (doserror<>0) or (num_disks>19);
  end;

begin
     {$IFDEF Darwin} install_crash_handler; {$ENDIF}
     writeln('[LBC] enter');
     set_def;
     writeln('[SP] after set_def stack=', stackdepth);
     writeln('[LBC] after set_def');
     new(pole);
     new(data_disks);
		for f:=1 to maxlen do pole^[f]:=0;
		num_disks:=0;
		scan_disks('*.dat');
		scan_disks('*.DAT');
		dump_font_globals;
		writeln('[SP] after scan_disks stack=', stackdepth);
		writeln('[LBC] after scan_disks, num_disks=', num_disks);
		 if num_disks=0 then errormes(3);
		 writeln('[LBC] before select_datadisk');
		 writeln('[SP] before select_datadisk stack=', stackdepth);
		 if longint(screen)=0 then writeln('[LBC] screen NIL');
		 select_datadisk;
   dump_font_globals;
		 writeln('[LBC] after select_datadisk');
		 load_level_list(zvukovy_subor,pole^);
		 load_defaults;
     dispose(data_disks);
     dispose(pole);
     if crc_checking then verify_crc(zvukovy_subor);
     writeln('[LBC] done');
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

{======================================================================}
{ Phase 2: C-driven library. The original monolithic program body was }
{ split into engine_init / engine_step / engine_shutdown. The C host   }
{ owns the run loop and calls engine_step() one tick at a time.        }
{======================================================================}

{--- re-runnable game-state setup (was the "fatal_restart" block) -----}
procedure do_fatal_restart;
var
  bolx: boolean;   {was program-body local in the original monolithic body}
begin
    set_numsounds(num_snd);
    font:=def_font;
    out_sounds_to_def;
    load_defaults;
    set_def;
    dump_font_globals;
    bolx:=false;
    smart_jump:=true;              {SKOK}
   write_palette(blackx,0,256);
   dump_font_globals;
   load_pohyby;
   dump_font_globals;
   load_basic_config;
   dump_font_globals;
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
   write_palette(blackx,0,256);
   tma:=true;

{nahra animovane obrazky}
draw_it(anim_file,0,0);
for ff:=0 to 3 do
 for f:=0 to 19 do begin
   getseg(16*f,ff*16,16,16,f+ff*20,anim^);
 end;
   dump_font_globals;

   score:=0;
   basic_score:=0;
   gravity:=20;
   rolling:=30;
   write_palette(blackx,0,256);
   restart:=false;
   load_predmet;
   load_anim_def;
   load_texture;
   dump_font_globals;
   clear_bitmap(screen);
   dump_font_globals;

{   editor:=true;}
{    test:=true;}

  if aktivita_snd then begin
   sounds_loaded:=true;
  end;
   sipka_limit(8,9,612,398,4,use_joystick,5,false,false,true,true);
   if use_joystick then joystick_kaliber;
   oldpol:=poloha;
   dump_font_globals;
{   write_palette(palx,0,256);}
end;

{--- full engine init up to (but not into) the run loop -------------}
procedure engine_init;
var
  fil: file;   {was program-body local in the original monolithic body}
  fl:  word;   {was program-body local in the original monolithic body}
  _dbg_i: word;
begin
   {$IFDEF Darwin} install_crash_handler; {$ENDIF}
   (* Phase 3: the C host owns the clock. From here on GetClock returns the
      virtual clock the C host advances once per engine_step(). *)
   set_clock_virtual(true);
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
			  'W':win_now:=true;          { test hook: win current level on start }
	     end;
    end;
 if (s<>'/T') then writeln(tx2[ja,3]);
 end;

if not subor_exist(input_file) then ending(tx3[ja,2]);
   { --- load the real 8-bit palette from the DAT so the framebuffer is not
        all black. JXVAR only inits blackx; palx stays empty unless we fill
        it. load_palette_block reads the PALETA resource (256 RGB triplets)
        straight from input_file via the BLOCKX DAT reader (no C involved). }
   load_palette_block(input_file, '>PALETA', palx);
   writeln('[SD] palette loaded from ', input_file, ' (PALETA)');
   { --- TEMP diagnostic: dump loaded palette --- }
   for _dbg_i:=0 to 15 do writeln('[SDPAL] palx[',_dbg_i,']=',palx[_dbg_i].r,',',palx[_dbg_i].v,',',palx[_dbg_i].b);
   flush(output);
if memavail>minimummem then begin
   writeln;
   writeln('Init...');
   writeln('[SP] start stack=', stackdepth);
     use_joystick:=false;
     initclock;
     randomize;
     init_keyboard(0);
     keyboard_speed(0,0);
     set_def;
   writeln('[SP] after set_def(1) stack=', stackdepth);
   writeln('[SDPAL3] after engine_init set_def palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
     zvuk_loaded:=false;
     crc_checking:=true;
     set_defaults;  {nastavi zakladne parametre prikazoveho modu W}
   writeln('[SDPAL3] after set_defaults palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
     scrx:=640;
     scry:=480;
     resx:=16;
     resy:=16;
   check_crc;      {kontorla CRC pre MIAN.DAT}
   writeln('[SDPAL3b] after check_crc palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
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
   writeln('[SP] after XMS stack=', stackdepth);
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
   writeln('[SDPAL3c] after load_config palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
  if zvuk then begin
   write('Please wait, initializing SFX...');
   time:=getclock+inicializacna_pauza;
   write_ok;
  end;
  if zvuk then Initsbx;
   grafika_init(scrx,scry,8);
   (* Phase 2: SDL2 video backend + headless auto-input. *)
   auto_input_enabled := true;
   writeln('[MAIN] pre-vid_init GetEnv=', GetEnv('SG_DUMPFILE'));
   flush(output);
   vid_init;
   writeln('[SP] after vid_init stack=', stackdepth);
   writeln('[SDPAL3d] after vid_init palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
    write_palette(blackx,0,256);
   writeln('[SDPAL3e] after write_palette(blackx) palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
    old_frame.init(no_handle,input_file,frame_gif,false);
   writeln('[SDPAL3g] after old_frame.init palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
    napis.init(2,2,15,0,0,true,true);
   writeln('[SDPAL3g] after napis.init palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
    napis2.init(2,2,15,0,0,true,false);
   writeln('[SDPAL3g] after napis2.init palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
    aktivita_snd:=false;
    animabl:=false;
    check_sound:=false;
    set_font(def_font);
   dump_font_globals;
   writeln('[SDPAL3g] after set_font palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
   writeln('[SP] after fonts stack=', stackdepth);
   writeln('[SDPAL3f] END engine_init palx[1]=',palx[1].r,',',palx[1].v,',',palx[1].b);
{    out_sounds_to_def;
   zvuk_loaded:=false;}
end;   {end if memavail>minimummem}
end;   {engine_init body: setup only. C host calls engine_step() to drive the run
        loop, so engine_init must NOT enter do_fatal_restart / the
        disk-selection menu here (that would block and never return).}

{--- release backend resources --------------------------------------}
procedure engine_shutdown;
begin
  vid_shutdown;
end;

{--- C owns the keyboard: hand a scan-code into the auto-input queue --}
procedure engine_press_key(k: word);
begin
  auto_key_pending := k;
end;

{--- C owns the clock: hand the virtual-clock value (already advanced by the
     C host for this step) to the engine. While clock_virtual is on, every
     GetClock call in the engine returns this value, so all timing loops are
     paced by the C run loop. ---}
procedure engine_set_clock(c: longint);
begin
  set_clock_virtual(true);
  set_clock_value(c);
end;

{--- C drives the run loop: tell the engine whether the clock is C-owned.
     Called once from engine_init. ---}
procedure engine_start_clock;
begin
  set_clock_virtual(true);
end;

{--- framebuffer the backends draw from (230400 B, 320x240x24) -------}
function engine_buffer: pointer;
begin
  engine_buffer := @FrameRGB[0];
end;

{--- double-buffer generation index (headless SHMEM off 0) ----------}
function engine_generation: longint;
begin
  engine_generation := longint(gen);
end;

{--- top-level run-loop state machine -------------------------------}
var
  es_state    : integer;   { 0=boot, 10=intro menu, 11=menu tick, 12=level
                             selector, 13=quit confirm, 21=gameplay,
                             22=level-complete dialog, 9=done }
  es_selector : byte;

{--- C host observes the selected intro-menu item (1=Game,2=Info,..,0=ESC) ---}
function engine_selector: longint;
begin
  engine_selector := longint(es_selector);
end;

{--- top-level run-loop state accessor (C host observes progress) ---}
function engine_state: longint;
begin
  engine_state := longint(es_state);
end;

procedure engine_step;
var _nz,_i:longint;
begin
  dump_font_globals;
  case es_state of
  0: begin {first boot — run the re-runnable setup ONCE. This loads the data
            disks and drives the disk-selection menu (auto-advances in the
            headless build via auto_input_enabled). Returns to the C host
            afterwards so it can read the framebuffer and feed keys.}
       do_fatal_restart;
       dump_font_globals;
       es_state := 10;
     end;
  10: begin {intro-menu entry — run once, paints the menu + cursor setup}
       set_def;
       new(me);
       show_intro_page;
       vid_present;
       (* screenshot captured by the C driver's dump_ppm (P6 PNM) from FrameRGB *)
       reload_sound(5,zvukovy_subor,snd_intro);
       pust(5);
       choice_init;
       es_state := 11;
     end;
  11: begin {intro-menu tick — one choice step per engine_step. The C host
            feeds keys via engine_press_key(); they arrive through the same
            auto_input queue the headless backend reads.}
       choice_step;
       (* Phase 3: present each menu tick so the moving cursor / highlight the
          engine draws in choice_step is actually shown (previously the menu
          was painted only in state 10, so navigation was invisible). *)
       vid_present;
       if ch_done then begin
         es_selector := choice_result;
         dispose(me);
         case es_selector of
          {--- Phase 5: item 1 is 'Game'. Show the graphical level selector
              (state 12) instead of auto-picking level 1, matching the
              original `menu_pointer:=1; select_level; goto skip`. ---}
          1: begin sl_init := false; es_state := 12; end;
          0,4: es_state := 9;                 {ESC / Quit -> exit}
          2,3: es_state := 10;                {Info / Hi-scores -> back}
          else es_state := 9;
         end;
       end;
     end;
  12: begin {Phase 5: level selector — one menu tick per engine_step.
             select_level_init() paints the level list once; select_level_step()
             advances the cursor. On commit a chosen level starts the game
             (state 21); Back/ESC returns to the intro menu (state 10).}
       if not sl_init then select_level_init;
       select_level_step;
       vid_present;
       if sl_done then begin
          dispose(sl_menu);
          if sl_result > 0 then begin
             old_level := sl_result;
             hra_init;
             es_state := 21;
          end
          else es_state := 10;          { Back / ESC -> back to intro menu }
       end;
     end;
  21: begin {gameplay — exactly one frame per engine_step. The C host owns the
             clock and feeds movement keys; the arcade/maze loop is gated by
             arc_done/maze_done. On level WIN the level-complete coordinator
             (acc_init, run via use_vec) has set acc_init_flag -> finalise and
             move to the congratulations/next-level dialog (state 22). On
             game over (no lives) finalise and return to the intro menu.}
       if (arc_done) or (maze_done) then begin
          if acc_init_flag then begin
             hra_step_final;
             es_state := 22;          { level won -> congratulations dialog }
          end else begin
             hra_step_final;          { game over / restart -> intro menu }
             es_state := 10;
          end;
       end else begin
          hra_step;
          (* ESC during gameplay sets quit_pending instead of blocking: hand off
             to the step-able quit-confirmation dialog (state 13). *)
          if quit_pending then begin
             quit_pending := false;
             quit_init := false;
             quit_done := false;
             quit_result := 2;
             es_state := 13;
          end
          else if inv_pending then begin
             (* Phase 9: Enter/Space during gameplay opens the inventory /
                pause overlay. Clear inv_init so menu_init() re-paints the
                overlay fresh in es_state=23. *)
             inv_pending   := false;
             inv_init      := false;
             inv_done      := false;
             inv_direct_done := false;
             es_state := 23;
          end
          else begin
             vid_present;
          end;
       end;
     end;
  22: begin {Phase 8: level-complete dialog. acc_init() already painted the
             congratulations/password screen when the level was won. Wait for
             Enter (non-blocking via acc_step); then advance to the next level
             (inc(old_level), hra_init), or return to the intro menu if this
             was the last level (acc_last).}
       acc_step;
       vid_present;
       if acc_done then begin
          if acc_last then begin
             es_state := 10;          { last level: ending shown -> menu }
          end else begin
             inc(old_level);          { hra_init() sets vybrane:=old_level }
             hra_init;
             es_state := 21;
          end;
       end;
     end;
  13: begin {Phase 7: quit-level confirmation — one menu tick per engine_step.
             quit_confirm_init() paints the Yes/No box once; quit_confirm_step()
             advances the cursor. Yes (quit) -> level selector (state 12);
             No/ESC (continue) -> back to gameplay (state 21).}
       if not quit_init then quit_confirm_init;
       quit_confirm_step;
       vid_present;
       if quit_done then begin
          draw_scr(handles[2], 269, 170, 120, 120);
          kill_handle(handles[2]);
          dispose(quit_menu);
          quit_init := false;
          if quit_result = 1 then begin      { Yes -> quit level }
             sl_init := false;
             es_state := 12;
          end
          else es_state := 21;               { No/ESC -> continue game }
       end;
     end;
  23: begin {Phase 9: inventory / pause overlay — one menu tick per engine_step.
             menu_init() paints the overlay (or applies a direct-use object)
             once; menu_step() advances the cursor on each key press via the
             non-blocking kkey2 (like state 12 / 13). On commit, if the used
             item completed the level (the_koniec) finalise like state 21
             does: won (acc_init_flag) -> state 22, game over -> state 10.
             Otherwise resume gameplay (state 21).}
       if not inv_init then menu_init;
       menu_step;
       vid_present;
       if the_koniec then begin
          (* the used item finished the level — finalise like state 21 *)
          if acc_init_flag then begin
             hra_step_final;
             es_state := 22;          { level won -> congratulations dialog }
          end else begin
             hra_step_final;
             es_state := 10;          { game over -> intro menu }
          end;
       end
       else if (inv_direct_done) or (inv_done) then begin
          (* menu interaction finished, level not over — resume gameplay *)
          es_state := 21;
       end;
     end;
  end;
end;

{ --- Pascal body is the FPC entry (_main).  FPC's own startup (_PASCALMAIN)
       calls fpc_initializeunits() exactly ONCE before the program body.  We
       must NOT call it again here: a second hit on the now-initialised runtime
       reads a cleared system pointer and faults with EAccessViolation.  So we
       only drive the C host host_main(). --- }
begin
  host_main;
end.
