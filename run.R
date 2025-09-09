# run.R
source("scripts/01_setup.R")
source("scripts/02_clean.R")
source("scripts/03_model.R")
source("scripts/04_evaluate.R")

# Optional extras (run if the files exist)
if (file.exists("scripts/05_xgboost_baseline.R")) source("scripts/05_xgboost_baseline.R")
if (file.exists("scripts/06_xgboost_tuning.R"))  source("scripts/06_xgboost_tuning.R")
if (file.exists("scripts/07_xgboost_shap.R"))    source("scripts/07_xgboost_shap.R")

