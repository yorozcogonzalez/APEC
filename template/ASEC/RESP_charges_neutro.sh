#!/bin/bash
#
# Reading data from Infos.dat
#

RESP="STATUS"

if [[ -d RESP_charges ]]; then
   echo " RESR_charges folder already exists "
   echo " Aborting ..."
   exit 0
fi

if [[ $RESP != "GRO" && $RESP != "TNK" ]]; then
   echo " Please define RESP type"
   echo " Aborting ..."
   exit 0
fi

mkdir RESP_charges
cd RESP_charges

if [[ $RESP == "TNK" ]]; then
   folder='6-31G_Opt'
   Project=`grep "Project" ../../Infos.dat | awk '{ print $2 }'`
   prm=`grep "Parameters" ../../Infos.dat | awk '{ print $2 }'`
   templatedir=`grep "Template" ../../Infos.dat | awk '{ print $2 }'`
   numatoms=`grep "numatoms" ../../Infos.dat | awk '{ print $2 }'`
   gropath=`grep "GroPath" ../../Infos.dat | awk '{ print $2 }'`
   tinkerdir=`grep "Tinker" ../../Infos.dat | awk '{ print $2 }'`
   retcharge=`grep "Ret_charge" ../../Infos.dat | awk '{ print $2 }'`

   cp ../${Project}_$folder/${Project}_$folder.Final.xyz final.xyz
   cp ../${Project}_$folder/$prm.prm .
   cp ../${Project}_$folder/${Project}_$folder.key key_file
   cp $templatedir/ASEC/fitting_RESP.sh ../
   if [[ -f ../../Dynamic/$Project.gro ]]; then
      cp ../../Dynamic/$Project.gro .
   else
      cp ../../Dynamic/${Project}_box_sol.gro $Project.gro
   fi
   cp ../../template_tk2gro .
   cp $templatedir/ASEC/fitting_RESP.sh ../
   sed -i "s/STATFIT/TNK/" ../fitting_RESP.sh
fi
if [[ $RESP == "GRO" ]]; then
   Project=`grep "Project" ../Infos.dat | awk '{ print $2 }'`
   prm=`grep "Parameters" ../Infos.dat | awk '{ print $2 }'`
   templatedir=`grep "Template" ../Infos.dat | awk '{ print $2 }'`
   numatoms=`grep "numatoms" ../Infos.dat | awk '{ print $2 }'`
   gropath=`grep "GroPath" ../Infos.dat | awk '{ print $2 }'`
   tinkerdir=`grep "Tinker" ../Infos.dat | awk '{ print $2 }'`
####
#    The following procedure for generating the RESP charges using initial pdb structure is:
#    1. Remove external waters and add the polar hydrogens with dowser.
#    2. Add initial charges to the Retinal equal zero because it is not needed now.
#    3. Converting from pdb to gro.
#    4. Denerating the templete tk2gro. It is needed for updating the charges.
#       Here it is also denegeted the xyz file (with no LAH).
#    5. Generating the key file and editing the xyz for adding the LAH.
####

   retcharge=10
   while [[ $retcharge -ne 1 && $retcharge -ne 0 ]]; do
      echo ""
      echo ""
      echo " What is the total charge of the retinal (1/0)"
      echo ""
      read retcharge
   done
   echo "Ret_charge $retcharge" >> ../Infos.dat

   if [[ $retcharge -eq 0 ]]; then
      sed -i "s/RetStereo new/RetStereo nAT/g" ../Infos.dat
   fi

   #
   #  Dowser
   #
   cp ../$Project.pdb .
   cp $templatedir/ASEC/fitting_RESP.sh ../
   sed -i "s/STATFIT/GRO/" ../fitting_RESP.sh             
   mkdir ${Project}_dowser
   cp $templatedir/carbret_dow ${Project}_dowser/labelret
   cp $templatedir/pdb-to-dow.sh ${Project}_dowser/
   cp $templatedir/yesH-tk-to-gro.sh ${Project}_dowser/
   cp $templatedir/${prm}.prm ${Project}_dowser/
   cp ../$Project.pdb ${Project}_dowser
   cp $templatedir/PdbFormatter.py ${Project}_dowser
   cp $templatedir/rundowser.sh ${Project}_dowser/
   cd ${Project}_dowser/
   sed -i "s/answer=t/answer=y/" rundowser.sh
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
   if [[ $retcharge -eq 0 ]]; then
     sed -i "/ HZ1 RET /d" $Project.pdb 
   fi

###########################################
   #
   #  Initial RET charges equal zero
   #
   mkdir pdb_2_gro
   cd pdb_2_gro
   cp ../../Infos.dat ../
   cp -r $templatedir/amber94.ff .
   cd amber94.ff/
   cp normalamino-h aminoacids.hdb

   if [[ $retcharge -eq 1 ]]; then
      cp $templatedir/ASEC/RESP/RET_labels_order .
      for i in {1..54}; do
          lab=`head -n $(($i+2)) RET_labels_order | tail -n1 | awk '{ print $1 }'`
          charge=0.00000
          sed -i "s/${lab}_RET/$charge/" amino-retnew
      done
      cp amino-retnew aminoacids.rtp
   else
      cp neuamino-h aminoacids.hdb
      cp $templatedir/ASEC/RESP/RETn_labels_order .
      for i in {1..53}; do
          lab=`head -n $(($i+2)) RETn_labels_order | tail -n1 | awk '{ print $1 }'`
          charge=0.00000
          sed -i "s/${lab}_RET/$charge/" amino-retnnew
      done
      cp amino-retnnew aminoacids.rtp
   fi

   cd ..

   #
   # Converting the PDB into a format suitable for Gromacs by using pdb-to-gro.sh
   # Output must be different if Dowser was used
   #
   cp $templatedir/pdb-to-gro.sh .
   cp ../$Project.pdb .
   dowser="YES"
   ./pdb-to-gro.sh $Project.pdb $dowser
   if [[ -f ../../arm.err ]]; then
      checkpdbdow=`grep 'pdb-to-gro' ../../arm.err | awk '{ print $2 }'`
   fi
   if [[ $checkpdbdow -ne 0 ]]; then
      echo " An error occurred in pdb-to-gro.sh. I cannot go on..."
      echo ""
      echo "NewStep.sh 2 PDBtoGroProblem" >> ../../arm.err
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
   #
   # pdb2gmx is the Gromacs utility for generating gro files and topologies
   #
   cp $templatedir/residuetypes.dat .
   $gropath/pdb2gmx -f $Project.pdb -o $Project.gro -p $Project.top -ff amber94 -water tip3p 2> grolog
   checkgro=`grep 'Writing coordinate file...' grolog`
      if [[ -z $checkgro ]]; then
         echo " An error occurred during the execution of pdb2gmx. Please look into grolog file"
         echo " No further operation performed. Aborting..."
         echo ""
         exit 0
      else
         echo " Gromacs file properly generated"
         echo ""
      fi
      waiti="b"
      while [[ $waiti != "y" ]]; do
         echo ""
         echo " Please check visually the positions of the hydrogens of the Retinal in the"
         echo " gromacs file: RESP_charges/pdb_2_gro/$Project.gro and fix if needed before"
         echo " continue with the RESP charges calculation."
         echo ""
         echo " Did you already chech it? Type \"y\" to contunue."
         read waiti
      done

   cp $Project.gro ../
   cd ..

#####################################
   #
   # generating the templete_tk2gro
   #
   mkdir Templates
   cp $templatedir/$prm.prm .
   cp $Project.gro Templates
   cd Templates

   sed -i "s/HOH/SOL/g" $Project.gro

   # editconf convert it to PDB and pdb-format-new fixes the format to
   # allow Tinker reading
   #
   cp ../../Infos.dat .
   cp $templatedir/pdb-format-new.sh .
   $gropath/editconf -f ${Project}.gro -o $Project.pdb -label A
   ./pdb-format-new.sh $Project.pdb

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
../$prm
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

####################################################

   #
   #Generating the key file. TAKEN FROM KET_MAKER.SH
   #

   echo "parameters $prm" > $Project-tk.key
   echo "" >> $Project-tk.key
   xyzfile="$Project-tk.xyz"
   #
   # Getting the retinal atoms in file retnum, and finding the 1st and last atom
   #
   awk '{ if ( $6 == 2012 || $6 == 2013 || $6 == 2014 ) print $0 }' $xyzfile > retnum
   startret=`cat retnum | head -n 1 | awk '{ print $1 }'`
   endret=`cat retnum | tail -n 1 | awk '{ print $1 }'`
   #
   # last-first plus one gives the number of retinal atoms
   #
   retatoms=$(($endret-$startret+1))
   #
   # retinal atoms + 5 QM lysine atoms + 9 MM lysine sidechain gives the total
   # 5+9=14. When retinal is neutral. there are just 4 QM lysine atoms
   #
   lysqm=5
   qmmmatoms=$(($retatoms+9+$lysqm))
   echo "QMMM $qmmmatoms" >> $Project-tk.key
   #
   # Cycling over the qmnums vector, which is created for VMD selection, by reading
   # retnum. i=6 because the 5 QM lysine atoms will be added in the first 5 places.
   # i=5 must be used for neutral retinal
   #
   i=$(($lysqm+1))
   while read line; do
      numatom=`echo $line | awk '{ print $1 }'`
      qmnums[$i]=$numatom
      conn1=`echo $line | awk '{ print $7 }'`
   #
   # When the difference between the atom number numatom and the first field of connectivity
   # is large, the C15 atom has been found. Its connectivity field is the lysine N3 number
   #
      diff=$(($numatom-$conn1))
      if [[ $diff -gt 50 ]]; then
         lysine=$conn1
      fi
      i=$(($i+1))
   done < retnum

   #
   # Storing the other QM atoms by relative position compared to lysine N3
   # Cepsilon,N3, Hepsilon1, Hepsilon2 and nitrogen H, which is not there when retinal is neutral
   #
   qmnums[1]=$(($lysine-1))
   qmnums[2]=$lysine
   qmnums[3]=$(($lysine+7))
   qmnums[4]=$(($lysine+8))
   if [[ $retstereo != "nAT" ]]; then
      qmnums[5]=$(($lysine+9))
   fi
   #
   # MM lysine atoms are calculated like before. Lysine N3 minus 4 is the Cbeta, and so on
   # The QMMM section is written with ranges of atoms
   #
   echo "MM -$(($lysine-4)) $(($lysine-2))" >> $Project-tk.key
   echo "MM -$(($lysine+1)) $(($lysine+6))" >> $Project-tk.key
   #
   # All the QM atoms stored before
   #
   echo "QM -${qmnums[1]} ${qmnums[2]}" >> $Project-tk.key
   echo "QM -${qmnums[3]} ${qmnums[$lysqm]}" >> $Project-tk.key
   echo "QM -$startret $endret" >> $Project-tk.key
   #
   # tuttiatm reads the total number of atoms in the xyz file. Link atom generated by Tinker
   # will have tuttiatm+1 as a number. * is for re-use the same key file after xyzedit
   #
   tuttiatm=`head -n 1 $xyzfile | awk '{ print $1 }'`
   echo "*LA $(($tuttiatm+1))" >> $Project-tk.key
   #
   # Cleaning up
   #
   rm retnum
   #
   # Creating the list of QM atoms to be used for VMD selection of the chromophore cavity
   #
   for ((i=1;i<=$(($lysqm));i=$(($i+1)))); do
       echo -n "${qmnums[$i]} " >> qmserials
   done

   #
   # xyzedit generates the Molcas input file and adds the link atom
   #

   $tinkerdir/xyzedit $Project-tk.xyz <<EOF
../$prm
20
../$prm
1
EOF

   cp $Project-tk.key ../key_file
   cp $Project-tk.xyz_2 ../final.xyz
   cd ..
   rm Infos.dat
   mv ../arm.err arm_dow.err


################################################

fi

#
# Here will be generated the gaussian input for computing the RESP charges (RET.com)
#

interv_qm=`grep -w -c "QM" key_file`

echo " $retcharge 1" > RET.com
echo "New labels" > check_RET
echo ""

for i in $(eval echo "{1..$interv_qm}")
do
   init[$i]=`grep -w -m $i "QM" key_file | tail -n1 | awk '{print ((-1*$2))}'`
   final[$i]=`grep -w -m $i "QM" key_file | tail -n1 | awk '{print $3}'`
done

#  coordinates of the chromophore

count=0

for i in $(eval echo "{1..$interv_qm}")
do
   for j in $(eval echo "{${init[$i]}..${final[$i]}}")
   do
      count=$(($count+1))

      att=`head -n $(($j+1)) final.xyz | tail -n1 | awk '{ print $2 }' | awk '{print substr ($0, 0, 1)}'`
      xyz=`head -n $(($j+1)) final.xyz | tail -n1 | awk '{ print $3"   "$4"   "$5 }'`
      echo " $att    $xyz" >> RET.com
      atnum=`head -n $(($j+1)) final.xyz | tail -n1 | awk '{ print $1 }'`
      atnumg=`head -n $(($j+1)) template_tk2gro | tail -n1 | awk '{ print $2 }'`
      labelg=`head -n $(($atnumg+2)) $Project.gro | tail -n1 | awk '{ print $2 }'`
      echo "$labelg" >> check_RET
   done
done

#rm $Project.gro

echo "LAH" >> check_RET

if [[ $retcharge -eq 1 ]]; then
   diff -y $templatedir/ASEC/RESP/RET_labels_order check_RET
else
   diff -y $templatedir/ASEC/RESP/RETn_labels_order check_RET
fi

echo ""
echo ""
echo " Please check that the labels of the Retinal (New labels)"
echo " are exactly in the same order as in the Reference,"
echo " otherwise the RESP input files (RET-resp1.in and RET-resp2.in)"
echo " must be modified."
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
   echo " Please modify the RESP input files RET-resp1.in and RET-resp2.in"
   echo " before continue"
   echo ""
   exit 0
else
   echo ""
   echo " Continuing ..."
   echo ""

fi

lines=`wc -l check_RET | awk '{ print $1 }'`
tail -n $(($lines-1)) check_RET > a
mv a check_RET

# coordinates of the link atom
xyz=`grep " LAH \| HLA " final.xyz | awk '{ print $3"   "$4"   "$5 }'`
echo " H    $xyz" >> RET.com
echo "" >> RET.com

#taking the charges from parameters file
ncharges=`grep -c "charge " $prm.prm`
grep "charge " $prm.prm > charges

# writing the point charges to RET.com, not including the retinal and puting to ZERO the charge of CD (close to LAH): Init[1]-2

total=`head -n1 final.xyz | awk '{ print $1 }'`

if [ -f tempRET ]; then
   rm tempRET
fi
echo "" >> final.xyz

CD=`grep " LAH \| HLA " final.xyz | awk '{ print $7 }'`
LAH=`grep " LAH \| HLA " final.xyz | awk '{ print $1 }'`

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
cc
cc this is for setting to zero the total charge of the lys
cc
         if ((i.eq.($CD-4)).or.(i.eq.($CD-5)).or.(i.eq.($CD-6))
     &   .or.(i.eq.($CD-8))) then
            if (i.eq.($CD-4)) then
               write(3,'(1x,3(f10.6,3x),f9.6)')coorx(i),coory(i),
     &         coorz(i),0.22455
            endif
            if (i.eq.($CD-5)) then
               write(3,'(1x,3(f10.6,3x),f9.6)')coorx(i),coory(i),
     &         coorz(i),-0.63955
            endif
            if (i.eq.($CD-6)) then
               write(3,'(1x,3(f10.6,3x),f9.6)')coorx(i),coory(i),
     &         coorz(i),0.68395
            endif
            if (i.eq.($CD-8)) then
               write(3,'(1x,3(f10.6,3x),f9.6)')coorx(i),coory(i),
     &      coorz(i),-0.39805
            endif
         else
            write(3,'(1x,3(f10.6,3x),f9.6)')coorx(i),coory(i),
     &      coorz(i),charge(indi(i))
         endif
      enddo
      end
YOE

   gfortran charges.f -o charges.x
   ./charges.x
   rm charges.x

#CD=`grep " LAH \| HLA " final.xyz | awk '{ print $7 }'`
#LAH=`grep " LAH \| HLA " final.xyz | awk '{ print $1 }'`

sed -e "${CD}s/.*/DELETE/;${LAH}s/.*/DELETE/" tempRET > a
mv a tempRET

for i in $(eval echo "{1..$interv_qm}"); do
   sed -e "${init[$i]},${final[$i]}s/.*/DELETE/" tempRET > a
   mv a tempRET
done

sed -i "/DELETE/d" tempRET

#cp tempRET salva_tempRET

cat RET.com tempRET > a
mv a RET.com

echo "" >> RET.com 

rm charges

cp $templatedir/ASEC/RESP/RESP.com .

cat RESP.com RET.com > ${Project}_RESP.com
rm RESP.com RET.com

cp $templatedir/ASEC/SUBMIGAU .
sed -i "s/PROJECTO/${Project}_RESP/" SUBMIGAU

SUBCOMMAND SUBMIGAU

echo ""
echo ""
echo " Gaussian calculation submitted (HF/6-31G* plus ASEC) for generating the"
echo " Molecular Electrostatic Potential (MEP)."
echo ""
echo " When this calculation is done, execute fitting_RESP.sh"
echo ""
echo ""

