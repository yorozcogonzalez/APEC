#!/bin/bash
#
# Reading project name, parm file and templatedir from Infos.dat
#
Project=`grep "Project" Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" Infos.dat | awk '{ print $2 }'`
multichain=`grep "MultChain" Infos.dat | awk '{ print $2 }'`
step=`grep "Step" Infos.dat | awk '{ print $2 }'`
charge=`grep "Init_Charge" Infos.dat | awk '{ print $2 }'`
relaxpr=`grep "Relax_protein" Infos.dat | awk '{ print $2 }'`
moldy=`grep "MD_ensemble" Infos.dat | awk '{ print $2 }'`
amber=`grep "AMBER" Infos.dat | awk '{ print $2 }'`

   cd Dynamic

   if [[ $step -eq 0 ]]; then     
      cp $templatedir/ASEC/dynamic_sol_NVT.mdp .
      cp Sim_NPT/output/final-${Project}_box_sol.gro ${Project}_box_sol.gro
      cp Sim_NPT/*.itp .
      cp Sim_NPT/${Project}_box_sol.ndx .
      cp Sim_NPT/${Project}_box_sol.top .
      cp Sim_NPT/residuetypes.dat .
      cp -r Sim_NPT/$amber.ff .
   fi

   if [[ $relaxpr == y ]]; then
      sed -i "s/;freezegrps = GroupDyna/freezegrps = GroupDyna/g" dynamic_sol_NVT.mdp
      sed -i "s/;freezedim = Y Y Y/freezedim = Y Y Y/g" dynamic_sol_NVT.mdp
   else
      sed -i "s/;freezegrps = non-Water/freezegrps = non-Water/g" dynamic_sol_NVT.mdp
      sed -i "s/;freezedim = Y Y Y/freezedim = Y Y Y/g" dynamic_sol_NVT.mdp
   fi
#else
#   cd Dynamic
#   sed -i "s/;freezegrps = GroupDyna/freezegrps = GroupDyna/g" dynamic_sol_NPT.mdp
#   sed -i "s/;freezedim = Y Y Y/freezedim = Y Y Y/g" dynamic_sol_NPT.mdp
#fi
echo ""  
echo " What is the PRODUCTION TEMPERATURE of the NVT simulation? (Kelvin)"
echo ""
read tempmd
echo ""
echo " Do you want to heat the system before the MD production run? (y/n)"
echo
read risposta
if [[ $risposta == y ]]; then
   echo ""
   echo " How long is the HEATING PHASE? (ps)"
   echo ""
   read timeheat
   echo ""
   echo " How long is the EQUILIBRATION PHASE? (ps)"
   echo ""
   read timequi
   echo ""
else
   echo ""
   echo " How long is the EQUILIBRATION PHASE? (ps)"
   echo ""
   read timequi
   timeheat=0
   #timequi=0
fi
echo ""
echo " How long is the PRODUCTION PHASE? (ps)"
echo ""
read timeprod
echo ""

parallelize=r
while [[ $parallelize != y && $parallelize != n ]]; do
   echo ""
   echo " Do you want to parallelize the production phase of the MD? (y/n)"
   echo ""
   read parallelize
   echo ""
done

numparallel=1
if [[ $parallelize == y ]]; then
   echo ""
   echo " How many MDs in parallel?"
   echo ""
   read numparallel
   echo ""
fi

../update_infos.sh "HeatMD" $timeheat ../Infos.dat
../update_infos.sh "EquiMD" $timequi ../Infos.dat
../update_infos.sh "ProdMD" $timeprod ../Infos.dat
../update_infos.sh "Parallel_MD" $numparallel ../Infos.dat

if [[ $parallelize == y ]]; then
   timeprod=$(($timeprod/$numparallel))
fi

if [[ $risposta == y ]]; then
   numsteps=$(($timeheat+$timequi+$timeprod))
   sed -i "s/TIME1/$timeheat/" dynamic_sol_NVT.mdp
   sed -i "s/TEMP1/$tempmd/g" dynamic_sol_NVT.mdp
else
   numsteps=$(($timequi+$timeprod))
   sed -i "s/annealing/;annealing/" dynamic_sol_NVT.mdp
#   sed -i "s/;gen_vel/gen_vel/" dynamic_sol_NVT.mdp    # it is goint to read vel from last .gro
#   sed -i "s/;gen_temp/gen_temp/" dynamic_sol_NVT.mdp
#   sed -i "s/;gen_temp/gen_temp/" dynamic.mdp
   sed -i "s/ref_t = 0/;ref_t = 0/" dynamic_sol_NVT.mdp
   sed -i "s/;ref_t = TEMP1/ref_t = TEMP1/" dynamic_sol_NVT.mdp
   sed -i "s/TEMP1/$tempmd/g" dynamic_sol_NVT.mdp
fi
numsteps=$(($numsteps*1000))
sed -i "s/PASSI/$numsteps/" dynamic_sol_NVT.mdp

#slurm
#cp $templatedir/gromacs.sh .
cp $templatedir/gromacs.slurm.sh gromacs.sh

if [[ $parallelize == y ]]; then
   for i in $(eval echo "{1..$numparallel}")
   do
      mkdir seed_$i
      cp -r $amber.ff seed_$i
      cp ${Project}_box_sol.* *.mdp *.itp *.dat *.sh seed_$i

      cd seed_$i
      sed -i "s/;gen_temp/gen_temp                = $tempmd/" dynamic_sol_NVT.mdp
      sed -i "s/;gen_vel/gen_vel/" dynamic_sol_NVT.mdp
      sed -i "/gen_vel/agen_seed                = $((23456+131*$i))" dynamic_sol_NVT.mdp

      $gropath/grompp -maxwarn 2 -f dynamic_sol_NVT.mdp -c ${Project}_box_sol.gro -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -o ${Project}_box_sol.tpr

      sed -i "s|NOMEPROGETTO|${Project}_box_sol|" gromacs.sh
      sed -i "s|NOMEDIRETTORI|$PWD|" gromacs.sh
      sed -i "s|GROPATH|$gropath|" gromacs.sh

      sed -i "s/SBATCH -t 23:59:00/SBATCH -t 47:59:00/" gromacs.sh
      #sed -i "/mem=800MB/a#PBS -A PAA0009" gromacs.sh
      #sed -i "/NPROCS/amodule load gromacs\/4.5.5" gromacs.sh
      #sed -i "/\/usr\/local/d" gromacs.sh
      #sed -i "/cp \* \$outdir/d" gromacs.sh
      ##echo "mdrun -s ${Project}_box_sol.tpr -o ${Project}_box_sol.trr -c final-${Project}_box_sol.gro" >> gromacs.sh
      #echo "mpiexec mdrun_mpi -s ${Project}_box_sol.tpr -o ${Project}_box_sol.trr -c final-${Project}_box_sol.gro" >> gromacs.sh
      #echo "cp * \$outdir" >> gromacs.sh
      #sed -i "/gromacs-4.5.5/d" gromacs.sh

      #slurm
      #cp gromacs.sh gromacs.slurm.sh
      sbatch gromacs.sh
      #qsub gromacs.sh

      ##mdrun -s ${Project}_box_sol.tpr -o ${Project}_box_sol.trr -c final-${Project}_box_sol.gro 2> grolog
      cd ..
      done
   else
      $gropath/grompp -maxwarn 2 -f dynamic_sol_NVT.mdp -c ${Project}_box_sol.gro -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -o ${Project}_box_sol.tpr

      sed -i "s|NOMEPROGETTO|${Project}_box_sol|" gromacs.sh
      sed -i "s|NOMEDIRETTORI|$PWD|" gromacs.sh
      sed -i "s|GROPATH|$gropath|" gromacs.sh

      sed -i "s/SBATCH -t 23:59:00/SBATCH -t 47:59:00/" gromacs.sh
      #sed -i "/mem=800MB/a#PBS -A PAA0009" gromacs.sh
      #sed -i "/NPROCS/amodule load gromacs\/4.5.5" gromacs.sh
      #sed -i "/\/usr\/local/d" gromacs.sh
      #sed -i "/cp \* \$outdir/d" gromacs.sh
      ##echo "mdrun -s ${Project}_box_sol.tpr -o ${Project}_box_sol.trr -c final-${Project}_box_sol.gro" >> gromacs.sh
      #echo "mpiexec mdrun_mpi -s ${Project}_box_sol.tpr -o ${Project}_box_sol.trr -c final-${Project}_box_sol.gro" >> gromacs.sh
      #echo "cp * \$outdir" >> gromacs.sh
      #sed -i "/gromacs-4.5.5/d" gromacs.sh

      #slurm
      #cp gromacs.sh gromacs.slurm.sh
      sbatch gromacs.sh
      #qsub gromacs.sh

      ##mdrun -s ${Project}_box_sol.tpr -o ${Project}_box_sol.trr -c final-${Project}_box_sol.gro 2> grolog
fi

   cd ../
   cp $templatedir/ASEC/MD_ASEC.sh .
   cp $templatedir/Analysis_MD.sh .
   echo ""
   echo ""
   echo " Wait for the NVT molecular dynamics to end then run MD_ASEC.sh"
   echo ""

