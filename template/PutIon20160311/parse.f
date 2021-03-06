      subroutine parse(chin,irid,natom,q,r)
*
      implicit none
*
      include 'param.h'
*
      integer irid(matom),natom
      double precision q(matom),r(matom,3)
      character*256 chin
*
      integer iatom,ixyz
      character*80 chwrk
*
      write(*,'(a)') 'Parsing pdb file...'
*
      iatom = 0
      open(unit=luin,file=chin,status='old')
 100  read(unit=luin,fmt='(a)',end=200) chwrk
      if (chwrk(1:6).eq.'ATOM  '.or.chwrk(1:6).eq.'HETATM') then
         iatom = iatom+1
         read(chwrk,1000) irid(iatom),(r(iatom,ixyz),ixyz=1,3),q(iatom)
      end if
      go to 100
 200  continue
      close(unit=luin)
      natom = iatom
*
* Note: The format statement below assumes that the 'occupancy' field
* used for storing the atomic charges is eight characters long. This is
* consistent with the output of the pdb2pqr program, but is two
* characters longer than for a normal pdb.
*

** YOE
* 1000 format(22x,i4,4x,4f8.0)
 1000 format(22x,i4,4x,3f10.0,f8.0)
**
*
      write(*,'(a)') 'Done'
      write(*,*)
*
      end
