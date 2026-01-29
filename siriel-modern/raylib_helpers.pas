unit raylib_helpers;

{$mode objfpc}{$H+}

{ This unit provides direct Pascal bindings to Raylib C functions }
{ All types here match the C Raylib API exactly }

interface

uses
  ctypes;

{ Raylib types that match C exactly }
type
  PRaylibImage = ^TRaylibImage;
  TRaylibImage = record
    data: pointer;
    width: cint;
    height: cint;
    mipmaps: cint;
    format: cint;
  end;

  PRaylibTexture2D = ^TRaylibTexture2D;
  TRaylibTexture2D = record
    id: cuint;
    width: cint;
    height: cint;
    mipmaps: cint;
    format: cint;
  end;

  TRectangle = record
    x: cfloat;
    y: cfloat;
    width: cfloat;
    height: cfloat;
  end;

  TVector2 = record
    x: cfloat;
    y: cfloat;
  end;

  PRaylibAudioStream = ^TRaylibAudioStream;
  TRaylibAudioStream = record
    buffer: pointer;
    processor: pointer;
    sampleRate: cuint;
    sampleSize: cuint;
    channels: cuint;
  end;

  PRaylibSound = ^TRaylibSound;
  TRaylibSound = record
    stream: TRaylibAudioStream;
    frameCount: cuint;
  end;

  PRaylibWave = ^TRaylibWave;
  TRaylibWave = record
    data: pointer;
    sampleCount: cuint;
    sampleRate: cuint;
    sampleSize: cuint;
    channels: cuint;
  end;

{ Pixel format constants }
const
  PIXELFORMAT_UNCOMPRESSED_GRAYSCALE = 1;     // 8 bit per pixel (no alpha)
  PIXELFORMAT_UNCOMPRESSED_GRAY_ALPHA = 2;    // 8*2 bpp (2 channels)
  PIXELFORMAT_UNCOMPRESSED_R5G6B5 = 3;        // 16 bpp
  PIXELFORMAT_UNCOMPRESSED_R8G8B8 = 4;        // 24 bpp
  PIXELFORMAT_UNCOMPRESSED_R5G5B5A1 = 5;      // 16 bpp (1 bit alpha)
  PIXELFORMAT_UNCOMPRESSED_R4G4B4A4 = 6;      // 16 bpp (4 bit alpha)
  PIXELFORMAT_UNCOMPRESSED_R8G8B8A8 = 7;      // 32 bpp
  PIXELFORMAT_UNCOMPRESSED_R32 = 8;           // 32 bpp (1 channel - float)
  PIXELFORMAT_UNCOMPRESSED_R32G32B32 = 9;     // 32*3 bpp (3 channels - float)
  PIXELFORMAT_UNCOMPRESSED_R32G32B32A32 = 10; // 32*4 bpp (4 channels - float)
  PIXELFORMAT_COMPRESSED_DXT1_RGB = 11;       // 4 bpp (no alpha)
  PIXELFORMAT_COMPRESSED_DXT1_RGBA = 12;      // 4 bpp (1 bit alpha)
  PIXELFORMAT_COMPRESSED_DXT3_RGBA = 13;      // 8 bpp
  PIXELFORMAT_COMPRESSED_DXT5_RGBA = 14;      // 8 bpp
  PIXELFORMAT_COMPRESSED_ETC1_RGB = 15;       // 4 bpp
  PIXELFORMAT_COMPRESSED_ETC2_RGB = 16;       // 4 bpp
  PIXELFORMAT_COMPRESSED_ETC2_EAC_RGBA = 17;  // 8 bpp
  PIXELFORMAT_COMPRESSED_PVRT_RGB = 18;       // 4 bpp
  PIXELFORMAT_COMPRESSED_PVRT_RGBA = 19;      // 4 bpp
  PIXELFORMAT_COMPRESSED_ASTC_4x4_RGBA = 20;  // 8 bpp
  PIXELFORMAT_COMPRESSED_ASTC_8x8_RGBA = 21;  // 2 bpp

{ Core Raylib functions }
procedure InitWindow(width: cint; height: cint; title: PChar); cdecl; external 'raylib';
procedure CloseWindow(); cdecl; external 'raylib';
function WindowShouldClose(): cint; cdecl; external 'raylib';
procedure BeginDrawing(); cdecl; external 'raylib';
procedure EndDrawing(); cdecl; external 'raylib';
procedure ClearBackground(r: cuchar; g: cuchar; b: cuchar; a: cuchar); cdecl; external 'raylib';
function GetFPS(): cint; cdecl; external 'raylib';
procedure SetTargetFPS(fps: cint); cdecl; external 'raylib';
function IsKeyDown(key: cint): cint; cdecl; external 'raylib';

{ Drawing functions }
procedure DrawPixel(x: cint; y: cint; color: cuint); cdecl; external 'raylib';
procedure DrawLine(x1: cint; y1: cint; x2: cint; y2: cint; color: cuint); cdecl; external 'raylib';
procedure DrawRectangle(x: cint; y: cint; width: cint; height: cint; color: cuint); cdecl; external 'raylib';
procedure DrawCircle(x: cint; y: cint; radius: cint; color: cuint); cdecl; external 'raylib';

{ Image functions }
function LoadImage(filename: PChar): TRaylibImage; cdecl; external 'raylib';
function LoadImageFromMemory(fileType: PChar; data: pointer; dataSize: cint): TRaylibImage; cdecl; external 'raylib';
procedure UnloadImage(image: TRaylibImage); cdecl; external 'raylib';
function ImageCopy(image: TRaylibImage): TRaylibImage; cdecl; external 'raylib';
procedure ImageFormat(img: PRaylibImage; newFormat: cint); cdecl; external 'raylib';
procedure ImageDrawPixel(img: PRaylibImage; x: cint; y: cint; color: cuint); cdecl; external 'raylib';
procedure ImageDrawLine(img: PRaylibImage; x1: cint; y1: cint; x2: cint; y2: cint; color: cuint); cdecl; external 'raylib';
procedure ImageDrawRectangle(img: PRaylibImage; x: cint; y: cint; width: cint; height: cint; color: cuint); cdecl; external 'raylib';
procedure ImageDrawCircle(img: PRaylibImage; x: cint; y: cint; radius: cint; color: cuint); cdecl; external 'raylib';

{ Texture functions }
function LoadTextureFromImage(image: TRaylibImage): TRaylibTexture2D; cdecl; external 'raylib';
procedure UnloadTexture(texture: TRaylibTexture2D); cdecl; external 'raylib';
procedure DrawTexture(texture: TRaylibTexture2D; x: cint; y: cint; tint: cuint); cdecl; external 'raylib';
procedure DrawTextureRec(texture: TRaylibTexture2D; srcRec: TRectangle; pos: TVector2; tint: cuint); cdecl; external 'raylib';

{ Screenshot function }
procedure TakeScreenshot(fileName: PChar); cdecl; external 'raylib';

{ Text drawing functions }
procedure DrawText(text: PChar; x: cint; y: cint; fontSize: cint; r: cuchar; g: cuchar; b: cuchar; a: cuchar); cdecl; external 'raylib';
function IsKeyPressed(key: cint): cint; cdecl; external 'raylib';

{ Audio functions }
procedure InitAudioDevice(); cdecl; external 'raylib';
procedure CloseAudioDevice(); cdecl; external 'raylib';
function IsAudioDeviceReady(): cint; cdecl; external 'raylib';
function LoadSound(fileName: PChar): TRaylibSound; cdecl; external 'raylib';
function LoadWave(fileName: PChar): TRaylibWave; cdecl; external 'raylib';
function LoadWaveFromMemory(fileType: PChar; data: pointer; dataSize: cint): TRaylibWave; cdecl; external 'raylib';
function LoadSoundFromWave(wave: TRaylibWave): TRaylibSound; cdecl; external 'raylib';
procedure UnloadWave(wave: TRaylibWave); cdecl; external 'raylib';
procedure UnloadSound(sound: TRaylibSound); cdecl; external 'raylib';
procedure PlaySound(sound: TRaylibSound); cdecl; external 'raylib';
procedure StopSound(sound: TRaylibSound); cdecl; external 'raylib';
procedure PauseSound(sound: TRaylibSound); cdecl; external 'raylib';
procedure ResumeSound(sound: TRaylibSound); cdecl; external 'raylib';
function IsSoundPlaying(sound: TRaylibSound): cint; cdecl; external 'raylib';
procedure SetSoundVolume(sound: TRaylibSound; volume: cfloat); cdecl; external 'raylib';
procedure SetSoundPitch(sound: TRaylibSound; pitch: cfloat); cdecl; external 'raylib';

implementation

end.
