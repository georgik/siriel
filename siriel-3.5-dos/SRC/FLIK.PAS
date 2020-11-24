unit flik;
{$G+,V+}
interface
procedure aaplay(filenam:string);

implementation
uses dos,crt,txt,geo,blockx;
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

  PROCEDURE InitClock; ASSEMBLER; {Taken from the FLILIB source}
  ASM
    mov  al,00110100b
    out  CMode,al
    xor  al,al
    out  CData,al
    out  CData,al
  END; {InitClock}
  FUNCTION GetClock : LongInt; ASSEMBLER; {Taken from the FLILIB source}
  {this routine returns a clock with occassional spikes where time
    will look like its running backwards 1/18th of a second.  The resolution
    of the clock is 1/(18*256) = 1/4608 second.  66 ticks of this clock
    are supposed to be equal to a monitor 1/70 second tick.}
  ASM
    mov  ah,0                  {get tick count from Dos and use For hi 3 Bytes}
    int  01ah                  {lo order count in DX, hi order in CX}
    mov  ah,dl
    mov  dl,dh
    mov  dh,cl
    mov  al,0                  {read lo Byte straight from timer chip}
    out  CMode,al              {latch count}
    mov  al,1
    out  CMode,al              {set up to read count}
    in   al,CData              {read in lo Byte (and discard)}
    in   al,CData              {hi Byte into al}
    neg  al                    {make it so counting up instead of down}
  END; {GetClock}

  PROCEDURE DrawFrame(Buffer : Pointer; Chunks : Word); ASSEMBLER;
  {this is the routine that takes a frame and put it on the screen}
  ASM
    cli                        {disable interrupts}
    push ds
    push es
    lds  si,Buffer             {let DS:SI point at the frame to be drawn}
  @Fli_Loop:                   {main loop that goes through all the chunks in a
frame}
    cmp  Chunks,0              {are there any more chunks to draw?}
    je   @Exit
    dec  Chunks                {decrement Chunks For the chunk to process now}
    mov  ax,[Word ptr ds:si+4] {let AX have the ChunkType}
    add  si,6                  {skip the ChunkHeader}
    cmp  ax,0Bh                {is it a FLI_COLor chunk?}
    je   @Fli_Color
    cmp  ax,0Ch                {is it a FLI_LC chunk?}
    je   @Fli_Lc
    cmp  ax,0Dh                {is it a FLI_BLACK chunk?}
    je   @Fli_Black
    cmp  ax,0Fh                {is it a FLI_BRUN chunk?}
    je   @Fli_Brun
    cmp  ax,10h                {is it a FLI_COPY chunk?}
    je   @Fli_Copy
    jmp  @Fli_Loop             {This command should not be necessary }
  @Fli_Color:
    mov  bx,[Word ptr ds:si]   {number of packets in this chunk (always 1?)}
    add  si,2                  {skip the NumberofPackets}
    mov  al,0                  {start at color 0}
    xor  cx,cx                 {reset CX}
  @Color_Loop:
    or   bx,bx                 {set flags}
    jz   @Fli_Loop             {Exit if no more packages}
    dec  bx                    {decrement NumberofPackages For the package to
process now}
    mov  cl,[Byte ptr ds:si+0] {first Byte in packet tells how many colors to
skip}
    add  al,cl                 {add the skiped colors to the start to get the
new start}
    mov  dx,$3C8               {PEL Address Write Mode Register}
    out  dx,al                 {tell the VGA card what color we start changing}
    inc  dx                    {at the port abow the PEL_A_W_M_R is the PEL
Data Register}
    mov  cl,[Byte ptr ds:si+1] {next Byte in packet tells how many colors to
change}
    or   cl,cl                 {set the flags}
    jnz  @Jump_Over            {if NumberstoChange=0 then NumberstoChange=256}
    inc  ch                    {CH=1 and CL=0 => CX=256}
  @Jump_Over:
    add  al,cl                 {update the color to start at}
    mov  di,cx                 {since each color is made of 3 Bytes (Red, Green
& Blue) we have to -}
    shl  cx,1                  {- multiply CX (the data counter) With 3}
    add  cx,di                 {- CX = old_CX shl 1 + old_CX   (the fastest way
to multiply With 3)}
    add  si,2                  {skip the NumberstoSkip and NumberstoChange
Bytes}
    rep  outsb                 {put the color data to the VGA card FAST!}
    jmp  @Color_Loop           {finish With this packet - jump back}
  @Fli_Lc:
    mov  ax,0A000h
    mov  es,ax                 {let ES point at the screen segment}
    mov  di,[Word ptr ds:si+0] {put LinestoSkip into DI -}
    mov  ax,di                 {- to get the offset address to this line we
have to multiply With 320 -}
    shl  ax,8                  {- DI = old_DI shl 8 + old_DI shl 6 -}
    shl  di,6                  {- it is the same as DI = old_DI*256 + old_DI*64
= old_DI*320 -}
    add  di,ax                 {- but this way is faster than a plain mul}
    mov  bx,[Word ptr ds:si+2] {put LinestoChange into BX}
    add  si,4                  {skip the LinestoSkip and LinestoChange Words}
    xor  cx,cx                 {reset cx}
  @Line_Loop:
    or   bx,bx                 {set flags}
    jz   @Fli_Loop             {Exit if no more lines to change}
    dec  bx
    mov  dl,[Byte ptr ds:si]   {put PacketsInLine into DL}
    inc  si                    {skip the PacketsInLine Byte}
    push di                    {save the offset address of this line}
  @Pack_Loop:
    or   dl,dl                 {set flags}
    jz   @Next_Line            {Exit if no more packets in this line}
    dec  dl
    mov  cl,[Byte ptr ds:si+0] {put BytestoSkip into CL}
    add  di,cx                 {update the offset address}
    mov  cl,[Byte ptr ds:si+1] {put BytesofDatatoCome into CL}
    or   cl,cl                 {set flags}
    jns  @Copy_Bytes           {no SIGN means that CL number of data is to come
-}
					 {- else the next data should be put -CL number
of times}
    mov  al,[Byte ptr ds:si+2] {put the Byte to be Repeated into AL}
    add  si,3                  {skip the packet}
    neg  cl                    {Repeat -CL times}
    rep  stosb
    jmp  @Pack_Loop            {finish With this packet}
  @Copy_Bytes:
    add  si,2                  {skip the two count Bytes at the start of the
packet}
    rep  movsb
    jmp  @Pack_Loop            {finish With this packet}
  @Next_Line:
    pop  di                    {restore the old offset address of the current
line}
    add  di,320                {offset address to the next line}
    jmp  @Line_Loop
  @Fli_Black:
    mov  ax,0A000h
    mov  es,ax                 {let ES:DI point to the start of the screen}
    xor  di,di
    mov  cx,32000              {number of Words in a screen}
    xor  ax,ax                 {color 0 is to be put on the screen}
    rep  stosw
    jmp  @Fli_Loop             {jump back to main loop}
  @Fli_Brun:
    mov  ax,0A000h
    mov  es,ax                 {let ES:DI point at the start of the screen}
    xor  di,di
    mov  bx,200                {numbers of lines in a screen}
    xor  cx,cx
  @Line_Loop2:
    mov  dl,[Byte ptr ds:si]   {put PacketsInLine into DL}
    inc  si                    {skip the PacketsInLine Byte}
    push di                    {save the offset address of this line}
  @Pack_Loop2:
    or   dl,dl                 {set flags}
    jz   @Next_Line2           {Exit if no more packets in this line}
    dec  dl
    mov  cl,[Byte ptr ds:si]   {put BytesofDatatoCome into CL}
    or   cl,cl                 {set flags}
    js   @Copy_Bytes2          {SIGN meens that CL number of data is to come -}
					 {- else the next data should be put -CL number
of times}
    mov  al,[Byte ptr ds:si+1] {put the Byte to be Repeated into AL}
    add  si,2                  {skip the packet}
    rep  stosb
    jmp  @Pack_Loop2           {finish With this packet}
  @Copy_Bytes2:
    inc  si                    {skip the count Byte at the start of the packet}
    neg  cl                    {Repeat -CL times}
    rep  movsb
    jmp  @Pack_Loop2           {finish With this packet}
  @Next_Line2:
    pop  di                    {restore the old offset address of the current
line}
    add  di,320                {offset address to the next line}
    dec  bx                    {any more lines to draw?}
    jnz  @Line_Loop2
    jmp  @Fli_Loop             {jump back to main loop}
  @Fli_Copy:
    mov  ax,0A000h
    mov  es,ax                 {let ES:DI point to the start of the screen}
    xor  di,di
    mov  cx,32000              {number of Words in a screen}
    rep  movsw
    jmp  @Fli_Loop             {jump back to main loop}
  @Exit:
    sti                        {enable interrupts}
    pop  es
    pop  ds
  END; {DrawFrame}

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
		    if keypressed>0 then k:=key;
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