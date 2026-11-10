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
  {this routine returns a clock with occassional spikes where time
    will look like its running backwards 1/18th of a second.  The resolution
    of the clock is 1/(18*256) = 1/4608 second.  66 ticks of this clock
    are supposed to be equal to a monitor 1/70 second tick.}
begin end;

  PROCEDURE DrawFrame(Buffer : Pointer; Chunks : Word); 
  {this is the routine that takes a frame and put it on the screen}
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
  VAR
    MainHeader  : MainHeaderRec;
    FrameHeader : FrameHeaderRec;
    FrameSize   : LongInt;
    RestartPos  : LongInt;
    Frame       : Word;
    Timeout     : LongInt;
    nahme,xyz:string;
    founded:boolean;

    FUNCTION ReadHeader : Boolean;
    BEGIN
	BlockRead(FliFile,MainHeader,SizeOf(MainHeader)); {Read header record}
	WITH MainHeader DO
	  IF ID <> $AF11 THEN  begin
	    ReadHeader := false; {Not a .FLI File}

	    end
	  ELSE
	    BEGIN
		IF Interval = -1 THEN {Read speed from header}
		  Interval := Speed * Clock_Scale;
		ReadHeader := TRUE;
	    END;
    END; {ReadHeader}

    PROCEDURE ReadFrame;
    BEGIN
	BlockRead(FliFile,FrameHeader,SizeOf(FrameHeader));
	FrameSize := FrameHeader.Size - SizeOf(FrameHeader);
    END; {ReadFrame}

    PROCEDURE ProcessFrame;
    BEGIN
	BlockRead(FliFile,Buffer^,FrameSize);
	DrawFrame(Buffer,FrameHeader.Chunks);
    END; {ProcessFrame}

  BEGIN {Play}
    frame:=1;
    founded:=true;
	 mov_string(filename,nahme,frame);
	  mov_string(filename,xyz,frame);
    {$I-}
	  if (not (nahme=filename)) and (length(xyz)>1) and (xyz[1]='>') then begin
	   xyz:=out_string(xyz);
	   assign(flifile,nahme);
	   reset(flifile,1);
	  founded:=getblockfile_ext(flifile,xyz)
	 end else begin
	  Assign(FLiFile,nahme);
	  Reset(FliFile,1);
	 end;
	 IF (founded) and (ReadHeader) THEN
	    BEGIN
{	InitClock;}
		ReadFrame;
		RestartPos := SizeOf(MainHeader) + SizeOf(FrameHeader) + FrameSize;
		ProcessFrame;
		  Frame := 1;
		  REPEAT
		    Timeout := GetClock + Interval;
		    ReadFrame;
		    IF FrameSize <> 0 THEN
			ProcessFrame;
		    REPEAT UNTIL GetClock > Timeout;
		    Inc(Frame);
		    if keypressed then k:=key;
		  UNTIL (Frame = MainHeader.Frames) OR (k=$011b);
	    END
            else if founded then write_error('Invalid FLI file: '+nahme+' '+xyz);
	  Close(FliFile);
	   clear_key_buffer;
    {$I+}
  END; {Play}

procedure aaplay(filenam:string);
var anik:^tfliplayer;
begin
  k:=0;
  clear_key_buffer;
  if anik^.init then begin
	    anik^.play(filenam);
	    anik^.done;
  end else write_error('Not enought memory !');
end;

end.