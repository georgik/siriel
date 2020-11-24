unit jxzvuk;
interface
uses smix,detect2,geo,txt,crt,blockx,jxgraf;

const Max_NumSounds = 20;
	SharedEMB     = true;
	Nos           = 'NOSOUND';
	def_zvuk_sub  = 'MAIN.DAT';

var
    zvuky:array[1..Max_NumSounds] of string[10];
    NumSounds,xms_memory,num_snd:word;
    Zvuk:boolean;
    zvukovy_subor:string[20];
    BaseIO: word; IRQ, DMA, DMA16: byte;
    Sound: array[0..Max_NumSounds-1] of PSound;
    OldExitProc: pointer;

function HexW(W: word): string; {Word}
{procedure OurExitProc; far;}
procedure LoadSounds;
procedure FreeSounds;
procedure Initsbx;
procedure Shutdown;
procedure pust(num:word);
procedure pust2(num:word);
procedure reload_sound(num:word;meno_suboru,meno_hlavy:string);
procedure set_numsounds(num:word);
procedure set_zvuk(x:boolean);    {ci je mozne prehrat zvuk}


implementation
procedure set_zvuk(x:boolean);    {ci je mozne prehrat zvuk}
begin
     zvuk:=x;
end;

procedure set_numsounds(num:word);
var f:word;
begin
   NumSounds    :=    num;
   num_snd      :=    num;
   for f:=1 to max_numsounds do zvuky[f]:=nos;
end;


  function HexW(W: word): string; {Word}
    const
	HexChars: array [0..$F] of Char = '0123456789ABCDEF';
    begin
      HexW :=
{        HexChars[(W and $F000) shr 12] +}
        HexChars[(W and $0F00) shr 8]  +
        HexChars[(W and $00F0) shr 4]  +
	  HexChars[(W and $000F)];
    end;

  procedure OurExitProc; far;
    var
      i: byte;
    begin
      for i := 0 to NumSounds-1 do
        if Sound[i] <> nil then FreeSound(Sound[i]);
      if SharedEMB then ShutdownSharing;
      ExitProc := OldExitProc; {Chain to next exit procedure}
    end;

  procedure LoadSounds;
    var
      i: integer;
    begin
	if zvuk then begin
      if not(InitXMS)
	  then
	    begin
            writeln('Chyba pri inicializacii extendnej pamate');
            writeln('HIMEM.SYS musi byt instalovany');
            Halt(3); {XMS driver not installed}
          end
        else
          begin
		writeln('Extendna pamat bola uspesne inicializivana');
            write('Volna XMS:  ', GetFreeXMS, 'k  ');
            if GetFreeXMS < XMS_memory
              then
                begin
			writeln('Nedostaok volnej XMS');
			writeln('Pravdepodobne ste spustili program v chranenom mode IDE');
                  writeln('Skuste spustit z prikazoveho riadku alebo kontaktujte autora');
			Halt(4); {Insufficient XMS memory}
                end
              else
                begin
                  writeln('Nahravam zvuky');
                  if SharedEMB then InitSharing;

                  if not(OpenSoundResourceFile(zvukovy_subor))
			  then
                      begin
				writeln('CHYBA ! Zvukovy subor neexistuje !');
				Halt(5); {Sound resource file does not exist}
			    end;

	    for i:=1 to num_snd do
		  if zvuky[i]=nos then begin
		     closesoundresourcefile;
		     opensoundresourcefile(def_zvuk_sub);
		     loadsound(sound[i-1],nos);
		     closesoundresourcefile;
		     opensoundresourcefile(zvukovy_subor);
		  end
		  else
		  if zvuky[i]<>'' then LoadSound(sound[i-1], zvuky[i]);

			CloseSoundResourceFile;

			OldExitProc := ExitProc;
			ExitProc := @OurExitProc;
			writeln('Zvuky... OK');
		    end
          end;
	  end;
    end;

  procedure FreeSounds;
    var
      i: integer;
    begin
      if zvuk then begin
	for i := 0 to NumSounds-1 do
        FreeSound(Sound[i]);
      if SharedEMB then ShutdownSharing;
     end;
    end;

  procedure Initsbx;
    begin
	if zvuk then begin
      writeln;
      writeln('Autodetekcia zvukovej karty');
      if not(GetSettings(BaseIO, IRQ, DMA, DMA16))
        then
          begin
            writeln('Chyba pri inicializacii: nespravne prostredie pre Blaster');
            Halt(1); {BLASTER environment variable invalid or non-existant}
	    end;

      if not(InitSB(BaseIO, IRQ, DMA, DMA16))
        then
          begin
		writeln('Chyba pri inicializacii zvukovej karty');
		writeln('Nespravna IO adresa.' );
            writeln('Mozne riesenia:');
		writeln('     - nastavte vacsi Init time v Setupe');
            writeln('     - skuste resetnut pocitac');
            Halt(2); {Sound card could not be initialized}
          end;

      writeln('BaseIO=', HexW(BaseIO), 'h     IRQ', IRQ, '     DMA8=', DMA, '     DMA16=', DMA16);
      write('DSP:', DSPVersion shr 8, '.', DSPVersion and $FF, ':  ');

	if SixteenBit
        then write('16-bit, ')
        else write('8-bit, ');
      if AutoInit
        then writeln('Auto-inicializacia')
	  else writeln('Jednoduchy cyklus');

	InitMixing;
	end;
    end;

  procedure Shutdown;
    begin
     if zvuk then begin
	ShutdownMixing;
	ShutdownSB;
     end;

    end;

procedure pust(num:word);
begin
     if zvuk then
	startsound(sound[num],num,false);
end;

procedure pust2(num:word);
begin
  if zvuk then begin
	pust(num);
	pulzx(10);
	clear_key_buffer;
{	  k:=0;
	  clear_key_buffer;
   pust(num);
   repeat
     if keypressed then begin
	  k:=key;
	  clear_key_buffer;
     end;
   until (not soundplaying(num)) or (k=$011b);
	k:=0;}
  end;
end;

procedure reload_sound(num:word;meno_suboru,meno_hlavy:string);
begin
  if zvuk then begin
   if meno_hlavy=NOS then meno_suboru:=def_zvuk_sub else
	meno_suboru:=zvukovy_subor;
{   if checkblock_info(meno_suboru,meno_hlavy) then begin}
    if sound[num]<>nil then begin
	   if soundplaying(num) then stopsound(num);
	 freesound(sound[num]);
   end;
    opensoundresourcefile(meno_suboru);
    loadsound(sound[num],meno_hlavy);
    closesoundresourcefile;
{   end;}
  end;
end;

begin
     zvuk          := false;
     zvukovy_subor := def_zvuk_sub;
     num_snd       := 16;
     NumSounds     := 16;
end.