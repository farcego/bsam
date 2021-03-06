#' Fit Bayesian state-space models to animal movement data
#' 
#' Fits state-space models to animal tracking data. User can choose
#' between a first difference correlated random walk (DCRW) model, a switching 
#' model (DCRWS) for estimating location and behavioural states, and their 
#' hierarchical versions (hDCRW, hDCRWS). The models are structured for Argos
#' satellite data but options exist for fitting to other tracking data types.
#' 
#' The models are fit using JAGS 4.2.0 (Just Another Gibbs Sampler, created and
#' maintained by Martyn Plummer; http://martynplummer.wordpress.com/;
#' http://mcmc-jags.sourceforge.net). \code{fit_ssm} is a wrapper that first
#' calls \code{dat4jags}, which prepares the input data, then calls \code{ssm}
#' or \code{hssm}, which fit the specified state-space model to the data, 
#' returning a list of results.
#' 
#' @param data A data frame containing the following columns, "id","date",
#' "lc", "lon", "lat". "id" is a unique identifier for the tracking dataset.
#' "date" is the GMT date-time of each observation with the following format
#' "2001-11-13 07:59:59". "lc" is the Argos location quality class of each
#' observation, values in ascending order of quality are "Z", "B", "A", "0", "1",
#' "2", "3". "lon" is the observed longitude in decimal degrees. "lat" is the
#' observed latitude in decimal degrees. The Z-class locations are assumed to 
#' have the same error distributions as B-class locations.
#' 
#' Optionally, the input data.frame can specify the error standard deviations 
#' for longitude and latitude (in units of degrees) in the last 2 columns, 
#' named "lonerr" and "laterr", respectively. These errors are assumed to be
#' normally distributed. When specifying errors in the input data, all "lc" 
#' values must be equal to "G". This approach allows the models to be fit to 
#' data types other than Argos satellite data, e.g. geolocation data. See 
#' \code{\link{dat4jags}} for other options for specifying error parameters.
#' 
#' WARNING: there is no guarantee that invoking these options will yield sensible results!
#' For GPS data, similar models can be fit via the \code{moveHMM} package.
#' 
#' @param model name of state-space model to be fit to data. This can be one of 
#' "DCRW", "DCRWS", "hDCRW", or "hDCRWS"
#' @param tstep time step as fraction of a day, default is 1 (24 hours).
#' @param adapt number of samples during the adaptation and update (burn-in)
#' phase, adaptation and updates are fixed at adapt/2
#' @param samples number of posterior samples to generate after burn-in
#' @param thin amount of thinning of to be applied to the posterior samples to 
#' minimize within-chain sample autocorrelation
#' @param span parameter that controls the degree of smoothing by \code{stats::loess},
#' used to obtain initial values for the location states. Smaller values = less
#' smoothing. Values > 0.2 may be required for sparse datasets
#' @return For DCRW and DCRWS models, a list is returned with each outer list
#' elements corresponding to each unique individual id in the input data
#' Within these outer elements are a "summary" data.frame of posterior mean and
#' median state estimates (locations or locations and behavioural states), the
#' name of the "model" fit, the "timestep" used, the input location "data", the
#' number of location state estimates ("N"), and the full set of "mcmc"
#' samples. For the hDCRW and hDCRWS models, a list is returned where results, etc are
#' combined amongst the individuals
#' @author Ian Jonsen
#' @references Jonsen ID, Mills Flemming J, Myers RA (2005) Robust state-space modeling of
#' animal movement data. Ecology 86:2874-2880
#' 
#' Block et al. (2011) Tracking apex marine predator movements in a dynamic
#' ocean. Nature 475:86-90
#' 
#' Jonsen et al. (2013) State-space models for biologgers: a methodological
#' road map. Deep Sea Research II DOI: 10.1016/j.dsr2.2012.07.008
#' 
#' Jonsen (2016) Joint estimation over multiple individuals improves behavioural state 
#' inference from animal movement data. Scientific Reports 6:20625
#' 
#' @examples
#' \dontrun{
#' # Fit DCRW model for state filtering and regularization
#' data(ellie)
#' fit <- fit_ssm(ellie, model = "DCRW", tstep = 2, adapt = 5000, samples = 5000, 
#'               thin = 5, span = 0.2)
#' diag_ssm(fit)
#' map_ssm(fit)
#' plot_fit(fit)
#' result <- get_summary(fit)
#' 
#' # Fit DCRWS model for state filtering, regularization and behavioural state estimation
#'  fit.s <- fit_ssm(ellie, model = "DCRWS", tstep = 2, adapt = 5000, samples = 5000, 
#'                 thin = 5, span = 0.2)
#'  diag_ssm(fit.s)
#'  map_ssm(fit.s)
#'  plot_fit(fit.s)
#'  result.s <- get_summary(fit.s)
#' 
#' # fit hDCRWS model to > 1 tracks simultaneously
#' # this may provide better parameter and behavioural state estimation 
#' # by borrowing strength across multiple track datasets
#'  hfit.s <- fit_ssm(ellie, model = "hDCRWS", tstep = 2, adapt = 5000, samples = 5000, 
#'                 thin = 5, span = 0.2)
#'  diag_ssm(hfit.s)
#'  map_ssm(hfit.s)
#'  plot_fit(hfit.s)
#'  result.hs <- get_summary(hfit.s)
#' }
#' @importFrom tibble as_data_frame
#' @export 
fit_ssm <- function (data, model = "DCRW", tstep = 1, adapt = 10000, samples = 5000, 
                    thin = 5, span = 0.2)
{
	if(!model %in% c('DCRW', 'DCRWS', 'hDCRW', 'hDCRWS')) stop("Model not implemented")
  model.file <- file.path(system.file(package = "bsam"), "jags", paste(model, ".txt", sep = ""))
    
	options(warn = -1)	    	
  st <- proc.time()
  
  ## assign temporary ordered id's so animal id order is preserved in all cases
  tmp.id <- as.numeric(factor(data$id, levels=unique(data$id)))
  id <- data$id
  data$id <- tmp.id
  
  data <- as_data_frame(data)
 
	d <- dat4jags(data, tstep = tstep, tpar=tpar())	

	if(model %in% c("DCRW", "DCRWS")) {
	  fit <- ssm(d, model = model, adapt = adapt, samples = samples, thin = thin, 
	             chains = 2, span = span)
	  
	  ## reassign original animal id's
	  fit <- lapply(1:length(fit), function(i) {
	    fit[[i]]$summary$id <- unique(id)[i]
	    fit[[i]]$data$id <- unique(id)[i]
	    fit[[i]]
	  })
	  names(fit) <- unique(id)
	  class(fit) <- "ssm"
	}
	else {
	  fit <- hssm(d, model = model, adapt = adapt, samples = samples, thin = thin, 
	              chains = 2, span = span)
	  
	  ## reassign original animal id's
	  fit$summary$id <- factor(as.numeric(fit$summary$id), labels = unique(id))
	  fit$data$id <- factor(as.numeric(fit$data$id), labels = unique(id))
	  class(fit) <- "hssm"
	}
	
	cat("Elapsed time: ", round((proc.time() - st)[3] / 60, 2), "min \n")	
	options(warn = 0)

	fit
}
