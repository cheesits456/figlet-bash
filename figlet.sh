#!/usr/bin/env bash

# ---------------------------------------------------------------------
# Static variables
declare -r FULL_WIDTH=0
declare -r FITTING=1
declare -r SMUSHING=2
declare -r CONTROLLED_SMUSHING=3

# ---------------------------------------------------------------------
# Variables that will hold information about the fonts
declare -A figFonts
declare -A figDefaults=( [font]="Standard" [fontPath]="./fonts" )

# ---------------------------------------------------------------------
# Functions

# This function takes in the oldLayout and newLayout data from the FIGfont
# header file and returns the layout information
getSmushingRules() {
	local oldLayout="$1" newLayout="$2"

	local rules val index len code
	local codes0=( 16384 "vLayout" "$SMUSHING" )
	local codes1=( 8192 "vLayout" "$FITTING" )
	local codes2=( 4096 "vRule5" true )
	local codes3=( 2048 "vRule4" true )
	local codes4=( 1024 "vRule3" true )
	local codes5=( 512 "vRule2" true )
	local codes6=( 256 "vRule1" true )
	local codes7=( 128 "hLayout" "$SMUSHING" )
	local codes8=( 64 "hLayout" "$FITTING" )
	local codes9=( 32 "hRule6" true )
	local codes10=( 16 "hRule5" true )
	local codes11=( 8 "hRule4" true )
	local codes12=( 4 "hRule3" true )
	local codes13=( 2 "hRule2" true )
	local codes14=( 1 "hRule1" true )
	local codes=( codes0 codes1 codes2 codes3 codes4 codes5 codes6 codes7 codes8 codes9 codes10 codes11 codes12 codes13 codes14 )

	[ -z "$newLayout" ] && val="$oldLayout" || val="$newLayout"
	index=0
	len=${#codes[@]}
	while [ $index -lt "$len" ]; do
		declare -n code=${codes[index]}
		if [ ! "$val" -lt "${code[0]}" ]; then
			val=$((val - code[0]))
			[ -z "${rules[${code[1]}]}" ] && rules[${code[1]}]=${code[2]} || rules[${code[1]}]=${rules[${code[1]}]}
		elif [ "${code[1]}" != "vLayout" ] && [ "${code[1]}" != "hLayout" ]; then
			rules[${code[1]}]=false
		fi
		index=$((index + 1))
	done

	if [ -z "${rules[hLayout]}" ]; then
		if [ "$oldLayout" == 0 ]; then
			rules[hLayout]="$FITTING"
		elif [ "$oldLayout" == -1 ]; then
			rules[hLayout]="$FULL_WIDTH"
		else
			if [ "${rules[hRule1]}" != 0 ] || [ "${rules[hRule2]}" != 0 ] || [ "${rules[hRule3]}" != 0 ] || [ "${rules[hRule4]}" != 0 ] || [ "${rules[hRule5]}" != 0 ] || [ "${rules[hRule6]}" != 0 ]; then
				rules[hLayout]="$CONTROLLED_SMUSHING"
			else
				rules[hLayout]="$SMUSHING"
			fi
		fi
	elif [ "${rules[hLayout]}" == "$SMUSHING" ]; then
		if [ "${rules[hRule1]}" != 0 ] || [ "${rules[hRule2]}" != 0 ] || [ "${rules[hRule3]}" != 0 ] || [ "${rules[hRule4]}" != 0 ] || [ "${rules[hRule5]}" != 0 ] || [ "${rules[hRule6]}" != 0 ]; then
			rules[hLayout]="$CONTROLLED_SMUSHING"
		fi
	fi

	if [ -z "${rules[vLayout]}" ]; then
		if [ "${rules[vRule1]}" != 0 ] || [ "${rules[vRule2]}" != 0 ] || [ "${rules[vRule3]}" != 0 ] || [ "${rules[vRule4]}" != 0 ] || [ "${rules[vRule5]}" != 0 ]; then
			rules[vLayout]="$CONTROLLED_SMUSHING"
		else
			rules[vLayout]="$FULL_WIDTH"
		fi
	elif [ "${rules[vLayout]}" == "$SMUSHING" ]; then
		if [ "${rules[vRule1]}" != 0 ] || [ "${rules[vRule2]}" != 0 ] || [ "${rules[vRule3]}" != 0 ] || [ "${rules[vRule4]}" != 0 ] || [ "${rules[vRule5]}" != 0 ]; then
			rules[vLayout]="$CONTROLLED_SMUSHING"
		fi
	fi

	getSmushingRules_return="$rules"
}

# Rule 1: EQUAL CHARACTER SMUSHING (code value 1)
#     Two sub-characters are smushed into a single sub-character if they are the
#     same. This rule does not smush hardblanks (see rule 6 on hardblanks below)
hRule1_Smush() {
	local ch1="$1" ch2="$2" hardBlank="$3"

	if [ "$ch1" == "$ch2" ] && [ "$ch1" != "$hardBlank" ]; then
		hRule1_Smush_return="$ch1"
	else
		hRule1_Smush_return=false
	fi
}

# Rule 2: UNDERSCORE SMUSHING (code value 2)
#     An underscore ("_") will be replaced by any of: "|", "/", "\", "[", "]",
#     "{", "}", "(", ")", "<", or ">"
hRule2_Smush() {
	local ch1="$1" ch2="$2"

	local rule2Str="|/\\[]{}()<>"
	if [ "$ch1" == "_" ]; then
		if [[ "$rule2Str" == *"$ch2"* ]]; then
			hRule2_Smush_return="$ch2"
		fi
	elif [ "$ch2" == "_" ]; then
		if [[ "$rule2Str" == *"$ch1"* ]]; then
			hRule2_Smush_return="$ch1"
		fi
	else
		hRule2_Smush_return=false
	fi
}