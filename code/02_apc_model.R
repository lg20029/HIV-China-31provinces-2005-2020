#!/usr/bin/env Rscript
# =============================================================================
# R Script for Age-Period-Cohort (APC) Model Analysis
# Author: Yu Shuang
# Date: 2025
# =============================================================================

# Install and load required packages
if (!require("tidyverse")) install.packages("tidyverse", repos = "https://cloud.r-project.org/")
if (!require("readxl")) install.packages("readxl", repos = "https://cloud.r-project.org/")
if (!require("apc")) install.packages("apc", repos = "https://cloud.r-project.org/")
if (!require("Epi")) install.packages("Epi", repos = "https://cloud.r-project.org/")
if (!require("patchwork")) install.packages("patchwork", repos = "https://cloud.r-project.org/")

library(tidyverse)
library(readxl)
library(apc)
library(Epi)
library(patchwork)

# =============================================================================
# 1. Data Preparation
# =============================================================================

# Read the raw data
raw_data <- read_excel("HIV_AIDS_Data_31_Provinces.xlsx")

# Create age-period matrix
# Age groups: 0-, 1-, 2-, ..., 85+
age_groups <- c("0-", "1-", "2-", "3-", "4-", "5-", "6-", "7-", "8-", "9-",
                "10-", "15-", "20-", "25-", "30-", "35-", "40-", "45-", "50-",
                "55-", "60-", "65-", "70-", "75-", "80-", "85+")

# Years: 2005-2020
years <- 2005:2020

# Create APC data matrix
apc_matrix <- matrix(0, nrow = length(age_groups), ncol = length(years))
rownames(apc_matrix) <- age_groups
colnames(apc_matrix) <- years

# Fill the matrix with case counts
for (i in 1:nrow(raw_data)) {
  age_idx <- match(raw_data$Age_group[i], age_groups)
  year_val <- as.numeric(gsub("-.*", "", raw_data$Date[i]))
  year_idx <- match(year_val, years)
  
  if (!is.na(age_idx) && !is.na(year_idx)) {
    cases <- as.numeric(gsub("-", "0", raw_data$`Cases`[i]))
    if (!is.na(cases)) {
      apc_matrix[age_idx, year_idx] <- apc_matrix[age_idx, year_idx] + cases
    }
  }
}

# Save APC data
write.csv(apc_matrix, "apc_data.csv")

# =============================================================================
# 2. Create APC Data Object
# =============================================================================

# Prepare data for apc package
# Using the apc package format
apc_data <- as.data.frame(apc_matrix) %>%
  rownames_to_column("age_group") %>%
  pivot_longer(cols = -age_group, names_to = "year", values_to = "cases") %>%
  mutate(
    year = as.numeric(year),
    age_group = factor(age_group, levels = age_groups)
  )

# Create age and period indices
# Age midpoints for each age group
age_midpoints <- c(0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5,
                   12.5, 17.5, 22.5, 27.5, 32.5, 37.5, 42.5, 47.5, 52.5,
                   57.5, 62.5, 67.5, 72.5, 77.5, 82.5, 87.5)

apc_data <- apc_data %>%
  mutate(
    age = age_midpoints[as.numeric(age_group)],
    period = year - 2005 + 1
  )

# Save long format data
write.csv(apc_data, "apc_data_long.csv", row.names = FALSE)

# =============================================================================
# 3. APC Model Fitting using Intrinsic Estimator
# =============================================================================

# Create apc data object
apc_obj <- apc.data.model(
  apc_matrix,
  model = "APC",
  age1 = 1,
  per1 = 2005,
  coh1 = NULL,
  nA = length(age_groups),
  nP = length(years),
  nC = length(age_groups) + length(years) - 1
)

# Fit APC model with Intrinsic Estimator
apc_fit <- apc.fit.model(apc_obj, "APC", "IE")

# Extract effects
age_effect <- apc_fit$coefficients.canonical[1:length(age_groups)]
period_effect <- apc_fit$coefficients.canonical[(length(age_groups)+1):(length(age_groups)+length(years))]
cohort_effect <- apc_fit$coefficients.canonical[(length(age_groups)+length(years)+1):length(apc_fit$coefficients.canonical)]

# =============================================================================
# 4. Results Summary
# =============================================================================

# Age effect
age_results <- data.frame(
  age_group = age_groups,
  age_effect = age_effect,
  age_mid = c(0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5,
              12.5, 17.5, 22.5, 27.5, 32.5, 37.5, 42.5, 47.5, 52.5,
              57.5, 62.5, 67.5, 72.5, 77.5, 82.5, 87.5)
)

# Period effect
period_results <- data.frame(
  year = years,
  period_effect = period_effect
)

# Cohort effect
birth_cohorts <- 2005 - c(0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5,
                          12.5, 17.5, 22.5, 27.5, 32.5, 37.5, 42.5, 47.5, 52.5,
                          57.5, 62.5, 67.5, 72.5, 77.5, 82.5, 87.5) + 
                 rep(0:(length(years)-1), each = length(age_groups))

cohort_results <- data.frame(
  cohort_index = 1:length(cohort_effect),
  cohort_effect = cohort_effect
)

# Save results
write.csv(age_results, "apc_age_effect.csv", row.names = FALSE)
write.csv(period_results, "apc_period_effect.csv", row.names = FALSE)
write.csv(cohort_results, "apc_cohort_effect.csv", row.names = FALSE)

# =============================================================================
# 5. Visualization
# =============================================================================

# Age effect plot
p_age <- ggplot(age_results, aes(x = age_mid, y = age_effect)) +
  geom_line(size = 1.2, color = "#2E86AB") +
  geom_point(size = 2) +
  labs(
    title = "Age Effect on HIV/AIDS Incidence",
    x = "Age (years)",
    y = "Age Effect (log relative risk)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("apc_age_effect.png", p_age, width = 8, height = 5, dpi = 300)

# Period effect plot
p_period <- ggplot(period_results, aes(x = year, y = period_effect)) +
  geom_line(size = 1.2, color = "#E94F37") +
  geom_point(size = 2) +
  geom_vline(xintercept = 2011, linetype = "dashed", color = "gray50") +
  labs(
    title = "Period Effect on HIV/AIDS Incidence",
    x = "Year",
    y = "Period Effect (log relative risk)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("apc_period_effect.png", p_period, width = 8, height = 5, dpi = 300)

# Cohort effect plot
p_cohort <- ggplot(cohort_results, aes(x = cohort_index, y = cohort_effect)) +
  geom_line(size = 1.2, color = "#44AF69") +
  geom_point(size = 2) +
  labs(
    title = "Cohort Effect on HIV/AIDS Incidence",
    x = "Cohort Index",
    y = "Cohort Effect (log relative risk)"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

ggsave("apc_cohort_effect.png", p_cohort, width = 8, height = 5, dpi = 300)

# Combined APC plot (patchwork already loaded at top)
p_combined <- p_age / p_period / p_cohort
ggsave("figure5_apc_combined.png", p_combined, width = 10, height = 12, dpi = 300)

# =============================================================================
# 6. Model Diagnostics
# =============================================================================

# Deviance and degrees of freedom
print(paste("Deviance:", round(apc_fit$deviance, 4)))
print(paste("Degrees of freedom:", apc_fit$df.residual))

# =============================================================================
# End of Script
# =============================================================================
