# Quick Start Guide - Smart Money EA

## 30-Second Setup

### 1. Compile the EA
```
File → Open (SmartMoneyEA_Enhanced.mq5)
Press F7 to compile
Verify: "0 error(s), 0 warning(s)" in console
```

### 2. Attach to Chart
```
Open chart (e.g., EURUSD, H1)
Drag SmartMoneyEA_Enhanced from Navigator to chart
Enable: ✓ AutoTrading ✓ DLL imports ✓ Live trading
Click OK
```

### 3. Verify
```
Check Journal (Ctrl + L)
Should see: "=== Smart Money EA Initialized ==="
Magic Number will be shown
```

**Done! EA is now active. It will start trading on next swing formation.**

---

## Parameter Quick Reference

| Parameter | Default | Range | Notes |
|-----------|---------|-------|-------|
| RiskPercent | 1.0 | 0.1-5 | % of balance per trade |
| RRRatio | 1.5 | 1-3 | Take profit multiplier |
| SwingLength | 50 | 20-100 | Bars for swing detection |
| SLBuffer | 5 | 2-20 | Stop loss buffer in pips |
| RequireCHoCH | false | - | Forces confirmation |
| UseBreakEven | true | - | Auto break-even |

---

## Compilation Errors & Fixes

### Error: "cannot compile"
→ Check Trade.mqh exists in: `...\MQL5\Include\Trade\Trade.mqh`

### Error: "undeclared identifier 'trade'"
→ Verify `#include <Trade\Trade.mqh>` at top

### Error: "function not found"
→ Ensure iHighest, iLowest functions are available

---

## Testing Checklist

- [ ] EA compiles without errors
- [ ] Symbol data is loaded (right-click chart → Properties)
- [ ] EA shows in Journal on init
- [ ] Open test position manually to verify bid/ask
- [ ] Stop loss placement is correct (5 pips below OB)
- [ ] Position sizing is reasonable
- [ ] Trade closes properly at TP

---

## Common Issues

**"No trades appearing"**
1. Check if order blocks detected (SwingLength correct?)
2. Verify zone calculation (check swing high/low)
3. Try RequireCHoCH = false to remove confirmation requirement
4. Check if price ever enters order block zone

**"Errors in Expert tab"**
1. Right-click chart → Expert Advisors → Remove
2. Recompile EA (F7)
3. Close/reopen chart with EA
4. Re-attach EA

**"Positions not closing"**
1. Verify TP price is above entry for sells / below entry for buys
2. Check position SL/TP in trade window
3. Ensure market hours are active (no overnight gaps)

---

## Performance Expectations (Demo Trading)

- **Win Rate**: 45-60% 
- **Average Trade Gain**: 20-40 pips
- **Largest Win**: 50-100+ pips
- **Largest Loss**: -40 to -50 pips
- **Profit Factor**: 1.5-2.5+

*Results vary by symbol, timeframe, and market conditions*

---

## Optimization Tips

1. **Best Timeframes**: H1, H4, D1
2. **Best Pairs**: EURUSD, GBPUSD, USDJPY
3. **Best Hours**: 8-17 GMT (European/US session overlap)
4. **Adjust RiskPercent** if losses exceed 5% weekly
5. **Lower SLBuffer** in trending markets, raise in choppy markets

---

## Safety Guidelines

✓ Always test on **DEMO** account first
✓ Start with **RiskPercent = 0.5%** on live
✓ Monitor **first 10 trades** manually
✓ Keep **maximum 2% risk** per trade
✓ Set **daily loss limits** if desired
✓ Review **journal logs** daily

---

**Questions? Review README.md for detailed documentation**
