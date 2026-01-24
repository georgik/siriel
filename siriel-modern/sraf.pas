unit sraf;

{$mode objfpc}{$H+}

interface

uses
  ctypes;

{ Raylib bindings for graphics }
type
  PTexture2D = ^TTexture2D;
  TTexture2D = record
    id: cuint;
    width: cint;
    height: cint;
    mipmaps: cint;
    format: cint;
  end;

  PImage = ^TImage;
  TImage = record
    data: pointer;
    width: cint;
    height: cint;
    mipmaps: cint;
    format: cint;
  end;

  PVector2 = ^TVector2;
  TVector2 = record
    x: cfloat;
    y: cfloat;
  end;

  PRectangle = ^TRectangle;
  TRectangle = record
    x: cfloat;
    y: cfloat;
    width: cfloat;
    height: cfloat;
  end;

{ Raylib function declarations }
procedure DrawPixel(x, y: cint; color: cuint); cdecl; external;
procedure DrawLine(x1, y1, x2, y2: cint; color: cuint); cdecl; external;
procedure DrawRectangleRec(rec: TRectangle; color: cuint); cdecl; external;
procedure DrawCircle(x, y, radius: cint; color: cuint); cdecl; external;

function LoadImage(filename: PChar): TImage; cdecl; external;
function LoadImageFromMemory(fileType: PChar; data: pointer; dataSize: cint): TImage; cdecl; external;
procedure UnloadImage(image: TImage); cdecl; external;

function LoadTextureFromImage(image: TImage): TTexture2D; cdecl; external;
procedure UnloadTexture(texture: TTexture2D); cdecl; external;
procedure DrawTextureRec(texture: TTexture2D; srcRec: TRectangle; pos: TVector2; tint: cuint); cdecl; external;
procedure DrawTexturePro(texture: TTexture2D; srcRec, destRec: TRectangle; origin: TVector2; rotation: cfloat; tint: cuint); cdecl; external;

function ImageCopy(image: TImage): TImage; cdecl; external;
procedure ImageDrawPixel(img: PImage; x, y: cint; color: cuint); cdecl; external;
procedure ImageDrawLine(img: PImage; x1, y1, x2, y2: cint; color: cuint); cdecl; external;
procedure ImageDrawRectangle(img: PImage; x, y, width, height: cint; color: cuint); cdecl; external;
procedure ImageDrawCircle(img: PImage; x, y, radius: cint; color: cuint); cdecl; external;

{ Color definitions }
function Color(r, g, b, a: cuchar): cuint; inline;

const
  COLOR_WHITE = $FFFFFFFF;
  COLOR_BLACK = $FF000000;
  COLOR_RED   = $FF0000FF;
  COLOR_GREEN = $FF00FF00;
  COLOR_BLUE  = $FFFF0000;
  COLOR_YELLOW= $FF00FFFF;
  COLOR_GRAY  = $FF888888;

{ SRAF - Siriel Raylib Abstraction Layer }

type
  PSrafImage = ^TSrafImage;
  TSrafImage = record
    raylibImage: TImage;
    texture: TTexture2D;
    isLoaded: boolean;
  end;

{ Core SRAF functions }
function SrafCreateImage(width, height: cint): PSrafImage;
procedure SrafDestroyImage(img: PSrafImage);
procedure SrafPutPixel(img: PSrafImage; x, y: cint; color: cuint);
function SrafGetPixel(img: PSrafImage; x, y: cint): cuint;
procedure SrafDrawLine(img: PSrafImage; x1, y1, x2, y2: cint; color: cuint);
procedure SrafDrawRectangle(img: PSrafImage; x, y, width, height: cint; color: cuint);
procedure SrafDrawCircle(img: PSrafImage; x, y, radius: cint; color: cuint);

{ Screen drawing }
procedure SrafDrawImage(img: PSrafImage; x, y: cint);
procedure SrafDrawImageRec(img: PSrafImage; srcX, srcY, srcW, srcH, destX, destY: cint);

{ Utility }
procedure SrafUpdateTexture(img: PSrafImage);
function SrafColorFromPalette(paletteIndex: cuchar): cuint;

implementation

{ Color helper }
function Color(r, g, b, a: cuchar): cuint;
begin
  Color := (a shl 24) or (r shl 16) or (g shl 8) or b;
end;

{ Image creation }
function SrafCreateImage(width, height: cint): PSrafImage;
var
  img: PSrafImage;
begin
  New(img);
  img^.raylibImage.data := nil;
  img^.raylibImage.width := width;
  img^.raylibImage.height := height;
  img^.raylibImage.mipmaps := 1;
  img^.raylibImage.format := 7; { PIXELFORMAT_UNCOMPRESSED_R8G8B8A8 }
  img^.isLoaded := False;
  
  { Allocate image data }
  GetMem(img^.raylibImage.data, width * height * 4);
  FillChar(img^.raylibImage.data^, width * height * 4, 0);
  
  SrafCreateImage := img;
end;

{ Image destruction }
procedure SrafDestroyImage(img: PSrafImage);
begin
  if Assigned(img) then
  begin
    if img^.isLoaded then
      UnloadTexture(img^.texture);
    if Assigned(img^.raylibImage.data) then
      FreeMem(img^.raylibImage.data);
    Dispose(img);
  end;
end;

{ Pixel operations }
procedure SrafPutPixel(img: PSrafImage; x, y: cint; color: cuint);
begin
  if not Assigned(img) then Exit;
  if (x < 0) or (x >= img^.raylibImage.width) then Exit;
  if (y < 0) or (y >= img^.raylibImage.height) then Exit;
  
  ImageDrawPixel(@img^.raylibImage, x, y, color);
end;

function SrafGetPixel(img: PSrafImage; x, y: cint): cuint;
var
  data: Pcuint;
begin
  SrafGetPixel := COLOR_BLACK;
  
  if not Assigned(img) then Exit;
  if (x < 0) or (x >= img^.raylibImage.width) then Exit;
  if (y < 0) or (y >= img^.raylibImage.height) then Exit;
  
  data := Pcuint(img^.raylibImage.data);
  data := data + (y * img^.raylibImage.width + x);
  SrafGetPixel := data^;
end;

{ Drawing primitives }
procedure SrafDrawLine(img: PSrafImage; x1, y1, x2, y2: cint; color: cuint);
begin
  if not Assigned(img) then Exit;
  ImageDrawLine(@img^.raylibImage, x1, y1, x2, y2, color);
end;

procedure SrafDrawRectangle(img: PSrafImage; x, y, width, height: cint; color: cuint);
begin
  if not Assigned(img) then Exit;
  ImageDrawRectangle(@img^.raylibImage, x, y, width, height, color);
end;

procedure SrafDrawCircle(img: PSrafImage; x, y, radius: cint; color: cuint);
begin
  if not Assigned(img) then Exit;
  ImageDrawCircle(@img^.raylibImage, x, y, radius, color);
end;

{ Texture management }
procedure SrafUpdateTexture(img: PSrafImage);
begin
  if not Assigned(img) then Exit;
  
  if img^.isLoaded then
    UnloadTexture(img^.texture);
    
  img^.texture := LoadTextureFromImage(img^.raylibImage);
  img^.isLoaded := True;
end;

{ Screen drawing }
procedure SrafDrawImage(img: PSrafImage; x, y: cint);
var
  pos: TVector2;
begin
  if not Assigned(img) then Exit;
  if not img^.isLoaded then
    SrafUpdateTexture(img);
    
  pos.x := x;
  pos.y := y;
  DrawTexturePro(img^.texture,
    Rectangle(0, 0, img^.raylibImage.width, img^.raylibImage.height),
    Rectangle(x, y, img^.raylibImage.width, img^.raylibImage.height),
    Vector2(0, 0), 0.0, COLOR_WHITE);
end;

procedure SrafDrawImageRec(img: PSrafImage; srcX, srcY, srcW, srcH, destX, destY: cint);
var
  srcRect, destRect: TRectangle;
  pos: TVector2;
begin
  if not Assigned(img) then Exit;
  if not img^.isLoaded then
    SrafUpdateTexture(img);
    
  srcRect.x := srcX;
  srcRect.y := srcY;
  srcRect.width := srcW;
  srcRect.height := srcH;
  
  destRect.x := destX;
  destRect.y := destY;
  destRect.width := srcW;
  destRect.height := srcH;
  
  pos.x := 0;
  pos.y := 0;
  
  DrawTexturePro(img^.texture, srcRect, destRect, pos, 0.0, COLOR_WHITE);
end;

{ Palette support - basic VGA palette conversion }
function SrafColorFromPalette(paletteIndex: cuchar): cuint;
{ Simple grayscale palette for now }
var
  intensity: cuchar;
begin
  intensity := paletteIndex;
  SrafColorFromPalette := Color(intensity, intensity, intensity, 255);
end;

{ Helper functions for rectangle and vector creation }
function Rectangle(x, y, width, height: cfloat): TRectangle;
begin
  Rectangle.x := x;
  Rectangle.y := y;
  Rectangle.width := width;
  Rectangle.height := height;
end;

function Vector2(x, y: cfloat): TVector2;
begin
  Vector2.x := x;
  Vector2.y := y;
end;

end.
