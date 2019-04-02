#!/bin/bash
#
# Retrieving information from Infos.dat
#
Project=`grep "Project" Infos.dat | awk '{ print $2 }'`
mode=`grep "Mode " Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" Infos.dat | awk '{ print $2 }'`
heatmd=`grep "HeatMD" Infos.dat | awk '{ print $2 }'`
equimd=`grep "EquiMD" Infos.dat | awk '{ print $2 }'`
backb=`grep "BackBoneMD" Infos.dat | awk '{ print $2 }'`

# If the mode is minimization, the $Project.xyz file has to be used
# Otherwise the last snapshot from MD will be used.
# When Gromacs is used, the last snapshot is used for minimization with Gromacs
# When MD is run, some analysis is performed before going on
#
if [[ -d Analysis_Dyna ]]; then
   echo ""
   echo " The MD analysis has been found, I suppose you are happy with it..."
   echo ""
   mdanalysis=yes
else
   if [[ $mode == Dynamic ]]; then
      echo ""
      echo " No MD analysis found, going on with 2nd minimization..."
      echo ""
      mdanalysis=no
   else
      echo ""
      echo " No MD performed, going on with 2nd minimization..."
      echo ""
      mdanalysis=no
   fi
fi
#
# Checking if this is a restart
#
if [[ -d 2nd_minimization ]]; then
   ./smooth_restart.sh 2nd_minimization "Do you want to re-run the 2nd minimization? (y/n)" 3
   if [[ ! -f Infos.dat ]]; then
      mv no.Infos.dat Infos.dat
      exit 0
   fi
fi
mkdir 2nd_minimization/
cd 2nd_minimization
cp $templatedir/standard-EM.mdp .
cp $templatedir/soglia .
cp $templatedir/minimization.sh .
cp -r ../Dynamic/amber94.ff .
if [[ $mode == "Minimization" ]]; then
   cp ../Dynamic/final-$Project.gro $Project.gro
   cp ../Dynamic/${Project}.top .
   cp ../Dynamic/*.itp .
   cp ../Dynamic/ndx-maker.sh .
   ./ndx-maker.sh $Project 2 0 n
else
   if [[ $mdanalysis == yes ]]; then
      cp ../Analysis_Dyna/cursel.log .
      cp ../Analysis_Dyna/${Project}.ndx .
   else
      cp ../Dynamic/$Project.ndx .
   fi
   cp $templatedir/extraver.sh .
   cp ../Dynamic/$Project.gro .
   cp ../Dynamic/$Project.tpr .
   cp ../Dynamic/output/${Project}.top  .
   cp ../Dynamic/output/${Project}.trr .
   cp ../Dynamic/output/*.itp .
fi
#
# Ask the user about using the last snapshot or the nearest-to-average frame
#
if [[ $mode == Dynamic ]]; then
   echo " Do you want to use the nearest-to-average frame? (y/n)"
   echo ""
   read risposta
   while [[ $risposta != y && $risposta != n ]]; do
         echo " Wrong answer! Please type y or n"
         echo ""
         read risposta
   done
   checkrest=`grep 'ReStRun_3' ../Infos.dat | wc -l`
   if [[ $risposta == y ]]; then
      initprod=$(($heatmd+$equimd+1))
      echo " Generating the nearest-to-average structure..."
      echo ""
      ./extraver.sh $Project $initprod ../cavity $backb
      numframe=`tail -n1 lowrmsd.dat`
      echo '0' > choice.txt
      $gropath/trjconv -s $Project.tpr -f $Project.trr -o average-$Project.gro -dump $numframe < choice.txt
      rm choice.txt
      mv $Project.gro preMD_$Project.gro
      cp average-$Project.gro $Project.gro
      ../update_infos.sh $checkrest "PostMD_Geom" "Average" ../Infos.dat
   else
      echo " Getting the last snapshot..."
      echo ""
      mv $Project.gro preMD_$Project.gro
      cp ../Dynamic/output/final-${Project}.gro $Project.gro
      ../update_infos.sh $checkrest "PostMD_Geom" "Last" ../Infos.dat
   fi
fi
sleep 1
#
# grompp is called to generate the tpr file for subsequent mdrun.
# the standard-EM.mdp input file must exist
#
if [[ -f standard-EM.mdp ]]; then
   sed -i "s|Protein-H Group1|GroupDyna|" standard-EM.mdp
   sed -i "s|Y Y Y Y Y Y|Y Y Y|" standard-EM.mdp
   $gropath/grompp -f standard-EM.mdp -c ${Project}.gro -n ${Project}.ndx -p ${Project}.top -o ${Project}.tpr > grolog
   checkmpp=`grep 'This run will generate roughly' grolog`
   if [[ -z $checkmpp ]]; then
      echo " An error occurred during the execution of grompp. Please look into grolog file"
      echo " No further operation performed. Aborting..."
      echo ""
      exit 0
   else
      echo " ${Project}.tpr was successfully generated. Now I'm going to run the minimization"
      echo ""
      rm grolog
   fi
else
   echo " standard-EM.mdp for 2nd minimization not found!"
   echo " Aborting..."
   echo ""
   exit 0
fi
#
# Calling the script for minimization
#
./minimization.sh

# The folder conversion is created to convert gro into pdb into Tinker xyz
#
echo " Converting final-$Project.gro into $Project-final.pdb,"
echo " to get atom selections and the xyz file"
echo ""
cd ..
if [[ -d conversion ]]; then
      k=1
      while [[ -d $k.conversion ]]; do
            k=$(($k+1))
      done
      mv conversion $k.conversion
fi
mkdir conversion
cp 2nd_minimization/final-$Project.gro conversion/
cd conversion/

# editconf convert it to PDB and pdb-format-new fixes the format to
# allow Tinker reading
#
cp $templatedir/pdb-format-new.sh .
$gropath/editconf -f final-${Project}.gro -o final-$Project.pdb -label A
./pdb-format-new.sh final-$Project.pdb

# Storing the serial numbers of the selection to be used for QM/MM,
# by reading cavity and Infos.dat files
#
#if [[ $modality == Cavity ]]; then
#   residline=`tr '\n' ' ' < ../cavity`
#   if [[ $backb -eq 0 ]]; then
#      backsel="and sidechain"
#   fi
#   acqua="or ((same residue as (all within 4 of (resname RET and not name N H CA HA C O CB CG CD HB1 HB2 HG1 HG2 HD1 HD2))) and water)"
#   selection=`echo "(resid $residline $backsel) $acqua"`
#cat > qmsel.tcl << VMD1
#mol new final-tk.pdb
#mol delrep 0 top
#set babbeo [ atomselect top "$selection" ]
#set nogo [\$babbeo get serial]
#set fileser serials.dat
#set file2Id [open \$fileser "w"]
#puts -nonewline \$file2Id \$nogo
#close \$file2Id
#exit
#VMD1
#fi

# pdbxyz conversion
#
mv final-tk.pdb $Project-tk.pdb
$tinkerdir/pdbxyz $Project-tk.pdb << EOF
ALL
../$prm
EOF

# Preparing the files for the following step
#
cp $Project-tk.xyz ../
cd ..
cp $templatedir/keymaker.sh .
./keymaker.sh $Project-tk $prm.prm
cp $templatedir/Molcami_SCF.sh .
echo ""
echo " Now run Molcami_SCF.sh to start the QM/MM calculations"
echo ""

