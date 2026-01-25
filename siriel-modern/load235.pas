unit load235;

{$mode objfpc}{$H+}

{ Modern resource loader for Siriel
  Replaces original LOAD235.PAS with proven draw_gif_block from blockx
  Focus: Resource loading for Step 5.6
}

interface

uses
  SysUtils,
  jxgraf,
  jxfont_simple,
  blockx,
  geo;

{ Core resource drawing functions }
procedure draw_it(name: string; x, y: word);
procedure load_predmet;
procedure load_texture;

implementation

{ === RESOURCE DRAWING === }

{ Generic drawing function - uses proven draw_gif_block from blockx
  Draws GIF blocks from MAIN.DAT
  Supports both direct files and blocks from DAT files
}
procedure draw_it(name: string; x, y: word);
var
  palette: tpalette;
  block_name: string;
begin
  if Length(name) = 0 then
    Exit;

  { Check if name starts with '>' indicating DAT file block }
  if name[1] = '>' then
  begin
    { Remove '>' prefix and load from DAT file }
    block_name := Copy(name, 2, Length(name) - 1);

    { Use proven draw_gif_block function }
    if not draw_gif_block(screen_image, 'data/MAIN.DAT', block_name, x, y, palette) then
    begin
      writeln('Warning: Failed to draw block "', block_name, '" from MAIN.DAT');
    end;
  end
  else
  begin
    { No prefix - assume direct block name from MAIN.DAT }
    { Use proven draw_gif_block function }
    if not draw_gif_block(screen_image, 'data/MAIN.DAT', name, x, y, palette) then
    begin
      writeln('Warning: Failed to draw block "', name, '" from MAIN.DAT');
    end;
  end;
end;

{ === ITEM SPRITE LOADING === }

{ Load item sprites from resource file
  Extracts sprites from VECI block and stores them
  Uses getsegxms/putsegxms from animing unit
}
procedure load_predmet;
var
  f, ff: word;
  resx, resy: word;
begin
  { Load item sprite sheet }
  { Original loads VECI block and extracts sprites }
  { For now, we'll use draw_it which works with draw_gif_block }

  resx := 16;  { Item sprite width }
  resy := 16;  { Item sprite height }

  { Draw items to screen for extraction }
  { In original: draw_it(veci, 0, 0) then extract with getsegxms }
  { Modern version will use animing functions }

  writeln('Loading item sprites...');
  { TODO: Implement sprite extraction using animing.getsegxms }
  { This will be completed when we integrate full animing support }
  writeln('Item sprites loaded (placeholder)');
end;

{ === TEXTURE LOADING === }

{ Load tile textures from resource file
  Extracts tiles from TEXTURA block
}
procedure load_texture;
var
  f, ff: word;
  resx, resy: word;
begin
  { Load texture tiles }
  { Original loads TEXTURA block and extracts tiles }
  { Uses draw_it then extracts with getseg }

  resx := 16;  { Tile width }
  resy := 16;  { Tile height }

  writeln('Loading tile textures...');
  { TODO: Implement tile extraction }
  { This will be completed when we integrate full animing support }
  writeln('Tile textures loaded (placeholder)');
end;

{ === INITIALIZATION === }

var
  initialization_done: boolean = False;

procedure InitLoad235;
begin
  if initialization_done then
    exit;

  initialization_done := True;
  writeln('LOAD235: Resource loader initialized');
end;

initialization
  InitLoad235;

finalization
  { Cleanup if needed }

end.
