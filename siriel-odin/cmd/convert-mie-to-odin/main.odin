/*
	MIE to Odin Level Converter

	Converts original Siriel 3.5 .MIE files to modern .odin format.

	Usage:
		convert-mie-to-odin <input.mie> <output.odin>
*/

package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

/*
	MIE Format Structures
*/

MIE_Header :: struct {
	name: string,
	start_x: int,
	start_y: int,
	sound_start: string,
}

MIE_Object :: struct {
	code: [4]byte,  // 4-letter type code
	sprite: int,
	x: int,
	y: int,
	funk: int,
	params: [10]int,  // p1-p7, z1, z2 (padding for unused)
}

MIE_Level :: struct {
	header: MIE_Header,
	objects: [dynamic]MIE_Object,
	map_data: [dynamic]byte,  // Raw map bytes
}

/*
	Parsing Functions
*/

parse_mie_file :: proc(path: string) -> (MIE_Level, bool) {
	level: MIE_Level

	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil || len(data) == 0 {
		fmt.eprintf("Failed to read file: %s\n", path)
		return level, false
	}

	content := string(data)
	lines := strings.split_lines(content)

	in_map_section := false
	map_row := 0
	MAP_WIDTH :: 38
	MAP_HEIGHT :: 26

	for line in lines {
		trimmed := strings.trim_space(line)

		// Skip empty lines
		if len(trimmed) == 0 do continue

		// Handle [MAPA]= section
		if len(trimmed) >= 7 && trimmed[:7] == "[MAPA]=" {
			in_map_section = true
			continue
		}

		// Parse map data
		if in_map_section {
			if len(trimmed) >= MAP_WIDTH {
				for x in 0..<MAP_WIDTH {
					if x < len(trimmed) {
						ch := trimmed[x]
						// Skip LF/CR
						if ch == 10 || ch == 13 do continue

						// Convert ASCII to tile index (offset by 15)
						tile_val := int(ch) - 15
						if tile_val >= 0 && tile_val < 256 {
							append(&level.map_data, byte(tile_val))
						} else {
							append(&level.map_data, 0)
						}
					}
				}
				map_row += 1
				if map_row >= MAP_HEIGHT {
					in_map_section = false
				}
			}
			continue
		}

		// Skip non-headers in map section
		if len(trimmed) == 0 || trimmed[0] != '[' do continue

		// Parse [KEY]=value format
		close_bracket := strings.index(trimmed, "]")
		if close_bracket == -1 do continue

		equals := strings.index(trimmed, "=")
		if equals == -1 do continue

		key := trimmed[1:close_bracket]
		value := strings.trim_space(trimmed[equals+1:])

		// Parse based on key
		if key == "MENO" {
			level.header.name = value
		} else if key == "START" {
			coords := strings.split(value, ",")
			if len(coords) >= 2 {
				level.header.start_x, _ = strconv.parse_int(coords[0])
				level.header.start_y, _ = strconv.parse_int(coords[1])
			}
		} else if key == "SNDSTART" {
			level.header.sound_start = value
		} else if len(key) == 4 {
			// Object code (4-letter code)
			obj, ok := parse_object_line(key, value)
			if ok {
				append(&level.objects, obj)
			}
		}
	}

	return level, true
}

parse_object_line :: proc(code: string, value: string) -> (MIE_Object, bool) {
	obj: MIE_Object

	// Copy 4-letter code
	copy(obj.code[:], code)

	// Parse parameters: sprite,x,y,funk,p1,p2,p3,p4,p5,p6,p7,z1,z2
	params := strings.split(value, ",")

	if len(params) < 4 do return obj, false

	obj.sprite, _ = strconv.parse_int(params[0])
	obj.x, _ = strconv.parse_int(params[1])
	obj.y, _ = strconv.parse_int(params[2])
	obj.funk, _ = strconv.parse_int(params[3])

	// Parse additional parameters
	for i in 4..<min(len(params), 14) {
		obj.params[i-4], _ = strconv.parse_int(params[i])
	}

	return obj, true
}

/*
	Helper Functions
*/

itoa :: proc(val: int) -> string {
	return fmt.aprintf("%d", val)
}

make_obj_id :: proc(x: int, y: int) -> string {
	return fmt.aprintf("obj_%d_%d", x, y)
}

/*
	Conversion Functions
*/

mie_to_odin :: proc(mie: MIE_Level) -> string {
	odin: strings.Builder

	// Header
	strings.write_string(&odin, "Level \"")
	strings.write_string(&odin, mie.header.name)
	strings.write_string(&odin, "\" {\n")
	strings.write_string(&odin, "    name: \"")
	strings.write_string(&odin, mie.header.name)
	strings.write_string(&odin, "\",\n")
	strings.write_string(&odin, "    music: \"")
	strings.write_string(&odin, mie.header.sound_start)
	strings.write_string(&odin, "\",\n")
	strings.write_string(&odin, "    start_position: Point { x = ")
	strings.write_string(&odin, itoa(mie.header.start_x))
	strings.write_string(&odin, ", y = ")
	strings.write_string(&odin, itoa(mie.header.start_y))
	strings.write_string(&odin, " },\n\n")

	// Objects
	strings.write_string(&odin, "    objects: []Object {\n")

	for obj in mie.objects {
		odin_obj := convert_object(obj)
		strings.write_string(&odin, odin_obj)
	}

	strings.write_string(&odin, "    },\n\n")

	// Map data as 2D array
	strings.write_string(&odin, "    map: Map {\n")
	strings.write_string(&odin, "        width:  38,\n")
	strings.write_string(&odin, "        height: 26,\n")
	strings.write_string(&odin, "        tiles: [26][38]int {\n")

	MAP_WIDTH :: 38
	MAP_HEIGHT :: 26

	for y in 0..<MAP_HEIGHT {
		strings.write_string(&odin, "            {")
		for x in 0..<MAP_WIDTH {
			idx := y * MAP_WIDTH + x
			if idx < len(mie.map_data) {
				strings.write_string(&odin, itoa(int(mie.map_data[idx])))
			} else {
				strings.write_string(&odin, "0")
			}
			if x < MAP_WIDTH - 1 {
				strings.write_string(&odin, ", ")
			}
		}
		strings.write_string(&odin, "},\n")
	}

	strings.write_string(&odin, "        },\n")
	strings.write_string(&odin, "    },\n")

	strings.write_string(&odin, "}\n")

	return strings.to_string(odin)
}

convert_object :: proc(obj: MIE_Object) -> string {
	builder: strings.Builder

	// Decode 4-letter code
	type_char := obj.code[0]
	anim_char := obj.code[1]
	danger_char := obj.code[2]
	group_char := obj.code[3]

	// Map type character to enum
	type_name := ""
	switch type_char {
		case 'Z': type_name = ".Collectible"
		case 'Y': type_name = ".Trigger"
		case 'X': type_name = ".Interactable"
		case 'W': type_name = ".Walker"
		case 'V': type_name = ".Static"
		case:    type_name = ".Static"
	}

	// Generate object ID
	obj_id := make_obj_id(obj.x, obj.y)

	strings.write_string(&builder, "        Object {\n")
	strings.write_string(&builder, "            id:       \"")
	strings.write_string(&builder, obj_id)
	strings.write_string(&builder, "\",\n")
	strings.write_string(&builder, "            type:     ")
	strings.write_string(&builder, type_name)
	strings.write_string(&builder, ",\n")
	strings.write_string(&builder, "            sprite:   ")
	strings.write_string(&builder, itoa(obj.sprite))
	strings.write_string(&builder, ",\n")
	strings.write_string(&builder, "            position: Point { x = ")
	strings.write_string(&builder, itoa(obj.x))
	strings.write_string(&builder, ", y = ")
	strings.write_string(&builder, itoa(obj.y))
	strings.write_string(&builder, " },\n")

	// Map funk number to enum (based on object type)
	funk_name := get_funk_name_for_type(obj.funk, type_char)
	strings.write_string(&builder, "            funk:     ")
	strings.write_string(&builder, funk_name)
	strings.write_string(&builder, ",\n")

	// Add funk-specific parameters
	add_funk_params(&builder, obj)

	// Group from code
	if group_char >= 'A' && group_char <= 'G' {
		strings.write_string(&builder, "            group:    .")
		strings.write_byte(&builder, group_char)
		strings.write_string(&builder, ",\n")
	}

	strings.write_string(&builder, "        },\n")

	return strings.to_string(builder)
}

get_funk_name :: proc(funk: int) -> string {
	switch funk {
		case 0:  return ".Default"
		case 1:  return ".Teleport"
		case 2:  return ".PlatformX"
		case 3:  return ".PlatformY"
		case 4:  return ".PatrolX"
		case 5:  return ".PatrolY"
		case 6:  return ".TextureChange"
		case 7:  return ".ShowItems"
		case 8:  return ".HideItems"
		case 9:  return ".LevelComplete"
		case 10: return ".AddLife"
		case 11: return ".MazeVisibility"
		case 12: return ".RandomMove"
		case 13: return ".SwapRoomVisibility"
		case 14: return ".TransferToStage"
		case 15: return ".Fireball"
		case 16: return ".Enemy"
		case 17: return ".SoundEmitter"
		case 18: return ".FireballWithSound"
		case 19: return ".Powerup"
		case:   return ".Default"
	}
}

// Get funk name based on object type
get_funk_name_for_type :: proc(funk: int, type_char: byte) -> string {
	// Z-type (Collectible) objects are always collectibles
	// The funk value modifies behavior but doesn't change the core type
	if type_char == 'Z' {
		return ".Default"  // Collectibles always use Default behavior
	}

	// For other types, use the funk mapping
	return get_funk_name(funk)
}

add_funk_params :: proc(builder: ^strings.Builder, obj: MIE_Object) {
	type_char := obj.code[0]

	// Handle collectibles (Z-type) - always use points/anim format
	if type_char == 'Z' {
		// Collectibles use params[0] for points, params[1] for anim
		strings.write_string(builder, "            points:   ")
		strings.write_string(builder, itoa(obj.params[0]))
		strings.write_string(builder, ",\n")
		strings.write_string(builder, "            anim:     .Animated,\n")
		return
	}

	// For other types, use funk-specific parameters
	switch obj.funk {
		case 0:  // Default: points, anim (for non-Z types)
			strings.write_string(builder, "            points:   ")
			strings.write_string(builder, itoa(obj.params[0]))
			strings.write_string(builder, ",\n")
			strings.write_string(builder, "            anim:     .Animated,\n")

		case 1:  // Teleport: destination, target_room
			// obj.params[0-1] = dest x, y
			strings.write_string(builder, "            destination: Point { x = ")
			strings.write_string(builder, itoa(obj.params[0]))
			strings.write_string(builder, ", y = ")
			strings.write_string(builder, itoa(obj.params[1]))
			strings.write_string(builder, " },\n")
			strings.write_string(builder, "            target_room: .A,\n")

		case 2, 3:  // Platform: bounds, speed, dir
			strings.write_string(builder, "            bounds: Bounds { min = ")
			strings.write_string(builder, itoa(obj.params[0]))
			strings.write_string(builder, ", max = ")
			strings.write_string(builder, itoa(obj.params[1]))
			strings.write_string(builder, " },\n")
			strings.write_string(builder, "            speed:  ")
			strings.write_string(builder, itoa(obj.params[2]))
			strings.write_string(builder, ",\n")
			strings.write_string(builder, "            dir:    .Forward,\n")

		case 9:  // LevelComplete: show_exit
			strings.write_string(builder, "            show_exit: true,\n")
	}
}

/*
	Main Entry Point
*/

main :: proc() {
	args := os.args

	if len(args) < 3 {
		fmt.println("Usage: convert-mie-to-odin <input.mie> <output.odin>")
		os.exit(1)
	}

	input_path := args[1]
	output_path := args[2]

	fmt.printf("Converting: %s -> %s\n", input_path, output_path)

	// Parse MIE file
	mie_level, ok := parse_mie_file(input_path)
	if !ok {
		fmt.eprintln("Failed to parse MIE file")
		os.exit(1)
	}

	// Convert to Odin format
	odin_level := mie_to_odin(mie_level)

	// Write output
	_ = os.write_entire_file_from_bytes(output_path, transmute([]byte)odin_level)

	fmt.printf("Done! Generated %d objects\n", len(mie_level.objects))
}
