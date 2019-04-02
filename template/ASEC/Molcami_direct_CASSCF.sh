#!/bin/bash
#
# Retrieving the needed information from Infos.dat
#
Project=`grep "Project" Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
retstereo=`grep "RetStereo" Infos.dat | awk '{ print $2 }'`
Step=`grep "Step" Infos.dat | awk '{ print $2 }'`
numatoms=`grep "numatoms" Infos.dat | awk '{ print $2 }'`
uphess=`grep "Update_hessian" Infos.dat | awk '{ print $2 }'`
solvent=`grep "SolventBox" Infos.dat | awk '{ print $2 }'`
shell=`grep "Shell" Infos.dat | awk '{ print $2 }'`
stationary=`grep "Stationary" Infos.dat | awk '{ print $2 }'`
chromophore=`grep "chromophore" Infos.dat | awk '{ print $2 }'`
state=`grep "State" Infos.dat | awk '{ print $2 }'`
ilov=`grep "iLOV_RESP" Infos.dat | awk '{ print $2 }'`
chargechr=`grep "Chromo_Charge" Infos.dat | awk '{ print $2 }'`

#
# Copying and running the script for Tinker files preparation
#

# Creating the directory calculations and copying all the needed files
# If calculations already exists, the script exits with a message
#
echo ""
echo " Using $Project.xyz and $prm.prm"
echo ""
if [ -d calculations ]; then
   echo " Folder calculations already exists. Please check it and remove if necessary"
   echo " Terminating..."
   echo ""
   exit 0
fi

echo "parameters $prm" > $Project.key
echo "parameters $prm" > ${Project}_nolink.key
echo "" >> $Project.key
echo "" >> ${Project}_nolink.key
chratoms=`head -n1 Chromophore/$chromophore.xyz | awk '{ print $1 }'`
xx=0
fx=0
final=`head -n1 $Project-tk.xyz | awk '{ print $1 }'`
init=$(($final-$chratoms))
rm -f mm
rm -f qm
rm -f chargemm
rm -f chargexx
rm -f chargefx
rm -f chargefxx
touch mm
touch qm
for i in $(eval echo "{1..$chratoms}"); do
   num=`head -n $(($init+1+$i)) $Project-tk.xyz | tail -n1 | awk '{ print $1 }'`
   charge=`head -n $i new_charges | tail -n1 | awk '{ print $1 }'`
   atmtype=`head -n $(($i+2)) Chromophore/$chromophore.xyz | tail -n1 | awk '{ print $6 }'`
   if [[ $atmtype == "MM" ]]; then
      echo "MM $num" >> mm
      echo "CHARGE  -$num   $charge" >> chargemm
   fi
   if [[ $atmtype == "QM" ]]; then
      echo "QM $num" >> qm
   fi
   if [[ $atmtype == "LQ" ]]; then
      echo "QM $num" >> qm
   fi
   if [[ $atmtype == "LM" ]]; then
      echo "MM $num" >> mm
      echo "CHARGE  -$num   0.0000" >> chargemm
      LM=$num
   fi
#  1 for atoms of the tail as ASEC points
#  0 for the fixed atoms of the tail
   if [[ $atmtype == "XX" ]]; then
      echo "CHARGE  $num   $charge    1"   >> chargefxx
      xx=$(($xx+1))
   fi
   if [[ $atmtype == "FX" ]]; then
      echo "CHARGE  $num   $charge    0" >> chargefxx
      fx=$(($fx+1))
   fi
done
if [[ $xx -gt 0 ]]; then
   correct=a
   while [[ $correct != "y" && $correct != "n" ]]; do
      echo ""
      echo " *************************************************************************"
      echo ""
      echo " It seems that the chromophore has a long tail, which just the LM atom"
      echo " will be considered in the QMMM calculations as MM atoms. The rest of the"
      echo " tail will be considered as ASEC points."
      echo ""
      echo " Is it correct? (y/n)"
      echo ""
      echo " *************************************************************************"
      read correct
   done
   if [[ $correct == "n" ]]; then
      echo " "
      echo " Please redifine the QM, MM, QL, ML, and XX atom types in the initial"
      echo " chromophore xyz file."
      echo " Aborting ..."
      exit 0
   fi
   conti=0
   while [[ $conti -eq 0 ]]; do
      echo ""
      echo " It was stated that the total charge of the " 
      echo " Chromophore + tail is ${chargechr}."
      echo " Please define the charge of the chromophore and the charge"
      echo " of the tail:"
      echo ""
      echo " Charge of the Chromophore: (... -2, -1, 0, 1, ... )"
      read char
      echo " Charge of the tail: (... -2, -1, 0, 1, ... )"
      read taill
      if [[ $(($char+$taill)) -ne $chargechr ]]; then
         echo " ***********************************************************"
         echo ""
         echo " There is something wrong with the charges, the sum of them"
         echo " must be equal to ${chargechr}."
         echo " Please try again."
      else
         carga=$taill
         conti=1
      fi
   done
fi

#
# round.f sets to zero the charge of the MM atom closest to the Link atom (LM). Then, the charges of the 
# remaining MM atoms are rounded to $carga to ensure that the total charge of the QM+MM part is the desired
# charge.
#
if [[ $xx -gt 0 ]]; then
   lines=`wc -l chargefxx | awk '{ print $1 }'`
   file="chargefxx"
   file0="chargefxx0"
   cp chargemm chargemm0
   carga=$taill
   rm -f col
   for i in $(eval echo "{1..$lines}"); do
      tipo=`head -n $i chargefxx | tail -n1 | awk '{ print $4 }'`
      echo "  $tipo" >> col
   done
else
   lines=`wc -l chargemm | awk '{ print $1 }'`
   file="chargemm"
   file0="chargemm0"
   carga=$chargechr
fi
cat > round.f << YOE
      Program round
      implicit real*8 (a-h,o-z)
      dimension charges(500), Ncharges(500), num(500)
      character texto*6
      open(1,file='$file',status='old')
      open(2,file='$file0',status='unknown')
      k=0 
      do i=1,$lines
         read(1,*)texto,num(i),charges(i)
         Ncharges(i)=nint(charges(i)*1000000)
         k=k+Ncharges(i)
      enddo
c      write(*,*)$LM
 2    i=1
      do while (k.ne.1000000*($carga))
         if (num(i).ne.$LM*(-1)) then
            if (k.gt.1000000*($carga)) then
               Ncharges(i)=Ncharges(i)-1
            else
               Ncharges(i)=Ncharges(i)+1
            endif

            k=0
            do j=1,$lines
               k=k+Ncharges(j)
            enddo
c            write(*,*)k
         endif
         i=i+1
         if (i.eq.($lines+1)) then
            goto 2
         endif
      enddo
      do i=1,$lines
         write(2,'("CHARGE",2x,I7,2x,f9.6,2x,i1)')num(i),
     &        Ncharges(i)/1000000.0d0
      enddo
      end
YOE
gfortran round.f -o round.x
./round.x
rm round.f round.x

if [[ $xx -gt 0 ]]; then
   paste chargefxx0 col > colu
   mv colu chargefxx0
fi

echo "QMMM $(($chratoms-$xx-$fx+1))" >> $Project.key
echo "QMMM $(($chratoms-$xx-$fx))" >> ${Project}_nolink.key

cat mm >> $Project.key
cat mm >> ${Project}_nolink.key
cat qm >> $Project.key
cat qm >> ${Project}_nolink.key
echo "LA $(($final+1))" >> $Project.key

echo "QMMM-ELECTROSTATICS ESPF" >> $Project.key
echo "QMMM-microiteration ON" >> $Project.key
echo "QMMM-ELECTROSTATICS ESPF" >> ${Project}_nolink.key
echo "QMMM-microiteration ON" >> ${Project}_nolink.key

cat chargemm0 >> $Project.key
cat chargemm0 >> ${Project}_nolink.key
cat qm >> mm
for i in $(eval echo "{1..$(($chratoms-$xx-$fx))}"); do
   active=`head -n $i mm | tail -n1 | awk '{ print $2 }'`
   echo "ACTIVE $active" >> $Project.key
   echo "ACTIVE $active" >> ${Project}_nolink.key
done
echo "ACTIVE $(($final+1))" >> $Project.key
rm -f qm mm col
#chargemm chargemm0

mv ${Project}_nolink.key $Project-tk.key
$tinkerdir/xyzedit $Project-tk.xyz << EOF
20
0
EOF
if [[ -f $Project-tk.xyz_2 ]] ; then
   if grep -q "HLA " $Project-tk.xyz_2; then
      if [[ $Molcami_OptSCF != "YES" ]]; then
         ./update_infos.sh "Shell" $(($shell+1)) Infos.dat
         ./update_infos.sh "Molcami_OptSCF" "YES" Infos.dat
      fi
cat > reformat.f << YOE
      Program reformat
      implicit real*8 (a-h,o-z)
      character line3*3,line74*74
      open(1,file='$Project-tk.xyz_2',status='old')
      open(2,file='$Project-tk.xyz_new',status='unknown')
      read(1,*)
      write(2,'(i6)')$(($final+1))
      do i=1,$(($final+1))
           read(1,'(i5,1x,A,1x,A)')nume,line3,line74
           write(2,'(i6,2x,A,1x,A)')nume,line3,line74
      enddo
      end
YOE
      gfortran reformat.f -o reformat.x
      ./reformat.x
      rm $Project-tk.xyz_2
      mv $Project-tk.xyz_new $Project-tk.xyz_2
      rm $Project-tk.key
      rm $Project-tk.input
   else
      echo "*********************************"
      echo " It seems to be something wrong"
      echo " adding the Link atom."
      echo " Aborting ..."
      echo "*********************************"
      exit 0
   fi
else
   echo "*********************************"
   echo " It seems to be something wrong"
   echo " adding the Link atom."
   echo " Aborting ..."
   echo "*********************************"
   exit 0
fi

mkdir calculations
newdir=${Project}_VDZP_Opt
mkdir calculations/${newdir}

cp $Project.key calculations/${newdir}/${newdir}.key

#
# This section is for inserting the optimizaed cromophore structure of the previous 
# Step into the new -tk.xyz in order to avoid the rounding arising from the tk to gro
# conversion and the new position of the Link atom.
#
if [[ $Step -gt 0 ]]; then
   cp ../Step_$(($Step-1))/calculations/${newdir}/${newdir}.Final.xyz ${newdir}.Final_last.xyz

   cp $templatedir/ASEC/Ins_tk_tk_Molcami.f .
   cp $Project-tk.xyz_2 new_tk.xyz
   cp ${newdir}.Final_last.xyz last_tk.xyz

   sed -i "s|numero|$(($shell+1))|g" Ins_tk_tk_Molcami.f

   grep "QM \|MM \|LA " $Project.key | grep -v "QMMM" | awk '{ print $2 }' > qmmmatoms
   sort -n -o sorted qmmmatoms
   mv sorted qmmmatoms

   fin=`wc -l qmmmatoms | awk '{ print $1 }'`
   sed -i "s/finall/$fin/g" Ins_tk_tk_Molcami.f

   gfortran Ins_tk_tk_Molcami.f -o Ins_tk_tk_Molcami.x
   ./Ins_tk_tk_Molcami.x
   mv Insert-tk.xyz calculations/${newdir}/${newdir}.xyz
#   rm qmmmatoms $Project-tk.xyz_2 new_tk.xyz last_tk.xyz Ins_tk_tk_Molcami.f Ins_tk_tk_Molcami.x $Project.key
else
   mv $Project-tk.xyz_2 calculations/${newdir}/${newdir}.xyz
fi
###################################################

# 
# If the neutral retinal is used, the right template is copied
#
#calcul=0
#while  [[ $calcul -ne 1 && $calcul -ne 2 ]]; do
#       echo " Now, select what kind of optimization"
#       echo ""
#       echo " 1) Minumum optimization"
#       echo " 2) TS Optimization"
#       echo ""
#       read calcul
#done
calcul=1

##### cp new_$prm.prm calculations/$prm.prm

if [[ -a ${newdir}.JobIph_old ]]; then
   cp ${newdir}.JobIph_old calculations/${newdir}/${newdir}.JobIph
fi
if [[ -a ${newdir}.RasOrb ]]; then
   cp ${newdir}.RasOrb calculations/${newdir}/${newdir}.RasOrb
fi
if [[ -a ${newdir}.Hessian_old ]]; then
   cp ${newdir}.Hessian_old calculations/${newdir}/${newdir}.Hessian_old
fi
if [[ -a ${newdir}.Hessian_QMMM ]]; then
   cp ${newdir}.Hessian_QMMM calculations/${newdir}/${newdir}.Hessian_old
fi

#slurm
#cp $templatedir/molcas-job.sh calculations/${newdir}/
cp $templatedir/molcas.slurm.sh calculations/${newdir}/molcas-job.sh


if [[ $retstereo == "nAT" ]]; then
   cp $templatedir/templateOPTSCFneu calculations/${newdir}/templateOPTSCF 
else
 if [[ $calcul == 1 ]]; then
   cp $templatedir/ASEC/template_CASSCF_min calculations/${newdir}/template_CASSCF
   sed -i "s|> COPY \$InpDir/\$Project.Espf.Data \$WorkDir|*> COPY \$InpDir/\$Project.Espf.Data \$WorkDir|" calculations/${newdir}/template_CASSCF
   if [[ $state -eq 1 ]]; then
      sed -i "/Ras2=/a\ \ \ \ ciroot=2 2 1" calculations/${newdir}/template_CASSCF
      sed -i "/ciroot=/a\ \ \ \ rlxroot=2" calculations/${newdir}/template_CASSCF
      if [[ $Step -eq 1 ]]; then
         sed -i "/\ \ \ \ cirestart/d" calculations/${newdir}/template_CASSCF
      fi
   fi
 else
   cp $templatedir/ASEC/template_CASSCF_TS calculations/${newdir}/template_CASSCF
   if [[ $Step -eq 0 ]]; then
      sed -i "/JobIph_old/d" calculations/${newdir}/template_CASSCF
      sed -i "/\ \ \ \ JobIph/d" calculations/${newdir}/template_CASSCF
      sed -i "/\ \ \ \ cirestart/d" calculations/${newdir}/template_CASSCF
   fi
 fi
fi

cd calculations
cd ${newdir}/

# Putting project name, input directory, time and memory in the submission script
# Since it is a SCF optimization, 1500 MB should be enough...
# And 30 hrs are enough as well
#

NOME=${newdir}
#echo ""
#echo ""
#echo "Enter the Name of the Script"
#echo ""
#echo ""
#read NOME
NOME=${Project}_VDZP_Opt
sed -i "s|NOMEPROGETTO|$NOME|" molcas-job.sh

no=$PWD
sed -i "s|NOMEDIRETTORI|${no}|" molcas-job.sh
sed -i "s|MEMTOT|23000|" molcas-job.sh
sed -i "s|MEMORIA|20000|" molcas-job.sh
sed -i "s|hh:00:00|230:00:00|" molcas-job.sh
#sed -i "s|ppn=4|ppn=8|" molcas-job.sh

# Replacing PARAMETRI with current prm filename templateOPTSCF
#
sed -i "s|PARAMETRI|${prm}|" template_CASSCF

#sed -i "/export Project=/c\ export Project=${newdir}" molcas-job.sh
#echo "cp \$WorkDir/\$Project.JobIph \$InpDir/\$Project.JobIph_new" >> molcas-job.sh
#
# Generation of the correct Molcas input from templateOPTSCF
#

if [[ $uphess == NO ]]; then
   sed -i "/RUNOLD/d" template_CASSCF
   sed -i "/OLDF/d" template_CASSCF
fi

#sed -i "/rHidden = 6.0/a> COPY \$WorkDir/\$Project.RunFile \$InpDir/\$Project.Hessian_new" template_CASSCF
#sed -i "s|> COPY \$InpDir/\$Project.Espf.Data \$WorkDir|*> COPY \$InpDir/\$Project.Espf.Data \$WorkDir|g" template_CASSCF
#sed -i "/SLAPAF/a    OLDF" template_CASSCF

#cat ../../$Project-tk.input template_CASSCF > ${newdir}.input

mv template_CASSCF ${newdir}.input 
sed -i "s|VDZ|VDZP|" ${newdir}.input

cd ../../
cp $templatedir/ASEC/ASEC_direct_CASSCF.sh .
echo ""
echo "Run ASEC_direct_CASSCF.sh to generate the final coordinate file and submitt"
echo ""

