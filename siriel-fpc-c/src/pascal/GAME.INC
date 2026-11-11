{--- Phase 7 globals: step-able quit-level confirmation dialog (quit_confirm_*).
     Declared here (before arcade_step/maze_step) because those routines
     reference quit_pending on ESC. ---}
var
   quit_menu   : ^jxmenu_typ;   { Yes/No quit-confirmation menu }
   quit_f      : word;          { current selection: 1=Yes, 2=No }
   quit_done   : boolean;       { a selection was committed }
   quit_result : byte;          { chosen: 1=Yes(quit level), 2=No(continue) }
   quit_init   : boolean;       { has quit_confirm_init() run for this entry? }
   quit_pending: boolean;       { ESC pressed during gameplay -> enter confirm }

{--- Phase 11: step-able level-start objective dialog flags (briefing_init /
     briefing_step, driven by es_state=30 in engine_step). Declared up top so
     briefing_init/briefing_step (declared below) can reference them. ---}
   briefing_started : boolean;  { has briefing_init() run for this entry? }
   briefing_done    : boolean;  { objective dismissed (Enter/Space/ESC) or none }

{--- Phase 12: step-able Info/Help (state 40) and Hi-scores (state 41) screens
     from the main menu, plus the scrolling-help state shared by the Info
     screen and the in-game help key. Declared up top so the routines below
     (info_init/step, show_hi_score_init/step, scroll_text_init/step) can use
     them. ---}
var
   info_started : boolean;  { has info_init() run for this Info screen? }
   info_done    : boolean;  { Info/Help dismissed (Enter/Space/ESC) }
   info_ret     : integer;  { state to return to after Info (10=menu, 21=play) }
   hs_started   : boolean;  { has show_hi_score_init() run? }
   hs_done      : boolean;  { Hi-scores dismissed }
   help_pending : boolean;  { help key pressed during gameplay -> Info screen }

   {--- scrolling-help text state (used by info) ---}
   scroll_plocha  : array[0..maxlen] of byte;
   scroll_counter, scroll_inter, scroll_smer, scroll_size : integer;
   scroll_posuv, scroll_poloha : byte;
   scroll_started, scroll_done : boolean;
   scroll_oldfont : string;     { font active before scroll_text_init(); restored on exit }

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
   (* Phase 12: the Info/Help screen is now step-able (engine_state=40). Flag
      it and let engine_step hand off; info_ret points back to gameplay (21). *)
   info_ret := 21;
   help_pending := true;
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

procedure arcade_init;
begin
   same:=0;
   rewait;
   arc_done := false;
end;

procedure arcade_step;
var k2,b,c        : word;
    old5,old7     : boolean;
begin
   if arc_done then exit;
   (* TEST HOOK (/W cmd flag): force level completion on the first gameplay
      frame, mirroring the natural use_vec(funk=9)->accomplished path, so the
      state-21 -> state-22 transition and Enter-advance can be exercised. *)
   if win_now then begin accomplished; win_now:=false; end;
	  if rollup=0 then oldkey:=0;
	  k:=0;
	  vypis_skore;
   time:=getclock+wait_point;    { Phase 3: C paces the tick (was a blocking wait) }
	  sipka_joystick2;
	  (* Phase 7: read the key the C host injected via the auto_input queue.
	     Use geo's Jxgraf.Keypressed (auto_key_pending<>0), NOT crt's keypressed
	     which reads real stdin and is always false inside the Raylib window.
	     Matches the intro-menu / level-selector / input_key key path. *)
	  if Jxgraf.Keypressed then begin
      (* Phase 7b: feed the physical-key table BEFORE key() consumes the
         pending key. txt.key() returns auto_key_pending and zeroes it, so
         if we read key() first, get_keyboard() below would see 0 and Klx[]
         (read by zmack() for movement) would never be populated -> the
         character could not be steered. Restore the event-loop order:
         get_keyboard() first, then consume via key(). *)
      get_keyboard;
	k:=key;
	k2:=0;
	case k of
		    $3920,$1c0d:if ((not truth) or(not rolldown)) then begin
					(* Phase 9: open the inventory/pause overlay instead of the
					   old blocking menu(). The item use now happens async in
					   es_state=23, which finalises on the_koniec -- so the
					   synchronous `if sace` check is gone here. *)
					inv_pending := true;
		    end;
		    $3b00,$2368,$2348:begin
								help_in_game;
								rewait;
				end;
			$3e00,$1970,$1950:begin
								pauza;
				end;
		     $011b:begin quit_pending := true; clear_key_buffer; end;
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
   (* Phase 2: present the framebuffer to the display backend. *)
   vid_present;
   (* Phase 3: loop exits here instead of via goto gotta *)
   if (the_koniec) or (restart) then arc_done := true;
end;
var movx,movy,mova,mavb:word;

procedure maze_init;
begin
    arc_done := false;
    maze_done := false;
    new(bl);
    ds:=0;
    for f:=0 to mie_x do
	for ff:=0 to mie_y do
		bl^[f,ff]:=false;
    aktivuj_texturu;
    rewait;
end;

procedure maze_step;
var kdir: word;
begin
   if maze_done then exit;
   writeln('[POS] x=', si.x, ' y=', si.y);
	  if rollup=0 then oldkey:=0;
	  k:=0;
	  vypis_skore;
   time:=getclock+wait_point;    { Phase 3: C paces the tick (was a blocking wait) }
		sipka_joystick;
		get_keyboard;      { Phase 14: populate Klx[] from the injected key so the
		                      physical-key table reflects the C host's press (press
		                      sets, release clears) before we read it below. }
		if Jxgraf.Keypressed then begin
			k:=key;
			clear_key_buffer;
		   case k of
			$3b00,$2368:begin help_in_game; rewait; end;
			$3e00,$1970:pauza;
			$011b:begin quit_pending := true; clear_key_buffer; end;
			$1c0d,$3920:begin (* Phase 9: open the inventory/pause overlay
								(es_state=23) instead of the old blocking menu. *)
								inv_pending := true;
				end;
			$3f00,3062:briefing_in_game;
		   end;
		end;
		{--- Phase 14: maze movement is driven by the PHYSICAL key held, not just
		     the injected press event. Klx[] stays set while the key is held (the
		     C host forwards a press word on down and a break word on release), so
		     reading zmack() every frame makes the avatar walk continuously until
		     the key is released -- key repeat. This matches arcade_step, which
		     steers from zmack() each frame. ---}
		kdir := 0;
		if zmack(75) then kdir := $4b00;   { LEFT }
		if zmack(77) then kdir := $4d00;   { RIGHT }
		if zmack(72) then kdir := $4800;   { UP }
		if zmack(80) then kdir := $5000;   { DOWN }
		if kdir > 0 then begin
		   case kdir of
			  $4b00: begin pl(2); sipka_fake(kdir, si.x, si.y); end;
			  $4d00: begin pl(3); sipka_fake(kdir, si.x, si.y); end;
			  $4800: begin pl(7); sipka_fake(kdir, si.x, si.y); end;
			  $5000: begin pl(1); sipka_fake(kdir, si.x, si.y); end;
		   end;
		   if (not quit_pending) and ((not po3(si.x-movx,si.y-movy))  or
			  (not po3(si.x+mova,si.y-movy)) or
			  (not po3(si.x-movx,si.y))     or
			  (not po3(si.x+mova,si.y)))
			  then sipka_spat(si.x,si.y);
		   aktivuj_texturu;
		end;
			   panak;
			   si.oldx:=si.x;
			   si.oldy:=si.y;
			   oldpol:=poloha;
		   zisti_vec;
   (* Phase 2: present the framebuffer to the display backend. *)
   vid_present;
   (* Phase 3: loop exits here instead of via goto gotta *)
   if (the_koniec) or (restart) then maze_done := true;
   if maze_done then begin
	    dispose(bl);
	    bl:=nil;
   end;
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
		(* Phase 3: non-blocking. kkey blocks waiting for a key press; in the
		   C-driven model C paces the ticks, so auto-advance instead. *)
		k:=kkey2;
	end;
end;

{--- Phase 11: step-able form of the level-start objective dialog. The
	blocking briefing() above (used by briefing_in_game for the in-game F1
	review) is kept as-is; these two routines drive the objective shown when
	a level is started (briefing() in the original hra_init). briefing_init()
	paints the objective text once; briefing_step() reads exactly one key per
	engine_step and dismisses on Enter / Space / ESC (like acc_step / state 22). ---}
procedure briefing_init;
begin
   briefing_done := false;
   if (msg[1]<>'') or (msg[2]<>'') or (msg[3]<>'') or (msg[4]<>'')
	or (msg[5]<>'') then begin
		zhasni;
		clear_bitmap(screen);
		for f:=1 to 5 do
			printc(screen,f*(chardy*2)+150,msg[f],15,0);
		rozsviet;
		clear_key_buffer;
   end
   else briefing_done := true;      { no objective text -> nothing to show }
end;

procedure briefing_step;
var k:word;
begin
   if briefing_done then exit;
   (* Phase 11: non-blocking key wait. One key per engine_step (C paces the
      ticks). Dismiss on Enter / Space / ESC. A key-RELEASE word has bit 15
      set and carries no character, so ignore it. *)
   k := kkey2;
   if k <> 0 then begin
      clear_key_buffer;
      if (k and $8000) = 0 then
         if (k=kb_enter) or (k=kb_esc) or (k=$3920) then briefing_done := true;
   end;
end;

procedure hra_init;
begin
   if priechody	= nil then new(priechody);
   if lift		= nil then new(lift);
   lifting		  := false;
   pocet_priechodov := 0;
   pocet_vytahov    := 0;
   start_stage      := 1;
   (* Phase 8: the level-complete coordinator (acc_init/accomplished) uses
      vybrane to pick the NEXT level's password; keep it in step with old_level.
      Reset the level-complete flags so acc_init() runs fresh this level. *)
   vybrane          := old_level;
   acc_init_flag    := false;
   acc_done         := false;
   acc_last         := false;
   (* Phase 9: fresh inventory/pause overlay state each level -- the C host
      re-enters es_state=23 when Enter/Space is pressed, and menu_init()
      re-paints the overlay. *)
   inv_pending       := false;
   inv_init          := false;
   inv_done          := false;
   inv_direct_done   := false;
   inv_result        := 0;
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
  anim_count:=0;
  decrease_palette(palx,30);
  if start_action>0 then begin
     (* Level-start [TEXT] dialog. The old blocking pouzi_predmet() was split
        into pouzi_predmet_init()/pouzi_predmet_step(); initialise the dialog
        here and let engine_step drive it (es_state=23). No level sets
        start_action, so this branch is currently never taken, but it must
        still compile. *)
     clear_bitmap(screen);
     pp_started := false;
     pp_pending := pouzi_predmet_init(0,false);
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
  (* Phase 3: start the (now step-able) game loop *)
  case st.stav of
     1: arcade_init;
     2,3,4,5: maze_init;
  end;
  hra_playing := true;
  hra_final_run := false;
end;

procedure hra_step;
begin
   (* Phase 3: exactly one game frame per call. The loop itself is external,
      gated by arc_done/maze_done, driven by the C run loop. *)
   if not hra_playing then exit;
   case st.stav of
      1: arcade_step;
      2,3,4,5: maze_step;
   end;
end;

procedure hra_final;
begin
   (* Phase 3: runs once after the arcade/maze loop ends. *)
   if (not sace) then begin
		insert_score;
	    decrease_palette(palx,20);
	 end else inc(menu_pointer);
	    if (k=$011b) or (restart) then score:=0;

   if priechody	<> nil then dispose(priechody);
   if lift		= nil then dispose(lift);
   priechody	:= nil;
   lift		:= nil;
   hra_playing := false;
end;

procedure hra_step_final;
begin
   (* Phase 3: one-shot finalisation after the loop. *)
   if hra_playing then exit;
   if hra_final_run then exit;
   hra_final_run := true;
   hra_final;
end;

{--- Backwards-compatible entry used by select_level(). Runs the step-able
     game loop to completion in one shot (setup, frames, finalise). The C
     driver drives it one frame per engine_step() instead. ---}
procedure hra;
begin
   hra_init;
   while (not arc_done) and (not maze_done) do
      hra_step;
   hra_step_final;
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

procedure scroll_text_init;
var f:word;
    pch:string;
begin
   scroll_started := true;
   scroll_done := false;
   scroll_oldfont := font;      { remember active font; scroll uses def_font2 }
   set_font(def_font2);
   linew;
   scroll_posuv:=0;
   scroll_smer:=1;
   scroll_poloha:=1;
   scroll_counter:=0;
   for f:=0 to maxlen do scroll_plocha[f]:=0;
   if not checkblock_info(zvukovy_subor,scroll_sub) then scroll_sub:=scroll_subor;
   if checkblock_info(zvukovy_subor,scroll_sub) then
      begin
      loadblock_array(zvukovy_subor,scroll_sub,scroll_plocha);
      f:=0;
      repeat
         if scroll_plocha[f]>0 then scroll_plocha[f]:=ord(scroll_plocha[f])+2;
         inc(f);
      until (scroll_plocha[f]=0) or (f>maxlen);
      end
   else begin
      pch:=tx[ja,14];
      for f:=0 to length(pch)-1 do begin
          scroll_plocha[f]:=ord(pch[f+1]);
      end;
   end;
   scroll_size:=f;
   if scroll_size<maxlen-60 then begin
    for f:=scroll_size downto 0 do begin
    scroll_plocha[f+32]:=scroll_plocha[f];
    end;
    inc(scroll_size,33);
    for f:=0 to 31 do begin
    scroll_plocha[f]:=ord(' ');
    scroll_plocha[f+scroll_size]:=ord(' ');
    end;
    inc(scroll_size,32);
   end;
   scroll_inter:=0;
end;

function scroll_text_step:boolean;
var pch:string;
    k,f:word;
begin
   (* Phase 12: step-able. The original scrolled with a blocking pulz(2) delay
      and 'until keypressed' (crt's keypressed, always false in the C model).
      Here C paces the ticks: the inter counter advances the text every 4
      steps, and we read the C-driven input queue for Enter/Space/ESC. *)
   scroll_text_step := false;
   if scroll_done then exit;
   inc(scroll_inter);
   if scroll_inter=4 then begin scroll_inter:=0; inc(scroll_counter);end;
   if scroll_counter>scroll_size-30 then scroll_counter:=0;
   pch:='';
   for f:=1 to 30 do pch:=pch+chr(scroll_plocha[scroll_counter+f]);

   scroll_posuv:=scroll_posuv+scroll_smer;
   if (scroll_posuv=10) or (scroll_posuv=0) then begin
      scroll_smer:=-scroll_smer;
      inc(scroll_poloha);
      if scroll_poloha=7 then scroll_poloha:=1;
   end;
   printx2(screen,40-scroll_inter*2,200+scroll_posuv,pch+' ',64,2,2,1,0);
   linew2(scroll_posuv,scroll_poloha);
    sipka_joystick;
   if Jxgraf.Keypressed then begin
      k := key;
      clear_key_buffer;
      if (k=$1c0d) or (k=$3920) or (k=$011b) then begin
         scroll_done := true;
         set_font(scroll_oldfont);   { restore the menu font before leaving Info }
         scroll_text_step := true;
      end;
   end;
end;

procedure info_init;
begin
   info_done := false;
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
  scroll_text_init;
  pust(3);
end;

procedure info_step;
begin
   (* Phase 12: advance the scrolling help one frame per engine_step. When
      the user presses Enter/Space/ESC scroll_text_step sets scroll_done,
      which we propagate to info_done. *)
   if not scroll_text_step then exit;
   info_done := true;
end;



{--- Phase 2: step-able form of choice(). C drives one menu tick per call:
     choice_init() runs once, then choice_step() per engine_step. The blocking
     'repeat until getclock>=time' blink-wait is removed so C paces the menu. ---}
procedure choice_init;
begin
     k:=0;
     si.buf:=sir_buf;
     poloha:=0;
     ch_sel:=1;
     si.x:=me^.dat[ch_sel].x-25;
     si.y:=me^.dat[ch_sel].y+8;
     si.oldx:=si.x;
     si.oldy:=si.y;
     init_charakter(resx,resy,si.x,si.y,0,si.buf,ar^);
     rewait;
     ch_done:=false;
     ch_first:=false;
     ch_lastkey:=0;
end;

procedure choice_step;
var first:boolean;
begin
     first := false;
     if ch_done then exit;
     si.oldx:=si.x;
     si.oldy:=si.y;
     si.x:=me^.dat[ch_sel].x-25;
     si.y:=me^.dat[ch_sel].y+8;
     clear_key_buffer;
     {removed blocking 'repeat until getclock>=time;' — C paces the tick}
     time:=getclock+600;
     inc(poloha);
     if poloha>35 then poloha:=0;
     charakter(si.x,si.y,si.oldx,si.oldy,poloha,si.buf,ar^);
     if not first then begin
	 si.oldx:=si.x;
     si.oldy:=si.y;
     first:=true;
     hi_it(me^.dat[ch_sel]);
     end;
     k:=kkey2;
     if k<>0 then begin
     first:=false;
	  clear_key_buffer;
	  norm_it(me^.dat[ch_sel]);
	  case k of
		 $4800,$4b00:if ch_sel>1 then begin pust(0);dec(ch_sel); end;
		 $4d00,$5000:if ch_sel<me^.pocet then begin pust(0);inc(ch_sel); end;
	    end;
		  for f:=1 to me^.pocet do begin {zistuje, ci danemu menu existuje klavesa}
		    if k=me^.dat[f].k then begin
			 ch_sel:=f;
			 k:=$1c0d;
		end;
	    end;
  end;
  ch_lastkey:=k;
  if (k=$011b) or (k=$1c0d) or (k=$3920) then ch_done:=true;
end;

function choice_result:byte;
begin
  if k=$011b then choice_result:=0
  else choice_result:=ch_sel;
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

{--- Phase 5: step-able form of select_level(). C drives one menu tick per
     engine_step (state 12 in engine_step). The blocking vyber_jxmenu() call is
     split into an init() that paints the level list once, and a step() that
     advances the cursor on demand so the C host can pace it. ---}
var
   sl_menu : ^jxmenu_typ;   { level-selector menu (level list + BACK) }
   sl_f    : word;          { current selection within sl_menu }
   sl_done : boolean;       { a selection was committed }
   sl_result : byte;        { chosen level (0 = Back / ESC) }
   sl_init : boolean;       { has select_level_init() run for this entry? }

{--- Phase 13: step-able form of the datadisk selector. The original
     select_datadisk() blocked inside vyber_jxmenu(), incompatible with the C
     host feeding one key per engine_step. Split into an init() that paints the
     disk list once (mirroring select_level_init) and a step() that advances
     the cursor and commits on demand (mirroring select_level_step). The disk
     list is populated by the scan-only load_basic_config() before init() runs. ---}
   sd_menu     : ^jxmenu_typ;   { datadisk selector menu (disk list + end) }
   sd_f        : word;          { current selection within sd_menu }
   sd_done     : boolean;       { a selection was committed }
   sd_result   : word;          { chosen disk item (pocet/0 = end-of-game) }
   sd_init     : boolean;       { has select_datadisk_init() run? }
   sd_boot     : boolean;       { has do_fatal_restart() (disk scan) run? }
   sd_fatal    : boolean;       { only disk has a wrong version -> end the game }
   sd_hint     : boolean;       { wrong version on a multi-disk pick: show the
                                 message, wait for a key, then restart the menu }
   sd_end      : boolean;       { user committed the trailing "Konec"/End item
                                 (or ESC) -> quit the game instead of loading }
   sd_pole_buf : array[0..maxlen] of byte;  { scratch for load_level_list; must
                                             persist across the selection step }

{--- Phase 10: step-able password prompt for password-protected levels. When a
     level is selected whose subtitle is prefixed with '>' the engine prompts
     the player for the password (the level name without the '>'). Correct ->
     gameplay (state 21); wrong or ESC -> feedback and back to the level
     selector (state 12). The blocking insert_password() is split into an
     init() that paints the prompt/field once, and a step() that reads exactly
     one key per engine_step (like acc_step / state 22 and the menus above). ---}
   pw_password  : string;   { password required for the selected level }
   pw_field     : string;   { current password input field (with placeholder) }
   pw_init      : boolean;  { has password_init() run for this entry? }
   pw_done      : boolean;  { a password was submitted }
   pw_ok        : boolean;  { was the submitted password correct? }

{--- Loads level f's subtitle to detect whether it is password-protected.
     Detection uses the subor '>' marker (the same signal load_predmet2's
     `bl` uses); the password value is out_string(st.meno), matching the
     original select_level() branch. Sets old_level and, for protected
     levels, pw_password. Returns true iff a password is required. Non-protected
     levels are NOT loaded here -- the caller starts them via hra_init(). ---}
function level_needs_password(f:byte):boolean;
var sub:string;
begin
   old_level := f;
   sub := levely^.lev[f].subor;
   if sub<>'' then begin
      load_predmet2(sub);
      if st.meno[1]='>' then begin
         pw_password := out_string(st.meno);
         upcased(pw_password,pw_password);
         level_needs_password := true;
      end
      else level_needs_password := false;
   end
   else level_needs_password := false;
end;

procedure password_init;
begin
   (* Paint the ' Password:' prompt and the (empty) input field once. *)
   napis.print(0,400,tx[ja,17]+tx[ja,16]+':');
   napis2.set_color(14);
   pw_field := '';
   pw_field := pw_field + napis2.opt^.input_char;   { single placeholder '<' }
   napis2.print(0,420,pw_field);
   pw_init := true;
   pw_done := false;
   pw_ok   := false;
end;

procedure password_step;
var k:word;
    pw_cmp:string;
begin
   if pw_done then exit;
   (* one key tick per engine_step, via geo's non-blocking kkey2 (same as the
      intro / level-selector / quit-confirm menus) so the key always comes from
      the C-fed auto_input queue via Jxgraf.Keypressed -- never blocks. *)
   k := kkey2;
   if k <> 0 then begin
      clear_key_buffer;
      (* A key-RELEASE word has bit 15 set (scan byte >= $80). It carries no
         character -- it only clears the held-key flag in gameplay -- so it
         must never be typed inside this text field. Ignore release words. *)
      if (k and $8000) = 0 then begin
         (* printable char: replace the trailing placeholder, add a new one *)
         if (k<>kb_esc) and (k<>kb_back) and (k<>kb_enter) and (length(pw_field)<=10)
             and (k<>kb_up) and (k<>kb_down) and (k<>kb_left) and (k<>kb_right) then begin
            napis2.print_col(0,420,pw_field,0);
            pw_field[length(pw_field)] := chr(k);
            pw_field := pw_field + napis2.opt^.input_char;
            napis2.print(0,420,pw_field);
         end
         else if (k<>kb_esc) and (k<>kb_back) and (k<>kb_enter) then
            napis2.print(0,420,pw_field);                    { refresh, ignore nav key }
         (* backspace / submit *)
         if k=kb_back then begin
            if length(pw_field)>1 then begin
               napis2.print_col(0,420,pw_field,0);
               pw_field[0]:=chr(length(pw_field)-2);
               pw_field := pw_field + napis2.opt^.input_char;
               napis2.print(0,420,pw_field);
            end
            else napis2.print(0,420,napis2.opt^.input_char);
         end
         else if (k=kb_enter) or (k=kb_esc) then begin
            napis2.print_col(0,420,pw_field,0);
            if k=kb_esc then pw_field:=''
            else pw_field[0]:=chr(length(pw_field)-1);   { drop trailing placeholder }
            napis2.print(0,420,pw_field);
            (* validate: case-insensitive compare against the level password *)
            upcased(pw_field,pw_cmp);
            pw_ok := (pw_cmp = pw_password);
            pw_done := true;
            if pw_ok then begin
               napis2.set_color(15);
               napis2.print_col(0,440,tx[ja,18]+tx[ja,16]+' !',12);   { Correct }
               pust(0);
            end else begin
               napis2.set_color(15);
               napis2.print_col(0,440,tx[ja,19]+tx[ja,16]+' !',12);   { Incorrect }
               reload_sound(3,zvukovy_subor,snd_strata);
               pust(3);
            end;
         end;
      end;
   end;
end;

procedure select_level_init;
var f:word;
begin
   set_defaults;
   decrease_palette(palx,10);
   set_def;
   clear_all_data;
   clear_bitmap(screen);
   print_normal(screen,160,380,tx3[ja,7],14,0);
   new(sl_menu);
   init_jxmenu(200,40,0,15,0,'Level',sl_menu^);
   for f:=1 to levely^.pocet do
      vloz_jxmenu2(levely^.lev[f].meno,sl_menu^,0);
   (* BACK option — last item; selecting it returns sl_result = 0 *)
   vloz_jxmenu2('   '+tx[ja,22],sl_menu^,0);
   menu_pointer := 1;
   first_jxmenu(menu_pointer,sl_menu^);
   old_frame.draw(200,40,12,18);
   size_jxmenu(192,288,sl_menu^);
   draw_jxmenu3(sl_menu^);
   increase_palette(blackx,palx,10);
   sl_f := sl_menu^.first;
   sl_done := false;
   sl_result := 0;
   sl_init := true;
end;

procedure select_level_step;
var ff,k:word;
begin
   if sl_done then exit;
   hi_jxmenu(sl_f,sl_menu^);
   (* one key tick, mirroring choice_step: read exactly one pending key.
      Use geo's non-blocking kkey2 (same as the intro menu) so the key is
      always read from the C-fed auto_input queue via Jxgraf.Keypressed --
      never blocks, and never falls back to crt's terminal stdin. *)
   k := kkey2;
   if k <> 0 then begin
      clear_key_buffer;
      normal_jxmenu(sl_f,sl_menu^);
      (* navigate up/down, rolling the menu when the list is long *)
      case k of
        $4800,$4b00,$4838,$4b34,$4a2d:
           if sl_f>1 then begin dec(sl_f);
              if sl_f-1<sl_menu^.posuv then begin roll_menu_down(sl_menu^);
                 if sl_f>1 then normal_jxmenu(sl_f-1,sl_menu^); end;
           end
           else if sl_menu^.pocet<=sl_menu^.roll then sl_f:=sl_menu^.pocet;
        $5000,$4d00,$5032,$4d36,$4e2b:
           if sl_f<sl_menu^.pocet then begin inc(sl_f);
              if sl_f>sl_menu^.posuv+sl_menu^.roll then begin roll_menu_up(sl_menu^);
                 if sl_menu^.pocet>sl_f then normal_jxmenu(sl_f+1,sl_menu^); end;
           end
           else if sl_menu^.pocet<=sl_menu^.roll then sl_f:=1;
      end;
      (* a hotkey on a menu item jumps straight to it *)
      for ff:=1 to sl_menu^.pocet do
         if k=sl_menu^.dat[ff].k then sl_f:=ff;
      (* commit on Enter / Back-space / ESC *)
      if (k=$1c0d) or (k=$3920) or (k=$011b) then begin
         if k=$011b then sl_result:=0
         else if sl_f<sl_menu^.pocet then sl_result:=sl_f   { a real level }
         else sl_result:=0;                                  { BACK chosen }
         sl_done := true;
      end;
   end;
end;

{--- Phase 7: step-able form of ano_nie2() — the "Quit level? Yes/No" dialog
     shown when ESC is pressed during gameplay. C drives one menu tick per
     engine_step (state 13 in engine_step). The blocking vyber_jxmenu() call is
     split into an init() that paints the Yes/No box once, and a step() that
     advances the cursor on demand so the C host can pace it. ---}

procedure quit_confirm_init;
begin
   new(quit_menu);
   save_scr(handles[2], 269, 170, 120, 120);
   init_jxmenu(270, 180, 0, 15, 0, tx[ja,13], quit_menu^);   { title "Quit" }
   size_jxmenu(100, 100, quit_menu^);
   vloz_jxmenu2(tx[ja,23], quit_menu^, 0);   { Yes }
   vloz_jxmenu2(tx[ja,24], quit_menu^, 0);   { No }
   old_frame.draw(270, 180, 3, 3);
   size_jxmenu(64, 48, quit_menu^);
   draw_jxmenu3(quit_menu^);
   increase_palette(blackx, palx, 10);
   quit_f := quit_menu^.first;          { default highlight = Yes }
   quit_done := false;
   quit_result := 2;                     { safe default = continue }
   quit_init := true;
end;

procedure quit_confirm_step;
var ff,k:word;
begin
   if quit_done then exit;
   hi_jxmenu(quit_f, quit_menu^);
   (* one key tick, mirroring select_level_step: read exactly one pending key
      via geo's non-blocking kkey2 (same as intro menu / level selector) so the
      key is always read from the C-fed auto_input queue via Jxgraf.Keypressed --
      never blocks, and never falls back to crt's terminal stdin. *)
   k := kkey2;
   if k <> 0 then begin
      clear_key_buffer;
      normal_jxmenu(quit_f, quit_menu^);
      (* navigate the 2-item menu, wrapping between Yes and No *)
      case k of
        $4800,$4b00,$4838,$4b34,$4a2d:
           if quit_f>1 then dec(quit_f)
           else if quit_menu^.pocet<=quit_menu^.roll then quit_f:=quit_menu^.pocet;
        $5000,$4d00,$5032,$4d36,$4e2b:
           if quit_f<quit_menu^.pocet then inc(quit_f)
           else if quit_menu^.pocet<=quit_menu^.roll then quit_f:=1;
      end;
      (* commit: ESC = No/continue; Enter/Space = current highlighted item *)
      if (k=$011b) then begin
         quit_result := 2;                  { ESC -> continue playing }
         quit_done := true;
      end
      else if (k=$1c0d) or (k=$3920) then begin
         quit_result := quit_f;             { 1=Yes(quit level), 2=No(continue) }
         quit_done := true;
      end;
   end;
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

procedure show_hi_score_init;
var f:word;
    s:string;
begin
   hs_done := false;
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
end;

procedure show_hi_score_step;
var k:word;
begin
   (* Phase 12: step-able key wait. The original blocked on kkey; here C paces
      the ticks, so we read one key per engine_step and finish on
      Enter/Space/ESC. *)
   if hs_done then exit;
   k := kkey2;
   if k <> 0 then begin
      clear_key_buffer;
      if (k and $8000) = 0 then
         if (k=kb_enter) or (k=kb_esc) or (k=$3920) then hs_done := true;
   end;
end;
