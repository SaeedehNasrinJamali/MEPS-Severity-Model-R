# scripts/04_evaluate.R  — GLM evaluation (high-contrast plots + extras)
suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(scales)
})

# --- Load data & model ---
dat <- readRDS("outputs/MEPS_clean.rds")
idx <- readRDS("outputs/split_idx.rds")
test <- dat[idx$test_idx, ]

glm_path <- "outputs/MEPS_glm_stepwise.rds"
model <- if (file.exists(glm_path)) readRDS(glm_path) else {
  if (exists("MEPS_simplified_model", inherits = TRUE)) MEPS_simplified_model
  else stop("No GLM model found. Run scripts/03_model.R first.")
}

# --- Predict on response scale (Gamma-log) ---
pred  <- as.numeric(predict(model, newdata = test, type = "response"))
y_w   <- as.numeric(test$TOTEXP20_winsorized)
y_org <- as.numeric(test$TOTEXP20)

df <- tibble(pred = pred, actual = y_w)

# --- Metrics ---
MAE  <- mean(abs(y_w - pred))
RMSE <- sqrt(mean((y_w - pred)^2))
R2   <- 1 - sum((y_w - pred)^2) / sum((y_w - mean(y_w))^2)
MAPE_wins <- mean(abs((y_w - pred) / y_w)) * 100
MAPE_orig <- mean(abs((y_org - pred) / y_org)) * 100

dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

write_csv(tibble(Model="GLM_Gamma_log",
                 MAE=MAE, RMSE=RMSE, R2=R2,
                 MAPE_winsorized_pct=MAPE_wins,
                 MAPE_original_pct=MAPE_orig),
          "outputs/test_metrics_glm.csv")

write_csv(tibble(pred_expend = pred,
                 actual_wins = y_w,
                 actual_orig = y_org,
                 residual = y_w - pred),
          "outputs/predictions_glm.csv")

nice <- theme_bw(base_size = 12)
labx <- scale_x_continuous(labels = comma)
laby <- scale_y_continuous(labels = comma)

title_main <- sprintf(
  "GLM (Gamma–log): Predicted vs Actual — R²=%.3f  RMSE=%s  MAE=%s",
  R2, comma(RMSE, accuracy = 1), comma(MAE, accuracy = 1)
)

# 1) Pred vs Actual (full)
p1 <- ggplot(df, aes(pred, actual)) +
  geom_point(alpha = 0.35, size = 1.2) +
  geom_abline(slope = 1, intercept = 0, linetype = 2) +
  labs(title = title_main, x = "Predicted", y = "Actual (winsorized)") +
  nice + labx + laby
ggsave("outputs/figures/glm_pred_vs_actual.png", p1, width = 7, height = 5, dpi = 150, bg = "white")

# 2) Zoom 0–10k
p2 <- p1 + coord_cartesian(xlim = c(0, 10000), ylim = c(0, 10000)) +
  labs(title = "GLM (Gamma–log): Predicted vs Actual — Zoom 0–10k")
ggsave("outputs/figures/glm_pred_vs_actual_zoom.png", p2, width = 7, height = 5, dpi = 150, bg = "white")

# 3) Log1p–Log1p view
p3 <- ggplot(df, aes(log1p(pred), log1p(actual))) +
  geom_point(alpha = 0.35, size = 1.2) +
  geom_abline(slope = 1, intercept = 0, linetype = 2) +
  labs(title = "GLM (Gamma–log): Predicted vs Actual (log1p scale)",
       x = "log1p(Predicted)", y = "log1p(Actual)") +
  nice
ggsave("outputs/figures/glm_pred_vs_actual_log.png", p3, width = 7, height = 5, dpi = 150, bg = "white")

# 4) Calibration by decile
df_cal <- df %>%
  mutate(decile = ntile(pred, 10)) %>%
  group_by(decile) %>%
  summarise(pred = mean(pred), actual = mean(actual), n = n(), .groups = "drop")

p4 <- ggplot(df_cal, aes(pred, actual, label = decile)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2) +
  geom_point(size = 2) +
  geom_text(vjust = -0.7, size = 3) +
  labs(title = "GLM Calibration: mean actual vs mean predicted by decile",
       x = "Mean predicted (decile)", y = "Mean actual (decile)") +
  nice + labx + laby
ggsave("outputs/figures/glm_calibration_deciles.png", p4, width = 7, height = 5, dpi = 150, bg = "white")

# 5) Residuals vs Fitted
resid <- y_w - pred
p5 <- ggplot(tibble(fitted = pred, resid = resid), aes(fitted, resid)) +
  geom_point(alpha = 0.35, size = 1.1) +
  geom_smooth(method = "loess", se = FALSE, linetype = 2) +
  labs(title = "GLM: Residuals vs Fitted", x = "Fitted (predicted)", y = "Residual (actual - pred)") +
  nice + labx + laby
ggsave("outputs/figures/glm_residuals_vs_fitted.png", p5, width = 7, height = 5, dpi = 150, bg = "white")

message("GLM evaluation complete. Metrics -> outputs/test_metrics_glm.csv | Plots -> outputs/figures/")
