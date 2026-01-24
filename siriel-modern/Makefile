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

# All targets
.PHONY: all clean run menu resources help

all: $(TARGET)

# Compile and run menu test
menu: test_menu
	./test_menu

# Compile and run resources test  
resources: test_resources
	./test_resources

# Compile menu test
test_menu: test_menu.pas
	$(FPC) $(FPCFLAGS) test_menu.pas

# Compile resources test
test_resources: test_resources.pas
	$(FPC) $(FPCFLAGS) test_resources.pas

# Run the test
run: $(TARGET)
	./$(TARGET)

# Clean build artifacts
clean:
	rm -f test_menu test_resources *.o *.ppu

# Help
help:
	@echo "Siriel Modern Test Programs"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build menu test (default)"
	@echo "  menu       - Build and run menu test"
	@echo "  resources  - Build and run resources test"
	@echo "  run        - Run the default test"
	@echo "  clean      - Remove build artifacts"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Tests:"
	@echo "  test_menu      - Initial game menu"
	@echo "  test_resources - Resource loading system"
