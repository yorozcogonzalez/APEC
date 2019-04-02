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
echo " The current project is $Project. Checking the CAS/3-21G single point..."
echo ""

# Checking if the single point ended successfully, with control on folder existence
#
sp=${Project}_VDZ
if [ -d $sp ]; then
   cd $sp
   contr=`grep 'landing' $sp.out | awk '{ print $1 }'`
   if [[ $contr == "Happy" ]]; then
      echo " CAS single point ended successfully" 
      echo ""
   else
      echo " CAS single point still in progress. Terminating..."
      echo ""
      exit 0
   fi
else
   echo " CAS/3-21G single point folder not found! Check what is wrong"
   echo " Terminating..."
   exit 0
fi

# Retrieving the occupation numbers from CAS single point for checking purposes
#
grep -A2 "Natural orbitals and occupation numbers for root  1" ${sp}.out
cd ..

# Asking the user if the occupation numbers are ok
#
echo ""
echo -n " Are all the occupation numbers in the range 0.02 to 1.98? (y/n)"
read answer
echo ""
contr=0
while [  $contr = 0 ]; do
      if [[ $answer != "y" && $answer != "n" ]]; then
         echo -n " Please answer y or n... -> "
         read answer
	 echo ""
      else
	 contr=1
         if [[ $answer == "y" ]]; then
            echo " Going ahead with the CAS/3-21G optimization"
	    echo ""
	 else
	    echo " You might have a problem with active space selection. To fix it:"
            echo " 1. - Use Molden to look at the orbitals in $sp.rasscf.molden"
	    echo " 2. - Find the right orbital(s) to be placed in the active space"
	    echo " 3. - Run the script alter_orbital_mod.sh"
	    echo ""
	    echo " Now 1st_to_2nd.sh will terminate"
	    echo ""
	    cp $templatedir/ASEC/alter_orbital_mod.sh .
	    exit 0
	 fi
      fi
done

# Preparing the files for CAS/3-21G optimization 
# If the folder exists, the script is aborted with an error
#
new=${Project}_VDZ_Opt
if [ -d $new ]; then
   ./smooth_restart.sh $new "Do you want to re-run the QM/MM 3-21G optimization? (y/n)" 6
   if [[ ! -f Infos.dat ]]; then
      mv no.Infos.dat Infos.dat
      exit 0
   fi
fi
mkdir ${new}
cp $sp/$sp.JobIph ${new}/${new}.JobIph
cp $sp/$sp.key ${new}/${new}.key
cp $sp/$sp.xyz ${new}/${new}.xyz
cp $sp/${prm}.prm ${new}/
cp $sp/$sp.Espf.Data ${new}/${new}.Espf.Data
#slurm
#cp $templatedir/molcas-job.sh ${new}/
cp $templatedir/molcas.slurm.sh ${new}/molcas-job.sh
cp $templatedir/ASEC/template_CASSCF_min ${new}/template
#cp $templatedir/modify-inp.vim ${new}/
cd ${new}/

# Editing the template for the CAS optimization
#
sed -i "s|PARAMETRI|${prm}|" template

# Calling xyzedit for input generation
#
#$tinkerdir/xyzedit ${new}.xyz <<EOF
#20
#1
#EOF

# Editing the input file with modify-inp.vim: removal of the Tinker standard part
# and introduction of the basis set
#
#sed -i 's/BASIS/3-21G/' modify-inp.vim
#sed -i 's/BAS2/3-21G/' modify-inp.vim
#vim -es $new.input < modify-inp.vim
#rm modify-inp.vim

# Merging the geometrical part and the template for CAS optimization
#
#mv ${new}.input temp
#cat temp template > ${new}.input
#rm temp template

mv template ${new}.input

# Writing the project name, the input directory, time and memory requested in the submission script
# Here there is a CASSCF/3-21G optimization, so 1.5 Gb should be more than enough
# A requested time of 36 hrs should be OK
#
sed -i "s|NOMEPROGETTO|${new}|" molcas-job.sh
no=$PWD
sed -i "s|NOMEDIRETTORI|${no}|" molcas-job.sh
sed -i "s|MEMTOT|23000|" molcas-job.sh
sed -i "s|MEMORIA|20000|" molcas-job.sh
sed -i "s|hh:00:00|90:00:00|" molcas-job.sh
#sed -i "/#PBS -l mem=/a#PBS -A PAA0009" molcas-job.sh

# Job submission and template copy for the following step
#
echo ""
echo " Submitting the CAS/3-21G optimization now..."
echo ""
sleep 1

#slurm
#qsub molcas-job.sh
sbatch molcas-job.sh

cd ..
cp $templatedir/ASEC/2nd_to_3rd_mod.sh .

# Updating the Infos.dat Current field, which stores the current running calculation
#
awk '{ if ( $1 == "CurrCalc") sub($2,"VDZ_Opt"); print}' ../Infos.dat > temp
mv temp ../Infos.dat

# Messages to the user
#
echo " As soon as the calculation is finished, run 2nd_to_3rd.sh"
echo ""

