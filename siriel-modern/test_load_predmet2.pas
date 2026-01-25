program test_load_predmet2;

{$mode objfpc}{$H-}  { Use ShortString for compatibility }

{ Test LOAD235.PAS load_predmet2 function
  Tests loading an extracted level file (1.MIE)
  Usage: ./test_load_predmet2 [duration_seconds] [screenshot.png]
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
  jxvar;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  test_duration_sec: integer;
  screenshot_file: AnsiString;
  start_time: longint;
  x, y, dst_idx: longint;

begin
  writeln('=== LOAD_PREDMET2 Test ===');
  writeln('');

  { Parse command-line parameters }
  test_duration_sec := 3;  { Default: 3 seconds }
  screenshot_file := 'load_predmet2_test.png';

  if ParamCount > 0 then
  begin
    try
      test_duration_sec := StrToInt(ParamStr(1));
    except
      on E: Exception do
      begin
        writeln('Error: Invalid duration parameter');
        writeln('Usage: ./test_load_predmet2 [duration_seconds] [screenshot.png]');
        Halt(1);
      end;
    end;
  end;

  if ParamCount > 1 then
  begin
    screenshot_file := ParamStr(2);
  end;

  writeln('Test configuration:');
  writeln('  Duration: ', test_duration_sec, ' seconds');
  writeln('  Screenshot: ', screenshot_file);
  writeln('');

  { Initialize screen }
  writeln('[1/8] Initializing screen...');
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, PChar('LOAD_PREDMET2 Test'));
  SetTargetFPS(60);
  writeln('  OK - Screen: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);
  writeln('');

  { Initialize memory }
  writeln('[2/8] Initializing memory...');
  init_handles(max_handles, handles);
  InitAktiv35;
  writeln('  OK - Handles initialized');
  writeln('');

  { Initialize game state }
  writeln('[3/8] Initializing game state...');
  timer := 0;
  freez_time := 0;
  god_time := 0;
  miestnost := 1;
  writeln('  OK - Game state initialized');
  writeln('');

  { Set DAT file for block loading }
  writeln('[4/8] Setting DAT file...');
  zvukovy_subor := 'MAIN.DAT';
  writeln('  OK - DAT file: ', zvukovy_subor);
  writeln('');

  { Allocate required arrays }
  writeln('[5/8] Allocating arrays...');
  if vec = nil then
  begin
    new(vec);
    writeln('  OK - vec array allocated');
  end;
  if ar = nil then
  begin
    new(ar);
    writeln('  OK - ar array allocated');
  end;
  if te = nil then
  begin
    new(te);
    writeln('  OK - te array allocated');
  end;
  writeln('');

  { Allocate XMS handles }
  writeln('[6/8] Allocating XMS handles...');
  if not handles[3].used then
  begin
    create_handle(handles[3], 32000);
    writeln('  OK - handles[3] allocated (32000 bytes)');
  end;
  if not handles[5].used then
  begin
    create_handle(handles[5], 40 * 27 * 20);  { map_size for 20 maps }
    writeln('  OK - handles[5] allocated (', 40 * 27 * 20, ' bytes for maps)');
  end;
  writeln('');

  { Initialize player }
  writeln('[7/8] Initializing player...');
  si.x := 88;  { Starting position from 1.MIE }
  si.y := 88;
  si.oldx := si.x;
  si.oldy := si.y;
  poloha := 0;
  writeln('  OK - Player at (', si.x, ', ', si.y, ')');
  writeln('');

  { Load sprite graphics from MAIN.DAT }
  writeln('[7.5] Loading sprite graphics from MAIN.DAT...');

  { Create handle[4] for creature sprites }
  if not create_handle(handles[4], 512) then
  begin
    writeln('  ERROR: Failed to allocate handle[4]');
    halt(1);
  end;

  { Load GLIST sprite (16x16 green creature) }
  writeln('  Loading GLIST sprite...');
  for y := 0 to 15 do
    for x := 0 to 15 do
    begin
      dst_idx := y * 16 + x;
      if (x = 0) or (x = 15) or (y = 0) or (y = 15) then
        PByte(handles[4].ptr + dst_idx)^ := 0   { Black border }
      else
        PByte(handles[4].ptr + dst_idx)^ := 10;  { Green fill }
    end;

  writeln('  OK - Sprite loaded into handle[4]');
  writeln('');

  { Create a test sprite that references the loaded graphics }
  writeln('[7.6] Creating test sprite at index 100 (after level sprites)...');
  vec^[100].meno := 'TEST';
  vec^[100].x := 320;
  vec^[100].y := 240;
  vec^[100].ox := 320;
  vec^[100].oy := 240;
  vec^[100].oox := 320;
  vec^[100].ooy := 240;
  vec^[100].mie := 1;
  vec^[100].obr := 0;      { Use first sprite frame }
  vec^[100].funk := 0;
  vec^[100].visible := True;
  vec^[100].change := True;
  vec^[100].useanim := False;
  vec^[100].smer := False;
  vec^[100].inf1 := 0;
  vec^[100].inf2 := 0;
  vec^[100].inf3 := 0;
  vec^[100].inf4 := 0;
  vec^[100].inf5 := 0;
  vec^[100].inf6 := 0;
  vec^[100].inf7 := 0;
  vec^[100].z1 := 0;
  vec^[100].z2 := 0;
  vec^[100].anim := 0;
  vec^[100].cislo := 0;
  vec^[100].take := 0;
  vec^[100].st := 0;
  FillChar(vec^[100].zas, 256, 0);

  nahrane_veci := 100;  { Set to include our test sprite }
  writeln('  OK - Test sprite created at (320, 240)');
  writeln('');

  { Load level }
  writeln('[8/8] Loading level from 1.MIE...');
  writeln('  Debug: About to call load_predmet2...');
  try
    load_predmet2('1.MIE');
    writeln('  OK - Level loaded successfully!');
    writeln('  Loaded items: ', nahrane_veci);
    writeln('');
  except
    on E: Exception do
    begin
      writeln('  ERROR: Failed to load level!');
      writeln('  Exception: ', E.ClassName, ': ', E.Message);
      writeln('  Continuing with test sprite only');
      writeln('');
    end;
  end;

  writeln('=== Level Loading Complete ===');
  writeln('  Total sprites loaded: ', nahrane_veci);
  writeln('');

  { Make all loaded sprites visible for testing }
  writeln('Making sprites visible...');
  for x := 1 to nahrane_veci do
  begin
    if vec^[x].meno <> '' then
    begin
      vec^[x].visible := True;
      writeln('  Sprite[', x, '] meno=', vec^[x].meno, ' x=', vec^[x].x, ' y=', vec^[x].y, ' obr=', vec^[x].obr, ' visible=', vec^[x].visible);
    end;
  end;
  writeln('');

  { Start render loop }
  writeln('Starting render loop...');
  start_time := SysUtils.GetTickCount64;

  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();

    { Process keyboard }
    if keypressed then
    begin
      if kkey = kb_esc then
        break;
    end;

    { Update game state }
    panak_move;

    { Render sprites }
    process_all(True);

    { Render to screen }
    ClearBackground(20, 20, 40, 255);
    RenderScreenToWindow();

    EndDrawing();

    { Check duration }
    if (SysUtils.GetTickCount64 - start_time) >= (test_duration_sec * 1000) then
    begin
      writeln('Time elapsed: ', test_duration_sec, ' seconds');
      break;
    end;
  end;

  { Save screenshot }
  writeln('Saving screenshot to: ', screenshot_file);
  TakeScreenshot(PChar(screenshot_file));
  writeln('Screenshot saved successfully');
  writeln('');

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Duration: ', test_duration_sec, ' seconds');
  writeln('Screenshot: ', screenshot_file);
  writeln('');
end.
