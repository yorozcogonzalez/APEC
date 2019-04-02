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
annealing=`grep "Annealing" Infos.dat | awk '{ print $2 }'`
cavity=`grep "CavityFile" Infos.dat | awk '{ print $2 }'`

# If Gromacs is used, no HF/3-21G single point was run, skipping the check
#
if [[ -d Dynamic ]]; then
   ./smooth_restart.sh Dynamic "Do you want to re-run MD? (y/n)" 2
   if [[ ! -f Infos.dat ]]; then
      mv no.Infos.dat Infos.dat
      exit 0
   fi
fi
echo ""
echo " Checking for correct termination of H adjustment with Gromacs..."
echo ""
if [[ $annealing == "yes" ]]; then
   cp Annealing_$Project/output/final-$Project.gro Annealing_$Project/
   lasto="Annealing_$Project"
else
   lasto="Minimize_$Project"
fi
cd $lasto
if [ -f final-$Project.gro  ]; then
   echo " Everything fine, going on..."
   echo ""
else
   echo " final-$Project.gro not found! Aborting..."
   echo ""
   exit 0
fi
cd ..

# Selection between MM minimization or MD
#
answer=0
while  [[ $answer -ne 1 && $answer -ne 2 && $answer -ne 3 && $answer -ne 4 && $answer -ne 5 ]]; do
       echo " Now, select what you want to do:"
       echo ""
       echo " 1) MM minimization on cavity sidechains"
       echo " 2) MD on cavity hydrogens"
       echo " 3) MD on cavity sidechains"
       echo " 4) All hydrogens MD"
       echo " 5) All sidechains MD"
       echo ""
       read answer
done
   
# Asking if retinal has to be moveable during MD
#
risposta=b
while [[ $risposta != y && $risposta != n ]]; do
      echo " Do you want to move also the retinal moiety? (y/n)"
      read risposta
done

# Preparing the Dynamic folder with the correct files 
#
checkrest=`grep 'ReStRun_2' Infos.dat | wc -l`
mkdir Dynamic
cp $lasto/final-$Project.gro Dynamic/$Project.gro
cp $lasto/$Project.top Dynamic/
cp -r $lasto/amber94.ff Dynamic/
cp $lasto/residuetypes.dat Dynamic/
cp $lasto/*.itp Dynamic/
cp $templatedir/standard-EM.mdp Dynamic/
cp $templatedir/ndx-maker.sh Dynamic/
cp $templatedir/soglia Dynamic/
cd Dynamic/

# Preparing the selection for Gromacs dynamics or minimization
#
case $answer in
     1) mode=Minimization
        if [[ $cavity != YES ]]; then
           echo " Please type the radius in Angstrom"
           read raggio
           echo ""
           while [[ $raggio -lt 4 || $raggio -gt 30 ]]; do
                 echo " Radius $raggio is too small or too large"
                 echo " Please type another one"
                 read raggio
                 echo ""
           done
           if [[ $raggio -ge 8 ]]; then
              echo " WARNING! You selected a large radius"
              echo " Check if the vacuum is far enough"
              echo ""
           fi
        else
           raggio="ND"
        fi
        ../update_infos.sh $checkrest "RadiusMD" $raggio ../Infos.dat
        ./ndx-maker.sh $Project 2 0 $risposta
     ;;
     2) mode=Dynamic
        ../update_infos.sh $checkrest "MDRelax" "Hydrogen" ../Infos.dat
        echo '2' > choices.txt
        echo 'q' >> choices.txt
        $gropath/make_ndx -f $Project.gro -o $Project.ndx < choices.txt
        rm choices.txt
        ./ndx-maker.sh $Project 1 0 $risposta
     ;;
     3) mode=Dynamic
        ../update_infos.sh $checkrest "MDRelax" "Cavity" ../Infos.dat
        if [[ $cavity != YES ]]; then
           echo " Please type the radius in Angstrom"
           read raggio
           echo ""
           while [[ $raggio -lt 4 || $raggio -gt 9 ]]; do
                 echo " Radius $raggio is too small or too large"
                 echo " Please type another one"
                 read raggio
                 echo ""
           done
           if [[ $raggio -ge 8 ]]; then
              echo " WARNING! You selected a large radius"
              echo " Check if the vacuum is far enough"
              echo ""
           fi
        else
           raggio="ND"
        fi
        ../update_infos.sh $checkrest "RadiusMD" $raggio ../Infos.dat
        backb=2
        echo " Please type 1 if you want to relax the backbone, 0 otherwise"
        while [[ $backb -ne 1 && $backb -ne 0 ]]; do
              read backb
        done
#
# Add the backbone choice to Infos.dat for further use
#
        ../update_infos.sh $checkrest "BackBoneMD" $backb ../Infos.dat
        echo ""
        echo '2' > choices.txt
        echo 'q' >> choices.txt
        $gropath/make_ndx -f $Project.gro -o $Project.ndx < choices.txt
        rm choices.txt
        ./ndx-maker.sh $Project 2 $backb $risposta
     ;;
     4) mode=Dynamic
        ../update_infos.sh $checkrest "MDRelax" "AllH" ../Infos.dat
        echo '2' > choices.txt
        echo 'q' >> choices.txt
        $gropath/make_ndx -f $Project.gro -o $Project.ndx < choices.txt
        rm choices.txt
        ./ndx-maker.sh $Project 3 0 $risposta
     ;;
     5) mode=Dynamic
        ../update_infos.sh $checkrest "MDRelax" "AllSide" ../Infos.dat
        echo '2' > choices.txt
        echo 'q' >> choices.txt
        $gropath/make_ndx -f $Project.gro -o $Project.ndx < choices.txt
        rm choices.txt
        ./ndx-maker.sh $Project 4 0 $risposta
     ;;
     *) echo "Not ready"
     ;;
esac
../update_infos.sh $checkrest "Mode" $mode ../Infos.dat
#
# Different action to be taken according to different setups
#
case $answer in 
     1) sed -i "s/Protein-H Group1/GroupDyna/; s/Y Y Y Y Y Y/Y Y Y/" standard-EM.mdp
        $gropath/grompp -f standard-EM.mdp -c $Project.gro -n $Project.ndx -p $Project.top -o $Project.tpr
        cp $templatedir/minimization.sh .
        ./minimization.sh 
     ;;
     2) cp $templatedir/moldynamic.sh .
        ./moldynamic.sh
     ;;
     3) cp $templatedir/moldynamic.sh .
        ./moldynamic.sh
     ;; 
     4) cp $templatedir/moldynamic.sh .
        ./moldynamic.sh
     ;;
     5) cp $templatedir/moldynamic.sh .
        ./moldynamic.sh
     ;;
esac

cd ..
cp $templatedir/new2mins.sh .
if [[ $mode == "Dynamic" ]]; then
   cp $templatedir/Analysis_MD.sh .
   echo " Wait for molecular dynamics to end, then:"
   echo " - run Analysis_MD.sh to analyze your MD run"
   echo " - when you are satisfied, run new2mins.sh to execute the post-MD minimization"
else
   echo " Now run new2mins.sh"
fi
echo ""

