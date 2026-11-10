const
	  num_check=5;
	chx:string[15]=
	   ('SIRIEL3.CFG');
	  def_zvuk=nos;

procedure load_config;
var fun,funx:string;
begin
 for f:=1 to  num_snd do
     zvuky[f]:=DEf_zvuk;
 if subor_exist(chx) then begin
  assign(t,chx);
  reset(t);
  repeat
	  readln(t,fun);
	  if not eof(t) then begin
		 setup(fun);
	  end;
  until (eof(t));
  close(t);
 end
 else ending(tx3[ja,8]);
 zvuky[1]:=snd_credit;
 zvuky[2]:=snd_zober;
 zvuky[3]:=snd_port;
end;

procedure clear_all_data;
begin
    for f:=1 to pocet_veci do begin
  vec^[f].meno:='     ';
  vec^[f].x:=0;
  vec^[f].y:=0;
  vec^[f].ox:=0;
  vec^[f].oy:=0;
  vec^[f].oox:=0;
  vec^[f].ooy:=0;
  vec^[f].cislo:=0;
  vec^[f].x1:=0;
  vec^[f].y1:=0;
  vec^[f].x2:=0;
  vec^[f].y2:=0;
  vec^[f].mie:=0;
  vec^[f].obr:=0;
  vec^[f].funk:=0;
  vec^[f].inf1:=0;
  vec^[f].inf2:=0;
  vec^[f].inf3:=0;
  vec^[f].inf4:=0;
  vec^[f].inf5:=0;
  vec^[f].inf6:=0;
  vec^[f].inf7:=0;
    end;
end;

