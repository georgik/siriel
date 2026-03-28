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
  raylib_helpers,
  load135;

const
  GAME_WIDTH = 640;    { Original game resolution width }
  GAME_HEIGHT = 480;   { Original game resolution height }

{ ========================================
   PARACHUTE - EXACT PORT from GAME.INC lines 18-53
   ======================================== }

procedure padak_init;
{ Initialize parachute sprite above avatar }
begin
  { Frames 36-39 are parachute animation frames }
  { Position: si.x+2, si.y-14 (above avatar) }
  { In Raylib version, this will be handled in rendering }
  writeln('[PARACHUTE] Initializing parachute at pos ', si.x + 2, ', ', si.y - 14);
end;

procedure padak_done;
{ Hide parachute when avatar stops falling }
begin
  writeln('[PARACHUTE] Hiding parachute');
  { Reset to standing animation }
  { In Raylib version, this will be handled in rendering }
end;

procedure padak(num: word);
{ Animate parachute - num is frame offset (1 or 2) }
begin
  { Displays parachute frame 36+num (37 or 38) }
  { In Raylib version, this will be handled in rendering }
  { writeln('[PARACHUTE] Showing parachute frame ', 36 + num); }
end;

procedure padak_check;
{ Check if avatar is falling and show/hide parachute }
begin
  if si.y > si.oldy then
  begin
    { Avatar is falling }
    if pad_pol < 20 then
    begin
      inc(pad_pol);
      case pad_pol of
        19: padak_init;
        20: padak(1);
      end;
    end
    else
    begin
      { After 20 frames of falling, show full parachute }
      padak(2);
    end;
  end
  else
  begin
    { Avatar is not falling }
    if pad_pol > 0 then
    begin
      if pad_pol > 18 then
        padak_done;
      pad_pol := 0;
    end;
  end;
end;

{ ========================================
   EXACT PORT from GAME.INC lines 78-222
   ======================================== }

procedure arcade;
var
  k2, b, c: word;
  old5, old7: boolean;
  frame_count: longint;  { For debugging - count rendered frames }
  last_log_time: longint;
  start_time, current_time: longint;
  game_render: TRaylibRenderTexture2D;  { Render texture for scaling }
  screen_scale_x, screen_scale_y: single;
  scale_rect: TRectangle;
begin
  same := 0;
  frame_count := 0;
  last_log_time := SysUtils.GetTickCount64;
  aktiv35.animation_frame_counter := 0;  { Initialize animation slowdown counter }

  { Create render texture at game resolution (GAME_WIDTHxGAME_HEIGHT) }
  writeln('arcade: Creating render texture for scaling...');
  game_render := LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT);
  writeln('arcade: Render texture created successfully');

  { Set target FPS to 60 for consistent game speed }
  SetTargetFPS(60);

  { Track test mode duration }
  start_time := SysUtils.GetTickCount64;

  writeln('arcade: Starting game loop...');
  { TODO: rewait; }

  repeat
    { Start Raylib rendering frame }
    BeginDrawing();

    { Check for window close event - respond immediately }
    if WindowShouldClose() <> 0 then
    begin
      writeln('arcade: Window close requested, exiting loop');
      the_koniec := True;
    end;

    { Check test mode duration }
    if test_mode_duration_ms > 0 then
    begin
      current_time := SysUtils.GetTickCount64;
      if (current_time - start_time) >= test_mode_duration_ms then
      begin
        writeln('arcade: Test mode duration reached, exiting loop');
        the_koniec := True;
      end;
    end;

    if rollup = 0 then
      oldkey := 0;
    k := 0;

    { Display score }
    vypis_skore;

    { Update game world rendering - ORIGINAL ENGINE APPROACH }
    { The original engine only redraws when necessary, not every frame }
    { Only redraw if player moved or state changed }
    if (si.x <> si.oldx) or (si.y <> si.oldy) or (oldpol <> poloha) then
    begin
      { Use redraw(false) for incremental updates (clears and redraws dynamic elements) }
      { This calls print_predmet2 which only redraws changed items }
      redraw(false);
    end;

    { Wait for next frame - NON-BLOCKING for Raylib }
    { Original DOS busy-wait won't work with event-driven UI }
    { Raylib's SetTargetFPS(60) handles timing, so we just update time }
    if GetClock >= time then
      time := time + wait_point;

    { Handle joystick input }
    sipka_joystick2;

    { ALWAYS update keyboard state - CRITICAL for key detection }
    get_keyboard;

    if keypressed then
    begin
      k := kkey;  { This clears key_buffer after reading - CRITICAL for proper key detection }
      k2 := 0;

      case k of
        $3920:
          begin
            writeln(' (SPACE - Action)');
            { Check for object interaction first }
            if mov > 0 then
            begin
              writeln('arcade: Interacting with object ', mov);
              use_vec(mov);
            end
            else if ((not truth) or (not rolldown)) then
            begin
              { TODO: menu; }
              { sace flag will cause loop exit in until condition }
            end;
          end;

        $1c0d:
          begin
            writeln(' (ENTER - Menu)');
            if ((not truth) or (not rolldown)) then
            begin
              { TODO: menu; }
              { sace flag will cause loop exit in until condition }
            end;
          end;

        $3b00, $2368, $2348:
          begin
            writeln(' (F1 - Help)');
            help_in_game;
            { TODO: rewait; }
          end;

        $3e00, $1970, $1950:
          begin
            writeln(' (F5/Esc - Pause)');
            pauza;
          end;

        $011b:
          begin
            writeln(' (ESC - Quit)');
            restart := ano_nie2('Really quit?');
          end;

        $5848, $5868:
          begin
            writeln(' (F11 - Toggle Fullscreen)');
            ToggleFullscreen;
          end;

        $4400:
          begin
            writeln(' (F10 - Toggle Fullscreen)');
            writeln(' Before: ', GetScreenWidth(), 'x', GetScreenHeight());
            ToggleFullscreen;
            writeln(' After: ', GetScreenWidth(), 'x', GetScreenHeight());
          end;

        $3f00, 3062:
          begin
            writeln(' (F2 - Briefing)');
            briefing_in_game;
          end;

        $4800, $4b00, $4d00, $5000, $4700, $4900, $5100, $4f00:
          begin
            { Show which arrow key was pressed }
            case k of
              $4800:
                if st.stav = 1 then
                  writeln(' (Arrow Up - JUMP in arcade mode)')
                else
                  writeln(' (Arrow Up - move up in maze mode)');
              $4b00: writeln(' (Arrow Left)');
              $4d00: writeln(' (Arrow Right)');
              $5000:
                if st.stav = 1 then
                  writeln(' (Arrow Down - ignored in arcade mode, gravity handles falling)')
                else
                  writeln(' (Arrow Down - move down in maze mode)');
              $4700: writeln(' (Home)');
              $4900: writeln(' (Page Up)');
              $5100: writeln(' (Page Down)');
              $4f00: writeln(' (End)');
            end;
            { In arcade mode, don't pass DOWN arrow to movement logic }
            { In maze mode, all arrow keys work normally }
            if (st.stav <> 1) or (k <> $5000) then
              k2 := k;
          end;

        else
          writeln(' (Unknown)');
      end;

      if joystick_able then
      begin
        { Use k2 (joystick) if set, otherwise keep k (keyboard) }
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

    { Use Raylib's native IsKeyDown() for continuous movement detection }
    { This is simpler and more reliable than the zmack() system }

    { Left/Right movement - use continuous state (both modes) }
    if IsKeyDown(KEY_LEFT) <> 0 then
      k := $4b00;

    if IsKeyDown(KEY_RIGHT) <> 0 then
      k := $4d00;

    { UP/DOWN handling - DIFFERENT for arcade vs maze mode }
    if st.stav = 1 then
    begin
      { ARCADE MODE (platformer): UP = jump, DOWN = ignored }
      { UP arrow is handled by jump logic below }
      { DOWN arrow is ignored - gravity handles falling }
      { No additional key processing needed here }
    end
    else
    begin
      { MAZE MODE (top-down): UP/DOWN move in those directions }
      if IsKeyDown(KEY_UP) <> 0 then
        k := $4800;

      if IsKeyDown(KEY_DOWN) <> 0 then
        k := $5000;
    end;

    if zmack(60) then
      k := $3c00;

    if zmack(61) then
      k := $3d00;

    { Process movement keys - DIFFERENT for arcade vs maze mode }
    if st.stav = 1 then
    begin
      { ARCADE MODE: Only LEFT/RIGHT movement }
      { UP triggers jump (handled below), DOWN is ignored }
      if (k = $4b00) or (k = $4d00) then
        sipka_fake(k, si.x, si.y);
    end
    else
    begin
      { MAZE MODE: All 4 directions work }
      if (k = $4800) or (k = $4b00) or (k = $4d00) or (k = $5000) then
        sipka_fake(k, si.x, si.y);
    end;

    { Jump handling - ONLY for arcade mode }
    if (st.stav = 1) and ((zmack(72)) or (IsKeyDown(KEY_UP) <> 0)) and (rollup = 0) and (not rolldown) then
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

        { ========================================
           JUMP ANIMATION - EXACT PORT from GAME.INC line 168-169
           ======================================== }
        if oldkey < 5 then
          pl(4)    { Jump straight up }
        else
          pl(oldkey);  { oldkey=5 → pl(5) jump up left, oldkey=6 → pl(6) jump up right }

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

      { Diagonal jumping - if jumping and no key pressed, continue diagonal }
      if (rollup > 0) and (k = 0) then
        case oldkey of
          5:
            sipka_fake($4b00, si.x, si.y);
          6:
            sipka_fake($4d00, si.x, si.y);
        end;

      { Collision detection above - push away from walls }
      if (not po3(si.x - 5, si.y - 12)) then
        sipka_fake($4d00, si.x, si.y);

      if (not po3(si.x + 6, si.y - 12)) then
        sipka_fake($4b00, si.x, si.y);

      { Auto-jump when walking off platforms }
      if (rollup = 0) and ((not truth) or (not rolldown))
        and ((k = $4800) or (k = $4b34) or (k = $4d36)) then
      begin
        rollup := rolling;
      end;

      if rollup = 1 then
      begin
        pom := 4;
        key_swap(72, false);
      end;
    end;  { End of jump handling block started at line 284 }

    { ========================================
       GRAVITY - EXACT PORT from GAME.INC lines 178-189
       This must be OUTSIDE the jump handling block!
       ======================================== }

    { Check if avatar is on solid ground }
    if (po(si.x, si.y)) then
      truth := true
    else
      truth := false;

    { If not on ground and not jumping high enough, fall down }
    if (truth) and (rollup < gravity - 5) and (not lifting) then
    begin
      sipka_fake($5000, si.x, si.y);
    end;

    { Update rolldown flag }
    if (po(si.x, si.y)) then
      rolldown := true
    else
      rolldown := false;

    { If not falling down, move up (hover/jump) }
    if (not rolldown) then
      sipka_fake($4800, si.x, si.y);

    { ========================================
       END GRAVITY SECTION
       ======================================== }

    { Ground movement animation - handle left/right when not jumping }
    if rollup = 0 then
    begin
      case k of
        $4b00: pl(2);  { Left arrow - use left animation frames 4-7 }
        $4d00: pl(3);  { Right arrow - use right animation frames 8-11 }
      end;
    end;

    { Idle animation logic - OUTSIDE jump handling, like original DOS code }
    if rollup = 0 then
    begin
      if k = 0 then
      begin
        { No keys pressed - reset to idle animation if needed }
        { If poloha is not in idle range (0-3), reset it immediately }
        if poloha > 3 then
          poloha := 0;

        { Slow down animation updates: original DOS was ~4 FPS, we're 60 FPS }
        { Only increment pom every 15 frames (60/15 = 4 FPS to match original) }
        inc(aktiv35.animation_frame_counter);
        if aktiv35.animation_frame_counter >= 15 then
        begin
          aktiv35.animation_frame_counter := 0;
          inc(pom);
        end;
      end
      else
      begin
        { Keys are pressed - reset idle animation counter }
        pom := 0;
        aktiv35.animation_frame_counter := 0;
      end;
      if pom > 3 then
      begin
        pom := 0;
        pl(1);
      end;
    end;

    { Update game state }
      panak_move;
      padak_check;  { Check if parachute should be shown }

      { Update animation }
      si.oldx := si.x;
      si.oldy := si.y;
      oldpol := poloha;

      { Check for object collision }
      zisti_vec;

      { Auto-pickup for funk=0 items (pickup items) }
      if (mov > 0) and (vec^[mov].funk = 0) then
      begin
        use_vec(mov);
      end;

    { Increment frame counter }
    inc(frame_count);

    { Log heartbeat every 60 frames (1 second at 60 FPS) }
    if (frame_count mod 60) = 0 then
    begin
      writeln('arcade: Frame ', frame_count, ' - Player at (', si.x, ', ', si.y, ') - Timer: ', timer, 's');
    end;

    { Render to screen - Raylib requires this }
    ClearBackground(0, 0, 0, 255);

    { Render game to texture first (for scaling) }
    BeginTextureMode(game_render);

    { Clear background of render texture }
    raylib_helpers.ClearBackground(0, 0, 0, 255);

    { Render map tiles using GPU textures (if available) }
    load235.RenderMapTiles();

    { Render objects using GPU textures }
    load235.DrawAllObjects(frame_count);

    { Render player avatar using GPU textures }
    { si.x and si.y are already in pixel coordinates (not tile coordinates) }
    { Just apply small offset like in menu (px=4, py=2 in original, converted to pixels) }
    { Debug: Log avatar rendering every 60 frames }
    if (frame_count mod 60) = 0 then
      writeln('arcade: Rendering avatar at (', si.x + 4, ', ', si.y + 2, ') frame=', poloha);
    jxmenu.RenderAvatarAt(si.x + 4, si.y + 2, poloha);

    { Only render screen_image if NOT using GPU tile rendering }
    { TODO: Eventually need to render UI elements directly with Raylib }
    if not load235.map_tiles_loaded then
      RenderScreenToWindow();

    EndTextureMode();

    { Calculate scaled rectangle to fit window while maintaining aspect ratio }
    { Get current window size }
    screen_scale_x := GetScreenWidth() / GAME_WIDTH;
    screen_scale_y := GetScreenHeight() / GAME_HEIGHT;

    { Use the smaller scale to fit entirely within the window }
    if screen_scale_x < screen_scale_y then
      screen_scale_y := screen_scale_x
    else
      screen_scale_x := screen_scale_y;

    { Calculate centered position }
    scale_rect.x := (GetScreenWidth() - Trunc(GAME_WIDTH * screen_scale_x)) div 2;
    scale_rect.y := (GetScreenHeight() - Trunc(GAME_HEIGHT * screen_scale_y)) div 2;
    scale_rect.width := Trunc(GAME_WIDTH * screen_scale_x);
    scale_rect.height := Trunc(GAME_HEIGHT * screen_scale_y);

    { Debug: Log window size and scale every 60 frames (1 second) }
    if (frame_count mod 60) = 0 then
    begin
      writeln('arcade: Window size: ', GetScreenWidth(), 'x', GetScreenHeight());
      writeln('arcade: Scale factors: x=', screen_scale_x:0:2, ' y=', screen_scale_y:0:2);
      writeln('arcade: Dest rect: x=', scale_rect.x:0:0, ' y=', scale_rect.y:0:0, ' w=', scale_rect.width:0:0, ' h=', scale_rect.height:0:0);
    end;

    { Draw the scaled texture (pixelated filtering) }
    { Source rectangle (entire texture) - negative height to flip render texture }
    DrawTexturePro(game_render.texture,
                   RectangleCreate(0, 0, GAME_WIDTH, -GAME_HEIGHT),  { Negative height to flip upside-down render texture }
                   scale_rect,
                   Vector2Create(0, 0), 0.0, $FFFFFFFF);

    EndDrawing();

  until (the_koniec) or (restart) or (sace) or (WindowShouldClose() <> 0);

  { Cleanup render texture }
  UnloadRenderTexture(game_render);
  writeln('arcade: Render texture unloaded');
end;

{ ========================================
   EXACT PORT from GAME.INC lines 226-277
   ======================================== }

procedure maze;
var
  movx, movy, mova, mavb: word;
  game_render: TRaylibRenderTexture2D;  { Render texture for scaling }
  screen_scale_x, screen_scale_y: single;
  scale_rect: TRectangle;
  frame_count: longint;  { For debugging }
begin
  new(bl);
  ds := 0;
  frame_count := 0;
  aktiv35.animation_frame_counter := 0;  { Initialize animation slowdown counter }

  { Create render texture at game resolution (GAME_WIDTHxGAME_HEIGHT) }
  writeln('maze: Creating render texture for scaling...');
  game_render := LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT);
  writeln('maze: Render texture created successfully');

  { Set target FPS to 60 for consistent game speed }
  SetTargetFPS(60);

  { Initialize pathfinding array }
  for f := 0 to mie_x do
    for ff := 0 to mie_y do
      bl^[f, ff] := false;

  aktivuj_texturu;
  { TODO: rewait; }

  repeat
    { Start Raylib rendering frame }
    BeginDrawing();
    inc(frame_count);

    { Check for window close event - respond immediately }
    if WindowShouldClose() <> 0 then
    begin
      the_koniec := True;
    end;

    if rollup = 0 then
      oldkey := 0;
    k := 0;

    { Display score }
    vypis_skore;

    { Update game world rendering - ORIGINAL ENGINE APPROACH }
    { The original engine only redraws when necessary, not every frame }
    { Only redraw if player moved or state changed }
    if (si.x <> si.oldx) or (si.y <> si.oldy) or (oldpol <> poloha) then
    begin
      { Use redraw(false) for incremental updates (clears and redraws dynamic elements) }
      { This calls print_predmet2 which only redraws changed items }
      redraw(false);
    end;

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
        $5848, $5868:
          begin
            writeln(' (F11 - Toggle Fullscreen)');
            ToggleFullscreen;
          end;

        $4400:
          begin
            writeln(' (F10 - Toggle Fullscreen)');
            writeln(' Before: ', GetScreenWidth(), 'x', GetScreenHeight());
            ToggleFullscreen;
            writeln(' After: ', GetScreenWidth(), 'x', GetScreenHeight());
          end;

        $1c0d, $3920:
          begin
            { Check for object interaction first }
            if mov > 0 then
            begin
              writeln('maze: Interacting with object ', mov);
              use_vec(mov);
            end
            else
            begin
              { TODO: menu; }
              { sace flag will cause loop exit in until condition }
            end;
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

    { Check for object collision }
    zisti_vec;

    { Auto-pickup for funk=0 items (pickup items) }
    if (mov > 0) and (vec^[mov].funk = 0) then
    begin
      writeln('maze: Auto-picking up object ', mov);
      use_vec(mov);
    end;

    { Render to screen - Raylib requires this }
    ClearBackground(0, 0, 0, 255);

    { Render game to texture first (for scaling) }
    BeginTextureMode(game_render);

    { Clear background of render texture }
    raylib_helpers.ClearBackground(0, 0, 0, 255);

    { Render map tiles using GPU textures (if available) }
    load235.RenderMapTiles();

    { Render objects using GPU textures }
    load235.DrawAllObjects(0);  { Use 0 for maze mode - objects not animated }

    { Render player avatar using GPU textures }
    { si.x and si.y are already in pixel coordinates (not tile coordinates) }
    { Just apply small offset like in menu (px=4, py=2 in original, converted to pixels) }
    { Debug: Log avatar rendering }
    writeln('maze: Rendering avatar at (', si.x + 4, ', ', si.y + 2, ') frame=', poloha);
    jxmenu.RenderAvatarAt(si.x + 4, si.y + 2, poloha);

    { Only render screen_image if NOT using GPU tile rendering }
    { TODO: Eventually need to render UI elements directly with Raylib }
    if not load235.map_tiles_loaded then
      RenderScreenToWindow();

    EndTextureMode();

    { Calculate scaled rectangle to fit window while maintaining aspect ratio }
    { Get current window size }
    screen_scale_x := GetScreenWidth() / GAME_WIDTH;
    screen_scale_y := GetScreenHeight() / GAME_HEIGHT;

    { Debug: Log window size every 60 frames (1 second) }
    if (frame_count mod 60) = 0 then
      writeln('maze: Window size: ', GetScreenWidth(), 'x', GetScreenHeight(), ' scale: ', screen_scale_x:0:2, 'x', screen_scale_y:0:2);

    { Use the smaller scale to fit entirely within the window }
    if screen_scale_x < screen_scale_y then
      screen_scale_y := screen_scale_x
    else
      screen_scale_x := screen_scale_y;

    { Calculate centered position }
    scale_rect.x := (GetScreenWidth() - Trunc(GAME_WIDTH * screen_scale_x)) div 2;
    scale_rect.y := (GetScreenHeight() - Trunc(GAME_HEIGHT * screen_scale_y)) div 2;
    scale_rect.width := Trunc(GAME_WIDTH * screen_scale_x);
    scale_rect.height := Trunc(GAME_HEIGHT * screen_scale_y);

    { Draw the scaled texture (pixelated filtering) }
    { Source rectangle (entire texture) - negative height to flip render texture }
    DrawTexturePro(game_render.texture,
                   RectangleCreate(0, 0, GAME_WIDTH, -GAME_HEIGHT),  { Negative height to flip upside-down render texture }
                   scale_rect,
                   Vector2Create(0, 0), 0.0, $FFFFFFFF);

    EndDrawing();

  until (the_koniec) or (restart) or (sace) or (WindowShouldClose() <> 0);

  { Cleanup render texture }
  UnloadRenderTexture(game_render);
  writeln('maze: Render texture unloaded');

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
