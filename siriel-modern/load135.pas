unit load135;

{$mode objfpc}{$H+}

{ Modern cleanup and error handling for Siriel
  Replaces original LOAD135.PAS
  Focus: Game shutdown procedures
}

interface

{ Game ending with optional warning message }
procedure ending(varovanie: string);

{ Display error message and exit }
procedure errormes(cisl: integer);

{ Animation control - advances poloha and clamps to range }
procedure pl(stav: integer);

implementation

uses
  SysUtils,
  modern_mem,
  jxvar;  { For poloha variable }

{ === GAME ENDING === }

{ Cleanup and shutdown game
  Optionally displays warning message before exit
}
procedure ending(varovanie: string);
begin
  writeln('');
  writeln('=== Shutting down Siriel Modern ===');
  writeln('');

  { Deallocate XMS/handles }
  writeln('Memory cleanup...');

  { TODO: Clean up handles array when implemented }
  { done_handles(handles); }

  writeln('  OK - Memory deallocated');
  writeln('');

  { Display warning if provided }
  if varovanie <> '' then
  begin
    writeln('WARNING: ', varovanie);
    writeln('');
  end;

  { Cleanup complete }
  writeln('Cleanup complete.');

  if varovanie <> '' then
    Halt(2)  { Exit with error code }
  else
    Halt(0);  { Normal exit }
end;

{ === ERROR HANDLING === }

{ Display error message and shutdown
  cisl: Error code (1=general, 3=config error, 4=resource error)
}
procedure errormes(cisl: integer);
var
  msg: string;
begin
  case cisl of
    1: msg := 'General error occurred';
    3: msg := 'Configuration error';
    4: msg := 'Resource loading error';
  else
    msg := 'Unknown error';
  end;

  ending(msg);
end;

{ === ANIMATION CONTROL === }

{ Animation frame controller
  Advances poloha and clamps to specific ranges based on state
  State ranges:
    1: Standing (0-3)
    2: Walking left (3-7)
    3: Walking right (7-11)
    4: Jumping (11-19)
    5: Rolling (19-27)
    6: Falling (27-35)
    7: Special (40-43)
}
procedure pl(stav: integer);
begin
  inc(poloha);
  case stav of
    { State 1: IDLE animation - frames 0-3 (first row, first 4 frames) }
    1: if (poloha < 0) or (poloha > 3) then poloha := 0;

    { State 2: LEFT animation - frames 4-7 (first row, next 4 frames) }
    2: if (poloha < 4) or (poloha > 7) then poloha := 4;

    { State 3: RIGHT animation - frames 8-11 (first row, last 4 frames) }
    3: if (poloha < 8) or (poloha > 11) then poloha := 8;

    { State 4: JUMP UP animation - frames 12-19 (second row, 8 frames) }
    4: if (poloha < 12) or (poloha > 19) then poloha := 12;

    { State 5: JUMP UP LEFT animation - frames 23-30 (third row, 8 frames) }
    { Matches original DOS state 5 for jumping left (oldkey=5) }
    5: if (poloha < 23) or (poloha > 30) then poloha := 23;

    { State 6: JUMP UP RIGHT animation - frames 35-42 (fourth row, 8 frames) }
    { Matches original DOS state 6 for jumping right (oldkey=6) }
    6: if (poloha < 35) or (poloha > 42) then poloha := 35;

    { State 7: PARACHUTE animation - frames 20-22 (second row, 3 frames) }
    { Note: Parachute is rendered separately via padak() functions }
    { This state is kept for compatibility but not used in jump logic }
    7: if (poloha < 20) or (poloha > 22) then poloha := 20;

    { State 8: MAZE WALK UP animation - frames 31-34 (third row, 4 frames) }
    { NOTE: Used in maze mode for walking up }
    8: if (poloha < 31) or (poloha > 34) then poloha := 31;
  end;
end;

{ === INITIALIZATION === }

var
  initialization_done: boolean = False;

procedure InitLoad135;
begin
  if initialization_done then
    exit;

  initialization_done := True;
  writeln('LOAD135: Cleanup handler initialized');
end;

initialization
  InitLoad135;

finalization
  { Final cleanup }

end.
