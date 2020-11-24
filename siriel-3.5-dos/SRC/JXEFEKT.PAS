unit jxefekt;

interface
uses txt,crt,jxgraf,blockx,geo,jxxms,jxvar,animing;

type
     TPoint        = record
                      x,y           : word;
                     end;
     PPrint_option = ^Tprint_option;
     TPrint_option = record
                      px,py         : integer;
                      text_color    : byte;
                      shadow_color  : byte;
                      roll_color    : byte;
                      shadow        : boolean;
                      center        : boolean;
                      input_char    : char;
                     end;

     PFrame     = ^TFrame;
     TFrame     = object
                   ha_frame      : klucka;
                   ha_back       : klucka;
                   fill_color    : byte;
                   size_x,size_y : word;
                   version       : byte;
                   save          : boolean;
                   P1,P2         : TPoint;
                   killable      : boolean;       {ci je mozne danu klucku zlikvidovat}
                   constructor init(handle:klucka;Block_file,Gif_file:string;Asave:boolean);
                   procedure   draw_PO(var AP1,AP2:TPoint);    {DX,DY div SIZE !}
                   procedure   draw(x,y,dx,dy:word);
                   procedure   get_back;
                   procedure   put_back;
                   procedure   kill_back;
                   procedure   set_params(var Framex:TFrame);
                   destructor  done;
     end;
     PPrint     = ^TPrint;
     TPrint     = object
                   opt           : PPrint_option;
                   constructor init(PPx,PPy:integer;Tcol,CShadow,Roll:byte;Pcenter,PShadow:boolean);
                   procedure   print(x,y:word;s:string);
                   procedure   print_col(x,y:word;s:string;col:byte);
                   procedure   print_shad(x,y:word;s:string;b:boolean);
                   procedure   set_color(col:byte);
                   procedure   set_center(b:boolean);
                   procedure   set_shadow(b:boolean);
                   procedure   set_shadow_color(b:byte);
                   function    input(x,y:word;back_color:byte;num_char:byte):string;
                   destructor  done;
     end;



var
    block_file  : string[13];

procedure zablesk(var whitex,palx:tpalette;cas:word);
{spousobi efekt zablesku}
procedure draw_it(name:string;x,y:word;var palx:tpalette);
procedure draw_it2(block,name:string;x,y:word;var palx:tpalette);
{vykresli obrazok - bud z obycajneho alebo z blokoveho sub}
function  set_block_file(name:string):boolean;
{nastavy blokovy subor}
procedure SetDisplay(X,Y:integer);
{zmeni zaciatok videoramky}
procedure hviezdy(x1,y1,x2,y2,max_stars:word);
{vybodkuje obrazovku hviezdami}
procedure roll_screen_up(num,step,time:word);
{vyroluje obrazovku Hadrware paningom}
procedure vysum(x1,y1,x2,y2,col,num,time,hustota:word);
{vysumi sektor obrazovky}
procedure roll_text(x1,y1,x2,y2,num,smer,time:word);
{vyroluje riadok textu}
function Real_length (s : String):word;
{zisti realnu velkost napisu}
function Value (s : String):integer;

implementation
constructor TPrint.init(PPx,PPy:integer;Tcol,CShadow,Roll:byte;Pcenter,PShadow:boolean);
begin
    new(opt);
    with opt^ do begin
     px          := PPx;
     py          := PPy;
     text_color  := Tcol;
     Shadow_color:= CShadow;
     Roll_color  := Roll;
     Center      := Pcenter;
     shadow      := Pshadow;
     input_char  := '<';
    end;
end;

procedure TPrint.print(x,y:word;s:string);
begin
   if opt^.center then
      x:=(getmaxx div 2)-(real_length(s) div 2);

   if opt^.shadow then
      print_normal(screen,x+opt^.px,y+opt^.py,s,opt^.shadow_color,opt^.roll_color);

      print_normal(screen,x,y,s,opt^.text_color,opt^.roll_color);
end;

procedure TPrint.set_color(col:byte);
begin
   opt^.text_color:=col;
end;


procedure TPrint.print_col(x,y:word;s:string;col:byte);
var old_col : byte;
begin
   old_col:=opt^.text_color;
   set_color(col);
   print(x,y,s);
   set_color(old_col);
end;

procedure TPrint.print_shad(x,y:word;s:string;b:boolean);
var old_shad : boolean;
begin
    old_shad:=opt^.shadow;
    set_shadow(b);
    print(x,y,s);
    set_shadow(old_shad);
end;

procedure TPrint.set_center(b:boolean);
begin
   opt^.center:=b;
end;

procedure TPrint.set_shadow(b:boolean);
begin
   opt^.shadow:=b;
end;

procedure TPrint.set_shadow_color(b:byte);
begin
   opt^.shadow_color:=b;
end;

function TPrint.input(x,y:word;back_color:byte;num_char:byte):string;
var s    : string;
    k    : word;
begin
 k:=0;
 s:=s+opt^.input_char;
 print(x,y,s);
 repeat
  if keypressed then begin
    k:=key;
    clear_key_buffer;
  if (K<>kb_esc) and
     (k<>kb_back) and
     (K<>kb_enter) and
     (length(s)<=num_char) and
     (K<>kb_up) and
     (K<>kb_down) and
     (K<>kb_left) and
     (K<>kb_right) then begin
    print_col(x,y,s,back_color);
    s[length(s)]:=chr(k);
    s:=s+opt^.input_char;
    print(x,y,s);
   end else
	if (K<>kb_esc) and
           (k<>kb_back) and
           (K<>kb_enter) then
             print(x,y,s);
   if (k=kb_back) and (length(s)>1) then begin
   print_col(x,y,s,back_color);
   s[0]:=chr(length(s)-2);
   s:=s+opt^.input_char;
   print(x,y,s);
   end
   else if k=kb_back then print(x,y,opt^.input_char);
  end;
 until (k=kb_esc) or (k=kb_enter);
 print_col(x,y,s,back_color);
 if k=kb_esc then s:='';
 if k=kb_enter then s[0]:=chr(length(s)-1);
 print(x,y,s);
 input:=s;
end;

destructor TPrint.done;
begin
     dispose(opt);
end;

constructor TFrame.init(handle:klucka;Block_file,Gif_file:string;Asave:boolean);
var f       : byte;
begin
     ha_frame:=no_handle;
     ha_back:=no_handle;
     killable:=true;
     save:=Asave;
     if not handle.used then begin
       draw_it2(Block_file,Gif_file,0,0,palx);
       version:=getpixel(screen,0,0);
       size_x:=getpixel(screen,0,1);
       size_y:=getpixel(screen,0,2);
       fill_color:=getpixel(screen,0,3);
       create_handle(ha_frame,size_x*size_y*8);
       for f:=0 to 7 do begin
          getsegxms(ha_frame,1+f*size_x,0,size_x,size_y,f);
       end;
     end
     else begin
          ha_frame:=handle;
          killable:=false;
     end;
end;

procedure TFrame.get_back;
var size  : longint;
begin
     size:=P2.x;
     size:=size*P2.y;
     size:=size*size_x;
     size:=size*size_y;
     create_handle(ha_back,size);
     getsegxms(ha_back,P1.x,P1.y,size_x*P2.x,size_y*P2.y,0);
end;

procedure TFrame.put_back;
begin
     putsegxms(ha_back,P1.x,P1.y,P2.x*size_x,P2.y*size_y,0);
     kill_back;
end;

procedure TFrame.kill_back;
begin
     kill_handle(ha_back);
end;

procedure TFrame.set_params(var Framex:TFrame);
begin
     fill_color    := Framex.fill_color;
     size_x        := Framex.size_x;
     size_y        := Framex.size_y;
     version       := Framex.version;
end;

procedure TFrame.draw(x,y,dx,dy:word);
var Ap1,Ap2 : TPoint;
begin
     AP1.x:=x;
     AP1.y:=y;
     AP2.x:=dx+2;
     AP2.y:=dy+2;
     draw_PO(AP1,AP2);
end;

procedure TFrame.draw_PO(var AP1,AP2:TPoint);
var f     : word;
begin
    if save then
       if ha_back.used then put_back;
    P1.x:=AP1.x;
    P1.y:=AP1.y;
    P2.x:=AP2.x;
    P2.y:=AP2.y;
    if save then get_back;
    rectangle2(screen,P1.x+size_x,P1.y+size_y,(P2.x-2)*size_x,(P2.y-2)*size_y,fill_color);
    putseg2xms(ha_frame,P1.x,P1.y,size_x,size_y,0,13);
    putseg2xms(ha_frame,P1.x+(P2.x-1)*size_x,P1.y,size_x,size_y,2,13);
    putseg2xms(ha_frame,P1.x,P1.y+(P2.y-1)*size_y,size_x,size_y,5,13);
    putseg2xms(ha_frame,P1.x+(P2.x-1)*size_x,P1.y+(P2.y-1)*size_y,size_x,size_y,7,13);
    for f:=1 to P2.x-2 do begin
      putseg2xms(ha_frame,P1.x+f*size_x,P1.y,size_x,size_y,1,13);
      putseg2xms(ha_frame,P1.x+f*size_x,P1.y+(P2.y-1)*size_y,size_x,size_y,6,13);
    end;
    for f:=1 to P2.y-2 do begin
      putseg2xms(ha_frame,P1.x,P1.y+f*size_y,size_x,size_y,3,13);
      putseg2xms(ha_frame,P1.x+(P2.x-1)*size_x,P1.y+f*size_y,size_x,size_y,4,13);
    end;
end;

destructor TFrame.done;
begin
    if (save) and (ha_back.used) then put_back;
    if killable then kill_handle(ha_frame);
    ha_frame:=no_handle;
end;

procedure zablesk(var whitex,palx:tpalette;cas:word);
begin
   tma:=true;
   increase_palette(whitex,palx,cas);
end;

procedure draw_it(name:string;x,y:word;var palx:tpalette);
begin
    if length(name)>0 then begin
     if name[1]='>' then begin
            name:=out_string(name);
            if block_file<>'' then
             draw_gif_block(screen,block_file,name,x,y,palx);
     end
     else draw_gif(screen,name,x,y,palx);
    end;
end;

procedure draw_it2(block,name:string;x,y:word;var palx:tpalette);
begin
    if length(name)>0 then begin
     if name[1]='>' then begin
            name:=out_string(name);
            if block_file<>'' then
             draw_gif_block(screen,block,name,x,y,palx);
     end
     else draw_gif(screen,name,x,y,palx);
    end;
end;

function set_block_file(name:string):boolean;
begin
   if subor_exist(name) then block_file := name
      else block_file := '';
   if block_file<>'' then set_block_file:=true
      else set_block_file:=false;
end;

procedure SetDisplay(X,Y:integer);
var A:integer;
begin

  repeat until Port[$3DA] and 8<>8;
  repeat until Port[$3DA] and 8=8;
  A:=160*Y+X shr 2;
  Port[$3D4]:=$0C; Port[$3D5]:=A shr 8;    { Start addr high }
  Port[$3D4]:=$0D; Port[$3D5]:=A and $FF;  { Start addr low }
  repeat until Port[$3DA] and 1<>1;
  repeat until Port[$3DA] and 1=1;
  A:=Port[$3DA];                           { Horizental PEL panning }
  Port[$3C0]:=$13 or $20; Port[$3C0]:=(X mod 4) shl 1;
end;

procedure hviezdy(x1,y1,x2,y2,max_stars:word);
var     f  : word;
begin
   for f:=0 to max_stars do begin
      putpixel(screen,random(x2)+x1,random(y2)+y1,15);
      putpixel(screen,random(x2)+x1,random(y2)+y1,14);
   end;
end;

procedure roll_screen_up(num,step,time:word);
var f,ff : word;
begin
 ff:=0;
 for f:=1 to num do begin
   inc(ff,step);
   setdisplay(0,ff);
   pulzx(time);
 end;
end;

procedure vysum(x1,y1,x2,y2,col,num,time,hustota:word);
var f,ff  : word;
    clock : longint;
begin
     clock:=getclock+time;
     for f:=1 to num do begin
       for ff:=1 to hustota do
         putpixel(screen,x1+random(x2),y1+random(y2),col);
         repeat
         until getclock>clock;
         clock:=getclock+time;
     end;
     rectangle2(screen,x1,y1,x2,y2,col);
end;

procedure roll_text(x1,y1,x2,y2,num,smer,time:word);
var f,fy  : word;
    lajna1:^tline;
    stav :byte;
begin
 new(lajna1);
 for f:=1 to num do begin
   stav:=0;
   for fy:=y1 to y2+y1 do begin
      case smer of
       1: begin         {vlavo}
              read_linepos(screen,lajna1^,x2,fy,640-x2);
              write_linepos(screen,lajna1^,1,fy,640-x2);
          end;
       2: begin         {vpravo}
              read_linepos(screen,lajna1^,1,fy,640-x2);
              write_linepos(screen,lajna1^,x2,fy,640-x2);
          end;
       3: begin         {striedavo}
            if stav=0 then begin
              read_linepos(screen,lajna1^,x2,fy,640-x2);
              write_linepos(screen,lajna1^,1,fy,640-x2);
              stav:=1;
            end else begin
              read_linepos(screen,lajna1^,1,fy,640-x2);
              write_linepos(screen,lajna1^,x2,fy,640-x2);
              stav:=0;
            end;
          end;
       end;
   end;
   pulzx(time);
 end;
 dispose(lajna1);
end;

function Real_length (s : String):word;
Var
  ByteRange, c, n, h : Integer;
  Index, lsign       : Word;
  b : Byte;
  x : word;
Begin
  x:=0;
  lsign:=0;
  ByteRange:=1+((CharDX-1) SHR 3);
  For c:=1 to Length (s) Do Begin
    Index:=(Ord (s[c])+posuv)*(ByteRange)*CharDY-1;
    For n:=0 to CharDY-1 Do Begin
      For h:=0 to CharDX-1 Do Begin
        If (h And 7)=0 then Begin
           Inc (Index);
           b:=Fontik[Index];
        End;
           if (b>=128) and (h>lsign) then lsign:=h;
        b:=b SHL 1;
      End;
    End;
   if s[c]<>' ' then inc(x,lsign+2)
      else inc(x,chardx);
   lsign:=0;
  End;
  Real_length:=x;
End;

function Value (s : String):integer;
var x    : integer;
begin
    val(s,x,x);
    Value:=x;
end;

begin
    set_block_file('MAIN.DAT');
end.