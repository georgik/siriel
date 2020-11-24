unit jxvar;
interface
uses dos,jxgraf;

const
{----------------KEYs-------------------}
     kb_up            = $4800;
     kb_down          = $5000;
     kb_left          = $4b00;
     kb_right         = $4d00;
     kb_esc           = $011B;
     kb_enter         = $1C0D;
     kb_back          = $0E08;
{---------------------------------------}
var palx,blackx    : tpalette;
    sr             : searchrec;


implementation


begin
   fill_palette_black(blackx);
end.