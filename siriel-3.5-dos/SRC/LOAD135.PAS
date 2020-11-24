unit load135;
interface
uses jxgraf,geo,crt,jxxms,aktiv35,jxzvuk,geo2,xms2,smix;
procedure ending(varovanie:string);
procedure errormes(cisl:integer);
procedure pl(stav:integer);

implementation
procedure ending(varovanie:string);
var f:word;
begin
{   decrease_palette(palx,50);}
{   stopmod;
   freemod(modul);}
   done_graf;
   done_keyboard;
   textcolor(7);
   textbackground(0);
   writeln;
   write('Dealokacia XMS...');
{   for f:=1 to max_handles do begin
	 kill_handle(handles[f]);
   end;}
   done_handles(handles);
{   globalenablea20;}
   writeln('O.K.');
   write('Determinacia poli...');
{   if znak<>nil then dispose(znak);}
   old_frame.done;
   napis.done;
   napis2.done;
   if hraci<>nil then dispose(hraci);
   if te<>nil then dispose(te);
   if ar<>nil then dispose(ar);
   if anim<>nil then dispose(anim);
{   if post<>nil then dispose(post);}
   if vec<>nil then dispose(vec);
   if levely<>nil then dispose(levely);
   writeln('uspesna');
   writeln;
   write('Deinicializacia zvukov...');
{   if (check_sound) then begin
     stop_all_sounds;
	 for f:=0 to numsounds-1 do
	   freesound(sound[f]);
   end
   else}
   if ((zvuk) and (zvuk_loaded))
	 then begin
    Shutdown;
    FreeSounds;
    writeln('uspesna');
   end
   else
    writeln('preskocena');
   textcolor(15);
   credits(version);
   if varovanie<>'' then begin
	  write_error(varovanie);
	textcolor(12);
	writeln;
	writeln(varovanie);
	warning;
   end;
   clear_key_buffer;
   enable_ctrl_break;
   if varovanie='' then halt(0) else halt(2);
end;

procedure errormes(cisl:integer);
var e:string;
begin
  case cisl of
     1:ending(tx2[ja,4]);
     3:ending(tx3[ja,8]);
     4:ending(tx3[ja,9]);
  end;
end;

procedure pl(stav:integer);
begin
 inc(poloha);
		 case stav of
			1:if (poloha<0) or (poloha>3) then poloha:=0;
			2:if (poloha<3) or (poloha>7) then poloha:=4;
			3:if (poloha<7) or (poloha>11) then poloha:=8;
			4:if (poloha<11) or (poloha>19) then poloha:=12;
			5:if (poloha<19) or (poloha>27) then poloha:=20;
			6:if (poloha<27) or (poloha>35) then poloha:=28;
			7:if (poloha<40) or (poloha>43) then poloha:=40;
		 end;
end;

begin
end.