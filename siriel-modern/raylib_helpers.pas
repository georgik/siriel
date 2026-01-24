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

implementation

end.
