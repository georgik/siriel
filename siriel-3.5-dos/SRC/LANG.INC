const num_lang=2;

      language:array[1..num_lang] of string[3]=
       ('ENG','SLO');

      num_vyraz=27;
      num_vyraz2=4;
      num_vyraz3=12;

      tx:array[1..num_lang,1..num_vyraz] of string[20]=
      (('Time: ',' High score !',' Password:',' WOW !',' Ooou !',
        '   Quit','Pause...','Lifes: ','Loading...','Game','Info + Help',
        'Hi-scores','Quit','No message',' HELP:','password',
        'Enter ','Correct ','Incorrect ',' PASSWORD: ','Score:',
        'Back','Yes','No','Pocket','Empty','Inventory:'),
        ('�as: ',' Najvy��ie sk�re !',' Heslo:',' VAV !',' ���� !',
        '   Koniec','Pauza...','�ivoty: ','Nahr�vam...','Hra','Info + Pomoc',
        'Najlep�� hr��i','Koniec','�iadna spr�va',' POMOC:','heslo','Vlo� ',
        'Spr�vne ',' Nespr�vne ',' HESLO: ','Sk�re:','Sp��','�no','Nie',
        'Vrecko','Pr�zdne','Invent�r:'));

      tx2:array[1..num_lang,1..num_vyraz2] of string[25]=
      (('You`ve done it !','Select DATADISK','Unknown parameter !-<',
        'MAIN.DAT is CORRUPTED !'),
       ('   Zm�kol si to !','Vyber DATADISK','Nezn�my parameter !-<',
        'MAIN.DAT je po�koden� !'));


      tx3:array[1..num_lang,1..num_vyraz3] of string[80]=
      (('For this datadisk you need new Siriel 3.5 engine !',
      'Fatal error: MAIN.dat doesn`t exist !-<',
      'Arrows or NUM-pad => Move',
      'Space or Enter => Use',
      'Esc => Abort game, F1, H => HELP',
      'F4,P => Pause, F5, B => Briefing',
      'Controls: Arrows - move; Enter, Space - use',
      'No DATADISKS. You need to copy DATADISK into the SIRIEL.3_5 directory',
      'Siriel3.cfg was not found ! Run SETUP.EXE !',
      'CRC data deosn`t exist, file may be CORRUPTED !',
      'Incorect CRC ! File is  CORRUPTED !',
      'Do you still want to play it ? (contact me for correct version)'),
      ('Pre tento datadisk potrebujete nov� Siriel 3.5 engine !',
      'Osudov� chyba: MAIN.dat neexistuje !-<',
      '�ipky alebo NUM-pad => Pohyb',
      'Medzera alebo Enter => Pou�i',
      'ESC => Ukon�i hru, F1, H => POMOC',
      'F4, P => Pauza, F5, B => Br�fing',
      'Ovlad�nie: �ipky - pohyb; Enter, Medzera - pou�i',
      '�iadne DATADISKy. Nakopirujte DATADISK do adres�ra SIRIEL.3_5',
      'Siriel3.cfg nebol n�jdeny ! Spustite SETUP.EXE !',
      'CRC �daje neexistuj�, s�bor m��e by� PO�KODEN� !',
      'Nespr�vne CRC ! S�bor je po�koden� !',
      'Chcete aj na�alej hra� ? (kontaktujte ma pre spr�vnu verziu)'));