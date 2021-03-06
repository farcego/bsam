% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/hssm.R
\name{hssm}
\alias{hssm}
\title{Fits hierarchical state-space models to Argos data}
\usage{
hssm(d, model = "hDCRWS", adapt, samples, thin, chains, span)
}
\arguments{
\item{d}{structured data from \code{dat4jags} to be passed to JAGS}

\item{model}{the state-space model to be fit: hDCRW or hDCRWS}

\item{adapt}{number of samples in adaptation/burnin phase}

\item{samples}{number of posterior samples}

\item{thin}{thinning factor to reduce posterior sample autocorrelation}

\item{chains}{number of parallel McMC chains to run}

\item{span}{span}
}
\value{
Returns a list of McMC samples from marginal posteriors and a
summary \code{data.frame} of mean and median position estimates.
}
\description{
Takes output from \code{dat4jags}, sets up initial values, calls JAGS, and
aggregates results. Intended for internal use, called by \code{fit_ssm}.
}
\seealso{
Function to be called by \code{\link{fit_ssm}}.
}
