#!/usr/bin/env Rscript
# =============================================================================
# R Script for Policy Scenario Analysis
# Generates Figure 6: Scenario Analysis
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

# Read annual data from validated data file
annual_data <- read.csv("data/joinpoint_data.csv")

# Base year (2020) cases - use original data (62,167) for scenario projections
# Note: This matches the paper's baseline (not the BAPC-processed 61,412)
base_cases <- annual_data %>% filter(year == 2020) %>% pull(cases)

# =============================================================================
# 2. Define Scenarios
# =============================================================================

# Scenario 1: Constant Growth (Pessimistic)
# Assumes APC of 6.84% continues throughout 2021-2030
scenario_constant <- function(base, years, apc) {
  cases <- numeric(length(years))
  cases[1] <- base * (1 + apc/100)
  for (i in 2:length(years)) {
    cases[i] <- cases[i-1] * (1 + apc/100)
  }
  return(round(cases))
}

# Scenario 2: Moderate Acceleration
# 2021-2025: Maintain APC 6.84%
# 2026-2030: 5% annual decline
scenario_moderate <- function(base, years) {
  cases <- numeric(length(years))
  # 2021-2025: 6.84% growth (5 years: 2021,2022,2023,2024,2025)
  cases[1] <- base * (1 + 6.84/100)  # 2021
  cases[2] <- cases[1] * (1 + 6.84/100)  # 2022
  cases[3] <- cases[2] * (1 + 6.84/100)  # 2023
  cases[4] <- cases[3] * (1 + 6.84/100)  # 2024
  cases[5] <- cases[4] * (1 + 6.84/100)  # 2025
  # 2026-2030: 5% decline (5 years)
  cases[6] <- cases[5] * (1 - 5/100)  # 2026
  cases[7] <- cases[6] * (1 - 5/100)  # 2027
  cases[8] <- cases[7] * (1 - 5/100)  # 2028
  cases[9] <- cases[8] * (1 - 5/100)  # 2029
  cases[10] <- cases[9] * (1 - 5/100) # 2030
  return(round(cases))
}

# Scenario 3: Intensified Intervention (Optimistic)
# 2021-2025: 12% annual decline (achieving 90-95-95 by 2025)
# 2026-2030: 12% annual decline (achieving 95-95-95 by 2030)
# Note: Consistent 12% decline throughout 2021-2030
scenario_intensified <- function(base, years) {
  cases <- numeric(length(years))
  # 2021-2030: 12% decline throughout
  cases[1] <- base * (1 - 12/100)
  for (i in 2:length(years)) {
    cases[i] <- cases[i-1] * (1 - 12/100)
  }
  return(round(cases))
}

# =============================================================================
# 3. Generate Scenario Projections
# =============================================================================

years <- 2021:2030

scenario_results <- data.frame(
  year = years,
  constant_growth = scenario_constant(base_cases, years, 6.84),
  moderate_acceleration = scenario_moderate(base_cases, years),
  intensified_intervention = scenario_intensified(base_cases, years)
)

# Add base year
scenario_results <- rbind(
  data.frame(
    year = 2020,
    constant_growth = base_cases,
    moderate_acceleration = base_cases,
    intensified_intervention = base_cases
  ),
  scenario_results
)

# Convert to long format
scenario_long <- scenario_results %>%
  pivot_longer(
    cols = -year,
    names_to = "scenario",
    values_to = "cases"
  ) %>%
  mutate(
    scenario = factor(scenario, 
                      levels = c("constant_growth", "moderate_acceleration", "intensified_intervention"),
                      labels = c("Constant Growth", "Moderate Acceleration", "Intensified Intervention"))
  )

# Save scenario results
write.csv(scenario_results, "scenario_analysis_corrected.csv", row.names = FALSE)

# =============================================================================
# 4. Summary Statistics
# =============================================================================

# Calculate key metrics
summary_stats <- scenario_results %>%
  summarise(
    year_2030_constant = constant_growth[year == 2030],
    year_2030_moderate = moderate_acceleration[year == 2030],
    year_2030_intensified = intensified_intervention[year == 2030],
    reduction_vs_constant = round((1 - year_2030_intensified / year_2030_constant) * 100, 1),
    reduction_vs_base = round((1 - year_2030_intensified / base_cases) * 100, 1)
  )

print("Scenario Analysis Summary:")
print(paste("2030 Constant Growth:", summary_stats$year_2030_constant, "cases"))
print(paste("2030 Moderate Acceleration:", summary_stats$year_2030_moderate, "cases"))
print(paste("2030 Intensified Intervention:", summary_stats$year_2030_intensified, "cases"))
print(paste("Reduction vs Constant Growth:", summary_stats$reduction_vs_constant, "%"))
print(paste("Reduction vs 2020 Base:", summary_stats$reduction_vs_base, "%"))

# =============================================================================
# 5. Visualization - Figure 6: Scenario Analysis
# =============================================================================

# Color palette
colors <- c(
  primary = "#2E86AB",
  secondary = "#E94F37",
  tertiary = "#44AF69",
  quaternary = "#F18F01",
  gray = "#6C757D"
)

# Create scenario plot
p <- ggplot(scenario_long, aes(x = year, y = cases, color = scenario)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  # Add observed data
  geom_line(data = annual_data, aes(x = year, y = cases, color = NULL), 
            inherit.aes = FALSE, linewidth = 1.2, color = "gray50", linetype = "dashed") +
  geom_point(data = annual_data, aes(x = year, y = cases, color = NULL),
             inherit.aes = FALSE, size = 2, color = "gray50") +
  # Vertical line at 2020
  geom_vline(xintercept = 2020, linetype = "dotted", color = "gray50") +
  # Annotations
  annotate("text", x = 2025, y = 130000, label = "Constant Growth\n(6.84% APC)", 
           color = colors["primary"], size = 3, fontface = "bold") +
  annotate("text", x = 2027, y = 75000, label = "Moderate\nAcceleration", 
           color = colors["secondary"], size = 3, fontface = "bold") +
  annotate("text", x = 2028, y = 25000, label = "Intensified\nIntervention", 
           color = colors["tertiary"], size = 3, fontface = "bold") +
  scale_color_manual(values = c(colors["primary"], colors["secondary"], colors["tertiary"])) +
  scale_y_continuous(labels = scales::comma_format(), limits = c(0, 150000)) +
  labs(
    title = "HIV/AIDS Projections Under Three Policy Scenarios (2020-2030)",
    subtitle = "Based on China Action Plan (2024-2030) targets",
    x = "Year",
    y = "Number of Cases",
    color = "Scenario"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 11, color = "gray40"),
    legend.position = "bottom"
  )

ggsave("Figure6_Scenario_Analysis.png", p, width = 10, height = 6, dpi = 300)

# =============================================================================
# 6. Create Table 1 Data
# =============================================================================

# Create formatted table for manuscript
table1 <- scenario_results %>%
  filter(year %in% c(2020, 2025, 2030)) %>%
  mutate(
    Year = year,
    `Constant Growth` = format(constant_growth, big.mark = ","),
    `Moderate Acceleration` = format(moderate_acceleration, big.mark = ","),
    `Intensified Intervention` = format(intensified_intervention, big.mark = ",")
  ) %>%
  select(Year, `Constant Growth`, `Moderate Acceleration`, `Intensified Intervention`)

print("Table 1: Projected HIV/AIDS Cases Under Three Scenarios")
print(table1)

write.csv(table1, "table1_scenario_projections.csv", row.names = FALSE)

# =============================================================================
# 7. Cumulative Cases Analysis
# =============================================================================

# Calculate cumulative cases for each scenario
cumulative_cases <- scenario_results %>%
  mutate(
    cum_constant = cumsum(constant_growth),
    cum_moderate = cumsum(moderate_acceleration),
    cum_intensified = cumsum(intensified_intervention)
  )

# Cases averted by intensified intervention
cases_averted <- cumulative_cases %>%
  summarise(
    total_constant = sum(constant_growth),
    total_moderate = sum(moderate_acceleration),
    total_intensified = sum(intensified_intervention),
    averted_vs_constant = total_constant - total_intensified,
    averted_vs_moderate = total_moderate - total_intensified
  )

print("Cumulative Cases (2021-2030):")
print(paste("Constant Growth:", format(cases_averted$total_constant, big.mark = ",")))
print(paste("Moderate Acceleration:", format(cases_averted$total_moderate, big.mark = ",")))
print(paste("Intensified Intervention:", format(cases_averted$total_intensified, big.mark = ",")))
print(paste("Cases Averted vs Constant:", format(cases_averted$averted_vs_constant, big.mark = ",")))
print(paste("Cases Averted vs Moderate:", format(cases_averted$averted_vs_moderate, big.mark = ",")))

# =============================================================================
# End of Script
# =============================================================================
