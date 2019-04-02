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
# Copying the relevant files
#
cp $templatedir/gromacs.sh .
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
cp $templatedir/change_anneal.sh .
echo " Simulated annealing submitted!"
echo " In case of crashing, you can run change_anneal.sh and change the parameters of your simulation"
echo " Going back to NewStep.sh..."
echo ""
sleep 1
