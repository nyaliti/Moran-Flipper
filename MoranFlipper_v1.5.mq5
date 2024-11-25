//+------------------------------------------------------------------+
//|                                             MoranFlipper_v1.5.mq5 |
//|                                 Copyright 2023, Bryson N. Omullo |
//|                                     https://github.com/nyaliti |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Bryson N. Omullo"
#property link      "https://github.com/nyaliti"
#property version   "1.50"

#include <Trade\Trade.mqh>
#include <Math\Stat\Math.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Python\Python.mqh>
#include <Generic\HashMap.mqh>

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
input string[] TradingPairs = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD"}; // Trading pairs
input int RSIPeriod = 14;        // Period for RSI
input int StochasticKPeriod = 14; // K period for Stochastic
input int StochasticDPeriod = 3;  // D period for Stochastic
input int StochasticSlowing = 3;  // Slowing for Stochastic
input int OptimizationPeriod = 1000; // Number of bars for optimization
input int ValidationPeriod = 500;    // Number of bars for validation after optimization

// Global variables and objects
CTrade trade;
CHashMap<string, int> atrHandles, rsiHandles, stochHandles;
CHashMap<string, double[]> atrBuffers, rsiBuffers, stochMainBuffers, stochSignalBuffers;
CPython pyModule;
datetime lastOptimizationTime = 0;

struct TradeStats
{
    int totalTrades;
    int winningTrades;
    int losingTrades;
    double totalProfit;
    double totalLoss;
};

CHashMap<string, TradeStats> pairStats;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize indicators for each trading pair
    for(int i = 0; i < ArraySize(TradingPairs); i++)
    {
        string symbol = TradingPairs[i];
        
        int atrHandle = iATR(symbol, PERIOD_CURRENT, ATRPeriod);
        int rsiHandle = iRSI(symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
        int stochHandle = iStochastic(symbol, PERIOD_CURRENT, StochasticKPeriod, StochasticDPeriod, StochasticSlowing, MODE_SMA, STO_LOWHIGH);
        
        if(atrHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || stochHandle == INVALID_HANDLE)
            return(INIT_FAILED);
        
        atrHandles.Add(symbol, atrHandle);
        rsiHandles.Add(symbol, rsiHandle);
        stochHandles.Add(symbol, stochHandle);
        
        double atrBuffer[], rsiBuffer[], stochMainBuffer[], stochSignalBuffer[];
        ArraySetAsSeries(atrBuffer, true);
        ArraySetAsSeries(rsiBuffer, true);
        ArraySetAsSeries(stochMainBuffer, true);
        ArraySetAsSeries(stochSignalBuffer, true);
        
        atrBuffers.Add(symbol, atrBuffer);
        rsiBuffers.Add(symbol, rsiBuffer);
        stochMainBuffers.Add(symbol, stochMainBuffer);
        stochSignalBuffers.Add(symbol, stochSignalBuffer);
        
        // Initialize trade statistics for each pair
        TradeStats stats = {0, 0, 0, 0.0, 0.0};
        pairStats.Add(symbol, stats);
    }
    
    // Initialize Python environment
    if(!InitializePython())
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
    // Release indicator handles
    for(int i = 0; i < ArraySize(TradingPairs); i++)
    {
        string symbol = TradingPairs[i];
        IndicatorRelease(atrHandles.GetValueAt(i));
        IndicatorRelease(rsiHandles.GetValueAt(i));
        IndicatorRelease(stochHandles.GetValueAt(i));
    }
    
    pyModule.Finalize();
    
    // Print final trade statistics for each pair
    for(int i = 0; i < ArraySize(TradingPairs); i++)
    {
        string symbol = TradingPairs[i];
        PrintTradeStats(symbol);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(IsHighImpactNewsTime())
    {
        Print("High-impact news event detected. Avoiding new trades.");
        return;
    }
    
    // Perform adaptive parameter optimization
    if(TimeCurrent() - lastOptimizationTime > PeriodSeconds(PERIOD_D1))
    {
        PerformAdaptiveOptimization();
        lastOptimizationTime = TimeCurrent();
    }
    
    // Loop through all trading pairs
    for(int i = 0; i < ArraySize(TradingPairs); i++)
    {
        string symbol = TradingPairs[i];
        
        if(!UpdateMarketData(symbol)) continue;
        
        int marketTrend = AnalyzeTrendMultiTimeframe(symbol);
        double[] lstmPrediction = PredictWithLSTM(symbol);
        double sentimentScore = AnalyzeSentiment();
        
        bool entrySignal = false;
        bool isLong = false;
        
        if(lstmPrediction[0] > 0 && marketTrend > 0 && sentimentScore > 0.5)
        {
            entrySignal = CheckSMCEntry(symbol, true) || CheckSupplyDemandEntry(symbol, true) || CheckAdditionalIndicators(symbol, true);
            isLong = true;
        }
        else if(lstmPrediction[0] < 0 && marketTrend < 0 && sentimentScore < -0.5)
        {
            entrySignal = CheckSMCEntry(symbol, false) || CheckSupplyDemandEntry(symbol, false) || CheckAdditionalIndicators(symbol, false);
            isLong = false;
        }
        
        if(entrySignal)
        {
            double lotSize = CalculatePositionSize(symbol, isLong);
            if(CheckAdvancedRiskManagement(symbol, lotSize, isLong))
            {
                if(isLong)
                {
                    double entryPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
                    double stopLoss = CalculateDynamicStopLoss(symbol, true);
                    double takeProfit = CalculateDynamicTakeProfit(symbol, true);
                    
                    if(trade.Buy(lotSize, symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v1.5"))
                    {
                        LogTrade(symbol, "BUY", lotSize, entryPrice, stopLoss, takeProfit);
                    }
                }
                else
                {
                    double entryPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
                    double stopLoss = CalculateDynamicStopLoss(symbol, false);
                    double takeProfit = CalculateDynamicTakeProfit(symbol, false);
                    
                    if(trade.Sell(lotSize, symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v1.5"))
                    {
                        LogTrade(symbol, "SELL", lotSize, entryPrice, stopLoss, takeProfit);
                    }
                }
            }
        }
        
        ManageOpenPositions(symbol);
        ImplementTrailingStop(symbol);
        
        // Update trade statistics
        UpdateTradeStats(symbol);
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
        "from textblob import TextBlob\n"
        "import requests\n"
        "from stable_baselines3 import PPO\n"
        "\n"
        "# LSTM model\n"
        "lstm_model = Sequential([\n"
        "    LSTM(50, activation='relu', input_shape=(60, 5)),\n"
        "    Dense(1)\n"
        "])\n"
        "lstm_model.compile(optimizer='adam', loss='mse')\n"
        "\n"
        "scaler = MinMaxScaler(feature_range=(-1, 1))\n"
        "\n"
        "# Reinforcement Learning model\n"
        "rl_model = PPO('MlpPolicy', 'CartPole-v1', verbose=1)\n"
        "\n"
        "def train_lstm(data):\n"
        "    scaled_data = scaler.fit_transform(data)\n"
        "    X, y = [], []\n"
        "    for i in range(60, len(scaled_data)):\n"
        "        X.append(scaled_data[i-60:i])\n"
        "        y.append(scaled_data[i, 0])\n"
        "    X, y = np.array(X), np.array(y)\n"
        "    lstm_model.fit(X, y, epochs=50, batch_size=32, verbose=0)\n"
        "\n"
        "def predict_lstm(data):\n"
        "    scaled_data = scaler.transform(data)\n"
        "    X = np.array([scaled_data[-60:]])\n"
        "    scaled_prediction = lstm_model.predict(X)\n"
        "    return scaler.inverse_transform(scaled_prediction)[0, 0]\n"
        "\n"
        "def analyze_sentiment(text):\n"
        "    blob = TextBlob(text)\n"
        "    return blob.sentiment.polarity\n"
        "\n"
        "def fetch_news():\n"
        "    url = 'https://newsapi.org/v2/top-headlines?category=business&language=en&apiKey=YOUR_API_KEY'\n"
        "    response = requests.get(url)\n"
        "    if response.status_code == 200:\n"
        "        news = response.json()['articles']\n"
        "        return ' '.join([article['title'] + ' ' + article['description'] for article in news if article['description']])\n"
        "    return ''\n"
        "\n"
        "def rl_predict(state):\n"
        "    action, _ = rl_model.predict(state)\n"
        "    return action\n"
        "\n"
        "def rl_train(states, actions, rewards):\n"
        "    rl_model.learn(total_timesteps=1000)\n";
    
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
double[] PredictWithLSTM(string symbol)
{
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(symbol, PERIOD_CURRENT, 0, LSTMSequenceLength + LSTMPredictionHorizon, rates);
    
    if(copied != LSTMSequenceLength + LSTMPredictionHorizon)
    {
        Print("Failed to copy price data for ", symbol);
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
//| Analyze sentiment using NLP                                      |
//+------------------------------------------------------------------+
double AnalyzeSentiment()
{
    pyModule.Execute("news_text = fetch_news()");
    pyModule.Execute("sentiment_score = analyze_sentiment(news_text)");
    return pyModule.GetDouble("sentiment_score");
}

//+------------------------------------------------------------------+
//| Check additional technical indicators                            |
//+------------------------------------------------------------------+
bool CheckAdditionalIndicators(string symbol, bool isLong)
{
    double rsiBuffer[], stochMainBuffer[], stochSignalBuffer[];
    rsiBuffers.TryGetValue(symbol, rsiBuffer);
    stochMainBuffers.TryGetValue(symbol, stochMainBuffer);
    stochSignalBuffers.TryGetValue(symbol, stochSignalBuffer);
    
    if(CopyBuffer(rsiHandles[symbol], 0, 0, 1, rsiBuffer) != 1) return false;
    if(CopyBuffer(stochHandles[symbol], MAIN_LINE, 0, 1, stochMainBuffer) != 1) return false;
    if(CopyBuffer(stochHandles[symbol], SIGNAL_LINE, 0, 1, stochSignalBuffer) != 1) return false;
    
    if(isLong)
    {
        return (rsiBuffer[0] < 30 && stochMainBuffer[0] < 20 && stochMainBuffer[0] > stochSignalBuffer[0]);
    }
    else
    {
        return (rsiBuffer[0] > 70 && stochMainBuffer[0] > 80 && stochMainBuffer[0] < stochSignalBuffer[0]);
    }
}

//+------------------------------------------------------------------+
//| Advanced risk management considering correlations                |
//+------------------------------------------------------------------+
bool CheckAdvancedRiskManagement(string symbol, double lotSize, bool isLong)
{
    double totalRisk = 0;
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    // Calculate risk of existing positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            string positionSymbol = PositionGetString(POSITION_SYMBOL);
            double positionLotSize = PositionGetDouble(POSITION_VOLUME);
            double positionRisk = (PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_SL)) * positionLotSize * SymbolInfoDouble(positionSymbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(positionSymbol, SYMBOL_POINT);
            
            // Adjust risk based on correlation
            double correlation = CalculateCorrelation(symbol, positionSymbol);
            totalRisk += positionRisk * (1 - MathAbs(correlation));
        }
    }
    
    // Calculate risk of new position
    double atrBuffer[];
    atrBuffers.TryGetValue(symbol, atrBuffer);
    double newPositionRisk = atrBuffer[0] * 2 * lotSize * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(symbol, SYMBOL_POINT);
    totalRisk += newPositionRisk;
    
    // Check if total risk exceeds 2% of account balance
    if(totalRisk > accountBalance * 0.02)
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate correlation between two symbols                        |
//+------------------------------------------------------------------+
double CalculateCorrelation(string symbol1, string symbol2)
{
    int period = 100;
    double close1[], close2[];
    ArraySetAsSeries(close1, true);
    ArraySetAsSeries(close2, true);
    
    if(CopyClose(symbol1, PERIOD_H1, 0, period, close1) != period) return 0;
    if(CopyClose(symbol2, PERIOD_H1, 0, period, close2) != period) return 0;
    
    return MathCorrelation(close1, close2, period);
}

//+------------------------------------------------------------------+
//| Perform adaptive parameter optimization                          |
//+------------------------------------------------------------------+
void PerformAdaptiveOptimization()
{
    Print("Performing adaptive parameter optimization");
    
    // Example: Optimize ATR period for each symbol
    for(int i = 0; i < ArraySize(TradingPairs); i++)
    {
        string symbol = TradingPairs[i];
        double bestProfitFactor = 0;
        int bestATRPeriod = ATRPeriod;
        
        for(int testPeriod = 10; testPeriod <= 30; testPeriod += 2)
        {
            double profitFactor = SimulateTrades(symbol, testPeriod);
            if(profitFactor > bestProfitFactor)
            {
                bestProfitFactor = profitFactor;
                bestATRPeriod = testPeriod;
            }
        }
        
        // Update the ATR period for this symbol
        IndicatorRelease(atrHandles[symbol]);
        atrHandles[symbol] = iATR(symbol, PERIOD_CURRENT, bestATRPeriod);
        
        Print("Optimized ATR Period for ", symbol, ": ", bestATRPeriod);
    }
}

//+------------------------------------------------------------------+
//| Simulate trades for optimization                                 |
//+------------------------------------------------------------------+
double SimulateTrades(string symbol, int testATRPeriod)
{
    // Implement your trade simulation logic here
    // This is a placeholder function and should be customized based on your specific needs
    
    double totalProfit = 0;
    double totalLoss = 0;
    
    int bars = OptimizationPeriod + ValidationPeriod;
    
    for(int i = bars - 1; i >= 0; i--)
    {
        // Simulate your trading logic here
        // Use testATRPeriod instead of ATRPeriod
        
        // Example (not real trading logic):
        if(i % 10 == 0)  // Simulate a trade every 10 bars
        {
            double tradeResult = (MathRand() % 2 == 0) ? 100 : -80;  // Simulate win/loss
            if(tradeResult > 0)
                totalProfit += tradeResult;
            else
                totalLoss += MathAbs(tradeResult);
        }
    }
    
    return (totalLoss > 0) ? totalProfit / totalLoss : 0;
}

//+------------------------------------------------------------------+
//| Calculate position size using Kelly Criterion                    |
//+------------------------------------------------------------------+
double CalculatePositionSize(string symbol, bool isLong)
{
    TradeStats stats;
    pairStats.TryGetValue(symbol, stats);
    
    double winRate = stats.totalTrades > 0 ? (double)stats.winningTrades / stats.totalTrades : 0.5;
    double avgWin = stats.winningTrades > 0 ? stats.totalProfit / stats.winningTrades : 1;
    double avgLoss = stats.losingTrades > 0 ? stats.totalLoss / stats.losingTrades : 1;
    
    double kellyFraction = (winRate * avgWin - (1 - winRate) * avgLoss) / avgWin;
    
    // Limit the Kelly fraction to a maximum of 2% of the account balance
    kellyFraction = MathMin(kellyFraction, 0.02);
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double positionSize = accountBalance * kellyFraction;
    
    // Adjust position size based on market volatility
    double atrBuffer[];
    atrBuffers.TryGetValue(symbol, atrBuffer);
    double volatilityAdjustment = atrBuffer[0] / iATR(symbol, PERIOD_D1, 14);
    positionSize *= (1 / volatilityAdjustment);
    
    // Convert position size to lots
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    
    double lots = MathFloor(positionSize / (SymbolInfoDouble(symbol, SYMBOL_ASK) * SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE)) / lotStep) * lotStep;
    
    return MathMax(MathMin(lots, maxLot), minLot);
}

//+------------------------------------------------------------------+
//| Update market data                                               |
//+------------------------------------------------------------------+
bool UpdateMarketData(string symbol)
{
    double atrBuffer[], rsiBuffer[], stochMainBuffer[], stochSignalBuffer[];
    atrBuffers.TryGetValue(symbol, atrBuffer);
    rsiBuffers.TryGetValue(symbol, rsiBuffer);
    stochMainBuffers.TryGetValue(symbol, stochMainBuffer);
    stochSignalBuffers.TryGetValue(symbol, stochSignalBuffer);
    
    return CopyBuffer(atrHandles[symbol], 0, 0, 1, atrBuffer) == 1 &&
           CopyBuffer(rsiHandles[symbol], 0, 0, 1, rsiBuffer) == 1 &&
           CopyBuffer(stochHandles[symbol], MAIN_LINE, 0, 1, stochMainBuffer) == 1 &&
           CopyBuffer(stochHandles[symbol], SIGNAL_LINE, 0, 1, stochSignalBuffer) == 1;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions(string symbol)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) == symbol)
            {
                double positionProfit = PositionGetDouble(POSITION_PROFIT);
                double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
                
                // Implement trailing stop
                if(positionProfit > 0)
                {
                    double atrBuffer[];
                    atrBuffers.TryGetValue(symbol, atrBuffer);
                    double newStopLoss = NormalizeDouble(currentPrice - atrBuffer[0], SymbolInfoInteger(symbol, SYMBOL_DIGITS));
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
void ImplementTrailingStop(string symbol)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) == symbol)
            {
                double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentStopLoss = PositionGetDouble(POSITION_SL);
                double currentTakeProfit = PositionGetDouble(POSITION_TP);
                
                double atrBuffer[];
                atrBuffers.TryGetValue(symbol, atrBuffer);
                
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                {
                    double newStopLoss = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_BID) - atrBuffer[0] * 2, SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                    if(newStopLoss > currentStopLoss && newStopLoss < SymbolInfoDouble(symbol, SYMBOL_BID))
                    {
                        trade.PositionModify(PositionGetTicket(i), newStopLoss, currentTakeProfit);
                    }
                }
                else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                {
                    double newStopLoss = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK) + atrBuffer[0] * 2, SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                    if(newStopLoss < currentStopLoss && newStopLoss > SymbolInfoDouble(symbol, SYMBOL_ASK))
                    {
                        trade.PositionModify(PositionGetTicket(i), newStopLoss, currentTakeProfit);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Log trade information                                            |
//+------------------------------------------------------------------+
void LogTrade(string symbol, string action, double lotSize, double entryPrice, double stopLoss, double takeProfit)
{
    string logMessage = StringFormat("%s: %s %s %.2f lots at %.5f, SL: %.5f, TP: %.5f", 
                                     TimeToString(TimeCurrent()), symbol, action, lotSize, entryPrice, stopLoss, takeProfit);
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
int AnalyzeTrendMultiTimeframe(string symbol)
{
    int trendHigh = IdentifyTrend(symbol, TimeframeHigh);
    int trendMid = IdentifyTrend(symbol, TimeframeMid);
    int trendLow = IdentifyTrend(symbol, TimeframeLow);
    
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

