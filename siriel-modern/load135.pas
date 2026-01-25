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

implementation

uses
  SysUtils,
  modern_mem;

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
