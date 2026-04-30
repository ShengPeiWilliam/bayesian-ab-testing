# Cookie Cats A/B Testing

[![Full Report](https://img.shields.io/badge/📄_Read_Full_Report-PDF-blue?style=for-the-badge)](report/cookiecats_report.pdf)

Bayesian and Frequentist A/B testing on 90K mobile game players, comparing 
gate placement at level 30 versus level 40 on retention.

Gate 30 yields higher 7-day retention with 99.92% posterior probability 
(95% CI: 0.31%–1.33%), but Cramér's V = 0.0105 flags the effect as 
practically negligible. The 1-day retention difference is inconclusive 
because most players have not yet reached the gate within the first day, 
showing why metric timing matters in A/B test design.

## Motivation

A/B testing is a foundational topic in experimentation, and the Cookie Cats 
dataset is a clean entry point: it combines both binary outcomes (retention) 
and a continuous metric (game rounds), making it well-suited for exploring 
the contrast between Frequentist hypothesis testing and Bayesian posterior 
inference.

This project also sets up the framework later extended in 
[Marketing A/B Testing](https://github.com/ShengPeiWilliam/marketing-ab-testing), 
where the same approach is applied to subgroup analysis on a larger 
imbalanced dataset.

## Design Decisions

**Why use both Frequentist and Bayesian?**

Frequentist testing answers whether a difference is statistically significant, 
but cannot quantify how probable that difference is. Bayesian posterior 
inference provides a direct probability, P(gate_30 > gate_40), and a credible 
interval for the magnitude of the effect, which is more actionable for 
business decisions.

**Why Mann-Whitney instead of t-test for game rounds?**

EDA revealed that `sum_gamerounds` is heavily right-skewed with extreme 
outliers (max = 49,854). Mann-Whitney is a non-parametric alternative that 
does not assume normality.

## Key Results

**Headline finding**: Gate 30 outperforms Gate 40 on 7-day retention (99.92% posterior probability, 95% CI: 0.31%–1.33%); 1-day retention shows no reliable difference because most players have not yet reached the gate.

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

The Bayesian framework unifies results across different metric types, binary 
and continuous, into the same interpretable format (posterior probability and 
credible interval), which Frequentist tests cannot do cleanly.

Effect sizes are negligible across all metrics. With 90,189 observations, 
the dataset is large enough to detect even tiny differences as statistically 
significant, even when those differences have no real business impact. This 
is a common pitfall in large-sample A/B tests: a significant p-value does 
not mean the effect is meaningful.

Next steps:
- **Longer observation window**: 14-day or 30-day retention metrics would better capture long-term engagement effects
- **Revenue metrics**: retention rate is a proxy; revenue per player or lifetime value would be more directly actionable
- **Negative binomial model**: `sum_gamerounds` shows overdispersion, making Gamma-Poisson a potentially misspecified model

## Repository

```
report/
  └── cookiecats_report.pdf       # Full analysis writeup
code/
  ├── cookiecats_analysis.ipynb   # Main analysis (R notebook)
  ├── cookiecats_analysis.R       # Clean R script
  └── config.R                    # Data path configuration
```

## Tools

**Statistical methods**: Chi-square, Mann-Whitney U, Beta-Binomial, Gamma-Poisson  
**Language**: R  
**Libraries**: tidyverse (dplyr, tidyr), ggplot2, rstatix

## References

Mobile Games (2024). Cookie Cats [Dataset]. Kaggle. 
https://www.kaggle.com/datasets/yufengsui/mobile-games-ab-testing