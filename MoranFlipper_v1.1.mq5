//+------------------------------------------------------------------+
//|                                             MoranFlipper_v1.1.mq5 |
//|                                 Copyright 2023, Bryson N. Omullo |
//|                                     https://github.com/nyaliti |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Bryson N. Omullo"
#property link      "https://github.com/nyaliti"
#property version   "1.10"

#include <Trade\Trade.mqh>
#include <Math\Stat\Math.mqh>

// Input parameters
input double RiskPercent = 1.0;  // Risk per trade as a percentage of balance
input int ATRPeriod = 14;        // Period for ATR calculation
input int SMC_OB_Lookback = 10;  // Lookback period for Order Blocks
input int SMC_FVG_Lookback = 5;  // Lookback period for Fair Value Gaps

// Global variables and objects
CTrade trade;
int atrHandle;
double atrBuffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize ATR indicator
    atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(atrHandle == INVALID_HANDLE) return(INIT_FAILED);
    
    ArraySetAsSeries(atrBuffer, true);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!UpdateMarketData()) return;
    
    int marketCondition = AnalyzeMarketCondition();
    
    bool entrySignal = false;
    
    switch(marketCondition)
    {
        case 1: // Uptrend
            entrySignal = CheckSMCEntry() || CheckSupplyDemandEntry();
            break;
        case -1: // Downtrend
            // Implement short entry logic here if needed
            break;
        case 0: // Ranging market
            entrySignal = CheckFibonacciEntry();
            break;
        case 2: // Volatile market
            // You might want to avoid trading or use a different strategy
            break;
    }
    
    if(entrySignal)
    {
        double lotSize = CalculateLotSize();
        if(CheckRiskManagement(lotSize))
        {
            double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double stopLoss = entryPrice - atrBuffer[0] * 2;
            double takeProfit = entryPrice + atrBuffer[0] * 3;
            
            if(trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v1.1"))
            {
                LogTrade("BUY", lotSize, entryPrice, stopLoss, takeProfit);
            }
        }
    }
    
    ManageOpenPositions();
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
//| Analyze market conditions                                        |
//+------------------------------------------------------------------+
int AnalyzeMarketCondition()
{
    double ma[], close[];
    ArraySetAsSeries(ma, true);
    ArraySetAsSeries(close, true);
    
    int maHandle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    if(maHandle == INVALID_HANDLE) return 0;
    
    if(CopyBuffer(maHandle, 0, 0, 3, ma) != 3) return 0;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 3, close) != 3) return 0;
    
    IndicatorRelease(maHandle);
    
    // Trend following condition
    if(close[0] > ma[0] && ma[0] > ma[1] && ma[1] > ma[2])
    {
        return 1; // Uptrend
    }
    else if(close[0] < ma[0] && ma[0] < ma[1] && ma[1] < ma[2])
    {
        return -1; // Downtrend
    }
    
    // Range condition
    double atr = atrBuffer[0];
    double averageRange = (High[0] - Low[0] + High[1] - Low[1] + High[2] - Low[2]) / 3;
    
    if(averageRange < atr * 0.5)
    {
        return 0; // Ranging market
    }
    
    return 2; // Volatile market
}

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