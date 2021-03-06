% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/helper_condition_pr_matrix.R
\name{gen_pr_matrix_cluster}
\alias{gen_pr_matrix_cluster}
\title{Generate condition probability matrix given clusters and probabilities}
\usage{
gen_pr_matrix_cluster(clusters, treat_probs, simple)
}
\arguments{
\item{clusters}{A vector of clusters}

\item{treat_probs}{A vector of treatment (condition) probabilities}

\item{simple}{A boolean for whether the assignment is a random sample assignment (TRUE, default) or complete random assignment (FALSE)}
}
\description{
Generate condition probability matrix given clusters and probabilities
}
