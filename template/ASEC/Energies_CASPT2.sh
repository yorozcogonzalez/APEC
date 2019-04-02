#!/bin/bash
#
Project=`grep "Project" ../Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" ../Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" ../Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" ../Infos.dat | awk '{ print $2 }'`
numatoms=`grep "numatoms" ../Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" ../Infos.dat | awk '{ print $2 }'`
Step=`grep "Step" ../Infos.dat | awk '{ print $2 }'`

mkdir CASPT2_ipea_025
mkdir CASPT2_ipea_0
#mkdir CASPT2_ipea_0/CASSCF_3_States

Project_new=${Project}_VDZP_Opt

cp $templatedir/ASEC/template_CASPT2 CASPT2_ipea_025/${Project}_CASPT2_025.input
cp $templatedir/ASEC/template_CASPT2 CASPT2_ipea_0/${Project}_CASPT2_0.input
sed -i "s/ipea = 0.25/ipea = 0.0/g" CASPT2_ipea_0/${Project}_CASPT2_0.input
sed -i "s|PARAMETER|${prm}|" CASPT2_ipea_025/${Project}_CASPT2_025.input
sed -i "s|PARAMETER|${prm}|" CASPT2_ipea_0/${Project}_CASPT2_0.input

cp $Project_new/$Project_new.key CASPT2_ipea_025/${Project}_CASPT2_025.key
cp $Project_new/$Project_new.key CASPT2_ipea_0/${Project}_CASPT2_0.key

cp $Project_new/$Project_new.xyz CASPT2_ipea_025/${Project}_CASPT2_025.xyz
cp $Project_new/$Project_new.xyz CASPT2_ipea_0/${Project}_CASPT2_0.xyz

cp $Project_new/$prm.prm CASPT2_ipea_025
cp $Project_new/$prm.prm CASPT2_ipea_0

cp $Project_new/$Project_new.JobIph CASPT2_ipea_025/${Project}_CASPT2_025.JobIph
cp $Project_new/$Project_new.JobIph CASPT2_ipea_0/${Project}_CASPT2_0.JobIph

#slurm
cp $Project_new/SUBMISSION CASPT2_ipea_025
cp $Project_new/SUBMISSION CASPT2_ipea_0
sed -i "s/NOMEPROGETTO/$Project/" CASPT2_ipea_025/SUBMISSION
sed -i "s/NOMEPROGETTO/$Project/" CASPT2_ipea_0/SUBMISSION
sed -i "s/MEMTOT/23000/" CASPT2_ipea_025/SUBMISSION
sed -i "s/MEMTOT/23000/" CASPT2_ipea_0/SUBMISSION
sed -i "s/MEMORIA/20000/" CASPT2_ipea_025/SUBMISSION
sed -i "s/MEMORIA/20000/" CASPT2_ipea_0/SUBMISSION
sed -i "s/walltime=140/walltime=230/" CASPT2_ipea_025/SUBMISSION
sed -i "s/walltime=140/walltime=230/" CASPT2_ipea_0/SUBMISSION

sed -i "s/export Project=.*/export Project=${Project}_CASPT2_025/g" CASPT2_ipea_025/SUBMISSION
sed -i "s/export Project=.*/export Project=${Project}_CASPT2_0/g" CASPT2_ipea_0/SUBMISSION

cd CASPT2_ipea_025
SUBCOMMAND SUBMISSION
cd ..
cd CASPT2_ipea_0
#SUBCOMMAND SUBMISSION

cd ../../
cp $templatedir/ASEC/Energies_CAV_TINKER.sh .

