#!/bin/bash
#
# Copying generic Infos.dat from installation directory
# If Infos.dat already exists, the script terminates to avoid overwriting
#
if [ -f Infos.dat ]; then
   echo ""
   echo " ARM fatal error - Infos.dat is existing"
   echo " The new project must start in a folder with no other ARM projects"
   echo " Just create a suitable directory, move New.sh there and run it"
   echo ""
   echo " New.sh is terminating"
   exit 0
fi

camino=INSTALLDIR/template
cp $camino/Infos.dat .

# Asking the name of the project
#
echo ""
echo ""
echo ""
echo ""
echo "*****************************************************************************************************"
echo "*****************************************************************************************************"
echo ""
echo "          *           ***    *******      ***            ********  *******    *****                  "
echo "         ***        **   **  **         **   **          **        **        **   **                 "
echo "        ** **      **        **        **                **        **       **                       "
echo "       **   **       ****    ******    **         ***    ******    ******   **  *****                "
echo "      *********          **  **        **                **        **       **     **                "
echo "     **       **   **   **   **         **   **          **        **        **   **                 "
echo "    **         **    ***     *******      ***            **        *******    *****                  "
echo ""
echo ""
echo "                                                                Gozem Lab., Georgia State University "
echo "                                                   Last version, Sept/2018 by Yoelvis Orozco-Gonzalez"
echo "*****************************************************************************************************"
echo "*****************************************************************************************************"
echo ""
echo ""
echo ""

echo " What is the name of the project (the name MUST not start with a number)??"
read Project
echo ""

if [ -d Step_0 ]; then
      echo " Folder \"Step_0\" found! Something is wrong ..."
      echo " Terminating ..."
      exit 0
      echo ""
fi
mkdir Step_0

# Finding all the PDB files in the current folder
i=1
ext=pdb
for f in *.$ext; do
    filelist[$i]=$f
    i=$(($i+1))
done
i=$(($i-1))

# Variable len counts how many PDB files are in the folder, len+1 is required for ending
# the while loop smoothly. Here the user is asked to select which PDB file has to be used
#
len=${#filelist[*]}
echo ""
echo " Select within $len files $ext:"
echo " (This should be the pdb file of the protein without the chromophore)"
echo ""
len=$(($len+1))
i=1
while [ $i -lt $len ]; do
      echo " $i: ${filelist[$i]}"
      let i++
done
echo ""
read choice
if [ -z ${filelist[$choice]} ]; then
   echo " Option unavailable. The program is closing..."
   rm -r Step_0
   exit 0
else
   pdbfile=${filelist[$choice]}
   pdb=$(basename $pdbfile .pdb)
   echo " You just selected ${filelist[$choice]}"
   echo ""
fi
cp $pdb.pdb Step_0/${Project}.pdb
if [ -f *.prm ]; then
   cp *.prm Step_0/
fi
mv Infos.dat Step_0/
if [[ -f seqmut ]]; then
   cp Step_0/${Project}.pdb Step_0/wt_${Project}.pdb
   cp seqmut Step_0/
   cp $camino/mutate.sh Step_0/
fi
cd Step_0/

# Counts and tells the user the total charge of a system
#
plusc=`awk '{ print $4 " " $5 " " $6 }' ${Project}.pdb | uniq | awk '{ if ( $1 == "LYS" || $1 == "HIS" || $1 == "ARG" || $1 == "NA" ) print $1 }' | wc -l`
minusc=`awk '{ print $4 " " $5 " " $6 }' ${Project}.pdb | uniq | awk '{ if ( $1 == "ASP" || $1 == "GLU" || $1 == "CL" || $1 == "ACI" ) print $1 }' | wc -l`
totcarica=$(($plusc-$minusc))

# Checking if Infos.dat was copied
# If so, it copies the right melacu.prm reading the Tinker version
#
if [ -z Infos.dat ]; then
   echo " ARM fatal error! - Infos.dat not found"
   echo " Please check if Infos.dat exists in the ARM installation directory"
   echo " If not, reinstall ARM"
   echo ""
   echo " New.sh is terminating"
   echo ""
   cd ..
   rm -r Step_0
   exit 0
else
   echo "Project $Project" >> Infos.dat
   templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
fi

#
# Checking for all the available parameters file and asking for the one to use
#
amber=0
while [[ $amber -ne 1 && $amber -ne 2 ]]; do
   echo ""
   echo "*************************************************"
   echo ""
   echo " Select the force field to use during the" 
   echo " Molecular Dynamic and the QM/MM calculations"
   echo ""
   echo " Please just selct 1 or 2"
   echo ""
   echo " 1) amber-94"
   echo " 2) amber-99sb"
   echo ""
   echo "*************************************************"
   read amber
done
if [[ $amber -eq 1 ]]; then
   cp $templatedir/melacu51.prm .
   echo ""
   echo "AMBER94 will be used"
   echo ""
   echo "AMBER amber94" >> Infos.dat
   #
   # Updating the Infos.dat with prm file name, and CurrCalc field for calculation tracking
   #
   echo "Parameters melacu51" >> Infos.dat
else
   cp $templatedir/amber99sb.prm amber99sb.prm
   echo ""
   echo "AMBER99sb will be used"
   echo ""
   echo "AMBER amber99sb" >> Infos.dat
   #
   # Updating the Infos.dat with prm file name, and CurrCalc field for calculation tracking
   #
   echo "Parameters amber99sb" >> Infos.dat
fi

echo "CurrCalc Start" >> Infos.dat

# A folder named as the project is created, and the required files are copied inside
#
cp $templatedir/smooth_restart.sh .

# Checking for multiple chains in the PDB file. If so, it writes it in Infos.dat 
# for future use
#
grep 'ATOM' ${Project}.pdb > atoms
nchain=`grep 'TER' ${Project}.pdb | wc -l`
chain=A
if [[ $nchain -eq 1 ]]; then
   multchain=no
else
   multchain=yes
   numends=( $( grep -B1 'TER' ${Project}.pdb | grep 'ATOM' | awk '{ print $6 }' ) )
   numstarts=( $( grep -A1 'TER' ${Project}.pdb | grep 'ATOM' | awk '{ print $6 }' ) )
   ngaps=$(($nchain-1))
   for ((i=0;i<$ngaps;i=$(($i+1)))); do
       lastres[$i]=${numends[$i]}
       diffchain[$i]=$((${numstarts[$i]}-${numends[$i]}-1))
   done
fi

#
# Writing chain info in Infos.dat and running the appropriate pdbxyz command
#
if [[ $multchain == "yes" ]]; then
   echo "MultChain YES" >> Infos.dat
   echo "LastRes ${lastres[@]}" >> Infos.dat 
   echo "DiffChain ${diffchain[@]}" >> Infos.dat
else
   echo "MultChain NO" >> Infos.dat
fi
#
# Checking if a list of residues belonging to the retinal cavity is provided
#
if [[ -f ../cavity ]]; then
   answer=b
   while [[ $answer != y && $answer != n ]]; do
         echo " The cavity file has been found! Do you want to use it? (y/n)"
         read answer
         echo ""
   done
   if [[ $answer == y ]]; then
      echo "CavityFile YES" >> Infos.dat
      cp ../cavity .
   else
      echo "CavityFile NO" >> Infos.dat
   fi
else
   echo "CavityFile NO" >> Infos.dat
fi
#
# Checking the first residue number and writing it in Infos.dat
#
startres=`grep 'ATOM' $Project.pdb | head -n 1 | awk '{ print $6 }'`
echo "StartRes $startres" >> Infos.dat
#
# Retrieving non-standard ionization states for future use
#
for restrano in 'ASH' 'GLH' 'HIE' 'HID' 'LYD'; do
    strange=( $( grep " $restrano " $Project.pdb | awk '{ print $6 }' | uniq ) )
    if [[ ${strange[0]} != '' ]]; then
       echo "$restrano ${strange[@]}" >> Infos.dat
    fi
done
#
# Generate wild type PIR sequence by using Modeller
#
modelchk=`grep "Modeller" Infos.dat | awk '{ print $2 }'`
if [[ $modelchk == YES ]]; then
   cp $camino/getpir.py .
   cp $camino/mutate_model.py .
   sed -i "s/PROGETTO/$Project/g" getpir.py
   python getpir.py
   echo ""
fi

#
# Messages to the user
#

echo ""
echo ""
echo " What is the name of the CHROMOPHORE file? Omit the .xyz extension"
echo ""
echo " This file should provide the following information:"
echo " Number of atoms"
echo " Comment line"
echo " label(up to 4 letter), xyz_coord, AMBER atom type, charge"
echo " followed by the all bondings and \"End\" at the end of the file"
echo ""
echo " For instance:"
echo "  41"
echo ""
echo "  C1      -0.573  -0.262   0.118     CT   -0.0936"
echo "  C2      -1.449   0.737  -0.336     CA   -0.0106"
echo "  H3      -2.829   0.561  -0.349     H1    0.1750"
echo " ..."                                         
echo "  H41      5.007  -1.386  -0.211     HC    0.3914"
echo "  C1  C2"
echo "  C1  H3"
echo "  End"
echo "  ..."
echo ""
read chromophore

if [[ -f ../$chromophore.xyz ]]; then
   echo ""
   echo "$chromophore.xyz will be used"
   echo "chromophore $chromophore" >> Infos.dat
   echo ""
else
   echo ""
   echo " $chromophore.xyz does not exist"
   echo ""
   cd ..
   rm -r Step_0
   exit 0
fi

chr=20
while [[ $chr -ne -4 && $chr -ne -3 && $chr -ne -2 && $chr -ne -1 && $chr -ne 0 && $chr -ne 1 && $chr -ne 2 && $chr -ne 3 && $chr -ne 4 ]]; do
   echo ""
   echo ""
   echo " What is the total charge of the CHROMOPHORE (including the charge of the tail which is normally -2)."
   echo " Just type integer numbers (-1, 0, 1 ...)"
   echo ""
   read chr
done

#
# If seqmut is found, the mutation routine is started, given that either Modeller or SCWRL4 is available
# Such information is retrieved from Infos.dat
#

grep "ATOM  " $Project.pdb > ATOMS
lastatom=`tail -n1 ATOMS | awk '{ print $2 }'`
lastres=`tail -n1 ATOMS | awk '{ print $6 }'`
chratoms=`head -n1 ../$chromophore.xyz`

head -n $(($chratoms+2)) ../$chromophore.xyz | tail -n $chratoms > temp1
awk '{ print $2,"   ",$3,"   ",$4,"   ",$5}' temp1 > xyz

cat > format.f << YOE
      Program format
      implicit real*8 (a-h,o-z)
      character label2*2, label5*5

      open(1,file='xyz',status='old')
      open(2,file='HETATM_CHR',status='new')
      do i=1,$chratoms
         read(1,*)x,y,z,label2
         write(2,'(A,i5,2x,A,2x,A,i4,4x,f8.3,f8.3,f8.3)')"HETATM",
     &     $(($lastatom+1))+i,label2,"CHR A",$(($lastres+1)),x,y,z
      enddo
      close(1)
      close(2)
      end
YOE
gfortran format.f -o format.x
./format.x

grep "HETATM" $Project.pdb > HETATM_wat
grep "HETATM" $Project.pdb >> HETATM_CHR
sed -i "/HETATM/d" $Project.pdb
cat HETATM_CHR >> $Project.pdb

if [[ -f seqmut ]]; then
   scwrlchk=`grep "SCWRL4" Infos.dat | awk '{ print $2 }'`
   modelchk=`grep "Modeller" Infos.dat | awk '{ print $2 }'`
   if [[ $scwrlchk == YES || $modelchk == YES ]]; then 
      ./mutate.sh $Project $scwrlchk $modelchk
   else
      echo " You don't have any software to perform mutations!"
      echo " Please delete seqmut and try again"
      echo " Aborting..."
      echo ""
      exit 0
   fi
   errid=`grep 'mutate_errid' arm.err | awk '{ print $2 }'`
   if [[ $errid -eq 0 ]]; then
      echo " The following mutations has been inserted:"
      cat seqmut
      echo ""
   else
      echo " Problem in mutate.sh, no mutations will be performed."
      echo " Please type y to go on with the wild type, or n to abort"
      read scelta
      echo ""
      case $scelta in
           y) echo " Going on with the wild type..."
              mv wt_${Project}.pdb $Project.pdb
           ;;
           n) echo " Aborting..."
              echo ""
              exit 0
           ;;
      esac
   fi
else
   echo " No mutants requested, going on with the wild type.."
   echo ""
fi
sed -i "/HETATM/d" $Project.pdb
cat HETATM_wat >> $Project.pdb
rm ATOMS temp1 xyz HETATM_wat HETATM_CHR format.x format.f

plusc=`awk '{ print $4 " " $5 " " $6 }' ${Project}.pdb | uniq | awk '{ if ( $1 == "LYS" || $1 == "HIS" || $1 == "ARG" || $1 == "NA" ) print $1 }' | wc -l`
minusc=`awk '{ print $4 " " $5 " " $6 }' ${Project}.pdb | uniq | awk '{ if ( $1 == "ASP" || $1 == "GLU" || $1 == "CL" || $1 == "ACI" ) print $1 }' | wc -l`
totcarica=$(($plusc-$minusc))


mkdir Chromophore
cp ../$chromophore.xyz Chromophore
cd Chromophore

numatm=`head -n1 $chromophore.xyz | awk '{ print $1 }'`
end=`grep -n "End\|end\|END" $chromophore.xyz | cut -f1 -d:`

cat > write_pdb.f << YOE
      Program write_pdb
      implicit real*8 (a-h,o-z)
      character label*3,opls*8,line30*30

      open(1,file='$chromophore.xyz',status='old')
      open(2,file='$chromophore.pdb',status='unknown')

CCCCCCCCC Number of atoms of the solute
      num=$numatm
CCCCCCCCC
      read(1,*)
      read(1,*)
      do i=1,num
         read(1,*)label,x,y,z,opls
         write(2,'(A,1x,i4,2x,A,1x,A,4x,3(f7.3,1x))')
     &   "HETATM",i,label,"CHR A   1",x,y,z
      enddo
      write(2,*)
      do i=num+3,$end-1
         read(1,'(A)')line30
      enddo
      end
YOE

gfortran write_pdb.f -o write_pdb.x
./write_pdb.x
rm write_pdb.x
carga=$(($chr+$totcarica))
if [[ $totcarica != 0 ]]; then
   echo " The system total charge is $carga,"
   echo " which is different than zero"
   echo " Please be sure your PDB file is right"
   echo " Going on..."
   echo ""
else
   echo " The system total charge is $carga,"
   echo " everything seems ok"
   echo ""
fi

cd ..
cp $templatedir/ASEC/update_infos.sh .
./update_infos.sh "Step" "0" Infos.dat
./update_infos.sh "Init_Charge" $carga Infos.dat
./update_infos.sh "Chromo_Charge" $chr Infos.dat
cp $templatedir/NewStep.sh .
echo " Folder Step_0 created! cd Step_0/, then ./NewStep.sh"
echo ""

