#!/bin/sh
# (c) Mingye Wang <arthur2e5@aosc.io>
# 2016-02-25 @ https://github.com/AOSC-Dev/scriptlets/blob/master/mkfile.sh
# (c) Steve Parker, http://steve-parker.org/
# 2010-03-19 @ http://steve-parker.org/code/sh/mkfile.sh.txt
# Licensed under the GPL Version 2

# wrapper for dd and fallocate to act like Solaris' mkfile utility.

die(){ printf 'mkfile: error: %s' "$1"; exit "${2-1}"; }

usage()
{
	echo "\
Usage:	mkfile [ -qnvp ] [-m MODE] [ -i INFILE ] [ -b BS ] size[bkgtpe] FILES...
	mkfile -?

blocksize is 1048576 bytes by default. By default, the remainder from size%bs
is added with an additional dd pass in copy mode.

The \`b' suffix denotes block numbers; for compatibility, the default blocksize
used for this calculation is 512."
}

usage_more(){
	usage
	echo "Options:
-q	Turn off verbose output. This is the default.
-v	Turn on verbose output (looks like '{fn} {n}bytes @ {mode} -> {exit}')
-b BS	Sets blocksize for copy/pipe as well as for size calculation.
-i FILE	Sets the input file for dd (\`copy' mode only).
-m MODE	Sets the operation mode. Possible values are:
	copy	dd-from-infile. Creates a regular file, slow. Default.
	seek	dd-seek. Creates a sparse file (bad for swap), fast. See -n.
	alloc	fallocate. Creates a regular file, fast.
	redir	printf-pat-redir. Creates a regular file, slow.
	
-p PAT	The byte pattern to use in pipe mode. Do not use NUL bytes.

".
}

humanreadable ()
{
	multiplier=1
	case $1 in
  		*b)	multiplier=$hbs		;; # blocks (tricky, right?)
  		*k)	multiplier=$((1<<10))	;;
  		*m)	multiplier=$((1<<20)) 	;;
  		*g)	multiplier=$((1<<30))	;;
  	# warning: extended-precision POSIX shells only (e.g. bash on amd64)
  		*t)	multiplier=$((1<<40))	;;
  		*p)	multiplier=$((1<<50))	;;
  		*e)	multiplier=$((1<<60))	;;
  	# for z and y, consider 
	esac
	numeric=${1%[bkmgtpe]}
	printf "$((multiplier * numeric))"
}

bs=1048576 # bigger, better, faster!
hbs=512    # the bs used for humanreadable, in order to respect 'mkfile'.
quiet=0
method=copy # copy/seek/alloc
noremain=0
verbose=0
keepgoing=0
INFILE=/dev/zero

while getopts 'i:b:m:qnavr?' opt
do
  case $opt in
	b) bs=$OPTARG hbs=$bs	;;
	i) INFILE=$OPTARG;;
	q) verbose=0		;;
	k) keepgoing=1		;;
	n) method=seek		;; # dd seek-only
	m) method=optarg	;;
	r) noremain=1		;; # ignore (size % bs) difference
	v) verbose=1		;; # %s %llu bytes stdout; METHOD stderr; \n stdout.
	\?) usage_more; exit	;;
	*) usage; exit 2	;;
  esac
done

shift $((OPTIND-2))


if [ -z "$1" ]; then
  die "No size specificed"
fi
if [ -z "$2" ]; then
  echo "ERROR: No filename specificed"
fi

SIZE=`humanreadable $1` || die "Invalid 
FILENAME="$2"

BS=`humanreadable $bs`

COUNT=`expr $SIZE / $BS`
CHECK=`expr $COUNT \* $BS`
if [ "$CHECK" -ne "$SIZE" ]; then 
  echo "Warning: Due to the blocksize requested, the file created will be `expr $COUNT \* $BS` bytes and not $SIZE bytes"
fi

echo -en "Creating $SIZE byte file $FILENAME...."

dd if=$INFILE bs=$BS count=$COUNT of="$FILENAME" 2>/dev/null
ddresult=$?
if [ "$quiet" -ne "1" ]; then
  # We all know that you're goint to do this next - let's do it for you:
  if [ "$ddresult" -eq "0" ]; then
    echo "Finished:"
  else
    echo "An error occurred. dd returned code $ddresult."
  fi
  ls -l "$FILENAME" && ls -lh "$FILENAME"
fi

exit  $ddresult
