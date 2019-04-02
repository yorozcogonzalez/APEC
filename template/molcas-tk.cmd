#!/bin/bash
#
# @ shell       = /bin/bash
# @ job_name    = NOMEPROGETTO
# @ output      = NOMEPROGETTO.$(jobid).out
# @ error       = NOMEPROGETTO.$(jobid).err
# @ wall_clock_limit = hh:00:00
# @ job_type    = serial
# @ resources = ConsumableMemory(MEMTOTMb)
# NB: The following line for ISCRA account holders only
# @ account_no = IscrA_ASREXMD
# @ queue

export Project=$LOADL_JOB_NAME
export MOLCAS=MOLCASDIR
export MOLCASMEM=MEMORIAMB
export TINKER=TINKERDIR
export WorkDir=$CINECA_SCRATCH/$Project.$RANDOM
export InpDir=NOMEDIRETTORI

MOLCASDRV/molcas $InpDir/$Project.input > $InpDir/$Project.out 2> $InpDir/$Project.err

