{$m 16384,0,300000}
program xmsparameter;


uses txt,crt,xms2,geo,jxgraf,flik;

var x,y,z,k:word;
    size:longint;
    b:byte;
begin
  clrscr;
  x:=256;
  y:=256;
  z:=16;
  size:=x;
  size:=size*y;
  size:=size*z;
  size:=size*z;
  writeln(size);
  writeln(x*y*z*z);
  key;
end.