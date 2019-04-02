#!/bin/bash
#
#
# Retrieving project name, parameter file, template folder and Tinker path from Infos.dat
#
Project=`grep "Project" Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" Infos.dat | awk '{ print $2 }'`
#retstereo=`grep "RetStereo" Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" Infos.dat | awk '{ print $2 }'`
dowser=`grep "Dowser" Infos.dat | awk '{ print $2 }'`
chromophore=`grep "chromophore" Infos.dat | awk '{ print $2 }'`

echo ""
echo " Name of the project is ${Project}"
echo " ${prm}.prm file found, and i am using it..."
echo ""
#
# Creating the directory where hydrogen atoms MM minimization will be done
# and putting the required files
#
if [[ -d Minimize_${Project} ]]; then
   ./smooth_restart.sh Minimize_${Project} "Do you want to re-run Dowser + H minimization? (y/n)" 1
   if [[ ! -f Infos.dat ]]; then
      mv no.Infos.dat Infos.dat
      exit 0
   fi
fi
mkdir Minimize_${Project}
cp $Project.pdb Minimize_${Project}
cd Minimize_${Project}
cp -r $templatedir/amber94.ff .
cd amber94.ff/
cp normalamino-h aminoacids.hdb
cp amino-rettrans aminoacids.rtp

cd ..
cp $templatedir/residuetypes.dat .
cp $templatedir/standard-EM.mdp .
cp $templatedir/soglia .
cp $templatedir/pdb-to-gro.sh .
if [[ $dowser == "YES" ]]; then
   mkdir ${Project}_dowser
   cp $templatedir/carbret_dow ${Project}_dowser/labelret
   cp $templatedir/pdb-to-dow.sh ${Project}_dowser/
   cp $templatedir/yesH-tk-to-gro.sh ${Project}_dowser/
   cp $templatedir/${prm}.prm ${Project}_dowser/
   cp ../$Project.pdb ${Project}_dowser
   cp $templatedir/PdbFormatter.py ${Project}_dowser
   cp $templatedir/rundowser.sh ${Project}_dowser/
   cd ${Project}_dowser/
   ./rundowser.sh $Project $tinkerdir $prm
   checkrundow=`grep rundowser ../../arm.err | awk '{ print $2 }'`
   if [[ $checkrundow -ne 0 ]]; then
      echo " Problem in rundowser.sh. Aborting..."
      echo ""
      echo " NewStep.sh 1 RunDowserProbl" >> ../../arm.err
      exit 0
   fi
   mv ../$Project.pdb ../$Project.pdb.old.1
   cp $Project.pdb ../
   cd ..
###### YOE added
#  Dowser is adding HZ1 even though nAT is selected
#   if [[ $retstereo == "nAT" ]]; then
#      sed -i "/ HZ1 RET /d" $Project.pdb
#   fi
######
else
   cp $templatedir/carbret labelret
fi
#
# Converting the PDB into a format suitable for Gromacs by using pdb-to-gro.sh
# Output must be different if Dowser was used
#

./pdb-to-gro.sh $Project.pdb $dowser
if [[ -f ../arm.err ]]; then
   checkpdbdow=`grep 'pdb-to-gro' ../arm.err | awk '{ print $2 }'`
fi
if [[ $checkpdbdow -ne 0 ]]; then
   echo " An error occurred in pdb-to-gro.sh. I cannot go on..."
   echo ""
   echo "NewStep.sh 2 PDBtoGroProblem" >> ../arm.err
   exit 0
fi
#
# Backing up the starting PDB and renaming new.pdb (the output of pdb-to-gro.sh)
#
mv $Project.pdb $Project.pdb.old.2
mv new.pdb $Project.pdb
echo " $Project.pdb converted successfully! Now it will converted into $Project.gro, "
echo " the Gromacs file format"
echo ""

cp ../Chromophore/rtp amber94.ff
cp ../Chromophore/${chromophore}.pdb .
cd amber94.ff
cat rtp >> aminoacids.rtp
cd ..
cat ${chromophore}.pdb >> $Project.pdb

#
# pdb2gmx is the Gromacs utility for generating gro files and topologies
#
$gropath/pdb2gmx -f $Project.pdb -o $Project.gro -p $Project.top -ff amber94 -water tip3p 2> grolog
checkgro=`grep 'Writing coordinate file...' grolog`
   if [[ -z $checkgro ]]; then
      echo " An error occurred during the execution of pdb2gmx. Please look into grolog file"
      echo " No further operation performed. Aborting..."
      echo ""
      exit 0
   else
      echo " new.gro and its topology were successfully generated"
      echo ""
      carica=`grep 'Total charge in system' grolog | awk '{ print $5 }'`
      carica=${carica/.*}
      if [[ $carica -ne 0 ]]; then
         if [[ $carica -gt 0 ]]; then
            poschg=0
            negchg=$carica
         else
            poschg=$(($carica*(-1)))
            negchg=0 
         fi
      else
         poschg=0
         negchg=0
      fi
      rm grolog
   fi

#
# Generating the ndx file for moving H (frozen heavy atoms of the protein plus the O atoms of water
#
echo '2' > choices.txt
echo 'q' >> choices.txt
$gropath/make_ndx -f $Project.gro -o $Project.ndx < choices.txt
grep 'OW' $Project.gro | awk '{ print $3 }' > oxywat
echo "[ Group1 ]" >> $Project.ndx
cat oxywat >> $Project.ndx
rm oxywat choices.txt

backb=5
while  [[ $backb -ne 0 && $backb -ne 1 ]]; do
       echo ""
       echo " An energy minimization of the protein will be performed before"
       echo " embedding in the Solvent Box"
       echo ""
       echo " Please type 1 if you want to relax the backbone, 0 otherwise"
       echo ""
       echo ""
       read backb
done

cp $templatedir/ASEC/ndx-maker_mod.sh .
./ndx-maker_mod.sh $Project 5 $backb

$gropath/grompp -f standard-EM.mdp -c $Project.gro -n $Project.ndx -p $Project.top -o $Project.tpr

conver=10
iter=1
while [[ conver -ne 0 ]]; do
   $gropath/grompp -f standard-EM.mdp -c $Project.gro -n $Project.ndx -p $Project.top -o $Project.tpr

   echo ""
   echo " Please wait, minimizing, batch $iter of 1000 steps"
   echo ""

   $gropath/mdrun -s $Project.tpr -o $Project.trr -x $Project.xtc -c final-$Project.gro 2> grolog

   if grep -q "Steepest Descents did not converge to Fmax" md.log; then
      mkdir Iter_$iter
      mv ener.edr $Project.gro $Project.tpr $Project.trr md.log mdout.mdp Iter_$iter
      cp final-$Project.gro Iter_$iter
      mv final-$Project.gro $Project.gro
      iter=$(($iter+1))
   else
      if grep -q "Steepest Descents converged to Fmax" md.log; then
         conver=0
         echo ""
         echo " MM energy minimization seems to finish properly."
         cp $templatedir/ASEC/Solvent_box.sh ../
         echo " Hydrogen atoms and sidechains were minimized, then run Solvent_box.sh"
         echo ""
      else
         echo ""
         echo " There is a problem with the energy minimization. Please check it. Terminating..."
         echo ""
         exit 0
      fi
   fi
done

