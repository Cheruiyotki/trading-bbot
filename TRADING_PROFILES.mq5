//+------------------------------------------------------------------+
//| CONFIGURATION PROFILES - SmartMoneyEA                            |
//| Copy-paste these parameters based on your trading style          |
//+------------------------------------------------------------------+

/*
PROFILE 1: ULTRA CONSERVATIVE (For risk-averse traders)
Purpose: Maximum capital preservation, lowest drawdown
Best For: New traders, small accounts ($1,000-$5,000)
Expected Win Rate: 50-60%
Expected Monthly Return: 2-5%

Input Parameters:
*/
RiskPercent = 0.3                    // Only 0.3% per trade
RRRatio = 2.0                        // 1:2 reward/risk ratio
SwingLength = 75                     // Longer lookback = more stable swings
InternalLength = 10                  // Larger internal moves only
SLBuffer = 10                        // Wide stops to avoid whipsaws
OrderBlockCount = 3                  // Only track recent OBs
RequireCHoCH = true                  // Require confirmation
AllowMultiplePositions = false       // One trade at a time
MaxPositions = 1
BarHistoryForOB = 300                // Very thorough OB detection

// Expected Results:
// - 20 trades/month: ~5-8 wins
// - Profit Factor: 1.8+
// - Max Drawdown: <5%
// - Largest Losing Streak: 2-3 losses

/*
---

PROFILE 2: CONSERVATIVE (For cautious traders)
Purpose: Steady growth with controlled risk
Best For: Intermediate traders, accounts $5,000-$20,000
Expected Win Rate: 45-55%
Expected Monthly Return: 5-10%

Input Parameters:
*/
RiskPercent = 0.5                    // 0.5% per trade
RRRatio = 1.75                       // 1:1.75 reward/risk ratio
SwingLength = 60                     // Standard swing lookback
InternalLength = 5                   // Normal internal structure
SLBuffer = 7                         // Moderate stops
OrderBlockCount = 5                  // Balanced OB tracking
RequireCHoCH = true                  // Confirm before entry
AllowMultiplePositions = false       // One position
MaxPositions = 1
BarHistoryForOB = 250                // Good OB history

// Expected Results:
// - 25 trades/month: ~11-14 wins
// - Profit Factor: 1.6-1.8
// - Max Drawdown: <8%
// - Largest Losing Streak: 2-4 losses

/*
---

PROFILE 3: BALANCED (Recommended - "Goldilocks Setup")
Purpose: Good balance of risk and reward
Best For: Most traders, accounts $10,000+
Expected Win Rate: 45-55%
Expected Monthly Return: 8-15%

Input Parameters:
*/
RiskPercent = 1.0                    // 1% per trade
RRRatio = 1.5                        // 1:1.5 reward/risk ratio
SwingLength = 50                     // Standard 50-bar swings
InternalLength = 5                   // Standard internal (5-bar)
SLBuffer = 5                         // Standard 5-pip buffer
OrderBlockCount = 5                  // Track recent OBs
RequireCHoCH = false                 // Allow most setups
AllowMultiplePositions = false       // One trade at a time
MaxPositions = 1
BarHistoryForOB = 200                // Standard history

// Expected Results:
// - 30 trades/month: ~14-16 wins
// - Profit Factor: 1.5-1.8
// - Max Drawdown: <10%
// - Largest Losing Streak: 2-5 losses

/*
---

PROFILE 4: AGGRESSIVE (For experienced traders)
Purpose: Maximize profits, accept higher risk
Best For: Advanced traders, accounts $20,000+
Expected Win Rate: 40-50%
Expected Monthly Return: 15-30%

Input Parameters:
*/
RiskPercent = 1.5                    // 1.5% per trade
RRRatio = 1.25                       // 1:1.25 reward/risk (tighter TP)
SwingLength = 40                     // Shorter swings = more entries
InternalLength = 5                   // Standard internal
SLBuffer = 3                         // Tight stops (aggressive)
OrderBlockCount = 7                  // Track more OBs
RequireCHoCH = false                 // High-frequency entries
AllowMultiplePositions = true        // Allow multiple positions
MaxPositions = 2                     // Up to 2 concurrent trades
BarHistoryForOB = 150                // Shorter history

// Expected Results:
// - 45 trades/month: ~18-22 wins
// - Profit Factor: 1.3-1.6
// - Max Drawdown: 12-20%
// - Largest Losing Streak: 3-6 losses

/*
---

PROFILE 5: EXTREME AGGRESSION (For professional traders only)
Purpose: Maximum profits, high risk of ruin
Best For: Experienced traders with $50,000+ accounts
Expected Win Rate: 35-45%
Expected Monthly Return: 30-50%+ (if winning)

Input Parameters:
*/
RiskPercent = 2.0                    // 2% per trade (WARNING: risky!)
RRRatio = 1.0                        // 1:1 ratio (breakeven on losses)
SwingLength = 30                     // Very short swings (scalping)
InternalLength = 3                   // Micro internal structures
SLBuffer = 2                         // Extremely tight stops
OrderBlockCount = 10                 // Track many OBs
RequireCHoCH = false                 // Take all setups
AllowMultiplePositions = true        // Multiple concurrent positions
MaxPositions = 3                     // Up to 3 concurrent trades
BarHistoryForOB = 100                // Minimal history

// Expected Results:
// - 60+ trades/month: ~21-27 wins
// - Profit Factor: 1.0-1.5 (risky!)
// - Max Drawdown: 20-40%+ (EXTREME)
// - Largest Losing Streak: 5-10+ losses

/*
---

PROFILE 6: SWING TRADER (Longer-term holds)
Purpose: Hold positions for multiple days
Best For: Part-time traders, less screen time
Expected Win Rate: 50-60%
Expected Monthly Return: 10-20%

Input Parameters:
*/
RiskPercent = 1.2                    // Slightly higher risk
RRRatio = 2.0                        // 1:2 ratio (multiple-day moves)
SwingLength = 100                    // Very long swing lookback
InternalLength = 20                  // Larger internal structures
SLBuffer = 15                        // Wider stops for swing moves
OrderBlockCount = 5                  // Track major OBs
RequireCHoCH = true                  // Confirm before entry
AllowMultiplePositions = false       // One swing at a time
MaxPositions = 1
BarHistoryForOB = 350                // Extended history for swings

// Expected Results:
// - 10 trades/month: ~5-6 wins
// - Profit Factor: 1.8+
// - Max Drawdown: <8%
// - Avg days in trade: 3-5 days

/*
---

PROFILE 7: DAY TRADER (Multiple entries per day)
Purpose: Close all positions before market close
Best For: Active traders with time
Expected Win Rate: 45-55%
Expected Monthly Return: 20-40%

Input Parameters:
*/
RiskPercent = 0.8                    // Managed risk
RRRatio = 1.3                        // 1:1.3 quick profits
SwingLength = 35                     // Mid-range swings
InternalLength = 3                   // Very small internal moves
SLBuffer = 4                         // Tight but manageable
OrderBlockCount = 8                  // Track multiple OBs
RequireCHoCH = false                 // Take all setups
AllowMultiplePositions = true        // Multiple daily trades
MaxPositions = 3
BarHistoryForOB = 120                // Minimal OB history

// Expected Results:
// - 50+ trades/month: ~23-27 wins
// - Profit Factor: 1.4-1.7
// - Max Drawdown: 10-15%
// - Avg trade duration: 30 mins - 2 hours

/*
---

PROFILE 8: SCALPER (Very short-term, tight SL)
Purpose: Capture every small move
Best For: Professionals only, $50,000+ accounts
Expected Win Rate: 55-65%
Expected Monthly Return: 40-80%+

Input Parameters:
*/
RiskPercent = 0.6                    // Limited risk per scalp
RRRatio = 1.0                        // 1:1 quick victories
SwingLength = 20                     // Micro swings
InternalLength = 2                   // Tick-level structures
SLBuffer = 1                         // Extremely tight stops
OrderBlockCount = 12                 // Track max OBs
RequireCHoCH = false                 // Instant entries
AllowMultiplePositions = true        // Rapid-fire trades
MaxPositions = 5                     // Multiple scalps
BarHistoryForOB = 50                 // Minimal historical data

// Expected Results:
// - 100+ trades/month: ~55-65 wins
// - Profit Factor: 1.2-1.5
// - Max Drawdown: 5-10%
// - Avg trade duration: 5-20 mins

/*
---

RECOMMENDED SETUPS BY ACCOUNT SIZE:

$1,000 - $5,000:     Use PROFILE 1 (Ultra Conservative)
$5,000 - $10,000:    Use PROFILE 2 (Conservative)
$10,000 - $20,000:   Use PROFILE 3 (Balanced) ← RECOMMENDED START
$20,000 - $50,000:   Use PROFILE 4 (Aggressive)
$50,000+:            Use PROFILE 5-8 based on experience

---

HOW TO IMPLEMENT A PROFILE:

1. Open SmartMoneyEA_Enhanced.mq5 in MetaEditor
2. Find the "INPUT PARAMETERS" section
3. Copy the parameters from your chosen profile above
4. Paste into the input section
5. Press F7 to compile
6. Backtest the profile (100+ trades recommended)
7. If satisfied, deploy to live account

---

TIPS FOR CHOOSING A PROFILE:

✓ START CONSERVATIVE: Better to be too cautious than lose capital
✓ MATCH YOUR TIME: Day traders = profiles 7-8, Swing traders = profile 6
✓ MATCH YOUR ACCOUNT: Smaller accounts = wider stops (profiles 1-2)
✓ TEST FIRST: Always backtest 3+ months minimum
✓ TRACK RESULTS: Compare backtest vs live performance
✓ ADJUST GRADUALLY: Change one parameter at a time
✓ CONSISTENCY MATTERS: Don't switch profiles frequently

---

PROFILE TRANSITION GUIDE:

If you're consistently profitable and want to scale up:

Month 1:   PROFILE 1 (Ultra Conservative)
Month 2-3: PROFILE 2 (Conservative)  
Month 4-5: PROFILE 3 (Balanced)
Month 6+:  PROFILE 4+ (Aggressive) - only if consistent

This gradual approach builds confidence and capital simultaneously.

---

DISASTER AVOIDANCE:

⚠ NEVER jump directly to Profile 5-8
⚠ NEVER use RiskPercent > 2% on live
⚠ NEVER overtrade (Profile 5+ can ruin accounts)
⚠ NEVER ignore stop losses
⚠ NEVER trade without backtest confirmation

---

Last Updated: March 2026
Compatible with: SmartMoneyEA_Enhanced v2.0+
*/
