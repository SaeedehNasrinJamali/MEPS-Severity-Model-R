# MEPS Severity Modeling in R, GLM + XGBoost

This is an end-to-end R project that cleans MEPS data, engineers features, builds a **Gamma GLM (log link)** as a classic actuarial baseline, and adds a **tree-based XGBoost** model as a non-linear benchmark. The repository includes data cleaning, winsorization, train/test evaluation, model diagnostics, hyperparameter tuning, and interpretability.

## Why this project?
It demonstrates a professional actuarial/pricing workflow for analyzing health expenditures, including:
- Careful preprocessing
- Transparent GLM modeling
- A modern ML baseline (XGBoost)
- Held-out evaluation
- SHAP-style interpretation (It will be added)

## Project Goal & Data Source
The goal is to build a predictive model for annual medical expenditures. The data comes from the **Medical Expenditure Panel Survey (MEPS)**, a publicly available survey of healthcare utilization and expenses in the United States.  

---

## Data Explanation

### Cohort & Target
- **Cohort**: Adults (`AGELAST > 17`) with **positive** annual expenditures (`TOTEXP20 > 0`) in MEPS 2020.
- **Target variables**:
  - `TOTEXP20`: total annual medical expenditures (USD).
  - `TOTEXP20_winsorized`: `TOTEXP20` capped at the 99th percentile to reduce extreme-tail influence (used for model training).

> **Why winsorize?** Expenditures are highly right-skewed; capping the top 1% stabilizes fitting and makes MAE/RMSE less dominated by rare extremes. 
For interpretability, we also report metrics against the original `TOTEXP20` where relevant.

### Feature Categories
- **Demographics & Socioeconomic**: `AGELAST`, `SEX`, `RACEV1X`, `FAMINC20`
- **Insurance**: `INSCOV20` (Any private / Public only / Uninsured)
- **Lifestyle**: `OFTSMK53` (smoking frequency)
- **Anthropometrics**: `ADBMI42` (BMI)
- **Chronic Conditions** (binary factors): `CHDDX`, `ASTHDX`, `DIABDX_M18`, `HIBPDX`, `MIDX`, `EMPHDX`, `CANCERDX`
- **Cancer Sites (raw)**: `CACOLON`, `CALUNG`, `CALYMPH`, `CAMELANO`, `CAOTHER`, `CAPROSTA`, `CASKINDK`, `CASKINNM`, `CAUTERUS`, `CABLADDR`, `CABREAST`
- **Engineered Flags**: `*_flag` created from each `CA*` site (`1` present, `0` absent, `NA` unknown)

### Cleaning & Encoding
- **Invalid codes → `NA`**: MEPS “not ascertained/refused/don’t know” negatives (e.g., `-1`, `-7`, `-8`, `-15`) are set to `NA`.
- **Complete cases**: rows with remaining `NA` are dropped (baseline approach).
- **Factor labeling**: categorical fields converted to factors with human-readable labels.
- **XGBoost**: categorical variables are one-hot encoded (`fastDummies::dummy_cols(..., remove_first_dummy=TRUE)`).

### Train/Test Protocol & Metrics
- **Split**: 70/30 hold-out with `set.seed(123)`.
- **GLM**: Gamma family with **log** link; predictions via `type = "response"`.
- **XGBoost**: `reg:squarederror`; baseline + tuned (grid/random search) and a log-target variant with early stopping.
- **Metrics**: MAE, RMSE, and R² on the test set; MAPE on winsorized **and** a **corrected MAPE** on original `TOTEXP20`.
### Encoding notes (for XGBoost)
- All factors above are **one-hot encoded** via `fastDummies::dummy_cols(..., remove_first_dummy=TRUE)` before XGBoost.
- The winsorized target is used for training; you additionally report a **corrected MAPE** against the original `TOTEXP20` for business interpretability.
### XGBoost Results

![Predicted vs Actual](docs/xgb_pred_vs_actual_baseline.png)






