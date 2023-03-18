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
