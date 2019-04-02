#!/bin/bash
#
# Reading project name, parm file and templatedir from Infos.dat
#
Project=`grep "Project" Infos.dat | awk '{ print $2 }'`
numatoms=`grep "numatoms" Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
Step=`grep "Step" Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" Infos.dat | awk '{ print $2 }'`
solvent=`grep "SolventBox" Infos.dat | awk '{ print $2 }'`

cp MD_ASEC/list_tk.dat calculations/${Project}_OptSCF
cp MD_ASEC/ASEC_tk.xyz calculations/${Project}_OptSCF
cp $templatedir/ASEC/ASEC.f calculations/${Project}_OptSCF
cp $prm.prm calculations/${Project}_OptSCF
cp $templatedir/ASEC/New_parameters.f calculations/${Project}_OptSCF

cd calculations/${Project}_OptSCF
cp ${Project}_OptSCF.xyz ${Project}_OptSCF_old.xyz
mv ${Project}_OptSCF.xyz coordinates_tk.xyz

if [[ -f ../../chargefxx0 ]]; then
   cp ../../chargefxx0 .
   fxx=`grep -c "CHARGE" chargefxx0 | awk '{ print $1 }'`
   sed -i "s|tailall|$fxx|g" ASEC.f
   sed -i "s|tailall|$fxx|g" New_parameters.f
else
   sed -i "s|tailall|0|g" ASEC.f
   sed -i "s|tailall|0|g" New_parameters.f
fi

shell=`grep "Shell" ../../Infos.dat | awk '{ print $2 }'`
sed -i "s|numero|$shell|g" ASEC.f
gfortran ASEC.f -o ASEC.x
./ASEC.x
mv new_coordinates_tk.xyz ${Project}_OptSCF.xyz

#
# This section is for obtaining the new force fiel parameters
#

grep "atom     " $prm.prm > atom.dat
numindx2=`grep -c "atom     " atom.dat`
sed -i "s|atomos|$numindx2|g" New_parameters.f

grep "charge   " $prm.prm > charges.dat
numcharges=`grep -c "charge   " charges.dat`
sed -i "s|cargas|$numcharges|g" New_parameters.f

sed -i "s|numero|$shell|g" New_parameters.f

grep "vdw      " $prm.prm > vdw.dat
numvdw=`grep -c "vdw      " vdw.dat`
sed -i "s|vander|$numvdw|g" New_parameters.f
sed -i "s|chnorm=40|chnorm=100|g" New_parameters.f

gfortran New_parameters.f -o New_parameters.x
./New_parameters.x

atom=`grep -n "atom     " $prm.prm | awk '{print $1}' FS=":" | tail -n1`
head -n$atom $prm.prm > temp1
cat temp1 new_atom.dat > temp2

vdw=`grep -n "vdw      " $prm.prm | awk '{print $1}' FS=":" | tail -n1`
head -n$vdw $prm.prm | tail -n$(($vdw-$atom)) >> temp2
cat temp2 new_vdw.dat > temp3

charge=`grep -n "charge   " $prm.prm | awk '{print $1}' FS=":" | tail -n1`
head -n$charge $prm.prm | tail -n$(($charge-$vdw)) >> temp3
cat temp3 new_charges.dat > temp4

last=`wc -l $prm.prm | awk '{print $1}'`
tail -n$(($last-$charge)) $prm.prm >> temp4

mv $prm.prm old_$prm.prm 
mv temp4 $prm.prm

rm ASEC_tk.xyz list_tk.dat coordinates_tk.xyz ASEC.x ASEC.f
rm temp1 temp2 temp3 new_atom.dat new_charges.dat new_vdw.dat atom.dat charges.dat vdw.dat New_parameters.x New_parameters.f

SUBCOMMAND SUBMISSION

echo ""
echo ""
echo " After complete the OptSCF/ANO-L-MB, run OptSCF_VDZ.sh"
echo ""

cd ..

#
# Updating the Infos.dat Current field, which stores the current running calculation
#
awk '{ if ( $1 == "CurrCalc") sub($2,"OptSCF"); print}' ../Infos.dat > temp
mv temp ../Infos.dat

cp $templatedir/ASEC/OptSCF_VDZ.sh .

