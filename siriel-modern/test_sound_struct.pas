program test_sound_struct;

{$mode objfpc}{$H+}

uses
  SysUtils,
  ctypes,
  raylib_helpers;

begin
  writeln('=== Raylib Sound Structure Test ===');
  writeln('');
  writeln('TRaylibSound size: ', SizeOf(TRaylibSound));
  writeln('  Expected: ', SizeOf(pointer) + ' + SizeOf(cuint) + ' + SizeOf(cint), ' (pointer + cuint + cint)');
  writeln('  pointer size: ', SizeOf(pointer));
  writeln('  cuint size: ', SizeOf(cuint));
  writeln('  cint size: ', SizeOf(cint));
  writeln('');
  writeln('PRaylibSound size: ', SizeOf(PRaylibSound));
end.
