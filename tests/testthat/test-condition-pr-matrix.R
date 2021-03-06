context("Helper - HT condition_pr_matrix")

test_that("condition_pr_matrix behaves as expected", {

  # Errors appropriately
  expect_error(
    declaration_to_condition_pr_mat(rbinom(5, 1, 0.5)),
    "'declaration' must be an object of class 'ra_declaration'"
  )

  # Complete randomization
  n <- 5
  prs <- rep(0.4, times = n)
  comp_ra <- randomizr::declare_ra(N = n, prob = prs[1])
  perms <- randomizr::obtain_permutation_matrix(comp_ra)

  expect_equal(
    declaration_to_condition_pr_mat(comp_ra),
    permutations_to_condition_pr_mat(perms)
  )

  # Complete randomization with number of treated units not fixed
  comp_odd_ra <- randomizr::declare_ra(N = 3, prob = 0.5)
  perms <- randomizr::obtain_permutation_matrix(comp_odd_ra)

  decl_cond_pr_mat <- declaration_to_condition_pr_mat(comp_odd_ra)

  # following passes so just use perms instead of get_perms
  # get_perms <- replicate(40000, comp_odd_ra$ra_function())
  # expect_true(
  #    max(permutations_to_condition_pr_mat(perms) -
  #         round(permutations_to_condition_pr_mat(get_perms), 3)) < 0.01
  # )

  expect_equal(
    decl_cond_pr_mat,
    permutations_to_condition_pr_mat(perms)
  )

  # Complete randomization with non 0.5 as remainder
  comp_odd_ra <- randomizr::declare_ra(N = 3, prob = 0.4)
  decl_cond_pr_mat <- declaration_to_condition_pr_mat(comp_odd_ra)

  set.seed(40)
  get_perms <- replicate(5000, comp_odd_ra$ra_function())
  expect_equal(
    decl_cond_pr_mat,
    permutations_to_condition_pr_mat(get_perms),
    tolerance = 0.01
  )

  # Simple randomization
  prs <- rep(0.4, times = n)
  simp_ra <- randomizr::declare_ra(N = n, prob = prs[1], simple = TRUE)

  # perms <- randomizr::obtain_permutation_matrix(simp_ra)
  # Won't work because some permutations are more likely than others
  # So instead we just resample and set the tolerance
  perms <- replicate(10000, simp_ra$ra_function())
  # Won't be equal because some permutations are more likely than others in
  # this case
  expect_equal(
    declaration_to_condition_pr_mat(simp_ra),
    permutations_to_condition_pr_mat(perms),
    tolerance = 0.02
  )

  # Blocked case
  dat <- data.frame(
    bl = c("A", "B", "A", "B", "B", "B"),
    pr = c(0.5, 0.25, 0.5, 0.25, 0.25, 0.25)
  )

  bl_ra <- randomizr::declare_ra(blocks = dat$bl, block_m = c(1, 1))
  bl_perms <- randomizr::obtain_permutation_matrix(bl_ra)

  expect_equal(
    declaration_to_condition_pr_mat(bl_ra),
    permutations_to_condition_pr_mat(bl_perms)
  )

  # with remainder
  bl <- c("A", "B", "A", "A", "B", "B")

  bl_ra <- randomizr::declare_ra(blocks = dat$bl, prob = 0.4)
  bl_perms <- replicate(5000, bl_ra$ra_function())

  expect_equal(
    declaration_to_condition_pr_mat(bl_ra),
    permutations_to_condition_pr_mat(bl_perms),
    tolerance = 0.02
  )

  # Cluster complete case
  dat <- data.frame(
    cl = c("A", "B", "A", "C", "A", "B")
  )

  cl_ra <- randomizr::declare_ra(clusters = dat$cl, m = 1)
  cl_perms <- randomizr::obtain_permutation_matrix(cl_ra)

  expect_equal(
    declaration_to_condition_pr_mat(cl_ra),
    permutations_to_condition_pr_mat(cl_perms)
  )

  # with remainder
  cl_ra <- randomizr::declare_ra(clusters = dat$cl, prob = 0.5)
  cl_perms <- randomizr::obtain_permutation_matrix(cl_ra)

  # lapply(1:ncol(cl_perms), function(x) table(dat$cl, cl_perms[, x]))
  expect_equal(
    declaration_to_condition_pr_mat(cl_ra),
    permutations_to_condition_pr_mat(cl_perms)
  )

  # Cluster simple
  dat$prs <- 0.3
  cl_simp_ra <- randomizr::declare_ra(clusters = dat$cl, prob = dat$prs[1])
  cl_simp_perms <- randomizr::obtain_permutation_matrix(cl_simp_ra)

  cl_simp_cpm <- declaration_to_condition_pr_mat(cl_simp_ra)

  expect_is(
    all.equal(
      cl_simp_cpm,
      permutations_to_condition_pr_mat(cl_simp_perms),
      check.attributes = FALSE
    ),
    "character"
  )

  cl_simp_sim_perms <- replicate(5000, cl_simp_ra$ra_function())

  expect_equal(
    cl_simp_cpm,
    permutations_to_condition_pr_mat(cl_simp_sim_perms),
    tolerance = 0.01
  )


  # Blocked and clustered
  dat <- data.frame(
    bl = c("A", "B", "B", "B", "A", "A", "B", "B"),
    cl = c(1, 2, 3, 3, 4, 4, 5, 5)
  )

  bl_cl_ra <- randomizr::declare_ra(clusters = dat$cl, blocks = dat$bl, block_m  = c(1, 2))
  bl_cl_perms <- randomizr::obtain_permutation_matrix(bl_cl_ra)

  expect_equal(
    declaration_to_condition_pr_mat(bl_cl_ra),
    permutations_to_condition_pr_mat(bl_cl_perms)
  )

  # with remainder
  dat <- data.frame(
    bl = c("A", "B", "B", "B", "A", "A", "B", "B"),
    cl = c(1, 2, 3, 3, 4, 4, 5, 5)
  )

  bl_cl_ra <- randomizr::declare_ra(clusters = dat$cl, blocks = dat$bl, prob = 0.5)
  bl_cl_perms <- randomizr::obtain_permutation_matrix(bl_cl_ra)

  expect_equal(
    declaration_to_condition_pr_mat(bl_cl_ra),
    permutations_to_condition_pr_mat(bl_cl_perms)
  )

  # Custom case
  cust_perms <- cbind(c(1, 0, 1, 0), c(1, 1, 0, 0))
  cust_ra <- randomizr::declare_ra(permutation_matrix = cust_perms)

  expect_equal(
    declaration_to_condition_pr_mat(cust_ra),
    permutations_to_condition_pr_mat(cust_perms)
  )

  # Errors for things that we can't support
  # Simple blocked


})
