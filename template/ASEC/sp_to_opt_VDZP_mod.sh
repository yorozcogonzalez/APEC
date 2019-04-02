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
echo " The current project is $Project. Checking the CAS/6-31G* single point..."
echo ""

# Checking if the single point ended successfully, with control on folder existence
#
sp=${Project}_VDZP
if [ -d $sp ]; then
   cd $sp
   contr=`grep 'landing' $sp.out | awk '{ print $1 }'`
   if [[ $contr == "Happy" ]]; then
      echo " CAS/VDZP single point ended successfully" 
      echo ""
   else
      echo " CAS/VDZP single point still in progress. Terminating..."
      echo ""
      exit 0
   fi
else
   echo " CAS/VDZP single point folder not found! Check what is wrong"
   echo " Terminating..."
   echo ""
   exit 0
fi

# Retrieving the occupation numbers from CAS single point for checking purposes
#
grep -A2 "Natural orbitals and occupation numbers for root  1" ${sp}.out

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
            echo " Going ahead with the CAS/VDZP optimization"
	    echo ""
	 else
	    echo " You might have a problem with active space selection. To fix it:"
            echo " 1. - Use Molden to look at the orbitals in $sp.rasscf.molden"
	    echo " 2. - Find the right orbital(s) to be placed in the active space"
	    echo " 3. - Run the script alter_orbital_mod.sh"
	    echo ""
	    echo " sp_to_opt_VDZP.sh will terminate"
	    echo ""
	    cp $templatedir/ASEC/alter_orbital_mod.sh .
	    exit 0
	 fi
      fi
done

# Preparing the files for CAS/6-31G* optimization 
# If the folder exists, the script is aborted with an error
#
cd ..
new=${Project}_VDZP_Opt
if [ -d $new ]; then
  ./smooth_restart.sh $new "Do you want to re-run the QM/MM VDZP optimization? (y/n)" 8
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
cp $templatedir/molcas.slurm.sh ${new}/molcas-job.sh
#cp $templatedir/molcas-job.sh ${new}/

cp $templatedir/ASEC/template_CASSCF_min ${new}/
#cp $templatedir/modify-inp.vim ${new}/
cd ${new}/

# Editing the template for the CAS optimization
#
sed -i "s|PARAMETRI|${prm}|" template_CASSCF_min

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

# Merging the geometrical part and the template for CAS optimization
#
#mv ${new}.input temp
#cat temp template > ${new}.input
#rm temp template

mv template_CASSCF_min ${new}.input
sed -i "s/ANO-L-VDZ/ANO-L-VDZP/g" ${new}.input
sed -i "/rHidden = 4.0/a> COPY \$WorkDir/\$Project.RunFile \$InpDir/\$Project.Hessian_new" ${new}.input

# Writing the project name, the input directory, time and memory requested in the submission script
# Here there is a CASSCF/6-31G* optimization, so 2 Gb should be enough...
# The maximum available hours, 144 hrs (6 days), are requested
#
sed -i "s|NOMEPROGETTO|${new}|" molcas-job.sh
no=$PWD
sed -i "s|NOMEDIRETTORI|${no}|" molcas-job.sh
sed -i "s|MEMTOT|23000|" molcas-job.sh
sed -i "s|MEMORIA|20000|" molcas-job.sh
sed -i "s|hh:00:00|120:00:00|" molcas-job.sh
#slurm
#sed -i "/#PBS -l mem=/a#PBS -A PAA0009" molcas-job.sh
#sed -i "s|ppn=4|ppn=8|" molcas-job.sh

# Job submission and template copy for the following step
#
echo ""
echo " Submitting the CAS/VDZP optimization now..."
echo ""
sleep 1

#slurm
#mv molcas-job.sh molcas.slurm.sh
sbatch molcas-job.sh
#qsub molcas-job.sh

cd ..
#cp $templatedir/ASEC/3rd_to_4th_mod.sh .
cp $templatedir/ASEC/finalPDB_mod.sh .
#cp $templatedir/ASEC/Energies_CASPT2.sh .
 
# Updating the Infos.dat Current field, which stores the current running calculation
#
awk '{ if ( $1 == "CurrCalc") sub($2,"VDZP_Opt"); print}' ../Infos.dat > temp
mv temp ../Infos.dat

echo ""
echo ""
echo " As soon as the calculation is finished run finalPDB_mod.sh"
echo " to continue the iterative procedure. The CASPT2 energies corresponding"
echo " to this optimized structure should be calculated in the next step"
echo " after the MD, by using Energies_CASPT2.sh"
echo ""

