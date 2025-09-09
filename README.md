# MEPS Severity Modeling in R — GLM + XGBoost

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
- **Utilization Totals**: `IPDIS20`, `OBTOTV20`, `OPTOTV20`, `HHTOTD20`, `ERTOT20`, `RXTOT20`
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

## Full Data Dictionary

### Targets
| Variable              | Type    | Role    | Notes / Levels |
|-----------------------|---------|---------|----------------|
| `TOTEXP20`            | numeric | target  | Annual total medical expenditures (USD); filtered to > 0 for this project. |
| `TOTEXP20_winsorized` | numeric | target  | `TOTEXP20` capped at the 99th percentile (p99) to reduce extreme-tail influence; used for model training/stability. |

### Demographics & Socioeconomic
| Variable   | Type    | Role    | Notes / Levels |
|------------|---------|---------|----------------|
| `AGELAST`  | numeric | feature | Age in years; adults only (> 17). |
| `SEX`      | factor  | feature | `Male`, `Female`. |
| `RACEV1X`  | factor  | feature | `White`, `Black`, `AI/AN`, `Asian`, `NH/PI`. |
| `FAMINC20` | numeric | feature | Family income (USD). |

### Insurance
| Variable   | Type   | Role    | Notes / Levels |
|------------|--------|---------|----------------|
| `INSCOV20` | factor | feature | Insurance status: `Any private`, `Public only`, `Uninsured`. |

### Lifestyle / Behavioral
| Variable   | Type   | Role    | Notes / Levels |
|------------|--------|---------|----------------|
| `OFTSMK53` | factor | feature | Smoking frequency: `Every day`, `Some days`, `Not at all`. |

### Anthropometrics
| Variable  | Type    | Role    | Notes / Levels |
|-----------|---------|---------|----------------|
| `ADBMI42` | numeric | feature | Body Mass Index (BMI). |

### Chronic Conditions (recoded to factors: `No`/`Yes`)
| Variable       | Type   | Role    | Notes / Levels |
|----------------|--------|---------|----------------|
| `CHDDX`        | factor | feature | Coronary heart disease: `No CHD`, `Yes CHD`. |
| `ASTHDX`       | factor | feature | Asthma: `No Asthma`, `Yes Asthma`. |
| `DIABDX_M18`   | factor | feature | Diabetes: `No Diabetes`, `Yes Diabetes`. |
| `HIBPDX`       | factor | feature | High blood pressure: `No HBP`, `Yes HBP`. |
| `MIDX`         | factor | feature | Myocardial infarction: `No MI`, `Yes MI`. |
| `EMPHDX`       | factor | feature | Emphysema: `No Emphysema`, `Yes Emphysema`. |
| `CANCERDX`     | factor | feature | Any cancer: `No Cancer`, `Yes Cancer`. |

### Utilization Totals (annual counts)
| Variable    | Type                | Role    | Notes / Levels |
|-------------|---------------------|---------|----------------|
| `IPDIS20`   | integer/numeric     | feature | Inpatient discharges. |
| `OBTOTV20`  | integer/numeric     | feature | Office-based visits. |
| `OPTOTV20`  | integer/numeric     | feature | Outpatient visits. |
| `HHTOTD20`  | integer/numeric     | feature | Home health days. |
| `ERTOT20`   | integer/numeric     | feature | Emergency room visits. |
| `RXTOT20`   | integer/numeric     | feature | Prescribed medicines. |

### Cancer Site Indicators (raw MEPS fields; used to build flags)
> Coding before recode: `1=Yes`, `2=No`, `-1=Unknown/Invalid`.  
> You **do not** model with these directly; you convert them to flags below.

`CACOLON`, `CALUNG`, `CALYMPH`, `CAMELANO`, `CAOTHER`, `CAPROSTA`, `CASKINDK`, `CASKINNM`, `CAUTERUS`, `CABLADDR`, `CABREAST`.

### Engineered Features
| Variable            | Type   | Role    | Notes / Levels |
|---------------------|--------|---------|----------------|
| `CACOLON_flag`      | binary | feature | From `CACOLON`: `1` yes, `0` no, `NA` unknown. |
| `CALUNG_flag`       | binary | feature | From `CALUNG`: `1` yes, `0` no, `NA` unknown. |
| `CALYMPH_flag`      | binary | feature | From `CALYMPH`: `1` yes, `0` no, `NA` unknown. |
| `CAMELANO_flag`     | binary | feature | From `CAMELANO`: `1` yes, `0` no, `NA` unknown. |
| `CAOTHER_flag`      | binary | feature | From `CAOTHER`: `1` yes, `0` no, `NA` unknown. |
| `CAPROSTA_flag`     | binary | feature | From `CAPROSTA`: `1` yes, `0` no, `NA` unknown. |
| `CASKINDK_flag`     | binary | feature | From `CASKINDK`: `1` yes, `0` no, `NA` unknown. |
| `CASKINNM_flag`     | binary | feature | From `CASKINNM`: `1` yes, `0` no, `NA` unknown. |
| `CAUTERUS_flag`     | binary | feature | From `CAUTERUS`: `1` yes, `0` no, `NA` unknown. |
| `CABLADDR_flag`     | binary | feature | From `CABLADDR`: `1` yes, `0` no, `NA` unknown. |
| `CABREAST_flag`     | binary | feature | From `CABREAST`: `1` yes, `0` no, `NA` unknown. |

### Encoding notes (for XGBoost)
- All factors above are **one-hot encoded** via `fastDummies::dummy_cols(..., remove_first_dummy=TRUE)` before XGBoost.
- The winsorized target is used for training; you additionally report a **corrected MAPE** against the original `TOTEXP20` for business interpretability.

