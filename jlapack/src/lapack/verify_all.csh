#!/bin/csh

setenv CPTMP $CLASSPATH":../../blas/blas.jar:../../error_reporting/xerbla.jar"
cd obj
foreach file(org/netlib/lapack/*.class)
  java -classpath $CPTMP de.fub.bytecode.verifier.Verifier $file
end
