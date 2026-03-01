procedure load_texture;
begin
  writeln('[MAP_TILES] Loading map tiles as textures...');
  writeln('[MAP_TILES] Starting with textura="', textura, '"');

  { Use Raylib texture loading for proper color handling }
  if not blockx.load_map_tiles_textures(zvukovy_subor, textura, 16, 16, 190, map_tile_textures) then
  begin
    writeln('[MAP_TILES] ERROR: Failed to load map tiles');
    map_tiles_loaded := False;
    exit;
  end;

  writeln('[MAP_TILES] Successfully loaded 190 map tile textures');
  map_tiles_loaded := True;
end;
