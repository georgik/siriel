program test_grid_debug;

{$mode objfpc}{$H+}

{ Debug test: Draw level tiles with 16x16 grid overlay
  This helps us visualize if the tile coordinates are aligned correctly
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
  animing;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  screenshot_file: string;
  frame_count: integer;
  start_time: longint;
  x, y, f: word;
  grid_color: longint;

begin
  writeln('=== Grid Debug Test ===');
  writeln('');

  { Parse command line }
  screenshot_file := 'grid_debug.png';
  if ParamCount >= 1 then
    screenshot_file := ParamStr(1);

  writeln('Mode: Automated (screenshot to "', screenshot_file, '")');
  writeln('');

  { Initialize screen }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  writeln('[1] Screen initialized: ', SCREEN_WIDTH, 'x', SCREEN_HEIGHT);
  writeln('');

  { Initialize memory system }
  writeln('[2] Initializing memory system...');
  init_handles(max_handles, handles);
  InitAktiv35;
  writeln('    OK - Memory initialized');
  writeln('');

  { Initialize game state }
  writeln('[3] Initializing game state...');
  timer := 0;
  freez_time := 0;
  god_time := 0;
  miestnost := 1;
  writeln('    OK - Game state initialized');
  writeln('');

  { Set DAT file }
  writeln('[4] Setting DAT file...');
  zvukovy_subor := 'data/SIRIEL35.DAT';
  writeln('    OK - DAT file: ', zvukovy_subor);
  writeln('');

  { Allocate required arrays }
  writeln('[5] Allocating arrays...');
  if vec = nil then
    new(vec);
  if ar = nil then
    new(ar);
  if te = nil then
    new(te);
  writeln('    OK - Arrays allocated');
  writeln('');

  { Allocate XMS handles }
  writeln('[6] Allocating XMS handles...');
  if not handles[3].used then
    create_handle(handles[3], 10000);
  if not handles[5].used then
    create_handle(handles[5], 2000);
  writeln('    OK - Handles allocated');
  writeln('');

  { Initialize handles[3] }
  writeln('[7] Initializing handles[3]...');
  rerun;
  writeln('    OK - Handles initialized');
  writeln('');

  { Set tile dimensions }
  writeln('[8] Setting tile dimensions...');
  resx := 16;
  resy := 16;
  writeln('    OK - Tile size: ', resx, 'x', resy);
  writeln('');

  { Set game mode }
  writeln('[9] Setting game mode...');
  st.stav := 1;
  writeln('    OK - Game mode: ', st.stav);
  writeln('');

  { Set texture }
  writeln('[10] Setting texture...');
  textura := '>GTEXT';
  writeln('    OK - Texture: ', textura);
  writeln('');

  { Load level }
  writeln('[11] Loading level: 1.MIE...');
  load_predmet2('1.MIE');
  writeln('    OK - Level loaded');
  writeln('    Map dimensions: ', mie_x, ' x ', mie_y);
  writeln('    Player start: (', si.x, ', ', si.y, ')');
  writeln('');

  { Load texture }
  writeln('[12] Loading texture...');
  load_texture;
  writeln('    OK - Texture loaded');
  writeln('');

  { Open window BEFORE drawing to screen }
  writeln('[13] Opening display window...');
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Grid Debug Test');
  SetTargetFPS(60);
  writeln('    OK - Window opened');
  writeln('');

  { Clear screen to black }
  writeln('[14] Drawing level tiles...');
  FillChar(screen_image^.data^, SCREEN_WIDTH * SCREEN_HEIGHT * 4, 0);

  { Draw tiles at their actual positions }
  for y := 0 to mie_y do
  begin
    for x := 0 to mie_x do
    begin
      if st.mie[x, y] > 0 then
      begin
        putseg2(x * 16, y * 16, 16, 16, st.mie[x, y], 0, te^);
      end;
    end;
  end;
  writeln('    Tiles drawn');
  writeln('');

  { Draw 16x16 grid overlay in bright green }
  writeln('[15] Drawing 16x16 grid overlay...');
  grid_color := (255 shl 24) or (0 shl 16) or (255 shl 8) or 0; { RGBA: 0xFF00FF00 }

  { Vertical lines every 16 pixels }
  for x := 0 to SCREEN_WIDTH div 16 do
  begin
    raylib_helpers.DrawLine(x * 16, 0, x * 16, SCREEN_HEIGHT, grid_color);
  end;

  { Horizontal lines every 16 pixels }
  for y := 0 to SCREEN_HEIGHT div 16 do
  begin
    raylib_helpers.DrawLine(0, y * 16, SCREEN_WIDTH, y * 16, grid_color);
  end;
  writeln('    Grid drawn (16x16 pixels per cell)');
  writeln('');

  { Render for 1 second }
  writeln('[16] Rendering for 1 second...');
  start_time := GetClock();
  frame_count := 0;

  while (GetClock() - start_time < 1000) do
  begin
    BeginDrawing();
    ClearBackground(20, 20, 30, 255);
    RenderScreenToWindow();
    EndDrawing();
    inc(frame_count);
  end;

  writeln('    Rendered ', frame_count, ' frames');
  writeln('');

  { Take screenshot }
  writeln('[17] Taking screenshot: ', screenshot_file);
  TakeScreenshot(PChar(screenshot_file));
  writeln('    OK - Screenshot saved');
  writeln('');

  { Cleanup }
  CloseWindow;

  writeln('=== Test Complete ===');
  writeln('Screenshot: ', screenshot_file);
  writeln('');
  writeln('You should see:');
  writeln('  - Green grid lines every 16 pixels (30x15 grid for 640x480)');
  writeln('  - Tiles drawn at their map positions');
  writeln('  - Each tile should be aligned within a grid cell');
  writeln('');
end.
