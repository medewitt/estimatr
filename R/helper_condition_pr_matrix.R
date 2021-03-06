#' Builds a condition probaability matrix for Horvitz-Thompson estimation from randomizr declaration
#'
#' @param declaration An object of class 'ra_declaration' that contains the experimental design
#'
#' @details This function takes a 'ra_declaration' from the
#' \code{\link[randomizr]{declare_ra}} function in \pkg{randomizr} and returns
#'  a 2n*2n matrix that can be used to fully specify the design for
#'  \code{\link{horvitz_thompson}} estimation. This is done by passing this
#'  matrix to the \code{condition_pr_mat} argument of
#'  \code{\link{horvitz_thompson}}.
#'
#' Currently, this function can learn the condition probability matrix for a
#' wide variety of randomizations: simple, complete, simple clustered, complete
#' clustered, blocked, block-clustered.
#'
#' This matrix is made up of four-submatrices, each of which corresponds to the
#' joint and marginal probability that each observation is in one of the two
#' treatment conditions.
#'
#' The upper-left quadrant is an n*n matrix. On the diagonal is the marginal
#' probability of being in condition 1, often control, for every unit
#' (Pr(Z_i = Condition1) where Z represents the vector of treatment conditions).
#' The off-diagonal elements are the joint probabilities of each unit being in
#' condition 1 with each other unit, Pr(Z_i = Condition1, Z_j = Condition1)
#' where i indexes the rows and j indexes the columns.
#'
#' The upper-right quadrant is also an n*n matrix. On the diagonal is the joint
#' probability of a unit being in condition 1 and condition 2, often the
#' treatment, and thus is always 0. The off-diagonal elements are the joint
#' probability of unit i being in condition 1 and unit j being in condition 2,
#' Pr(Z_i = Condition1, Z_j = Condition2).
#'
#' The lower-left quadrant is also an n*n matrix. On the diagonal is the joint
#' probability of a unit being in condition 1 and condition 2, and thus is
#' always 0. The off-diagonal elements are the joint probability of unit i
#' being in condition 2 and unit j being in condition 1,
#' Pr(Z_i = Condition2, Z_j = Condition1).
#'
#' The lower-right quadrant is an n*n matrix. On the diagonal is the marginal
#' probability of being in condition 2, often treatment, for every unit
#' (Pr(Z_i = Condition2)). The off-diagonal elements are the joint probability
#' of each unit being in condition 2 together,
#' Pr(Z_i = Condition2, Z_j = Condition2).
#'
#' @examples
#'
#' # Learn condition probability matrix from complete clustered design
#' library(randomizr)
#' n <- 100
#' dat <- data.frame(
#'   clusts = sample(letters[1:10], size = n, replace = TRUE),
#'   y = rnorm(n)
#' )
#'
#' # Declare complete clustered randomization
#' cl_declaration <- declare_ra(clusters = dat$clusts, prob = 0.4, simple = FALSE)
#' # Get probabilities
#' clust_pr_mat <- declaration_to_condition_pr_mat(cl_declaration)
#' # Do randomiztion
#' dat$z <- cl_declaration$ra_function()
#'
#' horvitz_thompson(y ~ z, data = dat, condition_pr_mat = clust_pr_mat)
#'
#' # When you pass a declaration to horvitz_thompson, this function is called
#' horvitz_thompson(y ~ z, data = dat, declaration = cl_declaration)
#'
#' @export
declaration_to_condition_pr_mat <- function(declaration) {

  if (class(declaration) != 'ra_declaration') {
    stop("'declaration' must be an object of class 'ra_declaration'")
  }

  # if (ncol(declaration$probabilities_matrix) > 2) {
  #   stop(
  #     "'declaration' must have been generated with a binary treatment ",
  #     "variable when `declaration_to_condition_pr_mat` is called directly"
  #   )
  # }

  p1 <- declaration$probabilities_matrix[, 1]
  p2 <- declaration$probabilities_matrix[, 2]

  declaration_call <- as.list(declaration$original_call)
  simple <- eval(declaration_call$simple)

  n <- nrow(declaration$probabilities_matrix)

  if (declaration$ra_type == "simple") {

    v <- c(p1, p2)
    condition_pr_matrix <- tcrossprod(v)
    diag(condition_pr_matrix) <- v
    condition_pr_matrix[cbind(n+1:n, 1:n)] <- 0
    condition_pr_matrix[cbind(1:n, n+1:n)] <- 0

  } else if (declaration$ra_type == "complete") {

    if (length(unique(p2)) > 1) {
      stop("Treatment probabilities must be fixed for complete randomized designs")
    }

    # On average the number of treated units may not be an integer
    # if (treated_remainder != 0) {
    #   stop(
    #     "Can't use 'declaration' with complete randomization when the number ",
    #     "of treated units is not fixed across randomizations (i.e. when the ",
    #     "number of total units is 3 and the probability of treatment is 0.5, ",
    #     "meaning there can be either 1 or 2 treated units. Instead, simulate ",
    #     "many treatment vectors using randomizr and pass those permutations ",
    #     "to `permutations_to_condition_pr_mat`."
    #   )
    # }

    condition_pr_matrix <-
      gen_pr_matrix_complete(
        pr = p2[1],
        n_total = n
      )

  } else if (declaration$ra_type == "clustered") {

    if (length(declaration_call) == 0) {
      warning("Assuming cluster randomization is complete. To have declare_ra work with simple random assignment of clusters, upgrade to the newest version of randomizr on GitHub.")
    }

    condition_pr_matrix <- gen_pr_matrix_cluster(
      clusters = declaration$clusters,
      treat_probs = p2,
      simple = simple
    )

  } else if (declaration$ra_type %in% c("blocked", "blocked_and_clustered")) {

    # Assume complete randomization
    condition_pr_matrix <- matrix(NA, nrow = 2*n, ncol = 2*n)

    # Split by block and get complete randomized values within each block
    id_dat <- data.frame(p1 = p1, p2 = p2, ids = 1:n)

    if (declaration$ra_type == "blocked_and_clustered") {
      id_dat$clusters <- declaration$clusters
    }

    block_dat <- split(
      id_dat,
      declaration$block
    )

    n_blocks <- length(block_dat)

    for (i in 1:n_blocks) {

      ids <- c(block_dat[[i]]$ids, n + block_dat[[i]]$ids)

      if (declaration$ra_type == "blocked") {

        if (length(unique(block_dat[[i]]$p2)) > 1) {
          stop("Treatment probabilities must be fixed within blocks for block randomized designs")
        }

        condition_pr_matrix[ids, ids] <-
          gen_pr_matrix_complete(
            pr = block_dat[[i]]$p2[1],
            n_total = length(block_dat[[i]]$p2)
          )

      } else if (declaration$ra_type == "blocked_and_clustered") {
        # Has to be complete randomization of clusters
        condition_pr_matrix[ids, ids] <-
          gen_pr_matrix_cluster(
            clusters = block_dat[[i]]$clusters,
            treat_probs = block_dat[[i]]$p2,
            simple = FALSE
          )
      }

      for (j in 1:n_blocks) {
        if (i != j) {
          condition_pr_matrix[
            ids,
            c(block_dat[[j]]$ids, n + block_dat[[j]]$ids)
          ] <- tcrossprod(
            c(block_dat[[i]]$p1, block_dat[[i]]$p2),
            c(block_dat[[j]]$p1, block_dat[[j]]$p2)
          )
        }
      }
    }
  } else if (declaration$ra_type == "custom") {
    # Use permutation matrix
    return(permutations_to_condition_pr_mat(declaration$permutation_matrix))
  }

  # Add names
  colnames(condition_pr_matrix) <- rownames(condition_pr_matrix) <-
    c(paste0("0_", 1:n), paste0("1_", 1:n))

  return(condition_pr_matrix)

}

#' Generate condition probability matrix given clusters and probabilities
#'
#' @param clusters A vector of clusters
#' @param treat_probs A vector of treatment (condition) probabilities
#' @param simple A boolean for whether the assignment is a random sample assignment (TRUE, default) or complete random assignment (FALSE)
#'
#' @export
gen_pr_matrix_cluster <- function(clusters, treat_probs, simple) {

  n <- length(clusters)
  cluster_lists <- split(1:n, clusters)
  n_clust <- length(cluster_lists)

  unique_first_in_cl <- !duplicated(clusters)

  cluster_marginal_probs <-
    treat_probs[unique_first_in_cl]


  # Container mats
  # Get cluster condition_pr_matrices
  # Complete random sampling
  if (is.null(simple) || !simple) {

    if (length(unique(cluster_marginal_probs)) > 1) {
      stop("Treatment probabilities must be fixed for complete (clustered) randomized clustered designs")
    }

    prs <- gen_joint_pr_complete(cluster_marginal_probs[1], n_clust)

    # This definitely could be optimized
    mat_00 <- matrix(prs[["00"]], n, n)
    mat_10 <- matrix(prs[["10"]], n, n)
    mat_11 <- matrix(prs[["11"]], n, n)

    for (i in 1:n_clust) {
      mat_11[cluster_lists[[i]], cluster_lists[[i]]] <-
        cluster_marginal_probs[i]

      mat_00[cluster_lists[[i]], cluster_lists[[i]]] <-
        1 - cluster_marginal_probs[i]

      mat_10[cluster_lists[[i]], cluster_lists[[i]]] <-
        0
    }

    condition_pr_matrix <-
      rbind(cbind(mat_00, mat_10),
            cbind(mat_10, mat_11))

  } else if (simple) { # cluster, simple randomized

    # container mats
    mat_00 <- mat_01 <- mat_10 <- mat_11 <-
      matrix(NA, nrow = n, ncol = n)
    for (i in seq_along(cluster_lists)) {
      for (j in seq_along(cluster_lists)) {
        if (i == j) {
          mat_11[cluster_lists[[i]], cluster_lists[[j]]] <-
            cluster_marginal_probs[i]

          mat_00[cluster_lists[[i]], cluster_lists[[j]]] <-
            1 - cluster_marginal_probs[i]

          mat_01[cluster_lists[[i]], cluster_lists[[j]]] <-
            0

          mat_10[cluster_lists[[i]], cluster_lists[[j]]] <-
            0

        } else {
          mat_11[cluster_lists[[i]], cluster_lists[[j]]] <-
            cluster_marginal_probs[i] *
            cluster_marginal_probs[j]

          mat_00[cluster_lists[[i]], cluster_lists[[j]]] <-
            (1 - cluster_marginal_probs[i]) *
            (1 - cluster_marginal_probs[j])

          mat_01[cluster_lists[[i]], cluster_lists[[j]]] <-
            (1 - cluster_marginal_probs[i]) *
            cluster_marginal_probs[j]

          mat_10[cluster_lists[[i]], cluster_lists[[j]]] <-
            cluster_marginal_probs[i] *
            (1 - cluster_marginal_probs[j])

        }
      }
    }

    condition_pr_matrix <-
      rbind(cbind(mat_00, mat_01),
            cbind(mat_10, mat_11))
  }

  return(condition_pr_matrix)
}

#' Builds a condition probaability matrix for Horvitz-Thompson estimation from treatment permutation matrix
#'
#' @param permutations A matrix where the rows are units and the columns are different treatment permutations; treated units must be represented with a 1 and control units with a 0
#'
#' @details This function takes a matrix of permutations, for example from from the \code{\link[randomizr]{declare_ra}} function in \pkg{randomizr} and returns a 2n*2n matrix that can be used to fully specify the design for \code{\link{horvitz_thompson}} estimation. This is done by passing this matrix to the \code{condition_pr_mat} argument of \code{\link{horvitz_thompson}}.
#'
#' @export
permutations_to_condition_pr_mat <- function(permutations) {

  N <- nrow(permutations)

  if (!all(permutations %in% c(0, 1))) {
    stop("Permutations matrix must only have 0s and 1s in it.")
  }

  condition_pr_matrix <- tcrossprod(rbind(1- permutations, permutations)) / ncol(permutations)

  colnames(condition_pr_matrix) <- rownames(condition_pr_matrix) <-
    c(paste0("0_", 1:N), paste0("1_", 1:N))

  return(condition_pr_matrix)

}

# Helper functions based on Stack Overflow answer by user Ujjwal
# https://stackoverflow.com/questions/26377199/convert-a-matrix-in-r-into-a-upper-triangular-lower-triangular-matrix-with-those
copy_upper_to_lower_triangle <- function(mat) {
  mat[lower.tri(mat, diag = F)] <- t(mat)[lower.tri(mat)]
  return(mat)
}

copy_lower_to_upper_triangle <- function(mat) {
  mat[upper.tri(mat, diag = F)] <- t(mat)[upper.tri(mat)]
  return(mat)
}

gen_pr_matrix_complete <- function(pr, n_total) {

  prs <- gen_joint_pr_complete(pr, n_total)

  pr00_mat <- matrix(prs[["00"]], nrow = n_total, ncol = n_total)
  diag(pr00_mat) <- 1 - pr
  pr10_mat <- matrix(prs[["10"]], nrow = n_total, ncol = n_total)
  diag(pr10_mat) <- 0
  pr11_mat <- matrix(prs[["11"]], nrow = n_total, ncol = n_total)
  diag(pr11_mat) <- pr

  pr_mat <- cbind(
    rbind(pr00_mat, pr10_mat),
    rbind(pr10_mat, pr11_mat)
  )

  return(pr_mat)

}

gen_joint_pr_complete <- function(pr, n_total) {

  n_treated <- pr * n_total
  remainder <- n_treated %% 1

  n_treated_floor <- floor(n_treated)
  n_control <- n_total - n_treated_floor

  prs <- list()

  prs[["11"]] <-
    remainder *                         # pr(M)
    ((n_treated_floor + 1) / n_total) *       # pr(j = 1 | M)
    (n_treated_floor / (n_total - 1)) +       # pr(i = 1 | j = 1, M)
    (1 - remainder) *                   # pr(M')
    (n_treated_floor / n_total) *             # pr(j = 1 | M')
    ((n_treated_floor - 1) / (n_total - 1))   # pr(i = 1 | j = 1, M')


  prs[["10"]] <-
    remainder *                         # pr(M)
    ((n_control - 1) / n_total) *       # pr(j = 0 | M)
    ((n_treated_floor + 1) / (n_total - 1)) + # pr(i = 1 | j = 0, M)
    (1 - remainder) *                   # pr(M')
    (n_control / n_total) *             # pr(j = 0 | M')
    (n_treated_floor / (n_total - 1))         # pr(i = 1 | j = 0, M')

  prs[["00"]] <-
    remainder *                         # pr(M)
    ((n_control - 1) / n_total) *       # pr(j = 0 | M)
    ((n_control - 2) / (n_total - 1)) + # pr(i = 0 | j = 0, M)
    (1 - remainder) *                   # pr(M')
    (n_control / n_total) *             # pr(j = 0 | M')
    ((n_control - 1) / (n_total - 1))   # pr(i = 0 | j = 0, M')

  return(prs)

}
