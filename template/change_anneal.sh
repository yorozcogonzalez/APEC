#!/bin/bash
#
# Script for running simulated annealing with Gromacs
# Retrieving information from Infos.dat, after checking for its existence
#
if [[ -f ../Infos.dat ]]; then
   Project=`grep "Project" ../Infos.dat | awk '{ print $2 }'`
   templatedir=`grep "Template" ../Infos.dat | awk '{ print $2 }'`
   gropath=`grep "GroPath" ../Infos.dat | awk '{ print $2 }'`
else
   echo " Fatal error! Infos.dat not found!"
   echo " Aborting.."
   exit 0
fi
#
# Backing up previous run if exists
#
i=1
while [[ -f anneal.$i ]]; do
      i=$(($i+1))
done
mv output anneal.$i
rm $Project.tpr mdout.mdp
#
# Retrieving the frozen groups from previous run
#
freddogrp=`grep freezegrps`
freddodim=`grep freezedim`
#
# Copying the relevant files
#
cp $templatedir/gromacs.sh .
cp $templatedir/annealing.mdp .
#
# Asking the user for the new parameters of the simulation
#
echo " Please choose the simulated annealing parameters:"
echo ""
echo " a) What is the total length of the simulation in ps?"
read numsteps
echo ""
echo " b) Do you want the system to stay at high temperature for some time? (y/n)"
read risposta
if [[ $risposta == y ]]; then
   echo "    For how long? (Number of ps)"
   read hotps
   echo ""
fi
echo " c) How long is the heating phase? (ps)"
read timeheat
echo ""
echo " d) What is the maximum temperature you wanna reach? (Kelvin)"
read tempmax
echo ""  
echo " e) How long is the cooling phase? (ps)"
read timecool
echo "" 
if [[ $risposta == y ]]; then
   sed -i "s/PUNTI/4/" annealing.mdp
   sed -i "s/TEMP3/0/" annealing.mdp
   time2=$(($timeheat+$hotps))
   time3=$(($timeheat+$hotps+$timecool))
   sed -i "s/TIME3/$time3/" annealing.mdp
   sed -i "s/TIME2/$time2/" annealing.mdp
   sed -i "s/TIME1/$timeheat/" annealing.mdp
   sed -i "s/TEMP1/$tempmax/;s/TEMP2/$tempmax/" annealing.mdp
else
   sed -i "s/PUNTI/3/" annealing.mdp
   sed -i "s/TEMP3//" annealing.mdp
   sed -i "s/TIME3//" annealing.mdp
   sed -i "s/TIME1/$timeheat/" annealing.mdp
   time2=$(($timeheat+$timecool))
   sed -i "s/TIME2/$time2/" annealing.mdp
   sed -i "s/TEMP1/$tempmax/" annealing.mdp
   sed -i "s/TEMP2/0/" annealing.mdp
fi
numsteps=$(($numsteps*1000))
sed -i "s/PASSI/$numsteps/" annealing.mdp
sed -i "s/.*freezegrps*/$freddogrp/;s/.*freezedim*/$freddodim/" annealing.mdp
#
# Calling grompp to prepare the annealing input
#
if [[ -f annealing.mdp ]]; then
   $gropath/grompp -f annealing.mdp -c $Project.gro -n $Project.ndx -p $Project.top -o ${Project}.tpr > mdlog
   checkmpp=`grep 'This run will generate roughly' mdlog`
   if [[ -z $checkmpp ]]; then
      echo " An error occurred during the execution of grompp. Please look into grolog file"
      echo " No further operation performed. Aborting..."
      echo ""
      exit 0
   else
      echo " ${Project}.tpr was successfully generated. Now I'm going to run the minimization"
      echo ""
      rm mdlog
   fi
else
   echo " annealing.mdp not found!"
   echo " Aborting..."
   echo ""
   exit 0
fi
#
# Modifying the submission script for Gromacs
#
sed -i "s|NOMEPROGETTO|${Project}|" gromacs.sh
sed -i "s|NOMEDIRETTORI|$PWD|" gromacs.sh
sed -i "s|GROPATH|$gropath|" gromacs.sh
qsub gromacs.sh
#
# Messages to the user
#
echo " New simulated annealing simulation submitted. "
echo " In case of further crashing you can re-run this script with different parameters"
echo ""
sleep 1
