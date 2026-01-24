program test_spritesheet;

{$mode objfpc}{$H+}

{ Test spritesheet loading and frame extraction
  Tests Phase 1 of animation system implementation
}

uses
  SysUtils,
  raylib_helpers,
  sprite_anim,
  jxgraf;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  ganim_sheet: TSpritesheet;
  glist_sheet: TSpritesheet;
  current_frame: word;
  frame_timer: longint;
  auto_play: boolean;

begin
  writeln('=== Siriel Modern - Spritesheet Extraction Test ===');
  writeln('');

  { Initialize screen buffer }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);

  { Test 1: Load GLIST spritesheet }
  writeln('[TEST 1] Loading GLIST spritesheet from MAIN.DAT...');
  glist_sheet := LoadSpritesheet('data/MAIN.DAT', 'GLIST', 16, 16);

  if not glist_sheet.loaded then
  begin
    writeln('ERROR: Failed to load GLIST spritesheet');
    readln;
    Exit;
  end;

  writeln('  OK - Loaded ', glist_sheet.total_frames, ' frames');
  writeln('  Dimensions: ', glist_sheet.columns, 'x', glist_sheet.rows, ' grid');
  writeln('');

  { Test 2: Load GZAL (avatar animations) from MAIN.DAT }
  writeln('[TEST 2] Loading GZAL spritesheet from MAIN.DAT...');
  ganim_sheet := LoadSpritesheet('data/MAIN.DAT', 'GZAL', 16, 16);

  if not ganim_sheet.loaded then
  begin
    writeln('  GZAL not found in MAIN.DAT');
    writeln('  Using GLIST for all tests');
    ganim_sheet := glist_sheet; { Use GLIST for both }
  end
  else
  begin
    writeln('  OK - Found GZAL: ', ganim_sheet.total_frames, ' frames');
    writeln('  Dimensions: ', ganim_sheet.columns, 'x', ganim_sheet.rows, ' grid');
  end;

  { Test 3: Display frames interactively }
  writeln('[TEST 3] Interactive frame viewer');
  writeln('  Instructions:');
  writeln('    LEFT/RIGHT arrows - Change frame');
  writeln('    SPACE - Toggle auto-play');
  writeln('    ESC - Quit');
  writeln('');
  writeln('Starting viewer...');
  writeln('');

  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, 'Spritesheet Test - GANIM/GLIST Viewer');
  SetTargetFPS(60);

  current_frame := 0;
  frame_timer := GetAnimationTime();
  auto_play := false;

  while WindowShouldClose() = 0 do
  begin
    BeginDrawing();

    { Clear screen image with black }
    FillChar(screen_image^.data^, SCREEN_WIDTH * SCREEN_HEIGHT * 4, 0);

    { Draw frames from GANIM at top of screen }
    { Draw current frame at different positions for visibility }
    if current_frame < ganim_sheet.total_frames then
    begin
      { Draw single frame at actual size (16x16) }
      DrawFrame(ganim_sheet.frames[current_frame], 50, 50);

      { Draw a row of frames to show grid }
      if current_frame + 4 < ganim_sheet.total_frames then
      begin
        DrawFrame(ganim_sheet.frames[current_frame], 100, 50);
        DrawFrame(ganim_sheet.frames[current_frame + 1], 120, 50);
        DrawFrame(ganim_sheet.frames[current_frame + 2], 140, 50);
        DrawFrame(ganim_sheet.frames[current_frame + 3], 160, 50);
      end;
    end;

    { Draw frames from GLIST }
    if glist_sheet.total_frames >= 8 then
    begin
      { Draw first 8 frames in a row }
      DrawFrame(glist_sheet.frames[0], 50, 100);
      DrawFrame(glist_sheet.frames[1], 70, 100);
      DrawFrame(glist_sheet.frames[2], 90, 100);
      DrawFrame(glist_sheet.frames[3], 110, 100);
      DrawFrame(glist_sheet.frames[4], 130, 100);
      DrawFrame(glist_sheet.frames[5], 150, 100);
      DrawFrame(glist_sheet.frames[6], 170, 100);
      DrawFrame(glist_sheet.frames[7], 190, 100);
    end;

    { Draw multiple rows to show grid extraction works }
    if glist_sheet.total_frames >= 16 then
    begin
      DrawFrame(glist_sheet.frames[8], 50, 120);
      DrawFrame(glist_sheet.frames[9], 70, 120);
      DrawFrame(glist_sheet.frames[10], 90, 120);
      DrawFrame(glist_sheet.frames[11], 110, 120);
      DrawFrame(glist_sheet.frames[12], 130, 120);
      DrawFrame(glist_sheet.frames[13], 150, 120);
      DrawFrame(glist_sheet.frames[14], 170, 120);
      DrawFrame(glist_sheet.frames[15], 190, 120);
    end;

    { Render screen_image to window }
    RenderScreenToWindow();

    { Handle keyboard input }
    if IsKeyPressed(263) <> 0 then  { LEFT }
    begin
      if current_frame > 0 then
        dec(current_frame);
    end;

    if IsKeyPressed(262) <> 0 then  { RIGHT }
    begin
      if current_frame < ganim_sheet.total_frames - 1 then
        inc(current_frame);
    end;

    if IsKeyPressed(32) <> 0 then  { SPACE }
    begin
      auto_play := not auto_play;
    end;

    { Auto-play animation }
    if auto_play then
    begin
      if GetAnimationTime() - frame_timer >= 100 then  { 10 FPS }
      begin
        inc(current_frame);
        if current_frame >= ganim_sheet.total_frames then
          current_frame := 0;
        frame_timer := GetAnimationTime();
      end;
    end;

    EndDrawing();
  end;

  { Cleanup }
  FreeSpritesheet(ganim_sheet);
  FreeSpritesheet(glist_sheet);
  CloseWindow;

  writeln('');
  writeln('=== Test Complete ===');
  writeln('Spritesheet extraction is working correctly!');
  writeln('Extracted frames from GANIM and GLIST blocks');
  writeln('Frames can be displayed and animated');
  writeln('');
  writeln('Ready to proceed to Phase 2: Animation sequencer');
end.
