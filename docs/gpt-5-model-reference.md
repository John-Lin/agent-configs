# GPT-5.5 and GPT-5.6 Model Reference

Last verified: 2026-07-17

This document summarizes OpenAI's published API pricing and benchmark results for
GPT-5.5 and the GPT-5.6 Sol, Terra, and Luna tiers. Prices are in USD per one
million tokens for the Standard API tier.

## Pricing

| Model | Input | Cached input / cache read | Output | Cache write |
|---|---:|---:|---:|---:|
| GPT-5.5 | $5.00 | $0.50 | $30.00 | Not separately listed |
| GPT-5.6 Sol | $5.00 | $0.50 | $30.00 | $6.25 calculated |
| GPT-5.6 Terra | $2.50 | $0.25 | $15.00 | $3.125 calculated |
| GPT-5.6 Luna | $1.00 | $0.10 | $6.00 | $1.25 calculated |

For GPT-5.6, OpenAI states that cache writes cost 1.25 times the uncached input
rate. The cache-write amounts above are calculated from that rule. GPT-5.5 does
not list a separate cache-write price, so the GPT-5.6 rule should not be assumed
to apply to it.

### Long-context pricing

For prompts over 272K input tokens, OpenAI charges twice the input rate and 1.5
times the output rate for the full request or session.

| Model | Input over 272K | Output over 272K |
|---|---:|---:|
| GPT-5.5 | $10.00 | $45.00 |
| GPT-5.6 Sol | $10.00 | $45.00 |
| GPT-5.6 Terra | $5.00 | $22.50 |
| GPT-5.6 Luna | $2.00 | $9.00 |

GPT-5.5 regional-processing endpoints also have a 10% uplift. Prices charged
through a gateway may differ from OpenAI's direct API prices.

## Published performance

The following results come from OpenAI's GPT-5.6 launch comparison. They are
vendor-reported benchmarks rather than independent measurements. Benchmark
scores are useful directionally, but they do not measure the cost of retries,
human correction, latency, or performance on a specific team's prompts.

| Benchmark | GPT-5.6 Sol | GPT-5.6 Terra | GPT-5.6 Luna | GPT-5.5 |
|---|---:|---:|---:|---:|
| GDPval-AA v2 (professional work, Elo) | 1,747.8 | 1,593.0 | 1,591.8 | 1,493.7 |
| SWE-Bench Pro (software engineering) | 64.6% | 63.4% | 62.7% | 59.4% |
| Terminal-Bench 2.1 (terminal tasks) | 88.8% | 87.4% | 84.7% | 85.6% |
| OSWorld 2.0 (computer use) | 62.6% | 50.2% | 45.6% | 47.5% |
| GPQA Diamond (expert knowledge) | 94.6% | 92.9% | 92.3% | 93.6% |
| MRCR v2, 8 needles, 256K-512K | 91.5% | 89.6% | 41.3% | 81.5% |
| MRCR v2, 8 needles, 512K-1M | 73.8% | 72.5% | 41.3% | 74.0% |

### Practical interpretation

- **GPT-5.6 Sol** has the highest score in six of the seven results above. It
  costs the same per token as GPT-5.5 and usually scores higher in this table,
  making it the first candidate to evaluate for difficult tasks at that price.
- **GPT-5.6 Terra** remains close to Sol on the listed coding and broad reasoning
  results at half the token price. It also beats GPT-5.5 on the listed
  professional-work, coding, terminal, and computer-use results.
- **GPT-5.6 Luna** has the lowest token price. Its weaker listed computer-use and
  long-context recall results make it a riskier candidate for complex agentic
  or long-context work. The cited benchmarks do not directly test routine
  summarization, extraction, classification, or drafting.
- **GPT-5.5** is difficult to justify from this price and benchmark table alone
  because Sol has the same standard token prices. Existing workflows may still
  favor it because these benchmarks do not establish workload-specific
  reliability or migration cost.

## Cost-performance recommendation

For general daily work, **GPT-5.6 Terra is the best default candidate to
validate for cost-performance**. It costs 50% less than Sol and GPT-5.5 while
remaining close to Sol on the listed coding and broad reasoning benchmarks.
Compared with GPT-5.5, it is both cheaper and stronger on most of the practical
benchmarks above.

The following routing policy is a starting hypothesis, not a conclusion proved
by the cited benchmarks:

| Workload | First model to evaluate | Reason |
|---|---|---|
| Email, rewriting, extraction, classification, short summaries | GPT-5.6 Luna | Lowest token price; validate output quality and correction rate |
| General research, documents, analysis, and normal coding | GPT-5.6 Terra | Strong listed results at half the Sol and GPT-5.5 token price |
| Difficult debugging, complex coding, computer use, and high-stakes analysis | GPT-5.6 Sol | Highest score on most of the listed benchmarks |
| Existing validated GPT-5.5 workflows | GPT-5.5 as a baseline | Compare before migration because benchmarks may not predict the workload |

Validate the policy with a small set of representative tasks and measure task
success, retries, human correction, latency, and total token use. Token price
alone can be misleading: a cheaper model loses its advantage if it requires
repeated retries or substantially more human correction.

## Sources

- [GPT-5.5 model documentation](https://developers.openai.com/api/docs/models/gpt-5.5)
- [GPT-5.6 Sol model documentation](https://developers.openai.com/api/docs/models/gpt-5.6-sol)
- [GPT-5.6 Terra model documentation](https://developers.openai.com/api/docs/models/gpt-5.6-terra)
- [GPT-5.6 Luna model documentation](https://developers.openai.com/api/docs/models/gpt-5.6-luna)
- [GPT-5.6 launch and benchmark comparison](https://openai.com/index/gpt-5-6/)
- [OpenAI GDPval methodology](https://openai.com/index/gdpval/)
