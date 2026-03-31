#!/usr/bin/env Rscript
# =============================================================================
# R Script for Bayesian Age-Period-Cohort (BAPC) Prediction Model
# Author: Yu Shuang
# Date: 2025
# =============================================================================

# Install and load required packages
# Note: INLA installation requires special handling
# Run the following if INLA is not installed:
# install.packages("INLA", repos = c(getOption("repos"), INLA = "https://inla.r-inla-download.org/R/stable"), dep = TRUE)

if (!require("tidyverse")) install.packages("tidyverse", repos = "https://cloud.r-project.org/")
if (!require("INLA")) {
  install.packages("INLA", repos = c(getOption("repos"), INLA = "https://inla.r-inla-download.org/R/stable"), dep = TRUE)
}
if (!require("forecast")) install.packages("forecast", repos = "https://cloud.r-project.org/")

library(tidyverse)
library(INLA)
library(forecast)

# =============================================================================
# 1. Data Preparation
# =============================================================================

# Read annual data
annual_data <- read.csv("joinpoint_data.csv")

# Prepare data for BAPC model
# Create age groups (simplified for demonstration)
# In practice, use detailed age-specific data

years <- annual_data$year
cases <- annual_data$cases
n_years <- length(years)

# Create data frame for modeling
model_data <- data.frame(
  year = years,
  cases = cases,
  year_index = 1:n_years,
  population = annual_data$population
)

# =============================================================================
# 2. BAPC Model Specification
# =============================================================================

# Define the model formula
# RW2 for period effect (smooth trend)
# Using Poisson distribution for case counts

# Create design matrix for age-period-cohort
# Simplified version - period effect only
model_formula <- cases ~ 1 + f(year_index, model = "rw2", hyper = list(
  prec = list(prior = "loggamma", param = c(1, 0.00005))
))

# =============================================================================
# 3. Model Fitting
# =============================================================================

cat("Fitting BAPC model...\n")

# Fit the model using INLA
bapc_fit <- inla(
  formula = model_formula,
  family = "poisson",
  data = model_data,
  control.compute = list(dic = TRUE, waic = TRUE, config = TRUE),
  control.predictor = list(compute = TRUE),
  num.threads = 2
)

# Summary of the fit
print(summary(bapc_fit))

# =============================================================================
# 4. Prediction for 2021-2030
# =============================================================================

cat("Generating predictions for 2021-2030...\n")

# Extend data for prediction
n_pred <- 10  # 10 years ahead
pred_years <- 2021:2030

# Create extended data frame
extended_data <- data.frame(
  year = c(years, pred_years),
  year_index = 1:(n_years + n_pred),
  cases = c(cases, rep(NA, n_pred)),
  population = c(model_data$population, rep(model_data$population[n_years], n_pred))
)

# Fit model with prediction
bapc_pred <- inla(
  formula = model_formula,
  family = "poisson",
  data = extended_data,
  control.compute = list(dic = TRUE, waic = TRUE, config = TRUE),
  control.predictor = list(compute = TRUE, link = 1),
  num.threads = 2
)

# Extract predictions
predictions <- bapc_pred$summary.fitted.values[(n_years+1):(n_years+n_pred), ]

# Create prediction data frame
pred_results <- data.frame(
  year = pred_years,
  mean = predictions$mean,
  lower = predictions$`0.025quant`,
  upper = predictions$`0.975quant`
)

print("Predictions for 2021-2030:")
print(pred_results)

# Save predictions
write.csv(pred_results, "bapc_predictions.csv", row.names = FALSE)

# =============================================================================
# 5. Model Validation
# =============================================================================

cat("Performing model validation...\n")

# Internal validation: 2005-2018 -> predict 2019-2020
train_data <- model_data %>% filter(year <= 2018)
test_data <- model_data %>% filter(year > 2018)

# Fit on training data
val_fit <- inla(
  formula = cases ~ 1 + f(year_index, model = "rw2", hyper = list(
    prec = list(prior = "loggamma", param = c(1, 0.00005))
  )),
  family = "poisson",
  data = train_data,
  control.predictor = list(compute = TRUE),
  num.threads = 2
)

# Predict 2019-2020
# Note: Use only train_data fitted model (val_fit) to do genuine out-of-sample prediction.
# Append NA rows for 2019-2020 so that INLA extrapolates via the RW2 prior,
# without the model "seeing" the future observations.
val_pred_data <- data.frame(
  year       = c(train_data$year, 2019, 2020),
  year_index = 1:(nrow(train_data) + 2),
  cases      = c(train_data$cases, NA, NA),
  population = c(train_data$population,
                 model_data$population[model_data$year == 2019],
                 model_data$population[model_data$year == 2020])
)

val_pred <- inla(
  formula = cases ~ 1 + f(year_index, model = "rw2", hyper = list(
    prec = list(prior = "loggamma", param = c(1, 0.00005))
  )),
  family = "poisson",
  data = val_pred_data,
  # Use the hyperparameters estimated from val_fit (training data only)
  # to ensure no information leakage from the test period
  control.mode = list(result = val_fit, restart = TRUE),
  control.predictor = list(compute = TRUE, link = 1),
  num.threads = 2
)

# Extract validation predictions
val_results <- val_pred$summary.fitted.values[(nrow(train_data)+1):(nrow(train_data)+2), ]

# Calculate MAPE
actual_2019 <- model_data$cases[model_data$year == 2019]
actual_2020 <- model_data$cases[model_data$year == 2020]
pred_2019 <- val_results$mean[1]
pred_2020 <- val_results$mean[2]

mape <- mean(c(
  abs(actual_2019 - pred_2019) / actual_2019,
  abs(actual_2020 - pred_2020) / actual_2020
)) * 100

print(paste("MAPE (Internal Validation):", round(mape, 2), "%"))

# =============================================================================
# 6. Scenario Analysis
# =============================================================================

cat("Performing scenario analysis...\n")

# Baseline scenario: maintain 2012-2020 APC (6.84%)
baseline_pred <- data.frame(
  year = 2021:2030,
  scenario = "Baseline",
  cases = sapply(1:10, function(t) {
    round(62167 * (1.0684)^t)
  })
)

# Intensified intervention scenario
# 2021-2025: -12% per year
# 2026-2030: -8% per year
intensified_pred <- data.frame(
  year = 2021:2030,
  scenario = "Intensified",
  cases = sapply(1:10, function(t) {
    if (t <= 5) {
      round(62167 * (0.88)^t)
    } else {
      round(62167 * (0.88)^5 * (0.92)^(t-5))
    }
  })
)

# Moderate intervention scenario
# 2021-2025: +6.84% per year
# 2026-2030: -5% per year
moderate_pred <- data.frame(
  year = 2021:2030,
  scenario = "Moderate",
  cases = sapply(1:10, function(t) {
    if (t <= 5) {
      round(62167 * (1.0684)^t)
    } else {
      round(62167 * (1.0684)^5 * (0.95)^(t-5))
    }
  })
)

# Combine scenarios
scenario_results <- rbind(baseline_pred, intensified_pred, moderate_pred)

print("Scenario Analysis Results:")
print(scenario_results %>% pivot_wider(names_from = scenario, values_from = cases))

# Save scenario results
write.csv(scenario_results, "scenario_analysis.csv", row.names = FALSE)

# =============================================================================
# 7. Sensitivity Analysis
# =============================================================================

cat("Performing sensitivity analysis...\n")

# RW1 vs RW2 prior sensitivity
# Fit with RW1 prior
rw1_fit <- inla(
  formula = cases ~ 1 + f(year_index, model = "rw1", hyper = list(
    prec = list(prior = "loggamma", param = c(1, 0.00005))
  )),
  family = "poisson",
  data = extended_data,
  control.predictor = list(compute = TRUE, link = 1),
  num.threads = 2
)

rw1_pred <- rw1_fit$summary.fitted.values[(n_years+1):(n_years+n_pred), ]

# Compare predictions
sensitivity_comparison <- data.frame(
  year = pred_years,
  RW2_mean = predictions$mean,
  RW1_mean = rw1_pred$mean,
  difference = abs(predictions$mean - rw1_pred$mean),
  cv = abs(predictions$mean - rw1_pred$mean) / ((predictions$mean + rw1_pred$mean) / 2) * 100
)

print("Sensitivity Analysis (RW1 vs RW2):")
print(sensitivity_comparison)

# Calculate mean CV across years to quantify RW1 vs RW2 disagreement
# (averaging the per-year CV already computed in sensitivity_comparison)
cv_mean <- mean(sensitivity_comparison$cv)
print(paste("Mean CV between RW1 and RW2 predictions:", round(cv_mean, 2), "%"))

# Save sensitivity results
write.csv(sensitivity_comparison, "sensitivity_analysis.csv", row.names = FALSE)

# =============================================================================
# 8. Visualization
# =============================================================================

cat("Creating visualizations...\n")

# Historical trend with prediction
hist_pred <- ggplot() +
  geom_line(data = model_data, aes(x = year, y = cases), linewidth = 1.2, color = "#2E86AB") +
  geom_point(data = model_data, aes(x = year, y = cases), size = 2, color = "#2E86AB") +
  geom_ribbon(data = pred_results, aes(x = year, ymin = lower, ymax = upper), 
              fill = "#E94F37", alpha = 0.3) +
  geom_line(data = pred_results, aes(x = year, y = mean), linewidth = 1.2, color = "#E94F37", linetype = "dashed") +
  labs(
    title = "HIV/AIDS Cases in China: Historical Trend and BAPC Prediction",
    x = "Year",
    y = "Number of Cases"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("figure7_bapc_prediction.png", hist_pred, width = 10, height = 6, dpi = 300)

# Scenario analysis plot
scenario_plot <- ggplot(scenario_results, aes(x = year, y = cases, color = scenario)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  scale_color_manual(values = c("#2E86AB", "#E94F37", "#44AF69")) +
  labs(
    title = "HIV/AIDS Projections Under Three Policy Scenarios",
    x = "Year",
    y = "Number of Cases",
    color = "Scenario"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("figure8_scenario_analysis.png", scenario_plot, width = 10, height = 6, dpi = 300)

# =============================================================================
# 9. Model Diagnostics
# =============================================================================

cat("Model Diagnostics:\n")
print(paste("DIC:", round(bapc_fit$dic$dic, 2)))
print(paste("WAIC:", round(bapc_fit$waic$waic, 2)))

# Effective number of parameters
print(paste("Effective number of parameters:", round(bapc_fit$dic$p.eff, 2)))

# =============================================================================
# End of Script
# =============================================================================
