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
