{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit flik;
{$G+,V+}
interface
procedure aaplay(filenam:string);

implementation
uses dos,crt,txt,geo,blockx,dosio;
var k:word;
const
  Clock_Hz     = 4608;                   {Frequency of clock}
  Monitor_Hz   = 70;                     {Frequency of monitor}
  Clock_Scale  = Clock_Hz DIV Monitor_Hz;
  CData        = $40;                    {Port number of timer 0}
  CMode        = $43;                    {Port number of timer control word}
  BufSize      = 65528;                  {Frame buffer size - Must be even}

type
  PFliPlayer = ^TFliPlayer;
  TFliPlayer = OBJECT
    CONSTRUCTOR Init;
    DESTRUCTOR  Done;                      VIRTUAL;
    PROCEDURE   SetSpeed(Speed : Integer); VIRTUAL; {0=Fastest}
    PROCEDURE   ClearSpeed;                VIRTUAL;
    PROCEDURE   Play(Filename : string);   VIRTUAL;
  PRIVATE
    Buffer   : Pointer;
    Interval : Integer;
    FliFile  : File;
  END; {TFliPlayer}

  MainHeaderRec = RECORD
    Padding1 : LongInt;
    ID       : Word;
    Frames   : Word;
    Padding2 : LongInt;
    Padding3 : LongInt;
    Speed    : Word;
    Padding4 : ARRAY[1..110] OF Char; {Pad to 128 Bytes}
  END; {MainHeaderRec}

  FrameHeaderRec = RECORD
    Size     : LongInt;
    Padding1 : Word;
    Chunks   : Word;
    Padding2 : ARRAY[1..8] OF Char; {Pad to 16 Bytes}
  END; {FrameHeaderRec}

  PROCEDURE InitClock;
  begin end;
  FUNCTION GetClock : LongInt;
  {HEADLESS STUB: real FLI playback needs the DOS 4608 Hz tick. There is no
   hardware timer in the headless, C-driven build, so this cannot advance.}
  begin end;

  PROCEDURE DrawFrame(Buffer : Pointer; Chunks : Word);
  {HEADLESS STUB: no FLI/BLD decoder in the headless build.}
  begin end;

  CONSTRUCTOR TFliPlayer.Init;
  BEGIN
    IF MemAvail < BufSize THEN Fail;
    GetMem(Buffer,BufSize);
    ClearSpeed;
  END; {Init}

  DESTRUCTOR TFliPlayer.Done;
  BEGIN
    FreeMem(Buffer,BufSize);
  END; {Done}

  PROCEDURE TFliPlayer.SetSpeed(Speed : Integer);
  BEGIN
    Interval := Speed * Clock_Scale;
  END; {SetSpeed}

  PROCEDURE TFliPlayer.ClearSpeed;
  BEGIN
    Interval := -1;
  END; {ClearSpeed}

  PROCEDURE TFliPlayer.Play(Filename : string);
  BEGIN
    (* HEADLESS STUB: the original looped 'REPEAT UNTIL GetClock > Timeout'
       spins forever because GetClock() is a stub and there is no FLI
       decoder (DrawFrame). play_ani() still performs its graphics/palette
       setup around this call; skipping the animation lets the level start
       instead of hanging. Filename is referenced to avoid an unused warning. *)
    Filename := Filename;
    BEGIN END;
  END; {Play}

var
  flik_filename : string;

procedure aaplay(filenam:string);
begin
  (* HEADLESS STUB: the original dereferenced an unallocated ^TFliPlayer
     (anik) and then ran the stubbed Play loop above -- both hang. We keep
     the clear_key_buffer() drain for parity, record the filename, and return
     immediately so play_ani() finishes its setup and the level begins. *)
  flik_filename := filenam;
  clear_key_buffer;
end;

end.
