#! /bin/bash

##edit only the name of the first CONFIG file and the seauence####
STARTFILE=./start0.CONFIG
SEQUENCE=({01..05})
###################################################################


ARGV=($@)
NARGV=${#ARGV[@]}
MAXNP=`cat ~/.MAXNP` 

case ${NARGV} in     
    1 ) 
	name=$1
	np=1
	;;
    2 )
	name=$1
	np=$2	
	;;
    * )
	echo "Error: wrong arguments number"
	echo "USAGE:"
	echo "`basename $0` my_process_name [np <= ${MAXNP}]"
	exit 666
	;;
esac

cp ${STARTFILE} CONFIG

for n in ${SEQUENCE[@]} ; do 
    # prepare
    

    # launch 
    echo "   case ${n} "
    echo "start ----"`date`
    ./dlpoly.sh ${name} ${np} magik
    echo "done  ----"`date`      

    # save
    SAVEDIR=nvt${n}
    mkdir -p ${SAVEDIR}
    thermoDynamics.py
    calculateMSD.py C
    cp CONTROL OUTPUT STATIS.dat REVCON CONFIG HISTORY.dlpolyhist msd_C.dat ${SAVEDIR}

    # reset
    cp REVCON CONFIG
    rm OUTPUT STATIS.dat msd_C.dat HISTORY.dlpolyhist     
done 
