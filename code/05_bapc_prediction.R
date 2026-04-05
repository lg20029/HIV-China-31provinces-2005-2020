#!/usr/bin/env Rscript
# ==============================================================================
# R Script for Bayesian Age-Period-Cohort (BAPC) Prediction Model
# Generates Figure 5: BAPC Prediction of HIV/AIDS Incidence (2005-2030)
#
# Method: Bayesian APC via R-INLA (Poisson model with random walk priors)
# Data:   National HIV/AIDS surveillance data, 31 provinces, 2005-2020
#
# NOTE: This model uses absolute case counts (Poisson) without population offset,
#       because population data by age group and year is not available in the
#       surveillance dataset. The model captures the age-period-cohort structure
#       of case counts and projects forward.
# ==============================================================================

# --- Install and load required packages ---
if (!require("tidyverse")) install.packages("tidyverse", repos = "https://cloud.r-project.org/")
if (!require("readxl"))    install.packages("readxl",    repos = "https://cloud.r-project.org/")
if (!require("INLA")) {
  install.packages("INLA",
    repos = c(getOption("repos"),
              INLA = "https://inla.r-inla-download.org/R/stable"),
    dep = TRUE)
}

library(tidyverse)
library(readxl)
library(INLA)

# ==============================================================================
# 1. Data Preparation - Real Age-Specific Case Counts
# ==============================================================================
cat("=== Step 1: Loading and preparing data ===\n")

# Read raw data from Excel (same source as 04_apc_model.R)
raw_data <- read_excel("HIV_AIDS_Data_31_Provinces.xlsx")

# Define age groups (open-ended 5-year bands used in the surveillance data)
broad_ages <- c("20-", "25-", "30-", "35-", "40-", "45-",
                "50-", "55-", "60-", "65-", "70-", "75-", "80-", "85+")

# Filter to valid age groups, convert types, remove missing cases
age_data <- raw_data %>%
  filter(Age_Group %in% broad_ages) %>%
  mutate(
    Cases = as.numeric(Cases),
    year  = as.integer(substr(Date, 1, 4))
  ) %>%
  filter(!is.na(Cases), year >= 2005, year <= 2020)

# Aggregate to national level by year and age group
national_annual <- age_data %>%
  group_by(year, Age_Group) %>%
  summarise(Cases = sum(Cases), .groups = "drop")

cat(sprintf("Observation period: %d-%d\n", min(national_annual$year),
            max(national_annual$year)))
cat(sprintf("Age groups: %d\n", n_distinct(national_annual$Age_Group)))
cat(sprintf("Total cells: %d, Total cases: %s\n",
            nrow(national_annual),
            format(sum(national_annual$Cases), big.mark = ",")))

# ==============================================================================
# 2. Create Numeric Indices for INLA
# ==============================================================================
# INLA's f() function requires numeric indices (not factors) for random effects.
# We create: age_idx (1..14), period_idx (1..16), cohort_idx (derived).

# 计算cohort原始值的范围（用于重新映射为正整数）
cohort_min <- min(national_annual$year - as.integer(factor(national_annual$Age_Group, levels = broad_ages)) + 1)

bapc_data <- national_annual %>%
  mutate(
    Age_Group = factor(Age_Group, levels = broad_ages),
    age_idx   = as.integer(Age_Group),          # 1, 2, ..., 14
    period_idx = year - min(year) + 1,           # 1, 2, ..., 16
    cohort_idx = period_idx - age_idx + 1,       # cohort = period - age + 1
    cohort_idx = cohort_idx - cohort_min + 1      # 重新映射为正整数 (从1开始)
  ) %>%
  arrange(age_idx, period_idx)

cat(sprintf("Age index range: %d-%d\n",
            min(bapc_data$age_idx), max(bapc_data$age_idx)))
cat(sprintf("Period index range: %d-%d\n",
            min(bapc_data$period_idx), max(bapc_data$period_idx)))
cat(sprintf("Cohort index range: %d to %d\n",
            min(bapc_data$cohort_idx), max(bapc_data$cohort_idx)))

# ==============================================================================
# 3. Build Prediction Data (2021-2030)
# ==============================================================================
# For future years, we extend the period index and compute corresponding cohorts.
# The cohort index naturally extends beyond the observed range.

pred_years <- 2021:2030
obs_min_year <- min(bapc_data$year)

pred_data <- expand.grid(
  Age_Group = factor(broad_ages, levels = broad_ages),
  year = pred_years,
  stringsAsFactors = FALSE
) %>%
  mutate(
    age_idx    = as.integer(Age_Group),
    period_idx = year - obs_min_year + 1,
    cohort_idx = period_idx - age_idx + 1,   # 原始cohort计算
    cohort_idx = cohort_idx - cohort_min + 1, # 与观测期一致的偏移映射
    Cases      = NA_real_
  ) %>%
  arrange(age_idx, period_idx)

cat(sprintf("Prediction period: %d-%d\n", min(pred_years), max(pred_years)))
cat(sprintf("Prediction period_idx: %d-%d\n",
            min(pred_data$period_idx), max(pred_data$period_idx)))

# ==============================================================================
# 4. INLA Model with inla.stack (Observation + Prediction)
# ==============================================================================
cat("\n=== Step 2: Fitting BAPC model with INLA ===\n")

# Model formula: Poisson case counts with random walk priors
# - age_idx:   first-order random walk (rw1) for smooth age effect
# - period_idx: first-order random walk (rw1) for temporal trend
# - cohort_idx: first-order random walk (rw1) for birth cohort effect
#
# NOTE: No offset (population exposure) because true age-specific population
#       data is not available. The model fits the age-period-cohort structure
#       of observed counts and projects the trend forward.

formula <- Cases ~ 1 +
  f(age_idx,    model = "rw1", cyclic = FALSE,
    prior = "pc.prec", param = c(1, 0.01)) +
  f(period_idx, model = "rw1", cyclic = FALSE,
    prior = "pc.prec", param = c(1, 0.01)) +
  f(cohort_idx, model = "rw1", cyclic = FALSE,
    prior = "pc.prec", param = c(1, 0.01))

# Combine observation and prediction data
combined_data <- bind_rows(bapc_data, pred_data)

n_obs  <- nrow(bapc_data)
n_pred <- nrow(pred_data)
n_total <- nrow(combined_data)

cat(sprintf("Combined data: %d observed + %d prediction = %d total\n",
            n_obs, n_pred, n_total))

# Create inla.stack with separate tags for observation and prediction
# Key: prediction rows have Cases = NA, so INLA will predict them.
# Fixed: use tag = "est" for combined data, extract indices manually
stack_fit <- inla.stack(
  data = list(y = combined_data$Cases),
  A = list(1),
  effects = list(
    data.frame(
      age_idx    = combined_data$age_idx,
      period_idx = combined_data$period_idx,
      cohort_idx = combined_data$cohort_idx
    ),
    data.frame(intercept = 1)
  ),
  tag = "est"
)

# Fit the model
bapc_fit <- inla(
  formula,
  family = "poisson",
  data   = inla.stack.data(stack_fit),
  A      = inla.stack.A(stack_fit),
  control.predictor = list(
    compute  = TRUE,
    link     = 1,
    A        = inla.stack.A(stack_fit)
  ),
  control.compute = list(
    dic  = TRUE,
    waic = TRUE,
    cpo  = TRUE
  )
)

cat("Model fitted successfully.\n")

# ==============================================================================
# 5. Extract Predictions
# ==============================================================================
cat("\n=== Step 3: Extracting predictions ===\n")

# Use inla.stack.index to get row indices for prediction data
idx_pred <- inla.stack.index(stack_fit, "pred")$data

# Extract fitted values for prediction rows
# Fixed: idx_pred should cover the prediction period rows
idx_pred <- ((n_obs + 1):n_total)

pred_summary <- bapc_fit$summary.fitted.values[idx_pred, ]

# Attach year and age group information
predictions <- pred_summary %>%
  as.data.frame() %>%
  mutate(
    year      = pred_data$year,
    Age_Group = pred_data$Age_Group
  )

# Aggregate predictions across age groups to get annual totals
annual_predictions <- predictions %>%
  group_by(year) %>%
  summarise(
    predicted_cases = sum(mean),
    lower_95        = sum(`0.025quant`),
    upper_95        = sum(`0.975quant`),
    .groups         = "drop"
  )

cat("Annual predictions:\n")
print(annual_predictions, n = 15)

# ==============================================================================
# 5b. Model Validation: Posterior Predictive Check on Observed Period
# ==============================================================================
cat("\n=== Step 3b: Model validation on observed period (2005-2020) ===\n")

# Extract fitted values for observation period
idx_obs <- 1:n_obs
fitted_obs <- bapc_fit$summary.fitted.values[idx_obs, ]
obs_fitted <- data.frame(
  year      = bapc_data$year,
  Age_Group = bapc_data$Age_Group,
  observed  = bapc_data$Cases,
  fitted    = fitted_obs$mean,
  lower_95  = fitted_obs$`0.025quant`,
  upper_95  = fitted_obs$`0.975quant`
)

# Aggregate to annual totals
annual_fitted <- obs_fitted %>%
  group_by(year) %>%
  summarise(
    observed   = sum(observed),
    fitted     = sum(fitted),
    lower_95   = sum(lower_95),
    upper_95   = sum(upper_95),
    .groups    = "drop"
  )

# Calculate fit metrics
annual_fitted <- annual_fitted %>%
  mutate(
    residual     = observed - fitted,
    rel_error    = abs(residual) / observed * 100,
    in_interval  = (observed >= lower_95) & (observed <= upper_95)
  )

cat("Observed vs Fitted (Annual Totals):\n")
print(annual_fitted, n = 20)
cat(sprintf("\nMean absolute percentage error: %.2f%%\n",
            mean(annual_fitted$rel_error)))
cat(sprintf("Coverage (95%% CI contains observed): %.1f%%\n",
            mean(annual_fitted$in_interval) * 100))

# ==============================================================================
# 6. Visualization - Figure 5: BAPC Prediction
# ==============================================================================
cat("\n=== Step 4: Creating visualization ===\n")

# Color palette (consistent with other scripts)
colors <- c(
  primary   = "#2E86AB",
  secondary = "#E94F37",
  tertiary  = "#44AF69",
  quaternary = "#F18F01",
  gray      = "#6C757D"
)

# Compute annual observed totals for the plot
obs_annual <- national_annual %>%
  group_by(year) %>%
  summarise(Cases = sum(Cases), .groups = "drop")

# Dynamic Y-axis limits
max_y <- max(c(obs_annual$Cases, annual_predictions$upper_95), na.rm = TRUE) * 1.15

# Create prediction plot
p <- ggplot() +
  # Observed data (solid line + points)
  geom_line(data = obs_annual,
            aes(x = year, y = Cases),
            linewidth = 1.2, color = colors["primary"]) +
  geom_point(data = obs_annual,
             aes(x = year, y = Cases),
             size = 3, color = colors["primary"]) +
  # Predictions (dashed line + points + credible interval ribbon)
  geom_line(data = annual_predictions,
            aes(x = year, y = predicted_cases),
            linewidth = 1.2, color = colors["secondary"], linetype = "dashed") +
  geom_ribbon(data = annual_predictions,
              aes(x = year, ymin = lower_95, ymax = upper_95),
              fill = colors["secondary"], alpha = 0.2) +
  geom_point(data = annual_predictions,
             aes(x = year, y = predicted_cases),
             size = 3, color = colors["secondary"], shape = 17) +
  # Vertical line separating observation and prediction
  geom_vline(xintercept = 2020.5, linetype = "dotted", color = "gray50") +
  annotate("text", x = 2020.8, y = max_y * 0.92,
           label = "Prediction ->", color = "gray50", size = 3.5, hjust = 0) +
  # Dynamic Y-axis
  scale_y_continuous(labels = scales::comma_format(), limits = c(0, max_y)) +
  scale_x_continuous(breaks = seq(2005, 2030, by = 5)) +
  labs(
    title    = "BAPC Model Prediction of HIV/AIDS Incidence in China (2005-2030)",
    subtitle = "Shaded area represents 95% credible interval",
    x = "Year",
    y = "Number of Cases"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 11, color = "gray40"),
    legend.position = "bottom"
  )

ggsave("Figure5_BAPC_Prediction.png", p, width = 10, height = 6, dpi = 300)
cat("Figure 5 saved to Figure5_BAPC_Prediction.png\n")

# ==============================================================================
# 7. Save Prediction Results
# ==============================================================================
write.csv(annual_predictions, "bapc_predictions.csv", row.names = FALSE)
cat("Predictions saved to bapc_predictions.csv\n")

# ==============================================================================
# 8. Model Diagnostics
# ==============================================================================
cat("\n=== Step 5: Model Diagnostics ===\n")
cat(sprintf("DIC: %.2f\n", bapc_fit$dic$dic))
cat(sprintf("WAIC: %.2f\n", bapc_fit$waic$waic))
cat(sprintf("Effective parameters (p.eff): %.2f\n", bapc_fit$dic$p.eff))

# ==============================================================================
# 9. Sensitivity Analysis: RW2 Prior
# ==============================================================================
cat("\n=== Step 6: Sensitivity Analysis (RW2 prior) ===\n")

formula_rw2 <- Cases ~ 1 +
  f(age_idx,    model = "rw2", cyclic = FALSE,
    prior = "pc.prec", param = c(1, 0.01)) +
  f(period_idx, model = "rw2", cyclic = FALSE,
    prior = "pc.prec", param = c(1, 0.01)) +
  f(cohort_idx, model = "rw2", cyclic = FALSE,
    prior = "pc.prec", param = c(1, 0.01))

bapc_rw2 <- inla(
  formula_rw2,
  family = "poisson",
  data   = inla.stack.data(stack_fit),
  A      = inla.stack.A(stack_fit),
  control.predictor = list(
    compute = TRUE,
    link    = 1,
    A       = inla.stack.A(stack_fit)
  ),
  control.compute = list(dic = TRUE, waic = TRUE)
)

cat(sprintf("RW2 DIC: %.2f\n", bapc_rw2$dic$dic))
cat(sprintf("RW2 WAIC: %.2f\n", bapc_rw2$waic$waic))

# Extract RW2 predictions for comparison
fitted_rw2 <- bapc_rw2$summary.fitted.values[idx_pred, ]
rw2_annual <- data.frame(year = pred_data$year, Age_Group = pred_data$Age_Group) %>%
  bind_cols(data.frame(predicted = fitted_rw2$mean)) %>%
  group_by(year) %>%
  summarise(rw2_predicted = sum(predicted), .groups = "drop")

# Compare RW1 vs RW2 predictions
comparison <- annual_predictions %>%
  left_join(rw2_annual, by = "year") %>%
  mutate(diff_pct = (rw2_predicted - predicted_cases) / predicted_cases * 100)

cat("\n=== RW1 vs RW2 Prediction Comparison ===\n")
print(comparison)
cat(sprintf("\nMean absolute difference: %.2f%%\n", mean(abs(comparison$diff_pct))))

cat("\n=== Script completed successfully ===\n")
