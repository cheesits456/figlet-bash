#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Static variables
declare -r FULL_WIDTH=0
declare -r FITTING=1
declare -r SMUSHING=2
declare -r CONTROLLED_SMUSHING=3

# ------------------------------------------------------------------------------
# Variables that will hold information about the fonts
declare -A figFonts
declare -A figDefaults=([font]="Standard" [fontPath]="./fonts")

# ------------------------------------------------------------------------------
# Functions

# This function takes in the oldLayout and newLayout data from the FIGfont
# header file and returns the layout information
getSmushingRules() {
	local oldLayout="$1" newLayout="$2"

	local rules val index len code
	local codes0=(16384 "vLayout" "$SMUSHING")
	local codes1=(8192 "vLayout" "$FITTING")
	local codes2=(4096 "vRule5" true)
	local codes3=(2048 "vRule4" true)
	local codes4=(1024 "vRule3" true)
	local codes5=(512 "vRule2" true)
	local codes6=(256 "vRule1" true)
	local codes7=(128 "hLayout" "$SMUSHING")
	local codes8=(64 "hLayout" "$FITTING")
	local codes9=(32 "hRule6" true)
	local codes10=(16 "hRule5" true)
	local codes11=(8 "hRule4" true)
	local codes12=(4 "hRule3" true)
	local codes13=(2 "hRule2" true)
	local codes14=(1 "hRule1" true)
	local codes=(
		codes0 codes1 codes2 codes3 codes4 codes5 codes6 codes7
		codes8 codes9 codes10 codes11 codes12 codes13 codes14
	)

	[ -z "$newLayout" ] && val="$oldLayout" || val="$newLayout"
	index=0
	len=${#codes[@]}
	while [ $index -lt "$len" ]; do
		declare -n code=${codes[index]}
		if [ ! "$val" -lt "${code[0]}" ]; then
			val=$((val - code[0]))
			[ -z "${rules[${code[1]}]}" ] &&
				rules[${code[1]}]=${code[2]} ||
				rules[${code[1]}]=${rules[${code[1]}]}
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
			if [ "${rules[hRule1]}" != 0 ] || [ "${rules[hRule2]}" != 0 ] ||
				[ "${rules[hRule3]}" != 0 ] || [ "${rules[hRule4]}" != 0 ] ||
				[ "${rules[hRule5]}" != 0 ] || [ "${rules[hRule6]}" != 0 ]; then
				rules[hLayout]="$CONTROLLED_SMUSHING"
			else
				rules[hLayout]="$SMUSHING"
			fi
		fi
	elif [ "${rules[hLayout]}" == "$SMUSHING" ]; then
		if [ "${rules[hRule1]}" != 0 ] || [ "${rules[hRule2]}" != 0 ] ||
			[ "${rules[hRule3]}" != 0 ] || [ "${rules[hRule4]}" != 0 ] ||
			[ "${rules[hRule5]}" != 0 ] || [ "${rules[hRule6]}" != 0 ]; then
			rules[hLayout]="$CONTROLLED_SMUSHING"
		fi
	fi

	if [ -z "${rules[vLayout]}" ]; then
		if [ "${rules[vRule1]}" != 0 ] || [ "${rules[vRule2]}" != 0 ] ||
			[ "${rules[vRule3]}" != 0 ] || [ "${rules[vRule4]}" != 0 ] ||
			[ "${rules[vRule5]}" != 0 ]; then
			rules[vLayout]="$CONTROLLED_SMUSHING"
		else
			rules[vLayout]="$FULL_WIDTH"
		fi
	elif [ "${rules[vLayout]}" == "$SMUSHING" ]; then
		if [ "${rules[vRule1]}" != 0 ] || [ "${rules[vRule2]}" != 0 ] ||
			[ "${rules[vRule3]}" != 0 ] || [ "${rules[vRule4]}" != 0 ] ||
			[ "${rules[vRule5]}" != 0 ]; then
			rules[vLayout]="$CONTROLLED_SMUSHING"
		fi
	fi

	getSmushingRules_return="$rules"
}

# The [vh]Rule[1-6]_Smush functions return the smushed character OR false if the
# two characters can't be smushed

# Rule 1: EQUAL CHARACTER SMUSHING (code value 1)
#     Two sub-characters are smushed into a single sub-character if they are the
#     same. This rule does not smush hardblanks (see rule 6 on hardblanks below)
hRule1_Smush() {
	local ch1="$1" ch2="$2" hardBlank="$3"
	hRule1_Smush_return=false

	if [ "$ch1" == "$ch2" ] && [ "$ch1" != "$hardBlank" ]; then
		hRule1_Smush_return="$ch1"
	fi
}

# Rule 2: UNDERSCORE SMUSHING (code value 2)
#     An underscore ("_") will be replaced by any of: "|", "/", "\", "[", "]",
#     "{", "}", "(", ")", "<", or ">"
hRule2_Smush() {
	local ch1="$1" ch2="$2"
	hRule2_Smush_return=false

	local rule2Str="|/\\[]{}()<>"
	if [ "$ch1" == "_" ]; then
		if [[ "$rule2Str" == *"$ch2"* ]]; then
			hRule2_Smush_return="$ch2"
		fi
	elif [ "$ch2" == "_" ]; then
		if [[ "$rule2Str" == *"$ch1"* ]]; then
			hRule2_Smush_return="$ch1"
		fi
	fi
}

# Rule 3: HIERARCHY SMUSHING (code value 4)
#     A hierarchy of six classes is used: "|", "/\", "[]", "{}", "()", and "<>".
#     When two smushing sub-characters are from different classes, the one from
#     the latter class will be used
hRule3_Smush() {
	local ch1="$1" ch2="$2"
	local temp
	hRule3_Smush_return=false

	local rule3Classes="| /\\ [] {} () <>"
	temp=${rule3Classes#*"$ch1"}
	local r3_pos1=$((${#rule3Classes} - ${#temp} - ${#ch1}))
	temp=${rule3Classes#*"$ch2"}
	local r3_pos2=$((${#rule3Classes} - ${#temp} - ${#ch2}))
	if [ "$r3_pos1" -gt -1 ] && [ "$r3_pos2" -gt -1 ]; then
		temp=$((r3pos1 - r3pos2))
		if [ "$r3_pos1" != "$r3_pos2" ] && [ "${temp/#-/}" != 1 ]; then
			temp=$((r3_pos1 > r3_pos2 ? r3_pos1 : r3_pos2))
			hRule3_Smush_return="${rule3Classes:temp:1}"
		fi
	fi
}

# Rule 4: OPPOSITE PAIR SMUSHING (code value 8)
#     Smushes opposing brackets ("[]" or "]["), braces ("{}" or "}{"), and
#     parentheses ("()" or ")(") together, replacing any such pair with a
#     vertical bar ("|")
hRule4_Smush() {
	local ch1="$1" ch2="$2"
	local temp
	hRule4_Smush_return=false

	local rule4Str="[] {} ()"
	temp=${rule4Str#*"$ch1"}
	local r4_pos1=$((${#rule4Str} - ${#temp} - ${#ch1}))
	temp=${rule4Str#*"$ch2"}
	local r4_pos2=$((${#rule4Str} - ${#temp} - ${#ch2}))
	if [ "$r4_pos1" -gt -1 ] && [ "$r4_pos2" -gt -1 ]; then
		temp=$((r4_pos1 - r4_pos2))
		if [ ! "${temp/#-/}" -gt 1 ]; then
			hRule4_Smush_return="|"
		fi
	fi
}

# Rule 5: BIG X SMUSHING (code value 16)
#     Smushes "/\" into "|", "\/" into "Y", and "><" into "X". Note that "<>" is
#     not smushed in any way by this rule. The name "BIG X" is historical;
#     originally all three pairs were smushed into "X"
hRule5_Smush() {
	local ch1="$1" ch2="$2"
	local temp
	hRule5_Smush_return=false

	local rule5Str="/\\ \\/ ><"
	declare -A rule5Hash=([0]="|" [3]="Y" [6]="X")
	temp=${rule5Str#*"$ch1"}
	local r5_pos1=$((${#rule5Str} - ${#temp} - ${#ch1}))
	temp=${rule5Str#*"$ch2"}
	local r5_pos2=$((${#rule5Str} - ${#temp} - ${#ch2}))
	if [ "$r5_pos1" -gt -1 ] && [ "$r5_pos2" -gt -1 ]; then
		if [ $((r5_pos2 - r5_pos1)) == 1 ]; then
			hRule5_Smush_return="${rule5Hash[$r5_pos1]}"
		fi
	fi
}

# Rule 6: HARDBLANK SMUSHING (code value 32)
#     Smushes two hardblanks together, replacing them with a single hardblank
#     (see "Hardblanks" below)
hRule6_Smush() {
	local ch1="$1" ch2="$2" hardBlank="$3"
	hRule6_Smush_return=false

	if [ "$ch1" == "$hardBlank" ] && [ "$ch2" == "$hardBlank" ]; then
		hRule6_Smush_return="$hardBlank"
	fi
}

# Rule 1: EQUAL CHARACTER SMUSHING (code value 256)
#     Same as horizontal smushing rule 1
vRule1_Smush() {
	local ch1="$1" ch2="$2"
	vRule1_Smush_return=false

	if [ "$ch1" == "$ch2" ]; then
		vRule1_Smush_return="$ch1"
	fi
}

# Rule 2: UNDERSCORE SMUSHING (code value 512)
#     Same as horizontal smushing rule 2
vRule2_Smush() {
	local ch1="$1" ch2="$2"
	vRule2_Smush_return=false

	local rule2Str="|/\\[]{}()<>"
	if [ "$ch1" == "_" ]; then
		if [[ "$rule2Str" == *"$ch2"* ]]; then
			vRule2_Smush_return="$ch2"
		fi
	elif [ "$ch2" == "_" ]; then
		if [[ "$rule2Str" == *"$ch1"* ]]; then
			vRule2_Smush_return="$ch1"
		fi
	fi
}

# Rule 3: HIERARCHY SMUSHING (code value 1024)
#     Same as horizontal smushing rule 3
vRule3_Smush() {
	local ch1="$1" ch2="$2"
	local temp
	vRule3_Smush_return=false

	local rule3Classes="| /\\ [] {} () <>"
	temp=${rule3Classes#*"$ch1"}
	local r3_pos1=$((${#rule3Classes} - ${#temp} - ${#ch1}))
	temp=${rule3Classes#*"$ch2"}
	local r3_pos2=$((${#rule3Classes} - ${#temp} - ${#ch2}))
	if [ "$r3_pos1" -gt -1 ] && [ "$r3_pos2" -gt -1 ]; then
		temp=$((r3pos1 - r3pos2))
		if [ "$r3_pos1" != "$r3_pos2" ] && [ "${temp/#-/}" != 1 ]; then
			temp=$((r3_pos1 > r3_pos2 ? r3_pos1 : r3_pos2))
			vRule3_Smush_return="${rule3Classes:temp:1}"
		fi
	fi
}

# Rule 4: HORIZONTAL LINE SMUSHING (code value 2048)
#     Smushes stacked pairs of "-" and "_", replacing them with a single "="
#     sub-character. It does not matter which is found above the other. Note
#     that vertical smushing rule 1 will smush IDENTICAL pairs of horizontal
#     lines, while this rule smushes horizontal lines consisting of DIFFERENT
#     sub-characters
vRule4_Smush() {
	local ch1="$1" ch2="$2"
	vRule4_Smush_return=false

	if [[ ("$ch1" == "-" && "$ch2" == "_") || ("$ch1" == "_" && "$ch2" == "-") ]]; then
		vRule4_Smush_return="="
	fi
}

# Rule 5: VERTICAL LINE SUPERSMUSHING (code value 2048)
#     This one rule is different from all others, in that it "supersmushes"
#     vertical lines consisting of several vertical bars ("|"). This creates the
#     illusion that FIGcharacters have slid vertically against each other.
#     Supersmushing continues until any sub-characters other than "|" would have
#     to be smushed. Supersmushing can produce impressive results, but it is
#     seldom possible, since other sub-characters would usually have to be
#     considered for smushing as soon as any such stacked vertical lines are
#     encountered
vRule5_Smush() {
	local ch1="$1" ch2="$2"
	vRule5_Smush_return=false

	if [ "$ch1" == "|" ] && [ "$ch2" == "|" ]; then
		vRule5_Smush_return="|"
	fi
}

# Universal smushing simply overrides the sub-character from the earlier
# FIGcharacter with the sub-character from the later FIGcharacter. This produces
# an "overlapping" effect with some FIGfonts, wherin the latter FIGcharacter may
# appear to be "in front"
uni_Smush() {
	local ch1="$1" ch2="$2" hardBlank="$3"

	if [ "$ch2" == " " ] || [ "$ch2" == "" ]; then
		uni_Smush_return="$ch1"
	elif [ "$ch2" == "$hardBlank" ] && [ "$ch1" != " " ]; then
		uni_Smush_return="$ch1"
	else
		uni_Smush_return="$ch2"
	fi
}

# ------------------------------------------------------------------------------
# Main vertical smush routines (excluding rules)

# txt1         - A line of text
# txt2         - A line of text
# fittingRules - FIGlet options
# About: Takes in two lines of text and returns one of the following:
# "valid" - These lines can be smushed together given the current smushing rules
# "end" - The lines can be smushed, but we're at a stopping point
# "invalid" - The two lines cannot be smushed together
canVerticalSmush() {
	local txt1="$1" txt2="$2" fittingRules="$3"
	local temp1 temp2

	if [ "${fittingRules[vLayout]}" == "$FULL_WIDTH" ]; then
		canVerticalSmush_return="invalid"
		return 0
	fi
	temp1="${#txt1}"
	temp2="${#txt2}"
	local ii len=$((temp1 < temp2 ? temp1 : temp2))
	local ch1 ch2 endSmush=false validSmush
	if [ "$len" == 0 ]; then
		canVerticalSmush_return="invalid"
		return 0
	fi

	for ((ii = 0; ii < len; ii++)); do
		ch1="${txt1:ii:1}"
		ch2="${txt2:ii:1}"
		if [ "$ch1" != " " ] && [ "$ch2" != " " ]; then
			if [ "${fittingRules[vLayout]}" == "$FITTING" ]; then
				canVerticalSmush_return="invalid"
				return 0
			elif [ "${fittingRules[vLayout]}" == "$SMUSHING" ]; then
				canVerticalSmush_return="end"
				return 0
			else
				vRule5_Smush "$ch1" "$ch2"
				if [ "$vRule5_Smush_return" != false ]; then
					continue
				fi
				validSmush=false
				if [ "${fittingRules[vRule1]}" != 0 ]; then
					vRule1_Smush "$ch1" "$ch2"
					validSmush="$vRule1_Smush_return"
				fi
				if [ "$validSmush" == false ] && [ "${fittingRules[vRule2]}" != 0 ]; then
					vRule2_Smush "$ch1" "$ch2"
					validSmush="$vRule2_Smush_return"
				fi
				if [ "$validSmush" == false ] && [ "${fittingRules[vRule3]}" != 0 ]; then
					vRule3_Smush "$ch1" "$ch2"
					validSmush="$vRule3_Smush_return"
				fi
				if [ "$validSmush" == false ] && [ "${fittingRules[vRule4]}" != 0 ]; then
					vRule4_Smush "$ch1" "$ch2"
					validSmush="$vRule4_Smush_return"
				fi
				endSmush=true
				if [ "$validSmush" == false ]; then
					canVerticalSmush_return="invalid"
					return 0
				fi
			fi
		fi
	done
	if [ "$endSmush" == true ]; then
		canVerticalSmush_return="end"
	else
		canVerticalSmush_return="valid"
	fi
}
