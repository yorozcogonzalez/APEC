#!/bin/bash
#
# Reading project name, parm file and templatedir from Infos.dat
#
Project=`grep "Project" Infos.dat | awk '{ print $2 }'`
templatedir=`grep "Template" Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" Infos.dat | awk '{ print $2 }'`
prm=`grep "Parameters" Infos.dat | awk '{ print $2 }'`
tinkerdir=`grep "Tinker" Infos.dat | awk '{ print $2 }'`
step=`grep "Step" Infos.dat | awk '{ print $2 }'`
heat=`grep "HeatMD" Infos.dat | awk '{ print $2 }'`
equi=`grep "EquiMD" Infos.dat | awk '{ print $2 }'`
prod=`grep "ProdMD" Infos.dat | awk '{ print $2 }'`
solvent=`grep "SolventBox" Infos.dat | awk '{ print $2 }'`
charge=`grep "Init_Charge" Infos.dat | awk '{ print $2 }'`
numparallel=`grep "Parallel_MD" Infos.dat | awk '{ print $2 }'`

confs=100

if [[ $step -eq 0 ]]; then

   #
   # The folder Templates is created to convert gro into pdb into Tinker xyz
   # and then create the templates
   #
   echo " Converting $Project.gro into $Project-final.pdb,"
   echo " to get atom selections and the xyz file"
   echo ""
 
   if [[ $solvent == "YES" ]]; then
      Project="${Project}_box_sol"
   fi
   mkdir Templates
   cp Dynamic/$Project.gro Templates/final-$Project.gro
   cd Templates
   
   if [[ $charge -ne 0 ]]; then
      if [[ $charge -lt 0 ]]; then
         nions=$(echo "-1*$charge" | bc)
      else
         nions=$charge
      fi
      head -n1 final-$Project.gro > new_final-$Project.gro
      nnum=`head -n2 final-$Project.gro | tail -n1 | awk '{ print $1 }'`
      echo "$(($nnum-$nions))" >> new_final-$Project.gro
      head -n $(($nnum-$nions+2)) final-$Project.gro | tail -n $(($nnum-$nions)) >> new_final-$Project.gro
      mv final-$Project.gro orig_final-$Project.gro
      mv new_final-$Project.gro final-$Project.gro
   else
      nions=0
   fi

   sed -i "s/HOH/SOL/g" final-$Project.gro

   # editconf convert it to PDB and pdb-format-new fixes the format to
   # allow Tinker reading
   #
   cp $templatedir/pdb-format-new.sh .
   $gropath/editconf -f final-${Project}.gro -o final-$Project.pdb -label A
   ./pdb-format-new.sh final-$Project.pdb

   # pdbxyz conversion
   #
   mv final-tk.pdb $Project-tk.pdb
   $tinkerdir/pdbxyz $Project-tk.pdb << EOF
ALL
../$prm
EOF
   echo " Please wait ..."

   if [[ $solvent == "YES" ]]; then
      Project=`grep "Project" ../Infos.dat | awk '{ print $2 }'`
   fi

   #
   #Generation of the templates
   #
   if [[ $solvent == "YES" ]]; then
      numatoms=`head -n2 ../Dynamic/${Project}_box_sol.gro | tail -n1 | awk '{ print $1 }'`
      protwat=`head -n2 ../Dynamic/$Project.gro | tail -n1 | awk '{ print $1 }'`
      numwat=`grep -c "HOH     OW" ../Dynamic/$Project.gro`
      numwatat=$(($numwat*3))

# when solvent box is used the number of atoms of the protein (protatoms) is only used by 
# MD_ASEC.f for computing the rms
      protatoms=$(($protwat-$numwatat))

      ../update_infos.sh "numatoms" $numatoms ../Infos.dat
      ../update_infos.sh "protatoms" $protatoms ../Infos.dat

      cp $templatedir/ASEC/Templates_gro_tk.f .
      if [[ $charge -ne 0 ]]; then
         sed -i "s|numero|$(($numatoms-$nions))|g" Templates_gro_tk.f
      else
         sed -i "s|numero|$numatoms|g" Templates_gro_tk.f
      fi
      cp final-${Project}_box_sol.gro final_Config.gro
      cp ${Project}_box_sol-tk.xyz coordinates_tk.xyz
      cp ../Dynamic/residuetypes.dat .
      gfortran Templates_gro_tk.f -o Templates_gro_tk.x
      ./Templates_gro_tk.x
      if [[ $charge -ne 0 ]]; then
         for i in $(eval echo "{1..$nions}")
         do
           if [[ $(($numatoms+$i)) -lt 1000 ]]; then
              echo "  $(($numatoms-$nions+$i))     $(($numatoms-$nions+$i))" >> template_tk2gro
              echo "  $(($numatoms-$nions+$i))     $(($numatoms-$nions+$i))" >> template_gro2tk
           else
              if [[ $(($numatoms+$i)) -lt 10000 ]]; then
                 echo " $(($numatoms-$nions+$i))    $(($numatoms-$nions+$i))" >> template_tk2gro
                 echo " $(($numatoms-$nions+$i))    $(($numatoms-$nions+$i))" >> template_gro2tk
              else
                 echo "$(($numatoms-$nions+$i))   $(($numatoms-$nions+$i))" >> template_tk2gro
                 echo "$(($numatoms-$nions+$i))   $(($numatoms-$nions+$i))" >> template_gro2tk
              fi
           fi
         done
      fi
   else
      numatoms=`head -n2 ../Dynamic/$Project.gro | tail -n1 | awk '{ print $1 }'`
      protatoms=$numatoms
      ../update_infos.sh "numatoms" $numatoms ../Infos.dat
      ../update_infos.sh "protatoms" $protatoms ../Infos.dat
      cp $templatedir/ASEC/Templates_gro_tk.f .
      sed -i "s|numero|$numatoms|g" Templates_gro_tk.f
      cp final-$Project.gro final_Config.gro
      cp $Project-tk.xyz coordinates_tk.xyz
      cp ../Dynamic/residuetypes.dat .
      gfortran Templates_gro_tk.f -o Templates_gro_tk.x
      ./Templates_gro_tk.x
   fi

   rm final_Config.gro
   rm coordinates_tk.xyz
   cp template_tk2gro ../
   cp template_gro2tk ../
   cd ..
fi
# paso indicates the time step in ps for writing the configurations
if [[ $solvent == "YES" ]]; then
   wrt=`grep "nstxtcout" Dynamic/dynamic_sol_NVT.mdp | awk '{ print $3 }'`
   dt=`grep "dt                      =" Dynamic/dynamic_sol_NVT.mdp | awk '{ print $3 }'`
   paso=$(echo "scale=0; ($dt*$wrt)/1" | bc)
else
   wrt=`grep "nstxtcout" Dynamic/dynamic.mdp | awk '{ print $3 }'`
   dt=`grep "dt =" Dynamic/dynamic.mdp | awk '{ print $3 }'`
   paso=$(echo "scale=0; ($dt*$wrt)/1" | bc)
fi

mkdir MD_ASEC
cp $templatedir/ASEC/MD_ASEC.f MD_ASEC
cp template_gro2tk MD_ASEC
cp template_tk2gro MD_ASEC
cd MD_ASEC

# w means written configurations
heatw=$(echo "scale=0; $heat/$paso" | bc)
equiw=$(echo "scale=0; $equi/$paso" | bc)
prodw=$(echo "scale=0; $prod/$paso" | bc)

echo " These are the number of writen configurations:"
echo "heat  equi  prod"
echo "$heatw $equiw $prodw"
echo " Writing step $paso ps"

# "skip" is the number configurations between the selected ones. It is based
# on the number of the written configurations

# "init" is the time in ps of the fist selected configuration

if [[ $heat -eq 0 ]]; then
   skip=$((($prodw-(300/$paso))/$confs))
   init=$(($prod-300+$skip*$paso))
else
   skip=$(($prodw/$confs))
   init=$(($skip*$paso+$heat+$equi))
fi
echo "init $init" ps
echo "skip $skip" configurations

#$gropath/trjconv -s ../Dynamic/output/$Project.tpr -f ../Dynamic/output/$Project.xtc -b $init -skip $skip -o Selected_100.gro << EOF
#0
#EOF

if [[ $solvent == "YES" ]]; then
   if [[ $numparallel -gt 1 ]]; then
      for i in $(eval echo "{1..$numparallel}")
      do
         $gropath/trjconv -s ../Dynamic/seed_$i/output/${Project}_box_sol.tpr -f ../Dynamic/seed_$i/output/${Project}_box_sol.xtc -b $init -skip $skip -o Selected_100_seed_$i.gro << EOF
0
EOF
         $gropath/trjorder -f Selected_100_seed_$i.gro -s ../Dynamic/seed_$i/output/${Project}_box_sol.tpr -n ../Dynamic/seed_$i/output/${Project}_box_sol.ndx -o Ordered_100_seed_$i.gro
# << EOF
#16
#13
#EOF
         if [[ $i -eq 1 ]]; then
            cp Selected_100_seed_$i.gro Selected_100.gro
            cp Ordered_100_seed_$i.gro Ordered_100.gro
         else
            cat Selected_100.gro Selected_100_seed_$i.gro > temp
            cat Ordered_100.gro Ordered_100_seed_$i.gro > temp2 
            mv temp Selected_100.gro
            mv temp2 Ordered_100.gro
         fi
      done
   else
      $gropath/trjconv -s ../Dynamic/output/${Project}_box_sol.tpr -f ../Dynamic/output/${Project}_box_sol.xtc -b $init -skip $skip -o Selected_100.gro << EOF
0
EOF
      $gropath/trjorder -f Selected_100.gro -s ../Dynamic/output/${Project}_box_sol.tpr -n ../Dynamic/output/${Project}_box_sol.ndx -o Ordered_100.gro
# << EOF
#16
#13
#EOF
   fi
      echo ""
      echo " wait ..."
      echo ""

   if [[ $step -eq 0 ]]; then
      att=`head -n2 Ordered_100.gro | tail -n1 | awk '{ print $1 }'`
      head -n $(($att+3)) Ordered_100.gro > first.gro
      att3=$(($att+3))
      att1=$(($att+1))
      vol=`tail -n1 first.gro | awk '{ print $0 }'`

      echo -e "mol new first.gro type gro" > selection.tcl
      echo -e "mol delrep 0 top" >> selection.tcl
      var1="set selec [ atomselect top \"same residue as (all within 20 of (resname RET and not name CA HA N H C O)) and not (resname NA CL) \" ]"
      echo -e "$var1" >> selection.tcl
      echo -e 'set fileId [open tempnum "w"]' >> selection.tcl
      echo -e 'set numat [$selec num]' >> selection.tcl
      echo -e 'puts $fileId $numat' >> selection.tcl
      echo -e 'close $fileId' >> selection.tcl
      echo -e "exit" >> selection.tcl
      vmd -e selection.tcl -dispdev text
      echo ""
      echo ""
      echo " wait ..."
      shel=`head -n1 tempnum | awk '{ print $1 }'`
      shell=$(($shel+$nions))
      ../update_infos.sh "Shell" "$shell" ../Infos.dat
      rm first.gro selection.tcl tempnum
   else
      shell=`grep "Shell" ../Infos.dat | awk '{ print $2 }'`
   fi
   mv Selected_100.gro Selected_100_full.gro
   att=`head -n2 Ordered_100.gro | tail -n1 | awk '{ print $1 }'`
   att1=$(($att+1))
   att3=$(($att+3))
   vol=`head -n $(($att+3)) Ordered_100.gro | tail -n1 | awk '{ print $0 }'`
#   for i in {1..100}
   for i in $(eval echo "{1..$confs}")
   do
      echo "Generated by MD_ASEC.sh" >> Selected_100.gro
      echo "$shell" >> Selected_100.gro
      head -n $(($att3*$i)) Ordered_100.gro | tail -n $att1 | head -n $shell >> Selected_100.gro
      echo "$vol" >> Selected_100.gro
   done

else

   if [[ $numparallel -gt 1 ]]; then
      for i in $(eval echo "{1..$numparallel}")
      do
         $gropath/trjconv -s ../Dynamic/seed_$i/output/${Project}_box_sol.tpr -f ../Dynamic/seed_$i/output/${Project}_box_sol.xtc -b $init -skip $skip -o Selected_100_seed_$i.gro << EOF
0
EOF
         if [[ $i -eq 1 ]]; then
            cp Selected_100_seed_$i.gro Selected_100.gro
         else
            cat Selected_100.gro Selected_100_seed_$i.gro > temp
            mv temp Selected_100.gro
         fi
      done
   else
      $gropath/trjconv -s ../Dynamic/output/${Project}_box_sol.tpr -f ../Dynamic/output/${Project}_box_sol.xtc -b $init -skip $skip -o Selected_100.gro << EOF
0
EOF
   fi

   $gropath/trjconv -s ../Dynamic/output/$Project.tpr -f ../Dynamic/output/$Project.xtc -b $init -skip $skip -o Selected_100.gro << EOF
0
EOF
fi

if [[ $solvent == "YES" ]]; then
   numatoms=$shell
   protatoms=`grep "protatoms" ../Infos.dat | awk '{ print $2 }'`
else
   numatoms=`grep "numatoms" ../Infos.dat | awk '{ print $2 }'`
   protatoms=`grep "protatoms" ../Infos.dat | awk '{ print $2 }'`
fi

sed -i "s|numero|$numatoms|g" MD_ASEC.f
sed -i "s|protatoms|$protatoms|g" MD_ASEC.f
sed -i "s|confs|$confs|g" MD_ASEC.f
gfortran MD_ASEC.f -o MD_ASEC.x
./MD_ASEC.x

if [[ $solvent == "YES" ]]; then
   best=`tail -n1 rms | awk '{ print $1 }'`
#   best=100
   head -n $(($att3*$best)) Selected_100_full.gro | tail -n $att3 > Best_Config_full.gro
fi

cd ..
cp $templatedir/ASEC/MD_2_QMMM.sh .

echo ""
echo "Continue with MD_2_QMMM.sh"
echo ""

