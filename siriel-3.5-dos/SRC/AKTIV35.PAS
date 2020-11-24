unit aktiv35;

interface

uses jxgraf,jxmenu,jxxms,jxvar,jxefekt;

const mie_pocet	= 1;
	num_maps	= 20;
	map_size	= 40*27*num_maps;
	start		= 1;
	textured	= 190;
	pocet_veci	= 200;
	pocet_textov= 255;
	dlzka_textu	= 100;
	vec_count	= 255;
	dlzka_obr	= 26;
	posuv_textu	= pocet_veci*21;
	posuv_obr	= posuv_textu+pocet_textov*dlzka_textu;
	pocet_obr	= 64;
	vypisy	= 460;
	vypisx	= 250;
	mie_x		= 38;
	mie_y		= 26;
	anim_nums	= 80;
	sir_nums	= 52;
	sir_buf	= sir_nums-1;
	talkx		= 72;
	talky		= 34;
	max_prechod = 64; 	{pocet prechodov medzi miestnostami}
	max_vytahy  = 64;		{pocet vytahov}

	vlavo		= $4B00;
	vpravo	= $4D00;
	hore		= $4800;
	dole		= $5000;

    XMSRequired   = 4000;
{    SharedEMB     = true;}
type
    prechod = record
			x1,y1,x2,y2	: word; {hranica}
			mie1,mie2	: byte; {zdrojova, cielova miestnost}
			cx,cy		: word; {cielove suradnice}
			used		: boolean;
		  end;

    prechody = array[1..max_prechod] of prechod;

    postava	= record
			x,y,oldx,oldy,buf	: word;
    end;

    animacia 	= array[1..anim_nums*256] of byte;

    long_panak	= array[1..sir_nums*256] of byte;
    long_vec	= array[1..textured*256] of byte;

    predmet	 = record
			 meno:string[5];
			 x,y,x2,y2,x1,y1,mie,st,take,obr,inf1,inf2,inf3,inf4,inf5,inf6,funk,anim,inf7:word;
			 ox,oy,oox,ooy,cislo	: word;
			 z1,z2			: byte;
			 useanim,change,visible,smer : boolean;
			 zas:array[0..255] of byte;
     end;
     stage   = record
		     meno	: string[20];
		     obr	: string[12];
		     mie	: array[0..mie_x,0..mie_y] of byte;
		     stav	: byte;
     end;

    vytah   = record
			mie	: byte;
			x1,y1,x2,y2	: word;
			smer	: byte;
			used	: boolean;
			rychlost	: byte;
		  end;
    vytahy  = array[1..max_vytahy] of vytah;

    ve	= array[1..pocet_veci] of predmet;


var oldkey		: word;
    vec		: ^ve;
    st		: stage;
{    palx,blackx	: tpalette;}
    Stop,non,okraj: boolean;
    Num,oldmov	: byte;
    Temp,menux	: integer;
    Rate		: word;
    scrx,scry,resx,resy,ani	: word;
    f,ff		: integer;
    si		: postava;
    k			: word;
    poloha,krok,oldpol		: integer;
    ar		: ^long_panak;     {daj si bacha, ABY sa neprekryvala}
    te		: ^long_vec;     {postava s bufferom}
    cl		: string[15];
    rollup,klast,rolling	: integer;
    t			: text;
    rx,ry,rp,pom,mov,stara_miestnost,vstupx,vstupy	: integer;
    rolldown,truth,clr,death,talking,sounds_loaded	: boolean;
    aktivita_snd,animabl	: Boolean;
    miestnost	: integer;
    ch		: char;
    scored		: array[1..pocet_textov] of boolean;
    dej		: array[1..pocet_textov] of byte;
    priechody	: ^prechody;
    pocet_priechodov	: byte;

type
    polozk_typ = record
		     meno:string;
		     x,y:word;
		     k:word;
    end;
    menum_typ  = record
		     dat:array[1..5] of polozk_typ;
		     pocet:byte;
     end;
type hrac 	   = record
			  meno:string[12];
			  score:longint;
     end;
     banda     = array[1..10] of hrac;

     diskx     = record
			  meno:string[25];
			  subor:string[12];
			  verzia:word;
     end;
     all_disks = array[1..19] of diskx;

     level     = record
			   meno:string[30];
			   subor:string[12];
     end;
     levels    = record
				  pocet:word;
				  lev:array[1..19]of level;
     end;
    zaznam     = array[1..100] of string[100];
    bludisko   = array[0..mie_x,0..mie_y] of boolean;
    cas        = record
	    h,m,s,o:word;
    end;

const 	posuv		= 15;
		posuv_padaku= 12;
		maxlen	= 4096;
		ver		= 108;
		VERSION	= 'SIRIEL 3.5        v.:1.08';
		hlavicka	= 'SIRIEL35';
		def_font	= 'FMOD';		{font 8x16}
		def_font2	= 'FMAIN';      {font 8x8 -skrol}
		none		= 'NONE';
		cfg_file	= 'SIRIEL3.CFG';
		veci_x	= 360;
		veci_y	= 440;
		no		= 'NO';
{		numsounds=7;}
		basic_snd	= 8;
		extra_snd   = 8;
		num_snd	= basic_snd+extra_snd;        {9-16 - nahradne}
		px		= 4;
		py		= 2;
		px16		= px+12;
		py16		= py+12;
		def_invisible	= 255;
		input_file	= 'MAIN.DAT';
            frame_gif   = '>GLIST';
		wait_point	= 250;                     {doba cakania}
		def_zivoty	= 3;
		def_completer	= 1;
		def_config	= 'CONFIG';
		score_sub	= 'SCORE.DAT';
		anonymous	= 'Anonymous';
		minimummem	= 300000;
		scroll_subor= 'SCROLL';
		frees		= '                             ';
	     yes	= 'YES';
	     inicializacny_cas	= 3000;
	     max_handles	= 6;

{$I lang.inc}

var ds	: integer;
    anim	: ^animacia;
    me	: ^menum_typ;
    hraci	: ^banda;
    levely	: ^levels;
    data_disks : ^all_disks;
    zal	: ^zaznam;
    med	: ^jxmenu_typ;
    bl	: ^bludisko;
    lift	: ^vytahy;
    diskd	: diskx;
    fx,fy,gravity	: word;
    score,basic_score,typ_miestnost	: word;
    restart,the_koniec,zvuk_loaded	: boolean;
    start_miestnost,next_miestnost	: string[20];
    obrazok_x,obrazok_y			: word;
    flik_start,flik_end			: string[30];
    msg : array[1..5]of string[80];
    textura,veci,anim_file,anim_def,intro_obr,pohyby,def_textura,def_veci,
    def_pohyby,def_intro_obr,DEF_ANIM_FILE:string[12];
    invisible:byte;
    snd_objav,snd_start,snd_strata,snd_koniec,snd_credit,snd_zober,snd_port,
    snd_succes,snd_acces,snd_zmizni,snd_intro,snd_zivot,snd_score,snd_appear,
    snd_theend,def_snd_objav,def_snd_start,def_snd_strata,def_snd_koniec,
    def_snd_credit,def_snd_zober,def_snd_port,def_snd_succes,def_snd_acces,
    def_snd_zmizni,def_snd_intro,def_snd_zivot,def_snd_score,def_snd_appear,
    def_snd_theend,outro_obr,def_outro_obr,snd_maze,def_snd_maze,scroll_sub,
    snd_fireball,def_snd_fireball,snd_fir,def_snd_fir,font,snd_change,
    def_snd_change      : string[10];
    count,anim_count,nahrane_veci,sipx,startx,starty:word;
    middle,sace,test,fli_abile:boolean;
    anic,bloing,zivoty,completer,vybrane:byte;
    time			: longint;
    selector		: byte;
    num_disks,dlzka_padu: word;
    meno_disku		: string[25];
    anx			: array[0..255] of word;
    old_level		: word;
    sprava			: string[30];
    block_ver		: array[0..2] of byte;
    ng,ma,ok,check_sound,crc_checking,use_joystick:boolean;
    data_count,typ	: word;
    suma,subor,miestn,s	: string;
    obrazovka,texnum,pad_pol:word;
    vyb,fz			: word;
    timer			: word;
    tim,tim2		: cas;
    ja			: byte;         {jazyk}
    own			: array[1..3] of byte;
    inusable		: word;  {neaktivne textury}
    maps			: array[1..num_maps] of boolean;
    freez_time          : byte; {doba zmrazenia}
    god_time            : byte; {doba nezranitelnosti}
    unfreez_sound       : byte; {rozmrazovaci zvuk}
    ungod_sound         : byte; {normalizacny zvuk}
    efekt_count         : byte; {pocitadlo charakterizujuce stav okolia SI}
    def_freez_time      : byte;
    def_god_time        : byte;
    shut_down_siriel    : boolean; {ci ma zhasnut Siriela}
    old_frame           : TFrame;
    napis               : TPrint;
    napis2              : TPrint;
    start_action        : byte; {startovacia akcia v miestnosti}
    aktual,obrazok_dx,obrazok_dy	: word;
    scan_x1,scan_x2,scan_y1,scan_y2	: byte;
    dscan_x1,dscan_x2,dscan_y1,dscan_y2	: byte;
    same,pocet_vytahov	: byte;
    smart_jump,lifting	: boolean;
    menu_pointer,inicializacna_pauza: word;    {ukazuje na menu, ktore sa ma inicializovat}
    start_stage         : byte;                {startovacia miestnost}
    handles			: array[1..max_handles] of klucka;
	{ 1 - obrazovka
	  2 - obrazovka pre menu
	  3 - nazvy predmetov
	  4 - neanimovane predmety
	  5 - sluzi na ulozenie map
	  6 - pozadie pri hre}
{    modul:ModDataRec;}
implementation
end.