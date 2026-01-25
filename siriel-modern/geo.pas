unit geo;

{$mode objfpc}{$H+}

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

{ Timing }
procedure wait(milliseconds: word);
function GetClock: longint;

{ Directional input }
procedure sipky(var sipx, sipy: integer; var kluc: word);
procedure sipka_fake(pseudo: word; var sipx, sipy: word);
function sipka_fakex(pseudo, step: word; var sipx, sipy: word): boolean;
function sipka_fake2(pseudo: word; var sipx, sipy: word; krok: word): boolean;

const
  { Key scancodes }
  kb_up      = $4800;
  kb_down    = $5000;
  kb_left    = $4b00;
  kb_right   = $4d00;
  kb_esc     = $011B;
  kb_enter   = $1C0D;
  kb_space   = $3920;
  
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
  dos;

var
  key_buffer: word = 0;
  clock_start: longint = 0;

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

{ Check if specific key is pressed }
function zmack(cisl: byte): boolean;
begin
  zmack := False;

  case cisl of
    1: zmack := (IsKeyDown(KEY_UP) <> 0);      { Up }
    2: zmack := (IsKeyDown(KEY_DOWN) <> 0);    { Down }
    3: zmack := (IsKeyDown(KEY_LEFT) <> 0);    { Left }
    4: zmack := (IsKeyDown(KEY_RIGHT) <> 0);   { Right }
    5: zmack := (IsKeyDown(KEY_ESCAPE) <> 0);  { ESC }
    6: zmack := (IsKeyDown(KEY_ENTER) <> 0);   { Enter }
    32: zmack := (IsKeyDown(KEY_SPACE) <> 0);   { Space }
  end;
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

{ Directional input handling }
procedure sipky(var sipx, sipy: integer; var kluc: word);
begin
  kluc := 0;
  sipx := 0;
  sipy := 0;

  { Check arrow keys and set direction }
  if IsKeyDown(KEY_LEFT) <> 0 then
  begin
    sipx := -1;
    kluc := kb_left;
  end
  else if IsKeyDown(KEY_RIGHT) <> 0 then
  begin
    sipx := 1;
    kluc := kb_right;
  end
  else if IsKeyDown(KEY_UP) <> 0 then
  begin
    sipy := -1;
    kluc := kb_up;
  end
  else if IsKeyDown(KEY_DOWN) <> 0 then
  begin
    sipy := 1;
    kluc := kb_down;
  end;

  { Check special keys }
  if IsKeyDown(KEY_ESCAPE) <> 0 then
    kluc := kb_esc
  else if IsKeyDown(KEY_ENTER) <> 0 then
    kluc := kb_enter
  else if IsKeyDown(KEY_SPACE) <> 0 then
    kluc := kb_space;
end;

{ Simulate key press for movement }
procedure sipka_fake(pseudo: word; var sipx, sipy: word);
begin
  case pseudo of
    kb_left:  dec(sipx);
    kb_right: inc(sipx);
    kb_up:    dec(sipy);
    kb_down:  inc(sipy);
  end;
end;

{ Extended directional input with step }
function sipka_fakex(pseudo, step: word; var sipx, sipy: word): boolean;
begin
  sipka_fakex := True;
  
  case pseudo of
    kb_left:
      if sipx >= step then
        dec(sipx, step)
      else
        sipka_fakex := False;
        
    kb_right:
      if sipx <= 640 - step then
        inc(sipx, step)
      else
        sipka_fakex := False;
        
    kb_up:
      if sipy >= step then
        dec(sipy, step)
      else
        sipka_fakex := False;
        
    kb_down:
      if sipy <= 480 - step then
        inc(sipy, step)
      else
        sipka_fakex := False;
  end;
end;

{ Directional input with custom step size }
function sipka_fake2(pseudo: word; var sipx, sipy: word; krok: word): boolean;
begin
  sipka_fake2 := sipka_fakex(pseudo, krok, sipx, sipy);
end;

end.
