unit vare;
interface
const
            st_cas      = 'Cas';
            st_zvuk     = 'Zvuk';
	    maxmeno		= 19;

	    meno		: array[0..maxmeno]of string[20]=
	    ('Nehybne','Teleport','Predmet X','Predmet Y','Gravitacia',
	     'Gravit + detekcia','Obj/zmiz textury','Objavenie predmetov',
	     'Zmiznutie predmetov','Ukoncovac','Zivot','Objav/zmiz bludiska',
	     'Nahodne pohyblivy','Zmiz + objav','Prechod mapy','Fireball',
	     'Predator','Zvukar','Tichy Fireball','Mrazak');
var     anix,smrt,variant	: char;

implementation
begin
end.
