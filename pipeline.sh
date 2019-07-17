#!/bin/bash -e


# module loads for programs
IMOD_VERSION="4.9.11"
IMOD_LOAD="imod/${IMOD_VERSION}"
EMAN2_VERSION="20190603"
EMAN2_LOAD="eman2/${EMAN2_VERSION}"
MOTIONCOR2_VERSION="1.2.2"
#MOTIONCOR2_LOAD="motioncor2-1.1.0-gcc-4.8.5-zhoi3ww"
MOTIONCOR2_LOAD="motioncor2/${MOTIONCOR2_VERSION}"
CTFFIND4_VERSION="4.1.13"
#CTFFIND4_LOAD="ctffind4-4.1.10-intel-17.0.4-rhn26cm"
CTFFIND4_LOAD="ctffind/${CTFFIND4_VERSION}"
RELION_VERSION="3.0.4"
RELION_LOAD="relion/${RELION_VERSION}"

# GENERATE
# force redo of all files
MODE=${MODE:-spa} # spa | tomo
TASK=${TASK:-all}
FORCE=${FORCE:-0}

# SCOPE PARAMS
CS=${CS:-2.7}
KV=${KV:-300}
APIX=${APIX}
SUPERRES=${SUPERRES:-0}
PHASE_PLATE=${PHASE_PLATE:-0}

# MOTIONCOR2 PARAMETERS
BFT=${BFT:-150}
FMDOSE=${FMDOSE}
PATCH=${PATCH:-5 5}
THROW=${THROW:-0}
TRUNC=${TRUNC:-0}
ITER=${ITER:-10}
TOL=${TOL:-0.5}
OUTSTACK=${OUTSTACK:-0}
INFMMOTION=${INFMMOTION:-1}
GPU=${GPU:-0}

# PICKING
PARTICLE_SIZE=${PARTICLE_SIZE:-150}
PARTICLE_SIZE_MIN=${PARTICLE_SIZE_MIN:-$(echo $PARTICLE_SIZE*0.8 | bc -l)}
PARTICLE_SIZE_MAX=${PARTICLE_SIZE_MAX:-$(echo $PARTICLE_SIZE*1.2 | bc -l)}

# usage
usage() {
  cat <<__EOF__
Usage: $0 MICROGRAPH_FILE

Mandatory Arguments:
  [-a|--apix FLOAT]            use specified pixel size
  [-d|--fmdose FLOAT]          use specified fmdose in calculations

Optional Arguments:
  [-g|--gainref GAINREF_FILE]  use specificed gain reference file
  [-k|--kev INT]               input micrograph was taken with INT keV microscope
  [-s|--superres]              input micrograph was taken in super-resolution mode (so we should half the number of pixels)
  [-p|--phase-plate]            input microgrpah was taken using a phase plate (so we should calculate the phase)
  [-P|--patch STRING]          use STRING patch settings for motioncor2 alignment
  [-e|--particle-size INT]     pick particles with size INT
  [-f|--force]                 reprocess all steps (ignore existing results).
  [-m|--mode [spa|tomo]]       pipeline to use: single particle analysis of tomography
  [-t|--task sum|align|pick|all] what to process; sum the stack, align the stack; just particle pick or all
  
__EOF__
}

# determine what to run
main() {

  # map long arguments to short
  for arg in "$@"; do
    shift
    case "$arg" in
      "--help")    set -- "$@" "-h";;
      "--gainref") set -- "$@" "-g";;
      "--force")   set -- "$@" "-F";;
      "--apix")    set -- "$@" "-a";;
      "--fmdose")  set -- "$@" "-d";;
      "--kev")     set -- "$@" "-k";;
      "--superres") set -- "$@" "-s";;
      "--phase-plate") set -- "$@" "-p";;
      "--patch")   set -- "$@" "-P";;
      "--particle-size")   set -- "$@" "-e";;
      "--mode")    set -- "$@" "-m";;
      "--task")    set -- "$@" "-t";;
      *)           set -- "$@" "$arg";;
   esac
  done

  while getopts "Fhspm:t:g:a:d:k:e:" opt; do
    case "$opt" in
    g) GAINREF_FILE="$OPTARG";;
    a) APIX="$OPTARG";;
    d) FMDOSE="$OPTARG";;
    k) KV="$OPTARG";;
    s) SUPERRES=1;;
    p) PHASE_PLATE=1;;
    P) PATCH="$OPTARG";;
    e) PARTICLE_SIZE="$OPTARG";;
    F) FORCE=1;;
    m) MODE="$OPTARG";;
    t) TASK="$OPTARG";;
    h) usage; exit 0;;
    ?) usage; exit 1;;
    esac
  done

  MICROGRAPH=${@:$OPTIND:1}
  if [ -z $MICROGRAPH ]; then
    echo "Need input micrograph MICROGRPAH_FILE to continue..."
    usage
    exit 1
  fi
  if [ -z $APIX ]; then
    echo "Need pixel size [-a|--apix] to continue..."
    usage
    exit 1
  fi
  if [ -z $FMDOSE ]; then
    echo "Need fmdose [-d|--fmdose] to continue..."
    usage
    exit 1
  fi

  if [ "$MODE" == "spa" ]; then
    do_spa
  elif [ "$MODE" == "tomo" ]; then
    do_tomo
  else
    echo "Unknown MODE $MODE"
    usage
    exit 1
  fi

}



do_spa()
{
  do_prepipeline

  if [[ "$TASK" == "align" || "$TASK" == "sum" || "$TASK" == "all" ]]; then
    do_gainref
  fi
 
  # start doing something!
  if [[ "$TASK" == "align" || "$TASK" == "all" ]]; then
    do_spa_align
  fi
  if [[ "$TASK" == "sum" || "$TASK" == "all" ]]; then
    do_spa_sum
  fi

  if [[ "$TASK" == "pick" || "$TASK" == "all" ]]; then
    # get the assumed pick file name
    if [ -z $ALIGNED_FILE ]; then
      ALIGNED_FILE=$(align_file ${MICROGRAPH})
    fi
    do_spa_pick
  fi


  #generate_preview $ALIGNED_FILE $PARTICLE_FILE

}

do_tomo()
{

  echo "TODO"
  exit 255

}


do_prepipeline()
{
  echo "pre-pipeline:"
  # input
  echo "  - task: micrograph"
  echo "    file: ${MICROGRAPH}"

  # other params
  echo "  - task: input parameters"
  echo "    data:"
  echo "      apix: ${APIX}"
  echo "      fmdose: ${FMDOSE}"
  echo "      astigmatism: ${CS}"
  echo "      kev: ${KV}"
  echo "      super_resolution: ${SUPERRES}"
  echo "      phase_plate: ${PHASE_PLATE}"

}


do_gainref()
{

  # gainref
  echo "  - task: gainref"
  echo "    file: ${GAINREF_FILE}"
  local start=$(date +%s.%N)
  GAINREF_FILE=$(process_gainref "$GAINREF_FILE")
  local duration=$( awk '{print $2-$1}' <<< "$start $(date +%s.%N)" )
  echo "    duration: $duration"


  #generate_file_meta "$GAINREF_FILE"
}


###
# process the micrograph by aligning and creating the ctfs and previews for the MICROGRAPH
###
do_spa_align() {

  >&2 echo
  >&2 echo "Processing align for micrograph $MICROGRAPH..."

  echo "single_particle_analysis:"

  echo "  - task: align"
  local start=$(date +%s.%N)
  ALIGNED_FILE=$(align_stack "$MICROGRAPH" "$GAINREF_FILE") #"./aligned/motioncor2/$MOTIONCOR2_VERSION")
  local duration=$( awk '{print $2-$1}' <<< "$start $(date +%s.%N)" )
  echo "    duration: $duration"
  echo "    file: ${ALIGNED_FILE}"

  echo "  - task: align data"
  parse_motioncor ${ALIGNED_FILE}

  echo "  - task: ctf"
  local start=$(date +%s.%N)
  ALIGNED_CTF_FILE=$(process_ctffind "$ALIGNED_FILE" "./aligned/motioncor2/$MOTIONCOR2_VERSION/ctffind4/$CTFFIND4_VERSION")
  local duration=$( awk '{print $2-$1}' <<< "$start $(date +%s.%N)" )
  echo "    duration: $duration"
  echo "    file: ${ALIGNED_CTF_FILE}"

  echo "  - task: ctf data"
  parse_ctffind $ALIGNED_CTF_FILE

}

###
# create the ctf and preview images for the summed stack of the MICROGRAPH. creating the sum temporarily if necessary
###
do_spa_sum() {

  >&2 echo
  >&2 echo "Processing sum for micrograph $MICROGRAPH..."


  local filename=$(basename -- "$MICROGRAPH")
  local extension="${filename##*.}"

  local outdir=./summed/imod/$IMOD_VERSION/ctffind4/$CTFFIND4_VERSION/
  SUMMED_CTF_FILE="$outdir/${filename%.${extension}}_sum_ctf.mrc"
  # check for the SUMMED_CTF_FILE, do if not exists
  if [ -e $SUMMED_CTF_FILE ]; then
    >&2 echo
    >&2 echo "sum ctf file $SUMMED_CTF_FILE already exists"
    #>&2 echo "SUMMED_CTF_FILE="${SUMMED_CTF_FILE}
  fi

  if [[ $FORCE -eq 1 || ! -e $SUMMED_CTF_FILE ]]; then

    echo "  - task: ctf sum"
    local tmpfile="/tmp/${filename%.${extension}}_sum.mrc"
    SUMMED_FILE=$(process_sum "$MICROGRAPH" "$tmpfile" "$GAINREF_FILE")
    #echo "="${SUMMED_FILE}

    SUMMED_CTF_FILE=$(process_ctffind "$SUMMED_FILE" "./summed/imod/$IMOD_VERSION/ctffind4/$CTFFIND4_VERSION")
    echo "    file: ${SUMMED_CTF_FILE}"

    rm -f ${tmpfile}

  fi

  echo "  - task: sum ctf data"
  parse_ctffind $SUMMED_CTF_FILE

}


do_spa_pick()
{
  # use DW file?
  PARTICLE_FILE=$(particle_pick "$ALIGNED_FILE")
  echo "PARTICLE_FILE="${PARTICLE_FILE}
}



function gen_template() {
  eval "echo \"$1\""
}

process_gainref()
{
  # read in a file and spit out the appropriate gainref to actually use via echo as path
  local input=$1
  local outdir=${2:-.}
  
  >&2 echo
  
  local filename=$(basename -- "$input")
  local extension="${filename##*.}"
  local output="$outdir/${filename}"
  mkdir -p $outdir

  if [[ ! -e $input ]]; then
    >&2 echo "gainref file $input does not exist!"
    exit
  fi

  if [[ "$extension" -eq "dm4" ]]; then
  
    output="$outdir/${input%.$extension}.mrc"
    if [[ $FORCE -eq 1 || ! -e $output ]]; then
      >&2 echo "converting gainref file $input to $output..."
      module load ${EMAN2_LOAD}
      e2proc2d.py "$input" "$output"  1>&2
    else
      >&2 echo "gainref file $output already exists"
    fi
  
  # TODO: this needs testing
  elif [[ "$extension" -eq 'mrc' && ! -e $output ]]; then
    
    >&2 echo "Error: output gainref file $output does not exist"
    
  fi
  
  echo $output
}


align_file()
{
  local filename=$(basename -- "$1")
  local outdir=${2:-./aligned/motioncor2/$MOTIONCOR2_VERSION}
  local extension="${filename##*.}"
  local output="$outdir/${filename%.${extension}}_aligned.mrc"
  echo $output
}


align_stack()
{
  # given a set of parameters, run motioncor on the input movie stack
  local input=$1
  local gainref="$2"
  local outdir=${3:-./aligned/motioncor2/$MOTIONCOR2_VERSION}
  
  >&2 echo
  
  mkdir -p $outdir
  local output=$(align_file $input $outdir)

  if [ -e $output ]; then
    >&2 echo "aligned file $output already exists"
  fi
  
  if [[ $FORCE -eq 1 || ! -e $output ]]; then

    >&2 echo "aligning stack $input to $output, using gainref file $gainref..."
    local cmd="
      MotionCor2  \
        $(if [ '$extension' == 'mrc' ]; then echo '-InMrc'; else echo '-InTiff'; fi) '$input' \
        $(if [ ! '$gainref' == '' ]; then echo -Gain \'$gainref\'; fi) \
        -OutMrc $output \
        -LogFile ${output%.${extension}}.log \
        -FmDose $FMDOSE \
        -kV $KV \
        -Bft $BFT \
        -PixSize $(if [ $SUPERRES -eq 1 ]; then echo $APIX/2 | bc -l; else echo $APIX; fi) \
        -FtBin $(if [ $SUPERRES -eq 1 ]; then echo 2; else echo 1; fi) \
        -Patch $PATCH \
        -Throw $THROW \
        -Trunc $TRUNC \
        -Iter $ITER \
        -Tol $TOL \
        -OutStack $OUTSTACK \
        -InFmMotion $INFMMOTION \
        -Gpu $GPU
    "

    align_command=$(gen_template "$cmd")
    >&2 echo "executing:" $align_command
    module load ${MOTIONCOR2_LOAD}
    eval $align_command  1>&2
  fi
  
  echo $output
}


process_ctffind()
{
  # do a ctf of the input mrc
  local input=$1
  local outdir=${2:-.}
  
  >&2 echo

  if [ ! -e $input ]; then
    >&2 echo "input micrograph $input not found"
    exit 4
  fi
    
  local filename=$(basename -- "$input")
  local extension="${filename##*.}"
  local output="$outdir/${filename%.${extension}}_ctf.mrc"
  mkdir -p $outdir

  local apix=${APIX}
  if [[ $SUPERRES -eq 1 ]]; then
    apix=$(echo $apix/2 | bc -l)
  fi

  if [ -e $output ]; then
    >&2 echo "output ctf file $output already exists"
  fi

  if [[ $FORCE -eq 1 || ! -e $output ]]; then
    >&2 echo "ctf'ing micrograph $input to $output..."
    module load ${CTFFIND4_LOAD}
    # phase plate?
    if [ $PHASE_PLATE -eq 0 ]; then
      ctffind > ${output%.${extension}}.log << __CTFFIND_EOF__
$input
$output
$apix
$KV
$CS
0.1
512
30
4
1000
50000
200
no
no
yes
100
no
no
__CTFFIND_EOF__
    else
      ctffind > $log << __CTFFIND_EOF__
$input
$output
$apix
$KV
$CS
0.1
512
30
4
1000
50000
200
no
no
yes
100
yes
0
1.571
0.1
no
__CTFFIND_EOF__
    fi
  fi

  echo $output
}


generate_jpg()
{
  local input=$1
  local outdir=${2:-.}
  
  local start=$(date +%s.%N)
  >&2 echo

  if [ ! -e $input ]; then
    >&2 echo "input micrograph $input not found"
    exit
  fi
    
  local filename=$(basename -- "$input")
  local extension="${filename##*.}"
  local output="$outdir/${filename%.${extension}}.jpg"
  mkdir -p $outdir
  
  if [ -e $output ]; then
    >&2 echo "preview file $output already exists"
  fi

  if [[ $FORCE -eq 1 || ! -e $output ]]; then
    >&2 echo "generating preview of $input to $output..."
    module load ${EMAN2_LOAD}
    e2proc2d.py --writejunk $input $output  1>&2
  fi

  local duration=$( awk '{print $2-$1}' <<< "$start $(date +%s.%N)" )
  >&2 echo "jpg(): $duration seconds"

  echo $output
}


process_sum()
{
  local input=$1
  local output=$2
  local gainref=$3
  local outdir=${4:-.}
  
  local filename=$(basename -- "$output")
  local extension="${filename##*.}"
  local log="${output%.${extension}}.log"
  
  local start=$(date +%s.%N)
  >&2 echo

  if [ ! -e $input ]; then
    >&2 echo "input micrograph $input not found"
    exit
  fi
    
  if [ -e $output ]; then
    >&2 echo "output micrograph $output already exists"
  fi

  if [[ $FORCE -eq 1 || ! -e $output ]]; then
    >&2 echo "summing stack $input to $output..."
    local tmpfile=$(mktemp /tmp/pipeline-sum.XXXXXX)
    module load ${IMOD_LOAD}
    >&2 echo "avgstack $input $tmpfile /"
    avgstack > $log << __AVGSTACK_EOF__
$input
$tmpfile
/
__AVGSTACK_EOF__
    >&2 echo clip mult -n 16 $tmpfile "$gainref" $output
    clip mult -n 16 $tmpfile "$gainref" $output  1>&2
    rm -f $tmpfile
  fi

  local duration=$( awk '{print $2-$1}' <<< "$start $(date +%s.%N)" )
  >&2 echo "sum(): $duration seconds"

  echo $output
}


particle_pick()
{

  local input=$1

  local start=$(date +%s.%N)
  >&2 echo

  if [ ! -e $input ]; then
    >&2 echo "input micrograph $input not found"
    exit
  fi

  local filename=$(basename -- "$input")
  local extension="${filename##*.}"
  local dirname='./particles'
  local output="$dirname/${input%.${extension}}_autopick.star"

  if [ -e $output ]; then
    >&2 echo "particle file $output already exists"
  fi
  if [[ $FORCE -eq 1 || ! -e $output ]]; then

    >&2 echo "particle picking from $input to $output..."
    module load ${RELION_LOAD}
    local cmd="relion_autopick --i $input --odir $dirname/ --pickname autopick --LoG  --LoG_diam_min $PARTICLE_SIZE_MIN --LoG_diam_max $PARTICLE_SIZE_MAX --angpix $APIX --shrink 0 --lowpass 15 --LoG_adjust_threshold -0.1"
    >&2 echo $cmd
    $cmd 1>&2

  fi

  local duration=$( awk '{print $2-$1}' <<< "$start $(date +%s.%N)" )
  >&2 echo "particle_pick(): $duration seconds"

  echo $output
}

generate_file_meta()
{
  local md5=$(md5sum "$1" | awk '{print $1}')
  local size=$(ls -l "$1" | cut -d " " -f5)
  >&2 echo "md5=$md5 size=$size"

}

generate_preview()
{
  local aligned=$1
  local particles=$2

  # create the picked preview
  local aligned_jpg=$(generate_jpg "$aligned" /tmp)
  local apix_size=68.16799999999999
  local picked_preview=$(mktemp /tmp/pipeline-picked-preview-XXXXXXXX)
  local origifs=$IFS
  IFS=$'
'
  local cmd="convert -flip -negate '$aligned_jpg' "
  for l in $(cat $particles | grep -vE '(_|\#|^ $)' ); do
    local shape=$(echo $l | awk -v size="$apix_size" '{print "circle " $1 "," $2 "," $1 + size/2 "," $2 }')
    cmd="${cmd}    -strokewidth 3 -stroke yellow -fill none -draw \" $shape \" "
  done
  cmd="${cmd}  $picked_preview"
  IFS=$origifs
  echo $cmd
  eval $cmd
  echo "PICKED: $picked_preview"

  # get a timestamp of when file was created
  local timestamp=$(TZ=America/Los_Angeles date +"%Y-%m-%d %H:%M:%S" -r $aligned)

  # create the top half
  SUMMED_CTF_PREVIEW=$(generate_jpg "${SUMMED_CTF_FILE}" "./summed/imod/$IMOD_VERSION/ctffind4/$CTFFIND4_VERSION" )
  echo "SUMMED_CTF_PREVIEW="${SUMMED_CTF_PREVIEW}

  local top=$(mktemp /tmp/pipeline-top.XXXXXXXX)
  convert \
    -resize '512x512^' -extent '512x512' $picked_preview \
    -flip ${SUMMED_CTF_PREVIEW} \
    +append -font DejaVu-Sans -pointsize 28 -fill SeaGreen1 -draw 'text 8,492 "~4500 pp"' \
    +append -font DejaVu-Sans -pointsize 28 -fill yellow -draw 'text 520,492 "'${timestamp}'"' \
    +append -font DejaVu-Sans -pointsize 28 -fill yellow -draw 'text 854,492 "3.8Å (22%)"' \
    $top

  # create the bottom half
  ALIGNED_CTF_PREVIEW=$(generate_jpg "${ALIGNED_CTF_FILE}" "./aligned/motioncor2/$MOTIONCOR2_VERSION/ctffind4/$CTFFIND4_VERSION" )
  echo "ALIGNED_CTF_PREVIEW="${ALIGNED_CTF_PREVIEW}

  local bottom=$(mktemp /tmp/pipeline-bottom.XXXXXXXX)
  convert \
    -resize '512x512^' -extent '512x512' $aligned_jpg \
    ${ALIGNED_CTF_PREVIEW} \
    +append -font DejaVu-Sans -pointsize 28 -fill orange -draw 'text 402,46 "0.412"'
    +append -font DejaVu-Sans -pointsize 28 -fill orange -draw 'text 854,46 "3.6Å (47%)"'
    $bottom

  # clean files
  rm -f $aligned_jpg

  # create the final preview
  local outdir=previews
  mkdir $outdir
  local filename=$(basename -- "$input")
  local extension="${filename##*.}"
  local output="$outdir/${filename%.${extension}}_full_sidebyside.jpg"
  
  convert $top $bottom \
     -append $output
  rm -f $top $bottom

  echo $output
}


parse_ctffind()
{
  local input=$1

  local filename=$(basename -- "$input")
  local extension="${filename##*.}"
  local datafile="${input%.${extension}}.txt"

  if [ ! -e $datafile ]; then
    >&2 echo "ctf data file $datafile does not exist"
    exit 4
  fi
  echo "    file: $datafile"
  echo "    data:"
  cat $datafile | awk \
'/# Pixel size: / { next } \
!/# / { defocus_1=$2; defocus_2=$3; astig=$4; phase_shift=$5; cross_correlation=$6; resolution=$7; next } \
END { \
print "      defocus_1: " defocus_1;
print "      defocus_2: " defocus_2;
print "      astigmatism: " astig;
print "      phase_shift: " phase_shift;
print "      cross_correlation: " cross_correlation;
print "      resolution: " resolution;
}'

}

parse_motioncor()
{
  local input=$1

  local datafile="${input}.log0-Patch-Full.log"

  echo "    file: $datafile"

  echo "    data:"
  cat $datafile | grep -vE '^$' | awk '!/# / { x=$2*$2; y=$3*$3; n=sqrt(x+y); print "    - "n; next }'

# print $2 ", " $3 "\t>>>\t" x "\t" y "\t>>" n;

}

main "$@"

