
function po(a1,a2:word):boolean;
var b1,b2:word;
begin
     po:=true;
     inc(a1,3);
     b1:=a1 div 16;
     b2:=(a2+16) div 16;
  if (st.mie[b1,b2]>inusable)
	 and (getcol(a1,a2,st.mie[b1,b2],te^)<>13) then
			po:=false;
end;

function po3(a1,a2:integer):boolean;
var b1,b2:word;
begin
	po3:=true;
		  b1:=(a1+3) div 16;
		  b2:=(a2+16) div 16;

	 if (st.mie[b1,b2]>inusable)
		and (getcol(a1+3,a2,st.mie[b1,b2],te^)<>13) then
		 po3:=false;
end;


