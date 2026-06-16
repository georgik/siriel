/*
	Siriel Odin - Runtime Level Loader
	Loads .odin format level files at runtime

	Parses Odin struct syntax for Level data
*/

package level

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

// Parse int array from row string like "{0, 24, 0, ...}"
parse_tile_row :: proc(line: string) -> [38]int {
	row := [38]int{}

	// Find braces content
	start := strings.index_byte(line, '{')
	if start == -1 do return row
	end := strings.index_byte(line, '}')
	if end == -1 do return row

	content := strings.trim_space(line[start+1:end])

	// Parse comma-separated values
	parts := strings.split(content, ",")
	for i in 0..<len(parts) {
		if i >= 38 do break
		trimmed := strings.trim_space(parts[i])
		if len(trimmed) > 0 {
			val, ok := strconv.parse_int(trimmed)
			if ok do row[i] = val
		}
	}

	return row
}

// Load level from .odin file at runtime
load_level_file :: proc(file_path: string) -> (Level, bool) {
	level := Level {}
	level.tilemap.width = MAP_WIDTH
	level.tilemap.height = MAP_HEIGHT

	data, err := os.read_entire_file_from_path(file_path, context.allocator)
	if err != os.ERROR_NONE || len(data) == 0 {
		return level, false
	}

	content := string(data)
	lines := strings.split_lines(content)

	// Parse Odin struct format
	row_index := 0
	in_tilemap := false
	parsing_tiles := false

	for line in lines {
		trimmed := strings.trim_space(line)

		// Parse name
		if strings.contains(trimmed, "name = ") {
			parts := strings.split(trimmed, "=")
			if len(parts) >= 2 {
				name_part := strings.trim_space(parts[1])
				// Remove quotes if present
				if strings.index_byte(name_part, '"') == 0 {
					name_part = name_part[1:len(name_part)-1]
				}
				level.name = name_part
			}
		}

		// Parse music
		if strings.contains(trimmed, "music = ") {
			parts := strings.split(trimmed, "=")
			if len(parts) >= 2 {
				music_part := strings.trim_space(parts[1])
				if strings.index_byte(music_part, '"') == 0 {
					music_part = music_part[1:len(music_part)-1]
				}
				level.music = music_part
			}
		}

		// Parse start position
		if strings.contains(trimmed, "start_position = ") {
			// Extract Point { x = 88, y = 88 }
			x_start := strings.index(trimmed, "x = ")
			y_start := strings.index(trimmed, "y = ")
			if x_start != -1 && y_start != -1 {
				x_str := trimmed[x_start+4:]
				x_end := strings.index_any(x_str, ",}")
				if x_end != -1 {
					x_val, ok := strconv.parse_int(strings.trim_space(x_str[:x_end]))
					if ok do level.start_position.x = x_val
				}
				y_str := trimmed[y_start+4:]
				y_end := len(y_str)
				if y_end != -1 {
					y_val, ok := strconv.parse_int(strings.trim_space(y_str[:y_end]))
					if ok do level.start_position.y = y_val
				}
			}
		}

		// Detect tilemap section
		if strings.contains(trimmed, "tilemap = Map") {
			in_tilemap = true
		}

		// Detect tiles array start
		if in_tilemap && strings.contains(trimmed, "tiles = [26][38]int") {
			parsing_tiles = true
			row_index = 0
			continue
		}

		// Parse tile rows
		if parsing_tiles && strings.contains(trimmed, "{") {
			if row_index < MAP_HEIGHT {
				level.tilemap.tiles[row_index] = parse_tile_row(trimmed)
				row_index += 1
			}
		}

		// End of tiles array
		if parsing_tiles && strings.contains(trimmed, "},") && !strings.contains(trimmed, "{") {
			// Array closing
			if row_index >= MAP_HEIGHT {
				break
			}
		}
	}

	return level, true
}
