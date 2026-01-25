program testval;
var
  s: string;
  num, code: word;
begin
  s := '1';
  val(s, num, code);
  writeln('val("", num, code): num=', num, ' code=', code);
  
  s := '8';
  val(s, num, code);
  writeln('val("", num, code): num=', num, ' code=', code);
  
  s := '17';
  val(s, num, code);
  writeln('val("17", num, code): num=', num, ' code=', code);
end.
