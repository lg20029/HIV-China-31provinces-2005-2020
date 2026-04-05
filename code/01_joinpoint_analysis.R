#!/usr/bin/env Rscript
# =============================================================================
# R Script for Joinpoint Regression Analysis of HIV/AIDS Data in China
# Generates Figure 1: Annual Trend with 2011 Inflection Point
# Author: Yu Shuang
# Date: 2025
# =============================================================================

if (!require("tidyverse")) install.packages("tidyverse", repos = "https://cloud.r-project.org/")
if (!require("readxl"))    install.packages("readxl",   repos = "https://cloud.r-project.org/")

library(tidyverse)
library(readxl)

# =============================================================================
# 1. Data Preparation
# =============================================================================

raw_data <- read_excel("HIV_AIDS_Data_31_Provinces.xlsx")

# Actual columns: Province, Age_Group, Date (YYYY-MM), Cases, Incidence_Rate,
#                 Deaths, Mortality_Rate
# '-' denotes missing / zero cells; Date is monthly; data cover 31 provinces
# and multiple age groups.  We aggregate to national annual totals first.

# China mid-year population (100,000 persons), source: National Bureau of Statistics
china_pop_100k <- c(
  `2005` = 13076, `2006` = 13140, `2007` = 13213, `2008` = 13280,
  `2009` = 13347, `2010` = 13409, `2011` = 13474, `2012` = 13540,
  `2013` = 13607, `2014` = 13678, `2015` = 13751, `2016` = 13827,
  `2017` = 13902, `2018` = 13954, `2019` = 14005, `2020` = 14118
)

annual_data <- raw_data %>%
  mutate(
    # Replace '-' with NA, then coerce to numeric
    cases  = suppressWarnings(as.numeric(Cases)),
    deaths = suppressWarnings(as.numeric(Deaths)),
    cases  = replace_na(cases,  0),
    deaths = replace_na(deaths, 0),
    # Extract 4-digit year from 'YYYY-MM' Date column
    year   = as.integer(substr(Date, 1, 4))
  ) %>%
  filter(year >= 2005 & year <= 2020) %>%
  # Aggregate across all provinces, age groups, and months
  group_by(year) %>%
  summarise(
    cases  = sum(cases,  na.rm = TRUE),
    deaths = sum(deaths, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    population = as.numeric(china_pop_100k[as.character(year)]),
    incidence  = cases  / population,   # per 100,000 population
    mortality  = deaths / population
  )

write.csv(annual_data, "joinpoint_data.csv", row.names = FALSE)

# =============================================================================
# 2. Prepare Input for NCI Joinpoint Software
# =============================================================================

joinpoint_input <- annual_data %>%
  select(year, cases, population) %>%
  mutate(
    year       = as.integer(year),
    cases      = as.integer(round(cases)),
    population = as.numeric(population)
  )

write.table(joinpoint_input, "joinpoint_input.txt",
            sep = "\t", row.names = FALSE, quote = FALSE)

# =============================================================================
# 3. Annual Percent Change (APC) Calculation
# =============================================================================
# APC is modeled on the incidence RATE (per 100,000 population) via
# log-linear regression, consistent with standard epidemiological practice.
# Using absolute case counts would confound population size changes.
#
# Segmentation: 2011 inflection point identified by NCI Joinpoint software.
#   Segment 1: 2005-2011 (2011 assigned to first segment)
#   Segment 2: 2012-2020

calculate_apc <- function(data, start_year, end_year) {
  subset_data <- data %>% filter(year >= start_year & year <= end_year)
  model    <- lm(log(incidence) ~ year, data = subset_data)
  beta     <- coef(model)[2]
  se       <- summary(model)$coefficients[2, 2]
  p_val    <- summary(model)$coefficients[2, 4]

  list(
    period   = paste0(start_year, "-", end_year),
    apc      = round((exp(beta) - 1) * 100, 2),
    ci_lower = round((exp(beta - 1.96 * se) - 1) * 100, 2),
    ci_upper = round((exp(beta + 1.96 * se) - 1) * 100, 2),
    p_value  = round(p_val, 4)
  )
}

apc_2005_2011 <- calculate_apc(annual_data, 2005, 2011)
apc_2012_2020 <- calculate_apc(annual_data, 2012, 2020)

# =============================================================================
# 4. Average Annual Percent Change (AAPC)
# =============================================================================
# AAPC is the weighted average of segment APCs (weights = segment length),
# per NCI definition. The single log-linear fit below serves as an
# approximation; for the exact value use NCI Joinpoint software output.

calculate_aapc <- function(data) {
  model <- lm(log(incidence) ~ year, data = data)
  beta  <- coef(model)[2]
  se    <- summary(model)$coefficients[2, 2]
  p_val <- summary(model)$coefficients[2, 4]

  list(
    aapc     = round((exp(beta) - 1) * 100, 2),
    ci_lower = round((exp(beta - 1.96 * se) - 1) * 100, 2),
    ci_upper = round((exp(beta + 1.96 * se) - 1) * 100, 2),
    p_value  = round(p_val, 4)
  )
}

aapc <- calculate_aapc(annual_data)

# =============================================================================
# 5. Results Summary
# =============================================================================

results <- data.frame(
  Period   = c("2005-2011", "2012-2020", "2005-2020 (AAPC)"),
  APC_AAPC = c(apc_2005_2011$apc,      apc_2012_2020$apc,      aapc$aapc),
  CI_Lower = c(apc_2005_2011$ci_lower, apc_2012_2020$ci_lower, aapc$ci_lower),
  CI_Upper = c(apc_2005_2011$ci_upper, apc_2012_2020$ci_upper, aapc$ci_upper),
  P_Value  = c(apc_2005_2011$p_value,  apc_2012_2020$p_value,  aapc$p_value)
)

print("Joinpoint Analysis Results (Incidence Rate per 100,000):")
print(results)

write.csv(results, "joinpoint_results.csv", row.names = FALSE)

# =============================================================================
# 6. Visualization - Figure 1: Annual Trend
# =============================================================================

colors <- c(
  primary   = "#2E86AB",
  secondary = "#E94F37",
  tertiary  = "#44AF69",
  quaternary = "#F18F01",
  gray      = "#6C757D"
)

y_max <- max(annual_data$incidence, na.rm = TRUE) * 1.15

p <- ggplot(annual_data, aes(x = year, y = incidence)) +
  geom_line(linewidth = 1.2, color = colors["primary"]) +
  geom_point(size = 3, color = colors["primary"]) +
  geom_vline(xintercept = 2011, linetype = "dashed",
             color = colors["secondary"], linewidth = 0.8) +
  annotate("text", x = 2011.3, y = y_max * 0.95,
           label = "2011\nInflection\nPoint",
           color = colors["secondary"], size = 3.5,
           hjust = 0, fontface = "bold") +
  scale_y_continuous(
    labels = scales::number_format(accuracy = 0.01),
    limits = c(0, y_max)
  ) +
  scale_x_continuous(breaks = seq(2005, 2020, by = 1)) +
  labs(
    title    = "Annual HIV/AIDS Incidence Rate in China (2005-2020)",
    subtitle = "Showing the 2011 inflection point identified by Joinpoint regression",
    x        = "Year",
    y        = "Incidence Rate (per 100,000 population)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 11, color = "gray40"),
    axis.title    = element_text(size = 12),
    axis.text     = element_text(size = 10),
    axis.text.x   = element_text(angle = 45, hjust = 1),
    panel.grid.minor = element_blank()
  )

ggsave("Figure1_Annual_Trend.png", p, width = 10, height = 6, dpi = 300)

# =============================================================================
# 7. Chow Test for Structural Break at 2011
# =============================================================================
# Tests whether the slope of log(incidence) differs significantly between
# the two segments. The break point is set so that 2011 belongs to Segment 1
# (year <= 2011), consistent with the APC segmentation above.

chow_test <- function(data, break_point) {
  # Segment 1: year <= break_point  |  Segment 2: year > break_point
  data1 <- data %>% filter(year <= break_point)
  data2 <- data %>% filter(year >  break_point)

  n1 <- nrow(data1)
  n2 <- nrow(data2)
  k  <- 2  # intercept + slope

  model_full <- lm(log(incidence) ~ year, data = data)
  model_1    <- lm(log(incidence) ~ year, data = data1)
  model_2    <- lm(log(incidence) ~ year, data = data2)

  RSS_full   <- sum(residuals(model_full)^2)
  RSS_pooled <- sum(residuals(model_1)^2) + sum(residuals(model_2)^2)

  F_stat  <- ((RSS_full - RSS_pooled) / k) / (RSS_pooled / (n1 + n2 - 2 * k))
  p_value <- 1 - pf(F_stat, df1 = k, df2 = n1 + n2 - 2 * k)

  list(F_stat = round(F_stat, 4), p_value = round(p_value, 6))
}

chow_result <- chow_test(annual_data, 2011)
print(paste("Chow test F-statistic:", chow_result$F_stat))
print(paste("P-value:", chow_result$p_value))

# =============================================================================
# End of Script
# =============================================================================
