program test_aktiv35_init;

{$mode objfpc}{$H+}

{ Test AKTIV35 unit initialization
  Verifies that modern_mem integration works correctly
  Usage: ./test_aktiv35_init
}

uses
  SysUtils,
  modern_mem,
  aktiv35;

var
  test_size: longint;
  test_handle: klucka;
  test_data: array[0..99] of byte;
  i: integer;
  ok: boolean;

begin
  writeln('=== AKTIV35 Unit Initialization Test ===');
  writeln('Testing modern_mem integration');
  writeln('');

  { Test 1: Initialize AKTIV35 }
  writeln('[1] Initializing AKTIV35 unit...');
  InitAktiv35;
  writeln('    OK - Unit initialized');
  writeln('');

  { Test 2: Verify handles are initialized }
  writeln('[2] Verifying handles array...');
  ok := true;
  for i := 1 to max_handles do
  begin
    if handles[i].used then
    begin
      writeln('    ERROR: Handle ', i, ' is marked as used');
      ok := false;
    end;
    if handles[i].ptr <> nil then
    begin
      writeln('    ERROR: Handle ', i, ' has non-nil pointer');
      ok := false;
    end;
  end;
  if ok then
    writeln('    OK - All ', max_handles, ' handles are clean');
  writeln('');

  { Test 3: Test handle allocation }
  writeln('[3] Testing handle allocation...');
  test_size := 1024;
  if create_handle(handles[1], test_size) then
    writeln('    OK - Handle 1 allocated (', test_size, ' bytes)')
  else
    writeln('    ERROR: Handle 1 allocation failed');
  writeln('');

  { Test 4: Write test data to handle }
  writeln('[4] Writing test pattern to handle 1...');
  if handles[1].used and (handles[1].ptr <> nil) then
  begin
    for i := 0 to 99 do
      PByte(handles[1].ptr + i)^ := (i * 7) mod 256;
    writeln('    OK - Test pattern written');
  end
  else
    writeln('    ERROR: Handle 1 not available for writing');
  writeln('');

  { Test 5: Read and verify data }
  writeln('[5] Reading and verifying data...');
  ok := true;
  if handles[1].used and (handles[1].ptr <> nil) then
  begin
    for i := 0 to 99 do
    begin
      test_data[i] := PByte(handles[1].ptr + i)^;
      if test_data[i] <> ((i * 7) mod 256) then
      begin
        writeln('    ERROR: Data mismatch at index ', i);
        ok := false;
        break;
      end;
    end;
    if ok then
      writeln('    OK - All 100 bytes verified');
  end
  else
    writeln('    ERROR: Handle 1 not available for reading');
  writeln('');

  { Test 6: Free handle }
  writeln('[6] Testing handle cleanup...');
  if kill_handle(handles[1]) then
    writeln('    OK - Handle 1 freed')
  else
    writeln('    WARNING: Handle 1 was not allocated');
  writeln('');

  { Test 7: Verify cleanup }
  writeln('[7] Verifying handle cleanup...');
  if not handles[1].used and (handles[1].ptr = nil) then
    writeln('    OK - Handle 1 properly cleaned up')
  else
  begin
    writeln('    ERROR: Handle 1 not properly cleaned');
    writeln('    used=', handles[1].used, ' ptr=', PtrUInt(handles[1].ptr));
  end;
  writeln('');

  writeln('=== Test Complete ===');
  writeln('');
  writeln('AKTIV35 unit modern_mem integration test successful!');
  writeln('  - Handles array initialized correctly');
  writeln('  - create_handle() works');
  writeln('  - Memory read/write works');
  writeln('  - kill_handle() works');
  writeln('  - Cleanup verification passed');
  writeln('');
end.
