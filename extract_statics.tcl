#!/usr/bin/tclsh

# zxspectrum_be, a package to support use of Andy Key's BE
# utility on the ZX Spectrum
# Copyright (C) 2018 Derek Fountain
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


# Tcl script to extract the statically declared variables from the C source files
# and spit them out translated into BE struct definitions.
#
# Give it the filenames on the command line:
#
#  ./extract_enums.tcl --symbols-file <file> *.cpre > statics.inc
#
# The symbols file is the output of the generate_smybols.pl script. The
# cpre files are the output of the C preprocessor for each C file. I can't
# use th C files themselves because comments and conditional compilation
# tend to hide what should and shouldn't be considered.
#

################################################################################
# On reflection I'm not sure this is a good idea. It does kinda work, but since
# it can't tell an array size, almost everything is shown in a limited way.
# My gut feeling is that this isn't a useful enough idea to pursue and that
# there's going to be a better way.
################################################################################


proc process_file { filename } {

    if { [catch {set handle [open $filename "r"]} err] } {
        puts stderr "Unable to open file \"$filename\" for reading. Error \"$err\""
        exit -1
    }

    while { 1 } {

        if { [gets $handle line] == -1 } {
            break
        }

        # Anything with a pointer to a pointer is currently too hard.
        #
        if { [string first {**} $line] != -1 } {
            continue
        }

        # Spot and ignore pre processor comments
        #
        if { [string first {#} $line] == 0 } {
            continue
        }

        # Anything with a double underscore at the start is too complicated
        #
        if { [string first {__} $line] == 0 } {
            continue
        }

        # Spot and ignore typedefs
        #
        if { [regexp {^(typedef)} $line] } {
            continue
        }
              
        # This picks out function declarations like, as a complex example:
        #
        # extern unsigned long intrinsic_swap_endian_32_fastcall(unsigned long n)
        #
        # I can't quite get away with just spotting the open bracket because
        # those might appear in structure content definition lines
        #     
        if { [regexp {^extern\s+(struct\s+|signed\s+|unsigned\s+)?[_0-9a-zA-Z\*]+\s+[_0-9a-zA-Z\*]+\s*\(} $line] } {
            continue
        }  

        # Spot and ignore structure declarations like this:
        #
        # struct r_Ival8
        # {
        #   uint8_t coord;
        #   uint8_t width;
        # };
        #
        # Catch those with the open brace on the first line too:
        #
        # struct r_Ival8 {
        #   uint8_t coord;
        #   uint8_t width;
        # };
        #
        # Since it's easy to do here, pick out forward declarations too:
        #
        # struct r_Ival8;
        #
        if { [regexp {^struct\s+\w+(\s*(\{|\;))?\s*$} $line] } {
            continue
        }
	      
	# OK, looks interesting. Parse it as a line defining a static value in the C.
	# If this regex says yes it should go into the output BE defintions.
	#
        if { [regexp {^((static|extern|const|volatile)\s+)*(struct\s+)?(signed|unsigned\s+)?([0-9a-zA-z]+)\s+(\*\s*)?([_0-9a-zA-Z\(]+)(\[(\d*)\])?} $line \
                     unused1 unused2 unused3 \
                     struct \
                     signedness \
                     type pointer label is_array array_size] } {

            # Already seen? This happens to externs which are declared in lots of headers
            #
	    if { [dict exists $::processed_symbols "_$label"] } {
		continue
	    }

            # If there's a bracket it's a line containing function declaration
            #
            if { [string first "(" $label] != -1 } {
                continue
            }

            # Line containing label which isn't in the symbols table. BE
            # won't be able to identify its address. The compiler chucks a
            # few weird things in
            #
	    if { ![dict exists $::known_symbols "_$label"] } {
		continue
	    }

	    # If the regex found a [] or [nn] at the end, it's an array. If the nn isn't
	    # provided in the C code there's no easy way to work out the size of the
	    # array. I make it a fixed value in the hope that's useful.
	    #
	    set output_array_size 1
	    if { $is_array ne "" } {
		set output_array_size 8
		if { $array_size ne "" } {
		    set output_array_size $array_size
		}
	    }

            # If the * was found it's a pointer, so add in the "ptr" bit to the BE def
            #
            set be_ptr ""
            if { [string trim $pointer] ne "" } {
                set be_ptr "n16 ptr "
            }


	    # Finally! It's of interest. Stick it in the output.
	    #
            puts "at _$label"
            puts "$output_array_size $be_ptr $type open \"$label\""

	    # Mark it as processed
	    #
	    dict set ::processed_symbols "_$label" 1
        }

        # puts ">>>>>>> $line"
    }

    close $handle
}

set usage "extract_statics.tcl --symbols-file <filename> <files>"
array set opts [list "--symbols-file" ""]
if { [llength $argv] >= 2 && [lindex $argv 0] eq "--symbols-file" } {
    set opts(--symbols-file) [lindex $argv 1]
    set argv [lrange $argv 2 end]
} else {
    puts stderr $usage
}

if { [llength $argv] < 1 } {
    puts stderr $usage
    exit -1
}

# Known symbols come from the symbols list generated by the compiler
#
set known_symbols [dict create]
set handle [open $::opts(--symbols-file) "r"]
while { [gets $handle line] >= 0 } {
    if { [regexp {^(\w+)\s+(\w+)} $line unused symbol address] } {
	dict append known_symbols $symbol $address
    }
}
close $handle


puts "def GENERATED struct\n{"

# Processed symbols are the ones this script has already seen and processed
#
set processed_symbols [dict create]

foreach filename $argv {
    process_file $filename
}

puts "\n}"
