unit jxxms;

interface
type klucka=record
		h:word;        {cislo klucky}
		used:boolean;  {pouzivanie klucky}
	end;
     helpline=array[0..639] of byte;    {sluzi naprevadzanie z scr do xms}


var num_handles:word;           {pocet vsetkych dostupnych kluciek}
    no_handle           : klucka;

procedure init_handles(num:word;var handles:array of klucka);
procedure done_handles(var handles:array of klucka);
function  kill_handle(var kluka:klucka):boolean;
function  create_handle(var kluka:klucka;size:longint):boolean;


Procedure Save_scr(var kluka:klucka; X, Y, SX, SY : longint );
Procedure draw_Scr(var kluka:klucka; X,Y,SX,SY:longint );


implementation
uses xms2,jxgraf,geo;

{inicializacia vsetkych handlov}
procedure init_handles(num:word;var handles:array of klucka);
var f:word;
begin
        num_handles:=num;
	for f:=0 to num_handles-1 do
		handles[f].used:=false;
end;

{dealokuje vsetky klucky}
procedure done_handles(var handles:array of klucka);
var f:word;
begin
      if num_handles>0 then
	for f:=0 to num_handles-1 do begin
		kill_handle(handles[f]);
	end;
        num_handles:=0;
end;

{vypne klucku - vystupom je, ci sa podarilo dealokovat pamat}
function kill_handle(var kluka:klucka):boolean;
begin
      xmunlock(kluka.h);
     kill_handle:=false;
     if (kluka.used) then begin
		xmfree(kluka.h);
		kluka.used:=false;
		kill_handle:=true;
     end;
end;

{alokuje klucku}
function create_handle(var kluka:klucka;size:longint):boolean;
begin
	create_handle:=false;
        if size mod 2 = 1 then inc(size);
	if not kluka.used then begin
	     kluka.h:=xmalloc((size div 1024)+1);
	     if kluka.h>0 then begin
		  kluka.used:=true;
		  create_handle:=true;
{                  xmlock(kluka.h);}
	     end;
	end
	else begin
{                  xmunlock(kluka.h);}
	     if xmrealloc(kluka.h,((size div 1024)+1)) then
			create_handle:=true;
{                  xmlock(kluka.h);}
	end;
end;

{---------------XMS save-------------------}
Procedure Save_scr(var kluka:klucka; X, Y, SX, SY : longint );
Var
   xmline:^tline;
   geoline:^helpline;
   A1 ,f: Longint;
Begin
     create_handle(kluka,(sx*sy));
     New( xmline );
     new( geoline );
     For A1 := Y To Y+SY-1 Do
     Begin
	    read_linepos( screen, xmLine^, X, A1, SX);
	    for f:=0 to sx-1 do geoline^[f]:=xmline^[f];
	    CopyCMemToXMem( kluka.h, ((A1 - Y) * SX) , geoline, SX );
     End;
     Dispose( xmLine );
     dispose( geoline );
End;

Procedure draw_Scr(var kluka:klucka; X,Y,SX,SY:longint );
Var
   xmline:^tline;
   geoline:^helpline;
   A1,f : Longint;
Begin
     New( xmLine );
     new( geoline );
     For A1 := Y To Y+SY-1 Do
     Begin
	    CopyXMemToCMem( geoline, kluka.h, ((A1 - Y) * SX), SX );
	    for f:=0 to sx-1 do xmline^[f]:=geoline^[f];
	    write_linepos(screen, xmLine^, X, A1, SX);
     End;
     Dispose( xmLine );
     dispose( geoline );
End;

begin
  num_handles    := 0;
  no_handle.used := false;
end.