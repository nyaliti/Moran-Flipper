//+------------------------------------------------------------------+
//|                                        MoranFlipper_v2.3.mq5     |
//|                                 Copyright 2023, Bryson N. Omullo |
//|                                     https://github.com/nyaliti   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Bryson N. Omullo"
#property link      "https://github.com/nyaliti"
#property version   "2.30"

#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Indicators\Trend.mqh>
#include <Math\Stat\Math.mqh>

// Input parameters
input double RiskPercent = 1.0;  // Risk per trade as a percentage of balance
input int ATRPeriod = 14;        // Period for ATR calculation
input int FiboPeriod = 34;       // Period for Fibonacci calculations
input int SMC_Lookback = 100;    // Lookback period for Smart Money Concepts
input ENUM_TIMEFRAMES TimeframeHigh = PERIOD_H4;   // Higher timeframe
input ENUM_TIMEFRAMES TimeframeMid = PERIOD_H1;    // Middle timeframe
input ENUM_TIMEFRAMES TimeframeLow = PERIOD_M15;   // Lower timeframe
input bool UseSMC = true;        // Use Smart Money Concepts
input bool UseSupplyDemand = true; // Use Supply and Demand zones
input bool UseFibonacci = true;  // Use Fibonacci retracements
input bool UseChartPatterns = true; // Use Chart Pattern recognition
input int OptimizationPeriod = 5000; // Number of bars for walk-forward optimization
input string[] TradingPairs = {"EURUSD", "GBPUSD", "USDJPY", "AUDUSD"}; // Trading pairs for portfolio management
input string FinnhubAPIKey = "ct24c3hr01qoprggvf6gct24c3hr01qoprggvf70"; // Finnhub API key for economic data
input double MaxDrawdownPercent = 20.0; // Maximum allowed drawdown percentage
input int VolatilityPeriod = 20; // Period for volatility calculation
input double VolatilityThreshold = 1.5; // Volatility threshold for trade entries
input bool UseTrailingStop = true; // Use trailing stop
input double TrailingStopMultiplier = 2.0; // Trailing stop distance as ATR multiplier

// Global variables
CTrade trade;
int atrHandle;
double atrBuffer[];
datetime lastOptimizationTime = 0;
int fundamentalImpact = 0; // -1: Negative, 0: Neutral, 1: Positive
double pairCorrelations[4][4]; // Correlation matrix for trading pairs
int momentumHandles[3];
double momentumBuffers[3][];
int marketRegime = 0; // 0: Ranging, 1: Trending Up, -1: Trending Down
double initialBalance;
double maxDrawdown;

// Structure to hold optimization parameters
struct OptimizationParams
{
    int ATRPeriod;
    int FiboPeriod;
    int SMC_Lookback;
};

OptimizationParams currentParams;

// Structure to hold backtesting results
struct BacktestResults
{
    double totalProfit;
    double maxDrawdown;
    int totalTrades;
    double winRate;
    double profitFactor;
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
    
    // Initialize momentum indicators
    momentumHandles[0] = iMomentum(_Symbol, TimeframeHigh, 14, PRICE_CLOSE);
    momentumHandles[1] = iMomentum(_Symbol, TimeframeMid, 14, PRICE_CLOSE);
    momentumHandles[2] = iMomentum(_Symbol, TimeframeLow, 14, PRICE_CLOSE);
    
    for(int i = 0; i < 3; i++)
    {
        if(momentumHandles[i] == INVALID_HANDLE) return(INIT_FAILED);
        ArraySetAsSeries(momentumBuffers[i], true);
    }
    
    // Initialize current optimization parameters
    currentParams.ATRPeriod = ATRPeriod;
    currentParams.FiboPeriod = FiboPeriod;
    currentParams.SMC_Lookback = SMC_Lookback;
    
    // Initialize pair correlations
    UpdatePairCorrelations();
    
    // Initialize drawdown tracking
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    maxDrawdown = 0;
    
    Print("Moran Flipper v2.3 initialized successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(atrHandle);
    for(int i = 0; i < 3; i++)
    {
        IndicatorRelease(momentumHandles[i]);
    }
    Print("Moran Flipper v2.3 deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!UpdateMarketData()) return;
    
    // Check for maximum drawdown
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double currentDrawdown = (initialBalance - currentBalance) / initialBalance * 100;
    if(currentDrawdown > maxDrawdown) maxDrawdown = currentDrawdown;
    
    if(maxDrawdown > MaxDrawdownPercent)
    {
        Print("Maximum drawdown reached. Stopping trading.");
        ExpertRemove();
        return;
    }
    
    // Perform walk-forward optimization if needed
    if(TimeCurrent() - lastOptimizationTime > PeriodSeconds(PERIOD_D1))
    {
        PerformWalkForwardOptimization();
        lastOptimizationTime = TimeCurrent();
    }
    
    // Update fundamental analysis impact
    UpdateFundamentalImpact();
    
    // Update pair correlations
    UpdatePairCorrelations();
    
    // Detect market regime
    DetectMarketRegime();
    
    // Manage portfolio
    ManagePortfolio();
    
    // Check if it's a suitable trading session
    if(!IsSuitableTradingSession()) return;
    
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
    else if(UseChartPatterns && CheckChartPatterns(isLong))
        entrySignal = true;
    
    // Consider fundamental impact
    if(fundamentalImpact != 0)
    {
        if(fundamentalImpact > 0 && !isLong) entrySignal = false;
        if(fundamentalImpact < 0 && isLong) entrySignal = false;
    }
    
    // Check volatility filter
    if(!CheckVolatilityFilter()) entrySignal = false;
    
    if(entrySignal)
    {
        double lotSize = CalculatePositionSize(isLong);
        if(CheckRiskManagement(lotSize) && CheckCorrelationFilter(_Symbol))
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
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) != 1) return false;
    
    for(int i = 0; i < 3; i++)
    {
        if(CopyBuffer(momentumHandles[i], 0, 0, 2, momentumBuffers[i]) != 2) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Perform walk-forward optimization                                |
//+------------------------------------------------------------------+
void PerformWalkForwardOptimization()
{
    // Implementation remains the same as in v2.2
}

//+------------------------------------------------------------------+
//| Backtest strategy with given parameters                          |
//+------------------------------------------------------------------+
BacktestResults BacktestStrategy(const OptimizationParams &params)
{
    // Implementation remains the same as in v2.2
}

//+------------------------------------------------------------------+
//| Update fundamental analysis impact                               |
//+------------------------------------------------------------------+
void UpdateFundamentalImpact()
{
    string economicData = FetchEconomicData();
    fundamentalImpact = AnalyzeEconomicData(economicData);
}

//+------------------------------------------------------------------+
//| Fetch economic data from Finnhub                                 |
//+------------------------------------------------------------------+
string FetchEconomicData()
{
    // Implementation remains the same as in v2.2
}

//+------------------------------------------------------------------+
//| Analyze economic data                                            |
//+------------------------------------------------------------------+
int AnalyzeEconomicData(string economicData)
{
    // Implementation remains the same as in v2.2
}

//+------------------------------------------------------------------+
//| Detect market regime                                             |
//+------------------------------------------------------------------+
void DetectMarketRegime()
{
    double maFast[], maSlow[];
    ArraySetAsSeries(maFast, true);
    ArraySetAsSeries(maSlow, true);
    
    int maFastHandle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    int maSlowHandle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    
    if(CopyBuffer(maFastHandle, 0, 0, 3, maFast) != 3 || CopyBuffer(maSlowHandle, 0, 0, 3, maSlow) != 3)
    {
        Print("Failed to copy MA data");
        return;
    }
    
    if(maFast[0] > maSlow[0] && maFast[1] > maSlow[1] && maFast[2] > maSlow[2])
        marketRegime = 1; // Trending Up
    else if(maFast[0] < maSlow[0] && maFast[1] < maSlow[1] && maFast[2] < maSlow[2])
        marketRegime = -1; // Trending Down
    else
        marketRegime = 0; // Ranging
    
    IndicatorRelease(maFastHandle);
    IndicatorRelease(maSlowHandle);
}

//+------------------------------------------------------------------+
//| Check if it's a suitable trading session                         |
//+------------------------------------------------------------------+
bool IsSuitableTradingSession()
{
    datetime currentTime = TimeCurrent();
    int currentHour = TimeHour(currentTime);
    
    // Avoid trading during low-liquidity periods (e.g., 22:00 - 02:00 GMT)
    if(currentHour >= 22 || currentHour < 2)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check volatility filter                                          |
//+------------------------------------------------------------------+
bool CheckVolatilityFilter()
{
    double volatility = iATR(_Symbol, PERIOD_CURRENT, VolatilityPeriod, 0);
    double averageVolatility = 0;
    
    for(int i = 1; i <= VolatilityPeriod; i++)
    {
        averageVolatility += iATR(_Symbol, PERIOD_CURRENT, VolatilityPeriod, i);
    }
    averageVolatility /= VolatilityPeriod;
    
    return (volatility > averageVolatility * VolatilityThreshold);
}

//+------------------------------------------------------------------+
//| Calculate position size using Kelly Criterion                    |
//+------------------------------------------------------------------+
double CalculatePositionSize(bool isLong)
{
    double winRate = CalculateWinRate();
    double avgWin = CalculateAverageWin();
    double avgLoss = CalculateAverageLoss();
    
    double kellyFraction = (winRate * avgWin - (1 - winRate) * avgLoss) / avgWin;
    kellyFraction = MathMax(0, MathMin(kellyFraction, 0.5)); // Limit Kelly fraction between 0 and 0.5
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * RiskPercent / 100;
    double kellyRiskAmount = accountBalance * kellyFraction;
    
    double riskAmountToUse = MathMin(riskAmount, kellyRiskAmount);
    
    double lotSize = NormalizeDouble(riskAmountToUse / (atrBuffer[0] * 100000), 2);
    
    // Adjust lot size based on market regime
    if(marketRegime == 0) // Ranging market
        lotSize *= 0.5;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate win rate based on recent trades                        |
//+------------------------------------------------------------------+
double CalculateWinRate()
{
    int totalTrades = 0;
    int winningTrades = 0;
    
    for(int i = HistoryDealsTotal() - 1; i >= MathMax(0, HistoryDealsTotal() - 100); i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealSelect(ticket) && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
        {
            totalTrades++;
            if(HistoryDealGetDouble(ticket, DEAL_PROFIT) > 0)
                winningTrades++;
        }
    }
    
    return totalTrades > 0 ? (double)winningTrades / totalTrades : 0.5;
}

//+------------------------------------------------------------------+
//| Calculate average win based on recent trades                     |
//+------------------------------------------------------------------+
double CalculateAverageWin()
{
    double totalWin = 0;
    int winningTrades = 0;
    
    for(int i = HistoryDealsTotal() - 1; i >= MathMax(0, HistoryDealsTotal() - 100); i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealSelect(ticket) && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
        {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if(profit > 0)
            {
                totalWin += profit;
                winningTrades++;
            }
        }
    }
    
    return winningTrades > 0 ? totalWin / winningTrades : 1;
}

//+------------------------------------------------------------------+
//| Calculate average loss based on recent trades                    |
//+------------------------------------------------------------------+
double CalculateAverageLoss()
{
    double totalLoss = 0;
    int losingTrades = 0;
    
    for(int i = HistoryDealsTotal() - 1; i >= MathMax(0, HistoryDealsTotal() - 100); i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealSelect(ticket) && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
        {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if(profit < 0)
            {
                totalLoss += MathAbs(profit);
                losingTrades++;
            }
        }
    }
    
    return losingTrades > 0 ? totalLoss / losingTrades : 1;
}

//+------------------------------------------------------------------+
//| Manage portfolio of multiple trading pairs                       |
//+------------------------------------------------------------------+
void ManagePortfolio()
{
    // Implementation remains the same as in v2.2
}

//+------------------------------------------------------------------+
//| Open a buy trade                                                 |
//+------------------------------------------------------------------+
void OpenBuyTrade(double lotSize)
{
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double stopLoss = CalculateDynamicStopLoss(true);
    double takeProfit = CalculateDynamicTakeProfit(true);
    
    trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v2.3");
}

//+------------------------------------------------------------------+
//| Open a sell trade                                                |
//+------------------------------------------------------------------+
void OpenSellTrade(double lotSize)
{
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = CalculateDynamicStopLoss(false);
    double takeProfit = CalculateDynamicTakeProfit(false);
    
    trade.Sell(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v2.3");
}

//+------------------------------------------------------------------+
//| Calculate dynamic stop loss                                      |
//+------------------------------------------------------------------+
double CalculateDynamicStopLoss(bool isBuy)
{
    double atr = atrBuffer[0];
    double stopLossDistance = atr * 2;
    
    if(isBuy)
        return SymbolInfoDouble(_Symbol, SYMBOL_ASK) - stopLossDistance;
    else
        return SymbolInfoDouble(_Symbol, SYMBOL_BID) + stopLossDistance;
}

//+------------------------------------------------------------------+
//| Calculate dynamic take profit                                    |
//+------------------------------------------------------------------+
double CalculateDynamicTakeProfit(bool isBuy)
{
    double atr = atrBuffer[0];
    double takeProfitDistance = atr * 3;
    
    if(isBuy)
        return SymbolInfoDouble(_Symbol, SYMBOL_ASK) + takeProfitDistance;
    else
        return SymbolInfoDouble(_Symbol, SYMBOL_BID) - takeProfitDistance;
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
                if(UseTrailingStop && positionProfit > 0)
                {
                    double newStopLoss = CalculateTrailingStop(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
                    
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
//| Calculate trailing stop level                                    |
//+------------------------------------------------------------------+
double CalculateTrailingStop(bool isBuy)
{
    double atr = atrBuffer[0];
    double trailingDistance = atr * TrailingStopMultiplier;
    
    if(isBuy)
        return SymbolInfoDouble(_Symbol, SYMBOL_BID) - trailingDistance;
    else
        return SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trailingDistance;
}

//+------------------------------------------------------------------+
//| Check risk management for a trade                                |
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
//| Update correlation matrix for trading pairs                      |
//+------------------------------------------------------------------+
void UpdatePairCorrelations()
{
    // Implementation remains the same as in v2.2
}

//+------------------------------------------------------------------+
//| Check correlation filter for a symbol                            |
//+------------------------------------------------------------------+
bool CheckCorrelationFilter(string symbol)
{
    // Implementation remains the same as in v2.2
}

//+------------------------------------------------------------------+
//| Analyze trend across multiple timeframes                         |
//+------------------------------------------------------------------+
int AnalyzeTrendMultiTimeframe()
{
    int trendHigh = momentumBuffers[0][0] > momentumBuffers[0][1] ? 1 : -1;
    int trendMid = momentumBuffers[1][0] > momentumBuffers[1][1] ? 1 : -1;
    int trendLow = momentumBuffers[2][0] > momentumBuffers[2][1] ? 1 : -1;
    
    if(trendHigh == trendMid && trendMid == trendLow)
        return trendHigh;
    if((trendHigh == trendMid) || (trendHigh == trendLow))
        return trendHigh;
    if(trendMid == trendLow)
        return trendMid;
    
    return 0; // No clear trend
}

// ... (The rest of the functions like CheckSMCEntry, CheckSupplyDemandEntry, CheckFibonacciEntry, and CheckChartPatterns remain the same as in v2.2)