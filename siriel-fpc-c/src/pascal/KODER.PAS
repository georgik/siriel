{$packrecords 1}   {TP7 port: pack records to match TP7 binary layout}
unit koder;         {vytvorena GEORGESOFTom pre vlastne potreby kodovania
                    suborov}


interface
procedure koduj(num:word;var bt:byte);
procedure dekoduj(num:word;var bt:byte);

implementation
uses crt;
var  b,f:word;
    c,d:byte;

procedure koduj(num:word;var bt:byte);
begin
 case num of
      1:bt:=bt-2;

      2:begin
             b:=bt;
             bt:=b;
        end;
      3:bt:=bt-74;
end; end;

procedure dekoduj(num:word;var bt:byte);
begin
 case num of
      1:bt:=bt+2;

      2:begin
             b:=bt;
             bt:=b;
        end;
      3:bt:=bt+74;
end; end;

end.