program editor_pre_Siriela;
uses jxzvuk,jxgraf,editing,geo,aktiv35,crc,crcr35,jxxms,xms2,jxvar,load235,animing,
     blockx,dos,crt,jxmenu,load135,vare;

procedure select_datadisk;
var mex:^jxmenu_typ;
    f,vybr,fl,ff:word;
    fatal:boolean;
label znovku;
begin
   fatal:=false;
   write_palette(blackx,0,256);
   clear_bitmap(screen);
   new(mex);
znovku:
   clear_bitmap(screen);
    init_jxmenu(200,40,0,15,0,tx2[ja,2],mex^);
    for f:=1 to num_disks do begin
	    diskd.meno:='';
	    for ff:=f to num_disks do begin
		    if diskd.meno<data_disks^[ff].meno then begin
			  diskd.meno:=data_disks^[ff].meno;
			  fl:=ff;
		    end;
	    end;
			  diskd:=data_disks^[f];
			  data_disks^[f]:=data_disks^[fl];
			  data_disks^[fl]:=diskd;
    end;
    {swapne to}
    for f:=1 to num_disks div 2 do begin
			  diskd:=data_disks^[f];
			  data_disks^[f]:=data_disks^[num_disks-f+1];
			  data_disks^[num_disks-f+1]:=diskd;
    end;
    for f:=1 to num_disks do begin
		    if data_disks<>nil then
		     vloz_jxmenu2(data_disks^[f].meno,mex^,0);
    end;
     vloz_jxmenu2(tx[ja,6],mex^,0);
  if num_disks>1 then begin
{     increase_palette(blackx,palx,10);}
     old_frame.draw(200,40,12,2+num_disks);
     size_jxmenu(192,288,mex^);
     draw_jxmenu3(mex^);
     write_palette(palx,0,256);
     vyber_jxmenu(mex^,vybr);
  end
  else vybr:=1;
    if (vybr=mex^.pocet) or (vybr=0) then ending('')
    else
    if vybr<mex^.pocet then begin
		zvukovy_subor:=data_disks^[vybr].subor;
		meno_disku:=data_disks^[vybr].meno;
    end;
   if data_disks^[vybr].verzia>ver then begin
	    printc(screen,440,tx3[ja,1],12,0);
	    clear_key_buffer;
	    kkey;
     if num_disks=1 then fatal:=true else
	    goto znovku
   end;
   dispose(mex);
   if fatal then ending('');
end;


procedure load_basic_config;
type polo=array[0..maxlen] of byte;
var pole:^polo;
    f,countx:word;
begin
     set_def;
     new(pole);
     new(data_disks);
		for f:=1 to maxlen do pole^[f]:=0;
		num_disks:=0;
		findfirst('*.dat',$3f,sr);
		repeat
				  if (doserror=0) and (checkblock_info(sr.name,hlavicka)) then begin
					   loadblock_array(sr.name,hlavicka,block_ver);
					   inc(num_disks);
					   for f:=0 to 2 do block_ver[f]:=block_ver[f]-48;
					   data_disks^[num_disks].verzia:=block_ver[0]*100+
								 block_ver[1]*10+block_ver[2];

					   data_disks^[num_disks].subor:=sr.name;
					   data_disks^[num_disks].meno:='';
					   load_level_list(sr.name,pole^);
				  end;
				  findnext(sr);
		until (doserror<>0) or (num_disks>19);
{		 if num_disks=0 then errormes(3);}
		 select_datadisk;
		 load_level_list(zvukovy_subor,pole^);
{		 load_defaults;}
     dispose(data_disks);
     dispose(pole);
     if crc_checking then verify_crc(zvukovy_subor);
end;


procedure load_pohyby;
begin
   draw_gif_block(screen,input_file,pohyby,0,0,palx);
    for f:=0 to 11 do
		    getseg(f*resx,0,resx,resy,f,ar^);
    for f:=0 to 7 do begin
		getseg(f*resx,16,resx,resy,f+12,ar^);
		getseg(f*resx,32,resx,resy,f+20,ar^);
		getseg(f*resx,48,resx,resy,f+28,ar^);
    end;
    for f:=0 to 2 do begin
		getseg(f*resx+128,16,resx,resy,f+36,ar^);
    end;
    for f:=0 to 3 do begin
		getseg(f*resx+128,32,resx,resy,f+40,ar^);
    end;
    for f:=0 to 1 do begin
		getseg(f*resx+128,48,resx,resy,f+44,ar^);
    end;
    for f:=0 to 3 do begin
		getseg(f*resx+160,48,resx,resy,f+47,ar^);
    end;
end;

begin
{   if not subor_exist(cfg_file) then ending(tx3[1,9]);}
   ja:=1;
   miestn:='';

if memavail>minimummem then begin
   writeln;
   writeln('Init...');
     use_joystick:=false;
     initclock;
     randomize;
     init_keyboard(0);
     keyboard_speed(0,0);
{     set_def;}
     zvuk_loaded:=false;
     crc_checking:=true;
{     set_defaults;  {nastavi zakladne parametre prikazoveho modu W}
     scrx:=640;
     scry:=480;
     resx:=16;
     resy:=16;
   {check_crc;      {kontorla CRC pre MIAN.DAT}
   write('XMS...');
   if xmsinstalled then begin
	  writeln(tx[1,23]);
	  writeln('Version:',xmsversion);
	  writeln('XMS free:',xmfreespace);
	  writeln('XMS contig:',xmcontig);
{	  xms_memory:=xmsrequired;}
	  init_handles(max_handles,handles);
	    XMSDriverCheck;
	    GetXMSFunct;
   end
   else begin
	writeln(tx[1,24]);
{	ending('Use HIMEM.SYS or other memory drivers !');}
   end;
   writeln('O.K.');
   write('Locating memory:');
   priechody	:=nil;
   lift		:=nil;
   new(ar);
   new(te);
   new(vec);
   new(anim);
   new(levely);
   create_handle(handles[3],21*pocet_veci+pocet_textov*dlzka_textu
			 +pocet_obr*dlzka_obr);
   create_handle(handles[4],256*vec_count);
   create_handle(handles[5],map_size);
   writeln('O.K.');
   write('Reading siriel3.cfg...');
    {load_config;}
    scrx:=2;
   writeln(' O.K.');
   grafika_init(scrx,scry,8);
    write_palette(blackx,0,256);
    old_frame.init(no_handle,input_file,frame_gif,false);
    napis.init(2,2,15,0,0,true,true);
    napis2.init(2,2,15,0,0,true,false);
    aktivita_snd:=false;
    animabl:=false;
    check_sound:=false;
    set_font(def_font);

    font:=def_font;
{    load_defaults;
    set_def;}
{    bolx:=false;}
    smart_jump:=true;              {SKOK}
   write_palette(blackx,0,256);
   load_pohyby;
   load_basic_config;
   {rerun;}
   write_palette(blackx,0,256);
   tma:=true;

{nahra animovane obrazky}
draw_it(anim_file,0,0);
for ff:=0 to 3 do
 for f:=0 to 19 do begin
   getseg(16*f,ff*16,16,16,f+ff*20,anim^);
 end;
   ja:=2;
   score:=0;
   basic_score:=0;
   gravity:=20;
   rolling:=30;
   write_palette(blackx,0,256);
   restart:=false;
   load_predmet;
   load_anim_def;
   load_texture;
   clear_bitmap(screen);

   sipka_limit(8,9,612,398,4,use_joystick,5,false,false,true,true);
   oldpol:=poloha;

   edit_it;
   credits(version);
   end;
   ending('');
end.