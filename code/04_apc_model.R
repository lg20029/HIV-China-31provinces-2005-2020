#!/usr/bin/env Rscript
# =============================================================================
# R Script for Age-Period-Cohort (APC) Model Analysis
# Generates Figure 4: APC Model Results
#
# Method: Intrinsic Estimator (IE) via R's apc package (v2.0.0)
# Data:   National HIV/AIDS surveillance data, 31 provinces, 2005-2020
# =============================================================================

# --- Setup: Working Directory ---
setwd(dirname(sys.frame(1)$ofile))

# --- Install and load required packages ---
packages <- c("tidyverse", "readxl", "apc", "patchwork")
new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]
if (length(new_packages)) {
  install.packages(new_packages, repos = "https://cloud.r-project.org/")
}
invisible(lapply(packages, library, character.only = TRUE))

# =============================================================================
# Global Constants
# =============================================================================

# Midpoints of each age group (central age for each 5-year band).
# Order must exactly match broad_ages below.
MID_AGES <- c(22, 27, 32, 37, 42, 47, 52, 57, 62, 67, 72, 77, 82, 87)

# Small constant added to avoid zero cells (required for log-linear model)
EPSILON <- 0.5

# Color theme for plots
COLORS <- list(
  age    = "#2E86AB",
  period = "#E94F37",
  cohort = "#44AF69"
)

# =============================================================================
# Helper Functions
# =============================================================================

#' Check if file exists and is readable
check_file_exists <- function(path) {
  if (!file.exists(path)) {
    stop(paste0("File not found: ", normalizePath(path)))
  }
}

#' Validate matrix integrity
validate_matrix <- function(mat, name = "Matrix") {
  if (anyNA(mat)) warning(paste(name, "contains NA values. Smoothing may be needed."))
  if (any(is.infinite(mat))) stop(paste(name, "contains infinite values."))
}

#' Validate that the variance-covariance matrix aligns with the coefficient vector
validate_variance_alignment <- function(vcov, effects) {
  p <- ncol(vcov)
  stopifnot(
    "Variance matrix dimensions do not match coefficient vector length" =
      p == nrow(vcov) && p == length(effects)
  )
}

#' Center effects around zero for interpretability
center_effect <- function(x) {
  x - mean(x, na.rm = TRUE)
}

#' Extract effects by type prefix using names (more robust than positional indexing)
extract_effects_by_name <- function(coef_names, effects, vcov, prefix) {
  idx <- grep(paste0("^", prefix), coef_names)
  stopifnot("No coefficients found for prefix" = length(idx) > 0)
  list(
    values = effects[idx],
    se     = sqrt(diag(vcov))[idx],
    names  = coef_names[idx]
  )
}

# =============================================================================
# 1. Load and Prepare Data
# =============================================================================
cat("=== Step 1: Loading and preparing data ===\n")

check_file_exists("HIV_AIDS_Data_31_Provinces.xlsx")
raw_data <- read_excel("HIV_AIDS_Data_31_Provinces.xlsx")

# Single-year open-ended bands (20- to 85+), each spanning a 5-year age range)
broad_ages <- c(
  "20-", "25-", "30-", "35-", "40-", "45-",
  "50-", "55-", "60-", "65-", "70-", "75-",
  "80-", "85+"
)

age_data <- raw_data %>%
  filter(Age_Group %in% broad_ages) %>%
  mutate(
    Cases = as.numeric(Cases),
    year  = as.integer(substr(Date, 1, 4))
  ) %>%
  filter(!is.na(Cases))

# Aggregate to national annual totals
national_annual <- age_data %>%
  group_by(year, Age_Group) %>%
  summarise(Cases = sum(Cases), .groups = "drop")

cat(sprintf(
  "[Data] Years: %d-%d, Age groups: %d, Total cells: %d\n",
  min(national_annual$year), max(national_annual$year),
  n_distinct(national_annual$Age_Group), nrow(national_annual)
))

# =============================================================================
# 2. Build Age-Period Matrix for apc Package
# =============================================================================
cat("\n=== Step 2: Building Age-Period Matrix ===\n")

apc_ages    <- broad_ages
apc_periods <- 2005:2020

apc_matrix <- national_annual %>%
  filter(Age_Group %in% apc_ages, year %in% apc_periods) %>%
  select(Age_Group, year, Cases) %>%
  pivot_wider(names_from = year, values_from = Cases, values_fill = 0) %>%
  mutate(Age_Group = factor(Age_Group, levels = apc_ages)) %>%
  arrange(Age_Group) %>%
  column_to_rownames(var = "Age_Group") %>%
  as.matrix()

validate_matrix(apc_matrix, "APC Matrix")

# Log-linear models require positive values; add EPSILON to avoid zero cells
apc_matrix <- apc_matrix + EPSILON

write.csv(
  data.frame(Age_Group = rownames(apc_matrix), apc_matrix),
  "apc_data_matrix.csv",
  row.names = FALSE
)

cat(sprintf(
  "[Matrix] Dimensions: %d ages x %d periods\n",
  nrow(apc_matrix), ncol(apc_matrix)
))
cat(sprintf(
  "[Matrix] Total cases (with smoothing): %s\n",
  format(sum(apc_matrix), big.mark = ",")
))

# =============================================================================
# 3. Fit APC Model using Intrinsic Estimator (IE)
# =============================================================================
cat("\n=== Step 3: Fitting APC model with Intrinsic Estimator ===\n")

apc_fit <- tryCatch(
  {
    apc.fit(response = apc_matrix, model.design = "AP")
  },
  error = function(e) {
    stop("Model fitting failed: ", e$message, "\n",
         "Please check data integrity, matrix dimensions, or try a different model.design.")
  }
)

cat("> APC model fitted successfully.\n")

# =============================================================================
# 4. Extract Effects Using Named Indices (Robust)
# =============================================================================
cat("\n=== Step 4: Extracting Age/Period/Cohort Effects ===\n")

coef_names <- names(apc_fit$coefficients.effects)
vcov       <- apc_fit$coefficients.variance

# Validate variance matrix alignment
validate_variance_alignment(vcov, apc_fit$coefficients.effects)

# Extract three effect types by name prefix
age_ret    <- extract_effects_by_name(coef_names, apc_fit$coefficients.effects, vcov, "^A")
period_ret <- extract_effects_by_name(coef_names, apc_fit$coefficients.effects, vcov, "^P")
cohort_ret <- extract_effects_by_name(coef_names, apc_fit$coefficients.effects, vcov, "^C")

cat(sprintf(
  "[Effects] Age: %d, Period: %d, Cohort: %d\n",
  length(age_ret$values), length(period_ret$values), length(cohort_ret$values)
))

# =============================================================================
# 4a. Compute Cohort Birth Years (Diagonal Mean Method)
# ---
# In the APC matrix, each cell (i, j) corresponds to:
#   - Row i = age group age_group[i] (midpoint age MID_AGES[i])
#   - Column j = period period[j]
#   - Birth year = period[j] - MID_AGES[i] + 1
#
# All cells belonging to the same birth cohort lie on parallel diagonals:
#   j - i + 1 = const (cohort index k)
# We take the mean birth year across all valid cells on each diagonal
# as the representative birth year label for that cohort.
# =============================================================================

n_ages         <- nrow(apc_matrix)
n_per          <- ncol(apc_matrix)
n_coh          <- length(cohort_ret$values)
per_years_vec  <- as.integer(colnames(apc_matrix))

birth_years       <- numeric(n_coh)
cells_per_cohort   <- numeric(n_coh)

for (k in seq_len(n_coh)) {
  # Cohort k: all cells satisfying j - i + 1 = k
  i_vals <- seq_len(n_ages)
  j_vals <- k + i_vals - 1
  valid  <- j_vals >= 1 & j_vals <= n_per

  if (sum(valid) == 0) {
    birth_years[k] <- NA_real_
  } else {
    byears <- per_years_vec[j_vals[valid]] - MID_AGES[i_vals[valid]] + 1
    birth_years[k]     <- mean(byears)
    cells_per_cohort[k] <- sum(valid)
  }
}

cat(sprintf("[Cohort] Birth year range: %d - %d\n",
            min(birth_years, na.rm = TRUE), max(birth_years, na.rm = TRUE)))
cat(sprintf("[Cohort] Cells per cohort: min=%d, max=%d\n",
            min(cells_per_cohort), max(cells_per_cohort)))

# =============================================================================
# 4b. Assemble Effect Data Frames (centered)
# =============================================================================

age_df <- tibble(
  age_group = age_ret$names,
  mid_age   = MID_AGES,
  effect    = center_effect(age_ret$values),
  se        = age_ret$se
)

period_df <- tibble(
  period = as.integer(period_ret$names),
  effect = center_effect(period_ret$values),
  se     = period_ret$se
)

cohort_df <- tibble(
  cohort     = seq_len(n_coh),
  birth_year = birth_years,
  n_cells    = cells_per_cohort,
  effect     = center_effect(cohort_ret$values),
  se         = cohort_ret$se
)

# Save model object for reproducibility
saveRDS(apc_fit, "apc_model_fitted.rds")

# =============================================================================
# 5. Plotting Functions
# =============================================================================

plot_apc_component <- function(df, x_var, y_var, se_col, color,
                              title, xlabel, ylabel,
                              x_breaks = NULL, x_labels = NULL) {
  df <- df %>% mutate(se_95 = !!sym(se_col) * 1.96)

  p <- ggplot(df, aes(x = !!sym(x_var), y = !!sym(y_var))) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.7) +
    geom_line(linewidth = 1.2, color = color) +
    geom_point(size = 3, color = color) +
    geom_errorbar(
      aes(ymin = !!sym(y_var) - se_95, ymax = !!sym(y_var) + se_95),
      width = if (x_var == "period") 0.3 else if (x_var == "birth_year") 1.5 else 0.8,
      color = color, alpha = 0.5
    ) +
    labs(title = title, x = xlabel, y = ylabel) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title       = element_text(hjust = 0.5, face = "bold"),
      panel.grid.minor = element_blank()
    )

  if (!is.null(x_breaks)) {
    p <- p + scale_x_continuous(breaks = x_breaks, labels = x_labels)
  }

  return(p)
}

# (a) Age Effect
p_age <- plot_apc_component(
  age_df, "mid_age", "effect", "se", COLORS$age,
  "(a) Age Effect", "Age Group", "Effect (log relative risk)",
  x_breaks = age_df$mid_age, x_labels = age_df$age_group
) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9))

# (b) Period Effect
p_period <- plot_apc_component(
  period_df, "period", "effect", "se", COLORS$period,
  "(b) Period Effect", "Year", "Effect (log relative risk)"
) +
  scale_x_continuous(breaks = seq(2005, 2020, by = 2))

# (c) Cohort Effect
p_cohort <- plot_apc_component(
  cohort_df, "birth_year", "effect", "se", COLORS$cohort,
  "(c) Cohort Effect", "Birth Cohort Year", "Effect (log relative risk)"
)

# Save individual panels
ggsave("apc_age_effect.png",    p_age,    width = 8, height = 5, dpi = 300)
ggsave("apc_period_effect.png", p_period, width = 8, height = 5, dpi = 300)
ggsave("apc_cohort_effect.png", p_cohort, width = 8, height = 5, dpi = 300)

# Combine into Figure 4
p_combined <- p_age / p_period / p_cohort +
  plot_annotation(
    title    = "Figure 4: Age-Period-Cohort Model Results",
    subtitle = "Intrinsic Estimator (IE) method | National HIV/AIDS Surveillance, 2005-2020",
    theme    = theme(
      plot.title    = element_text(hjust = 0.5, size = 14, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5, size = 10, color = "gray40")
    )
  )

ggsave("Figure4_APC_Model.png", p_combined, width = 10, height = 12, dpi = 300)
cat("> Figure 4 saved to Figure4_APC_Model.png\n")

# =============================================================================
# 6. Model Diagnostics
# =============================================================================
cat("\n=== Step 5: Model Diagnostics ===\n")

# Deviance statistics
if (apc_fit$df.residual > 0) {
  dev_ratio <- apc_fit$deviance / apc_fit$df.residual
  cat(sprintf("[Deviance] Deviance/DF ratio: %.4f\n", dev_ratio))
  if (dev_ratio > 2) {
    cat("[Warning] Deviance/DF > 2 indicates possible overdispersion. Consider using a dispersion parameter.\n")
  }
} else {
  cat("[Deviance] Residual df <= 0 (saturated model). Deviance ratio not applicable.\n")
}

cat(sprintf("[Deviance] Deviance: %.4f, Residual df: %d\n",
            apc_fit$deviance, apc_fit$df.residual))

cat("\n--- APC Model Summary ---\n")
print(summary(apc_fit))

# =============================================================================
# 7. Key Findings (for comparison with paper)
# =============================================================================
cat("\n=== Step 6: Key Findings ===\n")

# (1) Peak age effect
peak_age_row   <- age_df$age_group[which.max(age_df$effect)]
peak_age_eff   <- max(age_df$effect)
cat(sprintf("> Peak age effect: %s (effect = %.3f)\n", peak_age_row, peak_age_eff))
cat("    Expected (paper): 30-34 age group\n\n")

# (2) Period effect: trend change around 2011
if (2011 %in% period_df$period) {
  idx_2011  <- which(period_df$period == 2011)
  pre_2011  <- mean(diff(period_df$effect[seq_len(idx_2011)]), na.rm = TRUE)
  post_2011 <- mean(diff(period_df$effect[seq(idx_2011, nrow(period_df))]), na.rm = TRUE)
  cat("> Period trend (2005-2020):\n")
  cat(sprintf("   Pre-2011 annual change:  %.4f\n", pre_2011))
  cat(sprintf("   Post-2011 annual change: %.4f\n", post_2011))
  cat("   Expected (paper): marked growth deceleration after 2011\n\n")
}

# (3) Cohort effect: peak in 1960-1970 birth cohorts
coh_focus <- cohort_df %>% filter(birth_year >= 1955 & birth_year <= 1975)
if (nrow(coh_focus) > 0) {
  peak_coh_year <- coh_focus$birth_year[which.max(coh_focus$effect)]
  peak_coh_eff <- max(coh_focus$effect)
  cat(sprintf("> Peak cohort effect: born ~%d (effect = %.3f)\n", peak_coh_year, peak_coh_eff))
  cat("   Expected (paper): elevated risk for 1960-1970 birth cohorts\n\n")
}

# (4) Post-1990 cohorts
post_1990 <- cohort_df %>% filter(birth_year >= 1990)
if (nrow(post_1990) > 0) {
  post_1990_mean <- mean(post_1990$effect, na.rm = TRUE)
  cat(sprintf("> Post-1990 cohort mean effect: %.3f\n", post_1990_mean))
  cat("   Expected (paper): comparatively lower risk for post-1990 cohorts\n\n")
}

# (5) Full cohort effect table (for reviewer reference)
cat("--- Full Cohort Effect Table ---\n")
print(cohort_df, n = Inf)

cat("\n> Script completed successfully.\n")
