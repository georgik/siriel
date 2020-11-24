program kryptor;
uses txt,dos,crt,geo,koder,geo2;
type dat=array[1..64] of string;

var t,r:text;
    data:^dat;
    f,x:integer;
    ch:char;
    i,k,www,c,l:word;
    meno,prip,zdroj,s,wx,sx:string;
    d:array[0..3] of string;
    break:boolean;
    b:byte;


procedure vyber(x,y:integer;var vyber:word;menu:word);
 var
     n,i:integer;
     nadpis:string;
 label preskip;
 begin
  clrscr;
  N:=3;
  textcolor(12);
  gotoxy(40,20);
  write('Ktyptor');
  gotoxy(40,19);
  write('GEORGESOFT');
  textcolor(15);
 case menu of
 1:begin
  nadpis:=' Typ kodovania: ';
  D[1]:='Posuv -2,-#10 ';
  D[0]:='Posuv -2 ';
  D[2]:='Iba kompresia riadkov a medzier';
  D[3]:='NOT';
  end;
 end;
  for I:=2 to 25 do
  TextWindow1(X,Y,75,5+N ,14,15,2,nadpis);
  for I:=0 to N do PrintText(X+8,Y+2+i,15,D[I]);
  I:=0;
  repeat
    PrintText(X+7,Y+2+i,27,' '+D[I]);
    K:=Key;
    PrintText(X+7,Y+2+i,15,' '+D[I]);
    case K of
      $0231:i:=0;
      $0332:i:=1;
      $4B00:dec(I);   $4D00:inc(I);    { Left,Right }
      $4800:dec(I); $5000:inc(I);  { Up,Down }
    end;
    if I<0 then I:=N; if I>N then I:=0;
   if k=$011b then begin clrscr;writeln;writeln('Program ukonceny !  Konfiguracia nezapisana ! :('); break:=true; end;
  until (K=$1C0D) or (K=$011B);        { Enter,Esc }

  if K=$1C0D then begin
   vyber:=i;
    end;
  end;

procedure xkrypt(met:byte);
var len:longint;
    sr:searchrec;
label skip;
begin
  textmode(3);
  clrscr;
 if met=0 then
  vyber(3,10,www,1)
  else www:=1;
  inc(www);

  str(www,wx);
findfirst(zdroj+'mie',$3f,sr);
writeln('Krypting to ',zdroj,'.gmc');
assign(t,meno);
if (www=3) and (prip<>'.gmx') then
assign(r,zdroj+'.gmx')
   else
if zdroj[length(zdroj)]='.' then
assign(r,zdroj+'gmc')
else
assign(r,zdroj+'.gmc');
reset(t);
rewrite(r);
repeat
  case www of
    1:begin
      read(t,ch);
      dec(sr.size);
      ch:=chr(ord(ch)-2);
      write(r,ch);
    end;
    2:begin
      read(t,ch);
      dec(sr.size);
      ch:=chr(ord(ch)-2);
      if ord(ch)<>8 then write(r,ch);
    end;
    3:begin
                inc(c);
                readln(t,data^[c]);
    end;
    4:begin
      read(t,ch);
      b:=ord(ch);
      koduj(1,b);
      if b<>8 then begin
      koduj(2,b);
      ch:=chr(b);
      write(r,ch); end;
    end;
  end;
until sr.size<=0;
close(t);
close(r);

end;

procedure enkrypt;
var remain:longint;
begin
remain:=subor_size(zdroj+'gmc');
writeln('Enkrypting to ',zdroj,'gmc');
assign(t,meno);
assign(r,zdroj+'mie');
reset(t);
rewrite(r);
repeat
      read(t,ch);
      dec(remain);
      ch:=chr(ord(ch)+2);
      write(r,ch);
      if ord(ch)=13 then write(r,chr(10));
until remain=0;
close(t);
close(r);
end;

var sr:searchrec;
    xm:longint;
procedure gifkrypt;
begin
     findfirst(zdroj+'gif',$3f,sr);
     xm:=sr.size;
     assign(t,zdroj+'gif');
     assign(r,zdroj+'mag');
     reset(t);
     rewrite(r);
        for f:=1 to 6 do read(t,ch);
        write(r,'Jx1998');
        dec(xm,6);
        repeat
          read(t,ch);
          write(r,ch);
          dec(xm);
        until xm=0;
     close(t);
     close(r);
end;


procedure gifenkrypt;
begin
     findfirst(zdroj+'mag',$3f,sr);
     xm:=sr.size;
     assign(t,zdroj+'mag');
     assign(r,zdroj+'gif');
     reset(t);
     rewrite(r);
        for f:=1 to 6 do read(t,ch);
        write(r,'GIF89a');
        dec(xm,6);
        repeat
          read(t,ch);
          write(r,ch);
          dec(xm);
        until xm=0;
     close(t);
     close(r);
end;


begin
if (paramcount=1) and (paramstr(1)='a') then begin
   findfirst('*.mie',$3f,sr);
   if doserror=0 then begin
      repeat
            meno:=sr.name;
            zdroj:='';
            for i:=1 to length(meno)-3 do
            zdroj:=zdroj+meno[i];
            xkrypt(1);
            findnext(sr);
      until doserror=18;
   end;
end
else begin
 selectfile(10,10,meno,'*.mie');
{meno:='pozadie.gif';}
writeln(meno);
if meno<>'' then begin
prip:='';
for i:=length(meno)-2 to length(meno) do
prip:=prip+meno[i];

zdroj:='';
for i:=1 to length(meno)-3 do
zdroj:=zdroj+meno[i];
upcased(prip,prip);
if prip='GIF' then gifkrypt
else
if prip='MAG' then gifenkrypt
else
if prip='GMC' then enkrypt
 else xkrypt(0);
end;
end;
credits('Kryptor for GM v.:1.01');
end.