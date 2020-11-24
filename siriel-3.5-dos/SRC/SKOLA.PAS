{$m 16384,0,150000}
program demo_pre_skolu;

{$define xrec}    {1 recording}

uses txt,dos,crt,jxgraf,geo,blockx,jxxms,animing,jxefekt,jxfont,xms2,
     jxgmouse,mouse,geo2;

const version    = 'GympelDemko v.: 1.00';
      infile     = 'SKOLA.DAT';
      pgeo       = '>GGEO';
      puvadza    = '>GUVADZA';
      pdemko     = '>GDEMKO';
      paleta     = '>GPALETA';
      pnekonec   = 'Nekoneèný vesmír...';
        p99        = '99,9993 % bez života...';
        ppredsa    = 'A predsa...';
        pzem       = '>GZEM';
        scr_x      = 640;
        scr_y      = 480;

        NFont      = 'FMOD';          {klasicky font}
        GFont      = '>GFONT';    {vekly font}
        GButton    = '>GBUTTONS';
        GMouse     = '>GMYS';

        max_handles= 2;          {2 - tiskatka}
        zem_x      = 60;
        zem_y      = 60;
	but_x=108;
	but_y=31;
	num_but_pic= 5;
	max_num_but= 5;
        max_zaznamov = 1023;

{----------------EVENTS-----------------}
{---------------------------------------}

type bod = record
           x,y : word;
     end;
     x16x16 = array[0..255] of byte;
     zaznamy = array[0..max_zaznamov] of zaznam;

var
    palx,blackx,whitex  : tpalette;
    fx,fy,f             : word;
    handles             : array[1..max_handles] of klucka;
    sur,osur            : bod;
    font                : Tjx_font;
    buttons             : array[1..max_num_but] of tlac;
    mys                 : myska;
    event               : word;
    rec                 : ^zaznamy;
    counter             : word;    {ktora cast zaznamu sa ma previest}

procedure load_buttons_graphics;
var f:word;
begin
        create_handle(handles[2],but_x*but_y*num_but_pic);
        draw_it(GButton,0,0,palx);
        for f:=0 to num_but_pic-1 do begin
            getsegxms(handles[2],0,f*but_y,but_x,but_y,f);
        end;
end;

procedure define_buttons;
var f,ff:word;
begin
{1}     insert_button(buttons,20,400,but_x,but_y,'Zoom +',3,2,15,handles[2],true,1,ev_select);
{2}     insert_button(buttons,20,440,but_x,but_y,'Zoom -',3,2,15,handles[2],true,1,ev_none);
{3}     insert_button(buttons,20,480,but_x,but_y,'Funkcia',0,2,15,handles[2],false,1,ev_none);
{4}     insert_button(buttons,20,520,but_x,but_y,'Nie',3,2,15,handles[2],true,2,ev_none);
{5}     insert_button(buttons,20,560,but_x,but_y,'Ukoncit ?',1,2,15,handles[2],false,2,ev_none);
        active_floor(buttons,1);
end;

procedure x_zablesk;
begin
  zablesk(whitex,palx,40);
end;

procedure black_screen;
begin
  clear_bitmap(screen);
  write_palette(blackx,0,256);
end;

procedure b_wait(num:byte);
begin
  x_zablesk;
  pulzx(num);
end;

procedure reinit(num:byte);
begin
  b_wait(num);
  black_screen;
end;

procedure reinit2(num:byte;x1,y1,x2,y2:word);
begin
  b_wait(num);
  vysum(x1,y1,x2,y2,0,2000,2,100);
  black_screen;
end;


procedure roll_earth(num,step:word);
var f:word;
begin
     for f:=1 to num do begin
           putsegxms(handles[1],osur.x,osur.y,zem_x,zem_y,1);
           getsegxms(handles[1],sur.x,sur.y,zem_x,zem_y,1);
{         putseg2_mixxms(handles[1],handles[1],sur.x,sur.y,zem_x,zem_y,0,13,1);}
           putseg2xms(handles[1],sur.x,sur.y,zem_x,zem_y-1,0,13);
           osur.x:=sur.x;
           osur.y:=sur.y;
           dec(sur.y,step);
           pulz(4);
     end;
end;

procedure init;
begin
   if xmsinstalled then begin
                  write_ok;
                  writeln('Version:',xmsversion);
                  writeln('XMS free:',xmfreespace);
                  writeln('XMS contig:',xmcontig);
                  XMSDriverCheck;
                  GetXMSFunct;
   end
   else begin
       writeln('HIMEM.SYS needed !');
       warning;
       halt(1);
   end;

  randomize;
  grafika_init(scr_x,scr_y,8);
  fill_palette_black(blackx);
  fill_palette(whitex,63);
  write_palette(blackx,0,256);
  font_load_block(infile,NFont,fx,fy);
  init_handles(max_handles,handles);
  init_font(font);
  load_font(font,GFont,palx);
  load_mouse(mys,GMouse,24,24,palx);
  load_buttons_graphics;
  clear_bitmap(screen);
  write_palette(palx,0,256);
end;

procedure main;
begin
  draw_it(pgeo,170,200,palx);
  reinit2(30,170,200,361,31);

  draw_it(puvadza,230,200,palx);
  reinit2(30,230,200,120,69);

  draw_it(pdemko,190,200,palx);
  reinit2(50,190,200,280,67);

  draw_it(paleta,1,1,palx);
  hviezdy(1,1,scr_x,scr_y,100);
  rectangle2(screen,1,200,scr_x,25,0);
  jxprint_normal(font,200,200,pnekonec);
  b_wait(20);
  roll_text(200,200,10,24,50,1,2);
  black_screen;

  hviezdy(1,1,scr_x,scr_y,100);
  rectangle2(screen,1,200,scr_x,25,0);
  jxprint_normal(font,200,200,p99);
  b_wait(20);
  roll_text(200,200,10,24,50,2,2);
  black_screen;

  draw_it(pzem,1,1,palx);
  create_handle(handles[1],zem_x*zem_y*2);
  getsegxms(handles[1],1,1,zem_x,zem_y,0);
  clear_bitmap(screen);

  hviezdy(1,1,scr_x,scr_y+300,200);
  rectangle2(screen,1,200,scr_x,25,0);
  sur.x:=250;
  sur.y:=scr_y+5;
  osur.x:=sur.x;
  osur.y:=sur.y;
  getsegxms(handles[1],sur.x,sur.y,zem_x,zem_y,1);
  putseg2xms(handles[1],sur.x,sur.y,zem_x,zem_y,0,13);
  jxprint_normal(font,240,200,ppredsa);
  b_wait(20);
  roll_text(200,200,10,24,50,3,2);
  roll_screen_up(90,3,2);
  setdisplay(0,270);

end;

procedure mx1;
begin
  basic_mouse_init(mys,1,250,640,730);
  print_buttons(buttons,mys);
{$ifdef rec}
  init_recording;
{$else}
  initclock;
  counter:=1;
  print_mouserec(buttons,mys,rec^[counter]);
  timer:=getclock+rec^[counter].time;
{$endif}
  repeat
      mousepos;
{$ifdef rec}
       event:=record_mouse(buttons,mys,rec^);
{$else}
       if timer<=getclock then begin
          inc(counter);
          event:=print_mouserec(buttons,mys,rec^[counter]);
          timer:=getclock+rec^[counter].time;
       end;
{$endif}
       case event of
            ev_select:begin
                           buttons[3].s:='Ciel';
                           print_button(buttons,mys,3);
                      end;
       end;
  until (keypressed) or (event=ev_quit);
{$ifdef rec}
  done_recording(rec^,'mouse.out');
{$endif}
  jxprint_normal(font,240,500,'Zoom + + +');
  b_wait(40);
  setdisplay(0,0);
end;

begin
  engine_screen(version);
  rec:=nil;
  new(rec);
  set_block_file(infile);
  write('Fake mouse...');
  load_mouse_record('>MMYS1',rec^);
  write_ok;
  init;
  init_buttons(buttons,max_num_but);
  define_buttons;
  main;
  mx1;
  clear_key_buffer;
  done_graf;
  write('Records...');
  if rec<>nil then dispose(rec);
  write_ok;
  write('Font...');
  done_font(font);
  write_ok;
  write('Handles...');
  done_handles(handles);
  write_ok;
  credits(version);
end.