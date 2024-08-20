
-- FMIS01.MIE
level = {
    name = "START",
    start_position = { x = 88, y = 88 },
    sound_start = "ZPARA",
    messages = {
        {lang = 'EN', text = 'Collect all fruits.'},
        {lang = 'SK', text = 'Pozbieraj vĘetko ovocie.'}
    },
    objects = {
        {type = 'collectible', position = {x = 8, y = 17}, value = 10, name = 'pear', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 10, y = 17}, value = 10, name = 'pear', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 12, y = 17}, value = 10, name = 'pear', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 17, y = 29}, value = 50, name = 'coin', layer = 'A', other_data = {1, 3}, animated = true},
        {type = 'collectible', position = {x = 38, y = 29}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 40, y = 29}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 42, y = 29}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 67, y = 29}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 0, y = 37}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 2, y = 37}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 4, y = 37}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 6, y = 37}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 8, y = 37}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 0, y = 27}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false},
        {type = 'collectible', position = {x = 6, y = 15}, value = 5, name = 'cherry', layer = 'A', other_data = {1, 3}, animated = false}
    },
    map = {
        ".......................................",
        ".......................................",
        ".......................................",
        ".......................................",
        ".......................................",
        "...6...6...............................",
        ".......................................",
        ".....6.................................",
        ".......................................",
        "...6...6...............................",
        "...66666...............................",
        ".......................................",
        ".......................................",
        ".......................................",
        ".......................................",
        "FFFFI........JFLFFI....................",
        "....HFFFFFFFFG....HFFFFFFFFFFFFI.......",
        "...............................HI......",
        "....................................JFF",
        "...............JKFFFFFFFFFFFFFFFFFFFG..",
        "FFFFFFFFFFFFFFFG.......................",
        ".......................................",
        ".......................................",
        ".......................................",
        ".......................................",
        ".......................................",
        "......................................."
    }
}
