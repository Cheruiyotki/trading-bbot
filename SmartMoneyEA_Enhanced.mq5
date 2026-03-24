//+------------------------------------------------------------------+
//| Smart Money Concepts EA - Enhanced Version                       |
//| Advanced Order Block Detection & Zone Analysis                   |
//| Features: Dynamic zones, CHOCH detection, position management    |
//+------------------------------------------------------------------+
#property copyright "Smart Money Concepts - Enhanced"
#property link      "https://www.mql5.com"
#property version   "2.0"
#property strict
#property description "Enhanced SMC EA with advanced order block trading"

#include <Trade\Trade.mqh>

//--- Constants
#define BULLISH 1
#define BEARISH -1
#define BULLISH_LEG 1
#define BEARISH_LEG 0
#define MAX_ORDER_BLOCKS 10
#define MAX_OPEN_TRADES 5

//--- Enums
enum PriceAction {
    PRICE_IN_OB,
    PRICE_ABOVE_OB,
    PRICE_BELOW_OB,
    PRICE_NOT_TOUCHING
};

//--- Structure for Order Block
struct OrderBlock {
    double high;
    double low;
    double midpoint;
    datetime formationTime;
    int formationBar;
    int bias;           // BULLISH or BEARISH
    bool active;
    bool triggerFired;
};

//--- Structure for Swing Point
struct SwingPoint {
    double level;
    datetime barTime;
    int barIndex;
    int leg;
    bool confirmed;
};

//--- Structure for Market Structure
struct MarketStructure {
    SwingPoint lastSwingHigh;
    SwingPoint lastSwingLow;
    double premiumZoneTop;
    double premiumZoneBottom;
    double discountZoneTop;
    double discountZoneBottom;
    double equilibrium;
    int currentTrend;
    bool chochDetected;
};

//--- Structure for Trade Data
struct TradeData {
    ulong ticket;
    double entryPrice;
    double initialSL;
    double initialTP;
    double riskAmount;
    datetime entryTime;
    int orderBlockIndex;
    bool breakEvenMoved;
    bool profitProtected;
};

//+--INPUT PARAMETERS+
input double         RiskPercent = 1.0;
input int            SwingLength = 50;
input int            InternalLength = 5;
input double         RRRatio = 1.5;
input int            SLBuffer = 5;
input int            OrderBlockCount = 5;
input bool           UseBreakEven = true;
input bool           RequireCHoCH = false;
input double         CHoCHThreshold = 0.1;
input bool           AllowMultiplePositions = false;
input int            MaxPositions = 1;
input int            BarHistoryForOB = 200;
input string         CommentPrefix = "SMC_EA";
input int            MagicBase = 200000;

//+--GLOBAL VARIABLES+
CTrade                trade;
MarketStructure       structure;
OrderBlock            bullishOBs[];
OrderBlock            bearishOBs[];
TradeData             activeTrades[];
datetime              lastBarTime = 0;
int                   currentBarIndex = 0;
int                   tradeMagicNumber = 0;
double                lastSwingHighLevel = 0;
double                lastSwingLowLevel = 0;
int                   barsSinceSwingHigh = 0;
int                   barsSinceSwingLow = 0;

//+--STATISTICS+
int                   totalTradesOpened = 0;
int                   totalWins = 0;
int                   totalLosses = 0;
double                grossProfit = 0;
double                grossLoss = 0;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                            |
//+------------------------------------------------------------------+
int OnInit() {
    // Initialize magic number
    tradeMagicNumber = MagicBase + (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) * 10;
    
    // Verify platform connection
    if (!SymbolSelect(_Symbol, true)) {
        Print("ERROR: Cannot select symbol ", _Symbol);
        return INIT_FAILED;
    }
    
    // Initialize trade object
    trade.SetExpertMagicNumber(tradeMagicNumber);
    
    // Initialize structures
    ArrayResize(bullishOBs, 0);
    ArrayResize(bearishOBs, 0);
    ArrayResize(activeTrades, 0);
    
    // Initialize market structure
    structure.lastSwingHigh.level = iHigh(_Symbol, PERIOD_CURRENT, 0);
    structure.lastSwingLow.level = iLow(_Symbol, PERIOD_CURRENT, 0);
    structure.currentTrend = BULLISH;
    structure.chochDetected = false;
    
    Print("=== Smart Money EA Initialized ===");
    Print("Symbol: ", _Symbol);
    Print("Magic Number: ", tradeMagicNumber);
    Print("Risk per trade: ", RiskPercent, "%");
    Print("RR Ratio: ", RRRatio, ":1");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("\n=== Smart Money EA Statistics ===");
    Print("Total trades opened: ", totalTradesOpened);
    Print("Winning trades: ", totalWins);
    Print("Losing trades: ", totalLosses);
    Print("Gross profit: ", grossProfit);
    Print("Gross loss: ", grossLoss);
    Print("Win rate: ", totalTradesOpened > 0 ? (totalWins*100.0/totalTradesOpened) : 0, "%");
    Print("Open positions: ", ArraySize(activeTrades));
    Print("EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| MAIN TICK FUNCTION                                               |
//+------------------------------------------------------------------+
void OnTick() {
    // Process only on new bar
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (currentBarTime == lastBarTime) return;
    
    lastBarTime = currentBarTime;
    currentBarIndex = (int)iBarShift(_Symbol, PERIOD_CURRENT, currentBarTime);
    
    // Update market structure and detect swings
    UpdateMarketStructure();
    
    // Detect and store order blocks
    DetectOrderBlocks();
    
    // Update premium/discount zones
    CalculateZones();
    
    // Manage existing positions
    ManagePositions();
    
    // Update closed trades statistics
    UpdateClosedTradesStats();
    
    // Check entry conditions
    EvaluateEntrySignals();
}

//+------------------------------------------------------------------+
//| UPDATE MARKET STRUCTURE - Detect swings using highest/lowest     |
//+------------------------------------------------------------------+
void UpdateMarketStructure() {
    // Get swing highs and lows
    int highestBar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, SwingLength, 1);
    int lowestBar = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, SwingLength, 1);
    
    double swingHigh = iHigh(_Symbol, PERIOD_CURRENT, highestBar);
    double swingLow = iLow(_Symbol, PERIOD_CURRENT, lowestBar);
    
    // Detect swing high
    if (swingHigh > structure.lastSwingHigh.level) {
        // New swing high formed
        if (structure.lastSwingHigh.level > 0 && structure.currentTrend == BEARISH) {
            structure.chochDetected = true; // CHoCH on timeframe
        }
        
        structure.lastSwingHigh.level = swingHigh;
        structure.lastSwingHigh.barTime = iTime(_Symbol, PERIOD_CURRENT, highestBar);
        structure.lastSwingHigh.barIndex = highestBar;
        structure.lastSwingHigh.confirmed = true;
        structure.currentTrend = BEARISH;
        
        barsSinceSwingHigh = 0;
    } else {
        barsSinceSwingHigh++;
    }
    
    // Detect swing low
    if (swingLow < structure.lastSwingLow.level) {
        // New swing low formed
        if (structure.lastSwingLow.level > 0 && structure.currentTrend == BULLISH) {
            structure.chochDetected = true; // CHoCH on timeframe
        }
        
        structure.lastSwingLow.level = swingLow;
        structure.lastSwingLow.barTime = iTime(_Symbol, PERIOD_CURRENT, lowestBar);
        structure.lastSwingLow.barIndex = lowestBar;
        structure.lastSwingLow.confirmed = true;
        structure.currentTrend = BULLISH;
        
        barsSinceSwingLow = 0;
    } else {
        barsSinceSwingLow++;
    }
}

//+------------------------------------------------------------------+
//| DETECT ORDER BLOCKS                                              |
//+------------------------------------------------------------------+
void DetectOrderBlocks() {
    // Only detect new order blocks on structural changes
    if (barsSinceSwingHigh == 1) {
        // Just formed a new swing high, create bearish OB
        CreateBearishOrderBlock();
    }
    
    if (barsSinceSwingLow == 1) {
        // Just formed a new swing low, create bullish OB
        CreateBullishOrderBlock();
    }
    
    // Clean up old/inactive order blocks
    PruneOrderBlocks();
}

//+------------------------------------------------------------------+
//| CREATE BULLISH ORDER BLOCK from swing low structure              |
//+------------------------------------------------------------------+
void CreateBullishOrderBlock() {
    // Find the highest point from swing low to next move up
    int startBar = structure.lastSwingLow.barIndex;
    int searchRange = MathMin(BarHistoryForOB, startBar);
    
    int highestInRange = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, searchRange, startBar);
    double obHigh = iHigh(_Symbol, PERIOD_CURRENT, highestInRange);
    double obLow = structure.lastSwingLow.level;
    
    OrderBlock ob;
    ob.high = obHigh;
    ob.low = obLow;
    ob.midpoint = (obHigh + obLow) / 2.0;
    ob.formationTime = iTime(_Symbol, PERIOD_CURRENT, startBar);
    ob.formationBar = startBar;
    ob.bias = BULLISH;
    ob.active = true;
    ob.triggerFired = false;
    
    // Add to array
    int size = ArraySize(bullishOBs);
    if (size >= MAX_ORDER_BLOCKS) {
        ArrayRemove(bullishOBs, size - 1, 1);
    }
    ArrayInsert(bullishOBs, ob, 0, 1);
}

//+------------------------------------------------------------------+
//| CREATE BEARISH ORDER BLOCK from swing high structure             |
//+------------------------------------------------------------------+
void CreateBearishOrderBlock() {
    // Find the lowest point from swing high to next move down
    int startBar = structure.lastSwingHigh.barIndex;
    int searchRange = MathMin(BarHistoryForOB, startBar);
    
    int lowestInRange = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, searchRange, startBar);
    double obLow = iLow(_Symbol, PERIOD_CURRENT, lowestInRange);
    double obHigh = structure.lastSwingHigh.level;
    
    OrderBlock ob;
    ob.high = obHigh;
    ob.low = obLow;
    ob.midpoint = (obHigh + obLow) / 2.0;
    ob.formationTime = iTime(_Symbol, PERIOD_CURRENT, startBar);
    ob.formationBar = startBar;
    ob.bias = BEARISH;
    ob.active = true;
    ob.triggerFired = false;
    
    // Add to array
    int size = ArraySize(bearishOBs);
    if (size >= MAX_ORDER_BLOCKS) {
        ArrayRemove(bearishOBs, size - 1, 1);
    }
    ArrayInsert(bearishOBs, ob, 0, 1);
}

//+------------------------------------------------------------------+
//| PRUNE ORDER BLOCKS - Remove mitigated blocks                     |
//+------------------------------------------------------------------+
void PruneOrderBlocks() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Check bullish OBs
    for (int i = ArraySize(bullishOBs) - 1; i >= 0; i--) {
        if (bullishOBs[i].bias == BULLISH) {
            // OB mitigated if price closes above high
            if (iClose(_Symbol, PERIOD_CURRENT, 0) > bullishOBs[i].high) {
                ArrayRemove(bullishOBs, i, 1);
            }
        }
    }
    
    // Check bearish OBs
    for (int i = ArraySize(bearishOBs) - 1; i >= 0; i--) {
        if (bearishOBs[i].bias == BEARISH) {
            // OB mitigated if price closes below low
            if (iClose(_Symbol, PERIOD_CURRENT, 0) < bearishOBs[i].low) {
                ArrayRemove(bearishOBs, i, 1);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| CALCULATE PREMIUM/DISCOUNT ZONES                                 |
//+------------------------------------------------------------------+
void CalculateZones() {
    // Find swing high and low to determine equilibrium
    double top = structure.lastSwingHigh.level;
    double bottom = structure.lastSwingLow.level;
    
    if (top <= 0 || bottom <= 0) return;
    
    // Equilibrium is 50% level
    structure.equilibrium = (top + bottom) / 2.0;
    
    // Premium zone (above 50%)
    structure.premiumZoneTop = top;
    structure.premiumZoneBottom = structure.equilibrium;
    
    // Discount zone (below 50%)
    structure.discountZoneTop = structure.equilibrium;
    structure.discountZoneBottom = bottom;
}

//+------------------------------------------------------------------+
//| IS PRICE IN DISCOUNT ZONE?                                       |
//+------------------------------------------------------------------+
bool IsInDiscountZone(double price) {
    return (price >= structure.discountZoneBottom && 
            price <= structure.discountZoneTop);
}

//+------------------------------------------------------------------+
//| IS PRICE IN PREMIUM ZONE?                                        |
//+------------------------------------------------------------------+
bool IsInPremiumZone(double price) {
    return (price >= structure.premiumZoneBottom && 
            price <= structure.premiumZoneTop);
}

//+------------------------------------------------------------------+
//| CHECK PRICE ACTION RELATIVE TO ORDER BLOCK                       |
//+------------------------------------------------------------------+
PriceAction CheckPriceActionOnOB(OrderBlock &ob, double currentPrice) {
    if (currentPrice >= ob.low && currentPrice <= ob.high) {
        return PRICE_IN_OB;
    } else if (currentPrice > ob.high) {
        return PRICE_ABOVE_OB;
    } else if (currentPrice < ob.low) {
        return PRICE_BELOW_OB;
    }
    return PRICE_NOT_TOUCHING;
}

//+------------------------------------------------------------------+
//| EVALUATE ENTRY SIGNALS                                           |
//+------------------------------------------------------------------+
void EvaluateEntrySignals() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Check position limit
    if (!AllowMultiplePositions && CountOpenPositions() >= MaxPositions) {
        return;
    }
    
    // Check CHoCH requirement
    if (RequireCHoCH && !structure.chochDetected) {
        return;
    }
    
    // Evaluate bullish OBs (Buy signals)
    for (int i = 0; i < ArraySize(bullishOBs); i++) {
        if (!bullishOBs[i].active || bullishOBs[i].triggerFired) continue;
        
        PriceAction action = CheckPriceActionOnOB(bullishOBs[i], bid);
        
        if (action == PRICE_IN_OB && IsInDiscountZone(bid)) {
            // Valid buy setup
            ExecuteBuyEntry(bullishOBs[i], bid);
            bullishOBs[i].triggerFired = true;
        }
    }
    
    // Evaluate bearish OBs (Sell signals)
    for (int i = 0; i < ArraySize(bearishOBs); i++) {
        if (!bearishOBs[i].active || bearishOBs[i].triggerFired) continue;
        
        PriceAction action = CheckPriceActionOnOB(bearishOBs[i], ask);
        
        if (action == PRICE_IN_OB && IsInPremiumZone(ask)) {
            // Valid sell setup
            ExecuteSellEntry(bearishOBs[i], ask);
            bearishOBs[i].triggerFired = true;
        }
    }
    
    // Reset CHoCH for next bar
    structure.chochDetected = false;
}

//+------------------------------------------------------------------+
//| EXECUTE BUY ENTRY                                                |
//+------------------------------------------------------------------+
bool ExecuteBuyEntry(OrderBlock &ob, double entryPrice) {
    // Calculate stop loss (below OB)
    double stopLoss = ob.low - (SLBuffer * _Point);
    
    // Calculate risk in points
    double riskPoints = (entryPrice - stopLoss) / _Point;
    if (riskPoints <= 0) return false;
    
    // Calculate take profit (RR ratio)
    double takeProfitPoints = riskPoints * RRRatio;
    double takeProfit = entryPrice + (takeProfitPoints * _Point);
    
    // Calculate position size
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (RiskPercent / 100.0);
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if (tickValue <= 0) return false;
    
    double positionSize = NormalizeDouble(
        riskAmount / (riskPoints * tickSize * tickValue),
        (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)
    );
    
    // Normalize volume
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    positionSize = MathMax(positionSize, minVolume);
    positionSize = MathMin(positionSize, maxVolume);
    positionSize = NormalizeDouble(
        MathFloor(positionSize / stepVolume) * stepVolume,
        2
    );
    
    if (positionSize < minVolume) return false;
    
    // Place order
    string comment = CommentPrefix + "_BUY_OB";
    
    if (trade.Buy(positionSize, _Symbol, 0, stopLoss, takeProfit, comment)) {
        ulong ticket = trade.ResultOrder();
        
        // Record trade
        TradeData td;
        td.ticket = ticket;
        td.entryPrice = entryPrice;
        td.initialSL = stopLoss;
        td.initialTP = takeProfit;
        td.riskAmount = riskAmount;
        td.entryTime = TimeCurrent();
        td.orderBlockIndex = ArraySize(bullishOBs) - 1;
        td.breakEvenMoved = false;
        td.profitProtected = false;
        
        ArrayResize(activeTrades, ArraySize(activeTrades) + 1);
        activeTrades[ArraySize(activeTrades) - 1] = td;
        
        totalTradesOpened++;
        
        Print("BUY Entry - Ticket: ", ticket, 
              " Entry: ", DoubleToString(entryPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
              " SL: ", DoubleToString(stopLoss, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
              " TP: ", DoubleToString(takeProfit, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
              " Volume: ", positionSize);
        
        return true;
    }
    
    Print("Failed to place BUY order. Error: ", GetLastError());
    return false;
}

//+------------------------------------------------------------------+
//| EXECUTE SELL ENTRY                                               |
//+------------------------------------------------------------------+
bool ExecuteSellEntry(OrderBlock &ob, double entryPrice) {
    // Calculate stop loss (above OB)
    double stopLoss = ob.high + (SLBuffer * _Point);
    
    // Calculate risk in points
    double riskPoints = (stopLoss - entryPrice) / _Point;
    if (riskPoints <= 0) return false;
    
    // Calculate take profit (RR ratio)
    double takeProfitPoints = riskPoints * RRRatio;
    double takeProfit = entryPrice - (takeProfitPoints * _Point);
    
    // Calculate position size
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (RiskPercent / 100.0);
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if (tickValue <= 0) return false;
    
    double positionSize = NormalizeDouble(
        riskAmount / (riskPoints * tickSize * tickValue),
        (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)
    );
    
    // Normalize volume
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    positionSize = MathMax(positionSize, minVolume);
    positionSize = MathMin(positionSize, maxVolume);
    positionSize = NormalizeDouble(
        MathFloor(positionSize / stepVolume) * stepVolume,
        2
    );
    
    if (positionSize < minVolume) return false;
    
    // Place order
    string comment = CommentPrefix + "_SELL_OB";
    
    if (trade.Sell(positionSize, _Symbol, 0, stopLoss, takeProfit, comment)) {
        ulong ticket = trade.ResultOrder();
        
        // Record trade
        TradeData td;
        td.ticket = ticket;
        td.entryPrice = entryPrice;
        td.initialSL = stopLoss;
        td.initialTP = takeProfit;
        td.riskAmount = riskAmount;
        td.entryTime = TimeCurrent();
        td.orderBlockIndex = ArraySize(bearishOBs) - 1;
        td.breakEvenMoved = false;
        td.profitProtected = false;
        
        ArrayResize(activeTrades, ArraySize(activeTrades) + 1);
        activeTrades[ArraySize(activeTrades) - 1] = td;
        
        totalTradesOpened++;
        
        Print("SELL Entry - Ticket: ", ticket, 
              " Entry: ", DoubleToString(entryPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
              " SL: ", DoubleToString(stopLoss, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
              " TP: ", DoubleToString(takeProfit, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
              " Volume: ", positionSize);
        
        return true;
    }
    
    Print("Failed to place SELL order. Error: ", GetLastError());
    return false;
}

//+------------------------------------------------------------------+
//| MANAGE POSITIONS - Break even and profit protection              |
//+------------------------------------------------------------------+
void ManagePositions() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    for (int i = ArraySize(activeTrades) - 1; i >= 0; i--) {
        if (!PositionSelectByTicket(activeTrades[i].ticket)) {
            // Position closed, remove from array
            ArrayRemove(activeTrades, i, 1);
            continue;
        }
        
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
        double posSL = PositionGetDouble(POSITION_SL);
        double posTP = PositionGetDouble(POSITION_TP);
        
        if (posType == POSITION_TYPE_BUY) {
            // For BUY positions
            double riskInPoints = (posOpen - posSL) / _Point;
            
            if (UseBreakEven && !activeTrades[i].breakEvenMoved) {
                // Move to BE at 1:1
                if (bid >= posOpen + (riskInPoints * _Point)) {
                    trade.PositionModify(activeTrades[i].ticket, posOpen, posTP);
                    activeTrades[i].breakEvenMoved = true;
                    Print("Break even moved - Ticket: ", activeTrades[i].ticket);
                }
            }
            
            // Trailing profit protection could be added here
            
        } else if (posType == POSITION_TYPE_SELL) {
            // For SELL positions
            double riskInPoints = (posSL - posOpen) / _Point;
            
            if (UseBreakEven && !activeTrades[i].breakEvenMoved) {
                // Move to BE at 1:1
                if (ask <= posOpen - (riskInPoints * _Point)) {
                    trade.PositionModify(activeTrades[i].ticket, posOpen, posTP);
                    activeTrades[i].breakEvenMoved = true;
                    Print("Break even moved - Ticket: ", activeTrades[i].ticket);
                }
            }
            
            // Trailing profit protection could be added here
        }
    }
}

//+------------------------------------------------------------------+
//| COUNT OPEN POSITIONS                                             |
//+------------------------------------------------------------------+
int CountOpenPositions() {
    int count = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionSelectByTicket(PositionGetTicket(i))) {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol && 
                PositionGetInteger(POSITION_MAGIC) == tradeMagicNumber) {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| UPDATE CLOSED TRADES STATISTICS                                  |
//+------------------------------------------------------------------+
void UpdateClosedTradesStats() {
    HistorySelect(0, TimeCurrent());
    
    for (int i = 0; i < HistoryDealsTotal(); i++) {
        ulong ticket = HistoryDealGetTicket(i);
        
        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) == tradeMagicNumber) {
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
            
            if (dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                
                if (profit > 0) {
                    totalWins++;
                    grossProfit += profit;
                } else if (profit < 0) {
                    totalLosses++;
                    grossLoss += MathAbs(profit);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
// END OF EXPERT ADVISOR
//+------------------------------------------------------------------+
