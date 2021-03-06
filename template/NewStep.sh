#!/bin/bash
#
#
# Retrieving project name, parameter file, template folder and Tinker path from Infos.dat
#
Project=`grep "Project" Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" Infos.dat | awk '{ print $2 }'`
dowser=`grep "Dowser" Infos.dat | awk '{ print $2 }'`
chromophore=`grep "chromophore" Infos.dat | awk '{ print $2 }'`
chr=`grep "Chromo_Charge" Infos.dat | awk '{ print $2 }'`
amber=`grep "AMBER" Infos.dat | awk '{ print $2 }'`

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
cp -r $templatedir/$amber.ff .

#cd amber.ff/
#cp normalamino-h aminoacids.hdb
#cp amino-rettrans aminoacids.rtp
#cd ..

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
######
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

wat=`grep -c "OW  HOH" $Project.pdb`
../update_infos.sh "DOWSER_wat" $wat ../Infos.dat

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
# RESP charges calculation
#
echo " **********************************************************************"
echo ""
echo " The Gromacs - Tinker templates will be created"
echo ""
echo " **********************************************************************"
cd ..

mkdir Templates
cp Minimize_$Project/$Project.gro Templates
cp $templatedir/$prm.prm Templates
cd Templates
sed -i "s/HOH/SOL/g" $Project.gro

#
# editconf convert it to PDB and pdb-format-new fixes the format to
# allow Tinker reading
#
cp $templatedir/ASEC/pdb-format-new_mod.sh .
$gropath/editconf -f ${Project}.gro -o $Project.pdb -label A
./pdb-format-new_mod.sh $Project.pdb

#
# pdbxyz conversion
#
mv final-tk.pdb $Project-tk.pdb

# If PRO is a terminal residue (N-terminal or residue 1) the extra hydrogen is labeled in 
# GROMACS as H2, being H1 and H2 the hydrogens bonded to the N. But in TINKER
# (specifically in the pdbxyz) these hydrogens are labeled as H2 and H3. So, it will be relabeled.
# This is also performed in MD_2_QMMM.sh
sed -i "s/ATOM      3  H2  PRO A   1 /ATOM      3  H3  PRO A   1 /" $Project-tk.pdb
sed -i "s/ATOM      2  H1  PRO A   1 /ATOM      2  H2  PRO A   1 /" $Project-tk.pdb

$tinkerdir/pdbxyz $Project-tk.pdb << EOF
ALL
$prm
EOF
echo " Please wait ..."

numatoms=`head -n2 $Project.gro | tail -n1 | awk '{ print $1 }'`

cp $templatedir/ASEC/Templates_gro_tk.f .
sed -i "s|numero|$numatoms|g" Templates_gro_tk.f

cp $Project.gro final_Config.gro
cp $Project-tk.xyz coordinates_tk.xyz
#   cp $templatedir/residuetypes.dat .
gfortran Templates_gro_tk.f -o Templates_gro_tk.x
./Templates_gro_tk.x
rm final_Config.gro
rm coordinates_tk.xyz
cp template_tk2gro ../
cp template_gro2tk ../

cd ..
mkdir RESP_charges
cp Chromophore/${chromophore}.xyz RESP_charges
cp Templates/$Project-tk.xyz RESP_charges/final.xyz
cp Templates/$prm.prm RESP_charges

cd RESP_charges
echo "New labels" > check_chromo
echo "" >> check_chromo
echo " $chr 1" > chromo.com
numchromo=`head -n1 ${chromophore}.xyz | awk '{ print $1 }'`

for i in $(eval echo "{1..$numchromo}")
do
   label=`head -n $(($i+2)) ${chromophore}.xyz | tail -n1 | awk '{ print $1 }'`
   att=`head -n $(($i+2)) ${chromophore}.xyz | tail -n1 | awk '{ print $1 }' | awk '{print substr ($0, 0, 1)}'`
   echo $label >> check_chromo
   xyz=`head -n $(($i+2)) ${chromophore}.xyz | tail -n1 | awk '{ print $2"   "$3"   "$4 }'`
   echo "$att     $xyz" >> chromo.com
done
echo "" >> chromo.com

multchain=`grep "MultChain" ../Infos.dat | awk '{ print $2 }'`
if [[ $multchain == "YES" ]]; then
   answer="b"
   while [[ $answer != "y" && $answer != "n" ]]; do
      echo ""
      echo "*****************************************************"
      echo " This seems to be a multi-chain protein. So, if this"
      echo " is a dimer calculation (one chromophore per chain)"
      echo " you must provide later the full path of the charges file"
      echo ""
      echo " Is this a dimer calculation? (y/n)"
      echo "*****************************************************"
      read answer
   done
   if [[ $answer == "y" ]]; then
      ../update_infos.sh "Dimer" "YES" ../Infos.dat
   else
      ../update_infos.sh "Dimer" "NO" ../Infos.dat
   fi
else
   answer="n"
   ../update_infos.sh "Dimer" "NO" ../Infos.dat
fi

###
### Definining the type of chromophore (quinine, semi quino, ...)
###
option=0
while [[ $option -ne 1 && $option -ne 4 ]]; do
   echo ""
   echo " Please select the Flavin model to use:"
   echo " !! Options 2 and 3, not ready yet. Coming soon !!"
   echo ""
   echo " 1) Quinone"
   echo " 2) Semi-quinone"
   echo " 3) Hydro-quinone"
   echo " 4) Gadda"
   echo ""
   read option
done

if [[ $answer == "n" ]]; then

   echo " **********************************************************************"
   echo ""
   echo " The charges of the Chromophore will be fit now by using the RESP model"
   echo ""
   echo " **********************************************************************"

   if [[ $option -eq 1 ]]; then
      if [[ $chr -eq -2 ]]; then
         diff -y $templatedir/ASEC/RESP/Quinone_0_labels_order check_chromo
         ../update_infos.sh "CHR_RESP" "Quinone_0" ../Infos.dat
      fi
      if [[ $chr -eq -3 ]]; then
         diff -y $templatedir/ASEC/RESP/Quinone_neg_labels_order check_chromo
         ../update_infos.sh "CHR_RESP" "Quinone_neg" ../Infos.dat
      fi
      if [[ $chr -ne -3 && $chr -ne -2 ]]; then
         echo ""
         echo " There is something wrong with the charge definition of the system"
         echo " Aborting ..."
         echo ""
         exit 0
      fi
   fi

   if [[ $option -eq 4 ]]; then
      if [[ $chr -eq -3 ]]; then
         diff -y $templatedir/ASEC/RESP/Gadda_labels_order check_chromo
         ../update_infos.sh "CHR_RESP" "Gadda" ../Infos.dat
      fi
      if [[ $chr -ne -3 ]]; then
         echo ""
         echo " There is something wrong with the charge definition of the system"
         echo " Aborting ..."
         echo ""
         exit 0
      fi
   fi
   echo ""
   echo ""
   echo " Please check that the labels of the Chromophore (New labels)"
   echo " are exactly in the same order as in the Reference."
   echo " If they are different, the chromophore atoms sequence must be re-orginized"
   echo " in the initial xyz file."
   echo " Or, new RESP input files (resp1.in and resp2.in) must be created."
   echo ""


   order="b"
   while [[ $order != "y" && $order != "n" ]]; do
      echo ""
      echo " Is the order the same? (y/n)"
      echo ""
      read order
   done

   if [[ $order == "n" ]]; then
      echo ""
      echo " Please modify the atom sequence in the initial xyz file of"
      echo " the chromophore before continue"
      echo ""
      exit 0
   else
      echo ""
      echo " Continuing ..."
      echo ""
   fi
   #
   #taking the charges from parameters file
   #
   ncharges=`grep -c "charge " $prm.prm`
   grep "charge " $prm.prm > charges

   #
   # writing the point charges to chromo.com, not including the chromophore
   #
   total=`head -n1 final.xyz | awk '{ print $1 }'`

   if [ -f tempRET ]; then
      rm tempRET
   fi
   echo "" >> final.xyz

cat > charges.f << YOE
      Program charges
      implicit real*8 (a-h,o-z)
      character line3*3,line7*7
      dimension coorx($total),coory($total),coorz($total)
     &          ,charge(9999),indi($total)

      open(1,file='final.xyz',status='old')
      open(2,file='charges',status='old')
      open(3,file='tempRET',status='unknown')

      read(1,*)
      do i=1,$total
         read(1,*)ini,line3,coorx(i),coory(i),coorz(i),indi(i)
      enddo

      do i=1,$ncharges
         read(2,*)line7,ind,value
         charge(ind)=value
      enddo
      do i=1,$total
         write(3,'(1x,3(f10.6,3x),f9.6)')coorx(i),coory(i),
     &        coorz(i),charge(indi(i))
      enddo
      end
YOE
   gfortran charges.f -o charges.x
   ./charges.x
   rm charges.x

   cat tempRET >> chromo.com
   echo "" >> chromo.com

   rm charges

   cp $templatedir/ASEC/RESP/RESP.com .

   cat RESP.com chromo.com > ${Project}_RESP.com
   rm RESP.com chromo.com

   cp $templatedir/ASEC/SUBMIGAU .
   sed -i "s/PROJECTO/${Project}_RESP/" SUBMIGAU

   SUBCOMMAND SUBMIGAU

   echo ""
   echo ""
   echo " ***********************************************************************"
   echo ""
   echo " Gaussian calculation submitted (HF/6-31G* plus ASEC) for generating the"
   echo " Molecular Electrostatic Potential (MEP)."
   echo ""
   echo " When this calculation is done, execute fitting_RESP.sh"
   echo ""
   echo " ***********************************************************************"
   echo ""
   echo ""
else
   filecheck=b
   while [[ $filecheck != "OK" ]]; do
      echo ""
      echo "**********************************************************"
      echo " Please provide the full path of the charges file,"
      echo " i.e. /home/.../new_charges"
      echo "**********************************************************"
      echo ""
      read chargepath
      if [[ -f $chargepath ]]; then
         filecheck="OK"
      fi
   done

   if [[ $option -eq 1 ]]; then
      ../update_infos.sh "iLOV_RESP" "iLOV" ../Infos.dat
   else
      ../update_infos.sh "iLOV_RESP" "iLOV_chain" ../Infos.dat
   fi

   cp $chargepath new_charges
   num=$(($numchromo/2))
   head -n $num new_charges > tempo
   head -n $num new_charges >> tempo
   echo "" >> tempo
   mv tempo new_charges
   cp new_charges ../
fi

cd ..
cp $templatedir/ASEC/fitting_RESP.sh .
sed -i "s/STATFIT/GRO/" fitting_RESP.sh

