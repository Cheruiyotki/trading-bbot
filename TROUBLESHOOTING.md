# FAQs & Troubleshooting Guide - Smart Money EA

## Frequently Asked Questions

### General Questions

**Q: Which EA version should I use?**
A: Use `SmartMoneyEA_Enhanced.mq5` for production trading. The basic version is for educational purposes.

**Q: Does the EA work on all symbols?**
A: Yes, it's symbol-agnostic. Works best on major pairs (EURUSD, GBPUSD, USDJPY) with tight spreads.

**Q: What timeframe should I use?**
A: Recommended: H1 (hourly) or H4 (4-hour). Avoid very small timeframes (M5, M15) due to noise.

**Q: Can I run multiple EAs on the same symbol?**
A: Use different magic numbers to avoid conflicts. Recommended: Set MagicBase to unique values (10000, 20000, etc.)

**Q: Does EA include news filtering?**
A: No. Current version trades through all events. Add your own filters if needed.

---

### Trading Logic Questions

**Q: How does the EA detect order blocks?**
A: 
1. Identifies swing highs/lows over SwingLength bars
2. On new swing, creates order block from extreme point
3. Tracks order block until price closes beyond it (mitigation)

**Q: What's the difference between BOS and CHoCH?**
A: 
- BOS (Break of Structure): Price closes beyond swing level
- CHoCH (Change of Character): BOS with reversed trend direction

**Q: Why are no trades being placed?**
A: Check:
1. Is price in discount zone (buy) or premium zone (sell)?
2. Has CHoCH occurred? (if RequireCHoCH = true)
3. Is price touching an order block?
4. Are swing highs/lows being calculated? (check SwingLength)

**Q: How does break-even work?**
A: When price gains 1:1 risk-reward, SL automatically moves to entry price. This locks breakeven.

**Q: Can I disable break-even?**
A: Yes, set `UseBreakEven = false` in inputs.

---

### Risk Management Questions

**Q: What's the optimal Risk Percentage?**
A: 
- Beginners: 0.3-0.5%
- Intermediate: 1-1.5%
- Professionals: 2%+ (advanced risk management)

**Q: How is position size calculated?**
A: `Position Size = (Risk % × Account Balance) / (SL-to-Entry Distance in points)`

**Q: What if position size exceeds account limits?**
A: EA automatically normalizes to broker's min/max volumes.

**Q: Can I have a max daily/monthly loss limit?**
A: Not built-in. Add manually with equity stops if needed.

**Q: What's a healthy Risk-to-Reward ratio?**
A: Minimum 1:1, recommended 1:1.5+, ideal 1:2.

---

## Troubleshooting Guide

### Compilation Issues

#### Problem: "Cannot find Trade.mqh"
**Error Message**: `'Trade.mqh' — file not found`

**Solutions**:
1. Verify MT5 installation (should include Trade.mqh)
2. Check file path: `...\MQL5\Include\Trade\Trade.mqh`
3. If missing: Copy from another MT5 installation
4. Restart MetaEditor and try again

#### Problem: "Syntax error at line X"
**Error Message**: `Invalid syntax at line 123`

**Solutions**:
1. Check for unmatched brackets: { } [ ] ( )
2. Verify quote marks are straight: " (not " ")
3. Check for missing semicolons at line end
4. Look for unexpected characters after line

#### Problem: "Function not found: iHighest"
**Error Message**: `Undeclared identifier 'iHighest'`

**Solutions**:
1. This shouldn't happen in MT5 (built-in function)
2. Check compiler mode is MQL5 (not MQL4)
3. Verify MT5 build is recent (build 3000+)
4. Try restarting MT5

---

### Runtime Issues

#### Problem: EA initializes but no icon appears on chart
**Possible Causes**:
- EA attached to wrong chart
- Symbol not selected correctly
- AutoTrading not enabled

**Solutions**:
1. Right-click chart → Expert Advisors → Detach
2. Re-attach EA from Navigator
3. Double-check AutoTrading is checked (✓)
4. Verify chart symbol matches account

#### Problem: "2016 Modify SL/TP" errors in Journal
**Meaning**: Cannot modify position stops

**Solutions**:
1. Check stop distance minimum (broker requirement)
2. SL must be >2 pips from entry
3. For sell, SL must be ABOVE entry (not below)
4. Try modifying with larger SL distance

**Example Fix**:
```
// Instead of SL 2 pips away:
double stopLoss = entryPrice - 0.0001;  // Too close!

// Use proper distance:
double stopLoss = entryPrice - (5 * _Point);  // 5 pips distance
```

#### Problem: Orders placed at wrong prices (slippage)
**Causes**:
- Market gaps during news
- Wide broker spreads
- Market volatility
- Pending order execution delay

**Solutions**:
1. Use pending orders with wider distances
2. Trade during stable market hours
3. Check broker spread (ask when lowest)
4. Consider using market orders during high volatility

---

### Trade Execution Issues

#### Problem: "No trades for days"
**Diagnosis Steps**:
1. Check if order blocks being created:
   - Add `Print("OB Count: ", ArraySize(bullishOBs));` 
2. Check if price touching OB:
   - Print price, OB high, OB low
3. Check zone calculation:
   - Print(`"Discount: ", DiscountZoneTop, " to ", DiscountZoneBottom`);
4. Check CHoCH status (if required)

**Common Causes**:
- SwingLength too long (misses swings)
- Zones calculated incorrectly
- CHoCH requirement impossible to meet
- Order blocks mitigated too quickly

**Fixes**:
- Reduce SwingLength to 30-40
- Set RequireCHoCH = false to test
- Increase SLBuffer or BarHistoryForOB

#### Problem: "Trades instantly closed at stop loss"
**Possible Causes**:
1. SL placed incorrectly
2. Extreme slippage/gaps
3. OB detection error
4. Bid-ask spread larger than SL

**Verification**:
1. Manually place order at same price
2. Check SL placement is 5+ pips away
3. Review chart bar at entry time
4. Check broker spread

**Fix**:
- Increase SLBuffer (e.g., 5 → 10)
- Check OB formation timing
- Try different symbol/timeframe

#### Problem: "Take profit never hit; price reverses before TP"
**Analysis**:
- RR Ratio too aggressive (1:1.5 is better than 1:1)
- Trading at wrong times (lower volatility = fewer moves)
- Wrong structure detection

**Solutions**:
1. Increase RRRatio to 2.0 for longer trades
2. Add trend filter (only buy in uptrend, sell in downtrend)
3. Verify swing detection is correct
4. Check if TP price is reasonable for market move

---

### Performance Issues

#### Problem: EA lags chart / slow execution
**Causes**:
- Too many order blocks tracked
- History array size too large
- Complex calculations every tick

**Solutions**:
1. Reduce OrderBlockCount (5-10 maximum)
2. Reduce BarHistoryForOB (100-200 enough)
3. Close unnecessary charts
4. Check CPU usage (right-click taskbar → Task Manager)

#### Problem: High memory usage
**Causes**:
- Historical data not cleaned
- Arrays growing unbounded
- Old order blocks not removed

**Solutions**:
1. Ensure PruneOrderBlocks() function works
2. Check ArrayResize operations
3. Restart MT5 if memory accumulates
4. Monitor Journal for memory warnings

---

### Demo vs Live Issues

#### Problem: "Works in backtest but not in live"
**Common Reasons**:
1. **Market hasn't formed same structure** - backtest had specific conditions
2. **Slippage differences** - live has real slippage vs backtest estimates
3. **Spread differences** - live spread > backtest spread
4. **Time-of-day differences** - backtest may miss session changes
5. **Different liquidity** - live market conditions vary

**Verification**:
1. Run backtest on same period as live trading
2. Include real spread in backtest settings
3. Check if structure formation same condition
4. Verify risk parameters identical

**Solutions**:
1. Use conservative risk (0.5-1%) on live
2. Test 1-2 weeks on demo after backtest
3. Monitor Journal logs closely
4. Compare live vs backtest P&L weekly

#### Problem: "EA works on demo but I'm losing on live"
**Likely Causes**:
- Psychological: Trading different size increases stress
- Execution: Real slippage affects tight SL trades
- Time: Different trading hours = different conditions
- Leverage: Live using different leverage than demo

**Solutions**:
1. Use email/SMS alerts to remove emotion
2. Increase SLBuffer on live (2 pips difference important)
3. Start with 0.5% risk instead of 1%
4. Trade same hours consistently

---

### Data & Symbol Issues

#### Problem: "Strategy Tester shows different results on same data"
**Causes**:
- Different spread settings
- Point value miscalculation
- Tick data incomplete
- Calculator precision issues

**Solutions**:
1. Check point value: Right-click symbol → Properties
2. Verify spread: Bid-Ask difference should be realistic
3. Use "Open Prices Only" for consistent testing
4. Ensure 4-5 decimal digit pricing (EURUSD)

#### Problem: "Trade calculations wrong (SL/TP prices incorrect)"
**Verify**:
```
Entry: 1.1000
Risk: 50 pips
SL: Entry - 50*0.0001 = 1.0995 ✓ Correct
TP: Entry + (50*1.5)*0.0001 = 1.1075 ✓ Correct
```

**If Wrong**:
- Check _Point value (0.0001 for EURUSD, 0.01 for USDJPY)
- Verify multiplication by 0.0001 or _Point
- Check for rounding errors

---

### Output & Logging Issues

#### Problem: "No messages in Journal"
**Causes**:
1. EA not attached
2. Print() statements not working
3. Journal tab not visible

**Solutions**:
1. Verify EA running (icon on chart corner)
2. Check Journal is visible (View → Experts → View)
3. Filter shows this EA's output
4. Try logging to file instead

**Alternative Logging**:
```
// File logging if Print() not working:
int file_handle = FileOpen("SmartMoneyLog.txt", FILE_WRITE|FILE_TXT);
FileWrite(file_handle, "Trade opened: ", entry_price);
FileClose(file_handle);
```

#### Problem: "Debug information not showing"
**Add Debug Logging**:
```
// In OnTick() or functions needing debugging:
Print("=== DEBUG ===");
Print("SwingHigh: ", structure.lastSwingHigh.level);
Print("SwingLow: ", structure.lastSwingLow.level);
Print("DiscountZone: ", structure.discountZoneTop, "-", structure.discountZoneBottom);
Print("BullishOBCount: ", ArraySize(bullishOBs));
Print("=============");
```

---

### Chart & Visualization Issues

#### Problem: "Can't manually verify positions on chart"
**Solution**: Add Visual Indicators:
1. Use Gann High-Low indicator to see swing points
2. Manually draw zones based on EA calculations
3. Compare with order block structures
4. Verify prices match Journal reports

#### Problem: "Need to see order blocks visually"
**Solution Options**:
1. Use the LuxAlgo indicator alongside EA for visual confirmation
2. Enable Alert sounds when trades placed
3. Use email/SMS notifications
4. Export trades to spreadsheet for analysis

---

## Advanced Troubleshooting

### Enabling Debug Mode
```mq5
// Add near top of EA (after #property declarations)
#define DEBUG_MODE 1

// Then use in functions:
#ifdef DEBUG_MODE
    Print("DEBUG: Current trend = ", structure.currentTrend);
    Print("DEBUG: OB array size = ", ArraySize(bullishOBs));
#endif
```

### Testing Individual Functions
```mq5
// In OnTick() during testing
void OnTick() {
    // Test swing detection only:
    UpdateMarketStructure();
    Print("Swing High: ", structure.lastSwingHigh.level);
    Print("Swing Low: ", structure.lastSwingLow.level);
    
    // Don't execute actual trades during testing
    return;
}
```

### Comparing Expected vs Actual
```mq5
double expectedSL = entry - (50 * _Point);
double actualSL = PositionGetDouble(POSITION_SL);

if(MathAbs(expectedSL - actualSL) > 0.0001) {
    Print("WARNING: SL mismatch!");
    Print("Expected: ", expectedSL, " Actual: ", actualSL);
}
```

---

## Getting Help

### Information to Provide
When reporting issues:
1. **Exact error message** from Journal
2. **Symbol and timeframe** used
3. **Input parameters** being tested
4. **Journal logs** showing problem
5. **Screenshot** of chart when issue occurred
6. **Backtest results** if applicable
7. **MT5 version** (View → About)

### Where to Find Logs
- Journal: View → Experts → View → Journal (or Ctrl+L)
- Terminal Log: View → General → Log
- Export: Right-click Journal → Save → .txt file

---

## Performance Optimization

### If EA Running Slow

1. **Reduce data lookback**:
   - BarHistoryForOB: 200 → 100

2. **Limit OB tracking**:
   - OrderBlockCount: 10 → 5

3. **Close extra windows**:
   - Only 1-2 charts open
   - Disable volume profile, market profile

4. **Upgrade hardware**:
   - Use SSD not HDD
   - More RAM helps
   - Dedicated trading PC better

---

**Still having issues? Review README.md for complete documentation or test on smaller timeframe with conservative parameters first.**
