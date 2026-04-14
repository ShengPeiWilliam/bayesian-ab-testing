# Cookie Cats A/B Testing
Bayesian and Frequentist A/B testing on the Cookie Cats mobile game dataset. Compared gate placement at level 30 vs level 40 across 90,189 players, using Chi-square, Mann-Whitney U, Beta-Binomial, and Gamma-Poisson models. Gate 30 yields higher 7-day retention with 99.92% posterior probability.


## Motivation

After exploring continuous outcomes in [Bike Sharing Demand Forecasting](https://github.com/ShengPeiWilliam/bikerental-ml) and binary classification in [Customer Churn Prediction](https://github.com/ShengPeiWilliam/telecom-churn-ml), A/B testing felt like a natural next step. Cookie Cats is a beginner-friendly dataset that combines both binary and continuous metrics, and a good place to explore where Frequentist testing falls short and why Bayesian inference fills that gap.

## Design Decisions

**Why use both Frequentist and Bayesian?**

Frequentist testing answers whether a difference is statistically significant, but cannot quantify how probable that difference is. Bayesian posterior inference provides a direct probability, P(gate_30 > gate_40), and a credible interval for the magnitude of the effect, which is more actionable for business decisions.

**Why Mann-Whitney instead of t-test for game rounds?**

EDA revealed that `sum_gamerounds` is heavily right-skewed with extreme outliers (max = 49,854). Mann-Whitney is a non-parametric alternative that does not assume normality.

## Key Results

Gate 30 outperforms Gate 40 on 7-day retention with 99.92% posterior probability, with an estimated advantage of 0.31%–1.33%. The effect on 1-day retention is inconclusive, as most players have not yet reached the gate within the first day.

**Frequentist**

| Metric | p-value | Effect Size |
|--------|---------|-------------|
| retention_1 | 0.0755 | V = 0.0059 |
| retention_7 | 0.0016 | V = 0.0105 |
| sum_gamerounds | 0.0502 | r = -0.0075 |

**Bayesian**

| Metric | P(gate_30 > gate_40) | 95% CI |
|--------|----------------------|--------|
| retention_1 | 96.19% | [-0.0006, 0.0124] |
| retention_7 | 99.92% | [0.0031, 0.0133] |
| sum_gamerounds | 100.00% | [1.0631, 1.2519] |

## Reflections & Next Steps

The Bayesian framework unifies results across different metric types, binary and continuous, into the same interpretable format (posterior probability and credible interval), which Frequentist tests cannot do cleanly.

Effect sizes are negligible across all metrics. With 90,189 observations, the dataset is large enough to detect even tiny differences as statistically significant, even when those differences have no real business impact. This is a common pitfall in large-sample A/B tests: a significant p-value does not mean the effect is meaningful.

Next steps:
- **Longer observation window**: 14-day or 30-day retention metrics would better capture long-term engagement effects
- **Revenue metrics**: retention rate is a proxy; revenue per player or lifetime value would be more directly actionable
- **Negative binomial model**: `sum_gamerounds` shows overdispersion, making Gamma-Poisson a potentially misspecified model


## Repository

- `report/cookiecats_report.pdf`: Final report
- `code/cookiecats_analysis.ipynb`: Main analysis notebook
- `code/cookiecats_analysis.R`: Clean R script
- `code/config.R`: Configuration file (data paths)

## Tools

R · ggplot2 · tidyr · dplyr · rstatix

## References

Mobile Games (2024). Cookie Cats [Dataset]. Kaggle. https://www.kaggle.com/datasets/yufengsui/mobile-games-ab-testing