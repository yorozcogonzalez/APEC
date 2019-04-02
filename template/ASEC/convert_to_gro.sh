#!/bin/bash
#

Project=`grep "Project" ../../Infos.dat | awk '{ print $2 }'`
Lys=`grep "LysNum" ../../Infos.dat | awk '{ print $2 }'`
Chain=`grep "RetChain" ../../Infos.dat | awk '{ print $2 }'`
gropath=`grep "GroPath" ../../Infos.dat | awk '{ print $2 }'`

################################

grep "ATOM " ${Project}_final.pdb > $Project.pdb

grep " RET Z   1 " $Project.pdb > RETI
sed "/ RET Z   1 /d" $Project.pdb > ${Project}_fixed.pdb

grep " ACI " ${Project}_fixed.pdb > CLORI
sed -i "/ ACI /d" ${Project}_fixed.pdb
grep " ACH " ${Project}_fixed.pdb >> CLORI
sed -i "/ ACH /d" ${Project}_fixed.pdb

grep " CL " ${Project}_fixed.pdb >> CLORI
grep " NA " ${Project}_fixed.pdb >> CLORI
sed -i "/ CL /d" ${Project}_fixed.pdb
sed -i "/ NA /d" ${Project}_fixed.pdb
sed -i "/CONECT/d" ${Project}_fixed.pdb
sed -i "/END/d" ${Project}_fixed.pdb
sed -i "/HEADER/d" ${Project}_fixed.pdb
sed -i "/COMPND/d" ${Project}_fixed.pdb
sed -i "/SOURCE/d" ${Project}_fixed.pdb
grep " WAT " ${Project}_fixed.pdb > WATER
sed -i "/ WAT /d" ${Project}_fixed.pdb

if [ $Lys -lt 10 ]; then
   sed -i "s/ RET Z   1 / RET $Chain   $Lys /g" RETI
   sed -i "s/LYS "$Chain"   "$Lys"/RET "$Chain" "$Lys"/g" ${Project}_fixed.pdb
fi
if [ $Lys -ge 10 ] && [ $Lys -lt 100 ]; then
   sed -i "s/ RET Z   1 / RET $Chain  $Lys /g" RETI
   sed -i "s/LYS "$Chain"  "$Lys"/RET "$Chain" "$Lys"/g" ${Project}_fixed.pdb
fi
if [ $Lys -ge 100 ] && [ $Lys -lt 1000 ]; then
   sed -i "s/ RET Z   1 / RET $Chain $Lys /g" RETI
   sed -i "s/LYS "$Chain" "$Lys"/RET "$Chain" "$Lys"/g" ${Project}_fixed.pdb
fi

LastRet=`grep -n " HZ1 RET " ${Project}_fixed.pdb | awk '{ print $1 }' FS=":"`
head -n $LastRet ${Project}_fixed.pdb > temp1
cat temp1 RETI > temp2
sed -e "1,$LastRet d" ${Project}_fixed.pdb > temp3
cat temp2 temp3 > temp5
echo "TER" >> temp5
mv temp5 ${Project}_fixed.pdb

#sed -i "s/ OT  WAT / OW  HOH /g" WATER
#sed -i "s/ HT  WAT / HW1 HOH /g" WATER
#sed -i "s/ HT  WAT / HW2 HOH /g" WATER

#####################

sed -i "s/ HB2 MET / HB1 MET /g" ${Project}_fixed.pdb
sed -i "s/ HB2 ASN / HB1 ASN /g" ${Project}_fixed.pdb
sed -i "s/ HB2 GLU / HB1 GLU /g" ${Project}_fixed.pdb
sed -i "s/ HB2 PRO / HB1 PRO /g" ${Project}_fixed.pdb
sed -i "s/ HB2 PHE / HB1 PHE /g" ${Project}_fixed.pdb
sed -i "s/ HB2 TYR / HB1 TYR /g" ${Project}_fixed.pdb
sed -i "s/ HB2 SER / HB1 SER /g" ${Project}_fixed.pdb
sed -i "s/ HB2 LYS / HB1 LYS /g" ${Project}_fixed.pdb
sed -i "s/ HB2 ARG / HB1 ARG /g" ${Project}_fixed.pdb
sed -i "s/ HB2 GLN / HB1 GLN /g" ${Project}_fixed.pdb
sed -i "s/ HB2 LEU / HB1 LEU /g" ${Project}_fixed.pdb
sed -i "s/ HB2 TRP / HB1 TRP /g" ${Project}_fixed.pdb
sed -i "s/ HB2 HIS / HB1 HIS /g" ${Project}_fixed.pdb
sed -i "s/ HB2 CYS / HB1 CYS /g" ${Project}_fixed.pdb
sed -i "s/ HB2 ASP / HB1 ASP /g" ${Project}_fixed.pdb
sed -i "s/ HB2 RET / HB1 RET /g" ${Project}_fixed.pdb


sed -i "s/ HB3 MET / HB2 MET /g" ${Project}_fixed.pdb
sed -i "s/ HB3 ASN / HB2 ASN /g" ${Project}_fixed.pdb
sed -i "s/ HB3 GLU / HB2 GLU /g" ${Project}_fixed.pdb
sed -i "s/ HB3 PRO / HB2 PRO /g" ${Project}_fixed.pdb
sed -i "s/ HB3 PHE / HB2 PHE /g" ${Project}_fixed.pdb
sed -i "s/ HB3 TYR / HB2 TYR /g" ${Project}_fixed.pdb
sed -i "s/ HB3 SER / HB2 SER /g" ${Project}_fixed.pdb
sed -i "s/ HB3 LYS / HB2 LYS /g" ${Project}_fixed.pdb
sed -i "s/ HB3 ARG / HB2 ARG /g" ${Project}_fixed.pdb
sed -i "s/ HB3 GLN / HB2 GLN /g" ${Project}_fixed.pdb
sed -i "s/ HB3 LEU / HB2 LEU /g" ${Project}_fixed.pdb
sed -i "s/ HB3 TRP / HB2 TRP /g" ${Project}_fixed.pdb
sed -i "s/ HB3 HIS / HB2 HIS /g" ${Project}_fixed.pdb
sed -i "s/ HB3 CYS / HB2 CYS /g" ${Project}_fixed.pdb
sed -i "s/ HB3 ASP / HB2 ASP /g" ${Project}_fixed.pdb
sed -i "s/ HB3 RET / HB2 RET /g" ${Project}_fixed.pdb

###########

sed -i "s/ HG2 MET / HG1 MET /g" ${Project}_fixed.pdb
sed -i "s/ HG2 PRO / HG1 PRO /g" ${Project}_fixed.pdb
sed -i "s/ HG2 GLU / HG1 GLU /g" ${Project}_fixed.pdb
sed -i "s/ HG2 ARG / HG1 ARG /g" ${Project}_fixed.pdb
sed -i "s/ HG2 LYS / HG1 LYS /g" ${Project}_fixed.pdb
sed -i "s/ HG2 GLN / HG1 GLN /g" ${Project}_fixed.pdb
sed -i "s/ HG2 RET / HG1 RET /g" ${Project}_fixed.pdb

sed -i "s/ HG3 MET / HG2 MET /g" ${Project}_fixed.pdb
sed -i "s/ HG3 PRO / HG2 PRO /g" ${Project}_fixed.pdb
sed -i "s/ HG3 GLU / HG2 GLU /g" ${Project}_fixed.pdb
sed -i "s/ HG3 ARG / HG2 ARG /g" ${Project}_fixed.pdb
sed -i "s/ HG3 LYS / HG2 LYS /g" ${Project}_fixed.pdb
sed -i "s/ HG3 GLN / HG2 GLN /g" ${Project}_fixed.pdb
sed -i "s/ HG3 RET / HG2 RET /g" ${Project}_fixed.pdb

###########

sed -i "s/ HD2 PRO / HD1 PRO /g" ${Project}_fixed.pdb
sed -i "s/ HD2 LYS / HD1 LYS /g" ${Project}_fixed.pdb
sed -i "s/ HD2 ARG / HD1 ARG /g" ${Project}_fixed.pdb
sed -i "s/ HD2 RET / HD1 RET /g" ${Project}_fixed.pdb

sed -i "s/ HD3 PRO / HD2 PRO /g" ${Project}_fixed.pdb
sed -i "s/ HD3 LYS / HD2 LYS /g" ${Project}_fixed.pdb
sed -i "s/ HD3 ARG / HD2 ARG /g" ${Project}_fixed.pdb
sed -i "s/ HD3 RET / HD2 RET /g" ${Project}_fixed.pdb

###########

sed -i "s/ HE2 LYS / HE1 LYS /g" ${Project}_fixed.pdb
sed -i "s/ HE2 RET / HE1 RET /g" ${Project}_fixed.pdb

sed -i "s/ HE3 LYS / HE2 LYS /g" ${Project}_fixed.pdb
sed -i "s/ HE3 RET / HE2 RET /g" ${Project}_fixed.pdb


sed -i "s/ 1HA  GLY /  HA1 GLY /g" ${Project}_fixed.pdb
sed -i "s/ HA3 GLY / HA2 GLY /g" ${Project}_fixed.pdb


sed -i "s/ HG12 ILE / HG11 ILE /g" ${Project}_fixed.pdb
sed -i "s/ HG13 ILE / HG12 ILE /g" ${Project}_fixed.pdb

###########
###########
#RET
###########
###########

sed -i "s/ C10 RET / CF  RET /" ${Project}_fixed.pdb
sed -i "s/ C11 RET / CI  RET /" ${Project}_fixed.pdb
sed -i "s/ C12 RET / CJ  RET /" ${Project}_fixed.pdb
sed -i "s/ C14 RET / CK  RET /" ${Project}_fixed.pdb
sed -i "s/ C15 RET / CM  RET /" ${Project}_fixed.pdb
sed -i "s/ C16 RET / CO  RET /" ${Project}_fixed.pdb
sed -i "s/ C17 RET / CP  RET /" ${Project}_fixed.pdb
sed -i "s/ C18 RET / CQ  RET /" ${Project}_fixed.pdb
sed -i "s/ C19 RET / CU  RET /" ${Project}_fixed.pdb
sed -i "s/ C20 RET / CX  RET /" ${Project}_fixed.pdb

sed -i "s/ H21 RET /HC21 RET /" ${Project}_fixed.pdb
sed -i "s/ H22 RET /HC22 RET /" ${Project}_fixed.pdb
sed -i "s/ H23 RET /HC31 RET /" ${Project}_fixed.pdb
sed -i "s/ H24 RET /HC32 RET /" ${Project}_fixed.pdb
sed -i "s/ H25 RET /HC41 RET /" ${Project}_fixed.pdb
sed -i "s/ H26 RET /HC42 RET /" ${Project}_fixed.pdb
sed -i "s/ H27 RET /HC71 RET /" ${Project}_fixed.pdb
sed -i "s/ H28 RET /HC81 RET /" ${Project}_fixed.pdb
sed -i "s/ H29 RET /HCF1 RET /" ${Project}_fixed.pdb
sed -i "s/ H30 RET /HCI1 RET /" ${Project}_fixed.pdb
sed -i "s/ H31 RET /HCJ1 RET /" ${Project}_fixed.pdb
sed -i "s/ H32 RET /HCK1 RET /" ${Project}_fixed.pdb
sed -i "s/ H33 RET /HCM1 RET /" ${Project}_fixed.pdb
sed -i "s/ H34 RET /HCO1 RET /" ${Project}_fixed.pdb
sed -i "s/ H35 RET /HCO2 RET /" ${Project}_fixed.pdb
sed -i "s/ H36 RET /HCO3 RET /" ${Project}_fixed.pdb
sed -i "s/ H37 RET /HCP1 RET /" ${Project}_fixed.pdb
sed -i "s/ H38 RET /HCP2 RET /" ${Project}_fixed.pdb
sed -i "s/ H39 RET /HCP3 RET /" ${Project}_fixed.pdb
sed -i "s/ H40 RET /HCQ1 RET /" ${Project}_fixed.pdb
sed -i "s/ H41 RET /HCQ2 RET /" ${Project}_fixed.pdb
sed -i "s/ H42 RET /HCQ3 RET /" ${Project}_fixed.pdb
sed -i "s/ H43 RET /HCU1 RET /" ${Project}_fixed.pdb
sed -i "s/ H44 RET /HCU2 RET /" ${Project}_fixed.pdb
sed -i "s/ H45 RET /HCU3 RET /" ${Project}_fixed.pdb
sed -i "s/ H46 RET /HCX1 RET /" ${Project}_fixed.pdb
sed -i "s/ H47 RET /HCX2 RET /" ${Project}_fixed.pdb
sed -i "s/ H48 RET /HCX3 RET /" ${Project}_fixed.pdb

# replacing the HIS residues by the corresponding 
# protonation state taken from the initial pdb file

grep " HIS " ${Project}_fixed.pdb > temp1

ii=`wc -l temp1 | awk '{ print $1 }'`
if [[ $ii -gt 0 ]]; then
   cont=1

   n=`head -n1 temp1 | awk '{ print $6 }'`
   hischain=`head -n1 temp1 | awk '{ print $5 }'`
   echo "$n $hischain"> temp2

   for i in $(eval echo "{2..$ii}")
   do
    k=`head -n $i temp1 | tail -n1 | awk '{ print $6 }'`
    hischain=`head -n $i temp1 | tail -n1 | awk '{ print $5 }'`
    if [[ $k != $n ]]; then
     echo "$k $hischain" >> temp2
     n=$k
    fi
   done
   rm temp1

   ii=`wc -l temp2 | awk '{ print $1 }'`
   i=1
   for i in $(eval echo "{1..$ii}")
   do
     his=`head -n $i temp2 | tail -n1 | awk '{ print $1 }'`
     hischain=`head -n $i temp2 | tail -n1 | awk '{ print $2 }'`

     if [ $his -lt 10 ]; then
       state=`grep " $hischain   $his " ${Project}_init.pdb | head -n1 | awk '{ print $4 }'`
       sed -i "s/ HIS $hischain   $his / $state $hischain   $his /g" ${Project}_fixed.pdb
     fi
     if [ $his -ge 10 ] && [ $his -lt 100 ]; then
       state=`grep " $hischain  $his " ${Project}_init.pdb | head -n1 | awk '{ print $4 }'`
       sed -i "s/ HIS $hischain  $his / $state $hischain  $his /g" ${Project}_fixed.pdb
     fi
     if [ $his -ge 100 ] && [ $his -lt 1000 ]; then
       state=`grep " $hischain $his " ${Project}_init.pdb | head -n1 | awk '{ print $4 }'`
       sed -i "s/ HIS $hischain $his / $state $hischain $his /g" ${Project}_fixed.pdb
     fi
   done
   rm temp2
else
   rm temp1
fi
echo ""
echo " wait ..."
echo ""

#
# Inserting TER between two chains
#
atoms=`grep -c "ATOM " ${Project}_fixed.pdb`
chain="A"
cont=0
cp ${Project}_fixed.pdb temmp
for i in $(eval echo "{1..$atoms}")
do
   newchain=`head -n $i ${Project}_fixed.pdb | tail -n1 | awk '{ print $5 }'`
   if [[ $newchain != $chain ]]; then
      chain=$newchain 
      sed "$(($i+$cont))iTER" temmp > temmp2
      cont=$cont+1
      mv temmp2 temmp
   fi
done

mv temmp ${Project}_fixed.pdb

#cat ${Project}_fixed.pdb WATER CLORI > ${Project}_fixed2.pdb
#mv ${Project}_fixed2.pdb ${Project}_fixed.pdb
rm temp* RETI CLORI WATER

#mv $Project.pdb ${Project}_back.pdb
mv ${Project}_fixed.pdb Protein.pdb
rm $Project.pdb

$gropath/pdb2gmx -f Protein.pdb -o Protein.gro -p $Project.top -ff amber94 -water tip3p 2> grolog
rm $Project.top
checkgro=`grep 'Writing coordinate file...' grolog`

# removing the volume and header

nume=`wc -l Protein.gro | awk '{ print $1 }'`
head -n $(($nume-1)) Protein.gro | tail -n $(($nume-3)) > temp
mv temp Protein.gro

if [[ -z $checkgro ]]; then
   echo " An error occurred during the execution of pdb2gmx. Please look into grolog file"
   echo " No further operation performed. Aborting..."
   echo ""
   exit 0
else
   echo " The ${Project}_box_sol.gro file was successfully generated"
   echo ""
fi

