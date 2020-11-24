unit jxfont;

interface

uses jxgraf,jxxms,jxefekt,animing,crt;

type Tjx_font = record
                size_x,size_y    : byte;
                handle           : klucka;
                loaded           : boolean;
                typ              : byte;
                start            : byte;
                death_color      : byte;
     end;

{var  jx_font    : Tjx_font;}

procedure init_font(var jx_font:Tjx_font);
function  load_font(var jx_font:Tjx_font;name:string;var palx:tpalette):boolean;
procedure done_font(var jx_font:Tjx_font);

procedure jxprint(var jx_font:Tjx_font; x,y:word; s:string);
procedure jxprint_normal(var jx_font:Tjx_font; x,y:word; s:string);

implementation

{-----------------------Loading------------------------------}
procedure load_type_no1(var jx_font:Tjx_font);   {nacitava stlpce}
var fx,fy,c,a,b,x,y:word;
    del1,del2,d,d1,d2:longint;
begin
     jx_font.size_x := getpixel(screen,0,1);
     jx_font.size_y := getpixel(screen,0,2);
     jx_font.start  := getpixel(screen,0,3);
     fx             := getpixel(screen,0,4);
     fy             := getpixel(screen,0,5);
     death_color    := getpixel(screen,0,6);
     del1           := getpixel(screen,0,7);
     del2           := getpixel(screen,0,8);
     d1:=jx_font.size_x;
     d2:=jx_font.size_y;
     d:=d1*d2*fx*fy;
{     d:=jx_font.size_x*jx_font.size_y*(256-jx_font.start);}
     create_handle(jx_font.handle,d);
     c:=0;
     for x:=0 to fx-2 do begin
         for y:=0 to fy-1 do begin
             a:=1+x*(jx_font.size_x+del1);
             b:=1+y*(jx_font.size_y+del2)+(y div 7);
             getsegxms(jx_font.handle,a,b,
                       jx_font.size_x,jx_font.size_y,c);
             {2*y - medzi pismenami je rovanka medzera}
             inc(c);
         end;
     end;
     inc(x);
     for y:=0 to 256-fx*fy do begin
             a:=1+x*(jx_font.size_x+del1);
             b:=1+y*(jx_font.size_y+del2);
        getsegxms(jx_font.handle,a,b,jx_font.size_x,jx_font.size_y,c);
        {2*y - medzi pismenami je rovanka medzera}
        inc(c);
     end;
     jx_font.loaded:=true;
end;

function load_font(var jx_font:Tjx_font;name:string;var palx:tpalette):boolean;
begin
   clear_bitmap(screen);
   load_font:=false;
   draw_it(name,0,0,palx);
   jx_font.typ := getpixel(screen,0,0);
   if jx_font.typ>0 then begin
      case jx_font.typ of
           1:begin
                  load_type_no1(jx_font);
                  load_font:=true;
           end;
      end;
   end;
end;

procedure init_font(var jx_font:Tjx_font);
begin
   jx_font.size_x        := 0; {1} {fx - 4; fy - 5}
   jx_font.size_y        := 0; {2}
   jx_font.typ           := 0; {0}
   jx_font.start         := 0; {3}
   jx_font.death_color   := 0; {6}
   jx_font.handle.used   := false;
   jx_font.loaded        := false;
end;

procedure done_font(var jx_font:Tjx_font);
begin
  if jx_font.handle.used then kill_handle(jx_font.handle);
  init_font(jx_font);
end;

{-----------------------Printing------------------------}
procedure jxprint_normal(var jx_font:Tjx_font; x,y:word; s:string);
var f,plus:word;
begin
   if jx_font.loaded then begin
    for f:=1 to length(s) do begin
       plus:=0;
       if ord(s[f])>=jx_font.start then
        plus:=putseg2xms_sizex(jx_font.handle,x,y,jx_font.size_x,jx_font.size_y,ord(s[f])-jx_font.start,jx_font.death_color)+1;
       if s[f]=' ' then inc(x,5) else inc(x,plus);
    end;
   end;
end;

procedure jxprint(var jx_font:Tjx_font; x,y:word; s:string);
var f:word;
begin
   if jx_font.loaded then begin
    for f:=1 to length(s) do begin
       if ord(s[f])>=jx_font.start then
        putseg2xms(jx_font.handle,x,y,jx_font.size_x,jx_font.size_y,ord(s[f])-jx_font.start,jx_font.death_color);
        inc(x,jx_font.size_x);
    end;
   end;
end;

begin
end.