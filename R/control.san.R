#  File ergm/R/control.san.R
#  Part of the statnet package, http://statnetproject.org
#
#  This software is distributed under the GPL-3 license.  It is free,
#  open source, and has the attribution requirements (GPL Section 7) in
#    http://statnetproject.org/attribution
#
#  Copyright 2010 the statnet development team
######################################################################
control.san<-function(prop.weights="default",
                      prop.args=NULL,
                      drop=FALSE,
                      maxedges=20000,
                      maxchanges=1000000,
                      packagenames="ergm",
                      network.output="network",
                      parallel=0){
  control<-list()
  for(arg in names(formals(sys.function())))
    control[[arg]]<-get(arg)
  control
}