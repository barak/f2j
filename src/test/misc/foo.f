      program foo
C      external blah
      integer x,y
      double precision z,blah
      x= 12
      y = 34
*
      z=sqrt(blah(x,y))
*
      write(*,*) ' z = ', z
*
      end
*
      double precision function blah(a,b)
      integer a,b
      blah=666.6
      return
      end
