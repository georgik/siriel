unit collision;

{$mode objfpc}{$H+}

{ Collision Detection System - EXACT PORT from original SI35.PAS
  This is the EXACT collision detection and movement system from the original game.
  Ported from:
  - SI35.PAS lines 13-29 (incsx, gravitacia)
  - SI35.PAS lines 67-91 (smeruj)
  - POCHECK3.INC (po, po3)

  DO NOT MODIFY these functions - they are the core gameplay mechanics!
}

interface

uses
  SysUtils,
  jxvar,
  aktiv35,
  geo,
  animing;

{ ========================================
   EXACT PORTS from SI35.PAS lines 13-29
   ======================================== }

procedure incsx(plus: word; var pr: predmet; speed: word);

function gravitacia(var pr: predmet): boolean;

{ ========================================
   EXACT PORT from SI35.PAS lines 67-91
   ======================================== }

function smeruj(num: word; var step, x, y: word; test_texture: boolean): boolean;
  {TRUE ak moze prejst}

{ ========================================
   EXACT PORTS from POCHECK3.INC
   ======================================== }

function po(a1, a2: word): boolean;

function po3(a1, a2: integer): boolean;

implementation

{ ========================================
   EXACT PORT from SI35.PAS lines 13-21
   ======================================== }

procedure incsx(plus: word; var pr: predmet; speed: word);
begin
  case plus of
    0: sipka_fake2($4b00, pr.x, pr.y, speed);
    1: sipka_fake2($4d00, pr.x, pr.y, speed);
    2: sipka_fake2($4800, pr.x, pr.y, speed);
    3: sipka_fake2($5000, pr.x, pr.y, speed);
  end;
end;

{ ========================================
   EXACT PORT from SI35.PAS lines 22-29
   ======================================== }

function gravitacia(var pr: predmet): boolean;
begin
  gravitacia := false;
  if po3(pr.x + 4, pr.y) and po3(pr.x - 12, pr.y) then
  begin
    incsx(3, pr, pr.inf1);
    gravitacia := true;
  end;
end;

{ ========================================
   EXACT PORT from SI35.PAS lines 67-91
   ======================================== }

function smeruj(num: word; var step, x, y: word; test_texture: boolean): boolean;
  {TRUE ak moze prejst}
var
  b: boolean;
  x1, y1, x2, y2, x3, y3: word;
begin
  x1 := x;
  y1 := y;
  b := sipka_fakex(num, step, x1, y1);
  if (not b) and (test_texture) then
  begin
    x2 := (x1 - 6) div 16;
    y2 := (y1 + 6) div 16;
    x3 := (x1 + 6) div 16;
    y3 := (y1 div 16) + 1;
    if (st.mie[x2, y2] > inusable) or
       (st.mie[x2, y3] > inusable) or
       (st.mie[x3, y2] > inusable) or
       (st.mie[x3, y3] > inusable) then
    begin
      b := true;
    end;
  end;
  if not b then
  begin
    x := x1;
    y := y1;
  end;
  smeruj := b;
end;

{ ========================================
   EXACT PORT from POCHECK3.INC lines 2-12
   ======================================== }

function po(a1, a2: word): boolean;
var
  b1, b2: word;
begin
  po := true;
  inc(a1, 3);
  b1 := a1 div 16;
  b2 := (a2 + 16) div 16;
  if (st.mie[b1, b2] > inusable)
    and (getcol(a1, a2, st.mie[b1, b2], te^) <> 13) then
    po := false;
end;

{ ========================================
   EXACT PORT from POCHECK3.INC lines 14-24
   ======================================== }

function po3(a1, a2: integer): boolean;
var
  b1, b2: word;
begin
  po3 := true;
  b1 := (a1 + 3) div 16;
  b2 := (a2 + 16) div 16;

  if (st.mie[b1, b2] > inusable)
    and (getcol(a1 + 3, a2, st.mie[b1, b2], te^) <> 13) then
    po3 := false;
end;

{ ========================================
   INITIALIZATION
   ======================================== }

var
  initialization_done: boolean = False;

procedure InitCollision;
begin
  if initialization_done then
    exit;

  initialization_done := True;

  writeln('COLLISION: Exact original collision detection loaded');
  writeln('  Functions: po, po3, smeruj, gravitacia, incsx');
end;

initialization
  InitCollision;

finalization
  { Final cleanup }

end.
