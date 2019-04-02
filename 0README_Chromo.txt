1. Extract the iLOV chromophore from the pdb to a new pdb file
3. Add the hydrogens using babel (install babel from here:https://openbabel.org/wiki/Category:Macintosh), it also generate the conectivities: babel -ipdb -h 'iLOV.pdb' -opdb 'iLOVH.pdb'
4. Remove the hydrogens of the phosphate
4. Create the CHR.xyz file, indicating the atom types, connectivities and QM/MM model.
  

