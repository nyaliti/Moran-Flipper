//+------------------------------------------------------------------+
//|                                        MoranFlipper_v2.0.mq5     |
//|                                 Copyright 2023, Bryson N. Omullo |
//|                                     https://github.com/nyaliti   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Bryson N. Omullo"
#property link      "https://github.com/nyaliti"
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Indicators\Trend.mqh>
#include <Math\Stat\Math.mqh>
#include <Python\Python.mqh>

// Input parameters
input double RiskPercent = 1.0;  // Risk per trade as a percentage of balance
input int ATRPeriod = 14;        // Period for ATR calculation
input int FiboPeriod = 34;       // Period for Fibonacci calculations
input int SMC_Lookback = 100;    // Lookback period for Smart Money Concepts
input ENUM_TIMEFRAMES TimeframeHigh = PERIOD_H4;   // Higher timeframe
input ENUM_TIMEFRAMES TimeframeMid = PERIOD_H1;    // Middle timeframe
input ENUM_TIMEFRAMES TimeframeLow = PERIOD_M15;   // Lower timeframe
input bool UseML = true;         // Use Machine Learning predictions
input bool UseSMC = true;        // Use Smart Money Concepts
input bool UseSupplyDemand = true; // Use Supply and Demand zones
input bool UseFibonacci = true;  // Use Fibonacci retracements

// Global variables
CTrade trade;
int atrHandle;
double atrBuffer[];
CPython pyModule;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize ATR indicator
    atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(atrHandle == INVALID_HANDLE) return(INIT_FAILED);
    
    ArraySetAsSeries(atrBuffer, true);
    
    // Initialize Python environment for ML
    if(UseML && !InitializePython())
    {
        Print("Failed to initialize Python environment");
        return(INIT_FAILED);
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(atrHandle);
    if(UseML) pyModule.Finalize();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!UpdateMarketData()) return;
    
    int marketTrend = AnalyzeTrendMultiTimeframe();
    bool entrySignal = false;
    bool isLong = false;
    
    // Check for entry signals using various methods
    if(UseSMC && CheckSMCEntry(isLong))
        entrySignal = true;
    else if(UseSupplyDemand && CheckSupplyDemandEntry(isLong))
        entrySignal = true;
    else if(UseFibonacci && CheckFibonacciEntry(isLong))
        entrySignal = true;
    
    // Use Machine Learning prediction if enabled
    if(UseML)
    {
        double mlPrediction = GetMLPrediction();
        if(mlPrediction > 0.6) // Strong bullish prediction
        {
            entrySignal = true;
            isLong = true;
        }
        else if(mlPrediction < 0.4) // Strong bearish prediction
        {
            entrySignal = true;
            isLong = false;
        }
    }
    
    if(entrySignal)
    {
        double lotSize = CalculateLotSize();
        if(CheckRiskManagement(lotSize))
        {
            if(isLong)
                OpenBuyTrade(lotSize);
            else
                OpenSellTrade(lotSize);
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
//| Analyze trend across multiple timeframes                         |
//+------------------------------------------------------------------+
int AnalyzeTrendMultiTimeframe()
{
    int trendHigh = IdentifyTrend(TimeframeHigh);
    int trendMid = IdentifyTrend(TimeframeMid);
    int trendLow = IdentifyTrend(TimeframeLow);
    
    if(trendHigh == trendMid && trendMid == trendLow)
        return trendHigh;
    if((trendHigh == trendMid) || (trendHigh == trendLow))
        return trendHigh;
    if(trendMid == trendLow)
        return trendMid;
    
    return 0; // No clear trend
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
//| Check for Smart Money Concepts entry                             |
//+------------------------------------------------------------------+
bool CheckSMCEntry(bool &isLong)
{
    if(IdentifyOrderBlock(isLong) && IdentifyFairValueGap(isLong) && IdentifyBreakOfStructure(isLong))
    {
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Identify Order Block                                             |
//+------------------------------------------------------------------+
bool IdentifyOrderBlock(bool &isLong)
{
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, SMC_Lookback, high) != SMC_Lookback) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, SMC_Lookback, low) != SMC_Lookback) return false;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, SMC_Lookback, close) != SMC_Lookback) return false;
    
    for(int i = 1; i < SMC_Lookback - 1; i++)
    {
        if(close[i] < close[i+1] && close[i-1] > close[i] && high[i-1] > high[i+1])
        {
            isLong = true;
            return true;
        }
        if(close[i] > close[i+1] && close[i-1] < close[i] && low[i-1] < low[i+1])
        {
            isLong = false;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Identify Fair Value Gap                                          |
//+------------------------------------------------------------------+
bool IdentifyFairValueGap(bool &isLong)
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, SMC_Lookback, high) != SMC_Lookback) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, SMC_Lookback, low) != SMC_Lookback) return false;
    
    for(int i = 1; i < SMC_Lookback - 1; i++)
    {
        if(low[i-1] > high[i+1])
        {
            isLong = true;
            return true;
        }
        if(high[i-1] < low[i+1])
        {
            isLong = false;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Identify Break of Structure                                      |
//+------------------------------------------------------------------+
bool IdentifyBreakOfStructure(bool &isLong)
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, SMC_Lookback, high) != SMC_Lookback) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, SMC_Lookback, low) != SMC_Lookback) return false;
    
    double lowestLow = low[ArrayMinimum(low, 0, SMC_Lookback)];
    double highestHigh = high[ArrayMaximum(high, 0, SMC_Lookback)];
    
    if(low[0] < lowestLow && high[1] > high[2])
    {
        isLong = true;
        return true;
    }
    if(high[0] > highestHigh && low[1] < low[2])
    {
        isLong = false;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for Supply and Demand entry                                |
//+------------------------------------------------------------------+
bool CheckSupplyDemandEntry(bool &isLong)
{
    if(IsPriceInDemandZone())
    {
        isLong = true;
        return true;
    }
    if(IsPriceInSupplyZone())
    {
        isLong = false;
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
    double recentLow = close[ArrayMinimum(close, 0, 100)];
    double demandZoneUpper = recentLow * 1.005; // 0.5% above recent low
    double demandZoneLower = recentLow * 0.995; // 0.5% below recent low
    
    return (currentPrice >= demandZoneLower && currentPrice <= demandZoneUpper);
}

//+------------------------------------------------------------------+
//| Check if price is in a supply zone                               |
//+------------------------------------------------------------------+
bool IsPriceInSupplyZone()
{
    double close[];
    ArraySetAsSeries(close, true);
    
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 100, close) != 100) return false;
    
    double currentPrice = close[0];
    double recentHigh = close[ArrayMaximum(close, 0, 100)];
    double supplyZoneLower = recentHigh * 0.995; // 0.5% below recent high
    double supplyZoneUpper = recentHigh * 1.005; // 0.5% above recent high
    
    return (currentPrice >= supplyZoneLower && currentPrice <= supplyZoneUpper);
}

//+------------------------------------------------------------------+
//| Check for Fibonacci entry                                        |
//+------------------------------------------------------------------+
bool CheckFibonacciEntry(bool &isLong)
{
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, FiboPeriod, high) != FiboPeriod) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, FiboPeriod, low) != FiboPeriod) return false;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, close) != 1) return false;
    
    int highestBar = ArrayMaximum(high, 0, FiboPeriod);
    int lowestBar = ArrayMinimum(low, 0, FiboPeriod);
    
    double range = high[highestBar] - low[lowestBar];
    double fibo382 = low[lowestBar] + range * 0.382;
    double fibo618 = low[lowestBar] + range * 0.618;
    
    if(close[0] >= fibo382 * 0.99 && close[0] <= fibo382 * 1.01)
    {
        isLong = true;
        return true;
    }
    if(close[0] >= fibo618 * 0.99 && close[0] <= fibo618 * 1.01)
    {
        isLong = false;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get Machine Learning prediction                                  |
//+------------------------------------------------------------------+
double GetMLPrediction()
{
    // Prepare input data for ML model
    double features[];
    ArrayResize(features, 5);
    features[0] = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE, 0);
    features[1] = iStochastic(_Symbol, PERIOD_CURRENT, 5, 3, 3, MODE_SMA, STO_LOWHIGH, MAIN_LINE, 0);
    features[2] = iADX(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = atrBuffer[0];
    features[4] = AnalyzeTrendMultiTimeframe();
    
    // Call Python function for prediction
    pyModule.SetArgument("features", features);
    pyModule.Execute("prediction = model.predict(np.array(features).reshape(1, -1))[0]");
    return pyModule.GetDouble("prediction");
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * RiskPercent / 100;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double stopLossPoints = atrBuffer[0] * 2;
    
    double lotSize = NormalizeDouble(riskAmount / (stopLossPoints * tickValue), 2);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    return MathMax(MathMin(lotSize, maxLot), minLot);
}

//+------------------------------------------------------------------+
//| Check risk management                                            |
//+------------------------------------------------------------------+
bool CheckRiskManagement(double lotSize)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    
    if(equity < balance * 0.95) // Stop trading if equity drops below 95% of balance
        return false;
    
    if(freeMargin < balance * 0.2) // Stop trading if free margin is less than 20% of balance
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Open a buy trade                                                 |
//+------------------------------------------------------------------+
void OpenBuyTrade(double lotSize)
{
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double stopLoss = entryPrice - atrBuffer[0] * 2;
    double takeProfit = entryPrice + atrBuffer[0] * 3;
    
    trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v2.0");
}

//+------------------------------------------------------------------+
//| Open a sell trade                                                |
//+------------------------------------------------------------------+
void OpenSellTrade(double lotSize)
{
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = entryPrice + atrBuffer[0] * 2;
    double takeProfit = entryPrice - atrBuffer[0] * 3;
    
    trade.Sell(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v2.0");
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
                double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                                      SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                
                // Implement trailing stop
                if(positionProfit > 0)
                {
                    double newStopLoss = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ?
                                         currentPrice - atrBuffer[0] : currentPrice + atrBuffer[0];
                    
                    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && newStopLoss > PositionGetDouble(POSITION_SL))
                        trade.PositionModify(PositionGetTicket(i), newStopLoss, PositionGetDouble(POSITION_TP));
                    else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && newStopLoss < PositionGetDouble(POSITION_SL))
                        trade.PositionModify(PositionGetTicket(i), newStopLoss, PositionGetDouble(POSITION_TP));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Initialize Python environment                                    |
//+------------------------------------------------------------------+
bool InitializePython()
{
    if(!pyModule.Initialize())
        return false;
    
    string pythonScript = 
        "import numpy as np\n"
        "from sklearn.ensemble import RandomForestClassifier\n"
        "\n"
        "# Initialize and train the model (this is a placeholder, you should train on actual data)\n"
        "model = RandomForestClassifier(n_estimators=100, random_state=42)\n"
        "X_train = np.random.rand(1000, 5)\n"
        "y_train = np.random.randint(2, size=1000)\n"
        "model.fit(X_train, y_train)\n";
    
    if(!pyModule.Execute(pythonScript))
    {
        Print("Failed to execute Python script");
        return false;
    }
    
    return true;
}