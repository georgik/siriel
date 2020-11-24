unit process;
interface

uses aktiv35,geo,animing;

procedure process_all(shut_down_siriel:boolean);
procedure process_all2(shut_down_siriel:boolean);

implementation

procedure process_all(shut_down_siriel:boolean);
var f     : word;
begin
    {polozi pozadie}
    for f:=1 to nahrane_veci do begin
	if (vec^[f].change)and (vec^[f].mie=miestnost) then begin
	   putseg(vec^[f].ox,vec^[f].oy,16,16,0,vec^[f].zas);
	end;
    end;
    for f:=1 to nahrane_veci do begin {kontroluje, ci sa firebally maju vratit na povodnu suradnicu}
    if ((vec^[f].funk=15) or (vec^[f].funk=18)) and (freez_time=0) then begin
	case vec^[f].inf1 of
	  1,2:if (vec^[f].x=vec^[f].oox) then vec^[f].change:=true;
	  3,4:if (vec^[f].y=vec^[f].ooy) then vec^[f].change:=true;
	 end;
	end;

	if (vec^[f].change) and (vec^[f].mie=miestnost) and (vec^[f].visible) then begin
	   getseg(vec^[f].x,vec^[f].y,16,16,0,vec^[f].zas);
	end;
    end;

    for f:=1 to nahrane_veci do begin
	if vec^[f].visible then begin
	  if ((vec^[f].meno[2]='A')and (vec^[f].mie=miestnost)) then begin
	    if (vec^[f].useanim) then begin
		if vec^[f].change then begin
		 vec^[f].ox:=vec^[f].x;
		 vec^[f].oy:=vec^[f].y;
		 putseg2(vec^[f].x,vec^[f].y,16,16,anic+anx[vec^[f].obr],13,anim^)
		end else
		if (freez_time=0) then putseg2_mix(vec^[f].x,vec^[f].y,16,16,anic+anx[vec^[f].obr],13,anim^,0,vec^[f].zas)
             else if (vec^[f].meno[3]<>'S') then
                  putseg2_mix(vec^[f].x,vec^[f].y,16,16,anic+anx[vec^[f].obr],13,anim^,0,vec^[f].zas)
	     end else
	     if {vec^[f].inf7=0} vec^[f].smer then begin
		if vec^[f].change then begin
		 vec^[f].ox:=vec^[f].x;
		 vec^[f].oy:=vec^[f].y;
		 putseg2_rev(vec^[f].x,vec^[f].y,16,16,bloing+anx[vec^[f].obr],13,anim^);
		end else
		if (freez_time=0) then putseg2_rev_mix(vec^[f].x,vec^[f].y,16,16,bloing+anx[vec^[f].obr],13,anim^,0,vec^[f].zas)
             else if (vec^[f].meno[3]<>'S') then
               putseg2_rev_mix(vec^[f].x,vec^[f].y,16,16,bloing+anx[vec^[f].obr],13,anim^,0,vec^[f].zas)
	     end else
	     if vec^[f].change then begin
		putseg2(vec^[f].x,vec^[f].y,16,16,bloing+anx[vec^[f].obr],13,anim^);
		vec^[f].ox:=vec^[f].x;
		vec^[f].oy:=vec^[f].y;
	     end else
		if (freez_time=0) then putseg2_mix(vec^[f].x,vec^[f].y,16,16,bloing+anx[vec^[f].obr],13,anim^,0,vec^[f].zas)
               else if (vec^[f].meno[3]<>'S') then
                 putseg2_mix(vec^[f].x,vec^[f].y,16,16,bloing+anx[vec^[f].obr],13,anim^,0,vec^[f].zas)
	    end else
	    if (vec^[f].change) and (vec^[f].mie=miestnost)then begin
	     vec^[f].ox:=vec^[f].x;
	     vec^[f].oy:=vec^[f].y;
	     putseg2xms(handles[4],vec^[f].x,vec^[f].y,16,16,vec^[f].obr,13);
	    end else
	    if (vec^[f].mie=miestnost) and (vec^[f].change){ and (not (vec^[f].meno[1]='Z'))} and (st.stav=2) then
	     putseg2xms(handles[4],vec^[f].x,vec^[f].y,16,16,vec^[f].obr,13);
	  end;
	end;
    if shut_down_siriel then begin
       init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^);
    end;
end;

procedure process_all2(shut_down_siriel:boolean);
var f     : word;
begin
          for f:=1 to nahrane_veci do begin
              if vec^[f].meno[3]='S' then vec^[f].change:=false;
          end;
          process_all(shut_down_siriel);
end;


begin
end.