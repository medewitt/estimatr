library(DDestimate)

df <- data.frame(Y = rnorm(100), Z = rbinom(100, 1, .5), X = rnorm(100))

difference_in_means(Y ~ Z, data = df)
difference_in_means(Y ~ Z, condition1 = 0, condition2 = 1, data = df)
difference_in_means(Y ~ Z, condition1 = 1, condition2 = 0, data = df)

difference_in_means(Y ~ Z, alpha = .05, data = df)
difference_in_means(Y ~ Z, alpha = .10, data = df)


df <- data.frame(Y = rnorm(100), Z = sample(1:3, 100, replace = TRUE), X = rnorm(100))

difference_in_means(Y ~ Z, data = df)
difference_in_means(Y ~ Z, condition1 = 1, condition2 = 2, data = df)
difference_in_means(Y ~ Z, condition1 = 2, condition2 = 1, data = df)
difference_in_means(Y ~ Z, condition1 = 3, condition2 = 1, data = df)
difference_in_means(Y ~ Z, condition1 = 3, condition2 = 2, data = df)