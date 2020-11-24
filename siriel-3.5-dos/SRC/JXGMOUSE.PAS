{unit created by GEORGESOFT}
unit jxgmouse;

interface

uses dos,txt,jxxms,jxefekt,jxgraf,blockx,jxvar,jxmenu,funct,animing;

const max_mpic_x        = 24;
	max_mpic_y        = 24;
	max16             = 16383;
	mouse_header      = 'Mouse rec block';

{----------------EVENTS-----------------}
     ev_none          = 0;
     ev_quit          = 1;
     ev_ok            = 2;
     ev_cancel        = 3;
     ev_select        = 4;
     ev_unselect      = 5;
     ev_start         = 6;
     ev_up            = 7;
     ev_down          = 8;
     ev_left          = 9;
     ev_right         = 10;
     ev_play          = 11;
     ev_stop          = 12;
     ev_save          = 13;
     ev_saveas        = 14;
     ev_load          = 15;
{----------------SPECIALS---------------}
     ON               = true;
     OFF              = false;
{----------------SIGNS------------------}
     si_end           = 'END';
     si_ok            = 'Ok';
     si_cancel        = 'Cancel';
{----------------COMMANDS---------------}
     cm_none          = 0;
     cm_scroff        = 1;
     cm_scron         = 2;
{----------------MENU-------------------}
     basic_menu       = 0;
     selector_menu    = 1;
{---------------------------------------}

type
    myska=record
		  cas       : longint;
		  poz,obr   : array[1..max_mpic_x*max_mpic_y] of byte;
		  x,y,ox,oy : word;
		  pic,count : byte;
                  mouse_file: string[13];
                  rx1,rx2,ry1,ry2 :word;
                  under_mouse: boolean;
    end;

    Ptlac=^Ttlac;
    Ttlac=record
		  x,y,dx,dy         : word;
		  pic,pic2,floor    : byte;
		  s                 : string[20]; {napis}
		  stav,visible,useable : boolean;
		  col               : byte;
		  handle            : klucka;
		  event             : word;
		  flash             : boolean;
                  next              : Ptlac;
    end;                                          {skupina tlacitok}
    PButtonGroup = ^TButtonGroup;
    TButtonGroup = record
                    next            : PButtonGroup;
                    Button          : Ptlac;
                  end;

    Pmouse      = ^Tmouse;
     Tmouse     = object
                   mys        : ^myska;
                   BGroup     : PButtonGroup;
                   constructor init(name:string);
                   function  insert(x,y,dx,dy:word;napis:string;pic1,pic2:word;col:byte;
	                           var handle:klucka;useable:boolean;floor:byte;event:word;next:Ptlac):Ptlac;
                   function  check:word;
                   procedure beta_test;
                   procedure turn_off;
                   procedure turn_on;
                   procedure change_button(p:PTlac);
                   procedure flash_button(p:PTlac);
                   procedure swap_button_pictures(p:PTlac);
                   procedure print_buttons;
                   destructor  done;
                  end;



    tlac=record
		  x,y,dx,dy         : word;
		  pic,pic2,floor    : byte;
		  s                 : string[20]; {napis}
		  stav,visible,useable : boolean;
		  col               : byte;
		  handle            : klucka;
		  event             : word;
		  flash             : boolean;
{                  next              : Ptlac;}
    end;



    zaznam = record
		  x,y       : word;
		  but       : byte;
		  time      : word;
    end;
    point  = record
                  x,y,dx,dy : word;
    end;
    napis  = record
                  place : point;
                  name  : string[64];
    end;

var under_mouse         : boolean;
    mpic_x,mpic_y       : word;  {velkost obrazku mysky}
    num_but             : word;
    num_but_2           : word;
    timer               : longint;
    point_record        : word; {ukazuje na posledne nahraty objekt}
    button_flash        : boolean; {ak an tak tlacitko po stlaceni zablika}
    flash_number        : word;    {pocet zablikani}
    flash_time          : word;    {cas medzi bliknutiami}
    basic_button        : tlac;
    event               : word;
    command             : word;
    no_handle           : klucka;
    message             : napis;

function  print_mouse(var buttons:array of tlac;var mys:myska):word; {vykresli mys a zistuje tlacitka}
function  print_mouserec(var buttons:array of tlac;var mys:myska;var rec:zaznam):word;
procedure change_button(var buttons:array of tlac;f:word);
{procedure init_grmouse(var kluc:klucka);}
function  execute_command:word;

procedure init_buttons(var buttons:array of tlac; num:word);
procedure insert_button(var buttons:array of tlac;x,y,dx,dy:word;napis:string;pic1,pic2:word;col:byte;
	     var handle:klucka;useable:boolean;floor:byte;event:word);
procedure insert_button2(var buttons:array of tlac);
procedure reset_basic_button;
procedure set_basic_XY(x,y:word);
procedure set_basic_DXY(x,y:word);
procedure set_basic_XY_name(x,y:word;s:string);
procedure set_basic(x,y:word;s:string;event:word);

procedure print_buttons(var buttons:array of tlac;var mys:myska);

procedure zhasni_mys(var mys:myska);
procedure rozsviet_mys(var mys:myska);

procedure disable_all_buttons(var buttons:array of tlac);
procedure active_floor(var buttons:array of tlac;floor:byte);
procedure add_floor(var buttons:array of tlac;floor:byte);

procedure print_button(var buttons:array of tlac;var mys:myska;f:word);

{procedure load_mouse(var mys:myska;mouse_file:string;dx,dy:word;var palx:tpalette);
procedure basic_mouse_init(var mys:myska;x1,y1,x2,y2:word);                         }

{recording part}
procedure init_recording;
function  record_mouse(var buttons:array of tlac;var mys:myska;var rec:array of zaznam):word;
procedure done_recording(var rec:array of zaznam; file_name:string);
procedure load_mouse_record(file_name:string;var rec:array of zaznam);
procedure insert_record(var rec:array of zaznam;var mys:myska);
procedure convert_mouse_record(file1,file2:string);

procedure flash_button(var buttons:array of tlac;var mys:myska; timex,but_num,flash_num:word);
procedure swap_button_pictures(var button:tlac);

function  vyber_jxmenu_mouse(var menx:jxmenu_typ;var buttons:array of tlac;var mys:myska;typ:byte):boolean;
procedure RPR_mouse(var buttons:array of tlac;var mys:myska);
procedure PR_mouse(var buttons:array of tlac;var mys:myska);

function  select_file(var place:point;mask:string;var mys:myska):string;
procedure set_point(var place:point;x,y,dx,dy:word);
procedure set_message(meno:string;x,y,dx,dy:word);

implementation

uses mouse,geo;

procedure m_test(var buttons:array of tlac;var mys:myska);
var f     : word;
begin
	 for f:=0 to num_but-1 do begin  {skontroluje, ci je myska na nejakom tlacitku}
	     if (buttons[f].visible) and (buttons[f].useable)then begin {ak je tlacitko viditelne}
		    if buttons[f].stav then begin {a podla jeho stavu}
		     if (buttons[f].x>mouse_posx) or (buttons[f].x+buttons[f].dx<mouse_posx)
			or (buttons[f].y>mouse_posy) or (buttons[f].y+buttons[f].dy<mouse_posy)
			 then begin
			 if not under_mouse then zhasni_mys(mys);
			 under_mouse:=true;
			 buttons[f].stav:=false;
			 change_button(buttons,f);
			end;
		    end
		    else begin
		     if (buttons[f].x<mouse_posx) and (buttons[f].x+buttons[f].dx>mouse_posx)
			and (buttons[f].y<mouse_posy) and (buttons[f].y+buttons[f].dy>mouse_posy)
			 then begin
			 if not under_mouse then zhasni_mys(mys);
			 under_mouse:=true;
			 buttons[f].stav:=true;
			 change_button(buttons,f);
		    end;
		  end;
	     end;
	 end;
end;

procedure Tmouse.change_button(p:Ptlac);
begin
  if (p^.visible) and (p^.useable) then begin
   if (p^.stav) then begin
     if p^.handle.used then begin
         putseg2xms(p^.handle,p^.x,p^.y,p^.dx,p^.dy,p^.pic2,13);
         print_normal(screen,p^.x+(p^.dx div 2)-(chardx*length(p^.s) div 2),p^.y+
			(p^.dy div 2)-(chardy div 2)-2,p^.s,p^.col,0);
        end
        else
        print_normal(screen,p^.x,p^.y,p^.s,p^.pic2,p^.col);
    end else
     if p^.handle.used then begin
       putseg2xms(p^.handle,p^.x,p^.y,p^.dx,p^.dy,p^.pic,13);
       print_normal(screen,p^.x+(p^.dx div 2)-(chardx*length(p^.s) div 2),p^.y+
		   (p^.dy div 2)-(chardy div 2)-2,p^.s,p^.col,0);
     end else
        print_normal(screen,p^.x,p^.y,p^.s,p^.pic,p^.col)
   end;
end;


procedure Tmouse.beta_test;
var f     : word;
    p     : Ptlac;
begin
         p:=BGroup^.button;
         while p<>nil do begin
            if (p^.visible) and (p^.useable)then begin
             if p^.stav then begin
              if (p^.x>mouse_posx) or (p^.x+p^.dx<mouse_posx)
		  or (p^.y>mouse_posy) or (p^.y+p^.dy<mouse_posy)
                   then begin
                     if not mys^.under_mouse then Tmouse.turn_off;
		     mys^.under_mouse:=true;
		     p^.stav:=false;
		     change_button(p);
                     end;
	           end else begin
		    if (p^.x<mouse_posx) and (p^.x+p^.dx>mouse_posx)
			and (p^.y<mouse_posy) and (p^.y+p^.dy>mouse_posy)
			 then begin
			  if not mys^.under_mouse then Tmouse.turn_off;
 			  mys^.under_mouse:=true;
			  p^.stav:=true;
			  change_button(p);
		         end;
                   end;
                  end;
            p:=p^.next;
         end;
end;

function Tmouse.check:word;
var f    : word;
    p    : PTlac;
begin
     check:=ev_none;
     mousepos;
	if (mys^.under_mouse) or ((mouse_posy<>mys^.y) or (mouse_posx<>mys^.x)) then begin
 	if not mys^.under_mouse then beta_test;

	  if not mys^.under_mouse then putseg(mys^.x,mys^.y,mpic_x,mpic_y,0,mys^.poz)
	     else mys^.under_mouse:=false;
	  mys^.oy:=mys^.y;
	  mys^.ox:=mys^.x;
	  mys^.x:=mouse_posx;
	  mys^.y:=mouse_posy;
	  getseg(mys^.x,mys^.y,mpic_x,mpic_y,0,mys^.poz);
	  putseg2(mouse_posx,mouse_posy,mpic_x,mpic_y,mys^.pic,13,mys^.obr);
	end;

     if mouse_button=1 then begin  {skontroluje zmacknute tlacitka}
      p:=BGroup^.button;
      while p<>nil do begin
        if p^.stav then begin
           check:=p^.event;
           flash_button(p);
        end;
        p:=p^.next;
      end;
     end;
     execute_command;
end;

function print_mouse(var buttons:array of tlac;var mys:myska):word;
var f:word;
begin
     print_mouse:=0;
     mousepos;
	if (under_mouse) or ((mouse_posy<>mys.y) or (mouse_posx<>mys.x)) then begin
	if not under_mouse then m_test(buttons,mys);

	  if not under_mouse then putseg(mys.x,mys.y,mpic_x,mpic_y,0,mys.poz)
	     else under_mouse:=false;
	  mys.oy:=mys.y;
	  mys.ox:=mys.x;
	  mys.x:=mouse_posx;
	  mys.y:=mouse_posy;
	  getseg(mys.x,mys.y,mpic_x,mpic_y,0,mys.poz);
	  putseg2(mouse_posx,mouse_posy,mpic_x,mpic_y,mys.pic,13,mys.obr);
	end;

     if mouse_button=1 then begin  {skontroluje zmacknute tlacitka}
	  for f:=0 to num_but-1 do begin
		if buttons[f].stav then begin
		   print_mouse:=buttons[f].event;
		   flash_button(buttons,mys,flash_time,f,flash_number);
		   break;
		end;
	  end;
     end;
     execute_command;
end;

procedure change_button(var buttons:array of tlac;f:word);
begin
  if (f<=num_but) and (buttons[f].visible) and (buttons[f].useable) then begin
   if (buttons[f].stav) then
     if buttons[f].handle.used then begin
         putseg2xms(buttons[f].handle,buttons[f].x,buttons[f].y,buttons[f].dx,buttons[f].dy,buttons[f].pic2,13);
         print_normal(screen,buttons[f].x+(buttons[f].dx div 2)-(chardx*length(buttons[f].s) div 2),buttons[f].y+
			(buttons[f].dy div 2)-(chardy div 2)-2,buttons[f].s,buttons[f].col,0);
        end
        else
        print_normal(screen,buttons[f].x,buttons[f].y,buttons[f].s,buttons[f].pic2,buttons[f].col)
   else
     if buttons[f].handle.used then begin
       putseg2xms(buttons[f].handle,buttons[f].x,buttons[f].y,buttons[f].dx,buttons[f].dy,buttons[f].pic,13);
       print_normal(screen,buttons[f].x+(buttons[f].dx div 2)-(chardx*length(buttons[f].s) div 2),buttons[f].y+
			(buttons[f].dy div 2)-(chardy div 2)-2,buttons[f].s,buttons[f].col,0);
     end else
        print_normal(screen,buttons[f].x,buttons[f].y,buttons[f].s,buttons[f].pic,buttons[f].col)
   end;
end;

procedure Tmouse.print_buttons;
var f     : word;
    p     : PTlac;
begin
   Tmouse.turn_off;
   p:=BGroup^.button;
   while p<>nil do begin
    if p^.visible then begin
     if p^.handle.used then begin
       putseg2xms(p^.handle,p^.x,p^.y,p^.dx,p^.dy,p^.pic,13);
       print_normal(screen,p^.x+(p^.dx div 2)-(chardx*length(p^.s) div 2),p^.y+
	  	   (p^.dy div 2)-(chardy div 2)-2,p^.s,15,0);     end
     else begin
        print_normal(screen,p^.x,p^.y,p^.s,p^.pic,p^.col)
     end;
    end;
      p:=p^.next;
   end;
end;

procedure print_buttons(var buttons:array of tlac;var mys:myska);
var f:word;
begin
   zhasni_mys(mys);
   for f:=0 to num_but-1 do
    if buttons[f].visible then begin
     if buttons[f].handle.used then begin
       putseg2xms(buttons[f].handle,buttons[f].x,buttons[f].y,buttons[f].dx,buttons[f].dy,buttons[f].pic,13);
       print_normal(screen,buttons[f].x+(buttons[f].dx div 2)-(chardx*length(buttons[f].s) div 2),buttons[f].y+
	  		  (buttons[f].dy div 2)-(chardy div 2)-2,buttons[f].s,15,0);     end
     else begin
        print_normal(screen,buttons[f].x,buttons[f].y,buttons[f].s,buttons[f].pic,buttons[f].col)
     end;
   end;
end;

procedure print_button(var buttons:array of tlac;var mys:myska;f:word);
begin
    dec(f);
    if buttons[f].visible then begin
	if (buttons[f].x-mpic_x<mys.x) and (buttons[f].x+buttons[f].dx>mys.x)
	    and (buttons[f].y-mpic_y<mys.y) and (buttons[f].y+buttons[f].dy>mys.y)
	    then begin
		  under_mouse:=true;
		 zhasni_mys(mys);
	     end;
     if buttons[f].handle.used then begin
       putseg2xms(buttons[f].handle,buttons[f].x,buttons[f].y,buttons[f].dx,buttons[f].dy,buttons[f].pic,13);
       print_normal(screen,buttons[f].x+(buttons[f].dx div 2)-(chardx*length(buttons[f].s) div 2),buttons[f].y+
	  		  (buttons[f].dy div 2)-(chardy div 2)-2,buttons[f].s,15,0);
     end else begin
        print_normal(screen,buttons[f].x,buttons[f].y,buttons[f].s,buttons[f].pic,buttons[f].col)
     end;
   end;
end;

procedure zhasni_mys(var mys:myska);
begin
   putseg(mys.x,mys.y,mpic_x,mpic_y,0,mys.poz);
end;

procedure Tmouse.turn_off;
begin
   putseg(mys^.x,mys^.y,mpic_x,mpic_y,0,mys^.poz);
end;

procedure rozsviet_mys(var mys:myska);
begin
   getseg(mys.x,mys.y,mpic_x,mpic_y,0,mys.poz);
   putseg2(mys.x,mys.y,mpic_x,mpic_y,mys.pic,13,mys.obr);
end;

procedure Tmouse.turn_on;
begin
   getseg(mys^.x,mys^.y,mpic_x,mpic_y,0,mys^.poz);
   putseg2(mys^.x,mys^.y,mpic_x,mpic_y,mys^.pic,13,mys^.obr);
end;

procedure disable_all_buttons(var buttons:array of tlac);
var f:word;
begin
    for f:=0 to num_but-1 do begin
	  buttons[f].visible:=false;
	  buttons[f].stav:=false;
    end;
end;

procedure active_floor(var buttons:array of tlac;floor:byte);
var f:word;
begin
    for f:=0 to num_but-1 do begin
	  if buttons[f].floor=floor then buttons[f].visible:=true
	     else buttons[f].visible:=false;
	  buttons[f].stav:=false;
    end;
end;

procedure PR_mouse(var buttons:array of tlac;var mys:myska);
begin
   print_buttons(buttons,mys);
   rozsviet_mys(mys);
end;

procedure RPR_mouse(var buttons:array of tlac;var mys:myska);
begin
   rozsviet_mys(mys);
   pr_mouse(buttons,mys);
end;

procedure add_floor(var buttons:array of tlac;floor:byte);
var f:word;
begin
    for f:=0 to num_but-1 do begin
	  if buttons[f].floor=floor then buttons[f].visible:=true;
        buttons[f].stav:=false;
    end;
end;

function Tmouse.insert(x,y,dx,dy:word;napis:string;pic1,pic2:word;col:byte;
	  var handle:klucka;useable:boolean;floor:byte;event:word;next:Ptlac):Ptlac;
begin
   new(BGroup^.button);
    BGroup^.button^.next:=next;
      if dx=0 then dx:=length(napis)*chardx;
      if dy=0 then dy:=chardy;
      BGroup^.button^.x           := x;
      BGroup^.button^.y           := y;
      BGroup^.button^.dx          := dx;
      BGroup^.button^.dy          := dy;
      BGroup^.button^.s           := napis;
      BGroup^.button^.pic         := pic1;
      BGroup^.button^.pic2        := pic2;
      BGroup^.button^.stav        := true;
{      BGroup^.button^.visible     := false;}
      BGroup^.button^.col         := col;
      BGroup^.button^.handle      := handle;
      BGroup^.button^.useable     := useable;
      BGroup^.button^.floor       := floor;
      BGroup^.button^.event       := event;
      BGroup^.button^.flash       := button_flash;
      BGroup^.button^.visible     := true;
   insert:=BGroup^.button;
end;

procedure insert_button(var buttons:array of tlac;x,y,dx,dy:word;napis:string;pic1,pic2:word;col:byte;
          var handle:klucka;useable:boolean;floor:byte;event:word);
begin
   if dx=0 then dx:=length(napis)*chardx;
   if dy=0 then dy:=chardy;
   buttons[num_but].x           := x;
   buttons[num_but].y           := y;
   buttons[num_but].dx          := dx;
   buttons[num_but].dy          := dy;
   buttons[num_but].s           := napis;
   buttons[num_but].pic         := pic1;
   buttons[num_but].pic2        := pic2;
   buttons[num_but].stav        := false;
   buttons[num_but].visible     := false;
   buttons[num_but].col         := col;
   buttons[num_but].handle      := handle;
   buttons[num_but].useable     := useable;
   buttons[num_but].floor       := floor;
   buttons[num_but].event       := event;
   buttons[num_but].flash       := button_flash;
   inc(num_but);
end;

procedure insert_button2(var buttons:array of tlac);
begin
   buttons[num_but] := basic_button;
   inc(num_but);
end;

function  print_mouserec(var buttons:array of tlac;var mys:myska;var rec:zaznam):word;
var f:word;
begin
      if (under_mouse) or ((rec.y<>mys.y) or (rec.x<>mys.x)) then begin
      if not under_mouse then
       for f:=0 to num_but-1 do begin  {skontroluje, ci je myska na nejakom tlacitku}
           if (buttons[f].visible) and (buttons[f].useable)then begin {ak je tlacitko viditelne}
                if buttons[f].stav then begin {a podla jeho stavu}
                 if (buttons[f].x>rec.x) or (buttons[f].x+buttons[f].dx<rec.x)
                  or (buttons[f].y>rec.y) or (buttons[f].y+buttons[f].dy<rec.y)
                   then begin
                   if not under_mouse then zhasni_mys(mys);
                   under_mouse:=true;
                   buttons[f].stav:=false;
                   change_button(buttons,f);
                  end;
		    end
                else begin
                 if (buttons[f].x<rec.x) and (buttons[f].x+buttons[f].dx>rec.x)
                  and (buttons[f].y<rec.y) and (buttons[f].y+buttons[f].dy>rec.y)
                   then begin
                   if not under_mouse then zhasni_mys(mys);
                   under_mouse:=true;
                   buttons[f].stav:=true;
                   change_button(buttons,f);
                end;
              end;
           end;
       end;

        if not under_mouse then putseg(mys.x,mys.y,mpic_x,mpic_y,0,mys.poz)
        else under_mouse:=false;
	  mys.oy:=mys.y;
        mys.ox:=mys.x;
        mys.x:=rec.x;
        mys.y:=rec.y;
        getseg(mys.x,mys.y,mpic_x,mpic_y,0,mys.poz);
        putseg2(rec.x,rec.y,mpic_x,mpic_y,mys.pic,13,mys.obr);
      end;

     if rec.but=1 then begin  {skontroluje zmacknute tlacitka}
        for f:=0 to num_but-1 do begin
            if buttons[f].stav then begin
               print_mouserec:=buttons[f].event;
		   flash_button(buttons,mys,flash_time,f,flash_number);
		   break;
		end;
        end;
     end
     else if rec.but=5 then print_mouserec:=ev_quit;
end;

procedure init_recording;
begin
     point_record:=0;
     initclock;
     timer:=getclock;
end;

procedure done_recording(var rec:array of zaznam; file_name:string);
var f                   : word;
    saving_file         : text;
begin
     rec[point_record].x    := 0;
     rec[point_record].y    := 0;
     rec[point_record].but  := 5;
     rec[point_record].time := 0;
     inc(point_record);
     assign(saving_file,file_name);
     rewrite(saving_file);
     for f:=0 to point_record-1 do begin
         writeln(saving_file,rec[f].x,',',rec[f].y,',',rec[f].but,',',rec[f].time);
     end;
     writeln(saving_file,si_end);
     close(saving_file);
end;

procedure insert_record(var rec:array of zaznam;var mys:myska);
begin
        rec[point_record].x    := mys.x;
	  rec[point_record].y    := mys.y;
        rec[point_record].but  := mouse_button;
        rec[point_record].time := getclock-timer;
        inc(point_record);
        timer:=getclock;
end;

function record_mouse(var buttons:array of tlac;var mys:myska;var rec:array of zaznam):word;
var f:word;
begin
     mousepos;
     if (under_mouse) or ((mouse_posy<>mys.y) or (mouse_posx<>mys.x)) then begin
      if not under_mouse then
       for f:=0 to num_but-1 do begin  {skontroluje, ci je myska na nejakom tlacitku}
           if (buttons[f].visible) and (buttons[f].useable)then begin {ak je tlacitko viditelne}
                if buttons[f].stav then begin {a podla jeho stavu}
		     if (buttons[f].x>mouse_posx) or (buttons[f].x+buttons[f].dx<mouse_posx)
                  or (buttons[f].y>mouse_posy) or (buttons[f].y+buttons[f].dy<mouse_posy)
                   then begin
                   if not under_mouse then zhasni_mys(mys);
                   under_mouse:=true;
                   buttons[f].stav:=false;
                   change_button(buttons,f);
                  end;
                end
                else begin
                 if (buttons[f].x<mouse_posx) and (buttons[f].x+buttons[f].dx>mouse_posx)
                  and (buttons[f].y<mouse_posy) and (buttons[f].y+buttons[f].dy>mouse_posy)
                   then begin
                   if not under_mouse then zhasni_mys(mys);
                   under_mouse:=true;
                   buttons[f].stav:=true;
			 change_button(buttons,f);
                end;
              end;
           end;
       end;

        if not under_mouse then putseg(mys.x,mys.y,mpic_x,mpic_y,0,mys.poz)
        else under_mouse:=false;
        mys.oy:=mys.y;
        mys.ox:=mys.x;
        mys.x:=mouse_posx;
        mys.y:=mouse_posy;
        insert_record(rec,mys);
        getseg(mys.x,mys.y,mpic_x,mpic_y,0,mys.poz);
        putseg2(mouse_posx,mouse_posy,mpic_x,mpic_y,mys.pic,13,mys.obr);
      end;
     if mouse_button=1 then begin  {skontroluje zmacknute tlacitka}
        insert_record(rec,mys);
        pulzx(3);
        for f:=0 to num_but-1 do begin
            if buttons[f].stav then begin
               record_mouse:=buttons[f].event;
               flash_button(buttons,mys,flash_time,f,flash_number);
               break;
            end;
        end;
     end;
end;

constructor Tmouse.init(name:string);
var f:word;
begin
     new(mys);
     BGroup:=nil;
     new(BGroup);
     BGroup^.button:=nil;
     mys^.under_mouse:=false;
     mys^.rx1:=1;
     mys^.ry1:=1;
     mys^.rx2:=getmaxx;
     mys^.ry2:=getmaxy;
     mys^.mouse_file:=name;
     draw_it(mys^.mouse_file,1,1,palx);
     mpic_x:=gif_x;
     mpic_y:=gif_y;
     getseg(1,1,mpic_x,mpic_y,0,mys^.obr);
     mouseinit(f);
     mousespeed(12,12);
     mousesensitivity(50,50,1);
     mousepos;
     mys^.x:=mouse_posx;
     mys^.y:=mouse_posy;
     mys^.ox:=mys^.x;
     mys^.oy:=mys^.y;
     mouserange(mys^.rx1,mys^.rx2-mpic_x,mys^.ry1,mys^.ry2-mpic_y);
     mousesetpos((mys^.rx1+mys^.rx2) div 2,(mys^.ry1+mys^.ry2) div 2);
     getseg(mys^.x,mys^.y,mpic_x,mpic_y,0,mys^.poz);
end;

destructor Tmouse.done;
var p,q:Ptlac;
begin
    p:=BGroup^.button;
    while p<>nil do begin
        q:=p;
        p:=p^.next;
        dispose(q);
    end;
    dispose(BGroup);
    dispose(mys);
end;

procedure init_buttons(var buttons:array of tlac; num:word);
var fnum:word;
begin
  for fnum:=0 to num-1 do begin
   buttons[fnum].x       := 0;
   buttons[fnum].y       := 0;
   buttons[fnum].dx      := 0;
   buttons[fnum].dy      := 0;
   buttons[fnum].s       := '';
   buttons[fnum].pic     := 0;
   buttons[fnum].pic2    := 0;
   buttons[fnum].stav    := false;
   buttons[fnum].visible := false;
   buttons[fnum].col     := 0;
   buttons[fnum].handle.used  := false;
   buttons[fnum].useable := false;
   buttons[fnum].floor   := 0;
   buttons[fnum].event   := ev_none;
  end;
  num_but:=0;
end;

procedure bw(var b:file;ch1,ch2:char);
begin
             blockwrite(b,ch1,1);
             blockwrite(b,ch2,1);
end;

procedure cd(num:word; var ch1,ch2:char);
begin
   ch1:=chr(num div 256);
   ch2:=chr(num mod 256);
end;

procedure convert_mouse_record(file1,file2:string);
var t     : text;
    b     : file;
    s     : string;
    ch1,ch2 : char;
    num,c : word;
begin
    if subor_exist(file1) then begin
       assign(t,file1);
       reset(t);
       assign(b,file2);
       rewrite(b,1);
       s:=mouse_header;
	 blockwrite(b,s,16);
       repeat
         readln(t,s);
         c:=1;
         if s<>'' then begin
          if s=si_end then begin
             ch1:='E';
             ch2:='N';
             bw(b,ch1,ch2);
          end else begin
            mov_num(s,num,c);
            cd(num,ch1,ch2);
            bw(b,ch1,ch2);
            mov_num(s,num,c);
            cd(num,ch1,ch2);
            bw(b,ch1,ch2);
		mov_num(s,num,c);
            ch1:=chr(num);
            blockwrite(b,ch1,1);
            mov_num(s,num,c);
            cd(num,ch1,ch2);
            bw(b,ch1,ch2);
          end;
         end;
       until eof(t);
       close(b);
       close(t);
    end;
end;

procedure load_mouse_record(file_name:string;var rec:array of zaznam);

type code=array[0..max16] of byte;

var t     : text;
    f,c   : word;
    s     : string;
    data  : ^code;
    stop  : boolean;
begin
   stop:=false;
   if file_name[1]='>' then begin
      file_name:=out_string(file_name);
      new(data);
      loadblock_array(block_file,file_name,data^);
      s:='';
      for f:=1 to 15 do begin
          s:=s+chr(data^[f]);
	end;
      if s=mouse_header then begin
       c:=f+1;
       repeat

         if (data^[c]<>ord('E')) and (data^[c+1]<>ord('N'))
             then begin

            rec[point_record].x:=ord(data^[c])*256+ord(data^[c+1]);
            inc(c,2);
            rec[point_record].y:=ord(data^[c])*256+ord(data^[c+1]);
            inc(c,2);
            rec[point_record].but:=ord(data^[c]);
            inc(c,1);
            rec[point_record].time:=ord(data^[c])*256+ord(data^[c+1]);
            inc(c,2);
		inc(point_record);

         end

         else stop:=true;

	 until (c>max16) or (stop);
	end else write_error('Wrong mouse block file !');

	dispose(data);

   end else begin
    if subor_exist(file_name) then begin
	 assign(t,file_name);
	 reset(t);
	 f:=0;
	 repeat
	    readln(t,s);
	    if (s<>'') and (s<>si_end) then begin
		 c:=1;
		 inc(f);
		 mov_num(s,rec[f].x,c);
		 mov_num(s,rec[f].y,c);
		 mov_num2(s,rec[f].but,c);
		 mov_num(s,rec[f].time,c);
	    end;
	 until (eof(t)) and (s=si_end);
	 close(t);
    end;
   end;
end;

procedure swap_button_pictures(var button:tlac);
begin
    swap_byte(button.pic,button.pic2);
end;

procedure Tmouse.swap_button_pictures(p:PTlac);
begin
    swap_byte(p^.pic,p^.pic2);
end;

procedure Tmouse.flash_button(p:PTlac);
var timer2 : longint;
    f      : word;
begin
 if p^.flash then begin
  for f:=1 to 3 do begin
   timer2:=getclock+flash_time;
   swap_button_pictures(p);
   turn_off;
   change_button(p);
{   timer2:=getclock+timer;}
   turn_on;
   repeat
   until timer2<getclock;
   turn_off;
   swap_button_pictures(p);
   change_button(p);
   turn_on;
   if flash_number>f then begin
     timer2:=getclock++flash_time;
     repeat
     until timer2<getclock;
   end;
  end;
 end;
end;

procedure flash_button(var buttons:array of tlac;var mys:myska; timex,but_num,flash_num:word);
var timer2 : longint;
    f      : word;
begin
  if buttons[but_num].flash then begin
    for f:=1 to flash_num do begin
	   timer2:=getclock+timex;
	   swap_button_pictures(buttons[but_num]);
	   zhasni_mys(mys);
	   change_button(buttons,but_num);
	   timer2:=getclock+timex;
	   rozsviet_mys(mys);
	   repeat
	   until timer2<getclock;
	   zhasni_mys(mys);
	   swap_button_pictures(buttons[but_num]);
	   change_button(buttons,but_num);
	   rozsviet_mys(mys);
	   if flash_num>f then begin
	     timer2:=getclock+timex;
	     repeat
	     until timer2<getclock;
	   end;
    end;
  end;
end;

procedure reset_basic_button;
begin
    basic_button.x     := 0;
    basic_button.y     := 0;
    basic_button.dx    := 0;
    basic_button.dy    := 0;
    basic_button.pic   := 0;
    basic_button.floor := 0;
    basic_button.s     := '';
    basic_button.stav  := false;
    basic_button.visible:= true;
    basic_button.useable:= true;
    basic_button.col   := 15;
    basic_button.event := ev_none;
    basic_button.flash := false;
end;

procedure set_basic_XY(x,y:word);
begin
     basic_button.x  := x;
     basic_button.y  := y;
end;

procedure set_basic_DXY(x,y:word);
begin
     basic_button.dx  := x;
     basic_button.dy  := y;
end;

procedure set_basic_XY_name(x,y:word;s:string);
begin
     basic_button.x  := x;
     basic_button.y  := y;
     basic_button.s  := s;
end;

procedure set_basic(x,y:word;s:string;event:word);
begin
     basic_button.x  := x;
     basic_button.y  := y;
     basic_button.s  := s;
     basic_button.event:= event;
end;

function execute_command;
begin
  if command>cm_none then
    case command of
         cm_scron:    increase_palette(blackx,palx,10);
         cm_scroff:   decrease_palette(palx,10);
    end;
end;

function vyber_jxmenu_mouse(var menx:jxmenu_typ;var buttons:array of tlac;var mys:myska;typ:byte):boolean;
{ked bolo vybrane}
var f,ff,k,num    : word;
    line_founded  : boolean;
begin
   vyber_jxmenu_mouse:=false;
   if menx.pocet>0 then begin
   if menx.pocet<menx.roll then menx.roll:=menx.pocet;

   if not menx.draw_menu then begin
      draw_jxmenu(menx);
      under_mouse:=true;
   end;
    f:=menx.first;
    hi_jxmenu(f,menx);
       {vypise posuvne znacky}
       if menx.posuv>0 then up_abl(menx,true)
          else up_abl(menx,false);
       if menx.posuv+menx.roll<menx.pocet then down_abl(menx,true)
          else down_abl(menx,false);
    repeat

    event := print_mouse(buttons,mys);

    line_founded:=false;
    if typ=basic_menu then begin
     if (mys.x<>mys.ox) or (mys.y<>mys.oy) then begin
     for ff:=menx.posuv to menx.posuv+menx.roll do begin
        if (menx.dat[ff].x<mys.x) and ((menx.dat[ff].x+chardx*length(menx.dat[ff].meno))>mys.x) and
           (menx.dat[ff].y-(menx.posuv)*chardy<mys.y) and ((menx.dat[ff].y-(menx.posuv-1)*chardy)>mys.y) then begin
             if (f<>ff) then begin
               zhasni_mys(mys);
		   normal_jxmenu(f,menx);
               f:=ff;
               hi_jxmenu(f,menx);
               rozsviet_mys(mys);
               line_founded:=true;
               break;
             end else line_founded:=true;
           end;
     end;
     end;
    end;

    if (event=ev_none) and (mouse_button=1) then begin
       case typ of
           basic_menu      : if (line_founded) then event:=ev_ok;
           selector_menu   :
       end;
    end;

    if (mouse_button=1) then begin  {zmacknutie tlacitok na posuv}
{       if (mys.x>med^.x+6) and (mys.x>menx,menx.y+chardy}
    end;

    if joystick_able then sipka_joystick;
    if keypressed then begin
        k:=key;
        clear_key_buffer;
	for ff:=1 to menx.roll do begin
	    if menx.dat[ff].k=k then f:=ff;
	end;
	case k of
	     $4800,$4b00,$4838,$4b34,$4a2d:begin
                         zhasni_mys(mys);
				 normal_jxmenu(f,menx);
                         if f>1 then begin
				    dec(f);
				    if f-1<menx.posuv then begin
					 roll_menu_down(menx);
					 if f>1 then begin
					    normal_jxmenu(f-1,menx);
					 end;
				    end;
				 end  else if menx.pocet<=menx.roll then f:=menx.pocet;
			       hi_jxmenu(f,menx);
                         rozsviet_mys(mys);
                       end;
	     $5000,$4d00,$5032,$4d36,$4e2b:begin
                        zhasni_mys(mys);
  			      normal_jxmenu(f,menx);
                        if f<menx.pocet then begin
				    inc(f);
				    if f>menx.posuv+menx.roll then begin
					 roll_menu_up(menx);
					 if menx.pocet>f then begin
					    normal_jxmenu(f+1,menx);
					 end;
				    end;
				 end
				 else if menx.pocet<=menx.roll then f:=1;
			       hi_jxmenu(f,menx);
                         rozsviet_mys(mys);
                       end;
	     $4700,$4900 : begin
				   normal_jxmenu(f,menx);
				   if menx.pocet<menx.roll then f:=1
				    else f:=menx.posuv+1;
				 end;
     	     $4f00,$5100 : begin
				   normal_jxmenu(f,menx);
				   if menx.pocet<menx.roll then f:=menx.pocet
				    else f:=menx.posuv+menx.roll;
				   hi_jxmenu(f,menx);
  			       end;
	end;
       {vypise posuvne znacky}
       if menx.posuv>0 then up_abl(menx,true)
          else up_abl(menx,false);
       if menx.posuv+menx.roll<menx.pocet then down_abl(menx,true)
          else down_abl(menx,false);
    end;
    until (k=kb_enter) or (k=kb_esc) or (k=$3920) or (k=$4c35) or
	    (event=ev_quit) or (event=ev_ok) or (event=ev_cancel);
    if (k=kb_esc) or (event=ev_quit) or (event=ev_cancel)then num:=0 else num:=f;
   end;
   clear_key_buffer;
   menx.vybrane:=num;
end;

function select_file(var place:point;mask:string;var mys:myska):string;
const  max_but = 2;
       from_x  = 200;
       from_y  = 50;
       dx      = 128;
       dy      = 250;
type   Tbutt   = array[1..max_but] of tlac;
var med  : ^jxmenu_typ;
    but  : ^Tbutt;
    old_num_but  : word;
    c            : byte;
    s            : ^string;
    scr          : klucka;
begin
    place.dx:=dx-4;
    place.dy:=dy-20;
    old_num_but:=num_but;
    num_but:=0;
    select_file:='';
    findfirst(mask,$3f,sr);
    if doserror=0 then begin
      new(but);
      new(med);
      zhasni_mys(mys);
      init_handle(scr);
      create_handle(scr,dx*dy);
      getsegxms(scr,place.x,place.y-chardy,dx,dy,0);
      graphicswindow(place.x,place.y,place.dx,place.dy,15,1,' Files');
      c:=0;
      init_buttons(but^,max_but);
      init_jxmenu(place.x+10,place.y+50,15,12,0,mask,med^);
      repeat
       vloz_jxmenu2(sr.name,med^,0);
       findnext(sr);
      until (doserror>0) or (c=63);
      button_flash:=on;
{1}   insert_button(but^,place.x+50,place.y+210,0,0,si_cancel,15,12,0,no_handle,true,1, ev_cancel);
{2}   insert_button(but^,place.x+10,place.y+210,0,0,si_ok    ,15,12,0,no_handle,true,1,  ev_ok);
      size_jxmenu(100,150,med^);
      setroll_jxmenu(5,med^);
      active_floor(but^,1);
      draw_jxmenu(med^);
      print_buttons(but^,mys);
      rozsviet_mys(mys);
      vyber_jxmenu_mouse(med^,but^,mys,selector_menu);

      zhasni_mys(mys);
      putsegxms(scr,from_x,from_y-chardy,dx,dy,0);
      kill_handle(scr);

      rozsviet_mys(mys);

      dispose(but);
      if med^.vybrane>0 then begin
         new(s);
         s^:=med^.dat[med^.vybrane].meno;
         kill_all_spaces(s^);
         select_file:=s^;
         dispose(s);
      end;
      dispose(med);
    end;
    num_but:=old_num_but;
    event:=ev_none;
end;

procedure set_point(var place:point;x,y,dx,dy:word);
begin
    place.x:=x;
    place.y:=y;
    place.dx:=dx;
    place.dy:=dy;
end;

procedure set_message(meno:string;x,y,dx,dy:word);
begin

end;

begin
    under_mouse := true;
    mpic_x      := max_mpic_x;
    mpic_y      := max_mpic_y;
    num_but     := 0;
    num_but_2   := 0;
    point_record:= 0;
    button_flash:= true;
    flash_number:= 2;
    flash_time  := 300;
    event       := ev_none;
    command     := cm_none;
    reset_basic_button;
    no_handle.used := off;
end.
