program mys_convertor;
uses txt,geo,crt,dos,jxgmouse;

var
   s,s2    : string;

begin
   selectfile(2,2,s,'*.out');
   if s<>'' then begin
      clrscr;
      write('Mouse output (.mys): ');
      readln(s2);
      s2:=s2+'.mys';
      convert_mouse_record(s,s2);
   end;
   credits('Mouse file convertor');
end.