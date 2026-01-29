unit geo;

{$mode objfpc}{$H-}  { Use ShortString for compatibility with original }

interface

uses
  ctypes,
  SysUtils;

{ Raylib core bindings }
procedure InitWindow(width, height: cint; title: PChar); cdecl; external;
procedure CloseWindow(); cdecl; external;
function WindowShouldClose(): cint; cdecl; external;
procedure BeginDrawing(); cdecl; external;
procedure EndDrawing(); cdecl; external;
procedure ClearBackground(r, g, b, a: cuchar); cdecl; external;
function GetFPS(): cint; cdecl; external;
procedure SetTargetFPS(fps: cint); cdecl; external;
function IsKeyDown(key: cint): cint; cdecl; external;

{ Core graphics initialization }
procedure grafika_init(resolution_x, resolution_y, bits_per_pixel: word);

{ Keyboard handling }
procedure clear_key_buffer;
function kkey: word;
function kkey2: word;
function keypressed: boolean;
function zmack(cisl: byte): boolean;
procedure get_keyboard;
procedure key_swap(cisl: byte; stav: boolean);
procedure reset_keyboard;
function key: word;
procedure init_keyboard(stav: byte);
procedure done_keyboard;
procedure fake_key2(fk: word);

{ Timing }
procedure wait(milliseconds: word);
function GetClock: longint;

{ Directional input }
procedure sipky(var sipx, sipy: integer; var kluc: word);
procedure sipka_fake(pseudo: word; var sipx, sipy: word);
function sipka_fakex(pseudo, step: word; var sipx, sipy: word): boolean;
function sipka_fake2(pseudo: word; var sipx, sipy: word; krok: word): boolean;
procedure sipka_spat(var sipx, sipy: word);
procedure sipka_joystick;
procedure sipka_joystick2;
procedure joystick(var v, yv: word; var button: byte);
procedure joystick_kaliber;
function detect_joystick: boolean;
procedure sipka_limit(sminx, sminy, smaxx, smaxy, sstep: word; abile: boolean; tol: byte; h, d, l, p: boolean);

{ String parsing functions (from original GEO.PAS) }
procedure mov_string(var zdroj, num: string; var poradie: word);
procedure mov_num(var zdroj: string; var num: word; var poradie: word);
procedure mov_num2(var zdroj: string; var num: byte; var poradie: word);
procedure get_name_normal(zdroj: string; var ciel: string);
procedure get_funk_normal(zdroj: string; var ciel: string);
procedure get_funk(zdroj: string; var ciel: string);

{ File I/O helper functions }
function subor_exist(const meno: string): boolean;
function upcased(const s: string): string;
procedure upcased(zdroj: string; var ciel: string);
function out_string(var s: string): string;

{ Sound function stubs (from original JXZVUK.PAS) }
procedure pust(cislo: word);
procedure pust2(cislo: word);
procedure pust_extra(cislo: byte);
procedure reload_sound(cislo: word; const datfile, zvuk: string);
procedure stop_all_sounds;
procedure stopsound(cislo: word);
procedure zvuk(cislo: word);
procedure zvuk(param: longint; cislo: word);
procedure aaplay(const params: string);

{ Additional helper functions from original codebase }
function value(const s: string): longint;
function kill_strings(const s: string; ch: char): string;
procedure pulz(cas: word);
procedure pulzx(cas: word);
function soundplaying(cislo: word): boolean;

{ Name parsing helpers }
procedure get_name(zdroj: string; var ciel: string);
function dekoduj(const s: string): string;
function dekoduj(param: longint; const s: string): string;

{ Additional state variables }
var
  tma: boolean;
  non_key: boolean;
  joystick_able: boolean;
  joystick_time, joystick_fire_time: longint;
  joystick_delay, joystick_fire_delay: word;

{ Font and text output }
procedure setfont(fontptr: pointer; width, height: word);
procedure printx(bitmap: Pointer; x, y: word; const text: string; col, back: word);

const
  { Key scancodes }
  kb_up      = $4800;
  kb_down    = $5000;
  kb_left    = $4b00;
  kb_right   = $4d00;
  kb_esc     = $011B;
  kb_enter   = $1C0D;
  kb_space   = $3920;

  { Direction constants (Slovak: up, down, left, right) - for load235 compatibility }
  dir_hore   = kb_up;
  dir_dole   = kb_down;
  dir_vlavo  = kb_left;
  dir_vpravo = kb_right;

  { Raylib key codes }
  KEY_UP      = 265;
  KEY_DOWN    = 264;
  KEY_LEFT    = 263;
  KEY_RIGHT   = 262;
  KEY_ESCAPE  = 256;
  KEY_ENTER   = 257;
  KEY_SPACE   = 32;

var
  { Global state }
  screen_width, screen_height: word;
  clock_offset: longint;

implementation

uses
  dos,
  jxgraf;  { For actual types in implementation }

var
  key_buffer: word = 0;
  clock_start: longint = 0;
  k, last, sx, sy: word;
  tolerancia: byte;
  sb: byte;
  hore, dole, lavo, pravo: boolean;
  sipkaminx, sipkaminy, sipkamaxx, sipkamaxy, sipkastep: word;
  klx: array[0..128] of boolean;
  sdf: byte;
  old_keyboard: byte;

{ Convert milliseconds to clock ticks (18.2 Hz = ~55ms per tick) }
function MillisecondsToClock(ms: word): longint;
begin
  MillisecondsToClock := (ms * 1000) div 54927;
end;

{ Graphics initialization - simplified }
procedure grafika_init(resolution_x, resolution_y, bits_per_pixel: word);
begin
  screen_width := resolution_x;
  screen_height := resolution_y;
  
  { Initialize Raylib window }
  InitWindow(resolution_x, resolution_y, 'Siriel Modern');
  SetTargetFPS(60);
  
  { Initialize clock }
  clock_start := SysUtils.GetTickCount64;
  clock_offset := 0;
  
  writeln('GEO: Graphics initialized: ', resolution_x, 'x', resolution_y);
end;

{ Clear keyboard buffer }
procedure clear_key_buffer;
begin
  key_buffer := 0;
end;

{ Get key from buffer }
function kkey: word;
begin
  kkey := key_buffer;
  key_buffer := 0;
end;

{ Get key without consuming }
function kkey2: word;
begin
  kkey2 := key_buffer;
end;

{ Check if key pressed }
function keypressed: boolean;
begin
  keypressed := (key_buffer <> 0);
end;

{ Check if specific key is pressed (using keyboard state array) }
function zmack(cisl: byte): boolean;
begin
  zmack := False;
  if cisl <= 128 then
    zmack := klx[cisl];
end;

{ Wait for specified milliseconds }
procedure wait(milliseconds: word);
var
  target_time: longint;
begin
  target_time := GetClock + MillisecondsToClock(milliseconds);
  while GetClock < target_time do
  begin
    { Update keyboard state }
    if IsKeyDown(KEY_UP) <> 0 then
      key_buffer := kb_up
    else if IsKeyDown(KEY_DOWN) <> 0 then
      key_buffer := kb_down
    else if IsKeyDown(KEY_LEFT) <> 0 then
      key_buffer := kb_left
    else if IsKeyDown(KEY_RIGHT) <> 0 then
      key_buffer := kb_right
    else if IsKeyDown(KEY_ESCAPE) <> 0 then
      key_buffer := kb_esc
    else if IsKeyDown(KEY_ENTER) <> 0 then
      key_buffer := kb_enter
    else if IsKeyDown(KEY_SPACE) <> 0 then
      key_buffer := kb_space;
      
    { Small sleep to avoid CPU spin }
    Sleep(1);
  end;
end;

{ Get clock in DOS ticks (18.2 Hz) }
function GetClock: longint;
begin
  GetClock := (SysUtils.GetTickCount64 - clock_start) div 55;
end;

{ ========================================
   KEYBOARD FUNCTIONS (from original GEO.PAS)
   ======================================== }

{ Initialize keyboard state tracking }
procedure init_keyboard(stav: byte);
begin
  for sdf := 0 to 128 do
    klx[sdf] := False;
  old_keyboard := 0;
  { Note: In DOS, this would set BIOS keyboard flags at 0:0417 }
  { For modern port, we track state in klx array }
end;

{ Restore keyboard state }
procedure done_keyboard;
begin
  { Note: In DOS, this would restore BIOS keyboard flags }
  { For modern port, keyboard state tracking is automatic }
end;

{ Get key from hardware (convert from Raylib) }
function key: word;
begin
  key := key_buffer;
end;

{ Update keyboard state from hardware }
procedure get_keyboard;
var
  klu: byte;
  ascii_char: byte;
begin
  { Clear buffer first }
  clear_key_buffer;

  { Map Raylib keys to DOS scancodes with ASCII }
  if IsKeyDown(KEY_UP) <> 0 then
  begin
    klu := 72;  { Up arrow scan code }
    ascii_char := 0;  { No ASCII for arrows }
  end
  else if IsKeyDown(KEY_DOWN) <> 0 then
  begin
    klu := 80;  { Down arrow scan code }
    ascii_char := 0;
  end
  else if IsKeyDown(KEY_LEFT) <> 0 then
  begin
    klu := 75;  { Left arrow scan code }
    ascii_char := 0;
  end
  else if IsKeyDown(KEY_RIGHT) <> 0 then
  begin
    klu := 77;  { Right arrow scan code }
    ascii_char := 0;
  end
  else if IsKeyDown(KEY_ESCAPE) <> 0 then
  begin
    klu := 1;   { ESC scan code }
    ascii_char := 27;  { ASCII ESC }
  end
  else if IsKeyDown(KEY_ENTER) <> 0 then
  begin
    klu := 28;  { Enter scan code }
    ascii_char := 13;  { ASCII CR }
  end
  else if IsKeyDown(KEY_SPACE) <> 0 then
  begin
    klu := 57;  { Space scan code }
    ascii_char := 32;  { ASCII space }
  end
  else
  begin
    klu := 0;
    ascii_char := 0;
  end;

  { Update state array }
  if klu >= 128 then
    klx[klu - 128] := False
  else if klu > 0 then
    klx[klu] := True;

  { Set key_buffer to DOS keycode format (scan_code in high byte, ASCII in low byte) }
  if klu > 0 then
    key_buffer := (klu shl 8) or ascii_char;

  { Special case: arrow keys clear all states }
  if (klu = 203) or (klu = 205) then
    reset_keyboard;
end;

{ Swap key state manually }
procedure key_swap(cisl: byte; stav: boolean);
begin
  if cisl <= 128 then
    klx[cisl] := stav;
end;

{ Clear all key states }
procedure reset_keyboard;
begin
  for sdf := 0 to 128 do
    klx[sdf] := False;
end;

{ Simulate keypress for joystick }
procedure fake_key2(fk: word);
begin
  key_buffer := fk;
  joystick_time := GetClock + joystick_delay;
end;

{ Directional input handling - EXACT PORT from GEO.PAS }
procedure sipky(var sipx, sipy: integer; var kluc: word);
begin
  if keypressed or joystick_able then
  begin
    if joystick_able then
      sipka_joystick;
    if keypressed then
      k := key;
    last := k;
    case k of
      $4800:  { Up }
        if hore then
          dec(sipy, sipkastep);
      $5000:  { Down }
        if dole then
          inc(sipy, sipkastep);
      $4b00:  { Left }
        if lavo then
          dec(sipx, sipkastep);
      $4d00:  { Right }
        if pravo then
          inc(sipx, sipkastep);
    end;
    if sipx < sipkaminx then
      sipx := sipkaminx;
    if sipy < sipkaminy then
      sipy := sipkaminy;
    if sipx > sipkamaxx then
      sipx := sipkamaxx;
    if sipy > sipkamaxy then
      sipy := sipkamaxy;
    kluc := k;
  end;
end;

{ Simulate key press for movement - EXACT PORT from GEO.PAS }
procedure sipka_fake(pseudo: word; var sipx, sipy: word);
begin
  last := pseudo;
  case pseudo of
    $4800: dec(sipy, sipkastep);
    $5000: inc(sipy, sipkastep);
    $4b00: dec(sipx, sipkastep);
    $4d00: inc(sipx, sipkastep);
  end;
  if sipx < sipkaminx then
    sipx := sipkaminx;
  if sipy < sipkaminy then
    sipy := sipkaminy;
  if sipx > sipkamaxx then
    sipx := sipkamaxx;
  if sipy > sipkamaxy then
    sipy := sipkamaxy;
end;

{ Extended directional input with step - EXACT PORT from GEO.PAS }
function sipka_fakex(pseudo, step: word; var sipx, sipy: word): boolean;
begin
  sipka_fakex := False;
  case pseudo of
    $4800: dec(sipy, step);
    $5000: inc(sipy, step);
    $4b00: dec(sipx, step);
    $4d00: inc(sipx, step);
  end;
  if sipx < sipkaminx then
  begin
    sipx := sipkaminx;
    sipka_fakex := True;
  end;
  if sipy < sipkaminy then
  begin
    sipy := sipkaminy;
    sipka_fakex := True;
  end;
  if sipx > sipkamaxx then
  begin
    sipx := sipkamaxx;
    sipka_fakex := True;
  end;
  if sipy > sipkamaxy then
  begin
    sipy := sipkamaxy;
    sipka_fakex := True;
  end;
end;

{ Directional input with custom step size - EXACT PORT from GEO.PAS }
function sipka_fake2(pseudo: word; var sipx, sipy: word; krok: word): boolean;
begin
  sipka_fake2 := True;
  case pseudo of
    $4800: dec(sipy, krok);
    $5000: inc(sipy, krok);
    $4b00: dec(sipx, krok);
    $4d00: inc(sipx, krok);
  end;
  if (sipx < sipkaminx) or (sipy < sipkaminy) or (sipx > sipkamaxx) or (sipy > sipkamaxy) then
    sipka_fake2 := False;
end;

{ Reverse movement - EXACT PORT from GEO.PAS line 343 }
procedure sipka_spat(var sipx, sipy: word);
begin
  case last of
    $4800: inc(sipy, sipkastep);
    $5000: dec(sipy, sipkastep);
    $4b00: inc(sipx, sipkastep);
    $4d00: dec(sipx, sipkastep);
  end;
end;

{ Set movement limits - EXACT PORT from GEO.PAS line 253 }
procedure sipka_limit(sminx, sminy, smaxx, smaxy, sstep: word; abile: boolean; tol: byte; h, d, l, p: boolean);
begin
  sipkaminx := sminx;
  sipkaminy := sminy;
  sipkamaxx := smaxx;
  sipkamaxy := smaxy;
  sipkastep := sstep;
  joystick_able := abile;
  tolerancia := tol;
  hore := h;
  dole := d;
  lavo := l;
  pravo := p;
end;

{ Joystick reading - STUB for modern port }
procedure joystick(var v, yv: word; var button: byte);
begin
  { TODO: Implement actual joystick reading for modern systems }
  { For now, joystick is disabled }
  v := sx;
  yv := sy;
  button := 0;
end;

{ Joystick calibration - STUB for modern port }
procedure joystick_kaliber;
begin
  { TODO: Implement joystick calibration }
  { For now, just set center position }
  sx := 320;
  sy := 240;
end;

{ Detect joystick - STUB for modern port }
function detect_joystick: boolean;
begin
  { TODO: Implement joystick detection }
  Result := False;
end;

{ Simple joystick handling - STUB for modern port }
procedure sipka_joystick;
var
  jx, jy: word;
  jb: byte;
begin
  if joystick_able and (GetClock > joystick_time) then
  begin
    joystick(jx, jy, jb);
    if jy < (sy - tolerancia) then
      fake_key2($4800);
    if jx < (sx - tolerancia) then
      fake_key2($4b00);
    if jx > (sx + tolerancia) then
      fake_key2($4d00);
    if jy > (sy + tolerancia) then
      fake_key2($5000);
  end;
end;

{ Advanced joystick with diagonals - STUB for modern port }
procedure sipka_joystick2;
var
  jx, jy: word;
  jb: byte;
label
  skip;
begin
  if joystick_able and (GetClock > joystick_time) then
  begin
    joystick(jx, jy, jb);
    if (jy < (sy - tolerancia)) and (jx < (sx - tolerancia)) then
    begin
      fake_key2($4700);
      goto skip;
    end;
    if (jy < (sy - tolerancia)) and (jx > (sx + tolerancia)) then
    begin
      fake_key2($4900);
      goto skip;
    end;
    if (jy > (sy + tolerancia)) and (jx > (sx + tolerancia)) then
    begin
      fake_key2($5100);
      goto skip;
    end;
    if (jy > (sy + tolerancia)) and (jx < (sx - tolerancia)) then
    begin
      fake_key2($4f00);
      goto skip;
    end;
    if jy < (sy - tolerancia) then
      fake_key2($4800);
    if jx < (sx - tolerancia) then
      fake_key2($4b00);
    if jx > (sx + tolerancia) then
      fake_key2($4d00);
    if jy > (sy + tolerancia) then
      fake_key2($5000);
  skip:
    { Fire button handling would go here }
  end;
end;

{ ========================================
   STRING PARSING FUNCTIONS (from original GEO.PAS)
   ======================================== }

procedure mov_string(var zdroj, num: string; var poradie: word);
var
  rox: string;
begin
  rox := '';
  if length(zdroj) >= poradie then
  begin
    repeat
      if (zdroj[poradie] <> '~') and (zdroj[poradie] <> ',') then
      begin
        rox := rox + zdroj[poradie];
        inc(poradie);
      end;
    until (zdroj[poradie] = '~')
          or (zdroj[poradie] = ',')
          or (poradie > length(zdroj));

    inc(poradie);
  end;
  num := rox;
end;

procedure mov_num(var zdroj: string; var num: word; var poradie: word);
var
  row: string;
  code: word;
begin
  mov_string(zdroj, row, poradie);
  if row = '' then
    num := 0
  else
  begin
    val(row, num, code);
    if code <> 0 then
      num := 0;
  end;
end;

procedure mov_num2(var zdroj: string; var num: byte; var poradie: word);
var
  numf: word;
  row: string;
begin
  mov_string(zdroj, row, poradie);
  if row = '' then
    num := 0
  else
  begin
    val(row, numf, numf);
    num := numf;
  end;
end;

procedure get_name_normal(zdroj: string; var ciel: string);
var
  fr: word;
begin
  fr := 0;
  ciel := '';
  if (length(zdroj) > 0) and (zdroj[1] <> ';') then
  begin
    repeat
      inc(fr);
    until (zdroj[fr] = '[') or (fr > length(zdroj));
    inc(fr);
    repeat
      ciel := ciel + zdroj[fr];
      inc(fr);
    until (zdroj[fr] = ']') or (fr > length(zdroj));
  end;
end;

procedure get_funk_normal(zdroj: string; var ciel: string);
var
  fr, fl: word;
begin
  fr := 0;
  ciel := '';
  if (length(zdroj) > 0) and (zdroj[1] <> ';') then
  begin
    repeat
      inc(fr);
    until (zdroj[fr] = '=') or (fr > length(zdroj));
    inc(fr);
    for fl := fr to length(zdroj) do
      ciel := ciel + zdroj[fl];
  end;
end;

procedure get_funk(zdroj: string; var ciel: string);
var
  fr, fl: word;
begin
  get_funk_normal(zdroj, ciel);
  for fl := fr to length(ciel) do
    ciel[fl] := UpCase(ciel[fl]);
end;

{ ========================================
   FILE I/O HELPER FUNCTIONS
   ======================================== }

{ Check if file exists }
function subor_exist(const meno: string): boolean;
begin
  subor_exist := FileExists(meno);
end;

{ Convert string to uppercase (procedure with 2 params - original version) }
procedure upcased_proc(zdroj: string; var ciel: string);
var
  raf: word;
begin
  ciel := '';
  for raf := 1 to length(zdroj) do
    ciel := ciel + UpCase(zdroj[raf]);
end;

{ Convert string to uppercase (function version) }
function upcased_func(const s: string): string;
var
  i: integer;
begin
  Result := s;
  for i := 1 to Length(Result) do
    Result[i] := UpCase(Result[i]);
end;

{ Compatibility wrapper - function version }
function upcased(const s: string): string;
begin
  Result := upcased_func(s);
end;

{ Compatibility wrapper - procedure version (for calls with 2 params) }
procedure upcased(zdroj: string; var ciel: string);
begin
  upcased_proc(zdroj, ciel);
end;

{ Process string with > prefix (DAT block reference) }
function out_string(var s: string): string;
begin
  if (Length(s) > 0) and (s[1] = '>') then
    out_string := Copy(s, 2, Length(s) - 1)
  else
    out_string := s;
end;

{ ========================================
   SOUND FUNCTION STUBS (from JXZVUK.PAS)
   ======================================== }

procedure pust(cislo: word);
begin
  { TODO: Implement sound playback }
  { For now, this is a stub }
end;

procedure pust2(cislo: word);
begin
  { TODO: Implement sound playback (alternative) }
  { For now, this is a stub }
end;

procedure pust_extra(cislo: byte);
begin
  { TODO: Implement extra sound playback }
  { For now, this is a stub }
end;

procedure reload_sound(cislo: word; const datfile, zvuk: string);
begin
  { TODO: Implement sound loading from DAT file }
  { For now, this is a stub }
end;

procedure stop_all_sounds;
begin
  { TODO: Implement stop all sounds }
  { For now, this is a stub }
end;

procedure stopsound(cislo: word);
begin
  { TODO: Stop specific sound }
  { For now, this is a stub }
end;

procedure zvuk(cislo: word);
begin
  { TODO: Play sound effect }
  { For now, this is a stub }
end;

{ 2-parameter version for compatibility }
procedure zvuk(param: longint; cislo: word);
begin
  { TODO: Play sound effect with parameter }
  { For now, this is a stub }
end;

procedure aaplay(const params: string);
begin
  { TODO: Play animation with parameters }
  { For now, this is a stub }
  writeln('STUB: aaplay(', params, ')');
end;

{ ========================================
   ADDITIONAL HELPER FUNCTIONS
   ======================================== }

function value(const s: string): longint;
var
  code: integer;
begin
  Val(s, Result, code);
  if code <> 0 then
    Result := 0;
end;

function kill_strings(const s: string; ch: char): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to Length(s) do
    if s[i] <> ch then
      Result := Result + s[i];
end;

procedure pulz(cas: word);
begin
  { Simple delay - wait for specified time }
  { TODO: Implement proper timing }
  wait(cas);
end;

procedure pulzx(cas: word);
begin
  { Extended delay with timing }
  pulz(cas * 10);
end;

function soundplaying(cislo: word): boolean;
begin
  { TODO: Implement sound status check }
  Result := False;
end;

{ Font and text output stubs }
procedure setfont(fontptr: pointer; width, height: word);
begin
  { TODO: Implement font loading }
  writeln('STUB: setfont ptr=', HexStr(fontptr), ' size=', width, 'x', height);
end;

procedure printx(bitmap: Pointer; x, y: word; const text: string; col, back: word);
var
  i: integer;
  px: word;
  bmp: PImage;
begin
  { Simple text rendering - draw each character as 8x8 colored block }
  bmp := PImage(bitmap);
  if not Assigned(bmp) then
    exit;

  px := x;
  for i := 1 to Length(text) do
  begin
    { Draw 8x8 rectangle for each character }
    if (px + 8 <= 640) and (y + 8 <= 480) then
      jxgraf.rectangle2(bmp, px, y, 8, 8, col);
    px := px + 8;
  end;
end;

{ Name parsing helper implementations }
procedure get_name(zdroj: string; var ciel: string);
begin
  { Extract name from string (simpler version of get_name_normal) }
  get_name_normal(zdroj, ciel);
end;

function dekoduj(const s: string): string;
begin
  { TODO: Implement decoding }
  Result := s;
end;

{ 2-parameter version for compatibility }
function dekoduj(param: longint; const s: string): string;
begin
  { TODO: Implement decoding with parameter }
  Result := s;
end;

initialization
  { Initialize state variables }
  tma := False;
  joystick_able := False;
  joystick_delay := 100;
  joystick_fire_delay := 1000;
  joystick_time := 0;
  joystick_fire_time := 0;

  { Initialize movement limits to defaults }
  sipkaminx := 0;
  sipkaminy := 0;
  sipkamaxx := 640;
  sipkamaxy := 480;
  sipkastep := 1;

  { Initialize direction flags }
  hore := True;
  dole := True;
  lavo := True;
  pravo := True;

  { Initialize keyboard state array }
  for sdf := 0 to 128 do
    klx[sdf] := False;

  { Initialize joystick center position }
  sx := 320;
  sy := 240;
  tolerancia := 50;

  { Initialize key tracking }
  k := 0;
  last := 0;

end.
