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
#  ./extract_enums.tcl *.c > statics.inc
#
# It's not too smart.
#

# Maybe I've done this wrong. Perhaps I should start with the symbols,
# go and find what they are, and build the include file from there?

proc process_file { filename } {

    if { [catch {set handle [open $filename "r"]} err] } {
        puts stderr "Unable to open file \"$filename\" for reading. Error \"$err\""
        exit -1
    }

    while { 1 } {

        if { [gets $handle line] == -1 } {
            break
        }

        # Anything with a pointer in is currently too hard.
        # TODO
        #
        if { [string first {*} $line] != -1 } {
            continue
        }
        if { [string first {GLOBAL} $line] != -1 } {
            continue
        }
        if { [string first {MAX_FOPEN} $line] != -1 } {
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

        if { [regexp {^((static|extern|const|volatile)\s+)*(struct\s+)?(signed|unsigned\s+)?([0-9a-zA-z\*]+)\s+([_0-9a-zA-Z\*\(]+)} $line \
                     unused1 unused2 unused3 \
                     struct \
                     signedness \
                     type label] } {
            if { [string first "(" $label] != -1 } {
                # Line containing function declaration
                #
                continue
            }
#            puts ">>>>>>> $line"
#            puts ">>>>>>> $struct $signedness $type $label\n"
#            puts "\$ifndef _$label"
            if { [string first {GLOBAL} $label] != -1 } {
puts "$filename $line"
exit -1
            }
            puts "at _$label"
            puts "1 $type open \"$label\""
#            puts "\$endif\n"
        }

        # puts ">>>>>>> $line"
    }

    close $handle
}

set usage "extract_statics.tcl <files>"
if { [llength $argv] < 1 } {
    puts stderr $usage
    exit -1
}

foreach filename $argv {
    process_file $filename
}