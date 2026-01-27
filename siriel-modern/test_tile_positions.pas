program test_tile_positions;

{$mode objfpc}{$H+}

{ Test to verify tile positions and rendering order
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
  animing,
  gameloop;

const
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 480;

var
  x, y, f, ff: word;

begin
  writeln('=== Tile Position Test ===');
  writeln('');

  { Initialize }
  init_screen(SCREEN_WIDTH, SCREEN_HEIGHT);
  init_handles(max_handles, handles);
  InitAktiv35;
  timer := 0;
  freez_time := 0;
  god_time := 0;
  miestnost := 1;
  zvukovy_subor := 'data/SIRIEL35.DAT';

  { Allocate arrays }
  if vec = nil then new(vec);
  if ar = nil then new(ar);
  if te = nil then new(te);

  { Allocate handles }
  if not handles[3].used then create_handle(handles[3], 10000);
  if not handles[5].used then create_handle(handles[5], 2000);
  rerun;
  resx := 16;
  resy := 16;
  st.stav := 1;
  textura := '>GTEXT';

  { Load level }
  load_predmet2('1.MIE');
  writeln('Map dimensions: ', mie_x, ' x ', mie_y);
  writeln('resx=', resx, ' resy=', resy);
  writeln('');

  { Print first 5 tiles using test_grid_debug method }
  writeln('Test method (x outer, y inner):');
  y := 0;
  for x := 0 to 4 do begin
    if st.mie[x, y] > 0 then
      writeln('  st.mie[', x, ',', y, ']=', st.mie[x, y], ' at (', x*16, ',', y*16, ')');
  end;
  writeln('');

  { Print first 5 tiles using main engine method }
  writeln('Main engine method (f outer, ff inner):');
  f := 0;
  for ff := 0 to 4 do begin
    if st.mie[f, ff] > 0 then
      writeln('  st.mie[', f, ',', ff, ']=', st.mie[f, ff], ' at (', f*16, ',', ff*16, ')');
  end;
  writeln('');

  { Check if array indexing is consistent }
  writeln('Array indexing check:');
  writeln('  st.mie[0,5]=', st.mie[0,5], '  st.mie[5,0]=', st.mie[5,0]);
  writeln('  st.mie[1,5]=', st.mie[1,5], '  st.mie[5,1]=', st.mie[5,1]);
  writeln('');

  CloseWindow;
end.
