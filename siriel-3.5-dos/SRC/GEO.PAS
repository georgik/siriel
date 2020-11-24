{Toto je specialna unita vytvorena pre potreby GEORGESOFTu}

unit geo;

interface

procedure grafika_init(resolution_x,resolution_y,bits_per_pixel:word);

procedure clear_key_buffer;
procedure sipka_limit(sminx,sminy,smaxx,smaxy,sstep:word;abile:boolean;tol:byte;h,d,l,p:boolean);
procedure sipky(var sipx,sipy:integer;var kluc:word);
procedure fake_key(fk:word);
procedure sipka_joystick;
procedure sipka_joystick2;
procedure sipka_spat(var sipx,sipy:word);
procedure sipka_fake(pseudo:word;var sipx,sipy:word);
function sipka_fakex(pseudo,step:word;var sipx,sipy:word):boolean;
function sipka_fake2(pseudo:word;var sipx,sipy:word;krok:word):boolean;

procedure keyboard_speed(rep,pau:byte);

procedure install_waiting;
procedure wait(ca:word);

procedure joystick(var v,yv:word;var button:byte);
procedure joystick_kaliber;
function detect_joystick:boolean;

{grafika}
procedure input_key(x,y,col,rol:integer;var vypis:string;maxinput:byte;charl:char);
procedure okno(x,y,x1,y1,col:integer);
procedure incs(var s:string;pridaj:string);

procedure credits(meno:string);

procedure init_keyboard(stav:byte);
procedure done_keyboard;
procedure get_keyboard;
function zmack(cisl:byte):boolean;
procedure key_swap(cisl:byte;stav:boolean);
procedure scroll_flash;
procedure non_key;
procedure key_wait;

procedure menu(x,y:integer;nazov:string;var pol:array of string;num:word;var vyber:word);

procedure SelectFile(X,Y:integer;var menko:string;maska:string);

{text}
function  text_okno(x,y,dl:word;napis:string;var vypis:string):boolean;
procedure get_text(x,y,col1,col2,typ:byte;znak:char;meno:string;var st:string;dlzka:byte);

procedure move_param(var s:string);     {presunie parametre z prikazoveho riadku}

function subor_exist(s:string):boolean;  {zisti, ci existuje dany subor}
procedure create_file(s:string);

procedure get_name(zdroj:string;var ciel:string); {vyberie meno zo sintaxu [meno]=nieco }
procedure get_name_normal(zdroj:string;var ciel:string); {vyberie meno zo sintaxu [meno]=nieco }
procedure get_funk(zdroj:string;var ciel:string); {vyberie nieco zo sintaxu [meno]=nieco }
procedure get_funk_normal(zdroj:string;var ciel:string); {vyberie nieco zo sintaxu [meno]=nieco }
procedure movarr2str(var par:array of byte;var sfx:string);
procedure mov_num(var zdroj:string;var num:word;var poradie:word);
procedure mov_num2(var zdroj:string;var num:byte;var poradie:word);
procedure mov_string(var zdroj,num:string;var poradie:word);
procedure upcased(zdroj:string;var ciel:string);
function upcased2(zdroj:string):string;
procedure mov_command(var zdroj,num:string;var poradie:word);
function is_command(var zdroj,ciel:string):boolean;  {vyberie metaprikaz}
procedure mov_part(var zdroj,num:string;var poradie:word); {presunie po /}
procedure mov_part_num(var zdroj:string;var num,poradie:word); {presunie po /}
procedure mov_part_num2(var zdroj:string;var num:byte;var poradie:word); {presunie po /}

function out_string(var zdroj:string):string;
function out_strings(var zdroj:string;znak:char):string;
function kill_strings(var zdroj:string;znak:char):string;

procedure pulzx(impulz:word);   {nieco ako pulz, caka presne urcenu dobu}
procedure swap_byte(var zdroj,ciel:byte);

{textove menu}
type
    polozka_typ=record
           meno:string;
           x,y:byte;
           k:word;
    end;
    menu_typ=record
           dat:array[1..15] of polozka_typ;
           pocet:byte;
           x,y,col1,col2,typ:byte;
         meno:string;
     end;

procedure init_menu(x,y,col1,col2,typ:word; meno:string;var menx:menu_typ);
procedure vloz_menu(x,y:byte;meno:string; var menx:menu_typ;k:word);
procedure vloz_menu2(meno:string;var menx:menu_typ;k:word);
procedure vyber_menu(var menx:menu_typ;var num:word);
procedure vloz_medzery(var zdroj:string;max:byte);


procedure swap(var zdroj,ciel:word);

procedure zapis_to(num:longint);
procedure zapis_string(num:string);
procedure warning;
procedure pripis_to(num:longint);
procedure pripis_string(num:string);
procedure vytvor_subor(s:string);
procedure write_bodka;
procedure write_ok;
procedure write_error(s:string);

function kkey:word;
function kkey2:word;

var  joystick_able:boolean;
     joystick_time,joystick_fire_time:longint;
     joystick_delay,joystick_fire_delay:word;

implementation

uses jxgraf,txt,crt,dos;
const  Color:array[1..13] of byte=(
    $3F,$3E,$31,$5F,$34, $2F,$2E,$2E,$5F, $5F,$5E,$5E, $71);
var k,last,sx,sy:word;
    tolerancia:byte;
    sb:byte;
    cch:char;
    hore,dole,lavo,pravo:boolean;
    waiting_time:word;
    sipkaminx,sipkaminy,sipkamaxy,sipkamaxx,sipkastep:word;
    klx:array[0..128] of boolean;
    old_keyboard:byte;
    sdf:byte;


{---}
procedure grafika_init(resolution_x,resolution_y,bits_per_pixel:word);
const er1='Unable to find graphic mode !';
      er2='Unable to activate graphic mode !-<';
var zx:string;
begin
{    if (resolution_x=320) and (resolution_y=200) and(bits_per_pixel=8) then
         mode:=0 else
    if (resolution_x=640) and (resolution_y=480) and(bits_per_pixel=8) then
       mode:=257 else}
    if find_best_mode(resolution_x, resolution_y, bits_per_pixel)=-1 then
    begin
         write_error(er1);
         done_graf;
         writeln(er1);
         halt(2);
    end;
    if not init_mode then begin
                 write_error(er2);
                 done_graf;
                 writeln(er2);
                 halt(2);
    end;
end;
{---}
procedure clear_key_buffer;
var k,f:word;
begin
    while keypressed do
          k:=key;
end;

procedure fake_key(fk:word);
begin
  clear_key_buffer;
  asm
    mov ah,05h
    mov cx,fk
    int 16h
  end;
end;

procedure fake_key2(fk:word);
begin
  asm
    mov ah,05h
    mov cx,fk
    int 16h
  end;
    joystick_time:=getclock+joystick_delay;
end;

procedure fake_key3(fk:word);
begin
  asm
    mov ah,05h
    mov cx,fk
    int 16h
  end;
    joystick_fire_time:=getclock+joystick_fire_delay;
end;

procedure sipka_joystick;
var jx,jy:word;
    jb:byte;
begin
  if (joystick_able) and (getclock>joystick_time) then begin
    joystick(jx,jy,jb);
    if jy<(sy-tolerancia) then fake_key2($4800);
    if jx<(sx-tolerancia) then fake_key2($4b00);
    if jx>(sx+tolerancia) then fake_key2($4d00);
    if jy>(sy+tolerancia) then fake_key2($5000);
  end;
  if (joystick_able) and (getclock>joystick_fire_time) then begin
    if jb=224 then fake_key3($1c0d);
    if jb=208 then fake_key3($011b);
  end;
end;

procedure sipka_joystick2;
var jx,jy:word;
    jb:byte;
label skip;
begin
  if (joystick_able) and (getclock>joystick_time) then begin
    joystick(jx,jy,jb);
    if (jy<(sy-tolerancia)) and (jx<(sx-tolerancia)) then begin
         fake_key2($4700);
       goto skip;
    end;
    if (jy<(sy-tolerancia)) and (jx>(sx+tolerancia)) then begin
       fake_key2($4900);
       goto skip;
    end;
    if (jy>(sy+tolerancia)) and (jx>(sx+tolerancia)) then begin
       fake_key2($5100);
       goto skip;
    end;
    if (jy>(sy+tolerancia)) and (jx<(sx-tolerancia)) then begin
       fake_key2($4f00);
       goto skip;
    end;
    if jy<(sy-tolerancia) then fake_key2($4800);
    if jx<(sx-tolerancia) then fake_key2($4b00);
    if jx>(sx+tolerancia) then fake_key2($4d00);
    if jy>(sy+tolerancia) then fake_key2($5000);
  end;
  skip:
  if (joystick_able) and (getclock>joystick_fire_time) then begin
    if jb=224 then fake_key3($1c0d);
    if jb=208 then fake_key3($011b);
  end;
end;


procedure sipka_limit(sminx,sminy,smaxx,smaxy,sstep:word;abile:boolean;tol:byte;h,d,l,p:boolean);
begin
 sipkaminx:=sminx;
 sipkaminy:=sminy;
 sipkamaxx:=smaxx;
 sipkamaxy:=smaxy;
 sipkastep:=sstep;
 joystick_able:=abile;
 tolerancia:=tol;
 hore:=h;
 dole:=d;
 lavo:=l;
 pravo:=p;
end;

procedure sipky(var sipx,sipy:integer;var kluc:word);
begin

  if (keypressed) or (joystick_able) then begin
   if joystick_able then sipka_joystick;
   if keypressed then k:=key;
   last:=k;
   case k of
     $4800:if hore then dec(sipy,sipkastep);
     $5000:if dole then inc(sipy,sipkastep);
     $4b00:if lavo then dec(sipx,sipkastep);
     $4d00:if pravo then inc(sipx,sipkastep);
   end;
   if sipx<sipkaminx then sipx:=sipkaminx;
   if sipy<sipkaminy then sipy:=sipkaminy;
   if sipx>sipkamaxx then sipx:=sipkamaxx;
   if sipy>sipkamaxy then sipy:=sipkamaxy;
   kluc:=k;               end;
end;

procedure sipka_fake(pseudo:word;var sipx,sipy:word);
begin
   last:=pseudo;
   case pseudo of
     $4800:dec(sipy,sipkastep);
     $5000:inc(sipy,sipkastep);
     $4b00:dec(sipx,sipkastep);
     $4d00:inc(sipx,sipkastep);
   end;
   if sipx<sipkaminx then sipx:=sipkaminx;
   if sipy<sipkaminy then sipy:=sipkaminy;
   if sipx>sipkamaxx then sipx:=sipkamaxx;
   if sipy>sipkamaxy then sipy:=sipkamaxy;
end;

function sipka_fakex(pseudo,step:word;var sipx,sipy:word):boolean;
begin
   sipka_fakex:=false;
   case pseudo of
     $4800:dec(sipy,step);
     $5000:inc(sipy,step);
     $4b00:dec(sipx,step);
     $4d00:inc(sipx,step);
   end;
   if sipx<sipkaminx then begin
                          sipx:=sipkaminx;
                          sipka_fakex:=true;
   end;
   if sipy<sipkaminy then begin
                          sipy:=sipkaminy;
                          sipka_fakex:=true;
   end;
   if sipx>sipkamaxx then begin
                          sipx:=sipkamaxx;
                          sipka_fakex:=true;
   end;
   if sipy>sipkamaxy then begin
                          sipy:=sipkamaxy;
                          sipka_fakex:=true;
   end;
end;

function sipka_fake2(pseudo:word;var sipx,sipy:word;krok:word):boolean;
begin
   sipka_fake2:=true;
   case pseudo of
     $4800:dec(sipy,krok);
     $5000:inc(sipy,krok);
     $4b00:dec(sipx,krok);
     $4d00:inc(sipx,krok);
   end;
   if (sipx<sipkaminx) or (sipy<sipkaminy) or (sipx>sipkamaxx)
        or (sipy>sipkamaxy) then sipka_fake2:=false;
end;

procedure sipka_spat(var sipx,sipy:word);
begin
   case last of
     $4800:inc(sipy,sipkastep);
     $5000:dec(sipy,sipkastep);
     $4b00:inc(sipx,sipkastep);
     $4d00:dec(sipx,sipkastep);
   end;
end;

procedure keyboard_speed(rep,pau:byte);
begin
 asm
   mov ah,03h
   mov al,5
   mov bl,rep
   mov bh,pau
   int 16h
 end;
end;

procedure install_waiting;
begin
asm
   mov ah,00h
   int 1ah
   mov waiting_time,dx
end;
end;

procedure wait(ca:word);
var zx:word;
begin
repeat
asm
   mov ah,00h
   int 1ah
   mov zx,dx
end;
until (waiting_time+ca<=zx);
      waiting_time:=zx;
end;

procedure joystick(var v,yv:word;var button:byte);
var wx,wy:word;
    wb:byte;
begin
 asm
    mov ah,84h
    mov dx,1
    int 15h
    mov wx,ax
    mov wy,bx  {suradnice}

    mov al,0
    mov ah,84h
    mov dx,0
    int 15h
    mov wb,al
 end;
 v:=wx;
 yv:=wy;
 button:=wb;
end;

procedure joystick_kaliber;
begin
  joystick(sx,sy,sb);
end;

procedure okno(x,y,x1,y1,col:integer);
var fo,ffo:word;
begin
 for fo:=x to x1+x do
   for ffo:=y to y1+y do
         putpixel(screen,fo,ffo,col);
end;

procedure input_key(x,y,col,rol:integer;var vypis:string;maxinput:byte;charl:char);
var kl:word;
    medz:string;
    f:word;
begin
 kl:=0;
 vypis:=vypis+charl;
 rectangle2(screen,x,y,maxinput*chardx,chardy,rol);
    print_normal(screen,x,y,vypis,col,rol);
 repeat
 if keypressed then begin
    kl:=key;
    clear_key_buffer;
    medz:='';
  if length(vypis)<=maxinput+1 then begin
    for f:=1 to length(vypis) do medz:=medz+' ';
    printat(screen,x,y,medz+' ',0,0,0);
  end;
  if (KL<>$011b) and (kl<>$0e08) and (KL<>$1c0d) and (length(vypis)<=maxinput)
     and (KL<>$4800) and (KL<>$4b00) and (KL<>$4d00) and (KL<>$5000) then begin
    vypis[length(vypis)]:=chr(kl);
    vypis:=vypis+charl;
    print_normal(screen,x,y,vypis,col,rol);
  end else
        if (KL<>$011b) and (kl<>$0e08) and (KL<>$1c0d) then
                print_normal(screen,x,y,vypis,col,rol);
  if (kl=$0e08) and (length(vypis)>1) then begin
  vypis[0]:=chr(length(vypis)-2);
  vypis:=vypis+charl+' ';
    print_normal(screen,x,y,vypis,col,rol);
  vypis[0]:=chr(length(vypis)-1);
  end
        else if kl=$0e08 then print_normal(screen,x,y,charl,col,rol);
 end;
 until (kl=$011b) or (kl=$1c0d);
 if kl=$011b then vypis:='';
 if kl=$1c0d then vypis[0]:=chr(length(vypis)-1);
 okno(x,y,(maxinput+1)*8,8,rol);
    print_normal(screen,x,y,vypis,col,rol);
end;

procedure incs(var s:string;pridaj:string);

begin
 s:=s+pridaj;
end;

procedure credits(meno:string);
begin
  textbackground(0);
  clrscr;
  writeln;
  writeln;
  textcolor(10);
  writeln('Program: '+meno);
  writeln;
  textcolor(12);
  writeln('   __  ___   __   ___    __  ___  ___   __   ___  ____');
  writeln('  / _)(  _) /  \ (  ,)  / _)(  _)/ __) /  \ (  _)(_  _)');
  writeln(' ( (/\ ) _)( () ) )  \ ( (/\ ) _)\__ \( () ) ) _)  )(');
  writeln('  \__/(___) \__/ (_)\_) \__/(___)(___/ \__/ (_)   (__)');
  writeln('-------------------------------------------------------');
  writeln('      ²±° (C) 1996-1999 All rights reserved ! °±²');
  textcolor(13);
  writeln;
  writeln('Programmer: Juraj Michalek');
  textcolor(9);
  writeln('Nick:       GEORGI');
  textcolor(15);
  writeln;
{  writeln('Street: Lanska 926/3-14');
  writeln('City:   Pov. Bystrica');
  writeln('ZIP:    017 01');
  writeln('State:  Slovakia');}
  textcolor(11);
  writeln('URL:    http://www.geocities.com/Area51/Stargate/3929');
  writeln;
  writeln('e-mail: georgi@post.sk');
  writeln;
  textcolor(14);
  writeln('Please send me e-mail. XX:-D');
  textcolor(15);
end;

procedure init_keyboard(stav:byte);
begin
   for sdf:=0 to 128 do klx[sdf]:=false;
   old_keyboard:=mem[0:$417];
   mem[0:$417]:=stav;
end;

procedure done_keyboard;
begin
   mem[0:$417]:=old_keyboard;
end;

procedure get_keyboard;
var klu:byte;
begin
  clear_key_buffer;
  asm

    in  al,60h
    mov klu,al
  end;
        if (klu>=128) then
                Klx[klu-128]:=false
        else
                Klx[klu]:=true;
   if  (klu=203) or (klu=205) then non_key;
{Povie mi niekto, co robi toto !}
{asm
   in al,61h
   mov ah,al
   or al,80h
   out 61h,al
   xchg ah,al
   out 61h,al
   mov al,20h
   out 20h,al
end; }                             {xxxxxxxxxxxxxx}
end;

function zmack(cisl:byte):boolean;
begin
  zmack:=klx[cisl]
end;

procedure key_swap(cisl:byte;stav:boolean);
begin
 klx[cisl]:=stav;
end;

procedure scroll_flash;
begin
  if mem[0:$417]=0 then mem[0:$417]:=16
     else mem[0:$417]:=0;
end;

procedure non_key;
begin
   for sdf:=0 to 128 do klx[sdf]:=false;

end;

procedure key_wait;
begin
clear_key_buffer;
key;
end;

procedure menu(x,y:integer;nazov:string;var pol:array of string;num:word;var vyber:word);
 var
     k:word;
     n,i:integer;
 label preskip;
 begin
  N:=num-1;
  for I:=2 to 25 do
  TextWindow1(X,Y,75,5+N ,31,31,3,nazov);
  for I:=0 to N do PrintText(X+8,Y+2+i,31,pol[I]);
  I:=0;
  repeat
    PrintText(X+7,Y+2+i,47,' '+pol[I]+' ');
    K:=Key;
    PrintText(X+7,Y+2+i,31,' '+pol[I]+' ');
    case K of
      $0231:i:=0;
        $0332:i:=1;
        $4B00:dec(I);   $4D00:inc(I);    { Left,Right }
      $4800:dec(I); $5000:inc(I);  { Up,Down }
    end;
    if I<0 then I:=N; if I>N then I:=0;
   if k=$011b then  vyber:=0;
  until (K=$1C0D) or (K=$011B);        { Enter,Esc }

  if K=$1C0D then begin
     vyber:=i+1;
    end;
end;

{file selector}
type Filesselector=array[0..1023] of string[12];
var files:^filesselector;
    Max,DirNum,Page,PageMax,No:integer;
    Mask:string[12];
    jopo,old,oldmeno:string;

function TestDir(Path:string;DirType:byte):integer;
var DirInfo:SearchRec;    { DirType: 1=File, 2=Dir, 3=Vol }
begin                     { 0=Find not, 1=Yes }
  FindFirst(Path,AnyFile,DirInfo); TestDir:=0;
  while DosError=0 do begin
    case DirType of
      1:if DirInfo.Attr in [$00..$07,$20..$27] then begin TestDir:=1; Exit; end;
      2:if DirInfo.Attr in [$10..$17] then begin TestDir:=1; Exit; end;
      3:if DirInfo.Attr in [$08,$18,$28] then begin TestDir:=1; Exit; end;
    end;
    FindNext(DirInfo);
  end;
end;
{ ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ SortFiles ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ }
procedure SortFiles(L,R:integer);
var I,J:integer;
    M,T:string[12];
begin
  I:=L; J:=R; M:=Files^[(L+R) shr 1];
  repeat
    while Files^[I]<M do Inc(I);  { Move right }
    while M<Files^[J] do Dec(J);  { Move left }
    if I<=J then begin
      T:=Files^[I]; Files^[I]:=Files^[J]; Files^[J]:=T;
      Inc(I); Dec(J);
    end;
  until I>J;
  if L<J then SortFiles(L,J);
  if I<R then SortFiles(I,R);
end;
{ ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ GetFiles ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ }
procedure GetFiles(Path:string);
var DirInfo:SearchRec;
begin
  Max:=0; DirNum:=0; Page:=0; No:=0;
  FindFirst('*.*',AnyFile,DirInfo);
  while DosError=0 do begin
    if DirInfo.Attr in [$10..$17] then
      begin Files^[DirNum]:=DirInfo.Name; Inc(DirNum); end;
    FindNext(DirInfo);
  end;
  Max:=DirNum;
  FindFirst(Path,AnyFile,DirInfo);
  while DosError=0 do begin
    if DirInfo.Attr in [$00..$07,$20..$27] then
        begin Files^[Max]:=DirInfo.Name; Inc(Max); end;
    FindNext(DirInfo);
  end;
  SortFiles(0,DirNum-1); SortFiles(DirNum,Max-1);
end;

{ ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ FilesMask ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ }
procedure FilesMask(X,Y:integer);
var St:string;
    I,J:integer;
begin
  TextWindow1(X,Y,40,3,Color[6],Color[7],1,' Zadajte masku s£boru ');
  TextBar(X+1,Y+1,38,1,Color[8],' ');
  if (InputText(X+2,Y+1,12,St)=0) or (St='') then
    begin SetCurShape($20,0); Exit; end;
  SetCurShape($20,0); J:=0;
  for I:=1 to Length(St) do if St[I] in [':','\'] then J:=1;
  if (J=0) and (TestDir('*.*',2)=1) then begin
    GetFiles(St); Mask:=St;  { 2=Dir }
  end else begin
    TextWindow1(X,Y,40,3,Color[10],Color[11],1,' Chyba ');
    PrintText(X+2,Y+1,Color[12],'Neexistuj£ci subor alebo maska.');
    K:=Key; K:=0;
  end;
end;
{ ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ SelectDrive ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ }
procedure SelectDrive(X,Y:integer);
var St:string;
    I,N:integer;
    D:array[0..25] of char;
begin
  D[0]:='A'; D[1]:='B'; N:=1;
  for I:=2 to 25 do
    if (TestDir(Chr(I+65)+':\*.*',1)=1) or (TestDir(Chr(I+65)+':\*.*',2)=1)
    then begin Inc(N); D[N]:=Chr(I+65); end;
  TextWindow1(X,Y,40,3+N div 7,Color[6],Color[7],1,' Vyberte disk ');
  for I:=0 to N do PrintText(X+3+5*(I mod 7),Y+1+I div 7,Color[8],D[I]+':');
  I:=0;
  repeat
    PrintText(X+2+5*(I mod 7),Y+1+I div 7,Color[9],' '+D[I]+': ');
    K:=Key;
    PrintText(X+2+5*(I mod 7),Y+1+I div 7,Color[8],' '+D[I]+': ');
    case K of
      $4B00:Dec(I);   $4D00:Inc(I);    { Left,Right }
      $4800:Dec(I,7); $5000:Inc(I,7);  { Up,Down }
    end;
    if I<0 then I:=N; if I>N then I:=0;
  until (K=$1C0D) or (K=$011B);        { Enter,Esc }
  if K=$1C0D then begin
    if (TestDir(D[I]+':'+Mask,1)=1) or (TestDir(D[I]+':*.*',2)=1)
    then begin
      GetDir(I+1,St); ChDir(St);
        GetFiles(Mask);
    end else begin
      TextWindow1(X,Y,47,3,Color[10],Color[11],1,' Chyba ');
      PrintText(X+2,Y+1,Color[12],'Neexistuj£ce alebo nepripraven‚ zariadenie.');
      K:=Key;
    end;
  end;
  K:=0;
end;
{ ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ PrintFile ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ }
procedure PrintFile(X,Y,Color,No:integer);
begin
  TextBar(X,Y,14,1,Color,' ');
  if No>=DirNum then PrintText(X+1,Y,Color,Files^[No])
    else PrintText(X+1,Y,Color,Files^[No]+'\');
end;
{ ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ ShowPage ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ }
procedure ShowPage(X,Y,PageNo:integer);  { 4x10,56x10 }
var I,C:integer;
begin
  PageMax:=40;
  if (Max<40) or (Page=(Max-1) div 40) then PageMax:=(Max-1) mod 40+1;
  for I:=0 to PageMax-1 do begin
    if PageNo*40+I>=DirNum then C:=Color[3] else C:=Color[5];
    PrintFile(X+14*(I and 3),Y+I shr 2,C,40*PageNo+I);
  end;
  for I:=PageMax to 39 do
    TextBar(X+14*(I and 3),Y+I shr 2,14,1,Color[1],' ');
end;
{ ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ PrintMask ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ }
procedure PrintMask(X,Y,Color:integer);
var St:string;
begin
  GetDir(0,St);
  if St[Length(St)]<>'\' then St:=St+'\';
  TextBar(X,Y,55,1,Color,' ');
  PrintText(X,Y,Color,St+Mask);
  jopo:=st;
  old:=st;
end;

procedure ukaz(x,y:integer);
begin
  SetCurShape($20,0);
  TextBar(1,1,80,1,Color[13],' '); TextBar(1,25,80,1,Color[13],' ');
  PrintText(3,1,Color[13],'Vyberte s£bor ....');
  PrintText(3,25,Color[13],'/-Maska *-Disk Enter-Nacitaj Esc-Koniec');
  TextWindow1(X,Y,58,13,Color[1],Color[2],1,' Vyberte s£bor ');

end;

{ ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ SelectFile ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ }
procedure SelectFile(X,Y:integer;var menko:string;maska:string);  { 58x13 }
var C,K2:integer;
    St:string;

begin
   oldmeno:=menko;
   new(files);
  if (TestDir('*.*',1)=0) and (TestDir('*.*',2)=0) then begin
    Writeln('Nie je mo§ne n jsœ s£bor alebo adres r !'); Halt(1); end;
  if old<>'' then st:=old
  else
   GetDir(0,St);
{  GetText(1,1,80,25,Buf);}
  ukaz(x,y);
  Mask:=maska; GetFiles(Mask);
  PrintMask(X+2,Y+1,Color[2]);
  ShowPage(X+1,Y+2,0);
   repeat
    PrintFile(X+1+14*(No and 3),Y+2+No shr 2,Color[4],40*Page+No);

    K:=Key; K2:=K mod 256;
    if 40*Page+No>=DirNum then C:=Color[3] else C:=Color[5];
    PrintFile(X+1+14*(No and 3),Y+2+No shr 2,C,40*Page+No);
    case K of
        $4B00:Dec(No);    $4D00:Inc(No);        { Left,Right }
      $4800:Dec(No,4);  $5000:Inc(No,4);      { Up,Down }
      $4700:No:=0;      $4F00:No:=PageMax-1;  { Home,End }
      $4900:if Page>0 then                    { PgUp}
                begin Dec(Page); ShowPage(X+1,Y+2,Page); end;
      $5100:if Page<(Max-1) div 40 then       { PgDn }
            begin Inc(Page); ShowPage(X+1,Y+2,Page); end;
      $352F:begin                             { / }
            FilesMask(X+8,Y+5);
            PrintMask(X+2,Y+1,Color[2]);
            ShowPage(X+1,Y+2,Page);
          end;

      $372A,$092A:begin                       { * }
            SelectDrive(X+7,Y+5);
                PrintMask(X+2,Y+1,Color[2]);
                ShowPage(X+1,Y+2,Page);
          end;
      $1C0D:if 40*Page+No<DirNum then begin   { Enter }
            ChDir(Files^[40*Page+No]);
                GetFiles(Mask);
            PrintMask(X+2,Y+1,Color[2]);
            ShowPage(X+1,Y+2,Page);
            k:=0;
          end
            else begin
           menko:=jopo+files^[40*page+no];

{              ukaz(x,y);
            PrintMask(X+2,Y+1,Color[2]);
            ShowPage(X+1,Y+2,Page);}

            end;
    end;
    if K2 in [48..57,65..90,97..122] then begin  { 0..9, A..Z, a..Z }
      if K2>=97 then Dec(K2,32);
        for C:=DirNum to Max-1 do if Files^[C,1]=Chr(K2) then begin
      Page:=C div 40; ShowPage(X+1,Y+2,Page);
      No:=C mod 40; C:=Max-1;
      end;
    end;
    if No<0 then No:=PageMax-1;
    if No>PageMax-1 then No:=0;
  until (K=$011B) or (k=$1c0d);                              { Esc }
  if k=$011b then menko:=oldmeno;
 setcurshape(30,14);
  dispose(files);
end;

function text_okno(x,y,dl:word;napis:string;var vypis:string):boolean;
begin
  text_okno:=true;
  TextWindow1(x,y,x+dl+2,3,Color[6],Color[7],1,napis);
  TextBar(x+1,y+1,x+dl,1,Color[8],' ');
  if (InputText(x+2,y+1,dl,vypis)=0) or (vypis='') then
    text_okno:=false;
end;






procedure move_param(var s:string);
var ft:byte;
begin
  s:='';
  if paramcount>0 then
          for ft:=1 to paramcount do
                s:=s+paramstr(ft);
end;

procedure create_file(s:string);
var t:text;
begin
    assign(t,s);
    rewrite(t);
    close(t);
end;

function subor_exist(s:string):boolean;
var sr:searchrec;
begin
    subor_exist:=false;
    findfirst(s,$3f,sr);
    if doserror=0 then subor_exist:=true;
end;

procedure get_name(zdroj:string;var ciel:string);
var fr:word;
begin
   get_name_normal(zdroj,ciel);
   for fr:=1 to length(ciel) do
     ciel[fr]:=upcase(ciel[fr]);
end;

procedure get_name_normal(zdroj:string;var ciel:string);
var fr:word;
begin
   fr:=0;
   ciel:='';
 if zdroj[1]<>';' then begin
   repeat
     inc(fr);
   until (zdroj[fr]='[') or (fr>length(zdroj));
     inc(fr);
   repeat
     ciel:=ciel+zdroj[fr];
     inc(fr);
   until (zdroj[fr]=']') or (fr>length(zdroj));
 end;
end;

procedure get_funk(zdroj:string;var ciel:string);
var fr,fl:word;
begin
     get_funk_normal(zdroj,ciel);
   for fl:=fr to length(ciel) do
     ciel[fl]:=upcase(ciel[fl]);
end;

procedure get_funk_normal(zdroj:string;var ciel:string);
var fr,fl:word;
begin
   fr:=0;
   ciel:='';
 if zdroj[1]<>';' then begin
   repeat
     inc(fr);
   until (zdroj[fr]='=') or (fr>length(zdroj));
     inc(fr);
   for fl:=fr to length(zdroj) do
     ciel:=ciel+zdroj[fl];
 end;
end;

procedure movarr2str(var par:array of byte;var sfx:string);
var row:word;
begin
    sfx:='';
    row:=0;
    repeat
      inc(row);
      if  par[row]<>0 then sfx:=sfx+chr(par[row]);
    until par[row]=0;
end;

procedure mov_num2(var zdroj:string;var num:byte;var poradie:word);
var numf:word;
    row:string;
begin
   mov_string(zdroj,row,poradie);
   if row='' then num:=0 else begin
     val(row,numf,numf);
     num:=numf;
   end;
end;

procedure mov_num(var zdroj:string;var num:word;var poradie:word);
var row:string;
begin
   mov_string(zdroj,row,poradie);
   if row='' then num:=0 else
      val(row,num,num);
end;

procedure mov_string(var zdroj,num:string;var poradie:word);
var    rox:string;
begin
   rox:='';
  if length(zdroj)>=poradie then begin
   repeat
     if (zdroj[poradie]<>'~') or (zdroj[poradie]<>',') then begin
        rox:=rox+zdroj[poradie];
        inc(poradie);
     end;
   until (zdroj[poradie]='~')
         or (zdroj[poradie]=',')
         or (poradie>length(zdroj));

   inc(poradie);
  end;
   num:=rox;
end;

procedure mov_command(var zdroj,num:string;var poradie:word); {vyberie vsetko pred ;}
var rox:string;
begin
   rox:='';
 if poradie<=length(zdroj) then begin
   repeat
     if (zdroj[poradie]<>';')  then begin
        rox:=rox+zdroj[poradie];
        inc(poradie);
     end;
   until (zdroj[poradie]=';')
         or (poradie>length(zdroj));
   inc(poradie);
 end;
   num:=rox;
end;

procedure mov_part_num2(var zdroj:string;var num:byte;var poradie:word); {presunie po /}
var x:word;
begin
    mov_part_num(zdroj,x,poradie);
    num:=x;
end;

procedure mov_part_num(var zdroj:string;var num,poradie:word); {presunie po /}
var rox:string;
begin
   mov_part(zdroj,rox,poradie);
   val(rox,num,num);
end;

procedure mov_part(var zdroj,num:string;var poradie:word); {vyberie vsetko pred ;}
var rox:string;
begin
   rox:='';
  if poradie<=length(zdroj) then begin
   repeat
     if (zdroj[poradie]<>'/') then begin
        rox:=rox+zdroj[poradie];
        inc(poradie);
     end;
   until (zdroj[poradie]='/')
         or (poradie>length(zdroj));
   inc(poradie);
  end;
   num:=rox;
end;

function is_command(var zdroj,ciel:string):boolean;  {vyberie metaprikaz}
begin
     if (length(zdroj)>2) and ((zdroj[1]='<') and (zdroj[length(zdroj)]='>'))
        or (zdroj[1]='#')
        then begin
             if zdroj[1]<>'#' then ciel[0]:=chr(length(ciel)-1);
             ciel:=out_string(zdroj);
             is_command:=true;
        end
        else is_command:=false;
end;

procedure upcased(zdroj:string;var ciel:string);
var raf:word;
begin
  ciel:='';
   for raf:=1 to length(zdroj) do
         ciel:=ciel+upcase(zdroj[raf]);
end;

function upcased2(zdroj:string):string;
var raf:word;
    ciel:string;
begin
  ciel:='';
   for raf:=1 to length(zdroj) do
         ciel:=ciel+upcase(zdroj[raf]);
  upcased2:=ciel;
end;


function out_string(var zdroj:string):string;
var raw:byte;
begin
  out_string:='';
  for raw:=2 to length(zdroj) do
      out_string[raw-1]:=zdroj[raw];
  out_string[0]:=chr(ord(zdroj[0])-1);
end;

procedure get_text(x,y,col1,col2,typ:byte;znak:char;meno:string;var st:string;dlzka:byte);
begin
  TextWindow1(X,Y,dlzka+4,3,col1,Col2,typ,meno);
  TextBar(X+1,Y+1,dlzka,1,col2,znak);
  InputText(X+2,Y+1,dlzka,St);
end;

procedure init_menu(x,y,col1,col2,typ:word; meno:string;var menx:menu_typ);
begin
    menx.x:=x;
    menx.y:=y;
    menx.pocet:=0;
    menx.col1:=col1;
    menx.col2:=col2;
    menx.typ:=typ;
    menx.meno:=meno;
end;

procedure vloz_menu(x,y:byte;meno:string; var menx:menu_typ;k:word);
begin
    if menx.pocet<15 then begin
     inc(menx.pocet);
     menx.dat[menx.pocet].x:=x;
     menx.dat[menx.pocet].y:=y;
     menx.dat[menx.pocet].meno:=' '+meno+' ';
     menx.dat[menx.pocet].k:=k;
    end;
end;

procedure vloz_menu2(meno:string;var menx:menu_typ;k:word);
begin
    if menx.pocet<15 then begin
     inc(menx.pocet);
     menx.dat[menx.pocet].x:=menx.x+2;
     menx.dat[menx.pocet].y:=menx.y+1+menx.pocet;
     menx.dat[menx.pocet].meno:=' '+meno+' ';
     menx.dat[menx.pocet].k:=k;
    end;
end;

procedure hi_menu(f:byte;var menx:menu_typ);
begin
      printtext(menx.dat[f].x,menx.dat[f].y,menx.col2,menx.dat[f].meno);
end;

procedure normal_menu(f:byte;var menx:menu_typ);
begin
      printtext(menx.dat[f].x,menx.dat[f].y,menx.col1,menx.dat[f].meno);
end;

procedure vyber_menu(var menx:menu_typ;var num:word);
var ff,f,max:byte;
    k:word;
begin
   clear_key_buffer;
   k:=0;
   if menx.pocet>0 then begin
    max:=length(menx.meno);
    for f:=1 to menx.pocet do begin
        if length(menx.dat[f].meno)>max then max:=length(menx.dat[f].meno);
    end;

    textwindow1(menx.x,menx.y,max+5,menx.pocet+4,menx.col1,menx.col1,menx.typ,' '+menx.meno+' ');

    for f:=1 to menx.pocet do begin
      vloz_medzery(menx.dat[f].meno,max);
      normal_menu(f,menx);
    end;
    f:=1;
    repeat
      hi_menu(f,menx);

        if joystick_able then sipka_joystick;
      if keypressed then begin
         k:=key;
        normal_menu(f,menx);
        for ff:=1 to menx.pocet do begin
          if menx.dat[ff].k=k then f:=ff;
      end;
      case k of
           $4800,$4b00:if f>1 then dec(f) else f:=menx.pocet;
           $5000,$4d00:if f<menx.pocet then inc(f) else f:=1;
           $4700,$4900:f:=1;
           $4f00,$5100:f:=menx.pocet;
        end;
    end;
    until (k=$1c0d) or (k=$011b);
    if k=$011b then num:=0 else num:=f;
   end;
end;

procedure vloz_medzery(var zdroj:string;max:byte);
var f:byte;
begin
   if length(zdroj)<max then begin
      for f:=length(zdroj) to max-1 do begin
          zdroj:=zdroj+' ';
      end;
   end;
end;

function out_strings(var zdroj:string;znak:char):string;
var raw:byte;
    s:string;
begin
  out_strings:='';
  s:='';
  for raw:=1 to length(zdroj) do
        if (zdroj[raw]<>znak) and (zdroj[raw]>chr(13)) then s:=s+zdroj[raw];
  out_strings:=s;
end;

function kill_strings(var zdroj:string;znak:char):string;
var raw,f:byte;
    s:string;
begin
  kill_strings:='';
  s:='';
  for raw:=1 to length(zdroj) do
      if (zdroj[raw]=znak) then break;
  for f:=raw+1 to length(zdroj) do
      s:=s+zdroj[f];
  kill_strings:=s;
end;

procedure swap(var zdroj,ciel:word);
var z:word;
begin
     z     :=zdroj;
     zdroj :=ciel;
     ciel  :=z;
end;

procedure swap_byte(var zdroj,ciel:byte);
var z:byte;
begin
     z     :=zdroj;
     zdroj :=ciel;
     ciel  :=z;
end;

procedure zapis_to(num:longint);
var t:text;
begin
     assign(t,'out.out');
     rewrite(t);
     write(t,num);
     close(t);
end;

procedure zapis_string(num:string);
var t:text;
begin
     assign(t,'out.out');
     rewrite(t);
     write(t,num);
     close(t);
end;

procedure warning;
begin
 crt.SOUND(100);
 delay(100);
 crt.NOSOUND;
end;

procedure vytvor_subor(s:string);
var t:text;
begin
  if not subor_exist(s) then begin
     assign(t,s);
     rewrite(t);
     close(t);
  end;
end;

procedure pripis_to(num:longint);
var t:text;
begin
     vytvor_subor('out.out');
   {$I-}
     assign(t,'out.out');
     append(t);
     writeln(t,num);
     close(t);
   {$I+}
end;

procedure pripis_string(num:string);
var t:text;
begin
     vytvor_subor('out.out');
   {$I-}
     assign(t,'out.out');
     append(t);
     writeln(t,num);
     close(t);
   {$I+}
end;

procedure write_bodka;
begin
  write('.');
end;

procedure write_ok;
begin
 writeln('O.K.');
end;

procedure write_error(s:string);
const chybovy_subor='ERROR.ERR';
var t:text;
    h,m,x,os:word;
begin
 {$I-}
     if not subor_exist(chybovy_subor) then begin
          assign(t,chybovy_subor);
          rewrite(t);
     end else begin
          assign(t,chybovy_subor);
          append(t);
     end;
     gettime(h,m,x,os);
     writeln(t,'TIME:',h,':',m,':',x);
     getdate(h,m,x,os);
     writeln(t,'DATE:',x,'-',m,'-',h);
     writeln(t,'ERROR MESSAGE:',s);
     close(t);
 {$I+}
end;

function kkey:word;
var k:word;
begin
   k:=0;
   repeat
     sipka_joystick;
     if keypressed then k:=key;
   until k<>0;
   kkey:=k;
end;

function kkey2:word;
var k:word;
begin
   k:=0;
     sipka_joystick;
     if keypressed then k:=key;
   kkey2:=k;
end;

function detect_joystick:boolean;
var result:word;
begin
   asm
     push ax
     int 11h
     and ah,255
     xor al,al
     mov result,ax
     pop ax
   end;
{   result:=mem[0:$0410];}
   writeln(result);
   writeln(result shl 11);
   if (result shl 11)>32767 then detect_joystick:=true
   else detect_joystick:=false;
end;

procedure pulzx(impulz:word);   {nieco ako pulz, caka presne urcenu dobu}
var hh,mm,ss,os,oo,xcou:word;
begin
 oo:=100;
 xcou:=0;
 repeat
  gettime(hh,mm,ss,os);
  if oo<>os then begin inc(xcou);
  oo:=os;
  clear_key_buffer;
  end;
 until xcou=impulz;
end;

begin
  joystick_able:=false;
  joystick_delay:=100;
  joystick_fire_delay:=1000;
  joystick_time:=0;
  joystick_fire_time:=0;
end.

