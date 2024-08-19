import os
import re

# Character baseline for map data transformation
baseline = 0x2E

# Directory paths
mie_dir = './fm'
lua_dir = './fm_lua'

# Create directory for Lua scripts
os.makedirs(lua_dir, exist_ok=True)

# Mapping for object types based on the first character in the brackets
object_type_map = {
    'Z': 'collectible',
    'X': 'trigger',
    'Y': 'special'
}

# Mapping for object indexes to static/animated objects
object_index_map = {
    1: 'pear',       # Example mapping
    2: 'cherry',
    6: 'coin',
    10: 'exit',      # Exit object from static objects
    # Add more object mappings here as needed
}

# Function to parse and convert MIE files to Lua
def convert_mie_to_lua(mie_file):
    with open(mie_file, 'r', encoding='cp852') as file:
        lines = file.readlines()

    level_name = ""
    start_position = { "x": 0, "y": 0 }
    sound_start = ""
    messages = []
    objects = []
    map_data = []
    in_map_section = False

    for line in lines:
        line = line.rstrip()

        if in_map_section:
            if line == "":
                in_map_section = False
            else:
                map_line = ''.join(chr(baseline + (ord(ch) - 0x0f)) for ch in line)
                map_data.append(map_line)
            continue

        if line.startswith("[MENO]"):
            level_name = line.split('=')[1].strip()
        elif line.startswith("[START]"):
            parts = line.split('=')[1].split(',')
            if len(parts) >= 2:
                start_position = { "x": int(parts[0]), "y": int(parts[1]) }
        elif line.startswith("[SNDSTART]"):
            sound_start = line.split('=')[1].strip()
        elif line.startswith("[MSG"):
            parts = line.split('=', 1)
            if len(parts) == 2:
                lang = "EN" if "~SLO~" not in parts[1] else "SK"
                text = parts[1].replace("~SLO~", "").strip()
                messages.append({ "lang": lang, "text": text })
        elif line.startswith("[MAPA]"):
            in_map_section = True
        elif re.match(r"\[\w+\]", line):
            command, attributes = line.split('=', 1)
            command = command.strip('[]')
            parts = attributes.split(',')
            if len(parts) >= 6:
                obj_type = object_type_map.get(command[0], "unknown")
                object_index = int(parts[0])

                # Translate object index into its corresponding name
                object_name = object_index_map.get(object_index, f"unknown_{object_index}")

                obj_properties = {
                    "type": obj_type,
                    "position": { "x": int(parts[1]), "y": int(parts[2]) },
                    "value": int(parts[5]),
                    "name": object_name,
                    "layer": command[-1],
                    "other_data": parts[3:5]
                }

                # Additional properties based on the type
                if obj_type == "special":
                    obj_properties["animated"] = command[2] == 'A'
                    obj_properties["dangerous"] = command[3] == 'S'

                objects.append(obj_properties)

    # Format messages and objects
    formatted_messages = ",\n        ".join([f"{{lang = '{msg['lang']}', text = '{msg['text']}'}}" for msg in messages])
    formatted_objects = ",\n        ".join([
        f"{{type = '{obj['type']}', position = {{x = {obj['position']['x']}, y = {obj['position']['y']}}}, value = {obj['value']}, name = '{obj['name']}', layer = '{obj['layer']}', other_data = {{{', '.join(obj['other_data'])}}}}}"
        for obj in objects
    ])
    formatted_map = ",\n        ".join([f'"{line}"' for line in map_data])

    lua_content = f"""
-- {os.path.basename(mie_file)}
level = {{
    name = "{level_name}",
    start_position = {{ x = {start_position['x']}, y = {start_position['y']} }},
    sound_start = "{sound_start}",
    messages = {{
        {formatted_messages}
    }},
    objects = {{
        {formatted_objects}
    }},
    map = {{
        {formatted_map}
    }}
}}
"""
    return lua_content

# Get the list of MIE files
mie_files = [f for f in os.listdir(mie_dir) if f.endswith('.MIE')]

# Convert each MIE file to Lua
for mie_file in mie_files:
    mie_path = os.path.join(mie_dir, mie_file)
    lua_content = convert_mie_to_lua(mie_path)
    lua_filename = mie_file.replace(".MIE", ".lua")
    lua_path = os.path.join(lua_dir, lua_filename)

    with open(lua_path, 'w', encoding='utf-8') as lua_file:
        lua_file.write(lua_content)

print("Conversion completed.")
