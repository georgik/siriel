unit koder;

{$mode objfpc}{$H+}

{ Caesar cipher encoder/decoder for Siriel data files }
{ Ported from original KODER.PAS }

interface

{ Encode a byte using the specified method }
procedure koduj(num: word; var bt: byte);

{ Decode a byte using the specified method }
{ num: 1 = add 2, 2 = NOT, 3 = add 74 }
procedure dekoduj(num: word; var bt: byte);

implementation

procedure koduj(num: word; var bt: byte);
begin
  case num of
    1: bt := bt - 2;

    2: bt := not bt;

    3: bt := bt - 74;
  end;
end;

procedure dekoduj(num: word; var bt: byte);
begin
  case num of
    1: bt := bt + 2;

    2: bt := not bt;

    3: bt := bt + 74;
  end;
end;

end.
