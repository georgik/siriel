program test_manual_logo;

{$mode objfpc}{$H+}

{ Manual test to load GLOGO without block file system }

uses
  ctypes,
  raylib_helpers,
  jxgraf,
  jxfont_simple,
  koder,
  SysUtils;

const
  GLOGO_OFFSET = $137D;  { From hexdump analysis }
  GLOGO_SIZE = $0415;    { From hexdump analysis }

var
  fil: file;
  data: pointer;
  x, y, frame: integer;
  raw_data: PByte;
  width, height: word;
  color_value, palette_idx: byte;

begin
  writeln('=== Manual GLOGO Load Test ===');
  writeln('');

  { Initialize Raylib }
  InitWindow(640, 480, 'Manual Logo Load Test');
  SetTargetFPS(60);

  { Initialize screen }
  writeln('Screen initialized');
  writeln('');

  { Allocate memory for GLOGO data }
  GetMem(data, GLOGO_SIZE);
  writeln('Allocated ', GLOGO_SIZE, ' bytes for GLOGO');

  { Read GLOGO block from MAIN.DAT }
  AssignFile(fil, 'data/MAIN.DAT');
  {$I-}
  Reset(fil, 1);
  {$I+}

  if IOResult = 0 then
  begin
    Seek(fil, GLOGO_OFFSET);
    BlockRead(fil, data^, GLOGO_SIZE);
    CloseFile(fil);
    writeln('GLOGO data read from offset $', IntToHex(GLOGO_OFFSET, 4));

    { Decrypt the data }
    writeln('Decrypting data...');
    for x := 0 to GLOGO_SIZE - 1 do
    begin
      if PByte(NativeUInt(data) + x)^ <> 0 then
        dekoduj(1, PByte(NativeUInt(data) + x)^);
    end;

    { Read dimensions (first 2 bytes are width and height) }
    raw_data := PByte(data);
    width := raw_data[0] + (raw_data[1] shl 8);
    height := raw_data[2] + (raw_data[3] shl 8);

    writeln('Logo dimensions: ', width, 'x', height);
    writeln('');

    { Clear screen }
    clear_bitmap(screen_image);

    { Draw the logo (assuming raw palette-indexed bitmap) }
    writeln('Drawing logo at position (100, 50)...');

    for y := 0 to height - 1 do
    begin
      for x := 0 to width - 1 do
      begin
        { Skip the 4-byte header }
        palette_idx := PByte(NativeUInt(data) + 4 + y * width + x)^;

        { Draw pixel using palette color }
        if palette_idx > 0 then
          putpixel(screen_image, 100 + x, 50 + y, palette_to_rgba(palette_idx));
      end;
    end;

    FreeMem(data);
  end
  else
    writeln('ERROR: Cannot open MAIN.DAT');

  { Add test text }
  print_normal(screen_image, 10, 450, 'Manual GLOGO Load Test', 15, 0);

  writeln('');
  writeln('Starting render loop (will run for 2 seconds)...');
  writeln('');

  { Render for 2 seconds (120 frames) }
  for frame := 1 to 120 do
  begin
    BeginDrawing();
    ClearBackground(0, 0, 0, 255);

    RenderScreenToWindow();

    EndDrawing();
  end;

  { Take screenshot }
  writeln('Taking screenshot: manual_logo_test.png');
  TakeScreenshot(PChar('manual_logo_test.png'));
  writeln('Screenshot saved');

  { Cleanup }
  CloseWindow;
  writeln('');
  writeln('=== Test Complete ===');
  writeln('Check manual_logo_test.png for the GLOGO');
end.
