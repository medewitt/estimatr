#' Internal method that creates linear fits
#'
#' @param y numeric outcome vector
#' @param X numeric design matrix
#' @param weights numeric weights vector
#' @param cluster numeric cluster vector
#' @param ci boolean that when T returns confidence intervals and p-values
#' @param se_type character denoting which kind of SEs to return
#' @param alpha numeric denoting the test size for confidence intervals
#' @param coefficient_name character vector of coefficients to return
#' @param return_vcov a boolean for whether to return the vcov matrix for later usage
#' @param try_cholesky a boolean for whether to try using a cholesky decomposition to solve LS instead of a QR decomposition
#'
#' @export
#'
lm_robust_fit <- function(y,
                          X,
                          weights,
                          cluster,
                          ci,
                          se_type,
                          alpha,
                          coefficient_name,
                          return_vcov,
                          try_cholesky) {

  ## allowable se_types with clustering
  cl_se_types <- c("CR0", "CR2", "stata")
  rob_se_types <- c("HC0", "HC1", "HC2", "HC3", "classical", "stata")

  ## Parse cluster variable
  if (!is.null(cluster)) {

    # set/check se_type
    if (is.null(se_type)) {
      se_type <- "CR2"
    } else if (!(se_type %in% c(cl_se_types, "none"))) {
      stop(
        "`se_type` must be either 'CR0', 'stata', 'CR2', or 'none' when ",
        "`clusters` are specified.\nYou passed: ", se_type
      )
    }

  } else {

    # set/check se_type
    if (is.null(se_type)) {
      se_type <- "HC2"
    } else if (se_type %in% setdiff(cl_se_types, "stata")) {
      stop(
        "`se_type` must be either 'HC0', 'HC1', 'stata', 'HC2', 'HC3', ",
        "'classical' or 'none' with no `clusters`.\nYou passed: ", se_type,
        " which is reserved for a case with clusters."
      )
    } else if (!(se_type %in% c(rob_se_types, "none"))) {
      stop(
        "`se_type` must be either 'HC0', 'HC1', 'stata', 'HC2', 'HC3', ",
        "'classical' or 'none' with no `clusters`.\nYou passed: ", se_type
      )
    } else if (se_type == "stata") {
      se_type <- "HC1"
    }

  }

  k <- ncol(X)

  if (is.null(colnames(X))) {
    colnames(X) <- paste0("X", 1:k)
  }
  variable_names <- colnames(X)

  # Get coefficients to get df adjustments for and return
  if (is.null(coefficient_name)) {

    which_covs <- rep(TRUE, ncol(X))

  } else {

    # subset return to coefficients the user asked for
    which_covs <- variable_names %in% coefficient_name

    # if ever we can figure out all the use cases in the test....
    # which_ests <- return_frame$variable_names %in% deparse(substitute(coefficient_name))
  }

  if (!is.null(cluster)) {
    cl_ord <- order(cluster)
    y <- y[cl_ord]
    X <- X[cl_ord,]
    cluster <- cluster[cl_ord]
    J <- length(unique(cluster))
    if (!is.null(weights)) {
      weights <- weights[cl_ord]
    }

  } else {
    J <- 1
  }

  if (!is.null(weights)) {
    Xunweighted <- X
    weight_mean <- mean(weights)
    weights <- sqrt(weights / weight_mean)
    X <- weights * X
    y <- weights * y
  } else {
    weight_mean <- 1
    Xunweighted <- NULL
  }


  fit <-
    lm_solver(
      Xfull = X,
      y = y,
      Xunweighted = Xunweighted,
      weight = weights,
      weight_mean = weight_mean,
      cluster = cluster,
      J = J,
      ci = ci,
      type = se_type,
      which_covs = which_covs,
      try_cholesky = try_cholesky
    )


  return_frame <- data.frame(
    est = as.vector(fit$beta_hat),
    se = NA,
    df = NA
  )

  est_exists <- !is.na(return_frame$est)

  N <- nrow(X)
  rank <- sum(est_exists)

  if(se_type != "none"){

    return_frame$se[est_exists] <- sqrt(diag(fit$Vcov_hat))

    if(ci) {

      if(se_type %in% cl_se_types){

        # Replace -99 with NA, easy way to flag that we didn't compute
        # the DoF because the user didn't ask for it
        return_frame$df[est_exists] <-
          ifelse(fit$dof == -99,
                 NA,
                 fit$dof)

      } else {

        # TODO explicitly pass rank from RRQR/cholesky
        return_frame$df[est_exists] <- N - rank

      }

    }
  }

  return_list <- add_cis_pvals(return_frame, alpha, ci && se_type != "none")

  return_list[["coefficient_name"]] <- variable_names
  return_list[["outcome"]] <- NA_character_
  return_list[["alpha"]] <- alpha
  return_list[["which_covs"]] <- coefficient_name
  return_list[["res_var"]] <- ifelse(fit$res_var < 0, NA, fit$res_var)
  # return_list[["XtX_inv"]] <- fit$XtX_inv
  return_list[["N"]] <- N
  return_list[["k"]] <- k
  return_list[["rank"]] <- rank

  if (return_vcov && se_type != 'none') {
    #return_list$residuals <- fit$residuals
    return_list[["vcov"]] <- fit$Vcov_hat
    dimnames(return_list[["vcov"]]) <- list(return_list$coefficient_name[est_exists],
                                            return_list$coefficient_name[est_exists])
  }

  return_list[["weighted"]] <- !is.null(weights)
  if (return_list[["weighted"]]) {
    return_list[["res_var"]] <- sum(fit$residuals^2 * weight_mean) / (N - rank)
  }

  attr(return_list, "class") <- "lm_robust"

  return(return_list)

}
