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
echo " The current project is $Project. Checking the CAS/VDZ optimization..."
echo ""

# Checking if the optimization ended successfully, or if the assigned hours ended
#
opt=${Project}_VDZ_Opt
if [ -d $opt ]; then
   cd $opt
   contr=`grep 'landing' $opt.out | awk '{ print $1 }'`
   if [[ $contr == "Happy" ]]; then
      echo " CAS optimization ended successfully"
      echo ""
   else
      echo " The CAS optimization did not finished well."
      echo " Please check if the assigned hours expired or if some error occurred."
      echo ""
      echo " If you need to restart, run the restart.sh script."
      echo " Otherwise find out what is the error and re-run 1st_to_2nd.sh."
      echo ""
      echo " 2nd_to_3rd.sh will terminate now!"
      echo ""
      cp $templatedir/restart.sh ../
      exit 0
   fi
else
   echo " CAS/VDZ optimization folder was not found! Check what is wrong"
   echo " Terminating"
   exit 0 
fi

# Preparing the files for CAS/6-31G* single point
# If the folder exists, the script is aborted with an error
#
cd ..
new=${Project}_VDZP
if [ -d $new ]; then
   ./smooth_restart.sh $new "Do you want to re-run the QM/MM VDZP single point? (y/n)" 7
   if [[ ! -f Infos.dat ]]; then
      mv no.Infos.dat Infos.dat
      exit 0
   fi
fi
mkdir ${new}
cp $opt/$opt.key ${new}/${new}.key
cp $opt/$opt.Final.xyz ${new}/${new}.xyz
cp $opt/${prm}.prm ${new}/
cp $templatedir/SUBMISSION ${new}
cp $templatedir/ASEC/templateSP ${new}/
#cp $templatedir/modify-inp.vim ${new}/
cd ${new}/

# Editing the template for the CAS single point
#
sed -i "s|PARAMETRI|${prm}|" templateSP

# Calling xyzedit for input generation
#
#$tinkerdir/xyzedit ${new}.xyz <<EOF
#20
#1
#EOF

# Editing the input file with modify-inp.vim: removal of the Tinker standard part
# and introduction of the basis set
#
#sed -i 's/BASIS/6-31G*/' modify-inp.vim
#sed -i 's/BAS2/6-31G\\*/' modify-inp.vim
#vim -es $new.input < modify-inp.vim
#rm modify-inp.vim

# Merging the geometrical part and the template for CAS single point
#
#mv ${new}.input temp
#cat temp templateSP > ${new}.input
#rm temp templateSP

mv templateSP ${new}.input
sed -i "s/ANO-L-VDZ/ANO-L-VDZP/g" ${new}.input

# Writing project name, input directory and memory requested in the submission script
# For CASSCF/6-31G* single point let's hope 2 Gb will be enough...
# Time requested will be 1 day
#
sed -i "s|NOMEPROGETTO|${new}|" SUBMISSION
no=$PWD
sed -i "s|NOMEDIRETTORI|${no}|" SUBMISSION
sed -i "s|MEMTOT|23000|" SUBMISSION
sed -i "s|MEMORIA|20000|" SUBMISSION
sed -i "s|hh:00:00|30:00:00|" SUBMISSION

# Job submission and template copy for the following step
#
echo ""
echo " Submitting the CAS/VDZP single point now..."
echo ""
sleep 1

SUBCOMMAND SUBMISSION

cd ..
cp $templatedir/ASEC/sp_to_opt_VDZP_mod.sh .
cp $templatedir/ASEC/alter_orbital_mod.sh .

# Updating the Infos.dat Current field, which stores the current running calculation
#
awk '{ if ( $1 == "CurrCalc") sub($2,"VDZP"); print}' ../Infos.dat > temp
mv temp ../Infos.dat

# Messages to the user
#
echo ""
echo ""
echo " As soon as the calculation is finished, run sp_to_opt_VDZP_mod.sh"
echo ""

