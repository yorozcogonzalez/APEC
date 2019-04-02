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
chromophore=`grep "chromophore" Infos.dat | awk '{ print $2 }'`
dimer=`grep "Dimer" Infos.dat | awk '{ print $2 }'`
amber=`grep "AMBER" Infos.dat | awk '{ print $2 }'`

cd Minimize_${Project}
rm -rf $amber.ff *.itp *.top $Project.gro
cp ../Chromophore/${chromophore}.pdb .
cp -r $templatedir/$amber.ff .
cd $amber.ff/
#cp amino-rettrans aminoacids.rtp
#cp normalamino-h aminoacids.hdb
cp ../../RESP_charges/new_rtp .
cat new_rtp >> aminoacids.rtp
cd ..

wat=`grep "DOWSER_wat" ../Infos.dat | awk '{ print $2 }'`
nwat=$(($wat+$wat+$wat))
if [[ $nwat -gt 0 ]]; then
   numchromo=`grep -c " CHR " ${chromophore}.pdb`
   lineas=`wc -l $Project.pdb | awk '{ print $1 }'`
   head -n $(($lineas-$nwat)) $Project.pdb > proteina
   tail -n $nwat $Project.pdb > tempwat
   cat ${chromophore}.pdb >> proteina
   head -n $(($lineas+$numchromo-$nwat)) proteina > proteina2
   cat tempwat >> proteina2
   mv proteina2 $Project.pdb
   rm proteina
else
   cat ${chromophore}.pdb >> $Project.pdb
fi



#
# pdb2gmx is the Gromacs utility for generating gro files and topologies
#
$gropath/pdb2gmx -f $Project.pdb -o $Project.gro -p $Project.top -ff $amber -water tip3p 2> grolog
checkgro=`grep 'Writing coordinate file...' grolog`
   if [[ -z $checkgro ]]; then
      echo " An error occurred during the execution of pdb2gmx. Please look into grolog file"
      echo " No further operation performed. Aborting..."
      echo ""
      exit 0
   else
      echo " new.gro and its topology were successfully generated"
      echo ""
      rm grolog
   fi

#
# Generating the ndx file for moving H (frozen heavy atoms of the protein plus the O atoms of water
#
echo '2' > choices.txt
echo 'q' >> choices.txt
$gropath/make_ndx -f $Project.gro -o $Project.ndx < choices.txt
grep -n 'OW' $Project.gro | cut -d : -f 1 > temporal
awk '$1=$1-2' temporal > oxywat
echo "[ Group1 ]" >> $Project.ndx
cat oxywat >> $Project.ndx
rm oxywat choices.txt

backb=5
while  [[ $backb -ne 0 && $backb -ne 1 ]]; do
       echo " **************************************************************"
       echo " An energy minimization of the protein will be performed before"
       echo " embedding in the Solvent Box"
       echo ""
       echo " Please type 1 if you want to relax the backbone, 0 otherwise"
       echo " **************************************************************"
       echo ""
       read backb
done

cp $templatedir/ASEC/ndx-maker_mod.sh .
./ndx-maker_mod.sh $Project 5 $backb



#         ans="b"
#         while [[ $ans != "y" ]]; do
#            echo "******************************************************************"
#            echo ""
#            echo " This is to modify the ndx if needded. Continue? (y/n)"
#            echo ""
#            echo "******************************************************************"
#            read ans
#         done


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
         echo ""
      else
         echo ""
         echo " There is a problem with the energy minimization. Please check it."
         echo ""
         ans="b"
         while [[ $ans != "y" && $ans != "n" ]]; do
            echo "******************************************************************"
            echo ""
            echo " Do you still want to continue? (y/n)"
            echo ""
            echo "******************************************************************"
            read ans
         done
         if [[ $ans == "n" ]]; then
            exit 0
         else
            conver=0
         fi
      fi
   fi
done

cd ..

continua="a"
while [[ $continua != "y" && $continua != "n" ]]; do
echo " ****************************************************************"
echo " The protein will be embbeded in a solvent box."
echo " Afterward it will be energetically minimized, followed by a NPT"
echo " molecular dynamic."
echo " Continue? (y/n)"
echo " ****************************************************************"
read continua
done

if [[ $continua == "n" ]]; then
   echo ""
   echo " Aborting..."
   echo ""
   exit 0
fi

echo " ****************************************************************"
echo " Please define the size of the cubic box in nanometers (i.e 7.0)."
echo " For a single proteins 7.0 is normally ok."
echo " For a dimer, maybe 10.0 is fine"
echo " ****************************************************************"
read box



relaxpr=y
./update_infos.sh "Relax_protein" "$relaxpr" Infos.dat

if [[ $relaxpr == "y" ]]; then
   relaxbb=b
   while [[ $relaxbb != y && $relaxbb != n ]]; do
      echo ""
      echo " Relax backbone? (y/n)"
      echo ""
      read relaxbb
   done
   ./update_infos.sh "Relax_backbone" "$relaxbb" Infos.dat
else
   ./update_infos.sh "Relax_backbone" "n" Infos.dat 
fi

mkdir Dynamic
cd Dynamic
mkdir Box
cd ..
cd Minimize_$Project
cp -r $amber.ff *.itp $Project.top residuetypes.dat ../Dynamic/Box
cp final-$Project.gro ../Dynamic/Box/$Project.gro
cd ..
cd Dynamic/Box

$gropath/editconf -f $Project.gro -bt cubic -box $box $box $box -o ${Project}_box_init.gro -c
$gropath/genbox -cp ${Project}_box_init.gro -cs spc216.gro -o ${Project}_box_sol_init.gro -p $Project.top >& genbox.out

### This is for excluding the water molecules from the solvent box that can be added inside the 
### Retinal cavity (8 A) or in any free space of the protein (1 A from protein, sometimes this 
### may bring problems in the minimization).

cp ${Project}_box_sol_init.gro Interm.gro

selection="((same residue as all within 0.5 of protein) and resname SOL) or ((same residue as all within 2 of resname CHR) and resname SOL)"

# TCL script for VMD: open file, apply selection, save the serial numbers into a file
#
echo -e "mol new Interm.gro" > removewat.tcl
echo -e "mol delrep 0 top" >> removewat.tcl
line1="set sele [ atomselect top \"$selection\" ]" 
echo -e "$line1" >> removewat.tcl
echo -e 'set numbers [$sele get serial]' >> removewat.tcl
line2="set filename Interwat"
echo -e "$line2" >> removewat.tcl
echo -e 'set fileId [open $filename "w"]' >> removewat.tcl
echo -e 'puts -nonewline $fileId $numbers' >> removewat.tcl
echo -e 'close $fileId' >> removewat.tcl
echo -e "exit" >> removewat.tcl
vmd -e removewat.tcl -dispdev text
rm removewat.tcl
echo ""
echo ""
echo " Please wait ..."

cp Interm.gro Interm_yoe.gro


numinit=`head -n2 $Project.gro | tail -n1 | awk '{ print $1 }'`
col=`awk '{print NF}' Interwat`
cont=0
for i in $(eval echo "{1..$col}")
do
   rem=`expr $i % 3`
   indx=`awk -v j=$i '{ print $j }' Interwat`
   if [[ $indx -gt $numinit ]]; then
      cont=$(($cont+1))
      if [[ $rem -eq 1 ]]; then
         sed -i "/  OW$indx /d" Interm.gro
         sed -i "/  OW $indx /d" Interm.gro
         sed -i "/  OW  $indx /d" Interm.gro
         sed -i "/  OW   $indx /d" Interm.gro
         sed -i "/  OW    $indx /d" Interm.gro
      else
         if [[ $rem -eq 2 ]]; then
            sed -i "/ HW1$indx /d" Interm.gro
            sed -i "/ HW1 $indx /d" Interm.gro
            sed -i "/ HW1  $indx /d" Interm.gro
            sed -i "/ HW1   $indx /d" Interm.gro
            sed -i "/ HW1    $indx /d" Interm.gro
         else
            sed -i "/ HW2$indx /d" Interm.gro
            sed -i "/ HW2 $indx /d" Interm.gro
            sed -i "/ HW2  $indx /d" Interm.gro
            sed -i "/ HW2   $indx /d" Interm.gro
            sed -i "/ HW2    $indx /d" Interm.gro
         fi
      fi
   fi
done

numatm=`head -n2 Interm.gro | tail -n1 | awk '{ print $1 }'`
newnum=$(($numatm-$cont))
head -n1 Interm.gro > ${Project}_box_sol.gro
echo "$newnum" >> ${Project}_box_sol.gro
tail -n$(($numatm-$cont+1)) Interm.gro >> ${Project}_box_sol.gro
#rm Interm.gro

########################

echo '2' > choices.txt
echo 'q' >> choices.txt
$gropath/make_ndx -f ${Project}_box_sol.gro -o ${Project}_box_sol.ndx < choices.txt
rm choices.txt

addwat=`tail -n1 $Project.top | awk '{ print $2 }'`
wattop=$((($addwat*3-$cont)/3))

lines=`wc -l $Project.top | awk '{ print $1 }'`
cp $Project.top tempo
head -n$(($lines-1)) tempo > ${Project}_box_sol.top
echo -e "SOL              $wattop" >> ${Project}_box_sol.top
rm tempo

mkdir ../Minimization
cp $templatedir/ASEC/min_sol.mdp ../Minimization
cp -r $amber.ff *.itp residuetypes.dat ../Minimization
cp ${Project}_box_sol.gro ${Project}_box_sol.ndx ${Project}_box_sol.top ../Minimization

cd ../Minimization

chratoms=`head -n1 ../../Chromophore/$chromophore.xyz | awk '{ print $1 }'`

if [[ $relaxpr == y ]]; then
   if [[ $relaxbb == n ]]; then
      selection="backbone or resname CHR"
      # TCL script for VMD: open file, apply selection, save the serial numbers into a file
      #
      echo -e "mol new ${Project}_box_sol.gro type gro" > ndxsel.tcl
      echo -e "mol delrep 0 top" >> ndxsel.tcl
      riga1="set babbeo [ atomselect top \"$selection\" ]"
      echo -e "$riga1" >> ndxsel.tcl
      echo -e 'set noah [$babbeo get serial]' >> ndxsel.tcl
      riga3="set filename dinabb"
      echo -e "$riga3" >> ndxsel.tcl
      echo -e 'set fileId [open $filename "w"]' >> ndxsel.tcl
      echo -e 'puts -nonewline $fileId $noah' >> ndxsel.tcl
      echo -e 'close $fileId' >> ndxsel.tcl
      echo -e "exit" >> ndxsel.tcl
      vmd -e ndxsel.tcl -dispdev text

      num=`awk '{print NF}' dinabb`
      for i in $(eval echo "{1..$num}")
      do
        awk -v j=$i '{ print $j }' dinabb >> dina
      done
   else
#
# Selecting the atoms of the chromophore plus the fixed and LQ, LM
# to be fixed during the MD
#
      grep -n 'CHR ' ${Project}_box_sol.gro | cut -d : -f 1 > temporal1
      awk '$1=$1-2' temporal1 > dina
      rm -f dina2
      for i in $(eval echo "{1..$chratoms}"); do
         atmtype=`head -n $(($i+2)) ../../Chromophore/$chromophore.xyz | tail -n1 | awk '{ print $6 }'`
         if [[ $atmtype == "QM" || $atmtype == "MM" || $atmtype == "LM" || $atmtype == "LQ" ]]; then
            head -n $i dina | tail -n1 | awk '{ print $1 }' >> dina2
         fi
      done
      mv dina2 dina
      num=`grep -c "CHR " ${Project}_box_sol.gro | awk '{ print $1 }'`
   fi
   if [[ $dimer == "YES" ]]; then
      chrnum=`grep -c "CHR " ${Project}_box_sol.gro | awk '{ print $1 }'`
      head -n $(($num-$chrnum+$chrnum/2)) dina > dinadimer
      mv dinadimer dina 
   fi
fi

tr '\n' ' ' < dina > dyna
echo ":set tw=75" > shiftline.vim
echo ":normal gqw" >> shiftline.vim
echo ":x" >> shiftline.vim
vim -es dyna < shiftline.vim
echo "[ GroupDyna ]" >> ${Project}_box_sol.ndx
cat ${Project}_box_sol.ndx dyna > last.ndx
mv last.ndx ${Project}_box_sol.ndx

sed -i "s/;freezegrps = GroupDyna/freezegrps = GroupDyna/g" min_sol.mdp
sed -i "s/;freezedim = Y Y Y/freezedim = Y Y Y/g" min_sol.mdp


$gropath/grompp -f -maxwarn 2 min_sol.mdp -c ${Project}_box_sol.gro -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -o ${Project}_box_sol.tpr
   
###################################################################
##  Adding ions to the Solvent Box for neutralizing the charge  ###
###################################################################

if [[ $charge -ne 0 ]]; then
   echo ""
   echo ""
   echo "*********************************************************************"
   echo " The total charge is not zero. CL or NA ions will be added randomly"
   echo " to the solvent box for neutraizing the system."
   echo " Please be sure that the \"SOL\" group will be selected next"
   echo "*********************************************************************"
   echo ""
   echo ""
   mkdir Add_Ion
   mv ${Project}_box_sol.tpr ${Project}_box_sol.ndx ${Project}_box_sol.top ${Project}_box_sol.gro Add_Ion
   cd Add_Ion
   numpro=`head -n2 ../../Box/$Project.gro | tail -n1 | awk '{ print $1 }'`

# This while is used for ensuring that the ions will not been generated inside the proteins
   res=0
   seed=111
   count=0
   while [[ $res -eq 0 ]]; do
      replace=0
      replacectl=0
      if [[ $charge -lt 0 ]]; then
         pcharge=$(echo "-1*$charge" | bc)
         if [[ -f back_${Project}_box_sol.top ]]; then
            cp back_${Project}_box_sol.top ${Project}_box_sol.top
         else
            cp ${Project}_box_sol.top back_${Project}_box_sol.top
         fi
         $gropath/genion -seed $seed -s ${Project}_box_sol.tpr -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -pname NA -pq 1 -np $pcharge -o ${Project}_box_sol_ion.gro 2> addedions << EOF
15
EOF
         
         ../../../update_infos.sh "Added_Ions" "${pcharge}_NA" ../../../Infos.dat

         lin=`grep -c "Replacing solvent molecule" addedions`
         for i in $(eval echo "{1..$lin}")
         do
            replace=`grep "Replacing solvent molecule" addedions | head -n $i | tail -n1 | awk '{ print $6 }' | sed 's/[^0-9]//g'`
         if [[ $replace -le $numpro ]]; then
            replacectl=$(($replacectl+1))
         fi
         done
      fi
      if [[ $charge -gt 0 ]]; then
         if [[ -f back_${Project}_box_sol.top ]]; then
            cp back_${Project}_box_sol.top ${Project}_box_sol.top
         else
            cp ${Project}_box_sol.top back_${Project}_box_sol.top
         fi
         $gropath/genion -seed $seed -s ${Project}_box_sol.tpr -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -nname CL -nq -1 -nn $charge -o ${Project}_box_sol_ion.gro 2> addedions << EOF
15
EOF
         ../../../update_infos.sh "Added_Ions" "${charge}_CL" ../../../Infos.dat

         lin=`grep -c "Replacing solvent molecule" addedions`
         for i in $(eval echo "{1..$lin}")
         do
            replace=`grep "Replacing solvent molecule" addedions | head -n $i | tail -n1 | awk '{ print $6 }' | sed 's/[^0-9]//g'`
         if [[ $replace -le $numpro ]]; then
            replacectl=$(($replacectl+1))
         fi
         done
   
      fi
#
#  This while is for being sure that the SOL group has been selected in genion for placing the ions.
#  In other systems it could be defferent from 13 and it should be corrected.
#
      soll=b
      while [[ $soll != "y" && $soll != "n" ]]; do
         echo ""
         echo " Was selected the \"SOL\" group for adding the ions? (y/n)"
         echo ""
         read soll
         if [[ $soll == "n" ]]; then
            echo ""
            echo " Modify this script in order to sellect the right"
            echo " number of the \"SOL\" group"
            echo " Terminating ..."
            echo ""
            exit 0
         fi
      done

      if [[ $replacectl -eq 0 ]]; then
         res=10

         cp ${Project}_box_sol_ion.gro ../${Project}_box_sol.gro
         cp ${Project}_box_sol.top ../${Project}_box_sol.top

         cd ..
         echo '2' > choices.txt
         echo 'q' >> choices.txt
         $gropath/make_ndx -f ${Project}_box_sol.gro -o ${Project}_box_sol.ndx < choices.txt
         rm choices.txt
         echo "[ GroupDyna ]" >> ${Project}_box_sol.ndx
         cat ${Project}_box_sol.ndx dyna > last.ndx
         mv last.ndx ${Project}_box_sol.ndx
         rm dyna
      else
         seed=$(($seed+3))
      fi
   done
fi

###########################################################

conver=10
iter=1
if [[ $dimer == "YES" ]]; then
   sed -i "s/emtol                   = 100/emtol                   = 500/" min_sol.mdp
fi
while [[ conver -ne 0 ]]; do
   $gropath/grompp -f -maxwarn 2 min_sol.mdp -c ${Project}_box_sol.gro -n ${Project}_box_sol.ndx -p ${Project}_box_sol.top -o ${Project}_box_sol.tpr

   echo ""
   echo " Please wait, minimizing, batch $iter of 1000 steps"
   echo ""

   $gropath/mdrun -s ${Project}_box_sol.tpr -o ${Project}_box_sol.trr -x ${Project}_box_sol.xtc -c final-${Project}_box_sol.gro 2> grolog

   if grep -q "Steepest Descents did not converge to Fmax" md.log; then
      mkdir Iter_$iter
      mv ener.edr ${Project}_box_sol.gro ${Project}_box_sol.tpr ${Project}_box_sol.trr md.log mdout.mdp Iter_$iter
      cp final-${Project}_box_sol.gro Iter_$iter
      mv final-${Project}_box_sol.gro ${Project}_box_sol.gro
      iter=$(($iter+1))
   else 
      if grep -q "Steepest Descents converged to Fmax" md.log; then
         conver=0  
         echo ""
         echo " MM energy minimization seems to finished properly."
         moldy=r
         while [[ $moldy != "NPT" && $moldy != "NVT" ]]; do
            echo ""
            echo " What ensemble will use for the MD along the iterative procedure (NPT or NVT)"
            echo ""
            echo ""
            read moldy
         done
         ../../update_infos.sh "MD_ensemble" "$moldy" ../../Infos.dat
         if [[ $moldy == "NVT" ]]; then
            echo ""
            echo " Continuum with the MD_NPT.sh for equilibrating the pressure."
            echo ""
            echo ""
         else
            echo ""
            echo " Continuum with the MD_NPT.sh."
            echo ""
            echo ""
         fi
         cp $templatedir/ASEC/MD_NPT.sh ../../
      else
         echo ""
         echo " There is a problem with the energy minimization. Please check it. Terminating..."
         echo ""
         exit 0
      fi
   fi
done

