# scripts/05_xgboost_baseline.R

suppressPackageStartupMessages({
  library(dplyr)
  library(fastDummies)
  library(xgboost)
  library(ggplot2)
  library(readr)
  library(scales)
})

# ---- Load cleaned data + split indexes ----
dat <- readRDS("outputs/MEPS_clean.rds")
idx <- readRDS("outputs/split_idx.rds")

# ---- One-hot encode factors (CANCERDX removed) ----
MEPS_dummy <- fastDummies::dummy_cols(
  dat,
  select_columns = c(
    "SEX","INSCOV20","RACEV1X","OFTSMK53",
    "CHDDX","ASTHDX","DIABDX_M18","HIBPDX","MIDX","EMPHDX"
  ),
  remove_first_dummy = TRUE,
  remove_selected_columns = TRUE
)

# ---- Split ----
train <- MEPS_dummy[idx$train_idx, ]
test  <- MEPS_dummy[idx$test_idx,  ]

# ---- X / y matrices ----
X_train <- dplyr::select(train, -TOTEXP20, -TOTEXP20_winsorized)
y_train <- train$TOTEXP20_winsorized
X_test  <- dplyr::select(test,  -TOTEXP20, -TOTEXP20_winsorized)
y_test  <- test$TOTEXP20_winsorized

# Safety: all numeric, no NA
stopifnot(!anyNA(y_train), !anyNA(y_test))
X_train <- dplyr::mutate(X_train, dplyr::across(dplyr::everything(), as.numeric))
X_test  <- dplyr::mutate(X_test,  dplyr::across(dplyr::everything(), as.numeric))

dtrain <- xgboost::xgb.DMatrix(as.matrix(X_train), label = y_train)
dtest  <- xgboost::xgb.DMatrix(as.matrix(X_test),  label = y_test)

# ---- Train baseline model (CV on TRAIN ONLY; no test in watchlist) ----
set.seed(123)
params <- list(
  objective = "reg:squarederror",
  eval_metric = "rmse",
  eta = 0.1,
  max_depth = 6,
  subsample = 0.8,
  colsample_bytree = 0.8
)

# Choose number of trees via k-fold CV on TRAIN
cv <- xgboost::xgb.cv(
  params = params,
  data = dtrain,
  nrounds = 5000,
  nfold = 5,
  early_stopping_rounds = 100,
  verbose = 0
)

best_nrounds <- if (!is.null(cv$best_iteration)) {
  cv$best_iteration
} else if (!is.null(cv$best_ntreelimit)) {
  cv$best_ntreelimit
} else {
  which.min(cv$evaluation_log$test_rmse_mean)
}

# Final model trained on full TRAIN set with selected nrounds
model_xgb <- xgboost::xgb.train(
  params = params,
  data = dtrain,
  nrounds = best_nrounds,
  verbose = 0
)

# ---- Predict (simple, no test leakage) ----
pred <- predict(model_xgb, dtest)

# ---- Metrics ----
MAE  <- mean(abs(y_test - pred))
RMSE <- sqrt(mean((y_test - pred)^2))
R2   <- 1 - sum((y_test - pred)^2) / sum((y_test - mean(y_test))^2)

# MAPE (winsorized) + corrected MAPE on original scale (safe division)
eps <- 1e-8
MAPE_wins <- mean(abs((y_test - pred) / (y_test + eps))) * 100
y_orig <- dat[idx$test_idx, ]$TOTEXP20
MAPE_orig <- mean(abs((y_orig - pred) / (y_orig + eps))) * 100

dir.create("outputs/models", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

readr::write_csv(
  data.frame(
    Model = "XGB_Baseline_TrainCV",
    Best_Trees = best_nrounds,
    MAE = MAE, RMSE = RMSE, R2 = R2,
    MAPE_winsorized_pct = MAPE_wins,
    MAPE_original_pct   = MAPE_orig
  ),
  "outputs/xgb_metrics_baseline.csv"
)
saveRDS(model_xgb, "outputs/models/xgb_baseline.rds")

# ---- Feature importance ----
imp <- xgboost::xgb.importance(feature_names = colnames(X_train), model = model_xgb)
readr::write_csv(imp, "outputs/xgb_importance_baseline.csv")

imp_top <- imp[1:min(10, nrow(imp)), ]
p_imp <- ggplot(imp_top, aes(x = reorder(Feature, Gain), y = Gain)) +
  geom_col() +
  coord_flip() +
  labs(title = "XGBoost Feature Importance (Top 10)", x = NULL, y = "Gain") +
  theme_minimal()

ggsave("outputs/figures/xgb_importance_top10_baseline.png",
       plot = p_imp, width = 7, height = 5, dpi = 150)

# ---- Pred vs Actual plot ----
p_scatter <- ggplot(data.frame(pred = pred, actual = y_test),
                    aes(x = pred, y = actual)) +
  geom_point(alpha = .5) +
  geom_abline(slope = 1, intercept = 0, linetype = 2) +
  labs(title = "Predicted vs Actual (XGBoost baseline, winsorized target)",
       x = "Predicted", y = "Actual (winsorized)") +
  theme_minimal()

ggsave("outputs/figures/xgb_pred_vs_actual_baseline.png",
       plot = p_scatter, width = 7, height = 5, dpi = 150)

message("Baseline XGBoost complete -> outputs/xgb_metrics_baseline.csv")
