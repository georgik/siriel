unit dos_compat;

{$mode objfpc}{$H+}

{ This unit provides DOS-compatible functions for Siriel Modern }
{ Replaces Turbo Pascal DOS unit with modern FPC equivalents }

interface

uses
  SysUtils;

{ File operations }
function subor_exist(filename: string): boolean;

{ String operations }
procedure upcased(var s: string);
function out_string(s: string): string;

{ Error handling }
procedure write_error(msg: string);

{ Missing constants from TXT unit that we need }
const
  death_color = 0;  { Transparent color index }
  gif_x: word = 0;
  gif_y: word = 0;

{ Missing error constants }
const
  Image_Ok = 0;
  Err_BadRead = 1;
  Err_BadWrite = 2;
  Err_BadSymbolSize = 3;
  Err_BadGifCode = 4;
  Err_BadFirstGifCode = 5;
  Err_InvalidBlockSize = 6;
  Err_NotAGif = 7;

implementation

{ Check if file exists }
function subor_exist(filename: string): boolean;
begin
  subor_exist := FileExists(filename);
end;

{ Convert string to uppercase in place }
procedure upcased(var s: string);
var
  i: integer;
begin
  for i := 1 to Length(s) do
    s[i] := UpCase(s[i]);
end;

{ Output string (placeholder for now) }
function out_string(s: string): string;
begin
  { TODO: Implement string processing if needed }
  out_string := s;
end;

{ Write error message }
procedure write_error(msg: string);
begin
  WriteLn(stderr, 'ERROR: ', msg);
end;

end.
