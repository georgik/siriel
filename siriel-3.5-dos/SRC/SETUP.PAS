{$m 16384,0,120000}
program setup;

uses geo,txt,crt,dos;

const yes='YES';
      no='NO';
      vypis='Setup for SIRIEL 3.5 - 1.06';
      infile='SIRIEL3.CFG';
      maxline=10;
      anims='ANIMS';
      zvuk='ZVUK';
      jaz='LANGUAGE';
      ini='INITTIME';
      joy='JOYSTICK';
      slo='SLO';
      eng='ENG';

type dat=array[1..64]of string;

var data:^dat;
    t:text;
    f,ff,c,m,v:word;
    menu:menu_typ;
    result:boolean;

procedure init;
begin
     videomode(3);
     setcurshape(8,0);
     new(data);
     for f:=1 to 64 do data^[f]:='';
     if not subor_exist(infile) then begin
       assign(t,infile);
       rewrite(t);
       writeln(t,'[ANIMS]=NO');
       writeln(t,'[ZVUK]=NO');
       writeln(t,'[INITTIME]=3000');
       writeln(t,';',vypis);
       close(t);
     end;
end;

procedure done;
begin
     dispose(data);
     credits(vypis);
     halt(1);
end;

procedure load_sub;
begin
     if not subor_exist(infile) then done;  {ak dany subor neexistuje, vyskoci}
     assign(t,infile);
     reset(t);
     for f:=1 to maxline do data^[f]:='';
     c:=0;      {- pocitadlo riadkov}
     repeat
       inc(c);
       readln(t,data^[c]);
     until (eof(t)) or (c>=maxline);
     close(t);
end;

procedure save_file;
begin
     assign(t,infile);
     rewrite(t);
     for f:=1 to c do begin
         writeln(t,data^[f]);
     end;
     close(t);
     result:=true;
end;

procedure insert_command(pr,s:string);
var found:boolean;
    sx:string;
begin
   found:=false;
   for f:=1 to c do begin
       get_name(data^[f],sx);
       if sx=pr then found:=true;
       if found then break;
   end;

   if found then begin
      data^[f]:='['+pr+']='+s;
   end
   else begin
        inc(c);
        for ff:=c downto 2 do begin
            data^[ff]:=data^[ff-1];
        end;
        data^[1]:='['+pr+']='+s;
   end;

end;

procedure basic_menu;
begin
    init_menu(25,8,31,47,2,'SETUP',menu);
    vloz_menu2('Animation setup',menu,$1e61);
    vloz_menu2('Sound setup',menu,$1f53);
    vloz_menu2('Language setup',menu,$266c);
    vloz_menu2('Joystick setup',menu,$266c);
    vloz_menu2('Exit and save',menu,$1265);
    vloz_menu2('Quit',menu,$1071);
    vyber_menu(menu,v);
    case v of
         1:m:=1;
         2:m:=2;
         3:m:=3;
         4:m:=4;
         5:save_file;
         0,6:result:=true;
    end;
end;

procedure inittime;
const sec=' sec.';
begin
    TextWindow1(10,2,65,6,31,31,3,' Warning ! ');
    gotoxy(11,3);
    write('If you are running Siriel under WIN and you are using starting');
    gotoxy(11,4);
    write('sound, disable it or set this parameter as the length of this');
    gotoxy(11,5);
    write('sound. If you have no starting sound or you are running it');
    gotoxy(11,6);
    write('under DOS, set it as 0 sec.');
    init_menu(25,10,31,47,1,'Init time',menu);
    vloz_menu2(' 0'+sec,menu,0);
    vloz_menu2(' 2'+sec,menu,0);
    vloz_menu2(' 4'+sec,menu,0);
    vloz_menu2(' 6'+sec,menu,0);
    vloz_menu2(' 8'+sec,menu,0);
    vloz_menu2(' 10'+sec,menu,0);
    vloz_menu2('Cancel',menu,$3e63);
    vyber_menu(menu,v);
    case v of
         1:insert_command(ini,'0');
         2:insert_command(ini,'4000');
         3:insert_command(ini,'8000');
         4:insert_command(ini,'12000');
         5:insert_command(ini,'16000');
         6:insert_command(ini,'20000');
    end;
     m:=0;
end;

procedure animation;
begin
    init_menu(50,4,31,47,1,'Animation',menu);
    vloz_menu2(' ON',menu,0);
    vloz_menu2(' OFF',menu,0);
    vloz_menu2('Cancel',menu,$3e63);
    vyber_menu(menu,v);
    case v of
         1:insert_command(anims,yes);
         2:insert_command(anims,no);
    end;
     m:=0;
end;

procedure sound;
begin
    init_menu(8,4,31,47,1,'SOUND',menu);
    vloz_menu2(' Sound blaster',menu,0);
    vloz_menu2(' Nosound',menu,0);
    vloz_menu2(' Init time',menu,0);
    vloz_menu2('Cancel',menu,$3e63);
    vyber_menu(menu,v);
    case v of
         1:insert_command(zvuk,yes);
         2:insert_command(zvuk,no);
         3:begin inittime; sound; end;
    end;
     m:=0;
end;

procedure lang;
begin
    init_menu(8,12,31,47,1,'LANGUAGE',menu);
    vloz_menu2('English (default)',menu,0);
    vloz_menu2('Slovensky',menu,0);
    vloz_menu2('Cancel',menu,$3e63);
    vyber_menu(menu,v);
    case v of
         1:insert_command(jaz,eng);
         2:insert_command(jaz,slo);
    end;
     m:=0;
end;

procedure joystick_set;
begin
    init_menu(10,4,31,47,1,'JOYSTICK',menu);
    vloz_menu2(' ON',menu,0);
    vloz_menu2(' OFF',menu,0);
    vloz_menu2('Cancel',menu,$3e63);
    vyber_menu(menu,v);
    case v of
         1:insert_command(joy,yes);
         2:insert_command(joy,no);
    end;
     m:=0;
end;

procedure background;
begin
 textcolor(7);
 textbackground(1);
 for f:=1 to 24 do begin
  gotoxy(1,f);
  for ff:=1 to 80 do begin
   write('°');
  end;
 end;
   TextWindow1(28,2,15,3,31,31,3,'Í');
   textcolor(11);
   gotoxy(30,3);
   write('Siriel 3.5');
end;

procedure menus;
begin
    result:=false;
    m:=0;
    repeat
       if m=0 then background;
       case m of
            0:basic_menu;
            1:animation;
            2:sound;
            3:lang;
            4:joystick_set;
       end;
    until result;
end;

begin
     init;
     load_sub;
     menus;
     done;
end.