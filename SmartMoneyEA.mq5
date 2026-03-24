//+------------------------------------------------------------------+
//| Smart Money Concepts Expert Advisor                              |
//| Translated from Pine Script (LuxAlgo) to MQL5                    |
//| Entry: Order Blocks in Premium/Discount Zones                    |
//| Risk Management: Dynamic SL/TP with Break Even                   |
//+------------------------------------------------------------------+
#property copyright "Smart Money Concepts Translation"
#property link      "https://www.mql5.com"
#property version   "1.0"
#property strict
#property description "Uses Order Blocks & Smart Money Concepts for entries with risk management"

#include <Trade\Trade.mqh>

//--- Constants
#define BULLISH 1
#define BEARISH -1
#define BULLISH_LEG 1
#define BEARISH_LEG 0

//--- Enums
enum ZONE_TYPE {
    PREMIUM_ZONE,
    DISCOUNT_ZONE,
    EQUILIBRIUM_ZONE,
    NO_ZONE
};

//--- Structure for Order Block
struct OrderBlock {
    double high;
    double low;
    datetime barTime;
    int bias; // BULLISH or BEARISH
    bool active;
};

//--- Structure for Swing Point
struct SwingPoint {
    double level;
    datetime barTime;
    int barIndex;
    int leg; // BULLISH_LEG or BEARISH_LEG
};

//--- Structure for Trade Info
struct TradeInfo {
    ulong ticket;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double riskAmount;
    datetime entryTime;
    bool breakEvenMoved;
};

//--- Input Parameters
input double RiskPercent = 1.0;                    // Risk % per trade
input int SwingLength = 50;                        // Bars for swing detection
input int InternalLength = 5;                      // Bars for internal structure
input double RRRatio = 1.5;                        // Risk to Reward Ratio (TP1)
input int SLPips = 5;                              // Pips outside OB for SL
input int OrderBlocksCount = 5;                    // Number of recent OBs to track
input bool UseBreakEven = true;                    // Enable break even
input bool RequireCHoCH = false;                   // Require CHoCH for entry
input ENUM_TIMEFRAME TradeTimeframe = PERIOD_H1;   // Trading timeframe
input string TradeSymbols = "EURUSD,GBPUSD,USDJPY"; // Comma-separated symbols
input int MagicNumberBase = 10000;                 // Base magic number

//--- Global Variables
CTrade trade;
TradeInfo openTrades[];
OrderBlock bullishOrderBlocks[];
OrderBlock bearishOrderBlocks[];
SwingPoint lastSwingHigh;
SwingPoint lastSwingLow;
double premiumZoneTop, premiumZoneBottom;
double discountZoneTop, discountZoneBottom;
double equilibriumLevel;
int currentLeg = BULLISH_LEG;
bool chochDetected = false;

//--- Statistics
datetime lastTradeTime = 0;
int closedTradesCount = 0;
double totalProfit = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    if (!trade.IsConnected()) {
        Print("Failed to connect to trading terminal!");
        return INIT_FAILED;
    }
    
    ArrayResize(openTrades, 0);
    ArrayResize(bullishOrderBlocks, 0);
    ArrayResize(bearishOrderBlocks, 0);
    
    lastSwingHigh.level = 0;
    lastSwingHigh.leg = BEARISH_LEG;
    lastSwingLow.level = 0;
    lastSwingLow.leg = BULLISH_LEG;
    
    Print("Smart Money EA initialized successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("=== Smart Money EA Deinit Summary ===");
    Print("Total closed trades: ", closedTradesCount);
    Print("Total profit: ", totalProfit);
    Print("Open trades on exit: ", ArraySize(openTrades));
    
    // Log remaining positions
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (OrderGetInteger(ORDER_MAGIC) >= MagicNumberBase) {
            Print("Remaining position - Ticket: ", ticket, 
                  " Symbol: ", OrderGetString(ORDER_SYMBOL),
                  " Type: ", OrderGetInteger(ORDER_TYPE));
        }
    }
    
    Print("EA stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Tick function - Main trading logic                               |
//+------------------------------------------------------------------+
void OnTick() {
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, TradeTimeframe, 0);
    
    // Process only on new bar
    if (lastBarTime == currentBarTime) return;
    lastBarTime = currentBarTime;
    
    // Update swing points and structures
    UpdateSwingStructure();
    
    // Update zones
    UpdatePremiumDiscountZones();
    
    // Detect order blocks
    DetectOrderBlocks();
    
    // Manage open trades
    ManageOpenTrades();
    
    // Check entry conditions
    CheckEntrySignals();
}

//+------------------------------------------------------------------+
//| Update swing highs and lows                                      |
//+------------------------------------------------------------------+
void UpdateSwingStructure() {
    int highest = iHighest(_Symbol, TradeTimeframe, MODE_HIGH, SwingLength, 1);
    int lowest = iLowest(_Symbol, TradeTimeframe, MODE_LOW, SwingLength, 1);
    
    double currentHigh = iHigh(_Symbol, TradeTimeframe, highest);
    double currentLow = iLow(_Symbol, TradeTimeframe, lowest);
    
    // Detect leg change
    int newLeg = BULLISH_LEG;
    if (currentHigh > lastSwingHigh.level) {
        newLeg = BEARISH_LEG;
    } else if (currentLow < lastSwingLow.level) {
        newLeg = BULLISH_LEG;
    }
    
    // Update swing high
    if (newLeg == BEARISH_LEG && currentLeg != BEARISH_LEG) {
        lastSwingHigh.level = currentHigh;
        lastSwingHigh.barTime = iTime(_Symbol, TradeTimeframe, highest);
        lastSwingHigh.barIndex = iBarShift(_Symbol, TradeTimeframe, lastSwingHigh.barTime);
        chochDetected = true;
    }
    
    // Update swing low
    if (newLeg == BULLISH_LEG && currentLeg != BULLISH_LEG) {
        lastSwingLow.level = currentLow;
        lastSwingLow.barTime = iTime(_Symbol, TradeTimeframe, lowest);
        lastSwingLow.barIndex = iBarShift(_Symbol, TradeTimeframe, lastSwingLow.barTime);
        chochDetected = true;
    }
    
    currentLeg = newLeg;
}

//+------------------------------------------------------------------+
//| Detect order blocks                                              |
//+------------------------------------------------------------------+
void DetectOrderBlocks() {
    // Get recent swings to identify order blocks
    int internalHighest = iHighest(_Symbol, TradeTimeframe, MODE_HIGH, InternalLength, 1);
    int internalLowest = iLowest(_Symbol, TradeTimeframe, MODE_LOW, InternalLength, 1);
    
    double internalHigh = iHigh(_Symbol, TradeTimeframe, internalHighest);
    double internalLow = iLow(_Symbol, TradeTimeframe, internalLowest);
    
    // Create bullish order block (low of structure)
    if (currentLeg == BEARISH_LEG) {
        OrderBlock ob;
        ob.high = internalHigh;
        ob.low = internalLow;
        ob.barTime = iTime(_Symbol, TradeTimeframe, internalLowest);
        ob.bias = BULLISH;
        ob.active = true;
        
        // Store bullish OB
        int size = ArraySize(bullishOrderBlocks);
        if (size >= OrderBlocksCount) {
            ArrayRemove(bullishOrderBlocks, size - 1, 1);
        }
        ArrayInsert(bullishOrderBlocks, ob, 0, 1);
    }
    
    // Create bearish order block (high of structure)
    if (currentLeg == BULLISH_LEG) {
        OrderBlock ob;
        ob.high = internalHigh;
        ob.low = internalLow;
        ob.barTime = iTime(_Symbol, TradeTimeframe, internalHighest);
        ob.bias = BEARISH;
        ob.active = true;
        
        // Store bearish OB
        int size = ArraySize(bearishOrderBlocks);
        if (size >= OrderBlocksCount) {
            ArrayRemove(bearishOrderBlocks, size - 1, 1);
        }
        ArrayInsert(bearishOrderBlocks, ob, 0, 1);
    }
}

//+------------------------------------------------------------------+
//| Update premium and discount zones                                |
//+------------------------------------------------------------------+
void UpdatePremiumDiscountZones() {
    // Get highest high and lowest low over swing period
    int startBar = iBarShift(_Symbol, TradeTimeframe, lastSwingHigh.barTime);
    int highestIdx = iHighest(_Symbol, TradeTimeframe, MODE_HIGH, startBar + 1, 0);
    int lowestIdx = iLowest(_Symbol, TradeTimeframe, MODE_LOW, startBar + 1, 0);
    
    double swingTop = iHigh(_Symbol, TradeTimeframe, highestIdx);
    double swingBottom = iLow(_Symbol, TradeTimeframe, lowestIdx);
    
    equilibriumLevel = (swingTop + swingBottom) / 2.0;
    
    // Premium zone (above 50%)
    premiumZoneTop = swingTop;
    premiumZoneBottom = equilibriumLevel;
    
    // Discount zone (below 50%)
    discountZoneTop = equilibriumLevel;
    discountZoneBottom = swingBottom;
}

//+------------------------------------------------------------------+
//| Check if price is in discount zone                               |
//+------------------------------------------------------------------+
bool IsInDiscountZone(double price) {
    return (price >= discountZoneBottom && price <= discountZoneTop);
}

//+------------------------------------------------------------------+
//| Check if price is in premium zone                                |
//+------------------------------------------------------------------+
bool IsInPremiumZone(double price) {
    return (price >= premiumZoneBottom && price <= premiumZoneTop);
}

//+------------------------------------------------------------------+
//| Check entry signals                                              |
//+------------------------------------------------------------------+
void CheckEntrySignals() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    int pointMultiplier = (int)SymbolInfoInteger(_Symbol, SYMBOL_POINT) == 0.0001 ? 100 : 10;
    
    // Check bullish order blocks (buy signal)
    for (int i = 0; i < ArraySize(bullishOrderBlocks); i++) {
        OrderBlock &ob = bullishOrderBlocks[i];
        
        if (!ob.active) continue;
        
        // Check if price touched the OB
        if (bid >= ob.low && bid <= ob.high && IsInDiscountZone(bid)) {
            // Optional: Check for CHoCH
            if (RequireCHoCH && !chochDetected) continue;
            
            // Calculate SL and TP
            double stopLoss = ob.low - (SLPips * _Point);
            double riskPoints = (bid - stopLoss) / _Point;
            double takeProfitPoints = riskPoints * RRRatio;
            double takeProfit = bid + (takeProfitPoints * _Point);
            
            // Calculate position size
            double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100.0);
            double positionSize = NormalizeDouble(riskAmount / (riskPoints * _Point * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)), 2);
            
            // Check for existing positions
            if (!HasOpenPosition(POSITION_TYPE_BUY)) {
                OpenBuyPosition(positionSize, bid, stopLoss, takeProfit);
                ob.active = false;
            }
        }
    }
    
    // Check bearish order blocks (sell signal)
    for (int i = 0; i < ArraySize(bearishOrderBlocks); i++) {
        OrderBlock &ob = bearishOrderBlocks[i];
        
        if (!ob.active) continue;
        
        // Check if price touched the OB
        if (ask <= ob.high && ask >= ob.low && IsInPremiumZone(ask)) {
            // Optional: Check for CHoCH
            if (RequireCHoCH && !chochDetected) continue;
            
            // Calculate SL and TP
            double stopLoss = ob.high + (SLPips * _Point);
            double riskPoints = (stopLoss - ask) / _Point;
            double takeProfitPoints = riskPoints * RRRatio;
            double takeProfit = ask - (takeProfitPoints * _Point);
            
            // Calculate position size
            double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100.0);
            double positionSize = NormalizeDouble(riskAmount / (riskPoints * _Point * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)), 2);
            
            // Check for existing positions
            if (!HasOpenPosition(POSITION_TYPE_SELL)) {
                OpenSellPosition(positionSize, ask, stopLoss, takeProfit);
                ob.active = false;
            }
        }
    }
    
    chochDetected = false;
}

//+------------------------------------------------------------------+
//| Open buy position                                                |
//+------------------------------------------------------------------+
bool OpenBuyPosition(double volume, double entryPrice, double stopLoss, double takeProfit) {
    int magicNumber = MagicNumberBase + SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    if (trade.Buy(volume, _Symbol, entryPrice, stopLoss, takeProfit, "SMC - Buy OB")) {
        TradeInfo tradeInfo;
        tradeInfo.ticket = trade.ResultOrder();
        tradeInfo.entryPrice = entryPrice;
        tradeInfo.stopLoss = stopLoss;
        tradeInfo.takeProfit = takeProfit;
        tradeInfo.riskAmount = (entryPrice - stopLoss) * volume;
        tradeInfo.entryTime = TimeCurrent();
        tradeInfo.breakEvenMoved = false;
        
        ArrayResize(openTrades, ArraySize(openTrades) + 1);
        openTrades[ArraySize(openTrades) - 1] = tradeInfo;
        
        Print("Buy position opened - Ticket: ", tradeInfo.ticket, 
              " Entry: ", entryPrice, " SL: ", stopLoss, " TP: ", takeProfit);
        return true;
    }
    
    Print("Failed to open buy position. Error: ", GetLastError());
    return false;
}

//+------------------------------------------------------------------+
//| Open sell position                                               |
//+------------------------------------------------------------------+
bool OpenSellPosition(double volume, double entryPrice, double stopLoss, double takeProfit) {
    int magicNumber = MagicNumberBase + SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    if (trade.Sell(volume, _Symbol, entryPrice, stopLoss, takeProfit, "SMC - Sell OB")) {
        TradeInfo tradeInfo;
        tradeInfo.ticket = trade.ResultOrder();
        tradeInfo.entryPrice = entryPrice;
        tradeInfo.stopLoss = stopLoss;
        tradeInfo.takeProfit = takeProfit;
        tradeInfo.riskAmount = (stopLoss - entryPrice) * volume;
        tradeInfo.entryTime = TimeCurrent();
        tradeInfo.breakEvenMoved = false;
        
        ArrayResize(openTrades, ArraySize(openTrades) + 1);
        openTrades[ArraySize(openTrades) - 1] = tradeInfo;
        
        Print("Sell position opened - Ticket: ", tradeInfo.ticket, 
              " Entry: ", entryPrice, " SL: ", stopLoss, " TP: ", takeProfit);
        return true;
    }
    
    Print("Failed to open sell position. Error: ", GetLastError());
    return false;
}

//+------------------------------------------------------------------+
//| Check if there's an open position                                |
//+------------------------------------------------------------------+
bool HasOpenPosition(int positionType) {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (!PositionSelectByTicket(PositionGetTicket(i))) continue;
        
        if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_TYPE) == positionType &&
            PositionGetInteger(POSITION_MAGIC) >= MagicNumberBase) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Manage open trades (break even, profit management)               |
//+------------------------------------------------------------------+
void ManageOpenTrades() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    for (int i = 0; i < ArraySize(openTrades); i++) {
        if (!PositionSelectByTicket(openTrades[i].ticket)) continue;
        
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        
        if (UseBreakEven && !openTrades[i].breakEvenMoved) {
            // Move to break even at 1:1 RR
            double riskAmount = MathAbs(openPrice - openTrades[i].stopLoss);
            
            if (posType == POSITION_TYPE_BUY) {
                if (currentPrice >= openPrice + riskAmount) {
                    trade.PositionModify(openTrades[i].ticket, openPrice, currentTP);
                    openTrades[i].breakEvenMoved = true;
                    Print("Break even moved for ticket: ", openTrades[i].ticket);
                }
            } else {
                if (currentPrice <= openPrice - riskAmount) {
                    trade.PositionModify(openTrades[i].ticket, openPrice, currentTP);
                    openTrades[i].breakEvenMoved = true;
                    Print("Break even moved for ticket: ", openTrades[i].ticket);
                }
            }
        }
        
        // Optional: Trailing stop logic could be added here
    }
}

//+------------------------------------------------------------------+
//| Update closed trades statistics                                  |
//+------------------------------------------------------------------+
void UpdateClosedTradeStats() {
    HistorySelect(0, TimeCurrent());
    
    for (int i = 0; i < HistoryDealsTotal(); i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) >= MagicNumberBase) {
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
            
            if (dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                totalProfit += profit;
                closedTradesCount++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| End of Expert Advisor                                            |
//+------------------------------------------------------------------+
