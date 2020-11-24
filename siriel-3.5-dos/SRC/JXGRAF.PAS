{Upgraded by GEORGESOFT}

(* $define debug*)              (*Define debug if you want to enable your compiler directive*)
(*$ifndef debug*)
(*$a+,b-,d-,e-,g+,i-,l-,n-,q-,r-,s-*)
(*$endif*)

unit jxgraf;

interface

type
    pbyte=^byte;
    pword=^word;
    plongint=^longint;
    t_palette = record
			    r, v, b : byte;
		    end;
    tline   = array[0..1023] of longint;
    tpalette = array[0..255] of t_palette;
    tdone = procedure;
    treadpal = procedure (var pal;debut, longueur : word);
    tmove = procedure (var source, dest;number : word);
    pline = ^tline;
    pimage = ^timage;
    tputpixel = procedure(bitmap : pimage;x, y : word;couleur : longint);
    tgetpixel = function(bitmap : pimage;x, y : word) : longint;
    twritepal = procedure(var pal;debut, longueur : word);
    twriteline = procedure(bitmap : pimage;var line : tline;ordonnee : word;number : word);
    twritelinepos = procedure(bitmap : pimage;var line : tline;abscisse, ordonnee : word;number : word);
    treadline = procedure(bitmap : pimage;var line : tline;ordonnee : word;number : word);
    treadlinepos = procedure(bitmap : pimage;var line : tline;abscisse, ordonnee : word;number : word);
    treadlinepos_for_blit = procedure(bitmap : pimage;abscisse, ordonnee : word;number : word);
    timage = record
			 width, height : word;
			 putpixel : tputpixel;
			 getpixel : tgetpixel;
			 write_line : twriteline;
			 write_linepos : twritelinepos;
			 read_line : treadline;
			 read_linepos : treadlinepos;
			 read_linepos_for_blit : treadlinepos_for_blit; (*When blitting from a bitmap, this procedure
								 must put the appriate adress in blit_line. Note that if a transfer
								 is effectively needed, then it can be done to line_for_blit*)
			 lines : array[0..767] of pline;
			 x, y : word;
		 end;
    tPoint = Record x, y : Integer; End;
		  vesainfo1= record
					 signature                                 : array[1..4] of byte;
					 versionhi, versionlo                      : byte;
					 fabricant                                 : pointer;
					 unused                                    : longint;
					 codes                                     : pointer;
					 bidon                                     : array [1..238] of byte;
				 end;
		  vesainfo2= record
					 f_mode                                    : word;
					 f_page                                    : array[0..1] of byte;
					 granularite, wsize                        : word;
					 wseg                                      : array[0..1] of word;
					 setpage                                   : pointer;
					 linesize, resx, resy                      : word;
					 matricex, matricey, bitplans, bitperpixel : byte;
					 memblocks, memmodel, blocksize            : byte;
				 end;
  PByteArray = ^ByteArray;
  ByteArray = Array [0..0] Of Byte;
(*graphic format types*)
   fileheaders= record
			   bftype                                  : word;
			   bfsize                                  : longint;
			   bfreserved1, bfreserved2                : word;
			   bfoffbits                               : longint;
		   end;
   infoheaders= record
			   bisize, biwidth, biheight               : longint;
			   biplanes, bibitcount                    : word;
			   bicompression, bisizeimage, bixpelspermeter, bitpelspermeter, biclrused, biclrimportant : longint;
		   end;
   header_bmp= record
			   fileheader: fileheaders;
			   infoheader: infoheaders;
		   end;
   color_32= record
			 b, v, r, o:byte;
		 end;
   tcolors_bmp= record
			  b, v, r : byte;             (*reversed order*)
		  end;
   tpalette_bmp = array[0..255] of color_32;
   tpalette_tga= array[0..255] of tcolors_bmp;
   Tga_type_lut = record
				     origin, size : word;
				     bits_lut : byte;
			     end;
   Tga_description_image = record
					   many_things : byte;
				   end;
   Tga_image_specification = record
					     Xorg, Yorg, width, heigh : word;
					     bits_per_pixel : byte;
					     description_image : Tga_description_image;
				     end;
   header_Tga = record
			    size_of_comment : byte;
			    lut_present : byte;
			    type_image : byte;
			    lut : Tga_type_lut;
			    image : Tga_image_specification;
		    end;
     header_pcx = record
				 manufacturer, version, compression, bits_per_pixel : byte;
				 xmin, ymin, xmax, ymax, xdpi, ydpi : word;
				 palette : array[1..16] of t_palette;
				 reserved, plane : byte;
				 bytesperline, paletteinfo, xscreen, yscreen : word;
				 void : array[1..54] of byte;
			end;
	header_gif               = Record
					     Signature : Array [1..6] Of char;
					     ScreenWidth, ScreenHeight : Word;
					     flags, background, aspect : Byte;
					  End;
    tImageStruct = RECORD
	 Width: Word;
	 Height: Word;
	 BitsPerPixel: Byte; { 1,4 or 8 }
	 NumberOfColors: Word; { 2, 16 or 256 }
	 SizeOfImage: Longint; { The size of the whole image in bytes }
	 Information: Word; { Information: for PCX: version (byte)
							   BMP: compression (byte):
								   RGB (0)
								   RLE4 (1)
								   RLE8 (2)
							   GIF: subtype (byte):
								   0 = GIF87a
								   1 = GIF89a
							   IMG: compression method
								  (for future use; now
								   only dynamic huffman)

								   }
     end;


const mouse_ptr_maxx = 15;
      mouse_ptr_maxy = 15;

type tmouse_ptr = array[0..mouse_ptr_maxx, 0..mouse_ptr_maxy] of longint;

const
     driver_cga=1;
     fin_cga=5;
     driver_ega=6;
     fin_ega=7;
     driver_ega64=8;
     fin_ega64=9;
     driver_mcga=10;
     fin_mcga=15;
     driver_att400=16;
     fin_att400=21;
     driver_egamono=22;
     fin_egamono=22;
     driver_ibm8514=23;
     fin_ibm8514=24;
     driver_hercmono=25;
     fin_hercmono=25;
     driver_pc3270=26;
     fin_pc3270=26;
     driver_vga=27;
     fin_vga=29;
     (*mode graphiques*)
     MCGA_320x200x256=0;
     (*mode BGI*)
     CGA_320x200c0=0+driver_cga;
     CGA_320x200c1=1+driver_cga;
     CGA_320x200c2=2+driver_cga;
     CGA_320x200c3=3+driver_cga;
     CGA_640x200=4+driver_cga;
     EGA_640x200=0+driver_ega;
     EGA_640x350=1+driver_ega;
     EGA64_640x200=0+driver_ega64;
     EGA64_640x350=1+driver_ega64;
     MCGA_320x200c0=0+driver_mcga;
     MCGA_320x200c1=1+driver_mcga;
     MCGA_320x200c2=2+driver_mcga;
     MCGA_320x200c3=3+driver_mcga;
     MCGA_640x200=4+driver_mcga;
     MCGA_640x480=5+driver_mcga;
     ATT_400320x200c0=0+driver_att400;
     ATT_400320x200c1=1+driver_att400;
     ATT_400320x200c2=2+driver_att400;
     ATT_400320x200c3=3+driver_att400;
     ATT_400640x200=4+driver_att400;
     ATT_400640x400=5+driver_att400;
     EGAMono_640x350=3+driver_egamono;
     IBM8514_640x480=0+driver_ibm8514;
     IBM8514_1024x768=1+driver_ibm8514;
     HercMono_720x348=0+driver_hercmono;
     PC3270_720x350=0+driver_pc3270;
     VGA_640x200=0+driver_vga;
     VGA_640x350=1+driver_vga;
     VGA_640x480=2+driver_vga;
     (*modes VESA*)
     VESA_640x400x256=$100;
     VESA_640x480x256=$101;
     VESA_800x800x256=$103;
     VESA_1024x768x256=$105;
     VESA_320x200x32768=$10d;
     VESA_320x200x65536=$10e;
     VESA_320x200x16M=$10f;                 (*For 16m colors mode, the color parameter is (red shl 16)+(green shl 8)+blue*)
     (*+ all others ...*)

     RadToDeg = 180/Pi;
     DegToRad = 1/RadToDeg;
     (*graphic format constant*)
     maxbuffer = 60001;
     largest_code=4095;
     table_size=5003;
     gifsig = 'GIF87a';
     masktable : array [0..7] of byte =($80, $40, $20, $10, $8, $4, $2, 1);
     bittable  : array [0..7] of byte =($1, $2, $4, $8, $10, $20, $40, $80);


  MaxSize = 65520; { 64K - 16 }

  { Error constants for reading and writing images }
  Image_Ok                   =   0;
  Err_GifInvalidColordepth = 100;
  Err_NotAGif              = 101;
  Err_BadSymbolSize        = 102;
  Err_InvalidBlockSize     = 103;
  Err_BadGifCode           = 104;
  Err_BadFirstGifCode      = 105;
  Err_BadRead              = 106;
  Err_BadWrite             = 107; { on disk or in XMS ! }
  Err_NoMemory             = 108; { No XMS or not enough XMS ! }
  Err_GifNotFound          = 109;
  Err_CreatingGif          = 110;
  Err_PCXNotFound          = 111;
  Err_NotAPCX              = 112;
  Err_BadPalette           = 113; { PCX only }
  Err_PCXInvalidColordepth = 114; { the same for GIF }
  Err_CreatingPCX          = 115;
  Err_NotABMP              = 116;
  Err_WrongColors          = 117; { BMP only: colors > 256 }
  Err_BMPNotFound          = 118;
  Err_CompressedBMP        = 119; { not compressed BMP's now; maybe later }
  Err_CreatingBMP          = 120;
  Err_BMPInvalidColorDepth = 121; { the same for GIF }
  Err_IMGNotFound          = 122;
  Err_NotAIMG              = 123;
  Err_IMGInvalidColordepth = 124; { the same for GIF }
  Err_CreatingIMG          = 125;
  Err_CompressingIMG       = 126; { Failed to compress, decompress IMG:
						 - disk error
						 - 32-bit CRC error }
  Err_ByUser               = 255;

  { Compression constants for bitmap: }
  BI_RGB  = 0; { RGB-encoded; not compressed }
  BI_RLE8 = 1; { RLE-encoded; compressed: 8 bits }
  BI_RLE4 = 2; { RLE-encoded; compressed: 4 bits }

  { Defined constants for my own image routines (IMG): }

  PACK_NOERR=0;
  PACK_EOD=-1;

  DHuffman = 1;


var mode : word;                                (*current mode, mode passed to init_mode*)
    gif_x,gif_y :word;
    tma:boolean;
    fontik:array[0..4096] of byte;
    death_color:word;       {farba, ktora sa vynechava pri obrazku}
    posuv:integer;
    write_palette : twritepal;
    screen : pimage;
    done_graf : tdone;
    getmaxx, getmaxy : integer;
    nb_colors : longint;                        (*number of colors*)
    nb_colors_mask : longint;                   (*number of colors-1. Allow and operation instead of mod*)
    read_palette : treadpal;
    vesa1 : vesainfo1;
    vesa2 : vesainfo2;
    lln : word;                                 (*size of a scan line*)
    movevesal : tmove;                          (*used by vesa routine*)
    movevesae : tmove;
    currentcolor : longint;
    FontScaleX, FontScaleY : Integer;           { Multiplication factors for fontwidth/height }
    CharDX, CharDY : Integer;                   { Dimensions of characters in current font    }

    mouse_posx, mouse_posy : integer;
    mouse_button : byte;
    mouse_current_mask_and, mouse_current_mask_or : tmouse_ptr;
    must_show_mouse : boolean;

    line_for_blit : tline;
    blit_line : pline;

(*For a description of each function, you should go to its implementation*)

function init_mode : boolean;                   (*init a mode*)
{function reinit_mode (resx,resy,bits:word): boolean;                   (*reinit a mode*)}

function find_best_mode(var getmaxx_required, getmaxy_required : word;bit_per_pixel : word) : longint;
procedure Line(bitmap : pimage;x1, y1, x2, y2 : word; coul : longint );
procedure ellipse(bitmap : pimage; xc, yc, a0, b0 : word;color: longint);
procedure circle(bitmap : pimage;xc, yc, r : word;coul : longint);
procedure fillarea(bitmap : pimage;x, y : word;coul : longint);
procedure moveto(bitmap : pimage;x, y : word);
procedure setcolor(color : longint);
procedure lineto(bitmap : pimage;x, y : word);
procedure clear_bitmap(bitmap : pimage);
procedure clear_bitmap2(bitmap : pimage;colx:word);
procedure totextmode;                           (*switch to text mode and keep video memory*)
procedure restauretxt;
procedure move(var source, but;taille : word);
procedure fillchar(var source; taille : word; value : byte);
procedure filldouble(var source;taille : word; value : longint);

(*Some of theese routines were not well tested, but they should work correctly*)
procedure rectangle(bitmap : pimage;x1, y1, x2, y2 : word);

procedure rectangle2(bitmap : pimage;x1, y1, x2, y2,col : word); {corrected by Misu}
{-=>  Added By MisuSoft  <=-}
procedure rectangle3(bitmap : pimage;x1, y1, x2, y2,col : word);

Procedure Arc (bitmap : pimage;x_center, y_center, radius, s_angle, e_angle : Word);
Procedure EllipseArc (bitmap : pimage;x_center, y_center, rx, ry, s_angle, e_angle : Word);
Procedure Curve (bitmap : pimage;x1, y1, x2, y2, x3, y3 : Integer; Segments : Word);
Procedure CubicBezierCurve (bitmap : pimage;x1, y1, x2, y2, x3, y3, x4, y4 : Integer; Segments : Word);
Procedure BSpline (bitmap : pimage;NumPoints : Word; Var Points : Array Of tPoint; Segments : Word);
Procedure Catmull_Rom_Spline (bitmap : pimage;NumPoints : Word; Var Points : Array Of tPoint; Segments : Word);
Procedure DrawPoly (bitmap : pimage;NumPoints : Word; Var Points : Array Of tPoint);
Procedure PrintAt (bitmap : pimage;x, y : Integer; s : String; TextColor,background : longint; roll:integer);
Procedure Print (bitmap : pimage;s : String; TextColor,back : longint);
procedure printx(bitmap:pimage;x,y:integer;s:string;textcolor:longint;roll:integer);
Procedure Printu (bitmap : pimage; x, y : word; s : String; TextColor : longint);
procedure printr(bitmap:pimage;var x,y:word;s:string;textcolor:longint;roll:integer);
procedure print_normal(bitmap:pimage;x,y:word;s:string;textcolor:longint;roll:integer);
procedure print_zoom(bitmap:pimage;x,y:word;s:string;textcolor:longint;zoomx,zoomy:word);
procedure print_zoom_shadow(bitmap:pimage;x,y:word;s:string;textcolor:longint;zoomx,zoomy,px,py,col:word);
procedure printc(bitmap:pimage;y:integer;s:string;textcolor:longint;roll:integer);
procedure printx2(bitmap:pimage;x,y:integer;s:string;textcolor:longint;zoomx,zoomy,roll,back:integer);
procedure printzoom(bitmap:pimage;var x,y:word;s:string;textcolor:longint;zoomx,zoomy:word);
procedure printzoom2(bitmap:pimage;var x,y:word;s:string;textcolor:longint;zoomx,zoomy:word);
procedure prints(bitmap:pimage;x,y,pox,poy:integer;s:string;textcolor:longint;shadow,roll:integer);
Procedure SetFontScale (ScaleX, ScaleY : Integer);
procedure SetStartChar(posx:integer);
procedure FontLoad(fmeno:string;fod,fdo,fdlzka,fx,fy,ftrans:integer);
procedure Font_Load2(fmeno:string;var fx,fy:word);
Procedure SetFont (FontPtr : Pointer; FontWidth, FontHeight : Integer);
Procedure FontScale (Var ScaleX, ScaleY : Integer);
Function CharWidth : Integer;
Function CharHeight : Integer;

procedure decrease_palette(palx:tpalette;time:longint);
procedure decreaseup_palette(palx:tpalette;time:longint);
procedure increase_palette(start,palx:tpalette;time:longint);
function  load_palette(sub:string;var target_pal:tpalette;from_col,to_col:byte;write_it:boolean):boolean;
procedure fill_palette_black(var pal:tpalette);
procedure fill_palette(var pal:tpalette; col:byte);

(*Info units*)
procedure inicializuj(resolution_x,resolution_y,bits_per_pixel:word);
procedure koniec(s:string;break:boolean);

(*All draw_* do NOT verify that bitmap is big enough to handle them. It's your work.*)
procedure set_death_color(num:word);
function return_sizebmp(file_name : string;var sizex, sizey, bitsperpixel : word) : boolean;
function return_sizetga(file_name : string;var sizex, sizey, bitsperpixel : word) : boolean;
function return_sizepcx(file_name : string;var sizex, sizey, bitsperpixel : word) : boolean;
function return_sizegif(file_name : string;var sizex, sizey, bitsperpixel : word) : boolean;
function draw_bmp(bitmap : pimage;file_name : string;fromx, fromy : word;var pal : tpalette) : boolean;
function draw_tga(bitmap : pimage;file_name : string;fromx, fromy : word;var pal : tpalette) : boolean;
function draw_pcx(bitmap : pimage;file_name : string;fromx, fromy : word;var pal : tpalette) : boolean;
function draw_gif(bitmap : pimage;file_name : string;fromx, fromy : word;var pal : tpalette) : boolean;
function dump_to_gif(bitmap : pimage;file_name : string;xstart, ystart, xstop, ystop, bits_per_pixel : integer;
	   pal : tpalette) : longint;

(*Virtual screen function*)
function create_bitmap(width, height : word) : pimage;
procedure destroy_bitmap(bitmap : pimage);

procedure putpixel(bitmap : pimage;x, y : word;couleur : longint);
function getpixel(bitmap : pimage;x, y : word) : longint;
(*procedure writepal(bitmap : pimage;var pal;debut, longueur : word);*)
procedure write_line(bitmap : pimage;var line : tline;ordonnee : word;number : word);
procedure write_linepos(bitmap : pimage;var line : tline;abscisse, ordonnee : word;number : word);
procedure read_line(bitmap : pimage;var line : tline;ordonnee : word;number : word);
procedure read_linepos(bitmap : pimage;var line : tline;abscisse, ordonnee : word;number : word);
procedure read_linepos_for_blit(bitmap : pimage;abscisse, ordonnee : word;number : word); (*Should only be used for blitting*)

function wherex(bitmap : pimage) : word;
function wherey(bitmap : pimage) : word;

procedure blit(bit1, bit2 : pimage;x1, y1, x2, y2, numberx, numbery : word);
procedure blitx(bit1, bit2 : pimage;x1, y1, x2, y2, numberx, numbery: word; colx:longint);

(*Keyboard functions*)
function keypressed : boolean;
function read_key : word;
procedure clear_buffer;

(*Timer function*)
FUNCTION GetClock : LongInt;
PROCEDURE InitClock;
procedure wait_for_time(time:longint);
procedure install_timer(proc : tdone;freq : word);      (*WARNING : the 2 timer functions are just here to tests,
									    they're not reliable at all !!!*)
procedure remove_timer;

procedure wait_synchro;

(* waiting for time impulz*)
procedure pulz(impulz:word);

(*Mouse functions*)
procedure hide_mouse;                                   (*As with usual mouse drivers,
                                                          you need to hide mouse before doing any modification to screen*)
procedure show_mouse;
procedure mousepos;
procedure define_look(var m_and, m_or : tmouse_ptr);
procedure define_zone(x1, y1, x2, y2 : integer);
procedure define_speed(mickeysx, mickeysy : integer);
procedure define_double_speed_limit(limit : integer);
procedure get_speed(var mickeysx, mickeysy, double_limit : integer);
procedure init_mouse(var m_and, m_or : tmouse_ptr);
procedure done_mouse;

implementation

(*$f+*)       (* $f+ is needed for procedural types*)
uses txt,dos, graph;

type tgrgetpixel=function(x, y : integer) : word; (*cause of graph format*)
     tgrputpixel=procedure(x, y : integer;coul : word);

var mode2 : integer;                              (*save of mode*)
    granul, granul2 : byte;                       (*granularity of vesa mode*)
    newbank : tdone;
    current_page : byte;                          (*current vesa page*)
    toshift, is_3 : byte;
    grgetpixel : tgrgetpixel;
    grputpixel : tgrputpixel;
    p : pointer;
    buf : array[0..12200] of byte;                (*buffer to save when switching to text mode*)
								  (*to do : transform this to pointer to save DS memory !*)
    Font : PByteArray;                      { Pointer to current font                     }

    oldtimerint : pointer;
    tocall : tdone;

    recur : boolean;
    mouse_oldx, mouse_oldy, hide_mouse_x, hide_mouse_y : integer;
    old_screen, mask_and, mask_or : tmouse_ptr;

const maxy=16;
      EGAVGA_SEQUENCER = $3C4;   { Port addresses/datas of sequencer }
      EGAVGA_MONCTR    = $3D4;            { Address screen controler }
      EGAVGA_GRAPHCTR  = $3CE;{Port addr./data of graphic controler }
      EV_STATC         = $3DA;       { Register of state color EGA/VGA }
	EV_STATM         = $3BA;          { Register of state mono EGA/VGA }
	EV_ATTR          = $3C0;         { Attribute controler EGA/VGA }


procedure CLI; inline( $FA );               { Forbide interrupts }
procedure STI; inline( $FB );              { allow interrupts }

(*fast power function*)
function puissance(x : longint;p : longint) : longint;
begin
     if p<>1 then begin
        if p and 1=0 then x:=sqr(puissance(x, p shr 1)) else begin
           dec(p);
           x:=x*sqr(puissance(x, p shr 1));
        end;
     end;
     puissance:=x;
end;


(*New version, 386+ needed*)
(*$l ugrafmv3.obj*)
procedure move(var source, but;taille : word);external;
procedure fillchar(var source; taille : word; value : byte);external;
(*Filldouble allows you to initialize something with a 32bit value.
  For example, you can initialize a line like that : filldouble(line, getmaxx, your_color) *)
procedure filldouble(var source; taille : word;value : longint);external;

procedure done_general;
begin
     dispose(screen);           (*Release memory used by screen variable*)
end;

procedure done_bidon;  (*dummy done*)
begin
     asm
        mov  ax, 0003h
        int  10h
     end;
     done_general;
end;

(*all these routine are to interface with graph unit*)
procedure write_line_graph(bitmap : pimage;var line : tline;ordonnee, number : word);
var i : integer;
begin
     for i:=0 to number-1 do putpixel(bitmap, i, ordonnee, line[i]);
end;

procedure read_line_graph(bitmap : pimage;var line : tline;ordonnee, number : word);
var i : integer;
begin
     for i:=0 to number-1 do line[i]:=getpixel(bitmap, i, ordonnee);
end;

procedure write_line_graphpos(bitmap : pimage;var line : tline;abscisse, ordonnee, number : word);
var i : integer;
begin
     for i:=abscisse to number-1+abscisse do putpixel(bitmap, i, ordonnee, line[i]);
end;

procedure read_line_graphpos(bitmap : pimage;var line : tline;abscisse, ordonnee, number : word);
var i : integer;
begin
     for i:=abscisse to number-1+abscisse do line[i]:=getpixel(bitmap, i, ordonnee);
end;


procedure move8bitse(var source, dest;number : word);external;
procedure move8bitsl(var source, dest;number : word);external;
procedure move16bitse(var source, dest;number : word);external;
procedure move16bitsl(var source, dest;number : word);external;
procedure move24bitse(var source, dest;number : word);external;
procedure move24bitsl(var source, dest;number : word);external;
procedure move32bits(var source, dest;number : word);external;

procedure pulz(impulz:word);
var hh,mm,ss,os,oo,xcou:word;
begin
 oo:=100;
 xcou:=0;
 repeat
  gettime(hh,mm,ss,os);
  if oo<>os then begin inc(xcou);
  oo:=os;
  end;
 until xcou=impulz;
end;

procedure wait_synchro;assembler;            (*Waits for vertical retrace*)
							   (*It would be a good idea to call
							   this before doing any modification on screen,
							   since it would forbide blinking*)
asm
   mov  dx, 3dah
  @deb1:
   in   al, dx
   test al, 8
   jne  @deb1
  @deb2:
   in   al, dx
   test al, 88
   je   @deb2
end;


(*nothing*)
procedure rien(var pal;debut, longueur : word);
begin
end;

procedure rien_lectpal(var pal;debut, longueur : word);
begin
end;

(*mode 13h init*)
(*parameter == true -> we don't erase video mem*)
function umcgainit(keep : boolean) : boolean;
var i : word;

function active:boolean;
begin
asm
    xor  ah, ah
    mov  al, 13h
    int  10h
    mov  ah, 0fh
    int  10h
    cmp  al, 13h
    je   @ok
    xor  al, al
    jmp  @fin
   @ok:
    mov  al, 1
   @fin:
    mov  @result, al
end;
end;
function active2:boolean;
begin
asm
    xor  ah, ah
    mov  al, 13h
    or   al, 128
    int  10h
    mov  ah, 0fh
    int  10h
    cmp  al, 13h
    je   @ok
    xor  al, al
    jmp  @fin
   @ok:
    mov  al, 1
   @fin:
    mov  @result, al
end;
end;
begin
     if not keep then begin
     if not active then begin
					umcgainit:=false;
				end
                    else  umcgainit:=true;
     end else umcgainit:=active2;
end;

(*mode 13h putpixel*)
procedure umcgaputpixel(bitmap : pimage;x, y : word;coul : longint);assembler;
asm
   mov  ax, y
   mov  bx, x
   xchg ah, al
   mov  dx, ax
   (*$ifopt g+*)
      shr  dx, 2
   (*$else*)
	shr  dx, 1
	shr  dx, 1
   (*$endif*)
   add  dx, ax
   add  bx, dx
   mov  ax, 0a000h
   mov  es, ax
   mov  al, byte ptr coul
   mov  es:[bx], al
end;

function umcgagetpixel(bitmap : pimage;x, y : word) : longint;assembler;
asm
   mov  ax, y
   mov  bx, x
   xchg ah, al
   mov  dx, ax
   (*$ifopt g+*)
      shr  dx, 2
   (*$else*)
      shr  dx, 1
      shr  dx, 1
   (*$endif*)
   add  dx, ax
   add  bx, dx
   mov  ax, 0a000h
   mov  es, ax
   xor  ax, ax
   mov  al, es:[bx]
   xor  dx, dx
end;

procedure umcgawrite_line(bitmap : pimage;var line : tline;ordonnee : word;number : word);
begin
     move8bitse(line, mem[$a000:ordonnee*320], number);
end;

procedure umcgaread_line(bitmap : pimage;var line : tline;ordonnee : word;number : word);
begin
     move8bitsl(mem[$a000:ordonnee*320], line, number);
end;

procedure umcgawrite_linepos(bitmap : pimage;var line : tline;abscisse, ordonnee : word;number : word);
begin
     move8bitse(line, mem[$a000:ordonnee*320+abscisse], number);
end;

procedure umcgaread_linepos(bitmap : pimage;var line : tline;abscisse, ordonnee : word;number : word);
begin
     move8bitsl(mem[$a000:ordonnee*320+abscisse], line, number);
end;

procedure umcgacleardevice;assembler;
asm
   mov  ax, 0A000h
   mov  es, ax
   xor  di, di
   mov  cx, 32000
   xor  ax, ax
   rep  stosw
end;

(*vga and more palette write*)
(*should be quite fast*)
procedure ugrafwrite_palette(var palette;begining, number:word);assembler;
asm
    push ds
    lds  si, palette
    mov  dx, 3c8h
    cld
    mov  cx, number
    mov  bx, begining
   @deb1:
    mov  al, bl
    out  dx, al
    inc  dx
    lodsb
    out  dx, al
    lodsb
    out  dx, al
    lodsb
    out  dx, al
    dec  dx
    inc  bl
    loop @deb1
    pop  ds
end;

procedure ugrafread_palette(var palette;begining, number:word);assembLer;
asm
    push ds
    les  di, palette
    mov  dx, 3c8h
    cld
    mov  cx, number
    mov  bx, begining
   @deb1:
    mov  al, bl
    out  dx, al
    inc  dx
    in   al, dx
    stosb
    in   al, dx
    stosb
    in   al, dx
    stosb
    dec  dx
    inc  bl
    loop @deb1
    pop  ds
end;

(*change vesa video page by interrupt*)
procedure newbankint;assembler;
asm
        mov  current_page, al
        mov  cl, granul2
        shl  ax, cl
	  mov  dx, ax
        xor  bx, bx
        mov  ax, 4f05h
        int  10h
end;

(*by call to far function*)
(*faster, but not supported by all cards.*)
(*we will choose for best available*)
procedure newbankcall;assembler;
asm
	  mov  current_page, al
        mov  cl, granul2
        shl  ax, cl
        mov  dx, ax
        xor  bx, bx
	  call vesa2.setpage
end;

(*Sets a vesa mode*)
function uvesasetmode(m : word) : boolean;
var i : longint;
    regs : registers;
begin
     with regs do begin
          ax:=$4f00;
	    cx:=m;
	    es:=seg(vesa1);
          di:=ofs(vesa1);
     end;
     intr($10, regs);
     if regs.ax<>$4f then begin
	  uvesasetmode:=false;
        exit;
     end;
     with regs do begin
          ax:=$4f02;
          bx:=m;
     end;
     intr($10, regs);
     if regs.ax<>$4f then begin
        uvesasetmode:=false;
	  exit;
     end;
     with regs do begin
          ax:=$4f01;
          cx:=m;
          es:=seg(vesa2);
	    di:=ofs(vesa2);
     end;
     intr($10, regs);
     lln:=vesa2.linesize;
     if vesa2.setpage<>nil then newbank:=newbankcall else newbank:=newbankint;
     getmaxx:=vesa2.resx;
     getmaxy:=vesa2.resy;
     nb_colors:=puissance(2, vesa2.bitperpixel);
     nb_colors_mask:=nb_colors-1;
     case vesa2.bitperpixel of
	    8 : begin movevesal:=move8bitsl;movevesae:=move8bitse;toshift:=0;is_3:=0;end;
	    15 : begin movevesal:=move16bitsl;movevesae:=move16bitse;toshift:=1;is_3:=0;end;
          16 : begin movevesal:=move16bitsl;movevesae:=move16bitse;toshift:=1;is_3:=0;end;
          24 : begin movevesal:=move24bitsl;movevesae:=move24bitse;toshift:=0;is_3:=1;end;
          32 : begin movevesal:=move32bits;movevesae:=move32bits;toshift:=2;is_3:=0;end;
     end;
     if m>=$100 then begin
        i:=longint(vesa2.granularite)*1024;
        granul:=16;
        while (i shr granul)=0 do dec(granul);
        granul2:=16-granul;
     end;
     uvesasetmode:=true;
end;

(*vesa 8bits putpixel*)
procedure uvesaputpixel8(bitmap : pimage;x, y : word;coul : longint);assembler;
asm
        push ds
        mov  ax, 0a000h
        mov  es, ax
        mov  ax, seg @data
	  mov  ds, ax
        mov  dx, y
        mov  cx, x
        mov  ax, lln
        mul  dx
        add  ax, cx
        adc  dx, 0
        mov  bx, ax
        cmp  dl, current_page
        je   @same_bank
	  mov  ax, dx
	  push bx
        call newbank
        pop  bx
 @same_bank:
        mov  al, byte ptr coul
	  mov  es:[bx], al
        pop  ds
end;

function  uvesagetpixel8(bitmap : pimage;x, y : word) : longint;assembler;
asm
        push ds
        mov  ax, 0a000h
        mov  es, ax
        mov  ax, seg @data
	  mov  ds, ax
	  mov  dx, y
        mov  cx, x
        mov  ax, lln
        mul  dx
        add  ax, cx
	  adc  dx, 0
        mov  bx, ax
        cmp  dl, current_page
        je   @same_bank
        mov  ax, dx
        push bx
        call newbank
        pop  bx
 @same_bank:
        mov  al, es:[bx]
	  xor  ah, ah
	  xor  dx, dx
        pop  ds
end;

procedure uvesaputpixel16(bitmap : pimage;x, y : word;coul : longint);assembler;
asm
        push ds
        mov  ax, 0a000h
        mov  es, ax
        mov  ax, seg @data
        mov  ds, ax
        mov  dx, y
        mov  cx, x
        shl  cx, 1
        mov  ax, lln
	  mul  dx
	  add  ax, cx
        adc  dx, 0
        mov  bx, ax
        cmp  dl, current_page
        je   @same_bank
	  mov  ax, dx
        push bx
        call newbank
        pop  bx
 @same_bank:
        mov  ax, word ptr coul
        mov  es:[bx], ax
        pop  ds
end;

function  uvesagetpixel16(bitmap : pimage;x, y : word) : longint;assembler;
asm
        push ds
        mov  ax, 0a000h
        mov  es, ax
        mov  ax, seg @data
	  mov  ds, ax
        mov  dx, y
        mov  cx, x
        shl  cx, 1
        mov  ax, lln
        mul  dx
        add  ax, cx
        adc  dx, 0
        mov  bx, ax
        cmp  dl, current_page
	  je   @same_bank
	  mov  ax, dx
        push bx
        call newbank
        pop  bx
 @same_bank:
	  mov  ax, es:[bx]
        xor  dx, dx
        pop  ds
end;

procedure uvesaputpixel24(bitmap : pimage;x, y : word;coul : longint);assembler;
asm
        push ds
        mov  ax, 0a000h
        mov  es, ax
	  mov  ax, seg @data
	  mov  ds, ax
        mov  dx, y
        mov  cx, x
        shl  cx, 1
        add  cx, x
	  mov  ax, lln
        mul  dx
        add  ax, cx
        adc  dx, 0
        mov  bx, ax
        cmp  dl, current_page
        je   @same_bank
        mov  ax, dx
        push bx
        call newbank
	  pop  bx
 @same_bank:
        mov  ax, word ptr coul
        mov  es:[bx], ax
        mov  al, byte ptr [coul+2]
        mov  es:[bx+2], al
	  pop  ds
end;

function  uvesagetpixel24(bitmap : pimage;x, y : word) : longint;assembler;
asm
        push ds
        mov  ax, 0a000h
        mov  es, ax
        mov  ax, seg @data
        mov  ds, ax
	  mov  dx, y
	  mov  cx, x
        shl  cx, 1
        add  cx, x
        mov  ax, lln
        mul  dx
	  add  ax, cx
        adc  dx, 0
        mov  bx, ax
        cmp  dl, current_page
        je   @same_bank
        mov  ax, dx
        push bx
        call newbank
        pop  bx
 @same_bank:
	  mov  ax, es:[bx]
	  xor  dh, dh
        mov  dl, es:[bx+2]
        pop  ds
end;

procedure uvesaputpixel32(bitmap : pimage;x, y : word;coul : longint);assembler;
asm
        push ds
        mov  ax, 0a000h
        mov  es, ax
        mov  ax, seg @data
        mov  ds, ax
        mov  dx, y
        mov  cx, x
        (*$ifopt g+*)
	  shl  cx, 2
	  (*$else*)
        shl  cx, 1
        shl  cx, 1
        (*$endif*)
        mov  ax, lln
	  mul  dx
        add  ax, cx
        adc  dx, 0
        mov  bx, ax
        cmp  dl, current_page
        je   @same_bank
        mov  ax, dx
        push bx
        call newbank
        pop  bx
 @same_bank:
	  mov  ax, word ptr coul
        mov  es:[bx], ax
        mov  ax, word ptr [coul+2]
        mov  es:[bx+2], ax
        pop  ds
end;

function  uvesagetpixel32(bitmap : pimage;x, y : word) : longint;assembler;
asm
        push ds
        mov  ax, 0a000h
        mov  es, ax
        mov  ax, seg @data
        mov  ds, ax
        mov  dx, y
	  mov  cx, x
	  (*$ifopt g+*)
        shl  cx, 2
        (*$else*)
        shl  cx, 1
        shl  cx, 1
	  (*$endif*)
        mov  ax, lln
        mul  dx
        add  ax, cx
        adc  dx, 0
        mov  bx, ax
        cmp  dl, current_page
        je   @same_bank
        mov  ax, dx
        push bx
	  call newbank
	  pop  bx
 @same_bank:
        mov  ax, es:[bx]
        mov  dx, es:[bx+2]
        pop  ds
end;

(*ordonnee = y*)
procedure uvesawrite_line_vesa(bitmap : pimage;var line : tline;ordonnee : word; number : word);assembler;
asm
        push ds
        mov  ax, seg @data
        mov  ds, ax
        mov  ax, number
        or   is_3, 0
	  je   @yop

        mov  dx, ax
        shl  ax, 1
        add  ax, dx
@yop:
	  mov  cl, toshift
        shl  ax, cl
        mov  number, ax
        mov  dx, ordonnee
        mov  ax, lln
        mul  dx
        mov  bx, ax
        cmp  dl, current_page
        je   @same_bank
        push ax
	  push dx
	  mov  ax, dx
        call newbank
        pop  dx
        pop  ax
 @same_bank:
	  mov  cx, 0FFFFh
        sub  cx, ax
        cmp  number, cx
        jna  @paspepin
        inc  cx
        push cx
        push dx
        les  si, line
        push es
        push si
	  push 0A000h
	  push ax
        push cx
        call movevesae
        pop  dx
        pop  cx
	  inc  dx
        push cx
        mov  ax, dx
        call newbank
        pop  cx
        mov  ax, number
        sub  ax, cx
        les  di, line
        push es
        push si
	  push 0A000h
	  push 0
        push ax
        call movevesae
        jmp  @fin
 @paspepin:
	  les  si, line
        push es
        push si
        push 0A000h
        push ax

        push number

        call movevesae
 @fin:
	  pop  ds
end;

procedure uvesaread_line_vesa(bitmap : pimage;var line : tline;ordonnee : word;number : word);assembler;
asm
        push ds
	  mov  ax, seg @data
        mov  ds, ax
        mov  ax, number
        or   is_3, 0
        je   @yop

        mov  dx, ax
        shl  ax, 1
        add  ax, dx
@yop:
	  mov  cl, toshift
	  shl  ax, cl
        mov  number, ax
        mov  dx, ordonnee
        mov  ax, lln
        mul  dx
	  mov  bx, ax
        cmp  dl, current_page
        je   @same_bank
        push ax
        push dx
        mov  ax, dx
        call newbank
        pop  dx
        pop  ax
 @same_bank:
	  mov  cx, 0FFFFh
	  sub  cx, ax
        cmp  number, cx
        jna  @paspepin
        inc  cx
        push cx
	  push dx
        les  si, line
        push 0A000h
        push ax
        push es
        push si
        push cx
        call movevesal
        pop  dx
        pop  cx
	  inc  dx
	  push cx
        mov  ax, dx
        call newbank
        pop  cx
        mov  ax, number
	  sub  ax, cx
        les  si, line
        push 0A000h
        push 0
        push es
        push di
        push ax
        call movevesal
        jmp  @fin
 @paspepin:
	  les  si, line
	  push 0A000h
        push ax
        push es
        push si
        push number

        call movevesal
 @fin:
        pop  ds
end;

procedure uvesawrite_line_vesapos(bitmap : pimage;var line : tline;abscisse, ordonnee : word; number : word);assembler;
asm
        push ds
        mov  ax, seg @data
	  mov  ds, ax
	  mov  ax, number
        or   is_3, 0
        je   @yop

        mov  dx, ax
	  shl  ax, 1
        add  ax, dx
@yop:
        mov  cl, toshift
        shl  ax, cl
        mov  number, ax
        mov  dx, ordonnee
        mov  ax, lln
        mul  dx
        mov  bx, ax
	  mov  cx, ax
	  mov  di, abscisse
        or   is_3, 0
        jne  @_24_bits
        push cx
        mov  cl, toshift
	  shl  di, cl
        pop  cx
 @return:
        add  ax, di
        cmp  ax, cx
        jae  @suite
        inc  dl
        @suite:
        cmp  dl, current_page
        je   @same_bank
	  push ax
	  push dx
        mov  ax, dx
        call newbank
        pop  dx
        pop  ax
 @same_bank:
        mov  cx, 0FFFFh
        sub  cx, ax
        cmp  number, cx
        jna  @paspepin
        inc  cx
        push cx
        push dx
        les  si, line
        push es
	  push si
	  push 0A000h
        push ax
        push cx
        call movevesae
        pop  dx
	  pop  cx
        inc  dx
        push cx
        mov  ax, dx
        call newbank
        pop  cx
        mov  ax, number
        sub  ax, cx
        les  di, line
        push es
	  push si
	  push 0A000h
        push 0
        push ax
        call movevesae
        jmp  @fin

 @_24_bits:
        mov  si, di
        shl  di, 1
        add  di, si
        jmp  @return

 @paspepin:
        les  si, line
        push es
	  push si
	  push 0A000h
        push ax
        push number

        call movevesae
 @fin:
        pop  ds
end;

procedure uvesaread_line_vesapos(bitmap : pimage;var line : tline;abscisse, ordonnee : word;number : word);assembler;
asm
        push ds
        mov  ax, seg @data
        mov  ds, ax
        mov  ax, number
	  or   is_3, 0
	  je   @yop

        mov  dx, ax
        shl  ax, 1
        add  ax, dx
@yop:
        mov  cl, toshift
        shl  ax, cl
        mov  number, ax
        mov  dx, ordonnee
        mov  ax, lln
        mul  dx
        mov  bx, ax
        mov  cx, ax
        add  di, abscisse
	  or   is_3, 0
	  jne  @_24_bits
        push cx
        mov  cl, toshift
        shl  di, cl
        pop  cx
 @return:
        add  ax, di
        cmp  ax, cx
        jae  @suite
        inc  dl
        @suite:
        cmp  dl, current_page
        je   @same_bank
        push ax
        push dx
	  mov  ax, dx
	  call newbank
        pop  dx
        pop  ax
 @same_bank:
        mov  cx, 0FFFFh
	  sub  cx, ax
        cmp  number, cx
        jna  @paspepin
        inc  cx
        push cx
        push dx
        les  si, line
        push 0A000h
        push ax
        push es
	  push si
	  push cx
        call movevesal
        pop  dx
        pop  cx
        inc  dx
	  push cx
        mov  ax, dx
        call newbank
        pop  cx
        mov  ax, number
        sub  ax, cx
        les  si, line
(*        add  si, cx*)
        push 0A000h
        push 0
	  push es
	  push di
        push ax
        call movevesal
        jmp  @fin

 @_24_bits:
        mov  si, di
        shl  di, 1
        add  di, si
        jmp  @return

 @paspepin:
        les  si, line
        push 0A000h
        push ax
	  push es
	  push si

        push number

        call movevesal
 @fin:
        pop  ds
end;

procedure uvesacleardevice;
var line : tline;
    y : integer;
begin
     fillchar(line, sizeof(line), 0);
     for y:=0 to getmaxy-1 do write_line(screen, line, y, getmaxx);
end;

(*We call graph procedures when needed, making conversion from longint to integer*)
procedure graphputpixel(bitmap : pimage;x, y : word;coul : longint);
begin
     grputpixel(x, y, coul);
end;

function graphgetpixel(bitmap : pimage;x, y : word) : longint;
begin
     graphgetpixel:=grgetpixel(x, y);
end;

procedure set4pixels(bitmap : pimage;x, y, xc, yc : integer; color : longint);
begin
     if x<>0 then begin
	  putpixel(bitmap, xc+x, yc+y, color);
	  putpixel(bitmap, xc-x, yc+y, color);
        if y<>0 then begin
           putpixel(bitmap, xc+x, yc-y, color);
           putpixel(bitmap, xc-x, yc-y, color);
        end;
     end else begin
         putpixel(bitmap, xc, yc+y, color);
         if y<>0 then putpixel(bitmap, xc, yc-y, color);
     end;
end;

(*procedure to draw an ellipse*)
(*bresenham algorithm*)
procedure ellipse(bitmap : pimage;xc, yc, a0, b0 : word;color: longint);
var
   x,y:integer;
   a,b,asquared,twoasquared,bsquared,twobsquared,d,dx,dy:longint;

begin
     x := 0;
     y := b0;
     a := a0;
     b := b0;
     asquared := a * a;
     twoasquared := 2 * asquared;
     bsquared := b * b;
     twobsquared := 2 * bsquared;
     d := bsquared - asquared*b + round ( asquared / longint ( 4 ));
     dx := 0;
     dy := twoasquared * b;
     while dx < dy do
     begin
	 set4pixels (bitmap, x, y, xc, yc, color );
       if d > longint ( 0 ) then begin
          dec ( y );
          dy := dy - twoasquared;
          d := d - dy;
	    end;
       inc ( x );
       dx := dx + twobsquared;
       d := d + bsquared + dx;
     end;
     d := d + ( round (((longint(3) * (asquared - bsquared ) / longint ( 2 )) - ( dx + dy )) / longint ( 2 )));
     while y >= 0 do
     begin
       set4pixels (bitmap, x, y, xc, yc, color);
       if d < longint ( 0 ) then begin
	    inc ( x );
	    dx := dx + twobsquared;
          d := d + dx;
       end;
     dec ( y );
     dy := dy - twoasquared;
     d := d + asquared - dy;
     end;
end;

(*right circle, including screen ratio*)
(*Note : if you know that ratio is good (ie getmaxx/getmaxy=4/3), avoid this function,
since it is quite slow*)
procedure circle(bitmap : pimage;xc, yc, r : word;coul : longint);
var x, y, scale10 : real;
    a, b : word;
begin
     scale10:=(getmaxx/getmaxy)/(4/3);
     r:=round(r/scale10);
     x:=r;
     y:=r*scale10;
     a:=round(sqrt(x*x+y*y));
     b:=round(a/scale10);
     ellipse(bitmap, xc, yc, a, b, coul);
end;

procedure Line(bitmap : pimage; x1, y1, x2, y2 : word;coul : longint);

var d, dx, dy,
    aincr, bincr,
    xincr, yincr,
    x, y                 : integer;

(*Swaps 2 integers*)
procedure SwapInt( var i1, i2: word );

var dummy : word;

begin
  dummy := i2;
  i2    := i1;
  i1    := dummy;
end;


begin
  if ( abs(x2-x1) < abs(y2-y1) ) then     (*travel : we go by axis X or Y ? *)
    begin                                      (*Y travel*)
	if ( y1 > y2 ) then
	  begin
      SwapInt( x1, x2 );                      (* we need to swap x1 and x2 *)
      SwapInt( y1, y2 );                                    (* and Y1 et Y2 *)
        end;

	if ( x2 > x1 ) then xincr := 1          (*which direction*)
                     else xincr := -1;

      dy := y2 - y1;
      dx := abs( x2-x1 );
      d  := 2 * dx - dy;
      aincr := 2 * (dx - dy);
      bincr := 2 * dx;
      x := x1;
      y := y1;

	putpixel( bitmap, x, y, coul );              (*first point*)
      for y:=y1+1 to y2 do                      (*Goes through y axis*)
        begin
          if ( d >= 0 ) then
            begin
		  inc( x, xincr );
              inc( d, aincr );
            end
          else
            inc( d, bincr );
          putpixel( bitmap, x, y, coul );
        end;
    end
  else                                               (*We'll go by X axis*)
    begin
	if ( x1 > x2 ) then
	  begin
      SwapInt( x1, x2 );
      SwapInt( y1, y2 );
        end;

	if ( y2 > y1 ) then yincr := 1            (*which direction*)
                     else yincr := -1;

      dx := x2 - x1;
      dy := abs( y2-y1 );
      d  := 2 * dy - dx;
      aincr := 2 * (dy - dx);
      bincr := 2 * dy;
      x := x1;
      y := y1;

	putpixel( bitmap, x, y, coul );
      for x:=x1+1 to x2 do
        begin
          if ( d >= 0 ) then
            begin
		  inc( y, yincr );
              inc( d, aincr );
            end
          else
            inc( d, bincr );
          putpixel( bitmap, x, y, coul );
       end;
    end;
end;

(*breseham algorithm to trace a line*)
(*assembler port*)
(*was removed, since it didn't make 32-bits calls*)
(*should very easly be rewritten to fit to unit*)
{procedure line(bitmap : pimage;x1, y1, x2, y2 : word;coul : longint);assembler;
var xincr : word;
asm
   mov  ax, x2
   mov  bx, x1
   sub  ax, bx
   jns  @positif01
   neg  ax
   @positif01:
   mov  di, ax
   mov  cx, y1
   mov  dx, y2
   sub  cx, dx
   jns  @positif02
   neg  cx
   @positif02:
   cmp  ax, cx
   jnb  @below

   mov  ax, y1
   mov  bx, y2

   cmp  ax, bx
   jna  @suite01
   mov  y1, bx
   mov  y2, ax
   push ax
   push bx
   mov  ax, x1
   mov  bx, x2
   mov  x2, ax
   mov  x1, bx
   pop  bx
   pop  ax
   @suite01:

   mov  ax, x2
   mov  bx, x1
   mov  dx, 1
   cmp  ax, bx
   ja   @suite02
   mov  dx, -1
   @suite02:
   mov  xincr, dx
   mov  bx, di (*bx=abs(x2-x1) cx=y2-y1*)
   mov  ax, bx
   shl  ax, 1
   mov  si, ax (*si=bincr*)
   sub  ax, cx
   mov  es, ax (*es=d*)

   mov  ax, y2
   sub  ax, y1
   push bx
   sub  bx, ax
   mov  ax, bx
   pop  bx
   shl  ax, 1
   mov  di, ax (*di=aincr*)

   mov  dx, x1
   mov  ax, y1

   pusha
   push es

   push dx
   push ax
   push word ptr [coul+2]
   push word ptr coul
   call bitmap.putpixel
   pop  es
   popa

   inc  ax
   @loop01:
   push ax
   mov  ax, es
   or   ax, ax
   pop  ax
   jnge @suite03
   add  dx, xincr
   push ax
   mov  ax, es
   add  ax, di
   mov  es, ax
   pop  ax
   jmp  @suite04
   @suite03:
   push ax
   mov  ax, es
   add  ax, si
   mov  es, ax
   pop  ax
   @suite04:

   pusha
   push es
   push dx
   push ax
   push word ptr [coul+2]
   push word ptr coul
   call putpixel
   pop  es
   popa

   inc  ax
   cmp  ax, y2
   jbe  @loop01
   jmp  @fin


   @below:

   mov  ax, x2
   mov  bx, x1
   sub  ax, bx
   jns  @positif012
   neg  ax
   @positif012:
   mov  di, ax
   mov  cx, y1
   mov  dx, y2
   sub  cx, dx
   jns  @positif022
   neg  cx
   @positif022:
   cmp  ax, cx

   mov  ax, x1
   mov  bx, x2

   cmp  ax, bx
   jna  @suite012
   mov  x1, bx
   mov  x2, ax
   push ax
   push bx
   mov  ax, y1
   mov  bx, y2
   mov  y2, ax
   mov  y1, bx
   pop  bx
   pop  ax
   @suite012:

   mov  ax, y2
   mov  bx, y1
   mov  dx, 1
   cmp  ax, bx
   ja   @suite022
   mov  dx, -1
   @suite022:
   mov  xincr, dx
   mov  ax, x2
   sub  ax, x1
   mov  bx, ax
   (*bx=abs(x2-x1) cx=y2-y1*)
   mov  ax, cx
   shl  ax, 1
   mov  si, ax (*si=bincr*)
   sub  ax, bx
   mov  es, ax (*es=d*)

   mov  ax, y2
   sub  ax, y1
   jns  @suite32
   neg  ax
   @suite32:
   sub  ax, bx
   shl  ax, 1
   mov  di, ax (*di=aincr*)

   mov  dx, x1
   mov  ax, y1

   pusha
   push es

   push dx
   push ax
   push word ptr [coul+2]
   push word ptr coul
   call putpixel
   pop  es
   popa

   inc  dx
   @loop012:
   push ax
   mov  ax, es
   or   ax, ax
   pop  ax
   jnge @suite032
   add  ax, xincr
   push ax
   mov  ax, es
   add  ax, di
   mov  es, ax
   pop  ax
   jmp  @suite042
   @suite032:
   push ax
   mov  ax, es
   add  ax, si
   mov  es, ax
   pop  ax
   @suite042:

   pusha
   push es
   push dx
   push ax
   push word ptr [coul+2]
   push word ptr coul
   call putpixel
   pop  es
   popa

   inc  dx
   cmp  dx, x2
   jbe  @loop012
@fin:
end;
}

procedure moveto(bitmap : pimage;x, y : word);
begin
     bitmap^.x:=x;
     bitmap^.y:=y;
end;

procedure setcolor(color : longint);
begin
     currentcolor:=color;
end;

procedure lineto(bitmap : pimage;x, y : word);
begin
     line(bitmap, bitmap^.x, bitmap^.y, x, y, currentcolor);
     moveto(bitmap, x, y);
end;

procedure clear_bitmap(bitmap : pimage);
var line : tline;
    y : word;
begin
     filldouble(line, bitmap^.width, 0);
     for y:=0 to bitmap^.height do write_line(bitmap, line, y, bitmap^.width);
end;

procedure clear_bitmap2(bitmap : pimage;colx:word);
var line : tline;
    y : word;
begin
     filldouble(line, bitmap^.width, colx);
     for y:=0 to bitmap^.height do write_line(bitmap, line, y, bitmap^.width);
end;

(*fillarea part*)
(*Fills an area by by scan line*)
(*Quite fast*)
const up=-1;
      down=1;

var fillvalue, oldvalue : longint;

procedure scanleft(bitmap : pimage;var x, y : word);
var v : longint;
begin
     if x>0 then begin
        repeat
              x:=x-1;
              v:=getpixel(bitmap, x, y);
	  until (not ((v=oldvalue) and (v<>fillvalue))) or (x=0);
     end;
     inc(x);
end;

procedure scanright(bitmap : pimage;var x, y : word);
var v : longint;
begin
     if x<getmaxx-1 then begin
        repeat
		  x:=x+1;
		  v:=getpixel(bitmap, x, y);
        until (not ((v=oldvalue) and (v<>fillvalue))) or (x=getmaxx-1);
     end;
     dec(x);
end;

procedure fillarea(bitmap : pimage;x, y : word;coul : longint);
var xl, xr : word;
    line : tline;

function lineadjfill(seedx, seedy : word;d : integer;prevxl, prevxr : word) : word;
var x, y, xl, xr : word;
    v : longint;
begin
     y:=seedy;
     xl:=seedx;
     xr:=seedx;

     scanleft(bitmap, xl, y);
     scanright(bitmap, xr, y);

     write_linepos(screen, line, xl, y, xr-xl+1);

     x:=xl;
     while (x<=xr) do begin
         v:=getpixel(bitmap, x, y+d);
         if (v=oldvalue) and (v<>fillvalue) then x:=lineadjfill(x, y+d, d, xl, xr);
         inc(x);
     end;

     x:=xl;
     while(x<=prevxl-1) do begin
	   v:=getpixel(bitmap, x, y-d);
         if (v=oldvalue) and (v<>fillvalue) then x:=lineadjfill(x, y-d, -d, xl, xr);
         inc(x);
     end;

     lineadjfill:=xr;
end;

begin
     oldvalue:=getpixel(bitmap, x, y);
     fillvalue:=coul;
     filldouble(line, 1024, fillvalue);
     xl:=x;
     xr:=x;
     scanleft(bitmap, xl, y);
     scanleft(bitmap, xr, y);
     lineadjfill(x, y, up, xl, xr);
     lineadjfill(x, y, down, xl, xr);
end;

(*Function to close graph modes*)
procedure done_graph;
begin
     closegraph;
     done_general;
end;

(*finds the mode (between vesa and mode 13h, NOT graph ones) that is the nearest of getmaxx_required
and getmaxy_required, with bit_per_pixel bits per pixel.
it will set mode to the mode finded, will put in getmaxx_required and getmaxy_required
the resolution finded, and will return the square distance of the parameters to the mode
finded. If value returned is -1, then no mode were finded.
Note that :
. it will only find modes with resolution greater then parameters. Lower resolutions are ignored
. passing a 24 bits or a 32 bits paramter is totally different. So, to find a 16M color mode,
  you have to call this twice : first with 24 bits per pixel, second with 32 bits per pixel.
  the value returned will help you finding the best.
  If both are equivalent, use 32 bits modes, they are a LOT faster than 24 bits*)
(*You should call this preferently to a value to init_mode*)
function find_best_mode(var getmaxx_required, getmaxy_required : word;bit_per_pixel : word) : longint;

type tmode = record
                   number, getmaxx, getmaxy : word;
             end;
     tmodearray = array[0..0] of tmode;

var regs : registers;
    modes : ^word;
    possible_modes : ^tmodearray;
    pos_in_tab, i, tempx, tempy, nb_modes : word;
    minimum, current : longint;

begin
     set_death_color(256);
     regs.ax:=$4f00;
     regs.es:=seg(vesa1);
     regs.di:=ofs(vesa1);
     intr($10, regs);
     tempx:=0;
     tempy:=0;
     if regs.ax<>$004f
        then begin
             if (getmaxx_required>=320) and (getmaxy_required>=200) and (bit_per_pixel=8)
		    then begin
			   mode:=0;
                     find_best_mode:=sqr(320-getmaxx_required)+sqr(200-getmaxy_required);
                     getmaxx_required:=320;
                     getmaxy_required:=200;
                end else find_best_mode:=-1;
		 exit;
        end;

     modes:=vesa1.codes;
     while (modes^<>$ffff) do begin
           inc(nb_modes);
           inc(modes);
     end;
     getmem(possible_modes, nb_modes*sizeof(word));

     modes:=vesa1.codes;
     pos_in_tab:=0;
     while (modes^<>$ffff) do begin
           regs.ax:=$4f01;
           regs.cx:=modes^;
           regs.es:=seg(vesa2);
	     regs.di:=ofs(vesa2);
           intr($10, regs);
           if ( ( vesa2.f_mode and 1 ) <> 0 ) and ( vesa2.bitperpixel=bit_per_pixel )
              then begin
                   possible_modes^[pos_in_tab].number:=modes^;
                   possible_modes^[pos_in_tab].getmaxx:=vesa2.resx;
                   possible_modes^[pos_in_tab].getmaxy:=vesa2.resy;
                   inc(pos_in_tab);
              end;
           inc(modes);
     end;

     if (getmaxx_required<=320) and (getmaxy_required<=200) and (bit_per_pixel=8)
        then begin
             mode:=0;
             minimum:=sqr(320-getmaxx_required)+sqr(200-getmaxy_required);
		 tempx:=320;
             tempy:=200;
        end else minimum:=2000000000;
     if (pos_in_tab=0) and (minimum=2000000000)
        then begin
             find_best_mode:=-1;
             exit;
        end;
     for i:=0 to pos_in_tab-1 do begin
         if (possible_modes^[i].getmaxx>=getmaxx_required) and (possible_modes^[i].getmaxy>=getmaxy_required)
		then begin
		     current:=sqr(possible_modes^[i].getmaxx-getmaxx_required)+sqr(possible_modes^[i].getmaxy-getmaxy_required);
                 if current<minimum
                    then begin
                         mode:=possible_modes^[i].number;
                         minimum:=current;
				 tempx:=possible_modes^[i].getmaxx;
                         tempy:=possible_modes^[i].getmaxy;
                    end;
            end;
     end;

     getmaxx_required:=tempx;
     getmaxy_required:=tempy;
     if minimum<>2000000000
        then find_best_mode:=minimum
     else find_best_mode:=-1;

     freemem(possible_modes, nb_modes*sizeof(word));
end;


function init_mode : boolean;
var temp : boolean;
    grmode, grdriver : integer;
begin
     (*mcga ?*)
     if (mode=0) or (mode=65535) then begin
        if mode=0 then temp:=umcgainit(false) else temp:=umcgainit(true);
        if not temp then begin
           init_mode:=false;
	     exit;
        end;
        with screen^ do begin
             putpixel:=umcgaputpixel;
             getpixel:=umcgagetpixel;
             write_line:=umcgawrite_line;
             read_line:=umcgaread_line;
		 write_linepos:=umcgawrite_linepos;
		 read_linepos:=umcgaread_linepos;
	  end;
	  write_palette:=ugrafwrite_palette;
	  getmaxx:=320;
        getmaxy:=200;
        nb_colors:=256;
        nb_colors_mask:=255;
        done_graf:=done_bidon;
	  read_palette:=ugrafread_palette;
        lln:=320;
     end else if mode>=$100 then begin
         (*vesa mode ?*)
         if not uvesasetmode(mode) then begin
            init_mode:=false;
            exit;
         end;
         if vesa2.bitperpixel<=8 then begin
            screen^.putpixel:=uvesaputpixel8;
		screen^.getpixel:=uvesagetpixel8;
	   end else if vesa2.bitperpixel<=16 then begin
             screen^.putpixel:=uvesaputpixel16;
             screen^.getpixel:=uvesagetpixel16;
         end else if vesa2.bitperpixel<=24 then begin
             screen^.putpixel:=uvesaputpixel24;
		 screen^.getpixel:=uvesagetpixel24;
         end else if vesa2.bitperpixel=32 then begin
             screen^.putpixel:=uvesaputpixel32;
             screen^.getpixel:=uvesagetpixel32;
         end;
        write_palette:=ugrafwrite_palette;
        with screen^ do begin
             write_line:=uvesawrite_line_vesa;
             read_line:=uvesaread_line_vesa;
		 write_linepos:=uvesawrite_line_vesapos;
		 read_linepos:=uvesaread_line_vesapos;
	  end;
        done_graf:=done_bidon;
        read_palette:=ugrafread_palette;
     end else if (mode>=1) and (mode<=31) then begin
         (*graph mode ?*)
	   if mode in [driver_cga..fin_cga] then begin grmode:=mode-driver_cga;grdriver:=cga;end;
         if mode in [driver_mcga..fin_mcga] then begin grmode:=mode-driver_mcga;grdriver:=mcga;end;
         if mode in [driver_ega..fin_ega] then begin grmode:=mode-driver_ega;grdriver:=ega;end;
         if mode in [driver_ega64..fin_ega64] then begin grmode:=mode-driver_ega64;grdriver:=ega64;end;
         if mode in [driver_egamono..fin_egamono] then begin grmode:=mode-driver_egamono;grdriver:=egamono;end;
         if mode in [driver_ibm8514..fin_ibm8514] then begin grmode:=mode-driver_ibm8514;grdriver:=ibm8514;end;
         if mode in [driver_hercmono..fin_hercmono] then begin grmode:=mode-driver_hercmono;grdriver:=hercmono;end;
         if mode in [driver_att400..fin_att400] then begin grmode:=mode-driver_att400;grdriver:=att400;end;
         if mode in [driver_vga..fin_vga] then begin grmode:=mode-driver_vga;grdriver:=vga;end;
         if mode in [driver_pc3270..fin_pc3270] then begin grmode:=mode-driver_pc3270;grdriver:=pc3270;end;
	   initgraph(grdriver, grmode, 'c:\tp7\bgi');
	   if graphresult<>grok then init_mode:=false else init_mode:=true;
         grputpixel:=graph.putpixel;
         grgetpixel:=graph.getpixel;
         screen^.putpixel:=graphputpixel;
         screen^.getpixel:=graphgetpixel;
	   if mode in [driver_vga..fin_vga] then write_palette:=ugrafwrite_palette else write_palette:=rien;
         with screen^ do begin
              write_line:=write_line_graph;
              read_line:=read_line_graph;
		  write_linepos:=write_line_graphpos;
		  read_linepos:=read_line_graphpos;
	   end;
         getmaxx:=graph.getmaxx;
         getmaxy:=graph.getmaxy;
         nb_colors:=getmaxcolor+1;
	   nb_colors_mask:=nb_colors-1;
	   done_graf:=done_graph;
         read_palette:=rien_lectpal;
         lln:=getmaxx;
     end else init_mode:=false; (*what's this ?*)
     (*only update mode2 if mode is not a "don't clear video ram" mode*)
     (*actually is not supported by graph modes*)
     (*And actually, it's not a good idea to use theese switch to text procedures*)
     if mode < 32767 then mode2:=mode else if mode=65535 then mode2:=0 else mode2:=mode and 32767;
     (*Set default font*)
     SetStartChar(0);
     SetFont (@fontik,8,8);
     screen^.x:=0;
     screen^.y:=0;
     screen^.height:=getmaxy;
     screen^.width:=getmaxx;
     init_mode:=true;
end;

(*procedure to switch to text mode*)
(*test procedures !!!*)
function taille_buffer : word;assembler;
asm
   mov  ax, 4f04h
   xor  dx, dx
   mov  cx, 0ffffh
   int  10h
   mov  ax, bx
end;

procedure sauve_etat(var buf);assembler;
asm
   mov  ax, 4f04h
   mov  dx, 1
   mov  cx, 0ffffh
   les  bx, buf
   int  10h
end;

procedure restaure_etat(var buf);assembler;
asm
   mov  ax, 4f04h
   mov  dx, 2
   mov  cx, 0ffffh
   les  bx, buf
   int  10h
end;

procedure totextmode;
var toto, t, x : word;
begin
     toto:=2;
     t:=0;
     repeat
	     for x:=0 to 60 do buf[t*61+x]:=getpixel(screen, toto, x);
           inc(toto, 4);
           inc(t);
     until (toto>getmaxx-1);
     asm
        mov  ax, 3+128
        int  10h
     end;
end;

procedure restauretxt;
var oldmode : integer;
    toto, t, x : word;
begin
     oldmode:=mode;
     if mode=0 then mode:=65535 else mode:=mode or 32768;
     init_mode;
     mode:=oldmode;
     putpixel(screen, getmaxx-1, getmaxy-1, getpixel(screen, getmaxx-1, getmaxy-1));
     putpixel(screen, 0, 0, getpixel(screen, 0, 0));
     toto:=2;
     t:=0;
     repeat
           for x:=0 to 60 do putpixel(screen, toto, x, buf[t*61+x]);
           inc(toto, 4);
           inc(t);
     until (toto>getmaxx-1);
end;

procedure rectangle(bitmap : pimage;x1, y1, x2, y2 : word);
var line : tline;
    i, temp, toto : integer;
begin
     temp:=abs(y2-y1);
     filldouble(line, temp+1, currentcolor);
     if x1<x2 then toto:=x1 else toto:=x2;
     write_linepos(bitmap, line, y1, toto, temp);
     write_linepos(bitmap, line, y2, toto, temp);
     for i:=y1 to y2 do begin
	   putpixel(bitmap, x1, i, currentcolor);
	   putpixel(bitmap, x2, i, currentcolor);
     end;
end;

procedure rectangle2(bitmap : pimage;x1, y1, x2, y2,col : word);
var line : tline;
    i ,xi: integer;
    l    : longint;
begin
    Filldouble(line,x2,col);
    for i:=y1 to y1+y2-1 do write_linepos(bitmap, line, x1, i, x2);
end;

procedure rectangle3(bitmap : pimage;x1, y1, x2, y2,col : word);
var line : tline;
    i, temp, toto : integer;
begin
     temp:=abs(x2-x1);
     filldouble(line, temp, col);
     if x1<x2 then toto:=x1+1 else toto:=x2+1;
     write_linepos(bitmap, line, toto, y1, temp-1);
     write_linepos(bitmap, line, toto, y2, temp-1);
     for i:=y1+1 to y2-1 do begin
         putpixel(bitmap, x1, i, col);
	   putpixel(bitmap, x2, i, col);
     end;
     putpixel(bitmap, x1+1, y1+1, col);
     putpixel(bitmap, x2-1, y1+1, col);
     putpixel(bitmap, x1+1, y2-1, col);
     putpixel(bitmap, x2-1, y2-1, col);
end;


(*N. De Smedt stuff*)
Procedure Arc (bitmap : pimage;x_center, y_center, radius, s_angle, e_angle : Word);
{ An algorithm to draw an arc. Crude but it works (anyone have a better one?) }
Var
  p : Integer;
  x, y : Word;
  Alpha : Real;

Begin
  If radius=0 then Begin PutPixel (bitmap, x_center,y_center,currentColor); Exit; End;
  s_angle:=s_angle MOD 361;
  e_angle:=e_angle MOD 361;
  If s_angle>e_angle then Begin
    s_angle:=s_angle Xor e_angle; e_angle:=e_angle Xor s_angle; s_angle:=e_angle Xor s_angle;
  End;
  x:=0;
  y:=Radius;
  p:=3-2*Radius;
  While x<=y Do Begin
    Alpha:=RadToDeg*Arctan (x/y);
    If (Alpha>=s_angle) And (Alpha<=e_angle) then PutPixel (bitmap, x_center-x, y_center-y, currentColor);
    If (90-Alpha>=s_angle) And (90-Alpha<=e_angle) then PutPixel (bitmap, x_center-y, y_center-x, currentcolor);
    If (90+Alpha>=s_angle) And (90+Alpha<=e_angle) then PutPixel (bitmap, x_center-y, y_center+x, currentcolor);
    If (180-Alpha>=s_angle) And (180-Alpha<=e_angle) then PutPixel (bitmap, x_center-x, y_center+y, currentcolor);
    If (180+Alpha>=s_angle) And (180+Alpha<=e_angle) then PutPixel (bitmap, x_center+x, y_center+y, currentcolor);
    If (270-Alpha>=s_angle) And (270-Alpha<=e_angle) then PutPixel (bitmap, x_center+y, y_center+x, currentcolor);
    If (270+Alpha>=s_angle) And (270+Alpha<=e_angle) then PutPixel (bitmap, x_center+y, y_center-x, currentcolor);
    If (360-Alpha>=s_angle) And (360-Alpha<=e_angle) then PutPixel (bitmap, x_center+x, y_center-y, currentcolor);
    If p<0 then
      p:=p+4*x+6
    Else Begin
      p:=p+4*(x-y)+10;
      Dec (y);
    End;
    Inc (x);
  End;
End;

Procedure EllipseArc (bitmap : pimage;x_center, y_center, rx, ry, s_angle, e_angle : Word);
{ Draw an ellipse arc. Crude but it works (anyone have a better one?) }
Var
  aSqr, bSqr, twoaSqr, twobSqr, x, y, twoXbSqr, twoYaSqr, error : LongInt;
  Alpha : Real;

Procedure PlotPoints;

Begin
  If (Alpha>=s_angle) And (Alpha<=e_angle) then PutPixel (bitmap, x_center-x,y_center-y,currentcolor);
  If (180-Alpha>=s_angle) And (180-Alpha<=e_angle) then PutPixel (bitmap, x_center-x,y_center+y,currentcolor);
  If (180+Alpha>=s_angle) And (180+Alpha<=e_angle) then PutPixel (bitmap, x_center+x,y_center+y,currentcolor);
  If (360-Alpha>=s_angle) And (360-Alpha<=e_angle) then PutPixel (bitmap, x_center+x,y_center-y,currentcolor);
End;

Begin
  If rx=0 then Begin
    Line (bitmap, x_center,y_center-ry,x_center,y_center+ry, currentcolor);
    Exit;
  End;
  s_angle:=s_angle MOD 361;
  e_angle:=e_angle MOD 361;
  If s_angle>e_angle then Begin
    s_angle:=s_angle Xor e_angle; e_angle:=e_angle Xor s_angle; s_angle:=e_angle Xor s_angle;
  End;
  aSqr:=LongInt (rx)*LongInt (rx);
  bSqr:=LongInt (ry)*LongInt (ry);
  twoaSqr:=2*aSqr;
  twobSqr:=2*bSqr;
  x:=0;
  y:=ry;
  twoXbSqr:=0;
  twoYaSqr:=y*twoaSqr;
  error:=-y*aSqr;
  While twoXbSqr<=twoYaSqr Do Begin
    If y=0 then Alpha:=90 Else Alpha:=RadToDeg*Arctan (x/y); { Crude but it works }
    PlotPoints;
    Inc (x);
    Inc (twoXbSqr,twobSqr);
    Inc (error,twoXbSqr-bSqr);
    If error>=0 then Begin
      Dec (y);
      Dec (twoYaSqr,twoaSqr);
	Dec (error,twoYaSqr);
    End;
  End;
  x:=rx;
  y:=0;
  twoXbSqr:=x*twobSqr;
  twoYaSqr:=0;
  error:=-x*bSqr;
  While twoXbSqr>twoYaSqr Do Begin
    If y=0 then Alpha:=90 Else Alpha:=RadToDeg*Arctan (x/y);
    PlotPoints;
    Inc (y);
    Inc (twoYaSqr,twoaSqr);
    Inc (error,twoYaSqr-aSqr);
    If error>=0 then Begin
      Dec (x);
	Dec (twoXbSqr,twobSqr);
	Dec (error,twoXbSqr);
    End;
  End;
End;

function  load_palette(sub:string;var target_pal:tpalette;from_col,to_col:byte;write_it:boolean):boolean;
type pal=array[1..768] of byte;
var
    f,ff,rgb:word;
    sr:searchrec;
    plex:^pal;
begin
    findfirst(sub,$3f,sr);
    if (doserror=0)  then begin;
    new(plex);
    fileread(sub,0,1,768,plex^);
    rgb:=0;
    for f:=from_col*3 to to_col*3 do begin
        inc(rgb);
        if rgb>3 then rgb:=1;
        case rgb of
		 1:target_pal[f div 3].r:=plex^[f+1]shr 2;
             2:target_pal[f div 3].v:=plex^[f+1]shr 2;
             3:target_pal[f div 3].b:=plex^[f+1]shr 2;
        end;
    end;
    dispose(plex);
    if write_it then write_palette(target_pal,from_col,to_col);
    load_palette:=true;
 end
 else load_palette:=false;
end;

procedure fill_palette_black(var pal:tpalette);
var f:byte;
begin
  for f:=0 to 255 do begin
	pal[f].r:=0;
      pal[f].v:=0;
      pal[f].b:=0;
  end;
  tma:=true;
end;

procedure fill_palette(var pal:tpalette; col:byte);
var f:byte;
begin
  for f:=0 to 255 do begin
      pal[f].r:=col;
      pal[f].v:=col;
      pal[f].b:=col;
  end;
  tma:=true;
end;

procedure decreaseup_palette(palx:tpalette;time:longint);
var fpal,ffpal,ffx:word;
    all:boolean;
label skip;
begin
 if not tma then begin
  tma:=true;
  for ffpal:=0 to 255 do begin
      all:=true;
    wait_for_time(time);
      for ffx:=0 to 255 do begin
        if not((palx[ffx].b=255) and (palx[ffx].r=255)
           and (palx[ffx].v=255)) then all:=false;
        end;
           if all then goto skip;
    for fpal:=0 to 255 do begin
        if palx[fpal].v<254 then inc(palx[fpal].v);
        if palx[fpal].r<254 then inc(palx[fpal].r);
        if palx[fpal].b<254 then inc(palx[fpal].b);
	  if keypressed then key;
    end;
        write_palette(palx,0,256);
  end;
 end;
  skip:
end;

procedure decrease_palette(palx:tpalette;time:longint);
var fpal,ffpal,ffx:word;
    all:boolean;
label skip;
begin
 if not tma then begin
  tma:=true;
  for ffpal:=0 to 255 do begin
	all:=true;
    wait_for_time(time);
      for ffx:=0 to 255 do begin
        if not((palx[ffx].b=0) and (palx[ffx].r=0)
           and (palx[ffx].v=0)) then all:=false;
        end;
	     if all then goto skip;
    for fpal:=0 to 255 do begin
        if palx[fpal].v>0 then dec(palx[fpal].v);
        if palx[fpal].r>0 then dec(palx[fpal].r);
        if palx[fpal].b>0 then dec(palx[fpal].b);
        if keypressed then key;

    end;
        write_palette(palx,0,256);
  end;
 end;
  skip:
end;

procedure increase_palette(start,palx:tpalette;time:longint);
var fpal,ffpal,ffx:word;
    all:boolean;
begin
 if tma then begin
  tma:=false;
  for ffpal:=0 to 63 do begin
      all:=false;
      wait_for_time(time);
      for fpal:=0 to 255 do begin
	  if (palx[fpal].v>start[fpal].v) then begin all:=true; inc(start[fpal].v); end
             else if (palx[fpal].v<start[fpal].v) then begin all:=true; dec(start[fpal].v); end;
	  if (palx[fpal].r>start[fpal].r) then begin all:=true; inc(start[fpal].r); end
             else if (palx[fpal].r<start[fpal].r) then begin all:=true; dec(start[fpal].r); end;
	  if (palx[fpal].b>start[fpal].b) then begin all:=true; inc(start[fpal].b); end
             else if (palx[fpal].b<start[fpal].b) then begin all:=true; dec(start[fpal].b); end;
	  if keypressed then key;
      end;
      write_palette(start,0,256);
      if not all then break;
  end;
  write_palette(palx,0,256);
 end;
end;

Procedure Curve (bitmap : pimage;x1, y1, x2, y2, x3, y3 : Integer; Segments : Word);
{ Draw a curve from (x1,y1) through (x2,y2) to (x3,y3) divided in 'Segments' segments }
Var
  lsteps, ex, ey, fx, fy : LongInt;
  t1, t2 : Integer;

Begin
  x2:=(x2 SHL 1)-((x1+x3) SHR 1);
  y2:=(y2 SHL 1)-((y1+y3) SHR 1);
  lsteps:=Segments;
  If (lsteps<2) then lsteps:=2;
  If (lsteps>128) then lsteps:=128;  { Clamp value to avoid overcalculation }
  ex:=(LongInt (x2-x1) SHL 17) DIV lsteps;
  ey:=(LongInt (y2-y1) SHL 17) DIV lsteps;
  fx:=(LongInt (x3-(2*x2)+x1) SHL 16) DIV (lsteps*lsteps);
  fy:=(LongInt (y3-(2*y2)+y1) SHL 16) DIV (lsteps*lsteps);
  Dec (lsteps);
  While lsteps>0 Do Begin
    t1:=x3;
    t2:=y3;
    x3:=(((fx*lsteps+ex)*lsteps) SHR 16)+x1;
    y3:=(((fy*lsteps+ey)*lsteps) SHR 16)+y1;
    Line (bitmap, t1,t2,x3,y3, currentcolor);
    Dec (lsteps);
  End;
  Line (bitmap, x3,y3,x1,y1, currentcolor);
End;

Procedure CubicBezierCurve (bitmap : pimage;x1, y1, x2, y2, x3, y3, x4, y4 : Integer; Segments : Word);
{ Draw a cubic bezier-curve using the basis functions directly }
Var
  tx1, tx2, tx3, ty1, ty2, ty3, mu, mu2, mu3, mudelta : Real;
  xstart, ystart, xend, yend, n : Integer;

Begin
  If (Segments<1) then Exit;
  If Segments>128 then Segments:=128; { Clamp value to avoid overcalculation }

  mudelta:=1/Segments;
  mu:=0;
  tx1:=-x1+3*x2-3*x3+x4; ty1:=-y1+3*y2-3*y3+y4;
  tx2:=3*x1-6*x2+3*x3;   ty2:=3*y1-6*y2+3*y3;
  tx3:=-3*x1+3*x2;       ty3:=-3*y1+3*y2;

  xstart:=x1;
  ystart:=y1;
  mu:=mu+mudelta;
  For n:=1 to Segments Do Begin
    mu2:=mu*mu;
    mu3:=mu2*mu;
    xend:=Round (mu3*tx1+mu2*tx2+mu*tx3+x1);
    yend:=Round (mu3*ty1+mu2*ty2+mu*ty3+y1);
    Line (bitmap, xstart, ystart, xend, yend, currentcolor);
    mu:=mu+mudelta;
    xstart:=xend;
    ystart:=yend;
  End;
End;

Procedure BSpline (bitmap : pimage;NumPoints : Word; Var Points : Array Of tPoint; Segments : Word);
{ Draw a BSpline approximating a curve defined by the array of points.  }
{ Beware! A B-Spline generaly does not pass through the points defining }
{ it !                                                                  }
Function Calculate (mu : Real; p0, p1, p2, p3 : Integer) : Integer;

Var
  mu2, mu3 : Real;

Begin
  mu2:=mu*mu;
  mu3:=mu2*mu;
  Calculate:=Round ((1/6)*(mu3*(-p0+3*p1-3*p2+p3)+
                           mu2*(3*p0-6*p1+3*p2)+
                           mu *(-3*p0+3*p2)+(p0+4*p1+p2)));
End;

Var
  mu, mudelta : Real;
  x1, y1, x2, y2, n, h : Integer;

Begin
  If (NumPoints<4) Or (NumPoints>16383) then Exit;
  mudelta:=1/Segments;
  For n:=3 to NumPoints-1 Do Begin
    mu:=0;
    x1:=Calculate (mu,Points[n-3].x,Points[n-2].x,Points[n-1].x,Points[n].x);
    y1:=Calculate (mu,Points[n-3].y,Points[n-2].y,Points[n-1].y,Points[n].y);
    mu:=mu+mudelta;
    For h:=1 to Segments Do Begin
      x2:=Calculate (mu,Points[n-3].x,Points[n-2].x,Points[n-1].x,Points[n].x);
      y2:=Calculate (mu,Points[n-3].y,Points[n-2].y,Points[n-1].y,Points[n].y);
      Line (bitmap, x1, y1, x2, y2, currentcolor);
      mu:=mu+mudelta;
      x1:=x2;
      y1:=y2;
    End;
  End;
End;

Procedure Catmull_Rom_Spline (bitmap : pimage;NumPoints : Word; Var Points : Array Of tPoint; Segments : Word);
{ Draw a spline approximating a curve defined by the array of points.   }
{ In contrast to the BSpline this curve will pass through the points    }
{ defining is except the first and the last point. The curve will only  }
{ pass through the first and the last point if these points are given   }
{ twice after eachother, like this :                                    }
{ Array of points :                                                     }
{                                                                       }
{  First point defined twice           Last point defined twice         }
{   |-----|                                |----------|                 }
{ (0,0),(0,0),(100,100),....,(150,100),(200,200),(200,200)              }
{ the curve defined by these points will pass through all the points.   }
Function Calculate (mu : Real; p0, p1, p2, p3 : Integer) : Integer;

Var
  mu2, mu3 : Real;

Begin
  mu2:=mu*mu;
  mu3:=mu2*mu;
  Calculate:=Round ((1/2)*(mu3*(-p0+3*p1-3*p2+p3)+
                           mu2*(2*p0-5*p1+4*p2-p3)+
                           mu *(-p0+p2)+(2*p1)));
End;

Var
  mu, mudelta : Real;
  x1, y1, x2, y2, n, h : Integer;

Begin
  If (NumPoints<4) Or (NumPoints>16383) then Exit;
  mudelta:=1/Segments;
  For n:=3 to NumPoints-1 Do Begin
    mu:=0;
    x1:=Calculate (mu,Points[n-3].x,Points[n-2].x,Points[n-1].x,Points[n].x);
    y1:=Calculate (mu,Points[n-3].y,Points[n-2].y,Points[n-1].y,Points[n].y);
    mu:=mu+mudelta;
    For h:=1 to Segments Do Begin
      x2:=Calculate (mu,Points[n-3].x,Points[n-2].x,Points[n-1].x,Points[n].x);
      y2:=Calculate (mu,Points[n-3].y,Points[n-2].y,Points[n-1].y,Points[n].y);
      Line (bitmap, x1, y1, x2, y2, currentcolor);
      mu:=mu+mudelta;
      x1:=x2;
      y1:=y2;
    End;
  End;
End;

Procedure DrawPoly (bitmap : pimage;NumPoints : Word; Var Points : Array Of tPoint);
{ Draw the outline of a polygon }
Var
  n : Word;

Begin
  If (NumPoints=0) Or (NumPoints>16383) then Exit;
  For n:=0 to NumPoints-1 Do Begin
    Line (bitmap, Points[n].x,Points[n].y,Points[(n+1) MOD NumPoints].x,Points[(n+1) MOD NumPoints].y, currentcolor);
  End;
End;

procedure Font_Load2(fmeno:string;var fx,fy:word);
var ftt:text;
    tx:file;
    fdlzka,ftransf,mox:word;
    mach:char;
begin
 assign(ftt,fmeno);
 reset(ftt);
   read(ftt,fdlzka);
   read(ftt,fx);
   read(ftt,fy);
   read(ftt,ftransf);
   read(ftt,mach);
  for mox:=1 to fdlzka do begin read(ftt,mach);
      fontik[mox]:=ord(mach);
  end;
 close(ftt);
{ fileread(fmeno,12,fdo,fdlzka,fontik);}
 setstartchar(-ftransf);
 SetFont (@fontik,fx,fy);
end;

procedure FontLoad(fmeno:string;fod,fdo,fdlzka,fx,fy,ftrans:integer);
begin
 fileread(fmeno,fod,fdo,fdlzka,fontik);
 setstartchar(ftrans);
 SetFont (@fontik,fx,fy);
end;

procedure inicializuj(resolution_x,resolution_y,bits_per_pixel:word);
begin
     if find_best_mode(resolution_x, resolution_y, bits_per_pixel)=-1
        then begin
             done_graf;
             writeln('Nie je mozne najst graficky mod !!!');
             halt(250);
	  end;


     if not init_mode
        then begin
             done_graf;
             writeln('Nie je mozne aktivovat graficky mod ....');
             halt(2);
        end;
end;

procedure koniec(s:string;break:boolean);
begin
 done_graf;
 videomode(3);
 writeln;
 writeln(s);
 if break then halt(255);
end;

procedure prints(bitmap:pimage;x,y,pox,poy:integer;s:string;textcolor:longint;shadow,roll:integer);
begin
 printx(bitmap,x+pox,y+poy,s,shadow,0);
 printx(bitmap,x,y,s,textcolor,roll);
end;

procedure printc(bitmap:pimage;y:integer;s:string;textcolor:longint;roll:integer);
begin
  print_normal(bitmap,(getmaxx div 2)-(length(s)*chardx div 2),y,s,textcolor,roll);
end;

Procedure Printx (bitmap : pimage;x, y : Integer; s : String; TextColor : longint;roll:integer);
{ Put the given string on the screen using the current font }
Var
  ByteRange, c, n, h, i : Integer;
  DataIndex, Index, Size : Word;
  b : Byte;
  line1 : tline;

Begin
  If Font=NIL then Exit;
  Size:=FontScaleX*CharDX;
  ByteRange:=1+((CharDX-1) SHR 3);
  For c:=1 to Length (s) Do Begin
    Index:=(Ord (s[c])+posuv)*(ByteRange)*CharDY-1;
    i:=y;
    For n:=0 to CharDY-1 Do Begin
      DataIndex:=0;
	For h:=0 to CharDX-1 Do Begin
        If (h And 7)=0 then Begin
           Inc (Index);
           (*$ifdef debug*)
           (*$r-*)
           (*$endif*)
           b:=Font^[Index];
           (*$ifdef debug*)
           (*$r+*)
           (*$endif*)
        End;
           if b>=128 then putpixel(screen,x+h+(c-1)*chardx,y+n,textcolor+c*roll);
        Inc (DataIndex,FontScaleX);
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
	  b:=b SHL 1;
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
      End;
      Inc (i,FontScaleY);
    End;
  End;
End;

Procedure Printzoom (bitmap : pimage;var x, y : word; s : String; TextColor : longint;zoomx,zoomy:word);
{ Put the given string on the screen using the current font }
Var
  ByteRange, c, n, h, i : Integer;
  DataIndex, Index, Size ,lsign: Word;
  b : Byte;
  line1 : tline;

Begin
  If Font=NIL then Exit;
  lsign:=0;
  Size:=FontScaleX*CharDX;
  ByteRange:=1+((CharDX-1) SHR 3);
  For c:=1 to Length (s) Do Begin
    Index:=(Ord (s[c])+posuv)*(ByteRange)*CharDY-1;
    i:=y;
    For n:=0 to CharDY-1 Do Begin
      DataIndex:=0;
      For h:=0 to CharDX-1 Do Begin
        If (h And 7)=0 then Begin
           Inc (Index);
           (*$ifdef debug*)
	     (*$r-*)
           (*$endif*)
           b:=Font^[Index];
           (*$ifdef debug*)
           (*$r+*)
           (*$endif*)
        End;
           if b>=128 then begin
           putpixel(screen,x+(h+(c-1)*chardx)*zoomx,y+n*zoomy,textcolor);
            if h>lsign then lsign:=h;
           end;
        Inc (DataIndex,FontScaleX);
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
        b:=b SHL 1;
	  (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
      End;
      Inc (i,FontScaleY);
    End;
  End;
  if s<>' ' then
  x:=x+(lsign+3)*zoomx-chardx;
End;

Procedure Printu (bitmap : pimage;x, y : word; s : String; TextColor : longint);
{ Put the given string on the screen using the current font }
Var
  ByteRange, c, n, h, i : Integer;
  DataIndex, Index, Size ,lsign: Word;
  b : Byte;
  line1 : tline;
  oldx,cf:word;
Begin
  oldx:=x;
  If Font=NIL then Exit;
  Size:=FontScaleX*CharDX;
  ByteRange:=1+((CharDX-1) SHR 3);
  For c:=1 to Length (s) Do Begin
    Index:=(Ord (s[c])+posuv)*(ByteRange)*CharDY-1;
    i:=y;
      lsign:=0;
    For n:=0 to CharDY-1 Do Begin
      DataIndex:=0;
      For h:=0 to CharDX-1 Do Begin
        if n=chardy-2 then putpixel(screen,x+h+(c-1)*chardx,y-2+chardy,textcolor);
	  If (h And 7)=0 then Begin
           Inc (Index);
           (*$ifdef debug*)
           (*$r-*)
           (*$endif*)
           b:=Font^[Index];
           (*$ifdef debug*)
           (*$r+*)
           (*$endif*)
        End;
           if b>=128 then begin
           putpixel(screen,x+(h+(c-1)*chardx),y+n,textcolor);
            if h>lsign then lsign:=h;
           end;
        Inc (DataIndex,FontScaleX);
        (*$ifdef debug*)
	  (*$r-*)
        (*$endif*)
        b:=b SHL 1;
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
      End;
      Inc (i,FontScaleY);
    End;
  if s[c]<>' ' then
  x:=x+lsign-chardx+2;
putpixel(screen,x+h+(c-1)*chardx,y-2+chardy,textcolor);  End;


End;

Procedure Printzoom2 (bitmap : pimage;var x, y : word; s : String; TextColor : longint;zoomx,zoomy:word);
{ Put the given string on the screen using the current font }
Var
  ByteRange, c, n, h, i : Integer;
  DataIndex, Index, Size,lsign : Word;
  b : Byte;
  line1 : tline;

Begin
  If Font=NIL then Exit;
  lsign:=0;
  Size:=FontScaleX*CharDX;
  ByteRange:=1+((CharDX-1) SHR 3);
  For c:=1 to Length (s) Do Begin
    Index:=(Ord (s[c])+posuv)*(ByteRange)*CharDY-1;
    i:=y;
    For n:=0 to CharDY-1 Do Begin
      DataIndex:=0;
      For h:=0 to CharDX-1 Do Begin
        If (h And 7)=0 then Begin
           Inc (Index);
           (*$ifdef debug*)
           (*$r-*)
           (*$endif*)
           b:=Font^[Index];
           (*$ifdef debug*)
           (*$r+*)
           (*$endif*)
        End;
           if b>=128 then begin
           rectangle2(screen,x+(h+(c-1)*chardx)*zoomx,y+n*zoomy,zoomx+1,zoomy,textcolor);
            if h>lsign then lsign:=h;
	     end;
        Inc (DataIndex,FontScaleX);
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
        b:=b SHL 1;
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
      End;
      Inc (i,FontScaleY);
    End;
  End;
  if s<>' ' then
  x:=x+(lsign+3)*zoomx-chardx;
End;

procedure print_normal(bitmap:pimage;x,y:word;s:string;textcolor:longint;roll:integer);
var f:byte;
begin
    for f:=1 to length(s) do begin
        printr(screen,x,y,s[f],textcolor,roll);
        if roll>0 then inc(roll);
        inc(x,chardx);
    end;
end;

procedure print_zoom_shadow(bitmap:pimage;x,y:word;s:string;textcolor:longint;zoomx,zoomy,px,py,col:word);
var f:byte;
    xx,yy:word;
begin
    xx:=x+px;
    yy:=y+py;
    for f:=1 to length(s) do begin
        printzoom2(screen,xx,yy,s[f],col,zoomx,zoomy);
        printzoom2(screen,x,y,s[f],textcolor,zoomx,zoomy);
        inc(x,chardx);
        inc(xx,chardx);
    end;
end;

procedure print_zoom(bitmap:pimage;x,y:word;s:string;textcolor:longint;zoomx,zoomy:word);
var f:byte;
begin
    for f:=1 to length(s) do begin
        printzoom2(screen,x,y,s[f],textcolor,zoomx,zoomy);
        inc(x,chardx);
    end;
end;

Procedure Printr (bitmap : pimage;var x, y : word; s : String; TextColor : longint;roll:integer);
{ Put the given string on the screen using the current font }
Var
  ByteRange, c, n, h, i : Integer;
  DataIndex, Index, Size ,lsign: Word;
  b : Byte;
  line1 : tline;

Begin
  If Font=NIL then Exit;
  lsign:=0;
  Size:=FontScaleX*CharDX;
  ByteRange:=1+((CharDX-1) SHR 3);
  For c:=1 to Length (s) Do Begin
    Index:=(Ord (s[c])+posuv)*(ByteRange)*CharDY-1;
    i:=y;
    For n:=0 to CharDY-1 Do Begin
      DataIndex:=0;
      For h:=0 to CharDX-1 Do Begin
        If (h And 7)=0 then Begin
           Inc (Index);
           (*$ifdef debug*)
           (*$r-*)
           (*$endif*)
           b:=Font^[Index];
           (*$ifdef debug*)
           (*$r+*)
           (*$endif*)
        End;
           if b>=128 then begin
		putpixel(screen,x+h+(c-1)*chardx,y+n,textcolor+c*roll);
            if h>lsign then lsign:=h;
           end;
        Inc (DataIndex,FontScaleX);
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
        b:=b SHL 1;
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
      End;
      Inc (i,FontScaleY);
    End;
  End;
  if s<>' ' then
  x:=x+lsign-chardx+2;
End;

Procedure PrintAt (bitmap : pimage;x, y : Integer; s : String; TextColor,background : longint;roll:integer);
{ Put the given string on the screen using the current font }
Var
  ByteRange, c, n, h, i : Integer;
  DataIndex, Index, Size : Word;
  b : Byte;
  line1 : tline;

Begin
  If Font=NIL then Exit;
  Size:=FontScaleX*CharDX;
  ByteRange:=1+((CharDX-1) SHR 3);
  For c:=1 to Length (s) Do Begin
    Index:=(Ord (s[c])+posuv)*(ByteRange)*CharDY-1;
    i:=y;
    For n:=0 to CharDY-1 Do Begin
      DataIndex:=0;
      For h:=0 to CharDX-1 Do Begin
        If (h And 7)=0 then Begin
           Inc (Index);
           (*$ifdef debug*)
           (*$r-*)
           (*$endif*)
           b:=Font^[Index];
           (*$ifdef debug*)
           (*$r+*)
           (*$endif*)
        End;
        If b<128 then
		filldouble(line1[dataindex], fontscalex,background)
        Else
           filldouble(line1[dataindex], fontscalex, textcolor+c*roll);
        Inc (DataIndex,FontScaleX);
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
        b:=b SHL 1;
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
      End;
      For h:=0 to FontScaleY-1 Do
	  write_linepos (bitmap, line1, x+Size*(c-1), i+h, Size);
	Inc (i,FontScaleY);
    End;
  End;
End;

procedure printx2(bitmap:pimage;x,y:integer;s:string;textcolor:longint;zoomx,zoomy,roll,back:integer);
Var
  ByteRange, c, n, h, i : Integer;
  DataIndex, Index, Size : Word;
  b : Byte;
  line1 : tline;

Begin
  If Font=NIL then Exit;
  Size:=FontScaleX*CharDX;
  ByteRange:=1+((CharDX-1) SHR 3);
  For c:=1 to Length (s) Do Begin
    Index:=(Ord (s[c])+posuv)*(ByteRange)*CharDY-1;
    i:=y;
    For n:=0 to CharDY-1 Do Begin
      DataIndex:=0;
      For h:=0 to CharDX-1 Do Begin
        If (h And 7)=0 then Begin
           Inc (Index);
           (*$ifdef debug*)
           (*$r-*)
           (*$endif*)
           b:=Font^[Index];
           (*$ifdef debug*)
           (*$r+*)
           (*$endif*)
        End;
           if b>=128 then putpixel(screen,(x+h+(c-1)*chardx)*zoomx,(y+n)*zoomy,textcolor+n*roll)
           else putpixel(screen,(x+h+(c-1)*chardx)*zoomx,(y+n)*zoomy,back);
	  Inc (DataIndex,FontScaleX);
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
        b:=b SHL 1;
        (*$ifdef debug*)
        (*$r-*)
        (*$endif*)
      End;
      Inc (i,FontScaleY);
    End;
  End;
end;

Procedure Print (bitmap : pimage;s : String; TextColor,back : longint);
{ Put the given string on the screen using the current font }

Begin
  PrintAt (bitmap, wherex(bitmap),wherey(bitmap),s,TextColor,back,0);
  Inc (bitmap^.x,Length (s)*CharDX);
End;

Procedure SetFontScale (ScaleX, ScaleY : Integer);

Begin
  If (ScaleX<=0) Or (ScaleY<=0) then Exit;
  FontScaleX:=ScaleX;
  FontScaleY:=ScaleY;
End;

procedure SetStartChar(posx:integer);
begin
 posuv:=posx;
end;

Procedure SetFont (FontPtr : Pointer; FontWidth, FontHeight : Integer);
{ Install a new font }
Begin
  If (FontPtr=NIL) Or (FontWidth=0) Or (FontHeight=0) then Exit;
  Font:=FontPtr;
  CharDX:=FontWidth;
  CharDY:=FontHeight;
  SetFontScale (1,1);
End;

Procedure FontScale (Var ScaleX, ScaleY : Integer);

Begin
  ScaleX:=FontScaleX;
  ScaleY:=FontScaleY;
End;

Function CharWidth : Integer;
{ Return the width of a character in the current font }
Begin
  If Font=NIL then CharWidth:=0 Else CharWidth:=CharDX*FontScaleX;
End;

Function CharHeight : Integer;
{ Return the height of a character in the current font }
Begin
  If Font=NIL then CharHeight:=0 Else CharHeight:=CharDY*FontScaleY;
End;

(*this has to be modified !*)
function choisis_mode(maxx, maxy : word;bits_per_pixel : byte) : boolean;
begin
     if bits_per_pixel=8 then begin
        if (maxx<=320) and (maxy<=200) then begin
           mode:=0;
        end else begin
         if (maxx<=640) and (maxy<=480) then mode:=($101)
            else if (maxx<=800) and (maxy<=600) then mode:=($103)
                 else if (maxx<=1024) and (maxy<=768) then mode:=($105)
                      else mode:=($107);
        end;
     end else if (bits_per_pixel=24) or (bits_per_pixel=32) then begin
         if (maxx<=320) and (maxy<=200) then mode:=$10f
            else if (maxx<=640) and (maxy<=480) then mode:=$112 else begin
                 choisis_mode:=false;
		     exit;
            end;
     end else begin
         choisis_mode:=false;
         exit;
     end;
     if not init_mode then choisis_mode:=false else choisis_mode:=true;
end;


(*Following functions were re-written, but not well tested*)
(*So, they may have bugs*)

(*$undef iocheckerror*)
(*$ifopt i+*)
(*$define iocheckerror*)
(*$endif*)

function return_sizebmp(file_name : string;var sizex, sizey, bitsperpixel : word) : boolean;
var f : file;
    header : header_bmp;
begin
     assign(f, file_name);
     reset(f, 1);
     (*$ifndef iocheckerror*)
         if ioresult<>0
            then begin
                 return_sizebmp:=false;
                 exit;
            end;
     (*$endif*)
     blockread(f, header, sizeof(header));
     (*$ifndef iocheckerror*)
         if ioresult<>0
            then begin
                 close(f);
                 return_sizebmp:=false;
                 exit;
            end;
     (*$endif*)
     sizex:=header.infoheader.biwidth;
     sizey:=header.infoheader.biheight;
     bitsperpixel:=header.infoheader.bibitcount;
     close(f);
     return_sizebmp:=true;
end;

function return_sizetga(file_name : string;var sizex, sizey, bitsperpixel : word) : boolean;
var f : file;
    header : header_tga;
begin
     assign(f, file_name);
     reset(f, 1);
     (*$ifndef iocheckerror*)
         if ioresult<>0
            then begin
                 return_sizetga:=false;
                 exit;
            end;
     (*$endif*)
     blockread(f, header, sizeof(header));
     (*$ifndef iocheckerror*)
         if ioresult<>0
            then begin
		     close(f);
                 return_sizetga:=false;
                 exit;
            end;
     (*$endif*)
     sizex:=header.image.width;
     sizey:=header.image.heigh;
     bitsperpixel:=header.image.bits_per_pixel;
     close(f);
     return_sizetga:=true;
end;

function return_sizepcx(file_name : string;var sizex, sizey, bitsperpixel : word) : boolean;
var f : file;
    header : header_pcx;
begin
     assign(f, file_name);
     reset(f, 1);
     (*$ifndef iocheckerror*)
         if ioresult<>0
            then begin
                 return_sizepcx:=false;
                 exit;
            end;
     (*$endif*)
     blockread(f, header, sizeof(header));
     (*$ifndef iocheckerror*)
         if ioresult<>0
            then begin
                 close(f);
                 return_sizepcx:=false;
                 exit;
		end;
     (*$endif*)
     sizex:=header.xmax-header.xmin+1;
     sizey:=header.ymax-header.ymin+1;
     if header.version=5 then bitsperpixel:=8 else bitsperpixel:=4;
     close(f);
     return_sizepcx:=true;
end;

function return_sizegif(file_name : string;var sizex, sizey, bitsperpixel : word) : boolean;
var f : file;
    header : header_gif;
begin
     assign(f, file_name);
     reset(f, 1);
     (*$ifndef iocheckerror*)
	   if ioresult<>0
            then begin
                 return_sizegif:=false;
                 exit;
            end;
     (*$endif*)
     blockread(f, header, sizeof(header));
     (*$ifndef iocheckerror*)
         if ioresult<>0
            then begin
                 close(f);
                 return_sizegif:=false;
                 exit;
            end;
     (*$endif*)
     sizex:=header.screenwidth;
     sizey:=header.screenheight;
     bitsperpixel:=(header.flags and 7)+1;
     close(f);
     return_sizegif:=true;
end;

function draw_bmp(bitmap : pimage;file_name : string;fromx, fromy : word;var pal : tpalette) : boolean;
var header : header_bmp;
    f : file;
    x, y, numbers_of_colors_in_lut, t, i : word;
    palette_bmp : tpalette_bmp;
    line : tline;
begin
     assign(f, file_name);
     reset(f, 1);
     (*$ifndef iocheckerror*)
	   if ioresult<>0
            then begin
                 draw_bmp:=false;
                 exit;
            end;
     (*$endif*)
     blockread(f, header, sizeof(header));
     (*$ifndef iocheckerror*)
         if ioresult<>0
            then begin
                 close(f);
                 draw_bmp:=false;
                 exit;
            end;
     (*$endif*)
     if header.fileheader.bftype<>19778 then begin
	  close(f);
        draw_bmp:=false;
        exit;
     end;
     if header.infoheader.biplanes<>1 then begin
        close(f);
        draw_bmp:=false;
        exit;
     end;
     if header.infoheader.bicompression=1 then begin
        close(f);
        draw_bmp:=false;
        exit;
     end;

     if header.infoheader.biclrused<>0 then numbers_of_colors_in_lut:=header.infoheader.biclrused
						   else numbers_of_colors_in_lut:=256;
     blockread(f, palette_bmp, numbers_of_colors_in_lut*sizeof(color_32));
     (*$ifndef iocheckerror*)
         if ioresult<>0
            then begin
                 close(f);
                 draw_bmp:=false;
                 exit;
            end;
     (*$endif*)
     seek(f, header.fileheader.bfoffbits);
     (*$ifndef iocheckerror*)
         if ioresult<>0
            then begin
                 close(f);
                 draw_bmp:=false;
		     exit;
            end;
     (*$endif*)
     if header.infoheader.bibitcount<=8
        then begin
             for x:=0 to numbers_of_colors_in_lut-1 do begin
                 pal[x].r:=palette_bmp[x].r shr 2;
                 pal[x].v:=palette_bmp[x].v shr 2;
                 pal[x].b:=palette_bmp[x].b shr 2;
             end;
        end;

     t:=(header.infoheader.bibitcount+7) div 8;
     for y:=header.infoheader.biheight-1 downto 0 do begin
         for i:=0 to header.infoheader.biwidth-1 do begin
             blockread(f, line[i], t);
		 (*$ifndef iocheckerror*)
             if ioresult<>0
                then begin
                     close(f);
                     draw_bmp:=false;
                     exit;
                end;
             (*$endif*)
         end;
	   write_linepos(bitmap, line, fromx, y+fromy, header.infoheader.biwidth);
     end;
end;

function draw_tga(bitmap : pimage;file_name : string;fromx, fromy : word;var pal : tpalette) : boolean;
var f : file;
    header : header_tga;
    numbers_of_colors_in_lut, x, y, t, i : word;
    line : tline;
    palette : tpalette_tga;
begin
     assign(f, file_name);
     reset(f, 1);
     (*$ifndef iocheckerror*)
     if ioresult<>0
        then begin
             close(f);
             draw_tga:=false;
		 exit;
        end;
     (*$endif*)
     if (header.type_image<>1) and (header.type_image<>2) and (header.type_image<>10) then begin
        close(f);
	  draw_tga:=false;
        exit;
     end;
     if (header.image.description_image.many_things and 3)<>0 then begin
        close(f);
        draw_tga:=false;
        exit;
     end;
     if (header.image.bits_per_pixel<>8) and (header.image.bits_per_pixel<>24) then begin
        close(f);
        draw_tga:=false;
	  exit;
     end;
     numbers_of_colors_in_lut:=header.lut.size;
     if header.image.bits_per_pixel<=8 then begin
        blockread(f, palette, numbers_of_colors_in_lut*sizeof(tcolors_bmp));
	  (*$ifndef iocheckerror*)
        if ioresult<>0
           then begin
                close(f);
                draw_tga:=false;
                exit;
           end;
        (*$endif*)
        for x:=0 to numbers_of_colors_in_lut-1 do begin
            pal[x].r:=palette[x].r shr 2;
            pal[x].v:=palette[x].v shr 2;
		pal[x].b:=palette[x].b shr 2;
        end;
     end;
     t:=header.image.bits_per_pixel div 8;
     for y:=0 to header.image.heigh-1 do begin
	   for i:=0 to header.image.width do begin
             blockread(f, line[i], t);
             (*$ifndef iocheckerror*)
             if ioresult<>0
                then begin
                     close(f);
                     draw_tga:=false;
                     exit;
                end;
             (*$endif*)
         end;
	   write_linepos(bitmap, line, fromx, fromy+y, header.image.width);
     end;
     close(f);
end;

function draw_pcx(bitmap : pimage;file_name : string;fromx, fromy : word;var pal : tpalette) : boolean;

type tbuffer = array[0..63999] of byte;

function decompresse_ligne_pcx(var ligne : tline; largeur : word;
         var f : file; var buffer : tbuffer; position : longint) : word;
var octet : byte;
    compteur : word;
    octet2 : byte;
    compteur2 : word;
    pos : word;
begin
     compteur:=0;
     compteur2:=0;
     pos:=0;
     while(compteur<largeur) do begin
				     octet:=buffer[pos+position];
                             inc(pos);
                             inc(compteur2);
                             if octet and $c0 = $c0 then begin
                                octet2:=octet and $3f;
                                octet:=buffer[pos+position];
                                inc(pos);
                                filldouble(ligne[compteur], octet2, octet);
                                inc(compteur, octet2);
                                inc(compteur2);
                             end
                             else begin
                                  ligne[compteur]:=octet;
                                  inc(compteur);
                             end;
     end;
     decompresse_ligne_pcx:=compteur2;
end;

var f : file;
    header : header_pcx;
    buffer : ^tbuffer;
    position, position2, taille, temp : longint;
    width, is_therepal : integer;
    octet : byte;
    line : tline;
    i, x, y : integer;
begin
     assign(f, file_name);
     reset(f, 1);
     (*$ifndef iocheckerror*)
     if ioresult<>0
	  then begin
             close(f);
             draw_pcx:=false;
             exit;
        end;
     (*$endif*)
     blockread(f, header, sizeof(header));
     (*$ifndef iocheckerror*)
     if ioresult<>0
        then begin
             close(f);
             draw_pcx:=false;
             exit;
        end;
     (*$endif*)
     if header.version<>5 then begin
	  close(f);
        draw_pcx:=false;
        exit;
     end;
     if header.bits_per_pixel<>8 then begin
        close(f);
        draw_pcx:=false;
        exit;
     end;
     width:=header.xmax-header.xmin+1;
     new(buffer);
     position:=128;
     position2:=0;
     is_therepal:=0;
     taille:=filesize(f);
     seek(f, filesize(f)-769);
     blockread(f, octet, 1);
     (*$ifndef iocheckerror*)
     if ioresult<>0
        then begin
             close(f);
             draw_pcx:=false;
             exit;
        end;
     (*$endif*)
     if octet=12 then begin
        blockread(f, pal, 768);
        (*$ifndef iocheckerror*)
        if ioresult<>0
           then begin
                close(f);
                draw_pcx:=false;
		    exit;
           end;
        (*$endif*)
        seek(f, 128);
        for octet:=0 to 255 do begin
            pal[octet].r:=pal[octet].r shr 2;
            pal[octet].v:=pal[octet].v shr 2;
            pal[octet].b:=pal[octet].b shr 2;
        end;
        is_therepal:=768
     end;
     if position+sizeof(buffer^)<taille then blockread(f, buffer^, sizeof(buffer^))
        else blockread(f, buffer^, taille-position-is_therepal);
        (*$ifndef iocheckerror*)
        if ioresult<>0
           then begin
		    close(f);
                draw_pcx:=false;
                exit;
           end;
        (*$endif*)
     for y:=0 to header.ymax-header.ymin  do begin
         if header.compression=0
            then begin
                 for i:=0 to width-1 do begin
                     blockread(f, octet, 1);
                     (*$ifndef iocheckerror*)
                     if ioresult<>0
                        then begin
                             close(f);
                             draw_pcx:=false;
                             exit;
				end;
                     (*$endif*)
                     line[i]:=octet;
                 end;
            end else begin
                 if position2+width>=maxbuffer-width
                    then begin
                         position2:=0;
                         seek(f, position);
                         if position+sizeof(buffer^)<taille
                            then blockread(f, buffer^, sizeof(buffer^))
                            else blockread(f, buffer^, taille-position-is_therepal);
                         (*$ifndef iocheckerror*)
                         if ioresult<>0
                            then begin
                                 close(f);
					   draw_pcx:=false;
                                 exit;
                            end;
                         (*$endif*)
                    end;
                 temp:=decompresse_ligne_pcx(line, width, f, buffer^, position2);
                 inc(position, temp);
                 inc(position2, temp);
            end;
	   write_linepos(bitmap, line, fromx, fromy+y, width);
     end;
     dispose(buffer);
     close(f);
     draw_pcx:=true;
end;

(*Dump area from (xstart, ystart) to (xstop, ystop) to a gif file of name : file_name.
Returned value is size of file created. On error, it returns -1.
Note that gif supports only 8 bits images, so images of 32K, 65K or 16M colors will
be considered as 256 colors.
Pal parameter is palette to save.*)
(*This code is a port of Sverre Huseby( sverrehu@ifi.uio.no)'s gifsave portable C functions.
I assume any bug introduced by port*)
function dump_to_gif(bitmap : pimage;file_name : string;xstart, ystart, xstop, ystop, bits_per_pixel : integer;
         pal : tpalette) : longint;
const
     hash_free = $ffff;
     next_first = $ffff;

     maxbits = 12;
     maxstr = 1 shl maxbits;

     code_reserved = 2;

     hashsize = 9973;
     hashstep = 2039;

type
     ttabbyte = array[0..0] of byte;
     ptabbyte = ^ttabbyte;

     ttabword = array[0..0] of word;
     ptabword = ^ttabword;

     screendescriptor = record
                              screenwidth, screenheight : word;
                              flag : byte;
                              background, pixelaspectratio : byte;
				end;
     imagedescriptor = record
                             separator : char;
                             leftposition, topposition : word;
                             width, height : word;
                             flag : byte;
                       end;

var strchr : ptabbyte;
    strnext, strhash : ptabword;
    numstrings : word;

    outfile : file;

    buffer : array[0..255] of byte;
    index, bitsleft : integer;

    bitsperpixel, numcolors : integer;
    screenheight, screenwidth, relpixx, relpixy : integer;

function hash(index, lastbyte : word) : word;
begin
     hash:=( ( lastbyte shl 8 ) XOR index ) mod hashsize;
end;

function create(s : string) : boolean;
begin
     assign(outfile, s);
     rewrite(outfile, 1);
     (*$ifndef iocheckerror*)
     if ioresult<>0
        then begin
		 create:=false;
             exit;
        end;
     (*$endif*)
     create:=true;
end;

function write(var buf;len : word) : boolean;
begin
     blockwrite(outfile, buf, len);
     (*$ifndef iocheckerror*)
     if ioresult<>0
        then begin
             write:=false;
             exit;
        end;
     (*$endif*)
     write:=true;
end;

function writebyte(b : byte) : boolean;
begin
     blockwrite(outfile, b, 1);
     (*$ifndef iocheckerror*)
     if ioresult<>0
        then begin
             writebyte:=false;
             exit;
        end;
     (*$endif*)
     writebyte:=true;
end;

function writeword(w : word) : boolean;
begin
     blockwrite(outfile, w, 2);                 (*In original code, it was splitted in 2 byte output to ensure portability*)
     (*$ifndef iocheckerror*)                   (*Was removed since this library is not portable (as is TP) *)
     if ioresult<>0
        then begin
             writeword:=false;
             exit;
        end;
     (*$endif*)
     writeword:=true;
end;

(*Bit file oriented routines*)
procedure initbitfile;
begin
     index:=0;
     buffer[0]:=0;
     bitsleft:=8;
end;

function resetoutbitfile : boolean;
var numbytes : byte;
begin
     if bitsleft=8
        then numbytes:=index
        else numbytes:=index+1;
     if numbytes>0
        then begin
             if not writebyte(numbytes)
                then begin
			   resetoutbitfile:=false;
                     exit;
                end;
             if not write(buffer, numbytes)
                then begin
                     resetoutbitfile:=false;
                     exit;
                end;
             index:=0;
             buffer[0]:=0;
             bitsleft:=8;
     end;
     resetoutbitfile:=true;
end;

function writebits(bits, numbits : integer) : longint;
var bitswritten, numbytes : integer;
begin
     bitswritten:=0;
     numbytes:=255;
     repeat
           if ( (index=254) and (bitsleft=0) ) or (index>254)
              then begin
                   if not writebyte(numbytes)
                      then begin
                           writebits:=-1;
                           exit;
                      end;
                   if not write(buffer, numbytes)
                      then begin
                           writebits:=-1;
                           exit;
			    end;
                   index:=0;
                   buffer[index]:=0;
                   bitsleft:=8;
              end;
           if (numbits<=bitsleft)
              then begin
                   buffer[index]:=buffer[index] or ( ( bits and ( ( 1 shl numbits) -1 ) ) shl ( 8 - bitsleft ) );
                   inc(bitswritten, numbits);
                   dec(bitsleft, numbits);
                   numbits:=0;
              end else begin
                   buffer[index]:=buffer[index] or ( ( bits and ( ( 1 shl bitsleft) -1 ) ) shl (8 - bitsleft ) );
                   inc(bitswritten, bitsleft);
                   bits:=bits shr bitsleft;
                   dec(numbits, bitsleft);
			 inc(index);
                   buffer[index]:=0;
                   bitsleft:=8;
              end;
     until ( numbits = 0 );
     writebits:=bitswritten;
end;

procedure freestrtab;
begin
     if ( strhash <> nil )
        then begin
             freemem(strhash, hashsize * sizeof(word));
             strhash:=nil;
        end;

     if ( strnext <> nil )
        then begin
             freemem(strnext, maxstr * sizeof(word));
             strnext:=nil;
        end;

     if ( strchr <> nil )
        then begin
             freemem(strchr, maxstr * sizeof(byte));
             strchr:=nil;
        end;
end;

function allocstrtab : boolean;
begin
     getmem(strchr, maxstr * sizeof(byte));
     if strchr=nil
        then begin
             freestrtab;
             allocstrtab:=false;
             exit;
        end;
     getmem(strnext, maxstr * sizeof(word));
     if strnext=nil
        then begin
             freestrtab;
             allocstrtab:=false;
             exit;
        end;
     getmem(strhash, hashsize * sizeof(word));
     if strhash=nil
        then begin
		 freestrtab;
             allocstrtab:=false;
             exit;
        end;
     allocstrtab:=true
end;

function addcharstring(index : word;b : byte) : word;
var hshidx : word;
begin
     if numstrings>=maxstr
        then begin
             addcharstring:=$ffff;
             exit;
        end;

     hshidx:=hash(index, b);
     while (strhash^[hshidx]<>$ffff)
           do hshidx:=(hshidx + hashstep) mod hashsize;

     strhash^[hshidx]:=numstrings;
     strchr^[numstrings]:=b;
     if (index <> $ffff)
        then strnext^[numstrings]:=index
        else strnext^[numstrings]:=next_first;

     addcharstring:=numstrings;
     inc(numstrings);
end;

function findcharstring(index : word;b : byte) : word;
var hshidx, nextidx : word;
begin
     if (index=$ffff)
        then begin
             findcharstring:=b;
             exit;
        end;

     hshidx:=hash(index, b);

     nextidx:=strhash^[hshidx];
     while ( nextidx <> $ffff ) do begin
           if (strnext^[nextidx]=index) and (strchr^[nextidx]=b)
              then begin
                   findcharstring:=nextidx;
                   exit;
              end;
	     hshidx:=(hshidx+hashstep) mod hashsize;
           nextidx:=strhash^[hshidx];
     end;

     findcharstring:=$ffff;
end;

procedure clearstrtab(codesize : integer);
var q, w : integer;
    wp : ^word;
begin
     numstrings:=0;

     wp:=@(strhash^[0]);
     for q:=0 to hashsize-1 do begin
         wp^:=hash_free;
	   inc(wp, sizeof(word));
     end;

     w:=(1 shl codesize) + code_reserved;
     for q:=0 to w-1 do addcharstring($ffff, q);
end;

function inputbyte : integer;
var ret : integer;
begin
     if (relpixy>=screenheight)
        then begin
             inputbyte:=-1;
             exit;
        end;
     ret:=getpixel(bitmap, xstart+relpixx, ystart+relpixy) and $ff;
     inc(relpixx);
     if relpixx>=screenwidth
        then begin
             relpixx:=0;
             inc(relpixy);
        end;
     inputbyte:=ret;
end;

function writescreendescriptor(var sd : screendescriptor;globalcolortableflag, colorresolution, sortflag,
         globalcolortablesize : integer) : boolean;
begin
     sd.flag:=(globalcolortableflag shl 7) or (colorresolution shl 4) or (sortflag shl 3) or globalcolortablesize;
     blockwrite(outfile, sd, sizeof(screendescriptor));
     (*$ifndef iocheckerror*)
     if ioresult<>0
	  then begin
             writescreendescriptor:=false;
             exit;
        end;
     (*$endif*)
     writescreendescriptor:=true;
end;

function writeimagedescriptor(var id : imagedescriptor;localcoltab, interlace, sort, reserved,
         localtabsize : integer) : boolean;
begin
     id.flag:=(localcoltab shl 7) or (interlace shl 6) or (sort shl 5) or (reserved shl 3) or localtabsize;
     blockwrite(outfile, id, sizeof(imagedescriptor));
     (*$ifndef iocheckerror*)
     if ioresult<>0
        then begin
		 writeimagedescriptor:=false;
             exit;
        end;
     (*$endif*)
     writeimagedescriptor:=true;
end;

function lzw_compress(codesize : integer) : boolean;
var c : integer;
    index : word;
    clearcode, endofinfo, numbits, limit, errcode : integer;
    prefix : word;
begin
     prefix:=$ffff;

     initbitfile;

     clearcode:=1 shl codesize;
     endofinfo:=clearcode + 1;

     numbits:=codesize + 1;
     limit:=(1 shl numbits) -1;

     if not allocstrtab
        then begin
             lzw_compress:=false;
             exit;
        end;
     clearstrtab(codesize);

     writebits(clearcode, numbits);

     c:=inputbyte;

     while (c<>-1) do begin
           index:=findcharstring(prefix, c);
           if index<>$ffff
              then prefix:=index
              else begin
                   writebits(prefix, numbits);
                   if ( addcharstring(prefix, c) > limit )
                      then begin
                           inc(numbits);
                           if numbits>12
                              then begin
                                   writebits(clearcode, numbits-1);
                                   clearstrtab(codesize);
                                   numbits:=codesize+1;
					end;
                           limit:=(1 shl numbits)-1;
                      end;

                   prefix:=c;
              end;
           c:=inputbyte;
     end;

     if prefix<>$ffff
        then writebits(prefix, numbits);

     writebits(endofinfo, numbits);

     resetoutbitfile;

     freestrtab;

     lzw_compress:=true;
end;

function bitsneeded(n : word): integer;
var ret : integer;
begin
     ret:=1;
     if n=0
        then begin
             bitsneeded:=0;
             exit;
        end;
     dec(n);
     n:=n shr 1;
     while n>0 do begin
           inc(ret);
           n:=n shr 1;
     end;

     bitsneeded:=ret;
end;

var id : imagedescriptor;
    sd : screendescriptor;
    toto : string[8];
    temp : integer;

begin
     numcolors:=1 shl bitsperpixel;
     screenheight:=ystop-ystart+1;
     screenwidth:=xstop-xstart+1;

     if not create(file_name)
        then begin
             dump_to_gif:=-1;
             exit;
        end;

     toto:='GIF87a';
     if not write(toto[1], 6)
        then begin
             dump_to_gif:=-1;
             exit;
        end;

     sd.screenwidth:=screenwidth;
     sd.screenheight:=screenheight;
     sd.background:=0;
     sd.pixelaspectratio:=0;
     if not writescreendescriptor(sd, bits_per_pixel-1, 0, bits_per_pixel-1, bits_per_pixel-1)
        then begin
             dump_to_gif:=-1;
             exit;
        end;
     for temp:=0 to 255 do begin
         pal[temp].r:=pal[temp].r shl 2;
         pal[temp].v:=pal[temp].v shl 2;
         pal[temp].b:=pal[temp].b shl 2;
     end;
     if not write(pal, 768)
        then begin
             dump_to_gif:=-1;
		 exit;
        end;
     id.separator:=',';
     id.leftposition:=0;
     id.topposition:=0;
     id.width:=screenwidth;
     id.height:=screenheight;
     if not writeimagedescriptor(id, 0, 0, 0, 0, 0)
        then begin
             dump_to_gif:=-1;
             exit;
        end;

     if not writebyte(bits_per_pixel)
        then begin
             dump_to_gif:=-1;
		 exit;
        end;

     relpixx:=0;
     relpixy:=0;

     if not lzw_compress(bits_per_pixel)
        then begin
             dump_to_gif:=-1;
             exit;
        end;

     if not writebyte(0)
        then begin
             dump_to_gif:=-1;
             exit;
	  end;

     id.separator:=';';
     if not writeimagedescriptor(id, 0, 0, 0, 0, 0)
        then begin
             dump_to_gif:=-1;
             exit;
        end;

     dump_to_gif:=filesize(outfile);

     close(outfile);                            (*Ahhhh ... finished*)

end;

procedure set_death_color(num:word);
begin
     death_color:=num;
end;

(*function draw_gif(bitmap : pimage;file_name : string;x, y : word;var pal : tpalette) : boolean;*)
function draw_gif(bitmap : pimage;file_name : string;fromx, fromy : word;var pal : tpalette) : boolean;

type thashbyte = array[0..4095] of byte;
     thashword = array[0..4095] of integer;

var infile: file;
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
     blockread(infile, x, nb, toto);
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
  Assign(InFile, File_Name);
  Reset(InFile,1);
(*$ifndef iocheckerror*)
  If IOResult <> 0 then
     Begin
       draw_Gif := false;
       dispose(workspace1);
       dispose(workspace2);
       dispose(workspace3);
       Exit;
     end;
(*$endif*)
(*  InIndex := MaxSize;*)
  If Not Get(GifHeader,SizeOf(GifHeader)) then
     Begin
       draw_Gif := false;
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
       draw_Gif := (*Err_NotAGif*)false;
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
            draw_Gif := false;
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
                   draw_Gif := false;
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
                        draw_Gif := false;
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
                   draw_Gif := false;
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
  close(infile);
  draw_Gif := (giferror=0) ;
  dispose(workspace1);
  dispose(workspace2);
  dispose(workspace3);
end;


(*Functions to call apropriate functions*)
(*Ok, I know it looks very special, but it's the best way I found to have object's adaptibility
  with "standard" programmation*)
procedure putpixel(bitmap : pimage;x, y : word;couleur : longint);
begin
     bitmap^.putpixel(bitmap, x, y, couleur);
end;

function getpixel(bitmap : pimage;x, y : word) : longint;
begin
     getpixel:=bitmap^.getpixel(bitmap, x, y);
end;

procedure write_line(bitmap : pimage;var line : tline;ordonnee : word;number : word);
begin
     bitmap^.write_line(bitmap, line, ordonnee, number);
end;

procedure write_linepos(bitmap : pimage;var line : tline;abscisse, ordonnee : word;number : word);
begin
     bitmap^.write_linepos(bitmap, line, abscisse, ordonnee, number);
end;

procedure read_line(bitmap : pimage;var line : tline;ordonnee : word;number : word);
begin
     bitmap^.read_line(bitmap, line, ordonnee, number);
end;

procedure read_linepos(bitmap : pimage;var line : tline;abscisse, ordonnee : word;number : word);
begin
     bitmap^.read_linepos(bitmap, line, abscisse, ordonnee, number);
end;

function wherex(bitmap : pimage) : word;
begin
     wherex:=bitmap^.x;
end;

function wherey(bitmap : pimage) : word;
begin
     wherey:=bitmap^.y;
end;

(*The blit procedure*)
(*Copy any zone of any bitmap to any zone to any bitmap*)
procedure blit(bit1, bit2 : pimage;x1, y1, x2, y2, numberx, numbery : word);
var
    y : word;
begin
     if (bit1=bit2) and ( (y2>y1) or ( (y1=y2) and (x2>x1) ) )
        then begin                              (*We should blit in reversed order to avoid colision*)
             for y:=numbery-1 downto 0 do begin
                 read_linepos_for_blit(bit1, x1, y1+y, numberx);
                 write_linepos(bit2, blit_line^, x2, y2+y, numberx);
             end;
        end else begin
             for y:=0 to numbery-1 do begin     (*We can do in normal order*)
                 read_linepos_for_blit(bit1, x1, y1+y, numberx);
		     write_linepos(bit2, blit_line^, x2, y2+y, numberx);
             end;
        end;
end;

procedure putpixel_bitmap(bitmap : pimage;x, y : word;coul : longint);
begin
     bitmap^.lines[y]^[x]:=coul;
end;

function getpixel_bitmap(bitmap : pimage;x, y : word) : longint;
begin
     getpixel_bitmap:=bitmap^.lines[y]^[x];
end;

procedure blitx(bit1, bit2 : pimage;x1, y1, x2, y2, numberx, numbery: word;colx:longint);
var
    yg,yf,x3,y3 : word;
    pix:longint;
begin
             x3:=x2-x1;
             y3:=y2-y1;
             for yg:=x1 to x1+numberx-1 do
             for yf:=y1 to y1+numbery-1 do begin
                pix:=getpixel(bit1,yg,yf);
               if pix<>colx then
                putpixel(bit2,yg+x3,yf+y3,pix);
             end;
end;

procedure read_linepos_for_blit_memory_bitmap(bitmap : pimage;abscisse, ordonnee : word;number : word);
begin
     blit_line:=@(bitmap^.lines[ordonnee]^[abscisse]);   (*We just point on good point, to avoid one move*)
end;

procedure read_linepos_for_blit_with_move(bitmap : pimage;abscisse, ordonnee : word;number : word);
begin
     blit_line:=@line_for_blit;                         (*Have to do it classic way*)
     read_linepos(bitmap, line_for_blit, abscisse, ordonnee, number);
end;

procedure read_linepos_for_blit(bitmap : pimage;abscisse, ordonnee : word;number : word);
begin
     bitmap^.read_linepos_for_blit(bitmap, abscisse, ordonnee, number);
end;

(*Bitmap handling functions*)
(*This are the promitive for bitmaped operation*)
(*Note that even if they're faster than screen's one, it's still a good idea
to minimize putpixel/getpixel calls, as they're composed of several non consecutive
memoru reference*)

procedure write_line_bitmap(bitmap : pimage;var line : tline;ordonnee : word;number : word);
begin
     move(line, bitmap^.lines[ordonnee]^, number*sizeof(longint));
end;

procedure write_line_pos_bitmap(bitmap : pimage;var line : tline;abscisse, ordonnee : word;number : word);
begin
     move(line, bitmap^.lines[ordonnee]^[abscisse], number*sizeof(longint));
end;

procedure read_line_bitmap(bitmap : pimage;var line : tline;ordonnee : word;number : word);
begin
     move(bitmap^.lines[ordonnee]^, line, number*sizeof(longint));
end;

procedure read_line_pos_bitmap(bitmap : pimage;var line : tline;abscisse, ordonee : word;number : word);
begin
     move(bitmap^.lines[ordonee]^[abscisse], line, number*sizeof(longint));
end;

(*Create a bitmap, and allocate all necessesary mem*)
(*Returns nil if ther's not enough memory*)
(*This really take a LOT of memory : you can't allocate more than one 320x200
memory bitmap !*)
function create_bitmap(width, height : word) : pimage;
var image : pimage;
    y : integer;
begin
     if longint(width)*height*4>maxavail         (*We cast to longint to avoid overflow errors*)
        then begin
             create_bitmap:=nil;
             exit;
        end;
     new(image);
     image^.width:=width;
     image^.height:=height;
     for y:=0 to height-1 do begin
         getmem(image^.lines[y], width*sizeof(longint));
         fillchar(image^.lines[y]^, width*sizeof(longint), 0);
     end;
     create_bitmap:=image;
     with image^ do begin
          write_line:=write_line_bitmap;
          write_linepos:=write_line_pos_bitmap;
	    read_line:=read_line_bitmap;
          read_linepos:=read_line_pos_bitmap;
          read_linepos_for_blit:=read_linepos_for_blit_memory_bitmap;
          putpixel:=putpixel_bitmap;
          getpixel:=getpixel_bitmap;
    end;
    image^.x:=0;
    image^.y:=0;
end;

(*destroy a bitmap, and free its memory*)
procedure destroy_bitmap(bitmap : pimage);
var yo : integer;
begin
     with bitmap^ do begin
          for yo:=0 to height-1 do freemem(lines[yo], width*sizeof(longint));
     end;
     dispose(bitmap);
end;

function keypressed : boolean;assembler;        (*About 21 times faster than crt's keypressed*)
asm
   mov  ax, 40h
   mov  es, ax
   mov  dx, es:[1ah]
   mov  bx, es:[1ch]
   xor  ax, ax
   cmp  dx, bx
   je  @end
   mov  al, 1
 @end:
end;

procedure clear_buffer;assembler;               (*Clear keyboard buffer*)
asm
   mov  ax, 40h
   mov  es, ax
   mov  ax, es:[1ch]
   mov  es:[1ah], ax
end;

function read_key : word;assembler;             (*Return (scancode shl 8)+ascii*)
asm
   mov  ax, 1000h
   int  16h
end;

(*Timer functions*)
(*for TEST !!!*)
(*you should use this VERY carefully*)
(*procedure personnal_interrupt;assembler;
asm
   pushf
   push ax
   pushf
   call tocall
   mov  al, $20
   out  $20, al
   pop  ax
   popf
   iret
end;*)
procedure personnal_interrupt;interrupt;
begin
     tocall;
     port[$20]:=$20;
end;

procedure install_timer(proc : tdone;freq : word);
var compteur : word;
begin
     cli;
     compteur:=1193180 div freq;
     port[$43]:=$36;
     port[$40]:=lo(compteur);
     port[$40]:=hi(compteur);
     getintvec(8, oldtimerint);
     setintvec(8, @personnal_interrupt);
     tocall:=proc;
     sti;
end;

procedure remove_timer;
begin
     asm cli; end;
     port[$43]:=$36;
     port[$40]:=0;
     port[$40]:=0;
     setintvec(8, oldtimerint);
     asm sti; end;
end;

(*Mouse functions*)

(*This is the procedure that will be called by the assembler handler of mouse's call*)
(*Not in assembler for simplicity reasons*)
procedure handle_inter_pas;
var x, y : integer;
    posx, posy : integer;
    getxy : longint;
begin
     if must_show_mouse then begin
        if not recur then begin
           recur:=true;
           if (mouse_posx<>mouse_oldx) or (mouse_posy<>mouse_oldy) then begin
              for y:=0 to 15 do
                  for x:=0 to 15 do
                      putpixel(screen, x+mouse_oldx, y+mouse_oldy, old_screen[x, y]);
              for y:=0 to 15 do
                  for x:=0 to 15 do
                      old_screen[x, y]:=getpixel(screen, x+mouse_posx, y+mouse_posy);
              posy:=mouse_posy;
		  for y:=0 to 15 do begin
                  posx:=mouse_posx;
                  for x:=0 to 15 do begin
                      getxy:=getpixel(screen, posx, posy);
                      putpixel(screen, posx, posy, (getxy and mask_and[x, y]) or mask_or[x, y]);
                      inc(posx);
                  end;
                  inc(posy);
              end;
           end;
           recur:=false;
        end;
     end;
end;

(*This procedure will be called by the mouse driver each time an event occurs on mouse*)
(*Has to save all register, but must finish by a far ret*)
(*so can't be a pascal procedure (don't save registers) or an interupt pascal
procedure (which end with a iret*)
procedure handle_inter_asm;assembler;
asm
   push ax
   push bx
   push cx
   push dx
   push ds
   push es
   pushf
   push di
   push si
   mov  ax, seg @data
   mov  ds, ax
   mov  ax, mouse_posx
   mov  mouse_oldx, ax
   mov  ax, mouse_posy
   mov  mouse_oldy, ax
   mov  mouse_posx, cx
   mov  mouse_posy, dx
   mov  mouse_button, bl
   call handle_inter_pas
   pop  si
   pop  di
   popf
   pop  es
   pop  ds
   pop  dx
   pop  cx
   pop  bx
   pop  ax
end;

procedure mousepos;
var regs : registers;
begin
     mouse_oldx:=mouse_posx;
     mouse_oldy:=mouse_posy;
     regs.ax:=3;
     intr($33, regs);
     mouse_posx:=regs.cx;
     mouse_posy:=regs.dx;
     mouse_button:=regs.bl;
end;
(*Note that actually hiding/showing mouse (if called too often) cause garbagge on screen.*)
(*Don't know why*)
procedure hide_mouse;
var x, y : integer;
    savedx, savedy : integer;
begin
     must_show_mouse:=false;
     savedx:=mouse_posx;
     savedy:=mouse_posy;
     for y:=0 to 15 do
         for x:=0 to 15 do
             putpixel(screen, x+savedx, y+savedy, old_screen[x, y]);
end;

procedure show_mouse;
var x, y : integer;
    savedx, savedy, posx, posy : integer;
    getxy : longint;
begin
     hide_mouse_x:=mouse_posx;
     hide_mouse_y:=mouse_posy;
     savedx:=mouse_posx;
     savedy:=mouse_posy;
     for y:=0 to 15 do
         for x:=0 to 15 do
             old_screen[x, y]:=getpixel(screen, x+savedx, y+savedy);
     posy:=savedy;
     for y:=0 to 15 do begin
         posx:=savedx;
         for x:=0 to 15 do begin
             getxy:=getpixel(screen, posx, posy);
             putpixel(screen, posx, posy, (getxy and mask_and[x, y]) or mask_or[x, y]);
             inc(posx);
         end;
	   inc(posy);
     end;
     must_show_mouse:=true;
end;

(*To change mouse look*)
(*The two masks are a AND mask, and a OR mask*)
(*We take the value of current pixel, we AND it with its coresponding mask, then
we OR it with its mask. This is an extension of standard mask definition
(which is only for 2 colors pointer) *)
procedure define_look(var m_and, m_or : tmouse_ptr);
var temp : boolean;
begin
     if must_show_mouse then begin
        temp:=true;
        hide_mouse;
     end else temp:=false;
     move(m_and, mask_and, sizeof(mask_and));
     move(m_or, mask_or, sizeof(mask_or));
     if temp then show_mouse;
end;

(*Define where mouse can go*)
procedure define_zone(x1, y1, x2, y2 : integer);assembler;
asm
   mov  ax, 7
   mov  cx, x1
   mov  dx, x2
   int  33h
   mov  ax, 8
   mov  cx, y1
   mov  dx, y2
   int  33h
end;

(*Speed of mouse*)
procedure define_speed(mickeysx, mickeysy : integer);assembler;
asm
   mov  ax, 0fh
   mov  cx, mickeysx
   mov  dx, mickeysy
   int  33h
end;

(*From which physical speed mouse pointer's speed will be doubled*)
procedure define_double_speed_limit(limit : integer);assembler;
asm
   mov  ax, 13h
   mov  dx, limit
   int  33h
end;

(*Get actual speed parameter*)
procedure get_speed(var mickeysx, mickeysy, double_limit : integer);assembler;
asm
   mov  ax, 1bh
   int  33h
   les  di, mickeysx
   mov  ax, bx
   stosw
   les  di, mickeysy
   mov  ax, cx
   stosw
   les  di, double_limit
   mov  ax, dx
   stosw
end;

procedure init_mouse(var m_and, m_or : tmouse_ptr);
var regs : registers;
begin
     regs.ax:=0;
     intr($33, regs);
     regs.ax:=$c;
     regs.cx:=127;
     regs.es:=seg(handle_inter_asm);
     regs.dx:=ofs(handle_inter_asm);
     intr($33, regs);
     regs.ax:=3;
     intr($33, regs);
     mouse_posx:=regs.cx;
     mouse_posy:=regs.dx;
     mouse_button:=regs.bl;
     recur:=false;
     move(m_and, mask_and, sizeof(mask_and));
     move(m_or, mask_or, sizeof(mask_or));
     (*Default : mouse can go everywhere*)
     define_zone(0, 0, getmaxx-1-mouse_ptr_maxx, getmaxy-1-mouse_ptr_maxy);
     show_mouse;
end;

(*Don't forget it, or your program may crash*)
(*It removes the "interupt" handler*)
procedure done_mouse;
begin
     asm
	  xor  ax, ax
        int  33h
     end;
     if must_show_mouse
        then hide_mouse;
end;
 const
  CData        = $40;                    {Port number of timer 0}
  CMode        = $43;                    {Port number of timer control word}

  procedure wait_for_time(time:longint);
  var time_delay:longint;
  begin
	time_delay:=time+getclock;
	repeat
	until getclock>=time_delay;
  end;

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

begin
     tma:=false;
     new(screen);
     screen^.read_linepos_for_blit:=read_linepos_for_blit_with_move;
     done_graf:=done_bidon;
end.