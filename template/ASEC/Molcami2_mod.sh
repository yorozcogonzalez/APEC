#!/bin/bash
#
# Retrieving information from Infos.dat
#
Project=`grep "Project" ../Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" ../Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" ../Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" ../Infos.dat | awk '{ print $2 }'`

# Instructions to the user
#
echo ""
echo " The current project is $Project. Checking the HF optimization..."
echo ""

# Grepping the Happy landing to check that the calculation ended up properly
#
scf=${Project}_OptSCF_VDZ
contr=`grep 'landing' $scf/$scf.out | awk '{ print $1 }'`
if [[ $contr == "Happy" ]]; then
   echo " HF optimization ended successfully"
   echo ""
else
   echo " HF optimization still in progress. Terminating..."
   echo ""
   exit 0 
fi	

# Creation of the folder for CAS/3-21G single point and copy of all the files
# If the folder already exists, it finishes with an error message
#
new=${Project}_VDZ
if [ -d $new ]; then
   ./smooth_restart.sh $new "Do you want to re-run the QM/MM 3-21G single point? (y/n)" 5
   if [[ ! -f Infos.dat ]]; then
      mv no.Infos.dat Infos.dat
      exit 0
   fi
fi
mkdir ${new}
cp $scf/$scf.Final.xyz ${new}/${new}.xyz
cp $scf/$scf.key ${new}/${new}.key
cp $scf/${prm}.prm ${new}/
#cp $templatedir/modify-inp.vim ${new}/
#slurm
cp $templatedir/SUBMISSION ${new}
cp $templatedir/ASEC/templateSP ${new}/
cd ${new}/

# Editing the template for single point
#
sed -i "s|PARAMETRI|${prm}|" templateSP


# Editing the submission script template for a CAS single point 
#

mv templateSP $new.input
 
sed -i "s|NOMEPROGETTO|${new}|" SUBMISSION
no=$PWD
sed -i "s|NOMEDIRETTORI|${no}|" SUBMISSION
sed -i "s|MEMTOT|23000|" SUBMISSION
sed -i "s|MEMORIA|20000|" SUBMISSION
sed -i "s|hh:00:00|160:00:00|" SUBMISSION

#
# Submitting the CAS/3-21G single point
#
echo ""
echo " Submitting the CAS/ANO-L-VDZ single point now..."
echo ""
sleep 1

SUBCOMMAND SUBMISSION

# Copying the script for the following step and giving instructions to the user
#
cd ..
cp $templatedir/ASEC/1st_to_2nd_mod.sh .
cp $templatedir/ASEC/alter_orbital_mod.sh .

# Updating the Infos.dat Current field, which stores the current running calculation
#
awk '{ if ( $1 == "CurrCalc") sub($2,"VDZ"); print}' ../Infos.dat > temp
mv temp ../Infos.dat

echo ""
echo " As soon as the CAS single point is finished, run 1st_to_2nd.sh"
echo ""


