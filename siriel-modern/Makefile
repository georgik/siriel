# Makefile for Siriel Modern Test Programs
# Uses FPC with FPCR fix for macOS ARM64

# Configuration
FPC = /Volumes/ssdt5/Users/georgik/projects/fpc/FPCSource/compiler/ppca64
RTL = /Volumes/ssdt5/Users/georgik/projects/fpc/FPCSource/rtl/units/aarch64-darwin
RAYLIB_SRC = /Volumes/ssdt5/Users/georgik/projects/raylib/src
RAYLIB_LIB = /Volumes/ssdt5/Users/georgik/projects/raylib/build/raylib/libraylib.a
SDK = /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
MACOS_VERSION = 13.0

# FPC flags
FPCFLAGS = -MObjfpc -Scghi -O2 -g -gl \
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
TESTS = test_menu test_resources test_api test_simple test_graphics test_aktiv35 test_geo test_blue_screen test_bitmap_render test_colors test_font test_gif_load test_gif_file test_block_debug test_background_load

# All targets
.PHONY: all clean run menu resources tests help

all: $(TARGET)

# Build all test programs
tests: $(TESTS)

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

# Run the test
run: $(TARGET)
	./$(TARGET)

# Clean build artifacts
clean:
	rm -f $(TESTS) *.o *.ppu

# Help
help:
	@echo "Siriel Modern Test Programs"
	@echo ""
	@echo "Configuration:"
	@echo "  FPC:    $(FPC)"
	@echo "  Raylib: $(RAYLIB_LIB)"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build menu test (default)"
	@echo "  tests      - Build all test programs"
	@echo "  menu       - Build and run menu test"
	@echo "  resources  - Build and run resources test"
	@echo "  run        - Run the default test"
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
	@echo ""
	@echo "Examples:"
	@echo "  make menu"
	@echo "  ./test_menu 5 screenshot.png"
	@echo "  make tests"
