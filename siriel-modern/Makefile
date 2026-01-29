# Makefile for Siriel Modern Test Programs
# Uses FPC with FPCR fix for macOS ARM64

# Configuration
FPC = /Volumes/ssdt5/Users/georgik/projects/fpc/FPCSource/compiler/ppca64
RTL = /Volumes/ssdt5/Users/georgik/projects/fpc/FPCSource/rtl/units/aarch64-darwin
RAYLIB_SRC = /Volumes/ssdt5/Users/georgik/projects/raylib/src
RAYLIB_LIB = /Volumes/ssdt5/Users/georgik/projects/raylib/build/raylib/libraylib.a
SDK = /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
MACOS_VERSION = 13.0

# FPC flags - PRODUCTION BUILD (no heap tracing for clean output)
FPCFLAGS = -MObjfpc -Scghi -O- -g -gl -Ci -Co -Ct \
           -WM$(MACOS_VERSION) \
           -Fu$(RTL) \
           -XR$(SDK) \
           -I$(RAYLIB_SRC) \
           -k$(RAYLIB_LIB) \
           -k-framework -kAppKit \
           -k-framework -kCocoa \
           -k-framework -kIOKit \
           -k-framework -kCoreVideo \
           -k-framework -kOpenGL

# FPC flags - DEBUG BUILD with heap tracing (for development)
FPCFLAGS_DEBUG = -MObjfpc -Scghi -O- -g -gl -gh -Ci -Co -Ct \
           -WM$(MACOS_VERSION) \
           -Fu$(RTL) \
           -XR$(SDK) \
           -I$(RAYLIB_SRC) \
           -k$(RAYLIB_LIB) \
           -k-framework -kAppKit \
           -k-framework -kCocoa \
           -k-framework -kIOKit \
           -k-framework -kCoreVideo \
           -k-framework -kOpenGL

# Default target
TARGET = test_menu

# All test programs
TESTS = test_menu test_resources test_api test_simple test_graphics test_aktiv35 test_geo test_blue_screen test_bitmap_render test_colors test_font test_gif_load test_gif_file test_block_debug test_background_load test_palette test_palette_diagnostic test_wav_header test_gzal_display test_tile_display test_spritesheet test_animation test_menu_decor test_modern_mem test_keyboard test_aktiv35_init test_animing test_jxmenu test_load235 test_load_predmet2 test_minimal_game test_phase4_complete test_grid_debug

# Main game executable
SIRIEL = siriel

# All targets
.PHONY: all clean run menu resources tests game siriel debug debug-interactive help memcheck

all: $(TARGET)

# Build all test programs
tests: $(TESTS)

# Build and run main game
game: siriel
	./siriel

# Build siriel executable (production - no heap trace output)
siriel: siriel.pas
	$(FPC) $(FPCFLAGS) siriel.pas

# Build siriel with memory leak detection (for development)
memcheck: siriel.pas
	@echo "Building with heap tracing enabled..."
	$(FPC) $(FPCFLAGS_DEBUG) siriel.pas
	@echo "Heap tracing enabled - will show memory allocation report"

# Run siriel under LLDB debugger (batch mode - auto-captures crashes)
debug: siriel
	./debug_siriel.sh

# Run siriel under LLDB debugger (interactive - for debugging freezes)
# Press Ctrl+C when it freezes, then type 'bt' to see stack
debug-interactive: siriel
	@echo "Starting interactive LLDB session..."
	@echo "Type 'run <args>' to start, Ctrl+C to interrupt, 'bt' for stack trace"
	./debug_interactive.sh

# Compile and run menu test
menu: test_menu
	./test_menu

# Compile and run resources test
resources: test_resources
	./test_resources

# Compile test programs
test_menu: test_menu.pas
	$(FPC) $(FPCFLAGS) test_menu.pas

test_resources: test_resources.pas
	$(FPC) $(FPCFLAGS) test_resources.pas

test_api: test_api.pas
	$(FPC) $(FPCFLAGS) test_api.pas

test_simple: test_simple.pas
	$(FPC) $(FPCFLAGS) test_simple.pas

test_graphics: test_graphics.pas
	$(FPC) $(FPCFLAGS) test_graphics.pas

test_aktiv35: test_aktiv35.pas
	$(FPC) $(FPCFLAGS) test_aktiv35.pas

test_geo: test_geo.pas
	$(FPC) $(FPCFLAGS) test_geo.pas

test_blue_screen: test_blue_screen.pas
	$(FPC) $(FPCFLAGS) test_blue_screen.pas

test_bitmap_render: test_bitmap_render.pas
	$(FPC) $(FPCFLAGS) test_bitmap_render.pas

test_colors: test_colors.pas
	$(FPC) $(FPCFLAGS) test_colors.pas

test_font: test_font.pas
	$(FPC) $(FPCFLAGS) test_font.pas

test_gif_load: test_gif_load.pas
	$(FPC) $(FPCFLAGS) test_gif_load.pas

test_block_read: test_block_read.pas
	$(FPC) $(FPCFLAGS) test_block_read.pas

test_manual_logo: test_manual_logo.pas
	$(FPC) $(FPCFLAGS) test_manual_logo.pas

test_gif_file: test_gif_file.pas
	$(FPC) $(FPCFLAGS) test_gif_file.pas

test_block_debug: test_block_debug.pas
	$(FPC) $(FPCFLAGS) test_block_debug.pas

test_background_load: test_background_load.pas
	$(FPC) $(FPCFLAGS) test_background_load.pas

test_background_g: test_background_g.pas
	$(FPC) $(FPCFLAGS) test_background_g.pas

test_palette: test_palette.pas
	$(FPC) $(FPCFLAGS) test_palette.pas

test_raw_palette: test_raw_palette.pas
	$(FPC) $(FPCFLAGS) test_raw_palette.pas

test_palette_diagnostic: test_palette_diagnostic.pas
	$(FPC) $(FPCFLAGS) test_palette_diagnostic.pas

test_sound: test_sound.pas
	$(FPC) $(FPCFLAGS) test_sound.pas

test_sound_simple: test_sound_simple.pas
	$(FPC) $(FPCFLAGS) test_sound_simple.pas

test_sound_wav: test_sound_wav.pas
	$(FPC) $(FPCFLAGS) test_sound_wav.pas

test_sound_dat: test_sound_dat.pas
	$(FPC) $(FPCFLAGS) test_sound_dat.pas

test_wav_header: test_wav_header.pas
	$(FPC) $(FPCFLAGS) test_wav_header.pas

test_play_wav: test_play_wav.pas
	$(FPC) $(FPCFLAGS) test_play_wav.pas

test_play_dat: test_play_dat.pas
	$(FPC) $(FPCFLAGS) test_play_dat.pas

test_gzal_display: test_gzal_display.pas
	$(FPC) $(FPCFLAGS) test_gzal_display.pas

test_extract_tile: test_extract_tile.pas
	$(FPC) $(FPCFLAGS) test_extract_tile.pas

test_red_tile: test_red_tile.pas
	$(FPC) $(FPCFLAGS) test_red_tile.pas

test_tile_display: test_tile_display.pas
	$(FPC) $(FPCFLAGS) test_tile_display.pas

test_spritesheet: test_spritesheet.pas
	$(FPC) $(FPCFLAGS) test_spritesheet.pas

test_animation: test_animation.pas
	$(FPC) $(FPCFLAGS) test_animation.pas

test_menu_decor: test_menu_decor.pas
	$(FPC) $(FPCFLAGS) test_menu_decor.pas

test_modern_mem: test_modern_mem.pas
	$(FPC) $(FPCFLAGS) test_modern_mem.pas

test_keyboard: test_keyboard.pas
	$(FPC) $(FPCFLAGS) test_keyboard.pas

test_aktiv35_init: test_aktiv35_init.pas
	$(FPC) $(FPCFLAGS) test_aktiv35_init.pas

test_animing: test_animing.pas
	$(FPC) $(FPCFLAGS) test_animing.pas

test_jxmenu: test_jxmenu.pas
	$(FPC) $(FPCFLAGS) test_jxmenu.pas

test_load235: test_load235.pas
	$(FPC) $(FPCFLAGS) test_load235.pas

test_load_predmet2: test_load_predmet2.pas
	$(FPC) $(FPCFLAGS) test_load_predmet2.pas

test_minimal_game: test_minimal_game.pas
	$(FPC) $(FPCFLAGS) test_minimal_game.pas

test_phase4_complete: test_phase4_complete.pas
	$(FPC) $(FPCFLAGS) test_phase4_complete.pas

test_grid_debug: test_grid_debug.pas
	$(FPC) $(FPCFLAGS) test_grid_debug.pas

siriel_demo: siriel_demo.pas
	$(FPC) $(FPCFLAGS) siriel_demo.pas

# Run the test
run: $(TARGET)
	./$(TARGET)

# Clean build artifacts
clean:
	rm -f $(TESTS) siriel main *.o *.ppu

# Help
help:
	@echo "Siriel Modern - Game Engine"
	@echo ""
	@echo "Configuration:"
	@echo "  FPC:    $(FPC)"
	@echo "  Raylib: $(RAYLIB_LIB)"
	@echo "  Build: Production mode (symbols -g -gl, no heap tracing)"
	@echo ""
	@echo "Main Targets:"
	@echo "  siriel   - Build main game (production - clean output)"
	@echo "  game     - Build and run main game"
	@echo "  memcheck - Build with heap tracing for memory leak detection"
	@echo ""
	@echo "Debug Targets:"
	@echo "  debug            - Run under LLDB (batch mode, auto-captures crashes)"
	@echo "  debug-interactive - Run under LLDB (interactive, press Ctrl+C if frozen)"
	@echo "  memcheck         - Build with heap tracing to find memory leaks"
	@echo ""
	@echo "Test Targets:"
	@echo "  all        - Build menu test (default)"
	@echo "  tests      - Build all test programs"
	@echo "  menu       - Build and run menu test"
	@echo "  resources  - Build and run resources test"
	@echo "  run        - Run the default test"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean      - Remove build artifacts"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Available Tests:"
	@echo "  test_menu      - Initial game menu with screenshot support"
	@echo "  test_resources - Resource loading system"
	@echo "  test_api       - Raylib API tests"
	@echo "  test_simple    - Simple rendering tests"
	@echo "  test_graphics  - Graphics primitives"
	@echo "  test_aktiv35   - Game engine tests"
	@echo "  test_geo       - Geometry system tests"
	@echo "  test_phase4_complete - Complete game loop test"
	@echo ""
	@echo "Game Usage:"
	@echo "  make game"
	@echo "  ./siriel"
	@echo "  ./siriel --level-file 1.MIE"
	@echo ""
	@echo "Debugging:"
	@echo "  ./debug_siriel.sh --level-file 1.MIE --duration 1"
	@echo "  ./debug_interactive.sh --level-file 1.MIE"
	@echo "    (If app freezes, press Ctrl+C, then type 'bt')"
	@echo ""
	@echo "Examples:"
	@echo "  make siriel"
	@echo "  make game"
	@echo "  make debug"
	@echo "  ./siriel --level-file 1.MIE"

	@echo ""
	@echo "Note: Production builds have heap tracing disabled to avoid confusing"
	@echo "      FPC ParamStr cache warnings. Use 'make memcheck' to enable"
	@echo "      heap tracing for development."
	@echo ""
