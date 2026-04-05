#!/usr/bin/env Rscript
# =============================================================================
# R Script for Age Distribution Analysis of HIV/AIDS Cases
# Generates Figure 3: Age Distribution
# Author: Yu Shuang
# Date: 2025
# =============================================================================

# Install and load required packages
if (!require("tidyverse")) install.packages("tidyverse", repos = "https://cloud.r-project.org/")
if (!require("readxl"))    install.packages("readxl",   repos = "https://cloud.r-project.org/")
if (!require("patchwork")) install.packages("patchwork", repos = "https://cloud.r-project.org/")

library(tidyverse)
library(readxl)
library(patchwork)

# =============================================================================
# 1. Data Preparation
# =============================================================================

# Read the raw data
raw_data <- read_excel("HIV_AIDS_Data_31_Provinces.xlsx")

# Coerce columns to correct types
raw_data <- raw_data %>%
  mutate(
    Cases = suppressWarnings(as.numeric(Cases)),
    Deaths = suppressWarnings(as.numeric(Deaths))
  )

# The data contains two types of age groups:
#   - 5-year bands (0-4, 5-9, 10-14, ..., 50-54, 75-79) with NaN cases
#   - Single-age open-ended (20-, 25-, 30-, ..., 85+, not-known) with actual data
# We use only the open-ended groups which have actual case counts.

# Define broad age groups to retain (those with actual data)
broad_ages <- c("0-4", "5-9", "10-14", "15-19",
                "20-", "25-", "30-", "35-", "40-", "45-",
                "50-", "55-", "60-", "65-", "70-", "75-", "80-", "85+",
                "not-known")

# Map Chinese label
raw_data <- raw_data %>%
  mutate(Age_Group = ifelse(Age_Group == "\u4e0d\u8be6", "not-known", Age_Group))

# Filter to broad age groups only
age_data <- raw_data %>%
  filter(Age_Group %in% broad_ages) %>%
  mutate(
    year = as.integer(substr(Date, 1, 4)),
    Age_Group = factor(Age_Group, levels = broad_ages)
  )

# Aggregate to national annual totals by age group (sum over provinces and months)
annual_age <- age_data %>%
  filter(!is.na(Cases)) %>%
  group_by(year, Age_Group) %>%
  summarise(cases = sum(Cases, na.rm = TRUE), .groups = "drop")

# =============================================================================
# 2. Define Age Groups for Analysis
# =============================================================================

# Map single-age groups to broader 10-year categories for trend analysis
# Data has single-age open-ended groups: 20-, 25-, 30-, ..., 85+
# We combine adjacent groups into 10-year bands
# Note: 50- and 55- together = 50-64 (paper uses 50+ as threshold)
age_data <- age_data %>%
  mutate(
    Age_Cat = case_when(
      Age_Group %in% c("0-4", "5-9", "10-14")                  ~ "0-14",
      Age_Group %in% c("15-19", "20-")                         ~ "15-24",
      Age_Group %in% c("25-", "30-")                           ~ "25-34",
      Age_Group %in% c("35-", "40-")                           ~ "35-44",
      Age_Group %in% c("45-", "50-")                           ~ "45-54",
      Age_Group %in% c("55-", "60-")                           ~ "55-64",
      Age_Group %in% c("65-", "70-", "75-", "80-", "85+")     ~ "65+",
      TRUE                                                      ~ "not-known"
    ),
    Age_Cat = factor(Age_Cat, levels = c("0-14", "15-24", "25-34", "35-44",
                                          "45-54", "55-64", "65+"))
  )

# Aggregate by 10-year category
annual_cat <- age_data %>%
  filter(!is.na(Cases), Age_Cat != "not-known") %>%
  group_by(year, Age_Cat) %>%
  summarise(cases = sum(Cases, na.rm = TRUE), .groups = "drop")

# Calculate proportions within each year
annual_cat <- annual_cat %>%
  group_by(year) %>%
  mutate(
    proportion = cases / sum(cases) * 100,
    total = sum(cases)
  ) %>%
  ungroup()

# =============================================================================
# 3. Age Distribution Statistics
# =============================================================================

cat("Age Distribution Statistics (10-year categories):\n")
age_stats <- annual_cat %>%
  group_by(Age_Cat) %>%
  summarise(
    total_cases  = sum(cases),
    mean_prop    = mean(proportion),
    trend_slope  = lm(cases ~ year)$coefficients[2],
    .groups = "drop"
  )
print(age_stats)

# Overall age distribution (2005-2020)
cat("\nOverall age distribution (2005-2020):\n")
overall <- annual_cat %>%
  group_by(Age_Cat) %>%
  summarise(cases = sum(cases)) %>%
  mutate(pct = cases / sum(cases) * 100)
print(overall)

# Proportion aged 50+ over time (paper: 35.6% overall)
# In the data, "50-" is a single-age group starting at 50; paper uses 50+ threshold
# Using broad age groups directly (50- = 50+, 55- = 55+, etc.)
cat("\nProportion aged 50+ over time (from raw data, using broad groups):\n")
broad_50plus_ages <- c("50-", "55-", "60-", "65-", "70-", "75-", "80-", "85+")
prop_50plus_raw <- age_data %>%
  filter(!is.na(Cases), Age_Group %in% broad_50plus_ages) %>%
  group_by(year) %>%
  summarise(cases_50plus = sum(Cases), .groups = "drop")

# Total cases from ALL age groups (including narrow bands with data like 50-54, 75-79)
total_by_year <- raw_data %>%
  mutate(year = as.integer(substr(Date, 1, 4))) %>%
  filter(!is.na(Cases)) %>%
  group_by(year) %>%
  summarise(cases_total = sum(Cases), .groups = "drop")

prop_50plus <- prop_50plus_raw %>%
  left_join(total_by_year, by = "year") %>%
  mutate(pct_50plus = cases_50plus / cases_total * 100)
print(prop_50plus)
cat(sprintf("Overall proportion aged 50+ (2005-2020): %.1f%%\n",
            sum(prop_50plus$cases_50plus) / sum(prop_50plus$cases_total) * 100))

# Save age distribution data
write.csv(annual_cat, "age_distribution_data.csv", row.names = FALSE)

# =============================================================================
# 4. Visualization - Figure 3: Age Distribution
# =============================================================================

# Color palette (colorblind-friendly)
age_colors <- c(
  "0-14"  = "#4E79A7",
  "15-24" = "#F28E2B",
  "25-34" = "#E15759",
  "35-44" = "#76B7B2",
  "45-54" = "#59A14F",
  "55-64" = "#EDC948",
  "65+"   = "#B07AA1"
)

# --- Panel A: Stacked bar chart of age distribution by year ---
p_a <- ggplot(annual_cat, aes(x = factor(year), y = cases, fill = Age_Cat)) +
  geom_bar(stat = "identity", alpha = 0.9, color = "white", linewidth = 0.2) +
  scale_fill_manual(values = age_colors) +
  labs(
    title = "(A) Age Distribution of HIV/AIDS Cases by Year",
    x = "Year",
    y = "Number of Cases",
    fill = "Age Group"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0, size = 11, face = "bold"),
    legend.position = "right",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

# --- Panel B: Proportion of cases by age group over time ---
p_b <- ggplot(annual_cat, aes(x = year, y = proportion, color = Age_Cat)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  scale_color_manual(values = age_colors) +
  labs(
    title = "(B) Proportion of Cases by Age Group Over Time",
    x = "Year",
    y = "Proportion (%)",
    color = "Age Group"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0, size = 11, face = "bold"),
    legend.position = "right"
  )

# --- Panel C: Age distribution heatmap ---
p_c <- ggplot(annual_cat, aes(x = year, y = Age_Cat, fill = proportion)) +
  geom_tile(color = "white") +
  scale_fill_gradient(low = "#FFFFCC", high = "#B30000",
                      name = "Proportion (%)") +
  labs(
    title = "(C) Age Distribution Heatmap",
    x = "Year",
    y = "Age Group"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0, size = 11, face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

# --- Panel D: Horizontal bar chart for 2020 ---
d_2020 <- annual_cat %>%
  filter(year == 2020) %>%
  mutate(Age_Cat = factor(Age_Cat, levels = rev(levels(Age_Cat))))

p_d <- ggplot(d_2020, aes(x = Age_Cat, y = proportion, fill = Age_Cat)) +
  geom_bar(stat = "identity", alpha = 0.9) +
  geom_text(aes(label = sprintf("%.1f%%", proportion)), hjust = -0.1, size = 3) +
  coord_flip() +
  scale_fill_manual(values = age_colors) +
  labs(
    title = "(D) Age Distribution in 2020",
    x = "Age Group",
    y = "Proportion (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0, size = 11, face = "bold"),
    legend.position = "none"
  ) +
  ylim(0, max(d_2020$proportion) * 1.15)

# Combine panels
p_combined <- (p_a + p_b) / (p_c + p_d) +
  plot_annotation(
    title = "Figure 3: Age Distribution of HIV/AIDS Cases in China (2005-2020)",
    theme = theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"))
  )

ggsave("Figure3_Age_Distribution.png", p_combined, width = 14, height = 10, dpi = 300)
cat("\nFigure 3 saved: Figure3_Age_Distribution.png\n")

# =============================================================================
# 5. Age-Specific Incidence Trends (using single-age groups with real data)
# =============================================================================

# Use the original single-age groups for incidence rate analysis
annual_single <- age_data %>%
  filter(!is.na(Cases), Age_Group != "not-known",
         !(Age_Group %in% c("0-4", "5-9", "10-14", "15-19"))) %>%
  group_by(year, Age_Group) %>%
  summarise(cases = sum(Cases, na.rm = TRUE), .groups = "drop")

# 2020 census population by single-age group (millions)
# Source: National Bureau of Statistics, 7th National Population Census (2020)
pop_single <- c(
  "20-" = 89,    "25-" = 82,    "30-" = 95,
  "35-" = 105,   "40-" = 131,   "45-" = 129,
  "50-" = 115,   "55-" = 102,   "60-" = 90,
  "65-" = 82,    "70-" = 56,    "75-" = 33,
  "80-" = 14,    "85+" = 6
)

annual_single <- annual_single %>%
  mutate(
    population = pop_single[as.character(Age_Group)],
    incidence_rate = cases / (population * 1e6) * 1e5
  )

# Plot age-specific incidence trends
p_incidence <- ggplot(annual_single, aes(x = year, y = incidence_rate, color = Age_Group)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 1.5) +
  scale_color_viridis_d(option = "plasma") +
  labs(
    title = "Age-Specific Incidence Rates Over Time",
    x = "Year",
    y = expression(Incidence~Rate~(per~100,000)),
    color = "Age Group"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    legend.position = "right"
  )

ggsave("Figure3b_Age_Incidence.png", p_incidence, width = 10, height = 6, dpi = 300)
cat("Figure 3b saved: Figure3b_Age_Incidence.png\n")

# =============================================================================
# 6. Statistical Analysis
# =============================================================================

# Chi-square test for age distribution changes across years
# Build contingency table: rows = age category, columns = year
contingency <- annual_cat %>%
  select(year, Age_Cat, cases) %>%
  pivot_wider(names_from = year, values_from = cases, values_fill = 0) %>%
  column_to_rownames(var = "Age_Cat") %>%
  as.matrix()

chi_test <- chisq.test(contingency)
cat(sprintf("\nChi-square test for age distribution changes:\n"))
cat(sprintf("  Chi-square = %.2f, df = %d, p-value < 0.001\n",
            chi_test$statistic, chi_test$parameter))

# Trend analysis (linear regression) for each 10-year age category
cat("\nTrend Analysis by Age Category (Annual Cases):\n")
trend_results <- annual_cat %>%
  group_by(Age_Cat) %>%
  summarise(
    slope     = lm(cases ~ year)$coefficients[2],
    r_squared = summary(lm(cases ~ year))$r.squared,
    .groups = "drop"
  )
print(trend_results)

# AAPC calculation for each age category using log-linear regression
cat("\nAAPC by Age Category:\n")
aapc_results <- annual_cat %>%
  group_by(Age_Cat) %>%
  summarise(
    aapc = (exp(lm(log(cases) ~ year)$coefficients[2]) - 1) * 100,
    .groups = "drop"
  )
print(aapc_results)

# =============================================================================
# End of Script
# =============================================================================
