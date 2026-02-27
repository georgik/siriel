{ Test avatar implementation - draws simple animated character }
unit test_avatar;

{$mode objfpc}{$H+}

interface

uses
  jxgraf;

{ Draw a simple test avatar that changes color }
procedure DrawTestAvatar(x, y: word; anim_frame: byte);

implementation

procedure DrawTestAvatar(x, y: word; anim_frame: byte);
var
  color: byte;
  local_x, local_y: word;
begin
  { Cycle through 8 colors based on animation frame }
  case (anim_frame mod 8) of
    0: color := 15;  { White }
    1: color := 14;  { Yellow }
    2: color := 13;  { Light magenta }
    3: color := 12;  { Light red }
    4: color := 11;  { Light cyan }
    5: color := 10;  { Light green }
    6: color := 9;   { Light blue }
    7: color := 15;  { White }
    else color := 15;
  end;

  { Draw 16x16 colored rectangle }
  for local_y := 0 to 15 do
    for local_x := 0 to 15 do
      putpixel(screen_image, x + local_x, y + local_y, palette_to_rgba(color));

  { Draw eyes (white) }
  if (anim_frame mod 16) < 8 then
  begin
    putpixel(screen_image, x + 4, y + 5, $FFFFFFFF);
    putpixel(screen_image, x + 11, y + 5, $FFFFFFFF);
  end;
end;

end.
