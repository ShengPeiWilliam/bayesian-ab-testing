# ============================================================
# Cookie Cats A/B Testing Analysis
# ============================================================

library(ggplot2)
library(tidyr)
library(dplyr)
library(rstatix)
source("config.R")

# ============================================================
# Data Loading
# ============================================================

cookiecat.data <- read.csv(COOKIECATS_DATA)

str(cookiecat.data)
summary(cookiecat.data)

# ============================================================
# Exploratory Data Analysis
# ============================================================

check_missing <- function(df, df.name = "") {
  missing.idx <- which(!complete.cases(df))
  cat(df.name, ": Found", length(missing.idx), "missing rows\n")
  if (length(missing.idx) > 0) print(df[missing.idx, ], row.names = FALSE)
  invisible(missing.idx)
}

check_missing(cookiecat.data, "cookiecat.data")

# Retention Rate by Version
cookiecat.data %>%
  pivot_longer(cols = c(retention_1, retention_7),
               names_to = "retention_type",
               values_to = "retained") %>%
  group_by(version, retention_type) %>%
  summarise(retention_rate = mean(retained), .groups = "drop") %>%
  ggplot(aes(x = version, y = retention_rate, fill = version)) +
  geom_bar(stat = "identity") +
  facet_wrap(~retention_type) +
  labs(title = "Retention Rate by Version",
       x = "Version", y = "Retention Rate") +
  theme(legend.position = "none")

# Outlier Detection
Q1      <- quantile(cookiecat.data$sum_gamerounds, 0.25)
Q3      <- quantile(cookiecat.data$sum_gamerounds, 0.75)
IQR_val <- Q3 - Q1

lower_bound <- Q1 - 3 * IQR_val
upper_bound <- Q3 + 3 * IQR_val

outliers <- cookiecat.data[cookiecat.data$sum_gamerounds > upper_bound, ]

cat("Lower bound:", lower_bound, "\n")
cat("Upper bound:", upper_bound, "\n")
cat("Number of outliers:", nrow(outliers), "\n")
cat("Percentage:", round(nrow(outliers) / nrow(cookiecat.data) * 100, 2), "%\n")

ggplot(cookiecat.data, aes(x = version, y = sum_gamerounds + 1)) +
  geom_boxplot(alpha = 0.7) +
  geom_hline(yintercept = upper_bound + 1, color = "red", linetype = "dashed") +
  scale_y_log10() +
  labs(title = "Outlier Threshold by Version (Log Scale)",
       x = "Version", y = "Sum of Game Rounds + 1 (log)")

# ============================================================
# Frequentist A/B Testing
# ============================================================

run_chisq_test <- function(data, version_col, metric_col) {
  tbl    <- table(data[[version_col]], data[[metric_col]])
  result <- chisq.test(tbl)
  effect <- cramer_v(tbl)
  list(result = result, effect = effect)
}

make_chisq_results <- function(metric_name, test) {
  data.frame(
    metric     = metric_name,
    chi_square = round(test$result$statistic, 3),
    df         = test$result$parameter,
    p_value    = round(test$result$p.value, 4),
    cramers_v  = round(test$effect, 4)
  )
}

# Chi-Square Test
test_r1 <- run_chisq_test(cookiecat.data, "version", "retention_1")
test_r7 <- run_chisq_test(cookiecat.data, "version", "retention_7")

chisq_results <- rbind(
  make_chisq_results("retention_1", test_r1),
  make_chisq_results("retention_7", test_r7)
)

print(chisq_results, row.names = FALSE)

# Confidence Interval Plots
r1_ci <- cookiecat.data %>%
  group_by(version) %>%
  summarise(
    mean = mean(retention_1),
    se   = sqrt(mean(retention_1) * (1 - mean(retention_1)) / n()),
    .groups = "drop"
  )

ggplot(r1_ci, aes(x = version, y = mean, color = version)) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = mean - 1.96*se, ymax = mean + 1.96*se), width = 0.1) +
  labs(title = "1-Day Retention Rate with 95% CI",
       x = "Version", y = "Retention Rate") +
  theme(legend.position = "none")

r7_ci <- cookiecat.data %>%
  group_by(version) %>%
  summarise(
    mean = mean(retention_7),
    se   = sqrt(mean(retention_7) * (1 - mean(retention_7)) / n()),
    .groups = "drop"
  )

ggplot(r7_ci, aes(x = version, y = mean, color = version)) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = mean - 1.96*se, ymax = mean + 1.96*se), width = 0.1) +
  labs(title = "7-Day Retention Rate with 95% CI",
       x = "Version", y = "Retention Rate") +
  theme(legend.position = "none")

# Mann-Whitney U Test
result_sum_gamerounds <- wilcox.test(sum_gamerounds ~ version, data = cookiecat.data)

n_gate30        <- sum(cookiecat.data$version == "gate_30")
n_gate40        <- sum(cookiecat.data$version == "gate_40")
W               <- result_sum_gamerounds$statistic
rank_biserial_r <- 1 - (2 * W) / (n_gate30 * n_gate40)

mw_results <- data.frame(
  metric          = "sum_gamerounds",
  W               = W,
  p_value         = round(result_sum_gamerounds$p.value, 4),
  rank_biserial_r = round(rank_biserial_r, 4)
)

print(mw_results, row.names = FALSE)

cat("=== Chi-Square Results ===\n")
print(chisq_results, row.names = FALSE)
cat("\n=== Mann-Whitney Results ===\n")
print(mw_results, row.names = FALSE)

# ============================================================
# Bayesian A/B Testing
# ============================================================

run_beta_binomial <- function(tbl, group, alpha_prior = 1, beta_prior = 1) {
  success <- tbl[group, "TRUE"]
  total   <- sum(tbl[group, ])
  list(
    alpha_post = alpha_prior + success,
    beta_post  = beta_prior  + total - success
  )
}

sample_beta_posterior <- function(bb, n_samples = 100000) {
  rbeta(n_samples, bb$alpha_post, bb$beta_post)
}

run_gamma_poisson <- function(data, version, alpha_prior = 1, beta_prior = 1) {
  rounds <- data$sum_gamerounds[data$version == version]
  list(
    alpha_post = alpha_prior + sum(rounds),
    beta_post  = beta_prior  + length(rounds)
  )
}

sample_gamma_posterior <- function(gp, n_samples = 100000) {
  rgamma(n_samples, gp$alpha_post, gp$beta_post)
}

compare_posteriors <- function(samples_a, samples_b, label_a = "gate_30", label_b = "gate_40") {
  p_better <- mean(samples_a > samples_b)
  diff     <- samples_a - samples_b
  ci       <- quantile(diff, c(0.025, 0.975))

  cat("P(", label_a, ">", label_b, "):", round(p_better, 4), "\n")
  cat("95% Credible Interval:", round(ci[1], 4), "~", round(ci[2], 4), "\n")

  invisible(list(p_better = p_better, ci_lower = ci[1], ci_upper = ci[2]))
}

make_posterior_df <- function(x, params_a, params_b, dist = "beta") {
  density_fn <- if (dist == "beta") dbeta else dgamma
  data.frame(
    x       = rep(x, 2),
    density = c(density_fn(x, params_a$alpha_post, params_a$beta_post),
                density_fn(x, params_b$alpha_post, params_b$beta_post)),
    version = rep(c("gate_30", "gate_40"), each = length(x))
  )
}

make_bayesian_results <- function(metric_name, results) {
  data.frame(
    metric          = metric_name,
    p_gate30_better = round(results$p_better, 4),
    ci_lower        = round(results$ci_lower, 4),
    ci_upper        = round(results$ci_upper, 4)
  )
}

# Retention_7
retention_7_table <- table(cookiecat.data$version, cookiecat.data$retention_7)

bb_30_r7 <- run_beta_binomial(retention_7_table, "gate_30")
bb_40_r7 <- run_beta_binomial(retention_7_table, "gate_40")

set.seed(42)
samples_30_r7 <- sample_beta_posterior(bb_30_r7)
samples_40_r7 <- sample_beta_posterior(bb_40_r7)

r7_results <- compare_posteriors(samples_30_r7, samples_40_r7)

x <- seq(0.16, 0.22, length.out = 1000)
df_plot <- make_posterior_df(x, bb_30_r7, bb_40_r7)

ggplot(df_plot, aes(x = x, y = density, fill = version, color = version)) +
  geom_line(linewidth = 1) +
  geom_area(alpha = 0.3) +
  labs(title = "Posterior Distribution of 7-Day Retention Rate",
       x = "Retention Rate", y = "Density") +
  theme_minimal()

# Retention_1
retention_1_table <- table(cookiecat.data$version, cookiecat.data$retention_1)

bb_30_r1 <- run_beta_binomial(retention_1_table, "gate_30")
bb_40_r1 <- run_beta_binomial(retention_1_table, "gate_40")

set.seed(42)
samples_30_r1 <- sample_beta_posterior(bb_30_r1)
samples_40_r1 <- sample_beta_posterior(bb_40_r1)

r1_results <- compare_posteriors(samples_30_r1, samples_40_r1)

x_r1 <- seq(0.42, 0.47, length.out = 1000)
df_plot_r1 <- make_posterior_df(x_r1, bb_30_r1, bb_40_r1)

ggplot(df_plot_r1, aes(x = x, y = density, fill = version, color = version)) +
  geom_line(linewidth = 1) +
  geom_area(alpha = 0.3) +
  labs(title = "Posterior Distribution of 1-Day Retention Rate",
       x = "Retention Rate", y = "Density") +
  theme_minimal()

# sum_gamerounds (Gamma-Poisson)
gp_30 <- run_gamma_poisson(cookiecat.data, "gate_30")
gp_40 <- run_gamma_poisson(cookiecat.data, "gate_40")

set.seed(42)
samples_30_gp <- sample_gamma_posterior(gp_30)
samples_40_gp <- sample_gamma_posterior(gp_40)

gp_results <- compare_posteriors(samples_30_gp, samples_40_gp)

lambda_range <- seq(50, 55, length.out = 1000)
df_plot_gp   <- make_posterior_df(lambda_range, gp_30, gp_40, dist = "gamma")

ggplot(df_plot_gp, aes(x = x, y = density, fill = version, color = version)) +
  geom_line(linewidth = 1) +
  geom_area(alpha = 0.3) +
  labs(title = "Posterior Distribution of Game Rounds Rate (Gamma-Poisson)",
       x = "Average Game Rounds (λ)", y = "Density") +
  theme_minimal()

# Bayesian Results Summary
bayesian_results <- rbind(
  make_bayesian_results("retention_1", r1_results),
  make_bayesian_results("retention_7", r7_results),
  make_bayesian_results("sum_gamerounds", gp_results)
)

print(bayesian_results, row.names = FALSE)
