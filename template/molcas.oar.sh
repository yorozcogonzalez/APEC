#!/bin/bash
#OAR -n NOMEPROGETTO
#OAR -l nodes=1,walltime=hh:00:00
#--------------------------------------------------------------------#
module load gcc/4.8.3
#--------------------------------------------------------------------#
export MOLCAS="MOLCASDIR"
export MOLCAS_MEM=MEMORIAMB
export MOLCAS_MOLDEN=ON
export MOLCAS_PRINT=normal
export TINKER="TINKERDIR"
export Project=NOMEPROGETTO
export WorkDir=/tmp/$USER/$Project.$OAR_JOB_ID
export InpDir=NOMEDIRETTORI
#--------------------------------------------------------------------#
mkdir -p $WorkDir
cd $WorkDir
MOLCASDRV/molcas $InpDir/$Project.input >$InpDir/$Project.out 2>$InpDir/$Project.err
cd $InpDir
rm $WorkDir -r
