########################################################################################################################
######################################################### Info #########################################################

###################### Prerequisites ######################
#
# This makefile makes use of the following external binaries. Make sure they are installed and added to your PATH
# environment variable (they must be callable by just their name, without having to specify their full path).
#
#     > iverilog (for compiling verilog files)
#     > vvp      (for running simulations)
#     > gtkwave  (for viewing simualated waveforms)
#
# On Windows, these can be downloaded together from https://bleyer.org/icarus/. On Linux, check your
# package manager to see if they provide the above binaries ('iverilog' and 'vpp' are usually included in the same
# package). Alternatively, if 'iverilog' and 'vvp' are not provided by your package manager, they can be compiled
# directly from source, available at https://github.com/steveicarus/iverilog.
#
######################## Commands #########################
#
# This makefile has 5 commands: 'compile' (default), 'sim', 'simi', 'wave' and 'clean'.
#
#     > make
#     > make compile
#
#         Compiles the target testbench.
#
#     > make sim
#
#         Simulates the target testbench. If the testbench hasn't been compiled, it is automatically compiled first.
#         Simulation output is saved to a log file located at 'build/path/to/testbench.log'. The testbench should
#         include the following lines at the start of its 'initial' block in order to generate a dump file when
#         simulated:
#
#             $dumpfile(`DUMP_FILE);
#             $dumpvars();
#
#         The `DUMP_FILE macro is defined by the makefile to '"build/path/to/testbench.vcd"'.
#
#         Note that if the testbench doesn't call $finish(), you may have to force-exit the simulation (with Ctrl+C or
#         similar), which will cause it to fail and the dump file to be deleted; the log file will still be generated.
#         To run a testbench that doesn't call $finish(), run an interactive simulation with 'make simi'.
#
#     > make simi
#
#         Same as 'make sim' but runs the simulation in interactive mode, printing simulation output to the command
#         line. This allows more control over the simulation.
#
#     > make wave
#
#         Opens the simulation's dump file in GTKWave. If a dump file doesn't exist, the testbench is automatically
#         simulated first. Note that if the simulation doesn't generate a waveform file, this command will fail.
#
#     > make clean
#
#         Removes the build directory.
#
################# Specifying a testbench ##################
#
# The makefile allows for the project to contain multiple testbenches. You can specify which testbench to use when
# calling make:
#
#     > make TESTBENCH=path/to/testbench
#     > make sim TESTBENCH=path/to/testbench
#
# Alternatively, to save from writing it on the command line every time, create a file called 'config.mk' in the same
# directory as this makefile, and place the following line into it:
#
#     TESTBENCH ?= path/to/testbench
#
# This file can be changed whenever you want to work with a different testbench. The '?=' means you can override the
# value in this file by specifying the testbench on the command line, as explained above.
#
# Note that the path is relative to the source directory and should not contain the file's extension. For example, if
# you wanted to use a testbench located at 'source/counter/counter_tb.v', 'TESTBENCH' would be set equal to
# 'counter/counter_tb'.
#
##################### Including files #####################
#
# The testbench is expected to include any other files it uses, as they are not included automatically by this makefile.
#
# Include paths can either be relative to the current file's directory, or relative to the 'source' directory. For
# example, consider the following project structure:
#
#     source
#      |- module_a
#      |   |- main.v
#      |   |- child_a.v
#      |- module_b
#          |- child_b.v
#
# 'main.v' can include 'child_a.v' with either of the following, because they're in the same directory:
#
#     `include "child_a.v"
#     `include "module_a/child_a.v"
#
# but can only include 'child_b.v' with:
#
#     `include "module_b/child_b.v"
#
###########################################################

########################################################################################################################
############################################# Source and build directories #############################################

SOURCE_DIR := source
BUILD_DIR := build

########################################################################################################################
############################################## Config file and TESTBENCH ###############################################

# Config file name:
CONFIG_FILE := config.mk

# Include the config file if it exists:
include $(CONFIG_FILE)

# Check that TESTBENCH has a value:
ifeq ($(TESTBENCH),)
NULL :=
$(info Error: 'TESTBENCH' not specified.)
$(info )
$(info Please specify a value on the command line:)
$(info $(NULL)    make TESTBENCH=path/to/testbench)
$(info )
$(info Or place the following in a file named '$(CONFIG_FILE)':)
$(info $(NULL)    TESTBENCH ?= path/to/testbench)
$(info )
$(error )
endif

# Check that the TESTBENCH file exists:
ifeq ($(wildcard $(SOURCE_DIR)/$(TESTBENCH).v),)
$(error TESTBENCH '$(SOURCE_DIR)/$(TESTBENCH).v' not found)
endif

########################################################################################################################
################################################### Variables setup ####################################################

VERILOG_FILE := $(SOURCE_DIR)/$(TESTBENCH).v
COMPILED_FILE := $(BUILD_DIR)/$(TESTBENCH).vvp
DUMP_FILE := $(BUILD_DIR)/$(TESTBENCH).vcd
LOG_FILE := $(BUILD_DIR)/$(TESTBENCH).log

########################################################################################################################
################################################# OS-specific commands #################################################

ifeq ($(OS),Windows_NT)

# Windows:
# Commands that use PowerShell syntax must be called explicitly through PowerShell because Make doesn't properly support
# PowerShell (even through the SHELL variable). Commands that don't use any PowerShell stuff can be run directly.
SH := powershell -noprofile -command
echo                  = $(SH) "echo '$(1)'"
mkdir_parent          = $(SH) "$$null = new-item -type directory -force $(@D)"
compile              := iverilog -D 'DUMP_FILE="$(DUMP_FILE)"' -I $(SOURCE_DIR) -grelative-include -o $(COMPILED_FILE) $(VERILOG_FILE)
simulate             := $(SH) "vvp -n -l $(LOG_FILE) $(COMPILED_FILE) >$$null"
simulate_interactive := vvp -s -l $(LOG_FILE) $(COMPILED_FILE)
start_gtkwave        := $(SH) "start-process -nonewwindow -rso NUL -rse /dev/null gtkwave $(DUMP_FILE)"
rm_build             := $(SH) "if (test-path $(BUILD_DIR)) { remove-item -recurse $(BUILD_DIR) }"
rm_dump_file         := $(SH) "if (test-path $(DUMP_FILE)) { remove-item $(DUMP_FILE) }"
test_dump_file       := $(SH) " \
	if (!(test-path $(DUMP_FILE))) { \
		echo 'Error: Simluation did not generate dump file. Did you include the following in your testbench?'; \
		echo '    `$$dumpfile(``DUMP_FILE);'; \
		echo '    `$$dumpvars();'; \
		exit 1; \
		exit 1; \
	}"

else

# Linux:
echo                  = echo "$(1)"
mkdir_parent          = mkdir -p $(@D)
compile              := iverilog -D 'DUMP_FILE="$(DUMP_FILE)"' -I $(SOURCE_DIR) -grelative-include -o $(COMPILED_FILE) $(VERILOG_FILE)
simulate             := vvp -n -l $(LOG_FILE) $(COMPILED_FILE) >/dev/null
simulate_interactive := vvp -s -l $(LOG_FILE) $(COMPILED_FILE)
start_gtkwave        := nohup gtkwave $(DUMP_FILE) >/dev/null 2>&1 &
rm_build             := rm -rf "$(BUILD_DIR)"
rm_dump_file         := rm -f "$(DUMP_FILE)"
test_dump_file       := \
	if [ ! -f $(DUMP_FILE) ]; then \
		echo "Error: Simluation did not generate dump file. Did you include the following in your testbench?"; \
		echo "    \$$dumpfile(\`DUMP_FILE);"; \
		echo "    \$$dumpvars();"; \
		exit 1; \
	fi

endif

########################################################################################################################
################################################# Targets and recipes ##################################################

# Compile testbench:
.PHONY: compile
compile: $(COMPILED_FILE) ;

# Run simulation:
.PHONY: sim
sim: $(DUMP_FILE)

# Run simulation in interactive mode:
.PHONY: simi
simi: $(COMPILED_FILE)
	@ $(call echo,# Running interactive simulation:)
	$(call simulate_interactive)
	@ $(call echo)

# Open GTKWave with the simulated waveform:
.PHONY: wave
wave: $(DUMP_FILE)
	@ $(call echo,# Opening dump file in GTKWave:)
	$(call start_gtkwave)
	@ $(call echo)

# Clean the build directory:
.PHONY: clean
clean:
	@ $(call echo,# Removing build directory:)
	$(call rm_build)
	@ $(call echo)

# Compile testbench to generate vpp file:
$(COMPILED_FILE): $(VERILOG_FILE)
	@ $(call echo,# Compiling testbench:)
	@ $(call mkdir_parent)
	$(call compile)
	@ $(call echo)

# Run simulation to generate dump file and then check that it was generated:
$(DUMP_FILE): $(COMPILED_FILE)
	@ $(call echo,# Simulating testbench:)
	@ $(call rm_dump_file)
	$(call simulate)
	@ $(call test_dump_file)
	@ $(call echo)

########################################################################################################################
