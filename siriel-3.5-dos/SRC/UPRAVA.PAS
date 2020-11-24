program uprava;

uses txt,geo,jxgraf,jxfont,crt,dos,animing;

var s,s2:string;
    palx:tpalette;
    font:Tjx_font;

function check:boolean;
var f:word;
begin
   check:=false;
   for f:=1 to font.size_y do begin
      if getpixel(screen,600,f)<>font.death_color then begin
         check:=true;
         break;
      end;
   end;
end;

procedure spracuj;
var f,ff,fx,fy,del1,del2,c,fd:longint;
begin
  clrscr;
  write('Vystup (.gif): ');
  readln(s2);
  s2:=s2+'.GIF';
  grafika_init(640,480,8);
  init_font(font);
  load_font(font,s,palx);
  write_palette(palx,0,256);
  fx             := getpixel(screen,0,4);
  fy             := getpixel(screen,0,5);
  del1           := getpixel(screen,0,7);
  del2           := getpixel(screen,0,8);
  c:=0;
  for ff:=0 to fx-2 do begin
   for f:=0 to fy-1 do begin
       for fd:=1 to font.size_x do begin
        rectangle2(screen,600,1,font.size_x,font.size_y,font.death_color);
        jxprint(font,600,1,chr(c+font.start));
        if not check then begin
           getsegxms(font.handle,601,1,font.size_x,font.size_y,c);
        end else break;
       end;
       putsegxms(font.handle,1+ff*(font.size_x+del1),1+f*(font.size_y+del2)+(f div 4),
                 font.size_x,font.size_y,c);
       inc(c);
   end
  end;
  dump_to_gif(screen,s2,0,0,639,480,8,
              palx);
  done_font(font);
  done_graf;
end;


begin
   selectfile(10,10,s,'*.gif');
   if s<>'' then spracuj;
   credits('Program na upravu fontov');
end.