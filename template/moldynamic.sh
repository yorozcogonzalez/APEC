#!/bin/bash
#
# Script for running molecular dynamics with Gromacs
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
checkrest=`grep 'ReStRun_2' ../Infos.dat | wc -l`
#
# Copying the relevant files
#
cp $templatedir/dynamic.mdp .
cp $templatedir/gromacs.sh .
#
# Asking the simulation temperature and if heating and equilibration must be run,
# along with the duration of all MD phases
#
echo " What is the production temperature of the simulation? (Kelvin)"
read tempmd
echo " Do you want to heat the system before the MD production run? (y/n)"
read risposta
if [[ $risposta == y ]]; then
   echo " How long is the heating phase? (ps)"
   read timeheat
   echo ""
   echo " How long is the equilibration phase? (ps)"
   read timequi
   echo ""
else
   timeheat=0
   timequi=0
fi
echo " How long is the production phase? (ps)"
read timeprod
echo ""  
while [[ $timeprod -lt 100 || $timeprod -gt 10000 ]]; do
      echo " Wrong number! Please type a number between 100 and 10000 ps"
      read timeprod
      echo ""
done
#
# Updating Infos.dat with the MD parameters for further use
#
../update_infos.sh $checkrest "HeatMD" $timeheat ../Infos.dat
../update_infos.sh $checkrest "EquiMD" $timequi ../Infos.dat
../update_infos.sh $checkrest "ProdMD" $timeprod ../Infos.dat
if [[ $risposta == y ]]; then
   numsteps=$(($timeheat+$timequi+$timeprod))
   sed -i "s/TIME1/$timeheat/" dynamic.mdp
   sed -i "s/TEMP1/$tempmd/" dynamic.mdp
else
   numsteps=$timeprod
   sed -i "s/annealing/;annealing/" dynamic.mdp 
   sed -i "s/;gen_vel/gen_vel/" dynamic.mdp
   sed -i "s/;gen_temp/gen_temp/" dynamic.mdp
   sed -i "s/ref_t = 0/;ref_t = 0/" dynamic.mdp
   sed -i "s/;ref_t = TEMP1/ref_t = TEMP1/" dynamic.mdp
   sed -i "s/TEMP1/$tempmd/" dynamic.mdp
fi
numsteps=$(($numsteps*1000))
sed -i "s/PASSI/$numsteps/" dynamic.mdp
sed -i "s/;freezegrps/freezegrps/;s/;freezedim/freezedim/" dynamic.mdp
sed -i "s/;freezegrps/freezegrps/;s/;freezedim/freezedim/" dynamic.mdp
#
# Calling grompp to prepare the MD input
#
if [[ -f dynamic.mdp ]]; then
   $gropath/grompp -f dynamic.mdp -c $Project.gro -n $Project.ndx -p $Project.top -o ${Project}.tpr > mdlog
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
   echo " dynamic.mdp not found!"
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
echo " Molecular dynamics submitted! Going back to DynIt.sh..."
echo ""

