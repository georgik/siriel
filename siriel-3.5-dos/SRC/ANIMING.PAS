{+++++++++++++++ Unita vytvorena GEORGESOFTom +++++++++++++++++++++++++++++}

unit animing;
interface

uses jxxms,xms2,jxgraf,txt,crt;

procedure getseg(gx,gy,gd,gs,num:word;var aw:array of byte);
{zoberie sektor}
procedure putseg(gx,gy,gd,gs,num:word;var aw:array of byte);
{polozi sektor}
procedure getseg2(gx,gy,gd,gs,num,col:word;var aw:array of byte);
{zoberie sektor - ignoruje farbu}
procedure putseg2(gx,gy,gd,gs,num,col:word;var aw:array of byte);
{polozi sektor - ignoruje farbu}
procedure putseg3(gx,gy,gd,gs,num,col,col2:word;var aw:array of byte);
{polozi sektor, pricom polozi neignorovanu farbu iba s indexom col2}
procedure putseg2_rev(gx,gy,gd,gs,num,col:word;var aw:array of byte);
{polozi zrkadlovy obraz, pricom ignoruje farbu}
procedure putseg2_mix(gx,gy,gd,gs,num,col:word;var aw:array of byte;num2:word;var av:array of byte);
{polozi na zaklade zmixivania dvoch obrazkov}
procedure putseg2_rev_mix(gx,gy,gd,gs,num,col:word;var aw:array of byte;num2:integer;var av:array of byte);
{polozi zmixovanie, ale zrkadlovy obraz}

function getcol(gx,gy,num:word;var am:array of byte):word;
{zoberie farbu z pola - predstavuje stvorec}

procedure charakter(chx,chy,choldx,choldy,chpoloha,chbuf:word; var am:array of byte);
{presunie postavicku}
procedure init_charakter(chsizex,chsizey,chx,chy,chpoloha,chbuf:word; var am:array of byte);
{inicializuje postavicku}
procedure vypni_charakter(choldx,choldy,chbuf:word; var am:array of byte);
{vypne postavicku}
procedure zapni_charakter(chx,chy,num,chbuf:word;var am:array of byte);
{zapne postavicku}

{--------- Tieto funkcie sa prenasaju do XMS -----------------------------}
procedure getsegxms(var kluka:klucka;gx,gy,gd,gs,num:longint);
{zoberie sektor}
procedure putsegxms(var kluka:klucka;gx,gy,gd,gs,num:longint);
{polozi sektor}
procedure getseg2xms(var kluka:klucka;gx,gy,gd,gs,num,col:word);
{zoberie sektor - ignoruje farbu}
procedure putseg2xms(var kluka:klucka;gx,gy,gd,gs,num,col:longint);
{polozi sektor - ignoruje farbu}
function  putseg2xms_sizex(var kluka:klucka;gx,gy,gd,gs,num,col:longint):byte;
{polozi sektor - ignoruje farbu}
procedure putseg2_revxms(var kluka:klucka;gx,gy,gd,gs,num,col:word);
{polozi zrkadlovy obraz, pricom ignoruje farbu}
procedure putseg2_mixxms(var kluka,kluka2:klucka;gx,gy,gd,gs,num,col,num2:word);
{polozi na zaklade zmixivania dvoch obrazkov}
procedure putseg2_rev_mixxms(var kluka,kluka2:klucka;gx,gy,gd,gs,num,col,num2:word);
{polozi zmixovanie, ale zrkadlovy obraz}

var  sizex,sizey:word;
     lajna,lajno:tline;
     helplin:helpline;

implementation



{---}
procedure getseg(gx,gy,gd,gs,num:word;var aw:array of byte);
var gf,gff,cxx,cxx2:word;
begin
  cxx:=num*gd*gs;
  for gf:=0 to gs-1 do begin
      read_linepos(screen,lajna,gx,gf+gy,gd);
      cxx2:=cxx+gf*gs;
      for gff:=0 to gd-1 do begin
          aw[cxx2+gff]:=lajna[gff];
      end;
  end;
end;

procedure putseg(gx,gy,gd,gs,num:word;var aw:array of byte);
var gf,gff,cxx,cxx2:word;
begin
  cxx:=num*gd*gs;
  for gf:=0 to gd-1 do begin
      cxx2:=cxx+gf*gs;
      for gff:=0 to gs-1 do begin
          lajna[gff]:=aw[cxx2+gff];
      end;
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
end;

procedure getseg2(gx,gy,gd,gs,num,col:word;var aw:array of byte);
var gf,gff,cxx,cxx2:word;
begin
  cxx:=num*gd*gs;
  for gf:=0 to gs-1 do begin
      read_linepos(screen,lajna,gx,gf+gy,gd);
      cxx2:=cxx+gf*gs;
      for gff:=0 to gd-1 do begin
          if lajna[gff]<> col then aw[cxx2+gff]:=lajna[gff];
      end;
  end;

end;

procedure putseg2(gx,gy,gd,gs,num,col:word;var aw:array of byte);
var gf,gff,cxx,cxx2:word;
begin
  cxx:=num*gd*gs;
  for gf:=0 to gd-1 do begin
      read_linepos(screen,lajna,gx,gf+gy,gd);
      cxx2:=cxx+gf*gs;
      for gff:=0 to gs-1 do begin
         if aw[cxx2+gff]<>col then lajna[gff]:=aw[cxx2+gff];
      end;
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
end;

procedure putseg3(gx,gy,gd,gs,num,col,col2:word;var aw:array of byte);
var gf,gff,cxx2,cxx:word;
begin
  cxx:=num*gd*gs;
  for gf:=0 to gd-1 do begin
      read_linepos(screen,lajna,gx,gf+gy,gd);
      cxx2:=cxx+gf*gs;
      for gff:=0 to gs-1 do begin
         if aw[cxx2+gff]<>col then lajna[gff]:=col2;
      end;
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
end;

procedure putseg2_mix(gx,gy,gd,gs,num,col:word;var aw:array of byte;num2:word;var av:array of byte);
var gf,gff,cxx2,cxx,cxx3:word;
begin
  cxx:=num*gd*gs;
  for gf:=0 to gd-1 do begin
      cxx2:=cxx+gf*gs;
      cxx3:=num2*gd*gs+gf*gs;
      for gff:=0 to gs-1 do begin
         if aw[cxx2+gff]=col then lajna[gff]:=av[cxx3+gff]
            else lajna[gff]:=aw[cxx2+gff];
      end;
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
end;

procedure putseg2_rev(gx,gy,gd,gs,num,col:word;var aw:array of byte);
var gf,gff,cxx2,cxx,cxx3:word;
begin
  cxx:=num*gd*gs;
  cxx3:=(gs div 2) -1;
  for gf:=0 to gd-1 do begin
      read_linepos(screen,lajna,gx,gf+gy,gd);
      cxx2:=cxx+gf*gs+gd-1;
      for gff:=0 to gs-1 do begin
         if aw[cxx2-gff]<>col then lajna[gff]:=aw[cxx2-gff];
      end;
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
end;

procedure putseg2_rev_mix(gx,gy,gd,gs,num,col:word;var aw:array of byte;num2:integer;var av:array of byte);
var gf,gff,cxx2,cxx3,cxx:word;
begin
  cxx:=num*gd*gs;
  for gf:=0 to gd-1 do begin
      cxx2:=cxx+gf*gs+gd-1;
      cxx3:=num2*gd*gs+gf*gs;
      for gff:=0 to gs-1 do begin
         if aw[cxx2-gff]=col then lajna[gff]:=av[cxx3+gff]
            else lajna[gff]:=aw[cxx2-gff];
      end;
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
end;

procedure charakter(chx,chy,choldx,choldy,chpoloha,chbuf:word; var am:array of byte);
begin
   if (chx<>choldx) or (chy<>choldy) then begin
     putseg(choldx,choldy,sizex,sizey,chbuf,am);
     getseg(chx,chy,sizex,sizey,chbuf,am);
     putseg2(chx,chy,sizex,sizey,chpoloha,13,am);
   end
   else putseg2_mix(chx,chy,sizex,sizey,chpoloha,13,am,chbuf,am);
end;

procedure init_charakter(chsizex,chsizey,chx,chy,chpoloha,chbuf:word; var am:array of byte);
begin
     sizex:=chsizex;
     sizey:=chsizey;
     getseg(chx,chy,sizex,sizey,chbuf,am);
     putseg2(chx,chy,sizex,sizey,chpoloha,13,am);
end;

procedure vypni_charakter(choldx,choldy,chbuf:word; var am:array of byte);
begin
     putseg(choldx,choldy,sizex,sizey,chbuf,am);
end;

procedure dec_down(var num:word);
begin
       num:=num mod 16;
end;

function getcol(gx,gy,num:word;var am:array of byte):word;
begin
     if num=0 then getcol:=13
     else begin
      dec_down(gx);
      dec_down(gy);
      getcol:=am[256*num+gy*16+gx];
     end;
end;

procedure zapni_charakter(chx,chy,num,chbuf:word;var am:array of byte);
begin
     getseg(chx,chy,sizex,sizey,chbuf,am);
     putseg2(chx,chy,sizex,sizey,num,13,am);
end;


{=======================XMS===========================================}

procedure getsegxms(var kluka:klucka;gx,gy,gd,gs,num:longint);
var gf,gff,cxx:LONGINT;
begin
 if kluka.used then begin
  cxx:=num*gd*gs;
  for gf:=0 to gs-1 do begin
      read_linepos(screen,lajna,gx,gf+gy,gd);
      for gff:=0 to gd-1 do helplin[gff]:=lajna[gff];
      CopyCMemToXMem(kluka.h,cxx+gf*gd,@helplin,gd);
  end;
 end;
end;

procedure putsegxms(var kluka:klucka;gx,gy,gd,gs,num:longint);
var gf,gff,cxx:LONGINT;
begin
 if kluka.used then begin
  cxx:=num*gd*gs;
  for gf:=0 to gs-1 do begin
      CopyXMemToCMem(@helplin,kluka.h,cxx+gf*gd,gd);
      for gff:=0 to gd-1 do lajna[gff]:=helplin[gff];
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
 end;
end;


procedure getseg2xms(var kluka:klucka;gx,gy,gd,gs,num,col:word);
var gf,gff,cxx:word;
begin
 if kluka.used then begin
  cxx:=num*gd*gs;
  for gf:=0 to gs-1 do begin
      read_linepos(screen,lajna,gx,gf+gy,gd);
      for gff:=0 to gd-1 do begin
          if lajna[gff]= col then helplin[gff]:=0 else helplin[gff]:=lajna[gff];
      end;
      CopyCMemToXMem(kluka.h,cxx+gf*gs,@helplin,gd);
  end;
 end;
end;

procedure putseg2xms(var kluka:klucka;gx,gy,gd,gs,num,col:longint);
var gf,gff,cxx,cxx2:longint;
begin
 if kluka.used then begin
  cxx:=num*gd*gs;
  for gf:=0 to gs-1 do begin
      read_linepos(screen,lajna,gx,gf+gy,gd);
      CopyXMemToCMem(@helplin,kluka.h,cxx+gf*gd,gd);
      for gff:=0 to gd-1 do begin
         if helplin[gff]<>col then lajna[gff]:=helplin[gff];
      end;
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
 end;
end;

procedure putseg2_revxms(var kluka:klucka;gx,gy,gd,gs,num,col:word);
var gf,gff,cxx:word;
begin
 if kluka.used then begin
  cxx:=num*gd*gs;
  for gf:=0 to gs-1 do begin
      read_linepos(screen,lajno,gx,gf+gy,gd);
      CopyXMemToCMem(@lajna,kluka.h,cxx+gf*gd,gd);
      for gff:=0 to gd-1 do begin
         if lajna[gff]=col then lajna[gff]:=lajno[gff];
      end;
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
 end;
end;

procedure putseg2_mixxms(var kluka,kluka2:klucka;gx,gy,gd,gs,num,col,num2:word);
var gf,gff,cxx,cxx2:word;
begin
 if kluka.used then begin
  cxx:=num*gd*gs;
  cxx2:=num2*gd*gs;
  for gf:=0 to gs-1 do begin
      CopyXMemToCMem(@lajna,kluka.h,cxx+gf*gd,gd);
      CopyXMemToCMem(@lajno,kluka2.h,cxx2+gf*gd,gd);
      for gff:=0 to gd-1 do begin
         if lajna[gff]=col then lajna[gff]:=lajno[gff];
      end;
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
 end;
end;

function  putseg2xms_sizex(var kluka:klucka;gx,gy,gd,gs,num,col:longint):byte;
{polozi sektor - ignoruje farbu}
var gf,gff,cxx,cxx2:longint;
    long:word;
begin
 long:=0;
 if kluka.used then begin
  cxx:=num*gd*gs;
  for gf:=0 to gs-1 do begin
      read_linepos(screen,lajna,gx,gf+gy,gd);
      CopyXMemToCMem(@helplin,kluka.h,cxx+gf*gd,gd);
      for gff:=0 to gd-1 do begin
         if helplin[gff]<>col then begin
            lajna[gff]:=helplin[gff];
            if gff>long then long:=gff;
         end;
      end;
      write_linepos(screen,lajna,gx,gf+gy,gd);
  end;
 end;
 putseg2xms_sizex:=long;
end;


{toto treba dorazit}
procedure putseg2_rev_mixxms(var kluka,kluka2:klucka;gx,gy,gd,gs,num,col,num2:word);
var gf,gff,cxx2,cxx3,cxx:word;
begin
 if kluka.used then begin
  cxx:=num*gd*gs;
  cxx2:=num2*gd*gs;
  for gf:=0 to gs-1 do begin
      CopyXMemToCMem(@lajna,kluka.h,cxx+gf*gd,gd);
      CopyXMemToCMem(@lajno,kluka2.h,cxx2+gf*gd,gd);
      for gff:=0 to gd-1 do begin
         if lajna[gd-gff-1]<>col then lajno[gff]:=lajna[gd-gff-1]
      end;
      write_linepos(screen,lajno,gx,gf+gy,gd);
  end;
 end;
end;

end.