# scripts/07_xgboost_shap.R
# Creates SHAP summary plot for the best available XGBoost model
suppressPackageStartupMessages({
  library(dplyr)
  library(fastDummies)
  library(xgboost)
})

if (!requireNamespace("shap", quietly = TRUE)) {
  message("Package 'shap' not installed; skipping SHAP. (Optional) Install and re-run.")
} else {
  dat <- readRDS("outputs/MEPS_clean.rds")
  idx <- readRDS("outputs/split_idx.rds")

  # Re-create design matrix (same encoding)
  MEPS_dummy <- fastDummies::dummy_cols(
    dat,
    select_columns = c("SEX","INSCOV20","RACEV1X","OFTSMK53","CHDDX","ASTHDX",
                       "DIABDX_M18","HIBPDX","MIDX","EMPHDX","CANCERDX"),
    remove_first_dummy = TRUE,
    remove_selected_columns = TRUE
  )
  train <- MEPS_dummy[idx$train_idx, ]
  X_train <- dplyr::select(train, -TOTEXP20, -TOTEXP20_winsorized)

  # Prefer tuned model if present, else baseline
  model_path <- if (file.exists("outputs/models/xgb_tuned.rds")) {
    "outputs/models/xgb_tuned.rds"
  } else if (file.exists("outputs/models/xgb_baseline.rds")) {
    "outputs/models/xgb_baseline.rds"
  } else {
    NA_character_
  }

  if (is.na(model_path)) {
    message("No XGBoost model found for SHAP. Run 05/06 scripts first.")
  } else {
    model_obj <- readRDS(model_path)
    # caret::train stores booster at $finalModel
    booster <- if (!is.null(model_obj$finalModel)) model_obj$finalModel else model_obj

    dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

    shap_values <- shap::shap.values(
      xgb_model = booster,
      X_train   = as.matrix(X_train)
    )
    png("outputs/figures/xgb_shap_summary.png", width = 1100, height = 800)
    shap::shap.plot.summary.wrap1(shap_values$shap_score, as.matrix(X_train))
    dev.off()

    message("SHAP summary saved -> outputs/figures/xgb_shap_summary.png")
  }
}
