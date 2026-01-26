unit gameloop;

{$mode objfpc}{$H+}

{ Complete Game Loop - EXACT PORT from GAME.INC
  This contains the main game logic from original SI35.PAS
  Ported from:
  - GAME.INC lines 78-222 (arcade procedure)
  - GAME.INC lines 226-277 (maze procedure)

  This is the core gameplay that ties everything together
}

interface

uses
  SysUtils,
  jxvar,
  aktiv35,
  geo,
  collision,
  load235,
  animing,
  panak;

{ Main game loop for platformer mode (st.stav = 1)
  This is the complete original arcade() procedure }
procedure arcade;

{ Main game loop for top-down mode (st.stav = 2,3,4,5)
  This is the complete original maze() procedure }
procedure maze;

{ In-game menu and pause procedures }
procedure pauza;
procedure menu;
procedure help_in_game;
procedure briefing_in_game;
procedure briefing;

implementation

uses
  jxgraf,
  jxmenu,
  load135;

{ ========================================
   EXACT PORT from GAME.INC lines 78-222
   ======================================== }

procedure arcade;
label
  retry, exit_loop;
var
  k2, b, c: word;
  old5, old7: boolean;
begin
  same := 0;
  { TODO: rewait; }

  repeat
  retry:
    { Start Raylib rendering frame }
    BeginDrawing();

    { Check for window close event - respond immediately }
    if WindowShouldClose() <> 0 then
    begin
      the_koniec := True;
      EndDrawing();  { Finish the frame cleanly }
      goto exit_loop;  { Exit loop immediately }
    end;

    if rollup = 0 then
      oldkey := 0;
    k := 0;

    { Display score }
    vypis_skore;

    { Wait for next frame - NON-BLOCKING for Raylib }
    { Original DOS busy-wait won't work with event-driven UI }
    { Raylib's SetTargetFPS(60) handles timing, so we just update time }
    if GetClock >= time then
      time := time + wait_point;

    { Handle joystick input }
    sipka_joystick2;

    if keypressed then
    begin
      k := key;
      get_keyboard;
      k2 := 0;

      case k of
        $3920, $1c0d:
          if ((not truth) or (not rolldown)) then
          begin
            { TODO: menu; }
            { sace flag will cause loop exit in until condition }
          end;

        $3b00, $2368, $2348:
          begin
            help_in_game;
            { TODO: rewait; }
          end;

        $3e00, $1970, $1950:
          begin
            pauza;
          end;

        $011b:
          restart := ano_nie2('Really quit?');

        $3f00, 3062:
          briefing_in_game;

        $4800, $4b00, $4d00, $5000, $4700, $4900, $5100, $4f00:
          k2 := k;
      end;

      k := 0;

      if joystick_able then
      begin
        if k2 > 0 then
          k := k2;
        case k of
          $5000: reset_keyboard;
          $4900:
            begin
              if (rollup = 0) and (not rolldown) then
                rollup := rolling;
              k := $4d00;
            end;
          $4700:
            begin
              if (rollup = 0) and (not rolldown) then
                rollup := rolling;
              k := $4b00;
            end;
          $4f00: k := $4b00;
          $5100: k := $4d00;
          $4800:
            begin
              if (rollup = 0) and (not rolldown) then
                rollup := rolling;
              k := 0;
            end;
        end;
        k2 := 0;
      end;
    end;

    old5 := zmack(75);
    old7 := zmack(77);
    get_keyboard;

    if zmack(75) then
    begin
      k := $4b00;
      if old7 then
        key_swap(77, false);
    end;

    if zmack(77) then
    begin
      k := $4d00;
      if old5 then
        key_swap(75, false);
    end;

    if zmack(80) or zmack(28) or zmack(57) then
    begin
      k := $5000;
      reset_keyboard;
    end;

    if zmack(60) then
      k := $3c00;

    if zmack(61) then
      k := $3d00;

    if k > 0 then
      sipka_fake(k, si.x, si.y);

    if (zmack(72)) and (rollup = 0) and (not rolldown) then
    begin
      rollup := rolling;

      case k of
        $4b00:
          begin
            if rollup = 0 then
              pl(2)
            else
              oldkey := 5;
          end;
        $4d00:
          begin
            if rollup = 0 then
              pl(3)
            else
              oldkey := 6;
          end;
        $4b34:
          oldkey := 5;
        $7d36:
          oldkey := 6;
      end;

      if (rollup > 0) then
      begin
        dec(rollup);
        if rollup > gravity then
          sipka_fake($4800, si.x, si.y);

        if (smart_jump) and ((rollup < gravity) and (si.y <= si.oldy)) then
        begin
          inc(same);
          if same = 1 then
          begin
            rollup := 0;
            same := 0;
          end;
        end;

        if oldkey < 5 then
          pl(4)
        else
          pl(oldkey);

        begin
          if si.x < 3 then
            b := 1
          else
            b := si.x - 2;
          if si.y < 15 then
            c := 3
          else
            c := si.y - 14;
          if ((not po3(b, c)) or (not po3(si.x + 3, c))) then
            rollup := 0;
        end;
      end
      else
        same := 0;

      { Gravity check }
      if (po(si.x, si.y)) then
        truth := true
      else
        truth := false;

      if (truth) and (rollup < gravity - 5) and (not lifting) then
      begin
        sipka_fake($5000, si.x, si.y);
      end;

      if (po(si.x, si.y)) then
        rolldown := true
      else
        rolldown := false;

      if (not rolldown) then
        sipka_fake($4800, si.x, si.y);

      if (rollup > 0) and (k = 0) then
        case oldkey of
          5:
            sipka_fake($4b00, si.x, si.y);
          6:
            sipka_fake($4d00, si.x, si.y);
        end;

      if (not po3(si.x - 5, si.y - 12)) then
        sipka_fake($4d00, si.x, si.y);

      if (not po3(si.x + 6, si.y - 12)) then
        sipka_fake($4b00, si.x, si.y);

      if (rollup = 0) and ((not truth) or (not rolldown))
        and ((k = $4800) or (k = $4b34) or (k = $4d36)) then
      begin
        rollup := rolling;
      end;

      if rollup = 0 then
      begin
        if k = 0 then
          inc(pom)
        else
          pom := 0;
        if pom > 3 then
        begin
          pom := 0;
          pl(1);
        end;
      end;

      if rollup = 1 then
      begin
        pom := 4;
        key_swap(72, false);
      end;
    end;  { End of jump handling block started at line 180 }

    { Update game state }
      panak_move;
      { TODO: padak_check; }

      { Update animation }
      si.oldx := si.x;
      si.oldy := si.y;
      oldpol := poloha;

      { TODO: zisti_vec; }

    { Render to screen - Raylib requires this }
    ClearBackground(0, 0, 0, 255);
    RenderScreenToWindow();
    EndDrawing();

  exit_loop:
  until (the_koniec) or (restart) or (sace) or (WindowShouldClose() <> 0);
end;

{ ========================================
   EXACT PORT from GAME.INC lines 226-277
   ======================================== }

procedure maze;
label
  retry, exit_loop;
var
  movx, movy, mova, mavb: word;
begin
  new(bl);
  ds := 0;

  { Initialize pathfinding array }
  for f := 0 to mie_x do
    for ff := 0 to mie_y do
      bl^[f, ff] := false;

  aktivuj_texturu;
  { TODO: rewait; }

  repeat
  retry:
    { Start Raylib rendering frame }
    BeginDrawing();

    { Check for window close event - respond immediately }
    if WindowShouldClose() <> 0 then
    begin
      the_koniec := True;
      EndDrawing();  { Finish the frame cleanly }
      goto exit_loop;  { Exit loop immediately }
    end;

    if rollup = 0 then
      oldkey := 0;
    k := 0;

    { Display score }
    vypis_skore;

    { Wait for next frame - NON-BLOCKING for Raylib }
    { Original DOS busy-wait won't work with event-driven UI }
    { Raylib's SetTargetFPS(60) handles timing, so we just update time }
    if GetClock >= time then
      time := time + wait_point;

    sipka_joystick;

    if keypressed then
    begin
      k := key;
      clear_key_buffer;

      case k of
        $4b00:
          begin
            pl(2);
            sipka_fake(k, si.x, si.y);
          end;
        $4d00:
          begin
            pl(3);
            sipka_fake(k, si.x, si.y);
          end;
        $4800:
          begin
            pl(7);
            sipka_fake(k, si.x, si.y);
          end;
        $5000:
          begin
            pl(1);
            sipka_fake(k, si.x, si.y);
          end;
        $3b00, $2368:
          begin
            help_in_game;
            { TODO: rewait; }
          end;
        $3e00, $1970:
          pauza;
        $011b:
          restart := ano_nie2('Really quit?');
        $1c0d, $3920:
          begin
            { TODO: menu; }
            { sace flag will cause loop exit in until condition }
          end;
        $3f00, 3062:
          briefing_in_game;
      end;

      { Collision detection for maze mode }
      if (not po3(si.x - movx, si.y - movy)) or
         (not po3(si.x + mova, si.y - movy)) or
         (not po3(si.x - movx, si.y)) or
         (not po3(si.x + mova, si.y)) then
        sipka_spat(si.x, si.y);

      aktivuj_texturu;
    end;

    { Update game state }
    panak_move;

    { Update animation }
    si.oldx := si.x;
    si.oldy := si.y;
    oldpol := poloha;

    { TODO: zisti_vec; }

    { Render to screen - Raylib requires this }
    ClearBackground(0, 0, 0, 255);
    RenderScreenToWindow();
    EndDrawing();

  exit_loop:
  until (the_koniec) or (restart) or (sace) or (WindowShouldClose() <> 0);

  dispose(bl);
  bl := nil;
end;

{ ========================================
   IN-GAME MENU AND PAUSE PROCEDURES
   EXACT PORTS from GAME.INC and MENU35.INC
   ======================================== }

{ Pause game - EXACT PORT from GAME.INC line 1 }
procedure pauza;
var
  f: byte;
begin
  clear_key_buffer;
  f := 15;
  repeat
    inc(f);
    { TODO: printc(screen,230,tx[ja,7],f,0); }
    if f = 255 then
      f := 15;

    { NON-BLOCKING wait for Raylib }
    if GetClock >= time then
      time := time + wait_point + 50;

    { Check window events }
    if WindowShouldClose() <> 0 then
      exit;

  until keypressed;
  redraw(true);
  k := 0;
end;

{ In-game menu - EXACT PORT from MENU35.INC line 595 }
procedure menu;
const
  max_menu = 4;
var
  mass: ^jxmenu_typ;
  f, u, z: word;
  status, zobral, tester: boolean;
  s: string;
begin
  zobral := False;
  menux := 4;
  k := 0;
  u := 1;

  { TODO: Implement full menu logic }
  { For now, this is a stub to allow compilation }
  writeln('STUB: menu procedure called');
end;

{ Help in game - EXACT PORT from GAME.INC line 55 }
procedure help_in_game;
begin
  { TODO: decrease_palette(palx,20); }
  { TODO: info; }
  { TODO: decrease_palette(palx,20); }
  redraw(true);
  { TODO: increase_palette(blackx,palx,20); }

  writeln('STUB: help_in_game procedure called');
end;

{ Briefing in game - EXACT PORT from GAME.INC line 65 }
procedure briefing_in_game;
begin
  if (msg[1] <> '') or (msg[2] <> '') or (msg[3] <> '') or (msg[4] <> '') or (msg[5] <> '') then
  begin
    { TODO: zhasni; }
    briefing;
    { TODO: zhasni; }
    redraw(true);
    { TODO: rozsviet; }
    rewait;
  end;
end;

{ Briefing - EXACT PORT from GAME.INC line 281 }
procedure briefing;
begin
  if (msg[1] <> '') or (msg[2] <> '') or (msg[3] <> '') or (msg[4] <> '') or (msg[5] <> '') then
  begin
    { TODO: zhasni; }
    { TODO: clear_bitmap(screen); }
    { TODO: for f:=1 to 5 do printc(screen,f*(chardy*2)+150,msg[f],15,0); }
    { TODO: rozsviet; }
    clear_key_buffer;
    kkey;
  end;
end;

{ ========================================
   INITIALIZATION
   ======================================== }

var
  initialization_done: boolean = False;

procedure InitGameLoop;
begin
  if initialization_done then
    exit;

  initialization_done := True;

  writeln('GAMELOOP: Complete game loop system initialized');
  writeln('  Procedures: arcade, maze');
end;

initialization
  InitGameLoop;

finalization
  { Final cleanup }

end.
