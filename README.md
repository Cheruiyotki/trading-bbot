# Smart Money Concepts Trading Bot

This repository contains Smart Money Concepts (SMC) automation for MetaTrader 5 in two forms:

- MQL5 Expert Advisors (`.mq5`) for direct MT5 deployment
- A Python multi-timeframe bot (`smc_mtf_bot.py`) that connects to MT5 via the MetaTrader5 Python package

Use demo accounts first and treat this repo as a framework you tune for your own risk profile.

## Repository Contents

- `SmartMoneyEA.mq5` - Base EA implementation
- `SmartMoneyEA_Enhanced.mq5` - Enhanced EA version (recommended for MT5 EA users)
- `smc_mtf_bot.py` - Python SMC bot (H4/H1/M15 logic, dry-run by default)
- `requirements-python.txt` - Python dependencies
- `QUICK_START.md` - Fast MT5 EA setup
- `TROUBLESHOOTING.md` - FAQ and troubleshooting
- `TRADING_PROFILES.mq5` - Parameter profile examples

## Quick Start

### Option A: MT5 Expert Advisor (.mq5)

1. Copy `SmartMoneyEA_Enhanced.mq5` to your MT5 Experts folder:
   - `...\MQL5\Experts\`
2. Open MetaEditor and compile (`F7`).
3. Attach EA to a chart and enable Algo Trading.
4. Start with conservative risk settings on demo.

For detailed EA setup, use `QUICK_START.md`.

### Option B: Python Bot (`smc_mtf_bot.py`)

1. Create and activate a virtual environment:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

2. Install dependencies:

```powershell
pip install -r requirements-python.txt
```

3. Run in dry-run mode (default, no live orders):

```powershell
python smc_mtf_bot.py --symbol EURUSD
```

4. Run live mode only after demo validation:

```powershell
python smc_mtf_bot.py --live --symbol EURUSD --risk 0.5 --max-spread 1.5
```

## Python Bot Strategy Summary

The Python bot uses closed candles only to reduce repainting:

- `H4`: Directional bias (structure/BOS context)
- `H1`: Order-block or premium/discount zone selection
- `M15`: Entry trigger (micro break / CHoCH-style confirmation)

Additional controls:

- Spread filter (`--max-spread`)
- One-position guard per magic number
- Break-even management (enabled by default)
- ATR trailing stop (enabled by default)
- Auto-reconnect handling for MT5 disconnects

## Python Bot CLI Options

Main options currently supported by `smc_mtf_bot.py`:

- `--symbol` (default `EURUSD`)
- `--risk` risk percent per trade (default `1.0`)
- `--rr` reward:risk multiplier (default `1.8`)
- `--sl-buffer-pips` stop buffer in pips (default `3.0`)
- `--max-spread` spread cap in pips (default `2.0`)
- `--magic` magic number (default `460015`)
- `--interval` loop interval in seconds (default `30`)
- `--live` enable live execution (off by default)
- `--login`, `--password`, `--server` optional MT5 login override
- `--no-break-even` disable break-even logic
- `--no-trailing` disable ATR trailing stop
- `--trail-start-r` trailing activation threshold in R (default `1.2`)
- `--trail-atr-mult` ATR multiplier for trailing (default `1.0`)
- `--log-level` (`DEBUG`, `INFO`, `WARNING`, `ERROR`)
- `--log-file` log output file (default `smc_mtf_bot.log`)

## MT5 + Python Prerequisites

- Windows environment with MetaTrader 5 desktop installed
- MT5 terminal running and logged in to your account
- Symbol visible in Market Watch (bot attempts auto-select)
- Python 3.10+ recommended

## Safety Notes

- Default mode is dry-run for safer testing.
- Start with low risk (`0.3%` to `0.5%`) while validating behavior.
- Validate spread, slippage, and broker execution constraints before going live.
- Never deploy untested settings directly to production capital.

## Documentation

- EA quick setup: `QUICK_START.md`
- Troubleshooting: `TROUBLESHOOTING.md`
- Parameter profile ideas: `TRADING_PROFILES.mq5`

## Disclaimer

This software is for educational and research purposes. Trading leveraged products carries substantial risk and can result in loss of capital. You are responsible for any live deployment decisions.

## Last Updated

March 24, 2026
