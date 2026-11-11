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
 {
  --- Phase: item-activation / level-start [TEXT] dialog state (step-able form
     of the old blocking pouzi_predmet(), driven by engine_step es_state=23
     and es_state=30). Only state that must survive between engine_step calls
     is global; per-token scratch lives locally in pouzi_predmet_step. ---
 }
   pp_started  : boolean;  { pouzi_predmet_init() has run for this dialog }
   pp_done     : boolean;  { command loop finished (END/breaker or no text) }
   pp_pending  : boolean;  { a dialog is queued (menu_init/menu_step/hra_init) }
   pp_num      : word;     { item/num index passed to pouzi_predmet_init }
   pp_z        : word;     { originating item index (for return-value handling) }
   pp_return   : boolean;  { return value for the caller (false=consumed) }
   pp_wait_mode: byte;     { 0=running, 1=waiting key, 2=waiting pulses }
   pp_wait_left: word;     { remaining pulses (mode 2) }
   pp_wait_cmd : byte;     { blocking command that triggered the wait }
   pp_jump     : byte;     { conditional jump requested (38-46) }
   pp_breaker  : boolean;  { END command seen }
   pp_close    : boolean;  { text finished; waiting for Enter/Space/ESC to close }
   pp_xx       : byte;     { current text-buffer index }
   pp_s        : string;   { current text-buffer line }
   pp_count    : word;     { position within the current line }
   pp_napis3   : TPrint;
   pp_new_frame, pp_pic_frame : TFrame;

{--- The [TEXT] command table. In the DOS source this was a LOCAL const of
     the blocking pouzi_predmet(); because that routine was split into
     pouzi_predmet_init()/pouzi_predmet_step() the table must now live at file
     scope so the step() routine can look each command up by name. ---}
const
   num_prikazy = 73;
   prikazy: array[1..num_prikazy] of string =
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

{--- Item-activation / level-start [TEXT] dialog, step-able form of the old
     blocking pouzi_predmet(). The DOS routine ran a blocking repeat-until loop
     over the [TEXT] command script, calling wait_for_key (a DOS keypressed
     block) and pulzx (a wall-clock block). We split it into init() (setup +
     read the first buffer line) and step() (one command/text token per
     engine_step), converting the blocking calls into per-step advances:
       KEY (9/15/23/73) -> wait until one key arrives (kkey2, non-blocking);
       PULZX (64)       -> advance after two engine ticks.
     Driven by engine_step: es_state=23 drives item activation (an object used
     from the activation zone, or a direct-use 'V' object) via menu_init/
     menu_step; es_state=30 drives the level-start start_action dialog.

     Only the state that must survive between engine_step calls is a global;
     the per-token scratch (sc, sx, a..e, f, ff, cis, por, found, sys, zal) is
     local to pouzi_predmet_step, since each token is fully processed in one
     step. ---}
function pouzi_predmet_init(num:word; typ:boolean):boolean;
var f, ff: word;
begin
   pp_done     := false;
   pp_started  := true;
   pp_wait_mode:= 0;
   pp_jump     := 0;
   pp_return   := true;
   pp_breaker  := false;
   pp_close    := false;
   lajn        := 0;
   (* text-frame setup *)
   pp_napis3.init(2,2,15,0,0,true,false);
   pp_new_frame.init(old_frame.ha_frame,'','',true);
   pp_new_frame.set_params(old_frame);
   pp_pic_frame.init(old_frame.ha_frame,'','',true);
   pp_pic_frame.set_params(old_frame);
   (* typ: swap in the pointed-at object index, mirror the original *)
   if typ then begin
      pp_z := own[num];
      own[num] := 0;
      num := pp_z;
   end;
   (* funk side-effects for a direct object use *)
   if typ then
     case vec^[num].funk of
        1: begin
             for f:=1 to nahrane_veci do
                if vec^[f].mie=vec^[num].inf1 then begin
                   vec^[f].mie:=miestnost;
                   reprint_predmet(num);
                end;
             new_screen;
          end;
        2: begin
             for f:=vec^[num].inf1 to vec^[num].inf3 do
                for ff:=vec^[num].inf2 to vec^[num].inf4 do
                   st.mie[f,ff]:=vec^[num].inf5;
          end;
        4: begin
             st.mie[vec^[num].inf1,vec^[num].inf2]:=vec^[num].inf3;
             odomkni_dvere(vec^[num].inf1,vec^[num].inf2);
          end;
     end;
   (* which text buffer to show *)
   if (start_action<>0) or (vec^[num].inf7>0) then begin
      if automatic then set_defaults;
      if start_action=0 then pp_xx:=vec^[num].inf7 else pp_xx:=start_action;
      start_action := 0;
      pp_count := 1;
      pp_s := vrat_text(pp_xx);
   end
   else begin
      (* no comment text -> the dialog is immediately done *)
      pp_done := true;
      pp_napis3.done;
      pp_new_frame.done;
      pp_pic_frame.done;
      rewait;
   end;
   pp_num := num;
   pouzi_predmet_init := true;
end;

procedure pouzi_predmet_step;
var k:word;
    sc,sx,zal       : string;
    a,b,c,d,e       : word;
    f,ff,cis,por : word;
    found,sys : boolean;
begin
   if pp_done then exit;

   (* --- waiting to close: the [TEXT] script has finished, so the dialog
      now waits for Enter / Space / ESC before returning to gameplay. This
      mirrors briefing_step (es_state=30): one key per engine_step, and a
      key-RELEASE word has bit 15 set and carries no character, so it is
      ignored -- only a fresh key-DOWN dismisses the dialog. This is what
      stops the item-activation screen from closing the instant it opens. *)
   if pp_close then begin
      k := kkey2;
      if (k <> 0) and ((k and $8000) = 0) then begin
         clear_key_buffer;
         if (k=kb_enter) or (k=kb_esc) or (k=$3920) then begin
            pp_close := false;
            pp_done  := true;
            pp_napis3.done; pp_new_frame.done; pp_pic_frame.done; rewait;
         end;
      end;
      exit;
   end;

   (* --- waiting state: a KEY command (9/15/23/73) or a PULZX (64) --- *)
   if pp_wait_mode=1 then begin
      k := kkey2;                       { one key per engine_step, non-blocking }
      if k=0 then exit;
      clear_key_buffer;
      pp_wait_mode:=0;
      case pp_wait_cmd of               { post-wait side effects of the command }
        15: begin pp_new_frame.kill_back; pp_pic_frame.kill_back; new_screen; end;
        23: cls;
        73: begin pp_new_frame.put_back; pp_pic_frame.put_back; end;
      end;   { 9 (KEY) has no pre/post side effects }
      exit;   { next step continues with the following token }
   end
   else if pp_wait_mode=2 then begin
      dec(pp_wait_left);                 { PULZX: advance after two ticks }
      if pp_wait_left<>0 then exit;
      pp_wait_mode:=0;
      exit;
   end;

   (* --- line exhausted (or a conditional jump requested): next buffer --- *)
   if (pp_count>=length(pp_s)) or (pp_s='') or (pp_jump>0) then begin
      if pp_jump>0 then begin inc(pp_xx); pp_jump:=0; end;
      inc(pp_xx);
      pp_s := vrat_text(pp_xx);
      pp_count := 1;
      if (pp_xx>255) or (pp_s='') then begin
         pp_close:=true;
         exit;
      end;
   end;

   (* --- process exactly one token (command or text) --- *)
   por:=1;
   mov_command(pp_s, sx, pp_count);

   if is_command(sx, sx) then begin
      mov_part(sx, sc, por);
      found:=false;
      for cis:=1 to 73 do
        if prikazy[cis]=sc then begin
          found:=true;
          mov_part(sx, sc, por);
          case cis of
            1: begin reload_sound(3,zvukovy_subor,sc); pust(3); end;
            2: begin play_ani('>'+sc); write_palette(blackx,0,256); tma:=true; redraw(true); increase_palette(blackx,palx,palette_speed); end;
            3: cls;
            4: decrease_palette(palx,palette_speed);
            5: increase_palette(blackx,palx,palette_speed);
            6: redraw(true);
            7: begin play_ani('>'+sc); write_palette(blackx,0,256); tma:=true; end;
            8: if handles[1].used then draw_scr(handles[1],0,0,640,480);
            9: begin pp_wait_mode:=1; pp_wait_cmd:=9; exit; end;
            10: set_def;
            11: if sc=YES then automatic:=true else automatic:=false;
            12: val(sc,text_y,text_y);
            13: val(sc,no_line,no_line);
            14: pp_napis3.set_color(value(sc));
            15: begin increase_palette(blackx,palx,palette_speed); pp_wait_mode:=1; pp_wait_cmd:=15; exit; end;
            16: begin inc(lajn); if not center then text_x:=100; end;
            17: val(sc,text_x,text_x);
            18: if sc=YES then pp_napis3.set_center(true) else pp_napis3.set_center(false);
            19: begin val(sc,a,a); mov_part_num(sx,b,por); mov_part_num(sx,c,por); go_to_new_stage(a,b,c); end;
            20: putseg2(pic_x,pic_y,resx,resy,0,13,ar^);
            21: putseg2xms(handles[4],pic_x,pic_y,resx,resy,vec^[pp_num].obr,13);
            22: begin val(sc,pic_x,pic_x); mov_part_num(sx,pic_y,por); end;
            23: begin increase_palette(blackx,palx,palette_speed); pp_wait_mode:=1; pp_wait_cmd:=23; exit; end;
            24: begin val(sc,a,a); mov_part_num(sx,b,por); mov_part_num(sx,c,por);
                  if (b>0) and (c>0) then putseg2xms(handles[4],b,c,resx,resy,a,13)
                  else putseg2xms(handles[4],text_x,text_y+lajn*no_line,resx,resy,a,13); end;
            25: begin val(sc,a,a); mov_part(sx,sc,por);
                  if a>1 then inc(a,126);
                  for f:=1 to nahrane_veci do
                     if vec^[f].mie=ord(sc[1]) then vec^[f].mie:=a; end;
            26: begin val(sc,a,a); if not scored[pp_xx] then inc(score,a); scored[pp_xx]:=true; end;
            27: pp_breaker:=true;
            28: begin val(sc,a,a); pp_xx:=a-1; end;
            29: begin val(sc,a,a); vec^[pp_num].inf7:=a; end;
            30: begin val(sc,a,a); vec^[pp_num].inf7:=a; pp_xx:=a-1; end;
            31: begin val(sc,a,a); mov_part(sx,sc,por);
                  for f:=1 to nahrane_veci do
                     if (length(vec^[f].meno)=5) and (vec^[f].meno[5]=sc[1]) then vec^[f].inf7:=a; end;
            32: begin val(sc,a,a); mov_part_num(sx,b,por); mov_part_num(sx,c,por); mov_part_num(sx,d,por); mov_part_num(sx,e,por);
                  for f:=a to c+a do for ff:=b to b+d do st.mie[f,ff]:=e; end;
            33: begin val(sc,a,a); load_map(a); save_map(aktual); end;
            34: begin val(sc,a,a); save_map(a); end;
            35: begin val(sc,a,a); mov_part_num(sx,b,por); si.x:=a*8+8; si.y:=b*8+8; si.oldx:=si.x; si.oldy:=si.y; end;
            36: begin val(sc,a,a); mov_part(sx,sc,por);
                  for f:=1 to nahrane_veci do
                     if (length(vec^[f].meno)=5) and (vec^[f].meno[5]=sc[1]) then begin vec^[f].mie:=a; vec^[f].meno[4]:=chr(a); end; end;
            37: begin val(sc,a,a); save_map(aktual); load_map(a); if a>1 then miestnost:=a+126 else a:=1; end;
            38: begin val(sc,a,a); mov_part_num(sx,b,por);
                  for f:=1 to 3 do begin
                     if vec^[own[f]].cislo=a then begin pp_xx:=b-1; pp_jump:=1; end;
                  end; end;
            39: begin val(sc,a,a); mov_part_num(sx,b,por);
                  for f:=1 to 3 do begin
                     if vec^[own[f]].cislo=a then begin vec^[own[f]].mie:=b; own[f]:=0; pp_jump:=1; end;
                  end; end;
            40: begin sys:=false; val(sc,a,a);
                  for f:=1 to 3 do begin
                     if own[f]=0 then begin sys:=true;
                        for ff:=1 to nahrane_veci do
                           if vec^[ff].cislo=a then begin vec^[ff].mie:=2; own[f]:=ff; break; end;
                        break;
                     end;
                  end;
                  if not sys then begin
                     for ff:=1 to nahrane_veci do
                        if vec^[ff].cislo=a then begin vec^[ff].mie:=miestnost; vec^[ff].x:=si.x; vec^[ff].y:=si.y; vec^[ff].ox:=si.x; vec^[ff].oy:=si.y; break; end;
                  end; end;
            41: begin val(sc,a,a); mov_part_num(sx,b,por); dej[a]:=b; end;
            42: begin val(sc,a,a); inc(dej[a]); end;
            43: begin val(sc,a,a); dec(dej[a]); end;
            44: begin val(sc,a,a); mov_part_num(sx,b,por); mov_part_num(sx,c,por);
                  if (dej[a])=b then begin pp_xx:=c-1; pp_jump:=1; end; end;
            45: begin val(sc,a,a); mov_part_num(sx,b,por); mov_part_num(sx,c,por);
                  if (dej[a])<b then begin pp_xx:=c-1; pp_jump:=1; end; end;
            46: begin val(sc,a,a); mov_part_num(sx,b,por); mov_part_num(sx,c,por);
                  if (dej[a])>b then begin pp_xx:=c-1; pp_jump:=1; end; end;
            47: pp_return:=false;
            48: pp_return:=true;
            49: begin zal:=sc; mov_part_num(sx,b,por); mov_part_num(sx,c,por); draw_it(zal,b,c); end;
            50: accomplished;
            51: strata_zivota;
            52: begin val(sc,b,b); inc(zivoty,b); end;
            53: set_font(sc);
            54: set_font(font);
            55: begin mov_part_num(sx,a,por); mov_part(sx,zal,por); mov_part_num(sx,b,por); mov_part_num(sx,c,por); uloz_nazov_obrazku(a,zal,b,c); end;
            56: begin val(sc,b,b); stage_image(b); end;
            57: begin val(sc,a,a); scan_x1:=a; mov_part_num(sx,a,por); scan_x2:=a; mov_part_num(sx,a,por); scan_y1:=a; mov_part_num(sx,a,por); scan_y2:=a; end;
            58: begin val(sc,a,a); mov_part(sx,sc,por); if sc=yes then priechody^[a].used:=true else priechody^[a].used:=false; end;
            59: begin val(sc,a,a); mov_part(sx,sc,por); if sc=yes then lift^[a].used:=true else lift^[a].used:=false; end;
            60: begin val(sc,a,a); mov_part_num(sx,b,por); lift^[a].rychlost:=b; end;
            61: begin val(sc,a,a); mov_part_num(sx,b,por); lift^[a].smer:=b; end;
            62: begin mov_part(sx,zal,por);
                  for a:=1 to nahrane_veci do
                     if (length(vec^[a].meno)>4) and (vec^[a].meno[5]=sc[1]) then begin
                        if zal=yes then vec^[a].meno[2]:='A' else vec^[a].meno[2]:='N';
                     end; end;
            63: begin mov_part_num(sx,b,por);
                  for a:=1 to nahrane_veci do
                     if (length(vec^[a].meno)>4) and (vec^[a].meno[5]=sc[1]) then begin vec^[a].obr:=b;
                        if not tma then begin zhasni_vec(vec^[a]); reprint_predmet(a); end;
                     end; end;
            64: begin pp_wait_mode:=2; pp_wait_left:=2; exit; end;
            65: begin decrease_palette(palx,1); redraw3; increase_palette(blackx,palx,1); end;
            66: begin val(sc,a,a); freez_time:=a; mov_part_num2(sx,unfreez_sound,por); end;
            67: begin a:=Value(sc); god_time:=a; mov_part_num2(sx,ungod_sound,por); end;
            68: if sc=YES then pp_napis3.set_shadow(true) else pp_napis3.set_shadow(false);
            69: pp_napis3.set_shadow_color(value(sc));
            70: begin a:=value(sc); mov_part_num(sx,b,por); mov_part_num(sx,c,por); mov_part_num(sx,d,por); old_frame.draw(a,b,c,d); end;
            71: begin text_x:=110; text_y:=110; pp_new_frame.draw(100,100,25,15); pp_napis3.print_shad(text_x,text_y,sc,true); inc(text_y,chardy*2); no_line:=chardy; end;
            72: begin pp_pic_frame.draw(35,35,1,1); a:=value(sc); putseg2xms(handles[4],50,50,resx,resy,a,13); end;
            73: begin rozsviet; pp_wait_mode:=1; pp_wait_cmd:=73; exit; end;
          end;
          break;   { stop searching prikazy -- one command per token }
        end;
      if not found then write_error(sx);
   end
   else begin
      (* plain text token *)
      if center then begin
         if sx<>'' then pp_napis3.print(text_x,text_y+lajn*no_line, sx);
      end
      else begin
         pp_napis3.print(text_x,text_y+lajn*no_line, sx);
         inc(text_x, length(sx)*chardx);
         text_x:=100;
         inc(lajn);
      end;
   end;

   (* --- END command finished the script --- *)
   if pp_breaker then begin
      pp_close:=true;
      exit;
   end;
end;

{--- Phase 9: step-able form of the old blocking menu() -- the inventory /
     pause overlay shown when Enter/Space is pressed during gameplay. C drives
     it via es_state=23 (one menu tick per engine_step). The blocking
     vyber_jxmenu() call is split into an init() that paints the overlay once,
     and a step() that advances the cursor on demand. Direct-use objects
     (V / non-W) are handled here and reported via inv_direct_done. ---}
procedure menu_init;
const max_menu=4;
var f:word;
    status,zobral:boolean;
    z:word;
begin
   (* reset overlay state for this entry *)
   inv_pending     := false;
   inv_init        := false;
   inv_done        := false;
   inv_result      := 0;
   inv_direct_done := false;
   inv_menu        := nil;
   inv_f           := 1;

   (* Direct-use paths: no inventory overlay required. A direct-use 'V'
      object may still carry a comment ([TEXT]); show it via the step-able
      dialog (pp_pending) driven by engine_step, instead of blocking here. *)
   if (mov>0) and (vec^[mov].meno[1]='V') then begin
      pp_num := mov;
      pp_z   := 0;
      pp_return := pouzi_predmet_init(mov,false);
      pp_pending := true;
      exit;
   end
   else if (mov>0) and (vec^[mov].meno[1]<>'W') then begin
      use_vec(mov);
      inv_direct_done := true;
      exit;
   end;

   (* --- Inventory overlay: paint it once --- *)
   menux := 4;
   status := false;
   zobral := false;
   new(inv_menu);
   init_jxmenu(200,170,0,15,0,tx[ja,25],inv_menu^);
   size_jxmenu(249,149,inv_menu^);
   first_jxmenu(4,inv_menu^);
   if mov>0 then begin
      (* place the pointed-at object into the inventory *)
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
         vec^[own[1]].x:=si.x+px; vec^[own[1]].y:=si.y+py;
         vec^[own[1]].ox:=si.x+px; vec^[own[1]].oy:=si.y+py;
         vec^[own[1]].mie:=miestnost;
         own[1]:=own[2]; own[2]:=own[3]; own[3]:=mov;
         reprint_predmet(z);
      end;
      zobral := true;
   end;

   save_scr(handles[2],200,170,256,160);
   for f:=1 to 3 do begin
      if own[f]=0 then
         vloz_jxmenu(260,f*30+170,tx[ja,26],inv_menu^,0)
      else
         vloz_jxmenu(260,f*30+170,vrat_nazov(vec^[own[f]].cislo),inv_menu^,0)
   end;
   vloz_jxmenu(260,290,tx[ja,22],inv_menu^,0);   { Return }
   old_frame.draw(200,170,14,8);
   draw_jxmenu3(inv_menu^);
   for f:=1 to 3 do
      if own[f]=0 then
         putseg2(inv_menu^.dat[f].x-30,inv_menu^.dat[f].y,resx,resy,45,13,ar^)
      else
         putseg2xms(handles[4],inv_menu^.dat[f].x-30,inv_menu^.dat[f].y,resx,resy,vec^[own[f]].obr,13);
   putseg2(inv_menu^.dat[4].x-30,inv_menu^.dat[4].y,resx,resy,44,13,ar^);
   draw_inventar;
   if not zobral then first_jxmenu(1,inv_menu^);

   inv_f := inv_menu^.first;
   inv_init := true;
end;

{--- Phase 9: one menu tick. Reads a single pending key from the C-fed
     auto_input queue (non-blocking kkey2, like select_level_step /
     quit_confirm_step), advances the cursor, and on Enter/Space/ESC commits.
     Replaces the blocking vyber_jxmenu() from the original menu(). ---}
procedure menu_step;
var ff,k:word;
    tester:boolean;
    u:word;
begin
   if inv_done then exit;
   if inv_menu = nil then exit;
   hi_jxmenu(inv_f, inv_menu^);
   k := kkey2;
   if k = 0 then exit;
   clear_key_buffer;
   normal_jxmenu(inv_f, inv_menu^);
   (* navigate up/down, wrapping when the menu is short *)
   case k of
     $4800,$4b00,$4838,$4b34,$4a2d:
        if inv_f>1 then dec(inv_f)
        else if inv_menu^.pocet<=inv_menu^.roll then inv_f:=inv_menu^.pocet;
     $5000,$4d00,$5032,$4d36,$4e2b:
        if inv_f<inv_menu^.pocet then inc(inv_f)
        else if inv_menu^.pocet<=inv_menu^.roll then inv_f:=1;
   end;
   (* a hotkey on a menu item jumps straight to it *)
   for ff:=1 to inv_menu^.pocet do
      if k=inv_menu^.dat[ff].k then inv_f:=ff;
   (* commit on Enter / Space / ESC *)
   if (k=$1c0d) or (k=$3920) then begin
      inv_result := inv_f;
      inv_done := true;
   end
   else if k=$011b then begin
      inv_result := 0;
      inv_done := true;
   end;
   if not inv_done then exit;

   (* --- selection committed: mirror the original menu() handling --- *)
   draw_scr(handles[2],200,170,256,160);
   kill_handle(handles[2]);
   if (inv_result>0) and (inv_result<4) and (own[inv_result]<>0) then begin
      (* place the selected item at the player, then use it *)
      vec^[own[inv_result]].x:=si.x+px; vec^[own[inv_result]].y:=si.y+py;
      vec^[own[inv_result]].ox:=si.x+px; vec^[own[inv_result]].oy:=si.y+py;
      if (vec^[own[inv_result]].x>vec^[own[inv_result]].x1) and
         (vec^[own[inv_result]].y>vec^[own[inv_result]].y1) and
         (vec^[own[inv_result]].x<vec^[own[inv_result]].x2) and
         (vec^[own[inv_result]].y<vec^[own[inv_result]].y2) and
         (vec^[own[inv_result]].st=miestnost) then begin
         (* item activation: run the [TEXT] dialog step-by-step via
            engine_step (es_state=23) instead of blocking here.
            pouzi_predmet_init() records the item index in pp_z and the
            consumed-flag in pp_return, handled after the dialog completes. *)
         pp_return := pouzi_predmet_init(inv_result,true);
         pp_pending := true;
      end
      else begin
         (* not at the item's activation zone: drop it back (mirror original) *)
         tester := false;
         for u := 1 to 3 do if own[inv_result]=0 then tester := true;
         zisti_vec;
         if mov = 0 then tester := true;
         if tester then begin
            vec^[own[inv_result]].mie:=miestnost;
            own[inv_result] := 0;
         end else
            zhasni_vec(vec^[mov]);
      end;
      (* shift inventory items down after a possible consumption *)
      if (own[1]=0) and (own[2]>0) then begin own[1]:=own[2]; own[2]:=0; end;
      if (own[2]=0) and (own[3]>0) then begin own[2]:=own[3]; own[3]:=0; end;
      (* redraw the scene under the overlay *)
      if not tma then begin
         reprint_predmet(own[inv_result]);
         draw_inventar;
      end else begin
         redraw(true);
         increase_palette(blackx,palx,10);
      end;
   end;
end;
