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

# Tcl script to extract the struct types from the C source files
# and spit them out translated into BE struct definitions.
#
# Give it the filenames on the command line:
#
#  ./extract_enums.tcl  [--enum-list <file>] *.h *.c > maps.inc
#
# If you specify the enum list file, the names found in it will
# be assumed to be map definitions. This file would normally be
# created by extract_enums.tcl so this script can recognise
# enums in the structures.
#
# It's not too smart. It needs the C source to look like this:
#
# typedef struct _process_table
# {
#   values...
# } PROCESS_TABLE;;
#
# Don't add newlines or comments or anything else which will
# confuse it.
#

# Review of the extras this picks up:
#
# If a source file is found to contain a block marked like this:
#
# BE:LITERAL:START
# ...
# BE:LITERAL:END
#
# then everything between the two marker line (but not including
# them) will be copied verbatim into the output BE defintion
# file.
#
#
# If a source file contains a line containing, anywhere in it,
#
# BE:ignore
#
# then that line is ignored from all processing and not copied to
# the output.
#
# 
# If a source file line contains:
#
# BE:PICKUPDEF
# 
# then the next line of the source file is expected to contain a
# #define XXX yyy macro definition. In this case the C macro is
# copied into the output as a BE definition. eg. set XXX yyy
#
#
# A pointer which points to the first entry of an array can have
# a comment which describes the number of objects in that array:
#
# SOMETYPE *ptr;   /* BE:USECOUNT 500 */


proc process_file { filename } {

    set current_struct ""
    set current_struct_entries [list]
    set literal_block 0
    set pickup_def 0

    if { [catch {set handle [open $filename "r"]} err] } {
        puts stderr "Unable to open file \"$filename\" for reading. Error \"$err\""
        exit -1
    }

    while { 1 } {

        if { [gets $handle line] == -1 } {
            break
        }

        if { [regexp {BE:ignore} $line] } {
            continue
        }

        if { [regexp {BE:LITERAL:START} $line] } {
            set literal_block 1
            continue
        }
        if { [regexp {BE:LITERAL:END} $line] } {
            set literal_block 0
            continue
        }
        if { $literal_block } {
            lappend current_struct_entries $line
        }

        if { [regexp {BE:PICKUPDEF} $line] } {
            set pickup_def 1
            continue
        }
	if { $pickup_def && [regexp {#define\s+(\w+)\s+(\w+)} $line unused name value] } {
	    puts "set $name $value"
	    set pickup_def 0
	    continue
	}

        # Look for start of typedef struct
        if { [regexp {^\s*typedef\s+struct\s+(_\w+)\s*$} $line unused struct_name] } {
            set current_struct $struct_name
            # puts "Found start of struct: $struct_name"
            continue
        }

        # Looking for:
        #
        # <closebrace> STRUCT_NAME;
        #
        # not:
        #
        # <closebrace>
        # STRUCT_NAME;
        #
        #

        # Look for end of typedef struct
        if { $current_struct ne "" && [regexp {^\s*\}\s*(\w+)\s*;$} $line unused struct_def_name] } {
            # puts "Found end of struct: $struct_name, defined as $struct_def_name"

            puts "def $struct_def_name struct \n{"
            foreach struct_entry $current_struct_entries {
                puts "  $struct_entry"
            }
            puts "}\n"

            set current_struct ""
            set current_struct_entries [list]
            continue
        }

        # Look for struct entries
        if { $current_struct ne "" } {

            if { [regexp {^\s*uint8_t\s*(\*)?\s*([^;]+);} $line unused pointer struct_entry_name] } {

		# uint8_t
		#
                if { [string trim $pointer] eq "" } {

                    # I was tempted by this:
                    #
                    #   lappend current_struct_entries "uint8_t open \"$struct_entry_name\""
                    #
                    # which feels more correct. But it adds a level into the BE defintions
                    # which needs expanding out. It feels clunky and harder to look at.
                    # So I went back to a standard decimal value.
                    # For the pointer, I went the opposite way, with something like:
                    #
                    #   lappend current_struct_entries "n16 ptr char dec unsigned \"$struct_entry_name\""
                    #
                    # but that didn't feel right either. So I made that a pointer to a
                    # uint*_t struct. It's hard to know quite what works for generic
                    # scenarios. After playing with it for several hours I decided there
                    # probably wasn't a right answer. :)
                    
                    lappend current_struct_entries "n8 dec unsigned \"$struct_entry_name\""
                } else {
                    lappend current_struct_entries "n16 ptr uint8_t \"$struct_entry_name\""
                }

            } elseif { [regexp {^\s*uint16_t\s*(\*)?\s*([^;]+);} $line unused pointer struct_entry_name] } {

		# uint16_t
		#
                if { [string trim $pointer] eq "" } {
                    lappend current_struct_entries "n16 dec unsigned \"$struct_entry_name\""
                } else {
                    lappend current_struct_entries "n16 ptr uint16_t \"$struct_entry_name\""
                }

            } elseif { [regexp {^\s*int8_t\s*(\*)?\s*([^;]+);} $line unused pointer struct_entry_name] } {

		# int8_t
		#
                if { [string trim $pointer] eq "" } {
                    lappend current_struct_entries "n8 dec signed \"$struct_entry_name\""
                } else {
                    lappend current_struct_entries "n16 ptr int8_t \"$struct_entry_name\""
                }

            } elseif { [regexp {^\s*int16_t\s*(\*)?\s*([^;]+);} $line unused pointer struct_entry_name] } {

		# int16_t
		#
                if { [string trim $pointer] eq "" } {
                    lappend current_struct_entries "n16 dec signed \"$struct_entry_name\""
                } else {
                    lappend current_struct_entries "n16 ptr int16_t \"$struct_entry_name\""
                }

            } elseif { [regexp {^\s*struct\s+(\w+)\*\s+([^;]+);} $line unused struct_ptr struct_entry_name] } {

		# struct something* ptr_var
		#
                lappend current_struct_entries "n16 ptr $struct_ptr \"$struct_entry_name\""
                    
	    } elseif { [regexp {^\s*\w+\s+\(\*(.+)\)\(.*\);$} $line unused func_ptr_name] } {

		# function ptr, just the name
		#
                lappend current_struct_entries "n16 sym ptr $func_ptr_name \"fn ptr\""

	    } elseif { [regexp {^\s*(\w+)\s+([^;]+);} $line unused possible_enum struct_entry_name] &&
  		       [lsearch -exact $::known_enums $possible_enum] != -1 } {

		# typedef'ed enum
		#
		lappend current_struct_entries "n8 map $possible_enum open \"$struct_entry_name\""

	    } elseif { [regexp {^\s*(\w+)\s*\*\s*([^;]+);\s*(/\*.*\*/)?} $line unused type struct_entry_name comment] } {

		# Pointer to something:
		#
		#   SOMETYPE * ptr;
		#
		# If the thing being pointed to is actually an array, the size of the array can be
		# specified with a comment:
		#
		#   SOMETYPE * ptr; /* BE:USECOUNT 500 */
		#
		set use_count -1
		regexp {BE:USECOUNT\s+(\w+)} $comment unused use_count

		if { $use_count == -1 } {
		    lappend current_struct_entries "n16 ptr $type open \"$struct_entry_name\""
		} else {
		    lappend current_struct_entries "$use_count $type open \"$struct_entry_name\""
		}

	    } elseif { [regexp {^\s*(\w+)\s+([^;]+);} $line unused type struct_entry_name] } {

		# Something simple:
		#
		#   SOMETYPE val;
		#
		lappend current_struct_entries "1 $type open \"$struct_entry_name\""

	    } else {
                # puts "Unable to grok this: $line"
            }


        }
        

        # puts ">>>>>>> $line"
    }

    close $handle
}

set usage "extract_structs.tcl --enum-list <filename> <files>"
array set opts [list "--enum-list" ""]
if { [llength $argv] >= 2 && [lindex $argv 0] eq "--enum-list" } {
    set opts(--enum-list) [lindex $argv 1]
    set argv [lrange $argv 2 end]
} else {
    puts stderr $usage
}

set known_enums [list]
set handle [open $::opts(--enum-list) "r"]
while { [gets $handle line] >= 0 } {
    lappend known_enums $line
}
close $handle

foreach filename $argv {
    process_file $filename
}