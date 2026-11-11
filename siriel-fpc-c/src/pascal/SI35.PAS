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



{--- Phase 13: non-blocking, step-able form of the datadisk selector. The
     original select_datadisk() blocked inside vyber_jxmenu() waiting for a key,
     which is incompatible with the C host feeding one key per engine_step().
     Split into an init() that paints the disk list once (mirroring
     select_level_init), and a step() that advances the cursor and commits on
     demand (mirroring select_level_step). The disk list is populated by the
     scan-only load_basic_config() before init() runs. ---}
procedure select_datadisk_init;
var f,ff,fl:word;
begin
   g_sp := stackdepth;
   sd_fatal := false;
   sd_hint  := false;
   sd_end   := false;
   write_palette(blackx,0,256);
   clear_bitmap(screen);
   new(sd_menu);
   (* init the menu structure (dimensions/colors/title) before populating --
      mirrors the original select_datadisk() so draw_jxmenu3/normal_jxmenu get
      a valid menu instead of uninitialized fields. *)
   init_jxmenu(200,40,0,15,0,tx2[ja,2],sd_menu^);
   (* sort disks by lesser name with a simple bubble sort, then reverse --
      identical ordering to the original select_datadisk() so the list renders
      the same way.  The swap is a whole-record copy (diskx), so name/subor/
      version stay together.  The old tracker-based swap separated those fields
      on re-init, which garbled the disk names after returning to the menu. *)
   for f:=1 to num_disks-1 do begin
	   for ff:=f+1 to num_disks do begin
		   if data_disks^[ff].meno < data_disks^[f].meno then begin
			   diskd := data_disks^[f];
			   data_disks^[f] := data_disks^[ff];
			   data_disks^[ff] := diskd;
		   end;
	   end;
   end;
   for f:=1 to num_disks div 2 do begin
		  diskd:=data_disks^[f];
		  data_disks^[f]:=data_disks^[num_disks-f+1];
		  data_disks^[num_disks-f+1]:=diskd;
	   end;
   for f:=1 to num_disks do
      vloz_jxmenu2(data_disks^[f].meno,sd_menu^,0);
   vloz_jxmenu2(tx[ja,6],sd_menu^,0);
   (* single disk: no interactive menu, auto-select -- matches the original
      "else vybr:=1" path. *)
   if num_disks<=1 then begin
      if num_disks>=1 then begin
         zvukovy_subor:=data_disks^[1].subor;
         meno_disku:=data_disks^[1].meno;
      end;
      sd_result := 1;
      sd_done := true;
   end
   else begin
      (* multiple disks: paint the interactive menu. *)
      old_frame.draw(200,40,12,2+num_disks);
      size_jxmenu(192,288,sd_menu^);
      draw_jxmenu3(sd_menu^);
      write_palette(palx,0,256);
      vid_present;
      sd_f := 1;
      sd_result := 0;
      sd_done := false;
   end;
   sd_init := true;
end;

procedure select_datadisk_step;
var k,vybr:word;
    version_bad: boolean;
begin
   (* version-mismatch interstitial: show the warning, wait for a key, then
      restart the menu. Mirrors the original "goto znovku" branch. *)
   if sd_hint then begin
      printc(screen,440,tx3[ja,1],12,0);
      vid_present;
      if kkey2 <> 0 then begin
         clear_key_buffer;
         sd_hint := false;
         sd_f := 1;
         sd_result := 0;
         sd_done := false;
      end;
      exit;
   end;
   (* Single-disk auto path: init() already set zvukovy_subor/meno_disku to
      data_disks^[1]; here we only run the version check. The multi-disk menu
      commit is handled in the interactive block below -- state 0 consumes
      sd_done on the same step, so the disk selection can no longer be deferred
      here (that used to leave zvukovy_subor stuck at the load_basic_config
      placeholder = disk 0, CAULDRON, no matter what was selected). *)
   if sd_done then begin
      vybr := sd_result;
      version_bad := (vybr>0) and (vybr<=num_disks) and
                     (data_disks^[vybr].verzia > ver);
      if version_bad then begin
         if num_disks<=1 then sd_fatal := true
         else sd_hint := true;
      end;
      exit;
   end;
   (* interactive multi-disk selection: read exactly one pending key, like
      select_level_step / choice_step / acc_step. Never blocks. *)
   hi_jxmenu(sd_f, sd_menu^);
   k := kkey2;
   if k <> 0 then begin
      clear_key_buffer;
      normal_jxmenu(sd_f, sd_menu^);
      (* navigate up/down, rolling the menu when the list is long *)
      case k of
        $4800,$4b00,$4838,$4b34,$4a2d:
           if sd_f>1 then begin dec(sd_f);
              if sd_f-1<sd_menu^.posuv then begin roll_menu_down(sd_menu^);
                 if sd_f>1 then normal_jxmenu(sd_f-1, sd_menu^); end;
           end
           else if sd_menu^.pocet<=sd_menu^.roll then sd_f:=sd_menu^.pocet;
        $5000,$4d00,$5032,$4d36,$4e2b:
           if sd_f<sd_menu^.pocet then begin inc(sd_f);
              if sd_f>sd_menu^.posuv+sd_menu^.roll then begin roll_menu_up(sd_menu^);
                 if sd_menu^.pocet>sd_f then normal_jxmenu(sd_f+1, sd_menu^); end;
           end
           else if sd_menu^.pocet<=sd_menu^.roll then sd_f:=sd_menu^.pocet;
      end;
      (* commit: Enter / Space -> chosen item; ESC -> end-of-game (0). This is
         the fix for the selector always booting disk 0: record the actually
         selected disk HERE, because state 0 consumes sd_done on this same step
         and the selection can no longer be deferred to a later step.
         NOTE: sd_done := true MUST live inside each commit branch -- if it ran
         unconditionally it would fire on navigation keys (DOWN/UP) too,
         committing sd_result=0 (the placeholder disk) after the first arrow. *)
      if k=$011b then begin
         sd_result := 0;
         sd_end := true;
         sd_done := true;
      end
      else if (k=$1c0d) or (k=$3920) then begin
         sd_result := sd_f;
         if (sd_f>0) and (sd_f<=num_disks) then begin
            zvukovy_subor := data_disks^[sd_f].subor;
            meno_disku := data_disks^[sd_f].meno;
            sd_end := false;
            (* version check exactly once, mirroring the original
               post-vyber_jxmenu() branch *)
            if data_disks^[sd_f].verzia > ver then
               if num_disks<=1 then sd_fatal := true
               else sd_hint := true;
         end
         else
            sd_end := true;   { trailing End/Quit item -> quit }
         sd_done := true;
      end;
      vid_present;
   end;
end;


{nacita zoznam datadiskov}
procedure load_basic_config;

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
              load_level_list(sr.name, sd_pole_buf);
           end;
        end;
        findnext(sr);
     until (doserror<>0) or (num_disks>19);
  end;

begin
     {$IFDEF Darwin} install_crash_handler; {$ENDIF}
     set_def;
     new(data_disks);
		num_disks:=0;
		scan_disks('*.dat');
		scan_disks('*.DAT');
		 if num_disks=0 then errormes(3);
	 (* Phase 13: the disk-selection menu is driven non-blocking by state 0
	      (select_datadisk_init/step), so do NOT block here and do NOT dispose
	      the disk table -- init() builds its menu from data_disks. The scratch
	      buffer is the persistent global sd_pole_buf, reused by
	      load_level_list() after the selection commits. Pick the first disk as
	      a placeholder subor so the boot-time sound loading in do_fatal_restart
	      has a valid source; the real selection reloads SFX afterwards. *)
		 if num_disks>=1 then begin
			 zvukovy_subor := data_disks^[1].subor;
			 meno_disku := data_disks^[1].meno;
		 end;
		sd_init := false;
		sd_done := false;
		sd_fatal := false;
		sd_hint := false;
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
end;

{--- full engine init up to (but not into) the run loop -------------}
procedure engine_init;
var
  fil: file;   {was program-body local in the original monolithic body}
  fl:  word;   {was program-body local in the original monolithic body}
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
   flush(output);
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
   write_ok;
  end;
  if zvuk then Initsbx;
   grafika_init(scrx,scry,8);
   (* Phase 2: display backend + headless auto-input. *)
   auto_input_enabled := true;
   flush(output);
   vid_init;
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
                             22=level-complete dialog, 24=password prompt,
                             30=objective dialog, 40=info/help,
                             41=hi-scores,
                             9=done }
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
var _nz,_i:longint; f: word; _dcb,_ll:word; sel_key:word;
      sd_meno_save: array[1..19] of string[25];
begin
  case es_state of
  0: begin {first boot — run the heavy setup ONCE (do_fatal_restart scans the
            DAT disks via the scan-only load_basic_config), then drive the
            datadisk-selection menu non-blocking, one key per engine_step,
            exactly like the level selector (state 12). On a committed,
            version-valid selection the chosen disk's levels + defaults are
            loaded and the engine enters the intro menu (state 10).}
       if not sd_boot then begin
          do_fatal_restart;
          sd_boot := true;
       end
       else begin
          if not sd_init then select_datadisk_init;
          select_datadisk_step;
          vid_present;
          if sd_fatal then begin
             ending('');
          end
          else if sd_end then begin
             ending('');
          end
          else if sd_hint then begin
             (* version warning already shown by select_datadisk_step; wait for
                a key there before the menu restarts -- do NOT load yet. *)
          end
          else if sd_done then begin
             (* committed + version OK: load the chosen disk's levels +
                defaults, reload SFX for that disk, then the intro menu. *)
             (* load_level_list() has a side effect: when the disk config
                contains a MENO field it writes data_disks^[num_disks].meno.
                During scan num_disks is the freshly-added index, so that is
                correct. Here, at commit time, num_disks is the TOTAL count,
                so the call would overwrite an unrelated disk's display name
                (e.g. disk 3) with the committed disk's name, which the
                subsequent sort then duplicates/garbles. Save and restore the
                display names across the call so the disk table is untouched. *)
             for _dcb:=1 to num_disks do sd_meno_save[_dcb]:=data_disks^[_dcb].meno;
             load_level_list(zvukovy_subor, sd_pole_buf);
             writeln('[LEVELS] disk=',zvukovy_subor,' pocet=',levely^.pocet); flush(output);
             for _dcb:=1 to num_disks do data_disks^[_dcb].meno:=sd_meno_save[_dcb];
             load_defaults;
             if zvuk_loaded then
                for f:=1 to num_snd do
                   reload_sound(f-1, zvukovy_subor, zvuky[f]);
             if crc_checking then verify_crc(zvukovy_subor);
             dispose(sd_menu);
             es_state := 10;
          end;
       end;
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
         es_selector := choice_result;   (* 0 = ESC, else 1-based index into me^.dat *)
         (* Capture the selected item's DOS key word BEFORE disposing the menu,
            so we can route by the item's identity (position-independent)
            rather than by its index. Quit ($1071) exits no matter where it
            sits in the menu, and DATADISK ($2064) is matched by key too. *)
         if es_selector > 0 then sel_key := me^.dat[es_selector].k
         else sel_key := 0;               (* ESC: no item key selected *)
         dispose(me);
         if es_selector = 0 then begin
            (* ESC -> exit *)
            es_state := 9;
         end else if sel_key = $1071 then begin
            (* Quit -> exit *)
            es_state := 9;
         end else if (sel_key = $2064) and (num_disks > 1) then begin
            (* DATADISK item: return to the datadisk selector. Re-init
               resets all flags and re-paints the disk list. *)
            sd_init := false;
            es_state := 0;
         end else begin
            (*--- Phase 5: route by the selected item's key. Game ($2267)
                shows the graphical level selector (state 12) instead of
                auto-picking level 1, matching the original
                `menu_pointer:=1; select_level; goto skip`. ---*)
            case sel_key of
             $2267: begin sl_init := false; es_state := 12; end;
             $1769: begin {Phase 12: Info/Help screen} info_ret := 10; info_started := false; es_state := 40; end;
             $2368: begin {Phase 12: Hi-scores screen} hs_started := false;  es_state := 41; end;
             else es_state := 9;
            end;
         end;
       end;
     end;
  12: begin {Phase 5: level selector — one menu tick per engine_step.
             select_level_init() paints the level list once; select_level_step()
             advances the cursor. On commit a chosen level starts the game
             (state 21); Back/ESC returns to the intro menu (state 10).
             Password-protected levels (subtitle prefixed with '>') prompt for
             the password first via state 24.}
       if not sl_init then begin select_level_init; end;
       select_level_step;
       vid_present;
       if sl_done then begin
          dispose(sl_menu);
          if sl_result > 0 then begin
             (* Phase 10: detect a password-protected level before starting.
                level_needs_password() loads the subtitle and, if protected,
                stores the password in pw_password and returns true. *)
             if level_needs_password(sl_result) then begin
                pw_init := false;
                es_state := 24;
             end
             else begin
                hra_init;
                briefing_started := false;
                es_state := 30;
             end;
          end
          else es_state := 10;          { Back / ESC -> back to intro menu }
       end;
     end;
  24: begin {Phase 10: password prompt for password-protected levels. writeln('[S24] ENTER',flush(output));
             password_init() paints the ' Password:' prompt and field once;
             password_step() reads one key per engine_step. Correct -> start
             the game (state 21); wrong password or ESC -> feedback and back
             to the level selector (state 12).}
       if not pw_init then password_init;
       password_step;
       vid_present;
       if pw_done then begin
          pw_init := false;
          if pw_ok then begin
             hra_init;
             briefing_started := false;
             es_state := 30;          { objective -> gameplay }
          end
          else begin
             (* wrong / ESC: back to the level selector, freshly re-painted *)
             sl_init := false;
             es_state := 12;
          end;
       end;
     end;
  30: begin {Phase 11: level-start objective dialog. hra_init() (run when
             entering this state) already loaded the level data (msg[]) and
             drew the game screen. briefing_init() paints the objective text
             once; briefing_step() reads one key per engine_step. On
             Enter / Space / ESC the objective is dismissed, the game screen
             is redrawn, and gameplay begins (state 21). Levels with no
             objective text skip straight to gameplay.}
       if not briefing_started then begin briefing_init; briefing_started := true; end;
       briefing_step;
       vid_present;
       if briefing_done then begin
          briefing_started := false;
          redraw(true);                 { restore the game screen the objective replaced }
          es_state := 21;               { -> gameplay }
       end;
     end;
  40: begin {Phase 12: Info/Help screen (main menu item 2, and the in-game help
             key). info_init() draws the credits page and sets up the scrolling
             help; info_step() advances one frame per engine_step. On
             Enter/Space/ESC return to info_ret (10=main menu, 21=gameplay).}
       if not info_started then begin info_init; info_started := true; end;
       info_step;
       vid_present;
       if info_done then begin
          info_started := false;
          if info_ret = 21 then redraw(true);   { restore the game screen the Info replaced }
          es_state := info_ret;
       end;
     end;
  41: begin {Phase 12: Hi-scores screen (main menu item 3). show_hi_score_init()
             paints the table once; show_hi_score_step() waits for
             Enter/Space/ESC, then returns to the main menu (state 10).}
       if not hs_started then begin show_hi_score_init; hs_started := true; end;
       show_hi_score_step;
       vid_present;
       if hs_done then begin
          hs_started := false;
          es_state := 10;
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
          else if help_pending then begin
             (* Phase 12: help key during gameplay opens the Info/Help screen.
                info_ret is already 21 (set by help_in_game). Clear the flag
                and reset info_started so info_init() re-paints the screen fresh. *)
             help_pending := false;
             info_started := false;
             info_done := false;
             es_state := 40;
          end
          else if inv_pending then begin
             (* Phase 9: Enter/Space during gameplay opens the inventory /
                pause overlay. Clear inv_init so menu_init() re-paints the
                overlay fresh in es_state=23. Also clear any queued item-
                activation dialog so menu_init/menu_step start fresh. *)
             inv_pending   := false;
             inv_init      := false;
             inv_done      := false;
             inv_direct_done := false;
             pp_pending    := false;
             pp_started    := false;
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
             inc(old_level);          { advance to next level }
             (* The user just unlocked this level by finishing the previous
                one, so NO password is required here. The password only gates
                the Level Selector (state 12), where a player may SKIP AHEAD to
                a locked level. Go straight to the briefing, then gameplay. *)
             hra_init;
             briefing_started := false;
             es_state := 30;
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
             Two sub-phases, selected by a flag:
               * pp_pending: an item-activation [TEXT] dialog was queued by
                 menu_init/menu_step (a direct-use 'V' object, or a committed
                 inventory item used from its activation zone). pouzi_predmet_
                 init() already painted the first line; pouzi_predmet_step()
                 advances one command/text token per engine_step (converting
                 the old blocking wait_for_key / pulzx into per-step advances).
                 When pp_done, finalise like state 21 if the dialog won the
                 level (the_koniec via THEEND/LOSELIFE), else resume gameplay.
               * otherwise: the inventory / pause overlay. menu_init() paints
                 it (or applies a direct-use object) once; menu_step() advances
                 the cursor on each key press via the non-blocking kkey2 (like
                 state 12 / 13). On commit, if the used item completed the
                 level (the_koniec) finalise like state 21 does.
             The pp_pending dialog takes precedence so the item-activation
             screens step-able like briefing (es_state=30).}
       if pp_pending then begin
          pouzi_predmet_step;
          vid_present;
          if pp_done then begin
             (* DONTUSE (command 47): the item was not consumed, so put it
                back into the level (pp_z>0 only for a committed inventory
                item; a direct-use 'V' dialog has pp_z=0 and nothing to return). *)
             if (pp_z>0) and (not pp_return) then vec^[pp_z].mie:=miestnost;
             pp_pending := false;
             pp_started := false;
             if the_koniec then begin
                (* the dialog finished the level — finalise like state 21 *)
                if acc_init_flag then begin
                   hra_step_final;
                   es_state := 22;          { level won -> congratulations }
                end else begin
                   hra_step_final;
                   es_state := 10;          { game over -> intro menu }
                end;
             end else es_state := 21;          { dialog done — resume gameplay }
          end;
       end
       else begin
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
end;

{ --- Pascal body is the FPC entry (_main).  FPC's own startup (_PASCALMAIN)
       calls fpc_initializeunits() exactly ONCE before the program body.  We
       must NOT call it again here: a second hit on the now-initialised runtime
       reads a cleared system pointer and faults with EAccessViolation.  So we
       only drive the C host host_main(). --- }
begin
  host_main;
end.
