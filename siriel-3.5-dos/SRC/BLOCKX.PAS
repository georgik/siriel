unit blockx;
{$G+}

interface
uses txt,dos,crt,jxgraf,geo;

    type
      TKey = array[1..8] of char;
      gbuf = array[0..767] of byte;
var
      SoundFile : file;

function  checkblock_info(sub,key:string):boolean;
function  checkblock_header(filename:string):boolean;
procedure close_all_files;
function  OpenblockFile(FileName: string): boolean;
procedure CloseblockFile;

procedure CloseblockFile_ext(var fil:file);
function  GetBlockFile_ext(var fil:file;Key: string):boolean;

function  MatchingKeys(a, b: TKey): boolean;
procedure GetBlockFile(Key: string);
function  Min(a, b: LongInt): LongInt;
function  Loadblock_array(sub,kluc:string;var xdata:array of byte): boolean;
function  getblock_out(sub,kluc,vystup:string):boolean;

function  draw_gif_block(bitmap : pimage;file_name,kluc : string;fromx, fromy : word;var pal : tpalette) : boolean;
procedure Font_Load_block(fmeno,kluc:string;var fx,fy:word);
procedure load_palette_block(sub,kluc:string;var palx:tpalette);

implementation
      const loadchunksize=256;

    var
      ResourceFile     : boolean;
      ResourceFilename : string;
      SoundSize : LongInt;
      files_counter:word;
	k:word;
      t:text;

function checkblock_info(sub,key:string):boolean;
      type
	  Resource =
          record
            Key:   TKey;
		Start: LongInt;
		Size:  LongInt;
	    end;
	var
	  NumSounds: integer;
	  ResKey:    TKey;
	  ResHeader: Resource;
	  Index:     integer;
	  i:         integer;
	  Found:     boolean;
	  fil:file;
	begin
{$I-}
		  Found := false;
	if checkblock_header(sub) then begin
		  for i := 1 to 8 do
		    if i <= Length(Key)
			then ResKey[i] := Key[i]
			else ResKey[i] := #0;

		  Assign(Fil, sub);  Reset(Fil, 1);
		  BlockRead(Fil, NumSounds, SizeOf(NumSounds));

		  Index := 0;

		  while not(Found) and (Index < NumSounds) do
                begin
                  Index := Index + 1;
                  BlockRead(Fil, ResHeader, SizeOf(ResHeader));

			if MatchingKeys(ResHeader.Key, ResKey)
                    then
                      Found := true;
                end;
            close(fil);
       end;
            checkblock_info:=found;
{$I+}
end;

function checkblock_header(filename:string):boolean;
var ch:char;
    t:text;
begin
{$I-}
  checkblock_header:=false;
  assign(t,filename);
  reset(t);
  read(t,ch);
  read(t,ch);
  if ord(ch)=0 then checkblock_header:=true;
  close(t);
{$I+}
end;

    procedure close_all_files;
    var fl:integer;
    begin
      {$I-}
    if files_counter<0 then files_counter:=0;
    if files_counter>0 then begin
       for fl:=1 to files_counter do
           close(soundfile);
       files_counter:=0;
       end;
      {$I+}
    end;

    function OpenblockFile(FileName: string): boolean;
	begin
	  ResourceFile     := true;
	  ResourceFilename := FileName;
	  files_counter:=0;

	  OpenblockFile := subor_exist(FileName);
      end;

    procedure CloseblockFile;
      begin
        ResourceFile     := false;
        ResourceFilename := '';
        close_all_files;
      end;

    procedure CloseblockFile_ext(var fil:file);
	begin
	  ResourceFile     := false;
	  ResourceFilename := '';
         {$I-}
	  close(fil);
         {$I+}
	end;


    function MatchingKeys(a, b: TKey): boolean;
      var
        i: integer;
      begin
        MatchingKeys := true;

        for i := 1 to 8 do
          if a <> b
            then
              MatchingKeys := false;
      end;

    procedure GetBlockFile(Key: string);
      type
        Resource =
          record
            Key:   TKey;
            Start: LongInt;
            Size:  LongInt;
          end;
      var
        NumSounds: integer;
        ResKey:    TKey;
        ResHeader: Resource;
        Index:     integer;
        i:         integer;
        Found:     boolean;
      begin
        if ResourceFile
           {$I-}
          then
            begin
              for i := 1 to 8 do
                if i <= Length(Key)
                  then ResKey[i] := Key[i]
                  else ResKey[i] := #0;
              Assign(SoundFile, ResourceFilename);  Reset(SoundFile, 1);
{              inc(files_counter);}
              BlockRead(SoundFile, NumSounds, SizeOf(NumSounds));

              Found := false;
              Index := 0;

              while not(Found) and (Index < NumSounds) do
                begin
                  Index := Index + 1;
                  BlockRead(SoundFile, ResHeader, SizeOf(ResHeader));

                  if MatchingKeys(ResHeader.Key, ResKey)
                    then
                      Found := true;
                end;

              if Found
                then
                  begin
                    Seek(SoundFile, ResHeader.Start);
                    SoundSize := ResHeader.Size;
                  end
                else
                  SoundSize := 0;
            end
{          else
            begin
              Assign(SoundFile, Key);  Reset(SoundFile, 1);
		  inc(files_counter);
		  SoundSize := FileSize(SoundFile);
		end;      }
	{$I+}
	end;

    function GetBlockFile_ext(var fil:file;Key: string):boolean;
	type
	  Resource =
	    record
		Key:   TKey;
		Start: LongInt;
		Size:  LongInt;
	    end;
	var
	  NumSounds: integer;
	  ResKey:    TKey;
	  ResHeader: Resource;
	  Index:     integer;
	  i:         integer;
	  Found:     boolean;
	begin
{$I-}	  		  for i := 1 to 8 do
		    if i <= Length(Key)
			then ResKey[i] := Key[i]
			else ResKey[i] := #0;

	    {	  Assign(fil, ResourceFilename);}  Reset(fil, 1);
		  BlockRead(Fil, NumSounds, SizeOf(NumSounds));

		  Found := false;
		  Index := 0;

		  while not(Found) and (Index < NumSounds) do
		    begin
			Index := Index + 1;
			BlockRead(Fil, ResHeader, SizeOf(ResHeader));

			if MatchingKeys(ResHeader.Key, ResKey)
			  then
			    Found := true;
		    end;

		  if Found
		    then
			begin
			  Seek(Fil, ResHeader.Start);
		    {	  SoundSize := ResHeader.Size;}
			end
		    else
                    write_error('Header not found: '+key);
{$I+}		   { 	SoundSize := 0;}
                 GetBlockFile_ext:=found;
		end;
	{end;}

function Min(a, b: LongInt): LongInt;
	begin
	  if a < b
          then Min := a
          else Min := b;
      end;

function Loadblock_array(sub,kluc:string;var xdata:array of byte): boolean;
      type
          dat_typ=array[1..loadchunksize] of byte;

      var
        Size: LongInt;
        Remaining,par,ffl: LongInt;
        fl:word;
        dato:^dat_typ;
      begin
       if subor_exist(sub) then begin
{$I-}   openblockfile(sub);
        new(dato);
        upcased(kluc,kluc);
        Loadblock_array := false;
        GetblockFile(Kluc);

        if (SoundSize = 0)
          then exit;

        Remaining := SoundSize;
        ffl:=0;
        repeat
          par:=Min(Remaining, LoadChunkSize);
          BlockRead(SoundFile, dato^, par);
          for fl:=1 to par do begin
              xdata[ffl]:=dato^[fl];
              inc(ffl);
          end;
          Dec(Remaining, par);
        until not(Remaining > 0);

{       dec(files_counter);}
        Close(SoundFile);

        Loadblock_array := true;
{$I+}        dispose(dato);
    end else write_error('Block file does not exist !');
end;

function getblock_out(sub,kluc,vystup:string):boolean;
      type
          dat_typ=array[1..loadchunksize] of byte;

      var
        Size: LongInt;
        Remaining,par,ffl: LongInt;
        fl:word;
        dato:^dat_typ;
      begin
{$I-}        openblockfile(sub);
        new(dato);
        upcased(kluc,kluc);
        getblock_out := false;
        GetblockFile(Kluc);

        if (SoundSize = 0)
          then exit;

        Remaining := SoundSize;
        ffl:=0;
        assign(t,vystup);
        rewrite(t);
        repeat
          par:=Min(Remaining, LoadChunkSize);
          BlockRead(SoundFile, dato^, par);
          for fl:=1 to par do begin
              write(t,chr(dato^[fl]));
          end;
          Dec(Remaining, par);
        until not(Remaining > 0);
        close(t);
       dec(files_counter);
        Close(SoundFile);

        getblock_out := true;
{$I+}        dispose(dato);
end;


{-----font}
procedure get_parax(var s,vystup:string;var num:word);
begin
     vystup:='';
     repeat
      if (s[num]<>' ') and (s[num]<>chr(0)) then vystup:=vystup+s[num];
      inc(num);
     until (num>length(s)) or (s[num]=' ') or (s[num]=chr(0));
end;

procedure Font_Load_block(fmeno,kluc:string;var fx,fy:word);
type flont=array[1..4107] of byte;

var flx:^flont;
    st1,st2:string;
    num,f,fdlzka,ftransf:word;

begin
 new(flx);
 loadblock_array(fmeno,kluc,flx^);
 num:=1;
 st1:='';
 repeat
   if flx^[num]<>0 then st1:=st1+chr(flx^[num]);
   inc(num);
 until flx^[num]=0;
 num:=1;
 get_parax(st1,st2,num);
 val(st2,fdlzka,fdlzka);
 get_parax(st1,st2,num);
 val(st2,fx,fx);
 get_parax(st1,st2,num);
 val(st2,fy,fy);
 get_parax(st1,st2,num);
 val(st2,ftransf,ftransf);
 for f:=1 to fdlzka do begin
     fontik[f]:=flx^[f+num];
 end;

 dispose(flx);
 setstartchar(-ftransf);
 SetFont (@fontik,fx,fy);
end;


{--------------------DRAW GIF-------------------------}


function draw_gif_block(bitmap : pimage;file_name,kluc : string;fromx, fromy : word;var pal : tpalette) : boolean;

type thashbyte = array[0..4095] of byte;
     thashword = array[0..4095] of integer;

var
      GifError                : integer;
      WorkSpace1, WorkSpace2  : ^thashbyte;
      WorkSpace3              : ^thashword;
      StringHashtable         : (*Array [0..9972] Of Integer;*)
                                array[0..1] of integer;
      Interlaced              : Boolean;
      ImageWidth, ImageHeight : Integer;
      ImageColorDepth         : Byte;
      ImagePaletteSize        : Integer;
      ColorBits               : Byte;
      GifBlock                : Array [0..255] Of Byte;
      GifBlockindex           : Word;
      NumStrings              : Word;
      GifHeader               : Record
                                   Signature : Array [1..6] Of char;
                                   ScreenWidth, ScreenHeight : Word;
                                   flags, background, aspect : Byte;
                                End;
      ImageBlock              : Record
                                   Left, Top, Width, Height : Word;
                                   flags : Byte;
                                 End;
      ImageSize: Longint; (*Size of the image, in bytes *)
      gifimage : timagestruct;
  toto : word;
  line_nb :integer;
  line_gif : tline;
  currentx : integer;

function get(var x;nb : word) : boolean;
var toto : word;
begin
     blockread(SoundFile, x, nb, toto);
     (*$ifndef iocheckerror*)
     if ioresult<>0
        then begin
             get:=false;
             exit;
        end;
     (*$endif*)
     if toto<>nb then get:=false else get:=true;
end;

function put(var x;toto : integer) : boolean;
var yo : word;
    dat : array[0..64000] of byte absolute x;
begin
     yo:=0;
     while (yo<toto) do begin
         if dat[yo]=death_color then dat[yo]:=getpixel(bitmap,fromx+currentx,fromy+line_nb);
           line_gif[currentx]:=dat[yo];
           inc(yo);
           inc(currentx);
           if currentx>=gifimage.width then begin
              write_linepos(bitmap, line_gif, fromx, fromy+line_nb, gifimage.width);
              currentx:=0;
           end;
     end;
     put:=true;
end;

Procedure UnpackImage(bitmap : pimage;Bits : Integer);

Type TByteArray = Array [0..0] Of byte;

Var
  bits2, codesize, codesize2, nextcode, thiscode,
  oldtoken, currentcode, oldcode, bitsleft, blocksize,
  pass, byt, p, q, u, i : integer;
  ScanlineDataPos : LongInt;

Const
  wordmasktable : Array [0..15] Of Word =
          ( $0000, $0001, $0003, $0007,
            $000F, $001F, $003F, $007F,
            $00FF, $01FF, $03FF, $07FF,
            $0FFF, $1FFF, $3FFF, $7FFF );
  inctable : Array [0..4] Of Integer = ( 8, 8, 4, 2, 0 );
  starttable : Array [0..4] Of Integer = ( 0, 4, 2, 1, 0 );


Function GetBlock: Boolean;
Begin
  GetBlock := False;
  blocksize:=0;
  If Not Get(blocksize,1) then
     Begin
       GifError := Err_BadRead;
       Exit;
     end;
  If blocksize>0 then
     Begin
       p:=0;
       If Not Get (GifBlock,blocksize) then
          Begin
            GifError := Err_BadRead;
            Exit;
          end;
       q:=blocksize;
       GetBlock := True;
     End
  Else
     Begin
       GifError:=Err_InvalidBlockSize;
       Exit;
     End;
end;

Begin
  pass:=0;
  line_nb:=0;
  byt:=0;
  p:=0;
  q:=0;
  blocksize:=0;
  FillChar (GifBlock, 256, 0);
  bitsleft:=8;
  If (bits<2) Or (bits>8) then Begin
    GifError := Err_BadSymbolSize;
    Exit;
  End;
  bits2    :=1 SHL bits;
  nextcode :=bits2 + 2;
  codesize :=bits + 1;
  codesize2:=1 SHL codesize;
  oldcode  :=-1;
  oldtoken :=-1;
  while True do begin
    if bitsleft=8 then begin
      Inc (p);
      If p>=q then GetBlock;
      If GifError<>Image_Ok then
         Begin
           Exit;
         end;
      bitsleft:=0;
    end;
    thiscode:=GifBlock[p];
    currentcode:=codesize+bitsleft;
    If currentcode<=8 then begin
      GifBlock[p]:=GifBlock[p] shr codesize;
      bitsleft:=currentcode;
    end else begin
      Inc (p);
      If p>=q then
         If Not GetBlock then
            Begin
              Exit;
            end;
      thiscode:=thiscode Or (GifBlock[p] SHL (8-bitsleft));
      If currentcode<=16 then
        bitsleft:=currentcode-8
      else begin
        Inc (p);
        If p>=q then
           If Not GetBlock then Exit;
        thiscode:=thiscode Or (GifBlock[p] SHL (16-bitsleft));
        bitsleft:=currentcode-16;
      end;
      GifBlock[p]:=GifBlock[p] shr bitsleft;
    end;
    thiscode:=thiscode and wordmasktable[codesize];
    currentcode:=thiscode;
    If thiscode=bits2+1 then Break;
    If thiscode > nextcode then Begin
      GifError:=Err_BadGifCode;
      Exit;
    End;
    If thiscode=bits2 then Begin
      nextcode:=bits2+2;
      codesize:=bits+1;
      codesize2:=1 SHL codesize;
      oldtoken:=-1;
      OldCode:=-1;
      Continue;
    End;
    u:=0;
    If thiscode=nextcode then Begin
      If oldcode=-1 then Begin
        GifError:=Err_BadFirstGifCode;
        Exit;
      End;
      WorkSpace1^[u]:=oldtoken;
      Inc (u);
      thiscode:=oldcode;
    End;
    While thiscode>=bits2 Do Begin
      WorkSpace1^[u]:=WorkSpace2^[thiscode];
      Inc (u);
      thiscode:=WorkSpace3^[thiscode];
    End;
    oldtoken:=thiscode;

    while True do begin
      If Not Put (thiscode,1) then
         Begin
           GifError := Err_BadWrite;
           Exit;
         end;
      Inc (byt);
      if byt>=ImageWidth then begin
        byt:=0;
        if Interlaced then begin
          line_nb:=line_nb+inctable[pass];
          if line_nb >= ImageHeight then begin
            Inc (pass);
            line_nb:=starttable[pass];
          end;
(*          If Not SeekOutput (ScanlineDataPos+LongInt (line)*LongInt (ImageWidth)) then
             Begin
               GifError := Err_BadWrite;
               Exit;
             end;*)
        end
        else
          Inc (line_nb);
      end;
      if u<=0 then Break;
      Dec (u);
      thiscode:=WorkSpace1^[u];
    end;
    If (nextcode<4096) And (oldcode<>-1) then Begin
      WorkSpace3^[nextcode]:=oldcode;
      WorkSpace2^[nextcode]:=oldtoken;
      Inc (nextcode);
      If (nextcode>=codesize2) And (codesize<12) then Begin
        Inc (codesize);
        codesize2:=1 SHL codesize;
      End;
    End;
    Oldcode:=currentcode;
  End;
End;

Procedure SkipExtension;

Var
  n, c : Byte;

Begin
  Get (c,1);
  Case c Of
    $01 : Begin
            Get (GifBlock,13);
            Get (n,1);
            While n>0 Do Begin
              Get (GifBlock,n);
              Get (n,1);
            End;
          End;

    $F9 : Get (GifBlock,6);

    $FE : Begin
            Get (n,1);
            While n>0 Do Begin
              Get (GifBlock,n);
              Get (n,1);
            End;
          End;

    $FF : Begin
            Get (GifBlock,12);
            Get (n,1);
            While n>0 Do Begin
              Get (GifBlock,n);
              Get (n,1);
            End;
          End;

    Else Begin
      Get (n,1);
      Get (GifBlock,n);
    End;
  End;
End;


Var
  Background : Byte;
  c : Integer;
  ch : Char;
  i: Word;
  Size: Longint;

Begin
  gif_x:=0;
  gif_y:=0;
  currentx:=0;
  GifError:=0;
  new(workspace1);
  new(workspace2);
  new(workspace3);
{  Assign(InFile, File_Name);
  Reset(InFile,1);}
(*$ifndef iocheckerror*)
  if not subor_exist(file_name) then
     Begin
       draw_Gif_block := false;
       dispose(workspace1);
       dispose(workspace2);
       dispose(workspace3);
       Exit;
     end;
(*$endif*)
        openblockfile(file_name);
        upcased(kluc,kluc);
        GetblockFile(Kluc);

(*  InIndex := MaxSize;*)
  If Not Get(GifHeader,SizeOf(GifHeader)) then
     Begin
       draw_Gif_block := false;
       dispose(workspace1);
       dispose(workspace2);
       dispose(workspace3);
       Exit;
     end;
   gif_x:=GifHeader.ScreenWidth;
   gif_y:=GifHeader.ScreenHeight;
  If (GifHeader.Signature[1]+GifHeader.Signature[2]+GifHeader.Signature[3]<>'GIF') and
     (GifHeader.Signature[1]+GifHeader.Signature[2]+GifHeader.Signature[3]<>'Jx1')
      then
     Begin
       draw_Gif_block := (*Err_NotAGif*)false;
       dispose(workspace1);
       dispose(workspace2);
       dispose(workspace3);
       Exit;
     End;
  ColorBits := GifHeader.Flags And 7+1;
  Background:= GifHeader.Background;
  If GifHeader.Flags And 128=128 then
     Begin
       If Not Get (Pal,3*(1 SHL ColorBits)) then
          Begin
            draw_Gif_block := false;
            dispose(workspace1);
            dispose(workspace2);
            dispose(workspace3);
            Exit;
          end
     end;
  for toto:=0 to 255 do begin
      pal[toto].r:=pal[toto].r shr 2;
      pal[toto].v:=pal[toto].v shr 2;
      pal[toto].b:=pal[toto].b shr 2;
  end;
  With GifHeader do
    Begin
      Size := Longint(ScreenHeight)*Longint(ScreenWidth);
      ImageSize := Size;
    end; (* with *)
  Ch := #0;
  While (ch=',') or (ch='!') or (ch=#0) do begin
    Get (ch,1);
    case ch of
      ',' : begin
              If Not Get(ImageBlock,SizeOf (ImageBlock)) then
                 Begin
                   draw_Gif_block := false;
                   dispose(workspace1);
                   dispose(workspace2);
                   dispose(workspace3);
                   Exit;
                 end;
              if (ImageBlock.flags And 128)=128 then
                 Begin
                   ColorBits:=ImageBlock.Flags And 7+1;
                   If Not Get(pal,3*(1 SHL ColorBits)) then
                      Begin
                        draw_Gif_block := false;
                        dispose(workspace1);
                        dispose(workspace2);
                        dispose(workspace3);
                        Exit;
                      end;
                 End;
              ImageWidth:=ImageBlock.Width;
              ImageHeight:=ImageBlock.Height;
              ImageColorDepth:=ColorBits;
              ImagePaletteSize:=1 SHL ColorBits;
              With GifImage do
                Begin
                  Height := ImageHeight;
                  Width :=  ImageWidth;
                  NumberOfColors := ImagePaletteSize;
                  BitsPerPixel := ColorBits;
                  SizeOfImage := ImageSize;
                  If GifHeader.Signature[5] = '7' then (* GIF87a *)
                     Information := 0
                  Else
                     Information := 1; (* GIF89a *)
                end; (* With *)
              (*Now give the information: *)
(*              GifInfo(GifImage);*)
              Interlaced:=ImageBlock.Flags And 64=64;
              c:=0;
              If Not Get(c,1) then
                 Begin
                   draw_Gif_block := false;
                   dispose(workspace1);
                   dispose(workspace2);
                   dispose(workspace3);
                   Exit;
                 end;
              UnpackImage(bitmap, c);
            End;
      '!' : SkipExtension;
    End;
  End;
  close(SoundFile);
  draw_Gif_block := (giferror=0) ;
  dispose(workspace1);
  dispose(workspace2);
  dispose(workspace3);

end;

procedure load_palette_block(sub,kluc:string;var palx:tpalette);
var f,c:word;
    buf:^gbuf;
begin
{$I-}     new(buf);
        if kluc[1]='>' then begin
           kluc:=out_string(kluc);
           loadblock_array(sub,kluc,buf^);
           c:=0;
           for f:=0 to 767 do begin
               inc(c);
               if c>3 then c:=1;
               case c of
                    1:palx[f div 3].r:=buf^[f+1]shr 2;
                    2:palx[f div 3].v:=buf^[f+1]shr 2;
                    3:palx[f div 3].b:=buf^[f+1]shr 2;
               end;
           end;
        end
        else
        load_palette(kluc,palx,0,255,false);
{$I+}      dispose(buf);
end;



end.
