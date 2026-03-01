program siriel;

{$mode objfpc}{$H+}

{ Siriel Modern - Main Game Program
  Port of SI35.PAS with modern engine
  Loads data from DAT files and plays the game

  Usage:
    ./siriel                              [Interactive mode - auto-detect DAT file]
    ./siriel --dat=MAIN.DAT               [Specify DAT file in interactive mode]
    ./siriel [duration] [screenshot.png]  [Test mode - run for N seconds, save screenshot]

  Examples:
    ./siriel                    (Interactive mode with auto-detected DAT file)
    ./siriel --dat=MAIN.DAT     (Interactive mode with specific DAT file)
    ./siriel 5                  (Test mode: run for 5 seconds with default screenshot)
    ./siriel 10 test.png        (Test mode: run for 10 seconds, save to test.png)
}

uses
  SysUtils,
  Dos,
  raylib_helpers,
  jxgraf,
  jxmenu,
  modern_mem,
  load135,
  load235,
  panak,
  process,
  geo,
  aktiv35,
  jxvar,
  collision,
  gameloop,
  blockx,
  jxfont_simple;

const
  PROGRAM_NAME = 'Siriel Modern';
  PROGRAM_VERSION = '1.0';
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

type
  TDATFileList = array[1..10] of string;
  TLevelList = array[1..20] of string;

var
  selectedDAT: string;
  cli_level_file: string;  { Level file specified via --level-file }
  cli_level_select: boolean;  { Jump directly to level selection }
  currentLevel: integer;
  gameRunning: boolean;
  test_mode: boolean;
  test_duration_sec: integer;
  screenshot_file: string;
  movx, movy, mova: word;  { Movement variables for maze mode }

{ ========================================
   DAT FILE DETECTION
   ======================================== }

function FindDATFiles(var datList: TDATFileList): integer;
var
  sr: TSearchRec;
  count: integer;
begin
  count := 0;

  writeln('Scanning for DAT files...');

  if SysUtils.FindFirst('*.DAT', faAnyFile, sr) = 0 then
  begin
    repeat
      if (sr.Name <> '.') and (sr.Name <> '..') and
         (UpperCase(ExtractFileExt(sr.Name)) = '.DAT') and
         (sr.Size > 100000) then { Skip small files like MAIN.DAT (< 100KB) }
      begin
        inc(count);
        if count <= 10 then
        begin
          datList[count] := sr.Name;
          writeln('  Found: ', sr.Name, ' (', sr.Size, ' bytes)');
        end;
      end;
    until (SysUtils.FindNext(sr) <> 0) or (count >= 10);
  end;

  SysUtils.FindClose(sr);

  if count = 0 then
    writeln('  No DAT files found!')
  else
    writeln('  Total: ', count, ' DAT file(s) found');

  Result := count;
end;

function GetCLIDATFile: string;
var
  i: integer;
  param, value: string;
begin
  Result := '';

  for i := 1 to ParamCount do
  begin
    param := ParamStr(i);

    if (param = '--dat') and (i < ParamCount) then
    begin
      value := ParamStr(i + 1);
      if FileExists(value) then
      begin
        Result := value;
        writeln('Using DAT file from CLI: ', value);
      end
      else
        writeln('WARNING: DAT file from CLI not found: ', value);
    end
    else if Copy(param, 1, 6) = '--dat=' then
    begin
      value := Copy(param, 7, Length(param) - 6);
      if FileExists(value) then
      begin
        Result := value;
        writeln('Using DAT file from CLI: ', value);
      end
      else
        writeln('WARNING: DAT file from CLI not found: ', value);
    end;
  end;
end;

{ ========================================
   CLI ARGUMENT PARSING
   ======================================== }

procedure ShowHelp;
begin
  writeln('');
  writeln('Usage: ', ParamStr(0), ' [OPTIONS]');
  writeln('');
  writeln('Game Options:');
  writeln('  --level-file FILE.MIE    Load specific level file');
  writeln('  --level-select           Jump directly to level selection menu');
  writeln('  --dat FILE.DAT           Use specific DAT file');
  writeln('');
  writeln('Test Mode Options:');
  writeln('  --duration SECONDS       Run in test mode for N seconds');
  writeln('  --screenshot FILE.png    Save screenshot at end of test');
  writeln('');
  writeln('Information:');
  writeln('  --help, -h               Show this help message');
  writeln('  --version, -v            Show version information');
  writeln('');
  writeln('Examples:');
  writeln('  ', ParamStr(0), ' --level-file 1.MIE');
  writeln('  ', ParamStr(0), ' --duration 10 --screenshot test.png');
  writeln('  ', ParamStr(0), ' --duration 5 --level-file 2.MIE --screenshot demo.png');
  writeln('  ', ParamStr(0), ' --dat MAIN.DAT --level-file 1.MIE --duration 15');
  writeln('  ', ParamStr(0), ' --level-select --duration 3 --screenshot menu.png');
  writeln('');
end;

procedure ShowVersion;
begin
  writeln('');
  writeln(PROGRAM_NAME, ' v', PROGRAM_VERSION);
  writeln('Port of Siriel 3.5 from Turbo Pascal to Free Pascal + Raylib');
  writeln('');
end;

procedure ParseCommandLineArguments;
var
  i: integer;
  param, value: string;
  has_duration, has_level_file: boolean;
begin
  { Initialize defaults }
  test_mode := False;
  test_duration_sec := 60;
  screenshot_file := 'siriel_screenshot.png';
  has_duration := False;
  has_level_file := False;
  cli_level_select := False;

  i := 1;
  while i <= ParamCount do
  begin
    param := ParamStr(i);

    { Handle --help }
    if (param = '--help') or (param = '-h') then
    begin
      ShowHelp;
      Halt(0);
    end;

    { Handle --version }
    if (param = '--version') or (param = '-v') then
    begin
      ShowVersion;
      Halt(0);
    end;

    { Handle --duration }
    if param = '--duration' then
    begin
      if i < ParamCount then
      begin
        value := ParamStr(i + 1);
        try
          test_duration_sec := StrToInt(value);
          test_mode := True;
          has_duration := True;
          writeln('CLI: Test mode duration = ', test_duration_sec, ' seconds');
          inc(i);  { Skip next parameter }
        except
          writeln('Error: Invalid duration value: ', value);
          Halt(1);
        end;
      end
      else
      begin
        writeln('Error: --duration requires a value');
        Halt(1);
      end;
    end
    { Handle --screenshot }
    else if param = '--screenshot' then
    begin
      if i < ParamCount then
      begin
        value := ParamStr(i + 1);
        screenshot_file := value;
        writeln('CLI: Screenshot file = ', screenshot_file);
        inc(i);  { Skip next parameter }
      end
      else
      begin
        writeln('Error: --screenshot requires a value');
        Halt(1);
      end;
    end
    { Handle --level-file }
    else if param = '--level-file' then
    begin
      if i < ParamCount then
      begin
        value := ParamStr(i + 1);
        cli_level_file := value;
        has_level_file := True;
        test_mode := True;  { Auto-enable test mode if level file specified }
        writeln('CLI: Level file = ', value);
        inc(i);  { Skip next parameter }
      end
      else
      begin
        writeln('Error: --level-file requires a value');
        Halt(1);
      end;
    end
    { Handle --dat (already processed by GetCLIDATFile, but we accept it here too) }
    else if param = '--dat' then
    begin
      if i < ParamCount then
      begin
        { Just skip it - GetCLIDATFile will handle it }
        inc(i);  { Skip the value }
        inc(i);  { Skip next parameter after value }
      end;
    end
    { Legacy: Handle positional parameters (duration and screenshot) }
    else if Copy(param, 1, 2) <> '--' then
    begin
      test_mode := True;
      try
        test_duration_sec := StrToInt(param);
        writeln('CLI: Test mode duration (legacy) = ', test_duration_sec, ' seconds');

        { Second positional parameter is screenshot file }
        if i < ParamCount then
        begin
          value := ParamStr(i + 1);
          if Copy(value, 1, 2) <> '--' then
          begin
            screenshot_file := value;
            writeln('CLI: Screenshot file (legacy) = ', screenshot_file);
          end;
        end;
      except
        on E: Exception do
        begin
          writeln('Error: Invalid parameter: ', param);
          writeln('Use --help for usage information');
          Halt(1);
        end;
      end;
    end
    { Handle --level-select }
    else if param = '--level-select' then
    begin
      cli_level_select := True;
      writeln('CLI: Will jump directly to level selection');
    end
    else
    begin
      writeln('Warning: Unknown parameter: ', param);
      writeln('Use --help for usage information');
    end;

    inc(i);
  end;
end;

function SelectDATFile(const datList: TDATFileList; count: integer): string;
var
  selection: integer;
  i: integer;
begin
  Result := '';

  if count = 0 then
  begin
    writeln('');
    writeln('ERROR: No DAT files found in current directory!');
    writeln('');
    writeln('Please ensure one or more .DAT files are present.');
    writeln('DAT files should contain game resources (graphics, sounds, levels).');
    writeln('');
    Halt(1);
  end
  else if count = 1 then
  begin
    writeln('');
    writeln('Auto-selecting only available DAT file: ', datList[1]);
    Result := datList[1];
  end
  else
  begin
    writeln('');
    writeln('Multiple DAT files found. Please select one:');
    writeln('');
    for i := 1 to count do
      writeln('  [', i, '] ', datList[i]);
    writeln('');

    write('Select DAT file [1-', count, ']: ');

    {$I-}
    readln(selection);
    {$I+}

    if IOResult <> 0 then
      selection := 1;

    if (selection < 1) or (selection > count) then
    begin
      writeln('Invalid selection. Using first DAT file.');
      selection := 1;
    end;

    Result := datList[selection];
    writeln('Selected: ', Result);
  end;

  writeln('');
end;

function DetectAndSelectDAT: string;
var
  datList: TDATFileList;
  datCount: integer;
  cliDAT: string;
begin
  writeln('=== ', PROGRAM_NAME, ' v', PROGRAM_VERSION, ' ===');
  writeln('');

  { Check CLI parameter first }
  cliDAT := GetCLIDATFile;

  { Scan for DAT files }
  datCount := FindDATFiles(datList);

  { Use CLI parameter or ask user }
  if cliDAT <> '' then
    Result := cliDAT
  else
    Result := SelectDATFile(datList, datCount);
end;

{ ========================================
   GAME INITIALIZATION
   ======================================== }

procedure InitializeGame(const datFile: string);
var
  config_pole: array[0..32767] of byte;
begin
  writeln('Initializing game systems...');
  writeln('');

  { Initialize screen }
  writeln('[1/6] Initializing screen...');
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, PChar(PROGRAM_NAME + ' - ' + datFile));
  SetTargetFPS(60);
  writeln('  OK - Screen: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);

  { Initialize VGA palette - CRITICAL for correct colors }
  writeln('[1/6] Initializing VGA palette...');
  jxgraf.fill_palette_default;
  writeln('  OK - VGA palette initialized');
  writeln('');

  { Initialize memory }
  writeln('[2/6] Initializing memory...');
  init_handles(max_handles, handles);
  InitAktiv35;
  writeln('  OK - Handles: ', max_handles, ', vec allocated: ', vec <> nil);
  writeln('');

  { Initialize game state }
  writeln('[3/6] Initializing game state...');
  timer := 0;
  freez_time := 0;
  god_time := 0;
  miestnost := 1;
  writeln('  OK - Game state initialized');
  writeln('');

  { Load DAT file resources }
  writeln('[4/6] Loading DAT file resources...');

  { Allocate levely structure }
  if aktiv35.levely = nil then
    new(aktiv35.levely);

  { Allocate data_disks structure }
  if aktiv35.data_disks = nil then
    new(aktiv35.data_disks);

  { Load level list from DAT file CONFIG block }
  writeln('  Loading level list from ', datFile, '...');
  aktiv35.num_disks := 1;
  aktiv35.data_disks^[1].meno := datFile;
  aktiv35.data_disks^[1].subor := datFile;
  load235.load_level_list(datFile, config_pole);

  if aktiv35.levely^.pocet > 0 then
    writeln('  Loaded ', aktiv35.levely^.pocet, ' levels')
  else
    writeln('  WARNING: No levels found in CONFIG');

  { Load GLIST tiles for menu decoration }
  writeln('  Loading GLIST tiles for menu decoration...');
  jxmenu.LoadGlistTiles;
  if jxmenu.glist_loaded then
    writeln('  GLIST tiles loaded')
  else
    writeln('  WARNING: GLIST tiles not found');

  writeln('  OK - DAT file loaded');
  writeln('');

  { Initialize player }
  writeln('[5/6] Initializing player...');
  si.x := 320;
  si.y := 240;
  si.oldx := 320;
  si.oldy := 240;
  poloha := 0;
  writeln('  OK - Player at (', si.x, ', ', si.y, ')');
  writeln('');

  { Initialize creature system }
  writeln('[6/6] Initializing creature system...');
  if vec = nil then
    new(vec);
  nahrane_veci := 0;
  writeln('  OK - Creature system ready');
  writeln('');

  writeln('=== Game Initialized ===');
  writeln('');
end;

{ ========================================
   INTRO MENU (Graphical)
   ======================================== }

function ShowIntroMenu: integer;
var
  f: integer;
  menu: ^jxmenu_typ;
  choice: word;
  key: word;
  menu_done: boolean;
  background_loaded: boolean;
  font_pal: jxfont_simple.tpalette;
  num_disks: integer;
  menu_start_time, current_time: uint64;
  time_limit_ms: uint64;
begin
  Result := 0;

  writeln('=== MAIN MENU ===');
  writeln('');

  { Load GTREEP background - datadisk background image }
  { From test_background_g.pas: GTREEP is 640x480 background }
  writeln('[Menu] Loading GTREEP (background)...');
  if blockx.draw_gif_block(screen_image, selectedDAT, 'GTREEP', 0, 0, font_pal) then
    writeln('[Menu] GTREEP background loaded (640x480)')
  else
  begin
    writeln('[Menu] WARNING - GTREEP not found, using black background');
    clear_bitmap(screen_image);
  end;

  { Load GLOGO (logo) - from MAIN.DAT (shared assets across all datadisks) }
  writeln('[Menu] Loading GLOGO (Siriel 3.5 logo) from MAIN.DAT...');
  if blockx.draw_gif_block(screen_image, 'data/MAIN.DAT', 'GLOGO', 460, 100, font_pal) then
    writeln('[Menu] GLOGO loaded at (460, 100)')
  else
    writeln('[Menu] WARNING - GLOGO not found in MAIN.DAT');

  { TODO: Display version and disk name with shadow }
  { Original: print_zoom_shadow(screen, 250, 20, version, 14, 2, 2, 3, 3, 0); }
  { Original: print_zoom_shadow(screen, 230, 60, 'DISK: ' + meno_disku, 11, 1, 2, 3, 3, 0); }
  { For now, skip this - we'll add shadow text effect later }

  { Initialize graphical menu - matches original DOS structure }
  { col1=14 (yellow for selected), col2=15 (white for normal), col3=0 (black) }
  new(menu);
  init_jxmenu(0, 0, 14, 15, 0, '', menu^);

  { Add menu items at exact positions from original GAME.INC:402-459 }
  { tx[ja,10] = "Game" at (270, 150) }
  vloz_jxmenu_pos(270, 150, 'Game', menu^, $2267);

  { tx[ja,11] = "Info + Help" at (270, 185) }
  vloz_jxmenu_pos(270, 185, 'Info + Help', menu^, $1769);

  { tx[ja,12] = "Hi-scores" at (270, 220) }
  vloz_jxmenu_pos(270, 220, 'Hi-scores', menu^, $2368);

  { "DATADISK" option at (270, 255) - ONLY if num_disks > 1 }
  { For now, we have only one disk, so skip this }
  { if num_disks > 1 then
    vloz_jxmenu_pos(270, 255, 'DATADISK', menu^, $2064);
  }

  { tx[ja,13] = "Quit" at (280, 300) }
  vloz_jxmenu_pos(280, 300, 'Quit', menu^, $1071);

  num_disks := 4;  { Game, Info + Help, Hi-scores, Quit }

  { Render background to window first }
  BeginDrawing();
  ClearBackground(0, 0, 0, 255);
  RenderScreenToWindow();
  EndDrawing();

  { Draw menu decorations OVER the background - using original frame size }
  { Original: old_frame.draw(200, 40, 12, 2+num_disks) }
  { old_frame_draw(200, 40, 12, 2 + num_disks);  { TODO: Implement proper old_frame.draw } }

  { Display menu items WITHOUT decorative frame for intro screen }
  { GLIST decorations should NOT appear in intro menu }
  for f := 1 to menu^.pocet do
  begin
    jxmenu.normal_jxmenu(f, menu^);
  end;

  { Menu input loop - wait for key press }
  choice := 1;  { Default to first option }
  menu_done := False;

  { Initialize timeout for test mode }
  menu_start_time := SysUtils.GetTickCount64;
  if test_mode then
    time_limit_ms := test_duration_sec * 1000  { Convert seconds to milliseconds }
  else
    time_limit_ms := 0;

  { Highlight initial selection }
  jxmenu.hi_jxmenu(choice, menu^);

  { Render to window with initial highlight }
  BeginDrawing();
  ClearBackground(0, 0, 0, 255);
  RenderScreenToWindow();
  EndDrawing();

  repeat
    { Update avatar animation frame - mirrors original DOS implementation }
    jxmenu.UpdateAvatar;

    { Redraw highlighted item with updated avatar frame }
    jxmenu.hi_jxmenu(choice, menu^);

    { Update keyboard buffer }
    geo.get_keyboard;

    { Check for timeout in test mode }
    if test_mode and (time_limit_ms > 0) then
    begin
      current_time := SysUtils.GetTickCount64;
      if (current_time - menu_start_time) >= time_limit_ms then
      begin
        writeln('[Menu] Timeout reached, exiting...');

        { Capture screenshot before exiting }
        if screenshot_file <> '' then
        begin
          writeln('[Menu] Saving screenshot to: ', screenshot_file);
          { Render final frame }
          BeginDrawing();
          ClearBackground(0, 0, 0, 255);
          RenderScreenToWindow();
          EndDrawing();
          { Take screenshot }
          TakeScreenshot(PChar(screenshot_file));
          writeln('[Menu] Screenshot saved successfully');
        end;

        { Unhighlight current selection before exiting }
        jxmenu.normal_jxmenu(choice, menu^);
        choice := num_disks;  { Quit }
        menu_done := True;
      end;
    end;

    { Check for window close (modern addition - not in DOS version) }
    if WindowShouldClose() <> 0 then
    begin
      { Unhighlight current selection before exiting }
      jxmenu.normal_jxmenu(choice, menu^);
      choice := num_disks;  { Quit }
      menu_done := True;
    end;

    { Check for input }
    if geo.keypressed then
    begin
      key := geo.kkey2;
      case key of
        geo.kb_up:
          begin
            if choice > 1 then
            begin
              { Unhighlight current item }
              jxmenu.normal_jxmenu(choice, menu^);
              dec(choice);
              { Highlight new item }
              jxmenu.hi_jxmenu(choice, menu^);
            end;
          end;
        geo.kb_down:
          begin
            if choice < num_disks then
            begin
              { Unhighlight current item }
              jxmenu.normal_jxmenu(choice, menu^);
              inc(choice);
              { Highlight new item }
              jxmenu.hi_jxmenu(choice, menu^);
            end;
          end;
        geo.kb_enter, geo.kb_space:
          menu_done := True;
        geo.kb_esc:
          begin
            { Unhighlight current selection before exiting }
            jxmenu.normal_jxmenu(choice, menu^);
            choice := num_disks;  { Quit }
            menu_done := True;
          end;
      end;
    end;

    { Render to window every frame }
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);
    RenderScreenToWindow();
    jxmenu.RenderAvatar;  { Draw avatar on GPU after menu }
    EndDrawing();

    { Small delay to prevent CPU spin }
    Sleep(16);
  until menu_done;

  { Clear keyboard buffer to prevent key carryover to next screen }
  geo.clear_key_buffer;

  { Cleanup }
  dispose(menu);

  { Map choice to return value }
  { Original DOS: 1=Game, 2=Info+Help, 3=Hi-scores, 4=Quit }
  case choice of
    1: Result := 1;  { Game - Start Game }
    2: Result := 2;  { Info + Help - Show Help }
    3: Result := 3;  { Hi-scores - Show High Scores }
    4: Result := 0;  { Quit }
  else
    Result := 0;
  end;

  writeln('Selected option: ', Result);
  writeln('');
end;

{ ========================================
   LEVEL SELECTION (Graphical)
   ======================================== }

function SelectLevel: integer;
var
  menu: ^jxmenu_typ;
  choice: word;
  f: word;
  back_text: string;
  level_count: word;
begin
  Result := 0;

  writeln('=== LEVEL SELECTION ===');
  writeln('');

  { Clear screen and set up background }
  clear_bitmap(screen_image);

  { Initialize graphical menu at position (200, 40) per original DOS code }
  { Use dark blue (1) for menu fill instead of black (0) }
  new(menu);
  init_jxmenu(200, 40, 0, 15, 1, 'Level', menu^);

  { Add levels from levely^ structure if available }
  if (aktiv35.levely <> nil) and (aktiv35.levely^.pocet > 0) then
  begin
    writeln('  Found ', aktiv35.levely^.pocet, ' levels in DAT file');
    for f := 1 to aktiv35.levely^.pocet do
    begin
      writeln('  Level ', f, ': ', aktiv35.levely^.lev[f].meno,
              ' (', aktiv35.levely^.lev[f].subor, ')');
      vloz_jxmenu2(aktiv35.levely^.lev[f].meno, menu^, 0);
    end;
    level_count := aktiv35.levely^.pocet;
  end
  else
  begin
    { Add test levels for now since levely is not populated yet }
    writeln('  WARNING: levely not initialized, using test levels');
    writeln('  Adding test levels...');
    vloz_jxmenu2('LEVEL 1: The Beginning', menu^, 0);
    vloz_jxmenu2('LEVEL 2: Dark Forest', menu^, 0);
    vloz_jxmenu2('LEVEL 3: Mountain Pass', menu^, 0);
    vloz_jxmenu2('LEVEL 4: Ice Caverns', menu^, 0);
    vloz_jxmenu2('LEVEL 5: Final Castle', menu^, 0);
    level_count := 5;
  end;

  { Add "Back" option - use original text position }
  back_text := '   BACK';  { tx[ja,22] in original }
  vloz_jxmenu2(back_text, menu^, 0);

  { Size menu to 192x288 per original DOS code }
  size_jxmenu(192, 288, menu^);

  { Set initial selection to first level }
  menu^.first := 1;

  { Draw menu items (graphicswindow will handle GLIST decoration) }
  draw_jxmenu3(menu^);

  { Wait for user selection }
  writeln('  Waiting for selection...');
  vyber_jxmenu(menu^, choice, test_duration_sec * 1000);

  { Cleanup }
  dispose(menu);

  { Map choice: if "Back" was selected (last item), return 0 }
  if choice <= level_count then
  begin
    Result := choice;
    { Set global variables like original does }
    aktiv35.vybrane := choice;
    aktiv35.old_level := choice;
    writeln('  Selected level: ', Result);
  end
  else
  begin
    Result := 0;
    writeln('  Returning to main menu');
  end;

  { Clear keyboard buffer to prevent key carryover }
  geo.clear_key_buffer;

  writeln('');
end;

{ ========================================
   GAME LOOP
   EXACT PORT from GAME.INC lines 375-378
   ======================================== }

procedure RunGameLoop(duration_sec: integer = 0);
var
  start_time, current_time: longint;
  target_duration_ms: longint;
  original_test_mode: boolean;
begin
  gameRunning := true;
  start_time := SysUtils.GetTickCount64;

  { Calculate target duration if specified and set global for game loop to check }
  if duration_sec > 0 then
    target_duration_ms := duration_sec * 1000
  else
    target_duration_ms := 0;

  { Set global test mode duration for game loop procedures to check }
  test_mode_duration_ms := target_duration_ms;

  { Store original test mode flag }
  original_test_mode := test_mode;

  writeln('=== Starting Game ===');
  writeln('  Level: ', currentLevel);
  writeln('  Mode (st.stav): ', st.stav);
  writeln('  Timer: ', timer, ' seconds');
  writeln('  Lives: ', zivoty);
  if duration_sec > 0 then
    writeln('  Test mode: Will run for ', duration_sec, ' seconds');
  writeln('');
  writeln('Controls: Arrow keys to move, SPACE to jump, ESC to pause');
  writeln('');

  { EXACT PORT from GAME.INC lines 375-378 }
  case st.stav of
    1:
      begin
        writeln('Starting platformer mode (arcade)...');
        arcade;
      end;
    2, 3, 4, 5:
      begin
        writeln('Starting top-down mode (maze)...');
        maze;
      end;
  else
    begin
      writeln('WARNING: Invalid game mode (st.stav = ', st.stav, ')');
      writeln('Defaulting to platformer mode...');
      st.stav := 1;
      arcade;
    end;
  end;

  writeln('');
  writeln('=== Game Ended ===');
  writeln('  Final position: (', si.x, ', ', si.y, ')');
  writeln('');

  { Restore test mode flag (may have been modified by game loop) }
  test_mode := original_test_mode;

  { Save screenshot if in test mode }
  if test_mode then
  begin
    writeln('Saving screenshot to: ', screenshot_file);
    TakeScreenshot(PChar(screenshot_file));
    writeln('Screenshot saved successfully');
  end;
end;

procedure StartNewGame;
var
  levelFile: string;
  sr: TSearchRec;
  levelIndex: integer;
begin
  { Check if level file was specified via CLI }
  if cli_level_file <> '' then
  begin
    levelFile := cli_level_file;
    currentLevel := 1;
    writeln('Using CLI-specified level file: ', levelFile);
  end
  else if test_mode then
  begin
    { In test mode, auto-select level 1 }
    currentLevel := 1;
    writeln('Test mode: Auto-selecting Level 1');
    levelFile := '1.MIE';
  end
  else
  begin
    currentLevel := SelectLevel;
    if currentLevel = 0 then
      Exit;  { User went back to main menu }

    { Find the Nth .MIE file }
    levelIndex := 0;
    if SysUtils.FindFirst('*.MIE', faAnyFile, sr) = 0 then
    begin
      repeat
        if (sr.Name <> '.') and (sr.Name <> '..') and
           (UpperCase(ExtractFileExt(sr.Name)) = '.MIE') then
        begin
          inc(levelIndex);
          if levelIndex = currentLevel then
          begin
            levelFile := sr.Name;
            Break;
          end;
        end;
      until SysUtils.FindNext(sr) <> 0;
    end;
    SysUtils.FindClose(sr);
  end;

  if currentLevel > 0 then
  begin
    { Set default TEXTURA }
    writeln('Setting default TEXTURA...');
    textura := '>GTEXT';
    writeln('  TEXTURA set to: ', textura);

    { Load level using original load_predmet2 }
    writeln('Loading level file: ', levelFile);

    { Set DAT file for block loading }
    zvukovy_subor := selectedDAT;

    { Allocate required arrays for level loading }
    if vec = nil then
      new(vec);
    if ar = nil then
      new(ar);
    if te = nil then
      new(te);

    { Allocate XMS handles - EXACT PORT from SI35.PAS line 659-660 }
    if not handles[3].used then
      create_handle(handles[3], pocet_veci * 21 + pocet_textov * dlzka_textu + pocet_obr * dlzka_obr);
    if not handles[5].used then
      create_handle(handles[5], map_size);

    { EXACT PORT from SI35.PAS line 723: Initialize handles[3] with default values }
    rerun;
    writeln('Initialized handles[3] via rerun()');

    { EXACT PORT from SI35.PAS line 610-611: Initialize tile dimensions }
    resx := 16;
    resy := 16;
    writeln('Tile dimensions initialized: ', resx, 'x', resy);

    { EXACT PORT from GAME.INC line 311: Set game mode BEFORE loading }
    st.stav := 1;
    writeln('Game mode set to: ', st.stav, ' (platformer mode)');

    { Load the level }
    load_predmet2(levelFile);

    { EXACT PORT from SI35.PAS line 742: Load TEXTURA spritesheet }
    writeln('Loading TEXTURA spritesheet from DAT file...');
    load_texture;
    writeln('  TEXTURA loaded successfully');

    { DEBUG: Verify map data was loaded }
    writeln('');
    writeln('=== Level Load Debug ===');
    writeln('  Map dimensions: ', mie_x, ' x ', mie_y);
    writeln('  Player start: (', si.x, ', ', si.y, ')');
    writeln('  Items loaded: ', nahrane_veci);
    writeln('  Texture loaded: ', textura, ' (aktual=', aktual, ')');
    writeln('');
    writeln('  Complete map data (', mie_x+1, ' x ', mie_y+1, '):');
    for f := 0 to mie_y do
    begin
      write('    Row ', f:2, ': ');
      for ff := 0 to mie_x do
      begin
        write(st.mie[ff, f]:2, ' ');
      end;
      writeln('');
    end;
    writeln('=== End Debug ===');
    writeln('');

    { EXACT PORT from GAME.INC lines 313-337: Post-load initialization }
    case st.stav of
      1, 3, 5:
        begin
          { Make creatures visible for these modes }
          writeln('Setting creatures visible for mode ', st.stav);
        end;
      2, 4:
        begin
          { Hide creatures for these modes }
          writeln('Hiding creatures for mode ', st.stav);
        end;
    end;

    { Set movement variables based on mode }
    case st.stav of
      2, 3:
        begin
          movx := 6;
          movy := 12;
          mova := 8;
          writeln('Movement variables set: movx=', movx, ', movy=', movy, ', mova=', mova);
        end;
      4, 5:
        begin
          movx := 6;
          movy := 6;
          mova := 0;
          writeln('Movement variables set: movx=', movx, ', movy=', movy, ', mova=', mova);
        end;
    end;

    { EXACT PORT from GAME.INC lines 345-372: Game initialization }
    briefing;
    { TODO: play_ani(flik_start); }

    if not sace then
      zivoty := def_zivoty;
    sace := False;
    the_koniec := False;
    restart := False;
    poloha := 0;
    bloing := 0;
    rollup := 0;
    rolldown := False;
    anim_count := 0;

    { EXACT PORT from GAME.INC line 362: CRITICAL - Render initial screen! }
    writeln('Rendering initial screen with redraw(true)...');
    try
      redraw(true);
      writeln('  Screen rendered successfully');

      { CRITICAL: Display the initial screen to the window! }
      writeln('Displaying initial screen to window...');
      BeginDrawing();
      ClearBackground(0, 0, 0, 255);
      RenderScreenToWindow();
      EndDrawing();
      writeln('  Initial screen displayed');
    except
      on E: Exception do
      begin
        writeln('  ERROR during redraw: ', E.Message);
        writeln('  Exception class: ', E.ClassName);
        writeln('  Continuing without redraw...');
      end;
    end;

    { TODO: decrease_palette(palx,30); }
    { TODO: init_charakter(resx,resy,si.x+px,si.y+py,poloha,si.buf,ar^); }
    { TODO: redraw_score; }
    { TODO: increase_palette(blackx,palx,50); }
    { TODO: play_ball; }

    time := GetClock;
    dlzka_padu := 0;

    { Start game loop with duration if in test mode }
    if test_mode then
      RunGameLoop(test_duration_sec)
    else
      RunGameLoop;
  end;
end;

procedure LoadSavedGame;
begin
  writeln('Load Game - Not implemented yet');
  writeln('');
end;

procedure ShowSettings;
begin
  writeln('Settings - Not implemented yet');
  writeln('');
end;

procedure CleanupGame;
begin
  writeln('Cleaning up allocated memory...');

  { Free screen_image bitmap using jxgraf's cleanup }
  if screen_image <> nil then
  begin
    try
      destroy_bitmap(screen_image);
      screen_image := nil;
      writeln('  Freed screen_image bitmap');
    except
      on E: Exception do
        writeln('  Warning: Error freeing screen_image: ', E.Message);
    end;
  end;

  { Free screen structure }
  if screen <> nil then
  begin
    try
      Dispose(screen);
      screen := nil;
      writeln('  Freed screen structure');
    except
      on E: Exception do
        writeln('  Warning: Error freeing screen structure: ', E.Message);
    end;
  end;

  { Free texture array }
  if te <> nil then
  begin
    try
      dispose(te);
      te := nil;
      writeln('  Freed texture array (te)');
    except
      on E: Exception do
        writeln('  Warning: Error freeing texture array: ', E.Message);
    end;
  end;

  { Free item graphics array }
  if ar <> nil then
  begin
    try
      dispose(ar);
      ar := nil;
      writeln('  Freed item graphics array (ar)');
    except
      on E: Exception do
        writeln('  Warning: Error freeing item graphics array: ', E.Message);
    end;
  end;

  { Free XMS handles - clean up ALL used handles }
  for f := 1 to max_handles do
  begin
    if handles[f].used then
    begin
      try
        kill_handle(handles[f]);
        writeln('  Freed handles[', f, ']');
      except
        on E: Exception do
          writeln('  Warning: Error freeing handles[', f, ']: ', E.Message);
      end;
    end;
  end;

  { Free bl array if allocated }
  if bl <> nil then
  begin
    try
      dispose(bl);
      bl := nil;
      writeln('  Freed bl array');
    except
      on E: Exception do
      writeln('  Warning: Error freeing bl array: ', E.Message);
    end;
  end;

  { Free vec array if allocated }
  if vec <> nil then
  begin
    try
      dispose(vec);
      vec := nil;
      writeln('  Freed vec array');
    except
      on E: Exception do
      writeln('  Warning: Error freeing vec array: ', E.Message);
    end;
  end;

  writeln('Memory cleanup complete');
end;

{ ========================================
   MAIN PROGRAM
   ======================================== }

begin
  { Parse command line arguments }
  ParseCommandLineArguments;

  { Detect and select DAT file }
  selectedDAT := DetectAndSelectDAT;

  { Initialize game }
  InitializeGame(selectedDAT);

  { Main menu loop - ALWAYS show intro menu first (unless --level-select or --level-file) }
  if cli_level_select then
  begin
    { Jump directly to level selection for screenshot/debugging }
    writeln('=== CLI: --level-select mode ===');
    writeln('Skipping intro menu, going directly to level selection...');
    writeln('');
    currentLevel := SelectLevel;

    { In test mode with --level-select, just exit after selection (don't run game) }
    if test_mode then
    begin
      writeln('[CLI] Test mode: Level selection completed, exiting');
      { Save screenshot if requested }
      if screenshot_file <> '' then
      begin
        writeln('[CLI] Saving screenshot to: ', screenshot_file);
        TakeScreenshot(PChar(screenshot_file));
        writeln('[CLI] Screenshot saved');
      end;
      CloseWindow;
      CleanupGame;
      Halt(0);
    end;

    if currentLevel > 0 then
      RunGameLoop(test_duration_sec)
    else
      writeln('Level selection cancelled');
    CloseWindow;
    CleanupGame;
    Halt(0);
  end
  else if cli_level_file <> '' then
  begin
    { Jump directly to specified level file }
    writeln('=== CLI: --level-file mode ===');
    writeln('Skipping intro menu, loading level file: ', cli_level_file);
    writeln('');
    StartNewGame;  { This calls RunGameLoop internally }
    CloseWindow;
    CleanupGame;
    Halt(0);
  end;

  repeat
      case ShowIntroMenu of
        1: StartNewGame;  { Game - Start Game }
        2: begin
            { Info + Help - Show help screen }
            writeln('Showing Info + Help...');
            writeln('TODO: Implement help screen');
            { For now, just return to menu }
          end;
        3: begin
            { Hi-scores - Show high scores }
            writeln('Showing High Scores...');
            writeln('TODO: Implement high scores screen');
            { For now, just return to menu }
          end;
        0: begin  { Quit - via ESC, Quit option, or window close }
          writeln('Quitting ', PROGRAM_NAME, '...');
          writeln('Thank you for playing!');
          writeln('');
          CloseWindow;
          CleanupGame;
          Halt(0);
        end;
      end;
    until false;
end.
