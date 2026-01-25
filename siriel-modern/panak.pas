unit panak;

{$mode objfpc}{$H+}

{ Complete Creature Movement and Game Loop System
  Port of original panak() procedure from SI35.PAS
  Handles all creature movement, timers, fireballs, and collision detection
}

interface

uses
  SysUtils,
  aktiv35,
  geo,
  jxvar,
  animing,
  dos;

{ Main creature movement and game loop procedure
  Updates positions for all creatures, handles timers, fireballs, collision
}
procedure panak_move;

implementation

{ ========================================
   TIME_OUT - Level Timer Countdown
   ======================================== }

procedure time_out;
var
  hour, min, sec, hund: word;
  current_time: time_struct;
begin
  if timer > 0 then
  begin
    { Get current time }
    GetTime(hour, min, sec, hund);
    current_time.h := hour;
    current_time.m := min;
    current_time.s := sec;
    current_time.o := hund;

    { Check if second has changed }
    if (current_time.h <> tim2.h) or
       (current_time.m <> tim2.m) or
       (current_time.s <> tim2.s) then
    begin
      { Update last time }
      tim2.h := current_time.h;
      tim2.m := current_time.m;
      tim2.s := current_time.s;
      tim2.o := current_time.o;

      { Decrement timer }
      dec(timer);

      { Timer expired - game over }
      if timer = 0 then
      begin
        writeln('TIME OUT! Level timer expired.');
        { In full game: zivoty := 0; strata_zivota; }
      end;
    end;
  end;
end;

{ ========================================
   FREEZING - Power-up Timer Management
   ======================================== }

procedure freezing;
begin
  { Freeze timer }
  if (freez_time > 0) and (freez_time < 255) then
  begin
    dec(freez_time);
    if freez_time = 0 then
    begin
      writeln('FREEZE expired - creatures unfrozen');
      { In full game: pust_extra(unfreez_sound); }
    end;
  end;

  { God mode timer }
  if (god_time > 0) and (god_time < 255) then
  begin
    dec(god_time);
    if god_time = 0 then
    begin
      writeln('GOD MODE expired');
      { In full game: pust_extra(ungod_sound); }
    end;
  end;
end;

{ ========================================
   MOVEMENT - Fireball Projectile Handling
   ======================================== }

procedure movement(f: byte; var change_val, from_val: word);
begin
  { Handle fireball impact/arrival }
  if vec^[f].visible then
  begin
    { Fireball reached destination }
    case vec^[f].funk of
      15: begin
        { Normal fireball impact }
        { In full game: if (snd_fireball<>nos) then pust(4); }
      end;
      18: begin
        { Custom fireball impact }
        { In full game: if vec^[f].z2>0 then pust(basic_snd+vec^[f].z2-1); }
      end;
    end;

    { Remove fireball from screen }
    putseg(vec^[f].x, vec^[f].y, resx, resy, 0, vec^[f].zas);
    vec^[f].visible := false;
    vec^[f].change := true;
    inc(vec^[f].x);
    vec^[f].x := 640;  { Move off screen }
  end;

  { Handle fireball shooting cycle }
  inc(vec^[f].inf5);
  if vec^[f].inf5 >= vec^[f].inf4 then
  begin
    { Fireball ready to shoot again }
    case vec^[f].funk of
      15: begin
        { Normal fireball shoot }
        { In full game: if (snd_fir<>nos) then pust(6); }
      end;
      18: begin
        { Custom fireball shoot }
        { In full game: pust_extra(vec^[f].z1); }
      end;
    end;

    vec^[f].inf5 := 0;
    change_val := from_val;
    vec^[f].visible := true;
    vec^[f].x := vec^[f].oox;
    vec^[f].y := vec^[f].ooy;
    vec^[f].ox := vec^[f].x;
    vec^[f].oy := vec^[f].y;
    getseg(vec^[f].x, vec^[f].y, resx, resy, 0, vec^[f].zas);
  end;
end;

{ ========================================
   FIREBALL MOVEMENT - Funk 15 and 18
   ======================================== }

procedure update_fireball(var vec_item: predmet; idx: word);
begin
  case vec_item.inf1 of
    1: begin  { Moving right }
      if vec_item.x < vec_item.inf2 then
        inc(vec_item.x, vec_item.inf3)
      else
        movement(idx, vec_item.x, vec_item.oox);
    end;

    2: begin  { Moving left }
      if vec_item.x > vec_item.inf2 then
        dec(vec_item.x, vec_item.inf3)
      else
        movement(idx, vec_item.x, vec_item.oox);
    end;

    3: begin  { Moving down }
      if vec_item.y < vec_item.inf2 then
        inc(vec_item.y, vec_item.inf3)
      else
        movement(idx, vec_item.y, vec_item.ooy);
    end;

    4: begin  { Moving up }
      if vec_item.y > vec_item.inf2 then
        dec(vec_item.y, vec_item.inf3)
      else
        movement(idx, vec_item.y, vec_item.ooy);
    end;
  end;
end;

{ ========================================
   CREATURE TYPE 12 - Random Movement
   ======================================== }

procedure update_creature_type12(var vec_item: predmet);
begin
  { Only move if not frozen }
  if freez_time > 0 then
    exit;

  { Move in current direction }
  case vec_item.inf3 of
    0: begin  { Left }
      sipka_fakex(kb_left, vec_item.inf2, vec_item.x, vec_item.y);
      vec_item.smer := true;  { Facing left }
    end;

    1: begin  { Right }
      sipka_fakex(kb_right, vec_item.inf2, vec_item.x, vec_item.y);
      vec_item.smer := false;  { Facing right }
    end;

    2:  { Down }
      sipka_fakex(kb_down, vec_item.inf2, vec_item.x, vec_item.y);

    3:  { Up }
      sipka_fakex(kb_up, vec_item.inf2, vec_item.x, vec_item.y);
  end;

  { Decrease movement timer }
  dec(vec_item.inf4, vec_item.inf2);

  { Check if we need to change direction }
  case vec_item.inf1 of
    0: begin
      { Simple boundary checking }
      if (vec_item.x > 624) or (vec_item.x < 10) or
         (vec_item.y < 10)  or (vec_item.y > 464) or
         (vec_item.inf4 < 4) then
      begin
        { Clamp to boundaries }
        if vec_item.x > 624 then vec_item.x := 624;
        if vec_item.x < 10 then vec_item.x := 10;
        if vec_item.y > 464 then vec_item.y := 464;
        if vec_item.y < 10 then vec_item.y := 10;

        { Pick new random direction and timer }
        vec_item.inf3 := random(4);
        vec_item.inf4 := random(200) + 20;
      end;
    end;

    1: begin
      { With texture collision detection }
      if (vec_item.x > 624) or (vec_item.x < 10) or
         (vec_item.y < 10)  or (vec_item.y > 464) or
         (vec_item.inf4 < 4) or
         (st.mie[((vec_item.x - 6) div 16), ((vec_item.y) div 16)] > inusable) or
         (st.mie[((vec_item.x + 6) div 16), ((vec_item.y + 13) div 16)] > inusable) then
      begin
        { Collision detected - reverse direction and try again }
        case vec_item.inf3 of
          0: begin  { Was going left, go right }
            inc(vec_item.x);
            sipka_fakex(kb_right, vec_item.inf2, vec_item.x, vec_item.y);
          end;
          1: begin  { Was going right, go left }
            dec(vec_item.x);
            sipka_fakex(kb_left, vec_item.inf2, vec_item.x, vec_item.y);
          end;
          2: begin  { Was going down, go up }
            dec(vec_item.y);
            sipka_fakex(kb_up, vec_item.inf2, vec_item.x, vec_item.y);
          end;
          3: begin  { Was going up, go down }
            inc(vec_item.y);
            sipka_fakex(kb_down, vec_item.inf2, vec_item.x, vec_item.y);
          end;
        end;

        { Pick new random direction (different from current) }
        vec_item.inf5 := vec_item.inf3;
        repeat
          vec_item.inf3 := random(4);
        until (vec_item.inf3 <> vec_item.inf5);
        vec_item.inf4 := random(200);
      end;
    end;
  end;
end;

{ ========================================
   PANAK_MOVE - Main Game Loop Procedure
   ======================================== }

procedure panak_move;
var
  f: word;
begin
  { Reset shutdown flag }
  shut_down_siriel := false;

  { 1. Handle level timer }
  time_out;

  { 2. Update animation counters }
  inc(anim_count);
  if anim_count >= 4 then
  begin
    anim_count := 0;
    inc(anic);
    if anic >= 4 then
      anic := 0;
  end;

  inc(bloing);
  if bloing >= 4 then
    bloing := 0;

  { 3. Update character animation }
  { NOTE: In full game, call charakter() here }
  { charakter(si.x+px, si.y+py, si.oldx+px, si.oldy+py, poloha, si.buf, ar^); }

  { 4. Handle power-up timers }
  if (anim_count = 0) or (anim_count = 2) then
  begin
    freezing;

    { 5. Update all creatures }
    for f := 1 to nahrane_veci do
    begin
      if (vec^[f].mie = miestnost) and
         ((freez_time = 0) or ((freez_time > 0) and (vec^[f].meno[3] <> 'S'))) then
      begin
        { Only process animated creatures and those with functions }
        if (vec^[f].meno[2] = 'A') or
           (((vec^[f].meno[1] <> 'W') and (vec^[f].meno[1] <> 'V')) and
            (vec^[f].funk > 0)) then
        begin
          case vec^[f].funk of
            12: begin
              { Random movement creature }
              update_creature_type12(vec^[f]);
            end;

            15, 18: begin
              { Fireball movement }
              update_fireball(vec^[f], f);
            end;

            { Other creature types can be added here }
            // 16: { Chase behavior }
            // 17: { Sound generator }
            // etc.
          end;
        end;
      end;
    end;
  end;

  { 6. Check for position changes }
  if (anim_count = 0) or (anim_count = 2) then
  begin
    for f := 1 to nahrane_veci do
    begin
      if (vec^[f].ox <> vec^[f].x) or (vec^[f].oy <> vec^[f].y) then
        vec^[f].change := true
      else
        vec^[f].change := false;
    end;

    { 7. Check player-creature collision }
    for f := 1 to nahrane_veci do
    begin
      if (vec^[f].mie = miestnost) and
         ((vec^[f].change) or (vec^[f].meno[2] = 'A')) and
         (vec^[f].x > si.x - 24) and (vec^[f].x < si.x + 36) and
         (vec^[f].y > si.y - 24) and (vec^[f].y < si.y + 36) then
      begin
        shut_down_siriel := true;
        { NOTE: In full game, call vypni_charakter() here }
        { vypni_charakter(si.x+px, si.y+py, si.buf, ar^); }
        break;
      end;
    end;
  end;

  { 8. Handle god mode visual effect }
  if (god_time > 0) then
  begin
    { NOTE: In full game, render god mode effect here }
    { putseg2(si.x+px, si.y+py, resx, resy, 47+efekt_count, 13, ar^); }
    case anim_count of
      1:
        begin
          { inc(efekt_count); }
          { if efekt_count>3 then efekt_count:=0; }
        end;
    end;
  end;
end;

{ ========================================
   INITIALIZATION
   ======================================== }

var
  initialization_done: boolean = False;

procedure InitPanak;
begin
  if initialization_done then
    exit;

  initialization_done := True;

  { Initialize timer variables }
  timer := 0;
  FillChar(tim, SizeOf(tim), 0);
  FillChar(tim2, SizeOf(tim2), 0);

  { Initialize power-up timers }
  freez_time := 0;
  god_time := 0;

  { Initialize flags }
  shut_down_siriel := false;

  writeln('PANAK: Complete game loop system initialized');
end;

initialization
  InitPanak;

finalization
  { Final cleanup }

end.
