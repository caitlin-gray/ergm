#  File R/ergm.degeneracy.R in package ergm, part of the Statnet suite
#  of packages for network analysis, http://statnet.org .
#
#  This software is distributed under the GPL-3 license.  It is free,
#  open source, and has the attribution requirements (GPL Section 7) at
#  http://statnet.org/attribution
#
#  Copyright 2003-2018 Statnet Commons
#######################################################################

#' Checks an ergm Object for Degeneracy
#' 
#' The \code{ergm.degeneracy} function checks a given ergm object for
#' degeneracy by computing and returning the instability value of the model and
#' the value of the log-likelihood function at the maximized theta values
#' 
#' 
#' @param object an \code{\link{ergm}} object
#' @param control the list of control parameters as returned by
#' \code{control.ergm}; default=control.ergm()
#' @param fast whether the degeneracy check should be "fast", i.e to sample
#' changeobs(?) when there are > 100, rather than use all changeobs;
#' default=TRUE
#' @param test.only whether to silence printing of the model instability
#' calculation (T or F); this parameter is ignored if the instability > 1;
#' default=FALSE
#' @param verbose whether to print a notification when 'object' is deemed
#' degenerate (T or F); default=FALSE
#' @return returns the original ergm object with 2 additional components:
#' \item{degeneracy.value}{the instability of the model}
#' \item{degeneracy.type}{a 2-element vector containing \describe{
#' \item{`loglikelihood`}{the value of the log-likelihood function corresponding to 'theta'; if degenerate, this is a vector of Inf}
#' \item{`theta`}{the vector of theta values found through maximixing the log- likelihood; if degenerate, this is 'guess' }
#' }
#' }
#' @export ergm.degeneracy
ergm.degeneracy <- function(object, 
                          control=object$control,
                          fast=TRUE,
                          test.only=FALSE,
                          verbose=FALSE) {
  check.control.class("ergm", "ergm.degeneracy")
  
  if(!is.ergm(object)){
    stop("A ergm object argument must be given.")
  }
  if(is.matrix(object$sample)){
   if(is.null(object$mplefit$glm)){
    current.warn <- options()$warn
    options(warn=-1)
    fit <- try(ergm(object$formula, estimate="MPLE"),silent=TRUE)
    options(warn=current.warn)
    if(inherits(fit,"try-error")){
     object$degeneracy.value <- NA
     object$degeneracy.type <- NULL
     return(invisible(object))
    }
    if(is.null(fit$mplefit)){
     object$mplefit$glm <- fit$glm
    }else{
     object$mplefit <- fit$mplefit
    }
   }
   # So a MCMC fit
   if(object$loglikelihood>control$MCMLE.trustregion-0.1){
    object$degeneracy.value <- Inf
   }else{
    changeobs <- (-2*object$mplefit$glm$y+1)*model.matrix(object$mplefit$glm)
    if(fast && nrow(changeobs) > 100){
     index <- sample((1:nrow(changeobs)), size=100, replace=FALSE)
     changeobs <- changeobs[index,]
     wgts <- object$mplefit$glm$prior.weights[index]
    }else{
     wgts <- object$mplefit$glm$prior.weights
     if(nrow(changeobs) > 1000){
      message("This computation may take a while ...")
     }
    }
    object$degeneracy.type <- try(
      apply(changeobs, 1, ergm.compute.degeneracy,
      init=object$MCMCtheta, etamap=object$etamap, 
      statsmatrix=object$sample[,!object$etamap$offsettheta,drop=FALSE],
      trustregion=control$MCMLE.trustregion),silent=TRUE)
    if(inherits(object$degeneracy.type,"try-error")){
     object$degeneracy.value <- Inf
     object$degeneracy.type <- NULL
    }else{
     object$degeneracy.type <- t(rbind(object$degeneracy.type,wgts))
     colnames(object$degeneracy.type)[ncol(object$degeneracy.type)] <- "num.dyads"
     object$degeneracy.value <- max(object$degeneracy.type[,1],na.rm=TRUE)
    }
   }
  }else{
   # So a non-MCMC fit
   if("glm" %in% class(object$glm)){
   # So the MPLE was fit
    # This is the change in log-likelihood for logistic regression
#   object$degeneracy.type <- abs(model.matrix(object$glm) %*% object$glm$coef)
    changebeta <- t(influence(object$glm,do.coef=TRUE)$coefficients/object$glm$prior.weights)
#   newbeta <- sweep(changebeta,1,object$glm$coef,"+")
#   changexbeta <- diag(model.matrix(object$glm) %*% newbeta)
    changexchangebeta <- as.matrix(model.matrix(object$glm)) %*% changebeta
    pi <- predict(object$glm,type="response")
    changexpi <- pi %*% as.matrix(model.matrix(object$glm)) 
    changenorm <- as.vector(pi %*% changexchangebeta)*object$glm$prior.weights
    changeobs <- as.vector(object$glm$y %*% changexchangebeta)
    changesum <- changeobs * object$glm$prior.weights
    changey <- as.vector((2*object$glm$y-1) * diag(changexchangebeta))
#   changeobs <- changexbeta %*% (object$glm$prior.weights*object$glm$y)
#   object$degeneracy.type <- abs(sum(changeobs) - changexbeta*(2*object$glm$y-1))
    object$degeneracy.type <- abs(changesum-changey-changenorm)
#   object$degeneracy.type <- changey
    wgts <- object$glm$prior.weights
    object$degeneracy.type <- cbind(object$degeneracy.type,wgts)
    colnames(object$degeneracy.type) <- c("delta.log.lik","num.dyads")
    object$degeneracy.value <- max(object$degeneracy.type[,1],na.rm=TRUE)
   }else{
    object$degeneracy.value <- Inf
    object$degeneracy.type <- NULL
   }
  }
  if(object$degeneracy.value>control$MCMLE.trustregion-0.1){
   object$degeneracy.value <- Inf
  }
  if(is.infinite(object$degeneracy.value)){
   cat("\n Warning: The diagnostics indicate that the model is very unstable.\n   They suggest that the model is degenerate,\n   and that the numerical summaries are suspect.\n")
  }else{
    if(!test.only || object$degeneracy.value > 1){
     cat("The instability of the model is: ",
        format(object$degeneracy.value, digits=2),"\n")
    }
    if(object$degeneracy.value > 1){
      cat("Instabilities greater than 1 suggest the model is degenerate.\n")
    }
  }
  if(verbose){
    message_print(object$degeneracy.type)
  }
  return(invisible(object))
}





#######################################################################################
# The <ergm.compute.degeneracy> function is a helper function to <ergm.degenarcy> that
# establishes the 'degeneracy.type'
#
# --PARAMETERS--
#   xobs       : the changeobs
#   init     : the initial model parameters
#   etamap     : the theta-> eta mapping, as returned by <ergm.etamap>
#   statsmatrix: the sample summary statistics
#   nr.maxit   : the maximum number of iterations to be used by the native R
#                routine <optim>; default=100
#   nr.reltol  : the relative convergence tolerance; see ?optim for details;
#                default=.01
#   verbose    : whether the result as degenerate or not should be printed (T or F);
#                default=FALSE
#   trace      : an integer specifying how many levels of tracing should
#                should be printed during optimazition via the <optim> routine;
#                default=6*verbose
#   hessian    : whether a numerically differentiated Hessian matrix should be
#                returned by <optim>; default=FALSE
#   guess      : initial values used by the optimization routine <optim> ;
#   trustregion:  the maximum value of the log-likelihood ratio that is trusted;
#                default=20   
#
#
# --IGNORED PARAMETERS--
#   epsilon: ??; default=1e-10 
#   ...    : to accomodate additional parameters passed from within the program   
# 
# --RETURNED--
#   a 2-element vector containing  
#     loglikelihood: the value of the log-likelihood function corresponding to 'theta';
#                    if degenerate, this is a vector of Inf
#     theta        : the vector of theta values found through maximixing the log-
#                    likelihood; if degenerate, this is 'guess'
#
##########################################################################################

ergm.compute.degeneracy<-function(xobs, init, etamap, statsmatrix,
                        epsilon=1e-10, nr.maxit=100, nr.reltol=0.01,
                        verbose=FALSE, trace=6*verbose,
                        hessian=FALSE, guess=init,
                        trustregion=20, ...) {
  samplesize <- dim(statsmatrix)[1]
  statsmatrix0 <- statsmatrix
  probs <- rep(1/nrow(statsmatrix0),nrow(statsmatrix0))
  statsmatrix0.obs <- NULL
  probs.obs <- NULL
  av <- apply(sweep(statsmatrix0,1,probs,"*"), 2, sum)
  xsim <- sweep(statsmatrix0, 2, av,"-")
  xsim.obs <- NULL
  probs.obs <- NULL
  xobs <- -xobs - av
#
# Set up the initial estimate
#
  if (verbose) message("Converting init to eta0")
  eta0 <- ergm.eta(init, etamap) #unsure about this
  etamap$init <- init
#
# Log-Likelihood and gradient functions
#
  varweight <- 0.5
  if (verbose) message("Optimizing loglikelihood")
  Lout <- try(optim(par=guess, 
                    fn=llik.fun, #  gr=llik.grad,
                    hessian=FALSE,
                    method="BFGS",
                    control=list(trace=trace,fnscale=-1,reltol=nr.reltol,
                                 maxit=nr.maxit),
                    xobs=xobs,
                    xsim=xsim, probs=probs,
                    xsim.obs=xsim.obs, probs.obs=probs.obs,
                    varweight=varweight, trustregion=trustregion,
                    eta0=eta0, etamap=etamap),silent=TRUE)
  if(verbose){message("the change in the log-likelihood is ", Lout$value,"")}
  if(inherits(Lout,"try-error") || Lout$value > 199 ||
    Lout$value < -790) {
    if(verbose){
      message("MLE could not be found. Degenerate!")
      message("Nelder-Mead Log-likelihood ratio is ", Lout$value,"")
    }
    return(c(Inf, guess))
  }
  theta <- Lout$par
  names(theta) <- names(init)
# c0  <- llik.fun(theta=Lout$par, xobs=xobs,
#                 xsim=xsim, probs=probs,
#                 xsim.obs=xsim.obs, probs.obs=probs.obs,
#                 varweight=0.5, eta0=eta0, etamap=etamap)
  loglikelihood <- Lout$value
  names(loglikelihood) <- "delta.log.lik"

# list(coef=theta, 
#      loglikelihood=loglikelihood)
  c(loglikelihood, theta)
}
