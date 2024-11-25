//+------------------------------------------------------------------+
//|                                             MoranFlipper_v1.3.mq5 |
//|                                 Copyright 2023, Bryson N. Omullo |
//|                                     https://github.com/nyaliti |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Bryson N. Omullo"
#property link      "https://github.com/nyaliti"
#property version   "1.30"

#include <Trade\Trade.mqh>
#include <Math\Stat\Math.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Python\Python.mqh>

// Input parameters
input double RiskPercent = 1.0;  // Risk per trade as a percentage of balance
input int ATRPeriod = 14;        // Period for ATR calculation
input int SMC_OB_Lookback = 10;  // Lookback period for Order Blocks
input int SMC_FVG_Lookback = 5;  // Lookback period for Fair Value Gaps
input ENUM_TIMEFRAMES TimeframeHigh = PERIOD_H4;   // Higher timeframe
input ENUM_TIMEFRAMES TimeframeMid = PERIOD_H1;    // Middle timeframe
input ENUM_TIMEFRAMES TimeframeLow = PERIOD_M15;   // Lower timeframe
input int LSTMSequenceLength = 60;  // Sequence length for LSTM input
input int LSTMPredictionHorizon = 5;  // Number of future bars to predict

// Global variables and objects
CTrade trade;
int atrHandle;
double atrBuffer[];
CPython pyModule;

struct TradeStats
{
    int totalTrades;
    int winningTrades;
    int losingTrades;
    double totalProfit;
    double totalLoss;
};

TradeStats stats;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize ATR indicator
    atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(atrHandle == INVALID_HANDLE) return(INIT_FAILED);
    
    ArraySetAsSeries(atrBuffer, true);
    
    // Initialize Python environment
    if(!InitializePython())
    {
        Print("Failed to initialize Python environment");
        return(INIT_FAILED);
    }
    
    // Initialize trade statistics
    stats.totalTrades = 0;
    stats.winningTrades = 0;
    stats.losingTrades = 0;
    stats.totalProfit = 0;
    stats.totalLoss = 0;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(atrHandle);
    pyModule.Finalize();
    
    // Print final trade statistics
    PrintTradeStats();
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
    double[] lstmPrediction = PredictWithLSTM();
    
    bool entrySignal = false;
    bool isLong = false;
    
    if(lstmPrediction[0] > 0 && marketTrend > 0)
    {
        entrySignal = CheckSMCEntry() || CheckSupplyDemandEntry();
        isLong = true;
    }
    else if(lstmPrediction[0] < 0 && marketTrend < 0)
    {
        entrySignal = CheckSMCEntryShort() || CheckSupplyDemandEntryShort();
        isLong = false;
    }
    
    if(entrySignal)
    {
        double lotSize = CalculateKellyPositionSize();
        if(CheckRiskManagement(lotSize))
        {
            if(isLong)
            {
                double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double stopLoss = CalculateDynamicStopLoss(true);
                double takeProfit = CalculateDynamicTakeProfit(true);
                
                if(trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v1.3"))
                {
                    LogTrade("BUY", lotSize, entryPrice, stopLoss, takeProfit);
                }
            }
            else
            {
                double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double stopLoss = CalculateDynamicStopLoss(false);
                double takeProfit = CalculateDynamicTakeProfit(false);
                
                if(trade.Sell(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v1.3"))
                {
                    LogTrade("SELL", lotSize, entryPrice, stopLoss, takeProfit);
                }
            }
        }
    }
    
    ManageOpenPositions();
    ImplementTrailingStop();
    
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
//| Initialize Python environment                                    |
//+------------------------------------------------------------------+
bool InitializePython()
{
    if(!pyModule.Initialize())
        return false;
    
    string pythonScript = 
        "import numpy as np\n"
        "from tensorflow.keras.models import Sequential\n"
        "from tensorflow.keras.layers import LSTM, Dense\n"
        "from sklearn.preprocessing import MinMaxScaler\n"
        "\n"
        "model = Sequential([\n"
        "    LSTM(50, activation='relu', input_shape=(60, 5)),\n"
        "    Dense(1)\n"
        "])\n"
        "model.compile(optimizer='adam', loss='mse')\n"
        "\n"
        "scaler = MinMaxScaler(feature_range=(-1, 1))\n"
        "\n"
        "def train_lstm(data):\n"
        "    scaled_data = scaler.fit_transform(data)\n"
        "    X, y = [], []\n"
        "    for i in range(60, len(scaled_data)):\n"
        "        X.append(scaled_data[i-60:i])\n"
        "        y.append(scaled_data[i, 0])\n"
        "    X, y = np.array(X), np.array(y)\n"
        "    model.fit(X, y, epochs=50, batch_size=32, verbose=0)\n"
        "\n"
        "def predict_lstm(data):\n"
        "    scaled_data = scaler.transform(data)\n"
        "    X = np.array([scaled_data[-60:]])\n"
        "    scaled_prediction = model.predict(X)\n"
        "    return scaler.inverse_transform(scaled_prediction)[0, 0]\n";
    
    if(!pyModule.Execute(pythonScript))
    {
        Print("Failed to execute Python script");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with LSTM                                                |
//+------------------------------------------------------------------+
double[] PredictWithLSTM()
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, LSTMSequenceLength + LSTMPredictionHorizon, rates);
    
    if(copied != LSTMSequenceLength + LSTMPredictionHorizon)
    {
        Print("Failed to copy price data");
        return NULL;
    }
    
    double data[];
    ArrayResize(data, (LSTMSequenceLength + LSTMPredictionHorizon) * 5);
    
    for(int i = 0; i < LSTMSequenceLength + LSTMPredictionHorizon; i++)
    {
        data[i*5] = rates[i].close;
        data[i*5+1] = rates[i].open;
        data[i*5+2] = rates[i].high;
        data[i*5+3] = rates[i].low;
        data[i*5+4] = rates[i].tick_volume;
    }
    
    pyModule.SetArgument("data", data);
    pyModule.Execute("train_lstm(np.array(data).reshape(-1, 5))");
    
    double predictions[];
    ArrayResize(predictions, LSTMPredictionHorizon);
    
    for(int i = 0; i < LSTMPredictionHorizon; i++)
    {
        pyModule.SetArgument("data", data);
        pyModule.Execute("prediction = predict_lstm(np.array(data).reshape(-1, 5))");
        predictions[i] = pyModule.GetDouble("prediction");
        
        // Shift data for next prediction
        for(int j = 0; j < (LSTMSequenceLength + LSTMPredictionHorizon - 1) * 5; j++)
        {
            data[j] = data[j+5];
        }
        data[(LSTMSequenceLength + LSTMPredictionHorizon - 1) * 5] = predictions[i];
        // Fill other features with last known values
        for(int k = 1; k < 5; k++)
        {
            data[(LSTMSequenceLength + LSTMPredictionHorizon - 1) * 5 + k] = data[(LSTMSequenceLength + LSTMPredictionHorizon - 2) * 5 + k];
        }
    }
    
    return predictions;
}

//+------------------------------------------------------------------+
//| Update market data                                               |
//+------------------------------------------------------------------+
bool UpdateMarketData()
{
    return CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) == 1;
}

//+------------------------------------------------------------------+
//| Calculate position size using Kelly Criterion                    |
//+------------------------------------------------------------------+
double CalculateKellyPositionSize()
{
    double winRate = stats.totalTrades > 0 ? (double)stats.winningTrades / stats.totalTrades : 0.5;
    double avgWin = stats.winningTrades > 0 ? stats.totalProfit / stats.winningTrades : 1;
    double avgLoss = stats.losingTrades > 0 ? stats.totalLoss / stats.losingTrades : 1;
    
    double kellyFraction = (winRate * avgWin - (1 - winRate) * avgLoss) / avgWin;
    
    // Limit the Kelly fraction to a maximum of 2% of the account balance
    kellyFraction = MathMin(kellyFraction, 0.02);
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double positionSize = accountBalance * kellyFraction;
    
    // Convert position size to lots
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    double lots = MathFloor(positionSize / (SymbolInfoDouble(_Symbol, SYMBOL_ASK) * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE)) / lotStep) * lotStep;
    
    return MathMax(MathMin(lots, maxLot), minLot);
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
//| Implement trailing stop                                          |
//+------------------------------------------------------------------+
void ImplementTrailingStop()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentStopLoss = PositionGetDouble(POSITION_SL);
                double currentTakeProfit = PositionGetDouble(POSITION_TP);
                
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                {
                    double newStopLoss = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID) - atrBuffer[0] * 2, _Digits);
                    if(newStopLoss > currentStopLoss && newStopLoss < SymbolInfoDouble(_Symbol, SYMBOL_BID))
                    {
                        trade.PositionModify(PositionGetTicket(i), newStopLoss, currentTakeProfit);
                    }
                }
                else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                {
                    double newStopLoss = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + atrBuffer[0] * 2, _Digits);
                    if(newStopLoss < currentStopLoss && newStopLoss > SymbolInfoDouble(_Symbol, SYMBOL_ASK))
                    {
                        trade.PositionModify(PositionGetTicket(i), newStopLoss, currentTakeProfit);
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
}

//+------------------------------------------------------------------+
//| Print trade statistics                                           |
//+------------------------------------------------------------------+
void PrintTradeStats()
{
    double winRate = stats.totalTrades > 0 ? (double)stats.winningTrades / stats.totalTrades * 100 : 0;
    double profitFactor = stats.totalLoss > 0 ? stats.totalProfit / stats.totalLoss : 0;
    
    Print("=== Moran Flipper v1.3 Trade Statistics ===");
    Print("Total Trades: ", stats.totalTrades);
    Print("Winning Trades: ", stats.winningTrades);
    Print("Losing Trades: ", stats.losingTrades);
    Print("Win Rate: ", DoubleToString(winRate, 2), "%");
    Print("Total Profit: ", DoubleToString(stats.totalProfit, 2));
    Print("Total Loss: ", DoubleToString(stats.totalLoss, 2));
    Print("Profit Factor: ", DoubleToString(profitFactor, 2));
    Print("==========================================");
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
            // Potential bearish order
//+------------------------------------------------------------------+
//| Identify Fair Value Gap for Short Entries                        |
//+------------------------------------------------------------------+
bool IdentifyFairValueGapShort()
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, SMC_FVG_Lookback, high) != SMC_FVG_Lookback) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, SMC_FVG_Lookback, low) != SMC_FVG_Lookback) return false;
    
    // Look for bearish FVG
    for(int i = 1; i < SMC_FVG_Lookback - 1; i++)
    {
        if(high[i-1] < low[i+1])
        {
            // Bearish FVG found
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Identify Break of Structure for Short Entries                    |
//+------------------------------------------------------------------+
bool IdentifyBreakOfStructureShort()
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, high) != SMC_OB_Lookback) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, low) != SMC_OB_Lookback) return false;
    
    // Look for bearish break of structure
    double highestHigh = high[ArrayMaximum(high, 0, SMC_OB_Lookback)];
    if(high[0] > highestHigh && low[1] < low[2])
    {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Strategy: Supply and Demand for Short Entries                    |
//+------------------------------------------------------------------+
bool CheckSupplyDemandEntryShort()
{
    if(IsPriceInSupplyZone() && IsDowntrendConfirmed())
    {
        return true;
    }
    return false;
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
    double supplyZoneLower = IdentifyRecentHigh(close, 100) * 0.995; // 0.5% below recent high
    double supplyZoneUpper = IdentifyRecentHigh(close, 100) * 1.005; // 0.5% above recent high
    
    return (currentPrice >= supplyZoneLower && currentPrice <= supplyZoneUpper);
}

//+------------------------------------------------------------------+
//| Identify recent high price                                       |
//+------------------------------------------------------------------+
double IdentifyRecentHigh(const double &price[], int count)
{
    return price[ArrayMaximum(price, 0, count)];
}

//+------------------------------------------------------------------+
//| Confirm downtrend                                                |
//+------------------------------------------------------------------+
bool IsDowntrendConfirmed()
{
    double ma[], close[];
    ArraySetAsSeries(ma, true);
    ArraySetAsSeries(close, true);
    
    int maHandle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    if(maHandle == INVALID_HANDLE) return false;
    
    if(CopyBuffer(maHandle, 0, 0, 3, ma) != 3) return false;
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 3, close) != 3) return false;
    
    IndicatorRelease(maHandle);
    
    // Price below MA and MA sloping downwards
    return (close[0] < ma[0] && ma[0] < ma[1] && ma[1] < ma[2]);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize ATR indicator
    atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(atrHandle == INVALID_HANDLE) return(INIT_FAILED);
    
    ArraySetAsSeries(atrBuffer, true);
    
    // Initialize Python environment
    if(!InitializePython())
    {
        Print("Failed to initialize Python environment");
        return(INIT_FAILED);
    }
    
    // Initialize trade statistics
    stats.totalTrades = 0;
    stats.winningTrades = 0;
    stats.losingTrades = 0;
    stats.totalProfit = 0;
    stats.totalLoss = 0;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(atrHandle);
    pyModule.Finalize();
    
    // Print final trade statistics
    PrintTradeStats();
}