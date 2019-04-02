#!/bin/bash
#
Project=`grep "Project" Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" Infos.dat | awk '{ print $2 }'`
retstereo=`grep "RetStereo" Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" Infos.dat | awk '{ print $2 }'`
dowser=`grep "Dowser" Infos.dat | awk '{ print $2 }'`

cd Minimize_${Project}
$gropath/grompp -f standard-EM.mdp -c $Project.gro -n $Project.ndx -p $Project.top -o $Project.tpr
cp $templatedir/minimization.sh .
./minimization.sh

