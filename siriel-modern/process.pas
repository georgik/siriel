unit process;

{$mode objfpc}{$H+}

{ Modern Sprite Rendering System
  Port of original PROCESS.PAS
  Handles all sprite rendering with transparency and layering
}

interface

uses
  aktiv35,
  geo,
  animing;

{ Main sprite rendering procedure
  Renders all visible sprites with proper transparency and layering
  shut_down_siriel: If true, redraw player character after rendering
}
procedure process_all(shut_down_siriel: boolean);

{ Variant that skips 'S' type sprites during freeze mode
  Used when freeze_time is active
}
procedure process_all2(shut_down_siriel: boolean);

implementation

{ === MAIN SPRITE RENDERING === }

procedure process_all(shut_down_siriel: boolean);
var
  f: word;
begin
  { Step 1: Restore backgrounds for sprites that moved }
  { This puts back the original screen data before the sprite moved }
  for f := 1 to nahrane_veci do
  begin
    if (vec^[f].change) and (vec^[f].mie = miestnost) then
    begin
      putseg(vec^[f].ox, vec^[f].oy, 16, 16, 0, vec^[f].zas);
    end;
  end;

  { Step 2: Handle fireball return logic }
  { Check if fireballs (funk=15 or 18) need to return to original position }
  for f := 1 to nahrane_veci do
  begin
    if ((vec^[f].funk = 15) or (vec^[f].funk = 18)) and (freez_time = 0) then
    begin
      case vec^[f].inf1 of
        1, 2: if (vec^[f].x = vec^[f].oox) then vec^[f].change := true;
        3, 4: if (vec^[f].y = vec^[f].ooy) then vec^[f].change := true;
      end;
    end;

    { Save background for sprites that will be drawn }
    if (vec^[f].change) and (vec^[f].mie = miestnost) and (vec^[f].visible) then
    begin
      getseg(vec^[f].x, vec^[f].y, 16, 16, 0, vec^[f].zas);
    end;
  end;

  { Step 3: Render all visible sprites }
  for f := 1 to nahrane_veci do
  begin
    if vec^[f].visible then
    begin
      { Type 1: Animated sprites (meno[2] = 'A') }
      if (vec^[f].meno[2] = 'A') and (vec^[f].mie = miestnost) then
      begin
        if vec^[f].useanim then
        begin
          { Full animation with frame updates }
          if vec^[f].change then
          begin
            vec^[f].ox := vec^[f].x;
            vec^[f].oy := vec^[f].y;
            putseg2(vec^[f].x, vec^[f].y, 16, 16, anic + anx[vec^[f].obr], 13, anim^);
          end
          else
          begin
            { Mix with background (transparency) }
            if (freez_time = 0) then
              putseg2_mix(vec^[f].x, vec^[f].y, 16, 16, anic + anx[vec^[f].obr], 13, anim^, 0, vec^[f].zas)
            else if (vec^[f].meno[3] <> 'S') then
              putseg2_mix(vec^[f].x, vec^[f].y, 16, 16, anic + anx[vec^[f].obr], 13, anim^, 0, vec^[f].zas);
          end;
        end
        else
        begin
          { Directional sprites (smer = true for left-facing) }
          if vec^[f].smer then
          begin
            if vec^[f].change then
            begin
              vec^[f].ox := vec^[f].x;
              vec^[f].oy := vec^[f].y;
              putseg2_rev(vec^[f].x, vec^[f].y, 16, 16, bloing + anx[vec^[f].obr], 13, anim^);
            end
            else
            begin
              if (freez_time = 0) then
                putseg2_rev_mix(vec^[f].x, vec^[f].y, 16, 16, bloing + anx[vec^[f].obr], 13, anim^, 0, vec^[f].zas)
              else if (vec^[f].meno[3] <> 'S') then
                putseg2_rev_mix(vec^[f].x, vec^[f].y, 16, 16, bloing + anx[vec^[f].obr], 13, anim^, 0, vec^[f].zas);
            end;
          end
          else
          begin
            { Normal direction sprites }
            if vec^[f].change then
            begin
              putseg2(vec^[f].x, vec^[f].y, 16, 16, bloing + anx[vec^[f].obr], 13, anim^);
              vec^[f].ox := vec^[f].x;
              vec^[f].oy := vec^[f].y;
            end
            else
            begin
              if (freez_time = 0) then
                putseg2_mix(vec^[f].x, vec^[f].y, 16, 16, bloing + anx[vec^[f].obr], 13, anim^, 0, vec^[f].zas)
              else if (vec^[f].meno[3] <> 'S') then
                putseg2_mix(vec^[f].x, vec^[f].y, 16, 16, bloing + anx[vec^[f].obr], 13, anim^, 0, vec^[f].zas);
            end;
          end;
        end;
      end
      else
      begin
        { Type 2: Static sprites from XMS (handle[4]) }
        if (vec^[f].change) and (vec^[f].mie = miestnost) then
        begin
          vec^[f].ox := vec^[f].x;
          vec^[f].oy := vec^[f].y;
          putseg2xms(handles[4], vec^[f].x, vec^[f].y, 16, 16, vec^[f].obr, 13);
        end
        else
        begin
          { Special case for maze mode (stav = 2) }
          if (vec^[f].mie = miestnost) and (vec^[f].change) and (st.stav = 2) then
            putseg2xms(handles[4], vec^[f].x, vec^[f].y, 16, 16, vec^[f].obr, 13);
        end;
      end;
    end;
  end;

  { Step 4: Redraw player character if needed }
  { This ensures the player appears on top of all other sprites }
  if shut_down_siriel then
  begin
    init_charakter(resx, resy, si.x + px, si.y + py, poloha, si.buf, ar^);
  end;
end;

{ === FREEZE MODE VARIANT === }

procedure process_all2(shut_down_siriel: boolean);
var
  f: word;
begin
  { Skip 'S' type sprites during freeze mode }
  for f := 1 to nahrane_veci do
  begin
    if vec^[f].meno[3] = 'S' then
      vec^[f].change := false;
  end;

  { Call main rendering procedure }
  process_all(shut_down_siriel);
end;

{ === INITIALIZATION === }

var
  initialization_done: boolean = False;

procedure InitProcess;
begin
  if initialization_done then
    exit;

  initialization_done := True;
  writeln('PROCESS: Sprite rendering system initialized');
end;

initialization
  InitProcess;

finalization
  { Final cleanup }

end.
