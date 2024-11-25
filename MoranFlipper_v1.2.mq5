//+------------------------------------------------------------------+
//|                                             MoranFlipper_v1.2.mq5 |
//|                                 Copyright 2023, Bryson N. Omullo |
//|                                     https://github.com/nyaliti |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Bryson N. Omullo"
#property link      "https://github.com/nyaliti"
#property version   "1.20"

#include <Trade\Trade.mqh>
#include <Math\Stat\Math.mqh>
#include <Arrays\ArrayObj.mqh>

// Input parameters
input double RiskPercent = 1.0;  // Risk per trade as a percentage of balance
input int ATRPeriod = 14;        // Period for ATR calculation
input int SMC_OB_Lookback = 10;  // Lookback period for Order Blocks
input int SMC_FVG_Lookback = 5;  // Lookback period for Fair Value Gaps
input ENUM_TIMEFRAMES TimeframeHigh = PERIOD_H4;   // Higher timeframe
input ENUM_TIMEFRAMES TimeframeMid = PERIOD_H1;    // Middle timeframe
input ENUM_TIMEFRAMES TimeframeLow = PERIOD_M15;   // Lower timeframe
input int KNN_K = 5;             // Number of neighbors for KNN algorithm
input int KNN_History = 1000;    // Number of historical points to use for KNN

// Global variables and objects
CTrade trade;
int atrHandle;
double atrBuffer[];
CArrayObj knnData;

struct TradeStats
{
    int totalTrades;
    int winningTrades;
    int losingTrades;
    double totalProfit;
    double totalLoss;
};

TradeStats stats;

struct KNNDataPoint
{
    double features[4];  // RSI, ATR, MA Difference, Volatility
    int label;           // 1 for uptrend, -1 for downtrend, 0 for ranging
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize ATR indicator
    atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(atrHandle == INVALID_HANDLE) return(INIT_FAILED);
    
    ArraySetAsSeries(atrBuffer, true);
    
    // Initialize KNN data
    InitializeKNNData();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(atrHandle);
    knnData.Clear();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!UpdateMarketData()) return;
    
    if(IsHighImpactNewsTime())
    {
        Print("High-impact news event detected. Avoiding new trades.");
        return;
    }
    
    int marketTrend = AnalyzeTrendMultiTimeframe();
    int marketCondition = PredictMarketCondition();
    
    bool entrySignal = false;
    
    switch(marketCondition)
    {
        case 1: // Uptrend
            if(marketTrend > 0) // Confirm with multi-timeframe analysis
                entrySignal = CheckSMCEntry() || CheckSupplyDemandEntry();
            break;
        case -1: // Downtrend
            if(marketTrend < 0) // Confirm with multi-timeframe analysis
                entrySignal = CheckSMCEntryShort() || CheckSupplyDemandEntryShort();
            break;
        case 0: // Ranging market
            entrySignal = CheckFibonacciEntry();
            break;
    }
    
    if(entrySignal)
    {
        double lotSize = CalculateLotSize();
        if(CheckRiskManagement(lotSize))
        {
            if(marketTrend > 0)
            {
                double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double stopLoss = CalculateDynamicStopLoss(true);
                double takeProfit = CalculateDynamicTakeProfit(true);
                
                if(trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v1.2"))
                {
                    LogTrade("BUY", lotSize, entryPrice, stopLoss, takeProfit);
                }
            }
            else if(marketTrend < 0)
            {
                double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double stopLoss = CalculateDynamicStopLoss(false);
                double takeProfit = CalculateDynamicTakeProfit(false);
                
                if(trade.Sell(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v1.2"))
                {
                    LogTrade("SELL", lotSize, entryPrice, stopLoss, takeProfit);
                }
            }
        }
    }
    
    ManageOpenPositions();
    
    // Check for closed positions and update stats
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY || 
                   PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                {
                    double positionProfit = PositionGetDouble(POSITION_PROFIT);
                    UpdateTradeStats(positionProfit);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update market data                                               |
//+------------------------------------------------------------------+
bool UpdateMarketData()
{
    return CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) == 1;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk percentage                 |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * RiskPercent / 100;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    double stopLossPoints = atrBuffer[0] * 2;  // SL at 2 * ATR
    double lotSize = NormalizeDouble(riskAmount / (stopLossPoints * tickValue), 2);
    
    return MathFloor(lotSize / lotStep) * lotStep;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                double positionProfit = PositionGetDouble(POSITION_PROFIT);
                double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                
                // Implement trailing stop
                if(positionProfit > 0)
                {
                    double newStopLoss = NormalizeDouble(currentPrice - atrBuffer[0], _Digits);
                    if(newStopLoss > PositionGetDouble(POSITION_SL) && newStopLoss < currentPrice)
                    {
                        trade.PositionModify(PositionGetTicket(i), newStopLoss, PositionGetDouble(POSITION_TP));
                    }
                }
                
                // Implement breakeven stop
                if(currentPrice >= positionOpenPrice + atrBuffer[0])
                {
                    if(PositionGetDouble(POSITION_SL) < positionOpenPrice)
                    {
                        trade.PositionModify(PositionGetTicket(i), positionOpenPrice, PositionGetDouble(POSITION_TP));
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if new trade adheres to risk management rules              |
//+------------------------------------------------------------------+
bool CheckRiskManagement(double lotSize)
{
    double totalRisk = 0;
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    // Calculate risk of existing positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                double positionLotSize = PositionGetDouble(POSITION_VOLUME);
                double positionRisk = (PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_SL)) * positionLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                totalRisk += positionRisk;
            }
        }
    }
    
    // Calculate risk of new position
    double newPositionRisk = atrBuffer[0] * 2 * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    totalRisk += newPositionRisk;
    
    // Check if total risk exceeds 2% of account balance
    if(totalRisk > accountBalance * 0.02)
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Log trade information                                            |
//+------------------------------------------------------------------+
void LogTrade(string action, double lotSize, double entryPrice, double stopLoss, double takeProfit)
{
    string logMessage = StringFormat("%s: %s %.2f lots at %.5f, SL: %.5f, TP: %.5f", 
                                     TimeToString(TimeCurrent()), action, lotSize, entryPrice, stopLoss, takeProfit);
    int fileHandle = FileOpen("MoranFlipperTrades.log", FILE_WRITE|FILE_READ|FILE_TXT);
    
    if(fileHandle != INVALID_HANDLE)
    {
        FileSeek(fileHandle, 0, SEEK_END);
        FileWriteString(fileHandle, logMessage + "\n");
        FileClose(fileHandle);
    }
    else
    {
        Print("Failed to open log file. Error code: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Multi-timeframe trend analysis                                   |
//+------------------------------------------------------------------+
int AnalyzeTrendMultiTimeframe()
{
    int trendHigh = IdentifyTrend(TimeframeHigh);
    int trendMid = IdentifyTrend(TimeframeMid);
    int trendLow = IdentifyTrend(TimeframeLow);
    
    // All timeframes agree on the trend
    if(trendHigh == trendMid && trendMid == trendLow)
        return trendHigh;
    
    // At least two timeframes agree on the trend
    if((trendHigh == trendMid) || (trendHigh == trendLow))
        return trendHigh;
    if(trendMid == trendLow)
        return trendMid;
    
    // No clear trend
    return 0;
}

//+------------------------------------------------------------------+
//| Identify trend for a specific timeframe                          |
//+------------------------------------------------------------------+
int IdentifyTrend(ENUM_TIMEFRAMES timeframe)
{
    double ma[], close[];
    ArraySetAsSeries(ma, true);
    ArraySetAsSeries(close, true);
    
    int maHandle = iMA(_Symbol, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
    if(maHandle == INVALID_HANDLE) return 0;
    
    if(CopyBuffer(maHandle, 0, 0, 3, ma) != 3) return 0;
    if(CopyClose(_Symbol, timeframe, 0, 3, close) != 3) return 0;
    
    IndicatorRelease(maHandle);
    
    if(close[0] > ma[0] && ma[0] > ma[1] && ma[1] > ma[2])
        return 1;  // Uptrend
    if(close[0] < ma[0] && ma[0] < ma[1] && ma[1] < ma[2])
        return -1; // Downtrend
    
    return 0;  // No clear trend
}

//+------------------------------------------------------------------+
//| Calculate dynamic stop loss                                      |
//+------------------------------------------------------------------+
double CalculateDynamicStopLoss(bool isBuy)
{
    double atr = atrBuffer[0];
    double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = isBuy ? currentPrice - atr * 2 : currentPrice + atr * 2;
    
    return NormalizeDouble(stopLoss, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate dynamic take profit                                    |
//+------------------------------------------------------------------+
double CalculateDynamicTakeProfit(bool isBuy)
{
    double atr = atrBuffer[0];
    double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double takeProfit = isBuy ? currentPrice + atr * 3 : currentPrice - atr * 3;
    
    return NormalizeDouble(takeProfit, _Digits);
}

//+------------------------------------------------------------------+
//| Check for high-impact news events                                |
//+------------------------------------------------------------------+
bool IsHighImpactNewsTime()
{
    datetime currentTime = TimeCurrent();
    MqlCalendarValue values[];
    
    if(CalendarValueHistory(values, currentTime, currentTime + PeriodSeconds(PERIOD_H1)))
    {
        for(int i = 0; i < ArraySize(values); i++)
        {
            if(values[i].impact_type == CALENDAR_IMPACT_HIGH)
            {
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Custom function to update trade statistics                       |
//+------------------------------------------------------------------+
void UpdateTradeStats(double profit)
{
    stats.totalTrades++;
    if(profit > 0)
    {
        stats.winningTrades++;
        stats.totalProfit += profit;
    }
    else
    {
        stats.losingTrades++;
        stats.totalLoss += MathAbs(profit);
    }
    
    double winRate = (double)stats.winningTrades / stats.totalTrades * 100;
    double profitFactor = stats.totalLoss > 0 ? stats.totalProfit / stats.totalLoss : 0;
    
    Print("Trade Statistics:");
    Print("Total Trades: ", stats.totalTrades);
    Print("Win Rate: ", DoubleToString(winRate, 2), "%");
    Print("Profit Factor: ", DoubleToString(profitFactor, 2));
}

//+------------------------------------------------------------------+
//| Initialize KNN data                                              |
//+------------------------------------------------------------------+
void InitializeKNNData()
{
    knnData.Clear();
    
    double close[], rsi[], atr[], ma[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(atr, true);
    ArraySetAsSeries(ma, true);
    
    int rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    int maHandle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    
    if(rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE)
        return;
    
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, KNN_History, close) != KNN_History) return;
    if(CopyBuffer(rsiHandle, 0, 0, KNN_History, rsi) != KNN_History) return;
    if(CopyBuffer(atrHandle, 0, 0, KNN_History, atr) != KNN_History) return;
    if(CopyBuffer(maHandle, 0, 0, KNN_History, ma) != KNN_History) return;
    
    for(int i = 0; i < KNN_History - 1; i++)
    {
        KNNDataPoint* point = new KNNDataPoint();
        point.features[0] = rsi[i];
        point.features[1] = atr[i];
        point.features[2] = close[i] - ma[i];
        point.features[3] = MathAbs(close[i] - close[i+1]) / close[i+1];  // Volatility
        
        if(close[i] > ma[i] && ma[i] > ma[i+1])
            point.label = 1;  // Uptrend
        else if(close[i] < ma[i] && ma[i] < ma[i+1])
            point.label = -1; // Downtrend
        else
            point.label = 0;  // Ranging
        
        knnData.Add(point);
    }
    
    IndicatorRelease(rsiHandle);
    IndicatorRelease(atrHandle);
    IndicatorRelease(maHandle);
}

//+------------------------------------------------------------------+
//| Predict market condition using KNN                               |
//+------------------------------------------------------------------+
int PredictMarketCondition()
{
    double features[4];
    double close[], rsi[], ma[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(ma, true);
    
    int rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    int maHandle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    
    if(rsiHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE)
        return 0;
    
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 2, close) != 2) return 0;
    if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) != 1) return 0;
    if(CopyBuffer(maHandle, 0, 0, 1, ma) != 1) return 0;
    
    features[0] = rsi[0];
    features[1] = atrBuffer[0];
    features[2] = close[0] - ma[0];
    features[3] = MathAbs(close[0] - close[1]) / close[1];  // Volatility
    
    IndicatorRelease(rsiHandle);
    IndicatorRelease(maHandle);
    
    return KNNClassify(features);
}

//+------------------------------------------------------------------+
//| KNN classification                                               |
//+------------------------------------------------------------------+
int KNNClassify(const double &features[])
{
    CArrayObj distances;
    
    for(int i = 0; i < knnData.Total(); i++)
    {
        KNNDataPoint* point = knnData.At(i);
        double distance = EuclideanDistance(features, point.features);
        distances.Add(new CDistance(distance, point.label));
    }
    
    distances.Sort(0);
    
    int upVotes = 0, downVotes = 0, rangeVotes = 0;
    
    for(int i = 0; i < KNN_K; i++)
    {
        CDistance* dist = distances.At(i);
        switch(dist.label)
        {
            case 1:  upVotes++; break;
            case -1: downVotes++; break;
            case 0:  rangeVotes++; break;
        }
    }
    
    distances.Clear();
    
    if(upVotes > downVotes && upVotes > rangeVotes)
        return 1;
    else if(downVotes > upVotes && downVotes > rangeVotes)
        return -1;
    else
        return 0;
}

//+------------------------------------------------------------------+
//| Calculate Euclidean distance between two feature vectors         |
//+------------------------------------------------------------------+
double EuclideanDistance(const double &a[], const double &b[])
{
    double sum = 0;
    for(int i = 0; i < 4; i++)
    {
        sum += MathPow(a[i] - b[i], 2);
    }
    return MathSqrt(sum);
}

//+------------------------------------------------------------------+
//| Helper class for KNN distance calculation                        |
//+------------------------------------------------------------------+
class CDistance : public CObject
{
public:
    double distance;
    int label;
    
    CDistance(double d, int l) : distance(d), label(l) {}
    
    virtual int Compare(const CObject *node, const int mode=0) const
    {
        const CDistance *other = (const CDistance*)node;
        if(distance < other.distance) return -1;
        if(distance > other.distance) return 1;
        return 0;
    }
};

//+------------------------------------------------------------------+
//| Strategy: Smart Money Concepts (SMC)                             |
//+------------------------------------------------------------------+
bool CheckSMCEntry()
{
    if(IdentifyOrderBlock() && IdentifyFairValueGap() && IdentifyBreakOfStructure())
    {
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Identify Order Block                                             |
//+------------------------------------------------------------------+
bool IdentifyOrderBlock()
{
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, high) != SMC_OB_Lookback) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, low) != SMC_OB_Lookback) return false;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, close) != SMC_OB_Lookback) return false;
    
    // Look for bullish order block
    for(int i = 1; i < SMC_OB_Lookback - 1; i++)
    {
        if(close[i] < close[i+1] && close[i-1] > close[i] && high[i-1] > high[i+1])
        {
            // Potential bullish order block found
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Identify Fair Value Gap                                          |
//+------------------------------------------------------------------+
bool IdentifyFairValueGap()
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, SMC_FVG_Lookback, high) != SMC_FVG_Lookback) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, SMC_FVG_Lookback, low) != SMC_FVG_Lookback) return false;
    
    // Look for bullish FVG
    for(int i = 1; i < SMC_FVG_Lookback - 1; i++)
    {
        if(low[i-1] > high[i+1])
        {
            // Bullish FVG found
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Identify Break of Structure                                      |
//+------------------------------------------------------------------+
bool IdentifyBreakOfStructure()
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, high) != SMC_OB_Lookback) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, low) != SMC_OB_Lookback) return false;
    
    // Look for bullish break of structure
    double lowestLow = low[ArrayMinimum(low, 0, SMC_OB_Lookback)];
    if(low[0] < lowestLow && high[1] > high[2])
    {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Strategy: Supply and Demand                                      |
//+------------------------------------------------------------------+
bool CheckSupplyDemandEntry()
{
    if(IsPriceInDemandZone() && IsUptrendConfirmed())
    {
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if price is in a demand zone                               |
//+------------------------------------------------------------------+
bool IsPriceInDemandZone()
{
    double close[];
    ArraySetAsSeries(close, true);
    
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 100, close) != 100) return false;
    
    double currentPrice = close[0];
    double demandZoneUpper = IdentifyRecentLow(close, 100) * 1.005; // 0.5% above recent low
    double demandZoneLower = IdentifyRecentLow(close, 100) * 0.995; // 0.5% below recent low
    
    return (currentPrice >= demandZoneLower && currentPrice <= demandZoneUpper);
}

//+------------------------------------------------------------------+
//| Identify recent low price                                        |
//+------------------------------------------------------------------+
double IdentifyRecentLow(const double &price[], int count)
{
    return price[ArrayMinimum(price, 0, count)];
}

//+------------------------------------------------------------------+
//| Confirm uptrend                                                  |
//+------------------------------------------------------------------+
bool IsUptrendConfirmed()
{
    double ma[], close[];
    ArraySetAsSeries(ma, true);
    ArraySetAsSeries(close, true);
    
    int maHandle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    if(maHandle == INVALID_HANDLE) return false;
    
    if(CopyBuffer(maHandle, 0, 0, 3, ma) != 3) return false;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 3, close) != 3) return false;
    
    IndicatorRelease(maHandle);
    
    // Price above MA and MA sloping upwards
    return (close[0] > ma[0] && ma[0] > ma[1] && ma[1] > ma[2]);
}

//+------------------------------------------------------------------+
//| Strategy: Fibonacci Retracement                                  |
//+------------------------------------------------------------------+
bool CheckFibonacciEntry()
{
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 100, high) != 100) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 100, low) != 100) return false;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, close) != 1) return false;
    
    int highestBar = ArrayMaximum(high, 0, 100);
    int lowestBar = ArrayMinimum(low, 0, 100);
    
    double fibLevel382 = high[highestBar] - (high[highestBar] - low[lowestBar]) * 0.382;
    double fibLevel618 = high[highestBar] - (high[highestBar] - low[lowestBar]) * 0.618;
    
    // Check if current price is near 0.382 or 0.618 Fibonacci level
    if((close[0] >= fibLevel382 * 0.998 && close[0] <= fibLevel382 * 1.002) ||
       (close[0] >= fibLevel618 * 0.998 && close[0] <= fibLevel618 * 1.002))
    {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Strategy: Smart Money Concepts (SMC) for Short Entries           |
//+------------------------------------------------------------------+
bool CheckSMCEntryShort()
{
    if(IdentifyOrderBlockShort() && IdentifyFairValueGapShort() && IdentifyBreakOfStructureShort())
    {
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Identify Order Block for Short Entries                           |
//+------------------------------------------------------------------+
bool IdentifyOrderBlockShort()
{
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, high) != SMC_OB_Lookback) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, low) != SMC_OB_Lookback) return false;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, close) != SMC_OB_Lookback) return false;
    
    // Look for bearish order block
    for(int i = 1; i < SMC_OB_Lookback - 1; i++)
    {
        if(close[i] > close[i+1] && close[i-1] < close[i] && low[i-1] < low[i+1])
        {
            // Potential bearish order block found
            return true;
        }
    }
    
    return false;
}

