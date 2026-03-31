#!/usr/bin/env Rscript
# =============================================================================
# R Script for Joinpoint Regression Analysis of HIV/AIDS Data in China
# Author: Yu Shuang
# Date: 2025
# =============================================================================

# Install and load required packages
if (!require("tidyverse")) install.packages("tidyverse", repos = "https://cloud.r-project.org/")
if (!require("readxl")) install.packages("readxl", repos = "https://cloud.r-project.org/")

library(tidyverse)
library(readxl)

# =============================================================================
# 1. Data Preparation
# =============================================================================

# Read the raw data
# Note: Replace with your actual file path
raw_data <- read_excel("HIV_AIDS_Data_31_Provinces.xlsx")

# The data is already aggregated by year; rename columns to English for convenience
# Expected columns: Year, Cases, Deaths, Population, Incidence_rate_per_100k, Mortality_rate_per_100k
annual_data <- raw_data %>%
  rename(
    year       = `Year`,
    cases      = `Cases`,
    deaths     = `Deaths`,
    population = `Population`,
    incidence  = `Incidence_rate_per_100k`,
    mortality  = `Mortality_rate_per_100k`
  ) %>%
  mutate(
    year       = as.numeric(year),
    cases      = as.numeric(cases),
    deaths     = as.numeric(deaths),
    population = as.numeric(population),
    incidence  = as.numeric(incidence),
    mortality  = as.numeric(mortality)
  ) %>%
  filter(year >= 2005 & year <= 2020)

# Save prepared data
write.csv(annual_data, "joinpoint_data.csv", row.names = FALSE)

# =============================================================================
# 2. Joinpoint Analysis (using Joinpoint software output)
# =============================================================================
# Note: Joinpoint analysis requires the NCI Joinpoint software
# This script prepares data for Joinpoint and processes results

# Prepare data for Joinpoint software
joinpoint_input <- annual_data %>%
  select(year, cases, population) %>%
  mutate(
    year       = as.integer(year),
    cases      = as.integer(cases),
    population = as.numeric(population)   # avoid integer overflow for large values
  )

write.table(joinpoint_input, "joinpoint_input.txt", 
            sep = "\t", row.names = FALSE, quote = FALSE)

# =============================================================================
# 3. Manual APC Calculation (for verification)
# =============================================================================

calculate_apc <- function(data, start_year, end_year) {
  subset_data <- data %>% filter(year >= start_year & year <= end_year)
  
  # Log-linear regression
  model <- lm(log(cases) ~ year, data = subset_data)
  
  # APC calculation
  apc <- (exp(coef(model)[2]) - 1) * 100
  
  # Standard error and CI
  se <- summary(model)$coefficients[2, 2]
  ci_lower <- (exp(coef(model)[2] - 1.96 * se) - 1) * 100
  ci_upper <- (exp(coef(model)[2] + 1.96 * se) - 1) * 100
  
  return(list(
    period = paste(start_year, "-", end_year, sep = ""),
    apc = round(apc, 2),
    ci_lower = round(ci_lower, 2),
    ci_upper = round(ci_upper, 2)
  ))
}

# Calculate APC for different periods
apc_2005_2011 <- calculate_apc(annual_data, 2005, 2011)
apc_2012_2020 <- calculate_apc(annual_data, 2012, 2020)

# Calculate AAPC
calculate_aapc <- function(data) {
  model <- lm(log(cases) ~ year, data = data)
  aapc <- (exp(coef(model)[2]) - 1) * 100
  se <- summary(model)$coefficients[2, 2]
  ci_lower <- (exp(coef(model)[2] - 1.96 * se) - 1) * 100
  ci_upper <- (exp(coef(model)[2] + 1.96 * se) - 1) * 100
  
  return(list(
    aapc = round(aapc, 2),
    ci_lower = round(ci_lower, 2),
    ci_upper = round(ci_upper, 2)
  ))
}

aapc <- calculate_aapc(annual_data)

# =============================================================================
# 4. Results Summary
# =============================================================================

results <- data.frame(
  Period = c("2005-2011", "2012-2020", "2005-2020 (AAPC)"),
  APC = c(apc_2005_2011$apc, apc_2012_2020$apc, aapc$aapc),
  CI_Lower = c(apc_2005_2011$ci_lower, apc_2012_2020$ci_lower, aapc$ci_lower),
  CI_Upper = c(apc_2005_2011$ci_upper, apc_2012_2020$ci_upper, aapc$ci_upper)
)

print("Joinpoint Analysis Results:")
print(results)

# Save results
write.csv(results, "joinpoint_results.csv", row.names = FALSE)

# =============================================================================
# 5. Visualization
# =============================================================================

# Create annual trend plot
p <- ggplot(annual_data, aes(x = year, y = cases)) +
  geom_line(size = 1.2, color = "#2E86AB") +
  geom_point(size = 3, color = "#2E86AB") +
  geom_vline(xintercept = 2011, linetype = "dashed", color = "red") +
  annotate("text", x = 2011.5, y = max(annual_data$cases) * 0.9, 
           label = "2011 Inflection Point", color = "red") +
  labs(
    title = "Annual HIV/AIDS Cases in China (2005-2020)",
    x = "Year",
    y = "Number of Cases"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10)
  )

ggsave("figure1_annual_trend.png", p, width = 10, height = 6, dpi = 300)

# =============================================================================
# 6. Statistical Test for Inflection Point
# =============================================================================

# Chow test for structural break at 2011
chow_test <- function(data, break_point) {
  n1 <- sum(data$year < break_point)
  n2 <- sum(data$year >= break_point)
  
  # Full model
  model_full <- lm(log(cases) ~ year, data = data)
  
  # Split models
  model_1 <- lm(log(cases) ~ year, data = data %>% filter(year < break_point))
  model_2 <- lm(log(cases) ~ year, data = data %>% filter(year >= break_point))
  
  # RSS
  RSS_full <- sum(residuals(model_full)^2)
  RSS_1 <- sum(residuals(model_1)^2)
  RSS_2 <- sum(residuals(model_2)^2)
  RSS_pooled <- RSS_1 + RSS_2
  
  # F-statistic
  k <- 2  # number of parameters
  F_stat <- ((RSS_full - RSS_pooled) / k) / (RSS_pooled / (n1 + n2 - 2*k))
  p_value <- 1 - pf(F_stat, k, n1 + n2 - 2*k)
  
  return(list(F_stat = F_stat, p_value = p_value))
}

chow_result <- chow_test(annual_data, 2011)
print(paste("Chow test F-statistic:", round(chow_result$F_stat, 4)))
print(paste("P-value:", round(chow_result$p_value, 6)))

# =============================================================================
# End of Script
# =============================================================================
