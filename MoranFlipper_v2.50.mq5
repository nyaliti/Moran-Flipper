//+------------------------------------------------------------------+
//|                                        MoranFlipper_v2.4.mq5     |
//|                                 Copyright 2023, Bryson N. Omullo |
//|                                     https://github.com/nyaliti   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Bryson N. Omullo"
#property link      "https://github.com/nyaliti"
#property version   "2.40"

#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Indicators\Trend.mqh>
#include <Math\Stat\Math.mqh>
#include <Math\Stat\Sharpe.mqh>

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
input bool UseDynamicTimeframe = true; // Use dynamic timeframe selection
input bool UseSentimentAnalysis = true; // Use sentiment analysis for trade decisions
input int PortfolioRebalancePeriod = 7; // Days between portfolio rebalancing
input bool UseMLPrediction = true; // Use machine learning for trade entry prediction

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
ENUM_TIMEFRAMES currentTimeframe;
datetime lastRebalanceTime = 0;
int marketStrengthHandle;
double marketStrengthBuffer[];
double accountGrowthFactor = 1.0;

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
    double sharpeRatio;
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
    
    // Initialize market strength indicator
    marketStrengthHandle = iCustom(_Symbol, PERIOD_CURRENT, "Market Strength Index");
    if(marketStrengthHandle == INVALID_HANDLE) return(INIT_FAILED);
    ArraySetAsSeries(marketStrengthBuffer, true);
    
    // Initialize current optimization parameters
    currentParams.ATRPeriod = ATRPeriod;
    currentParams.FiboPeriod = FiboPeriod;
    currentParams.SMC_Lookback = SMC_Lookback;
    
    // Initialize pair correlations
    UpdatePairCorrelations();
    
    // Initialize drawdown tracking
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    maxDrawdown = 0;
    
    // Set initial timeframe
    currentTimeframe = PERIOD_CURRENT;
    
    Print("Moran Flipper v2.4 initialized successfully");
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
    IndicatorRelease(marketStrengthHandle);
    Print("Moran Flipper v2.4 deinitialized. Reason: ", reason);
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
    
    // Update account growth factor
    accountGrowthFactor = MathSqrt(currentBalance / initialBalance);
    
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
    
    // Update timeframe if using dynamic selection
    if(UseDynamicTimeframe)
    {
        currentTimeframe = SelectDynamicTimeframe();
    }
    
    // Manage portfolio
    ManagePortfolio();
    
    // Check if it's time for portfolio rebalancing
    if(TimeCurrent() - lastRebalanceTime > PeriodSeconds(PERIOD_D1) * PortfolioRebalancePeriod)
    {
        RebalancePortfolio();
        lastRebalanceTime = TimeCurrent();
    }
    
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
    
    // Check sentiment analysis
    if(UseSentimentAnalysis && !CheckSentimentAnalysis(isLong)) entrySignal = false;
    
    // Check machine learning prediction
    if(UseMLPrediction && !CheckMLPrediction(isLong)) entrySignal = false;
    
    // Check market strength
    if(!CheckMarketStrength(isLong)) entrySignal = false;
    
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
    
    if(CopyBuffer(marketStrengthHandle, 0, 0, 1, marketStrengthBuffer) != 1) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Perform walk-forward optimization                                |
//+------------------------------------------------------------------+
void PerformWalkForwardOptimization()
{
    Print("Starting walk-forward optimization");
    
    OptimizationParams bestParams;
    BacktestResults bestResults;
    bestResults.totalProfit = -DBL_MAX;
    
    // Define parameter ranges for optimization
    int atrPeriodRange[] = {10, 14, 20, 30};
    int fiboPeriodRange[] = {21, 34, 55, 89};
    int smcLookbackRange[] = {50, 100, 150, 200};
    
    for(int i=0; i<ArraySize(atrPeriodRange); i++)
    {
        for(int j=0; j<ArraySize(fiboPeriodRange); j++)
        {
            for(int k=0; k<ArraySize(smcLookbackRange); k++)
            {
                OptimizationParams testParams;
                testParams.ATRPeriod = atrPeriodRange[i];
                testParams.FiboPeriod = fiboPeriodRange[j];
                testParams.SMC_Lookback = smcLookbackRange[k];
                
                BacktestResults results = BacktestStrategy(testParams);
                
                if(results.totalProfit > bestResults.totalProfit)
                {
                    bestResults = results;
                    bestParams = testParams;
                }
            }
        }
    }
    
    // Update current parameters with best found
    currentParams = bestParams;
    ATRPeriod = currentParams.ATRPeriod;
    FiboPeriod = currentParams.FiboPeriod;
    SMC_Lookback = currentParams.SMC_Lookback;
    
    Print("Optimization complete. New parameters: ATR=", ATRPeriod, " Fibo=", FiboPeriod, " SMC=", SMC_Lookback);
    Print("Best results: Profit=", bestResults.totalProfit, " Drawdown=", bestResults.maxDrawdown, " Win Rate=", bestResults.winRate);
}

//+------------------------------------------------------------------+
//| Backtest strategy with given parameters                          |
//+------------------------------------------------------------------+
BacktestResults BacktestStrategy(const OptimizationParams &params)
{
    BacktestResults results;
    results.totalProfit = 0;
    results.maxDrawdown = 0;
    results.totalTrades = 0;
    results.winRate = 0;
    results.profitFactor = 0;
    results.sharpeRatio = 0;
    
    double initialBalance = 10000; // Assume starting balance of $10,000
    double balance = initialBalance;
    double maxBalance = initialBalance;
    int winningTrades = 0;
    double grossProfit = 0;
    double grossLoss = 0;
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, OptimizationPeriod, rates);
    
    if(copied > 0)
    {
        for(int i = copied - 1; i >= 0; i--)
        {
            // Simulate market conditions and check for entry signals
            bool entrySignal = false;
            bool isLong = false;
            
            // Your entry signal logic here, using the params
            // For example:
            if(CheckSMCEntry(isLong, params.SMC_Lookback) || CheckFibonacciEntry(isLong, params.FiboPeriod))
            {
                entrySignal = true;
            }
            
            if(entrySignal)
            {
                double lotSize = 0.01; // Fixed lot size for backtesting
                double entryPrice = isLong ? rates[i].close : rates[i].close;
                double stopLoss = isLong ? entryPrice - params.ATRPeriod * _Point : entryPrice + params.ATRPeriod * _Point;
                double takeProfit = isLong ? entryPrice + params.ATRPeriod * 2 * _Point : entryPrice - params.ATRPeriod * 2 * _Point;
                
                // Simulate trade
                for(int j = i - 1; j >= 0; j--)
                {
                    if((isLong && rates[j].low <= stopLoss) || (!isLong && rates[j].high >= stopLoss))
                    {
                        // Stop loss hit
                        balance += (stopLoss - entryPrice) * lotSize * 100000;
                        grossLoss += MathAbs((stopLoss - entryPrice) * lotSize * 100000);
                        break;
                    }
                    else if((isLong && rates[j].high >= takeProfit) || (!isLong && rates[j].low <= takeProfit))
                    {
                        // Take profit hit
                        balance += (takeProfit - entryPrice) * lotSize * 100000;
                        grossProfit += (takeProfit - entryPrice) * lotSize * 100000;
                        winningTrades++;
                        break;
                    }
                }
                
                results.totalTrades++;
                
                if(balance > maxBalance)
                    maxBalance = balance;
                else if((maxBalance - balance) > results.maxDrawdown)
                    results.maxDrawdown = maxBalance - balance;
            }
        }
    }
    
    results.totalProfit = balance - initialBalance;
    results.winRate = results.totalTrades > 0 ? (double)winningTrades / results.totalTrades * 100 : 0;
    results.profitFactor = grossLoss > 0 ? grossProfit / grossLoss : 0;
    results.sharpeRatio = CalculateSharpeRatio();
    
    return results;
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
    string url = "https://finnhub.io/api/v1/calendar/economic?token=" + FinnhubAPIKey;
    string headers = "Content-Type: application/json\r\n";
    char post[];
    char result[];
    string resultHeaders;
    
    int res = WebRequest("GET", url, headers, 5000, post, result, resultHeaders);
    
    if(res == -1)
    {
        Print("Error in WebRequest. Error code  =", GetLastError());
        return "";
    }
    
    return CharArrayToString(result);
}

//+------------------------------------------------------------------+
//| Analyze economic data                                            |
//+------------------------------------------------------------------+
int AnalyzeEconomicData(string economicData)
{
    // This is a simplified analysis. In a real scenario, you would parse the JSON
    // and analyze each economic event based on its impact and actual vs. forecast values.
    if(StringFind(economicData, "\"impact\":\"high\"") != -1)
    {
        if(StringFind(economicData, "\"actual\":") != -1 && StringFind(economicData, "\"estimate\":") != -1)
        {
            // Compare actual vs estimate (this is a very simplified approach)
            if(StringFind(economicData, "\"actual\":") < StringFind(economicData, "\"estimate\":"))
                return -1;  // Negative impact
            else
                return 1;   // Positive impact
        }
    }
    return 0;  // Neutral impact
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
//| Select dynamic timeframe based on volatility                     |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES SelectDynamicTimeframe()
{
    double currentVolatility = atrBuffer[0];
    double averageVolatility = 0;
    
    for(int i = 1; i <= VolatilityPeriod; i++)
    {
        averageVolatility += iATR(_Symbol, PERIOD_CURRENT, VolatilityPeriod, i);
    }
    averageVolatility /= VolatilityPeriod;
    
    if(currentVolatility > averageVolatility * 1.5)
        return PERIOD_M5;  // High volatility, use shorter timeframe
    else if(currentVolatility < averageVolatility * 0.5)
        return PERIOD_H1;  // Low volatility, use longer timeframe
    else
        return PERIOD_M15; // Normal volatility
}

//+------------------------------------------------------------------+
//| Manage portfolio of multiple trading pairs                       |
//+------------------------------------------------------------------+
void ManagePortfolio()
{
    double totalRisk = 0;
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Calculate total risk across all open positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            double positionRisk = CalculatePositionRisk();
            totalRisk += positionRisk;
        }
    }
    
    // Check if total risk exceeds maximum allowed
    if(totalRisk > accountEquity * RiskPercent / 100)
    {
        Print("Total portfolio risk exceeds maximum allowed. Closing most risky position.");
        CloseRiskiestPosition();
    }
    
    // Check for new trading opportunities in each pair
    for(int i = 0; i < ArraySize(TradingPairs); i++)
    {
        string symbol = TradingPairs[i];
        if(SymbolSelect(symbol, true))
        {
            // Analyze and potentially open new positions for this symbol
            AnalyzeSymbol(symbol);
        }
    }
}

//+------------------------------------------------------------------+
//| Rebalance portfolio                                              |
//+------------------------------------------------------------------+
void RebalancePortfolio()
{
    double totalEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    int symbolCount = ArraySize(TradingPairs);
    double targetAllocation = totalEquity / symbolCount;
    
    for(int i = 0; i < symbolCount; i++)
    {
        string symbol = TradingPairs[i];
        double currentAllocation = 0;
        
        for(int j = PositionsTotal() - 1; j >= 0; j--)
        {
            if(PositionSelectByTicket(PositionGetTicket(j)))
            {
                if(PositionGetString(POSITION_SYMBOL) == symbol)
                {
                    currentAllocation += PositionGetDouble(POSITION_VOLUME) * SymbolInfoDouble(symbol, SYMBOL_BID);
                }
            }
        }
        
        double allocationDifference = targetAllocation - currentAllocation;
        
        if(MathAbs(allocationDifference) > totalEquity * 0.01) // 1% threshold
        {
            double lotSize = NormalizeDouble(MathAbs(allocationDifference) / SymbolInfoDouble(symbol, SYMBOL_BID), 2);
            
            if(allocationDifference > 0)
                trade.Buy(lotSize, symbol, 0, 0, 0, "Portfolio Rebalance");
            else
                trade.Sell(lotSize, symbol, 0, 0, 0, "Portfolio Rebalance");
        }
    }
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
//| Check sentiment analysis                                         |
//+------------------------------------------------------------------+
bool CheckSentimentAnalysis(bool isLong)
{
    // Implement sentiment analysis logic here
    // This is a placeholder function, you should implement actual sentiment analysis
    double sentiment = 0.5; // Placeholder value
    
    if(isLong)
        return sentiment > 0.6;
    else
        return sentiment < 0.4;
}

//+------------------------------------------------------------------+
//| Check machine learning prediction                                |
//+------------------------------------------------------------------+
bool CheckMLPrediction(bool isLong)
{
    // Implement machine learning prediction logic here
    // This is a placeholder function, you should implement actual ML prediction
    double prediction = 0.5; // Placeholder value
    
    if(isLong)
        return prediction > 0.6;
    else
        return prediction < 0.4;
}

//+------------------------------------------------------------------+
//| Check market strength                                            |
//+------------------------------------------------------------------+
bool CheckMarketStrength(bool isLong)
{
    double strength = marketStrengthBuffer[0];
    
    if(isLong)
        return strength > 60;
    else
        return strength < 40;
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
    
    // Adjust lot size based on account growth
    lotSize *= accountGrowthFactor;
    
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
//| Open a buy trade                                                 |
//+------------------------------------------------------------------+
void OpenBuyTrade(double lotSize)
{
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double stopLoss = CalculateDynamicStopLoss(true);
    double takeProfit = CalculateDynamicTakeProfit(true);
    
    trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v2.4");
}

//+------------------------------------------------------------------+
//| Open a sell trade                                                |
//+------------------------------------------------------------------+
void OpenSellTrade(double lotSize)
{
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stopLoss = CalculateDynamicStopLoss(false);
    double takeProfit = CalculateDynamicTakeProfit(false);
    
    trade.Sell(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "Moran Flipper v2.4");
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
    int period = 100; // Number of periods for correlation calculation
    
    for(int i = 0; i < ArraySize(TradingPairs); i++)
    {
        for(int j = i; j < ArraySize(TradingPairs); j++)
        {
            if(i == j)
            {
                pairCorrelations[i][j] = 1.0; // Self-correlation is always 1
            }
            else
            {
                pairCorrelations[i][j] = pairCorrelations[j][i] = CalculatePairCorrelation(TradingPairs[i], TradingPairs[j], period);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate correlation between two symbols                        |
//+------------------------------------------------------------------+
double CalculatePairCorrelation(string symbol1, string symbol2, int period)
{
    double close1[], close2[];
    ArraySetAsSeries(close1, true);
    ArraySetAsSeries(close2, true);
    
    if(CopyClose(symbol1, PERIOD_H1, 0, period, close1) != period) return 0;
    if(CopyClose(symbol2, PERIOD_H1, 0, period, close2) != period) return 0;
    
    return MathCorrelation(close1, close2, period);
}

//+------------------------------------------------------------------+
//| Check correlation filter for a symbol                            |
//+------------------------------------------------------------------+
bool CheckCorrelationFilter(string symbol)
{
    int symbolIndex = ArraySearch(TradingPairs, symbol);
    if(symbolIndex == -1) return true; // Symbol not in correlation matrix, allow trade
    
    for(int i = 0; i < ArraySize(TradingPairs); i++)
    {
        if(i != symbolIndex && PositionSelect(TradingPairs[i]))
        {
            if(MathAbs(pairCorrelations[symbolIndex][i]) > 0.8) // High correlation threshold
            {
                Print("High correlation detected between ", symbol, " and ", TradingPairs[i], ". Avoiding trade.");
                return false;
            }
        }
    }
    
    return true;
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

//+------------------------------------------------------------------+
//| Check for SMC entry                                              |
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
//| Check for chart patterns                                         |
//+------------------------------------------------------------------+
bool CheckChartPatterns(bool &isLong)
{
    if(IdentifyHeadAndShoulders(isLong)) return true;
    if(IdentifyDoubleTopBottom(isLong)) return true;
    if(IdentifyTriangle(isLong)) return true;
    return false;
}

//+------------------------------------------------------------------+
//| Identify Head and Shoulders pattern                              |
//+------------------------------------------------------------------+
bool IdentifyHeadAndShoulders(bool &isLong)
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 100, high) != 100) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 100, low) != 100) return false;
    
    // Check for Head and Shoulders (bearish)
    if(high[20] < high[40] && high[40] > high[60] && high[60] < high[80] &&
       low[20] > low[40] && low[40] < low[60] && low[60] > low[80] &&
       high[40] > high[0] && high[40] > high[80])
    {
        isLong = false;
        return true;
    }
    
    // Check for Inverse Head and Shoulders (bullish)
    if(low[20] > low[40] && low[40] < low[60] && low[60] > low[80] &&
       high[20] < high[40] && high[40] > high[60] && high[60] < high[80] &&
       low[40] < low[0] && low[40] < low[80])
    {
        isLong = true;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Identify Double Top or Double Bottom pattern                     |
//+------------------------------------------------------------------+
bool IdentifyDoubleTopBottom(bool &isLong)
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 100, high) != 100) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 100, low) != 100) return false;
    
    // Check for Double Top (bearish)
    if(MathAbs(high[0] - high[20]) < ATRPeriod * _Point &&
       high[0] > high[10] && high[20] > high[10])
    {
        isLong = false;
        return true;
    }
    
    // Check for Double Bottom (bullish)
    if(MathAbs(low[0] - low[20]) < ATRPeriod * _Point &&
       low[0] < low[10] && low[20] < low[10])
    {
        isLong = true;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Identify Triangle pattern                                        |
//+------------------------------------------------------------------+
bool IdentifyTriangle(bool &isLong)
{
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 100, high) != 100) return false;
    if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 100, low) != 100) return false;
    
    // Check for Ascending Triangle (bullish)
    if(IsHorizontalResistance(high, 50) && IsAscendingSupport(low, 50))
    {
        isLong = true;
        return true;
    }
    
    // Check for Descending Triangle (bearish)
    if(IsHorizontalSupport(low, 50) && IsDescendingResistance(high, 50))
    {
        isLong = false;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for horizontal resistance                                  |
//+------------------------------------------------------------------+
bool IsHorizontalResistance(const double &prices[], int period)
{
    double sum = 0;
    for(int i = 0; i < period; i++)
        sum += prices[i];
    double average = sum / period;
    
    for(int i = 0; i < period; i++)
        if(MathAbs(prices[i] - average) > ATRPeriod * _Point)
            return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check for ascending support                                      |
//+------------------------------------------------------------------+
bool IsAscendingSupport(const double &prices[], int period)
{
    double slope, intercept;
    if(!CalculateLinearRegression(prices, period, slope, intercept))
        return false;
    
    return slope > 0;
}

//+------------------------------------------------------------------+
//| Check for horizontal support                                     |
//+------------------------------------------------------------------+
bool IsHorizontalSupport(const double &prices[], int period)
{
    double sum = 0;
    for(int i = 0; i < period; i++)
        sum += prices[i];
    double average = sum / period;
    
    for(int i = 0; i < period; i++)
        if(MathAbs(prices[i] - average) > ATRPeriod * _Point)
            return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check for descending resistance                                  |
//+------------------------------------------------------------------+
bool IsDescendingResistance(const double &prices[], int period)
{
    double slope, intercept;
    if(!CalculateLinearRegression(prices, period, slope, intercept))
        return false;
    
    return slope < 0;
}

//+------------------------------------------------------------------+
//| Calculate linear regression                                      |
//+------------------------------------------------------------------+
bool CalculateLinearRegression(const double &prices[], int period, double &slope, double &intercept)
{
    if(period <= 1) return false;
    
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for(int i = 0; i < period; i++)
    {
        sumX += i;
        sumY += prices[i];
        sumXY += i * prices[i];
        sumX2 += i * i;
    }
    
    double denominator = (period * sumX2 - sumX * sumX);
    if(denominator == 0) return false;
    
    slope = (period * sumXY - sumX * sumY) / denominator;
    intercept = (sumY - slope * sumX) / period;
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Sharpe Ratio                                           |
//+------------------------------------------------------------------+
double CalculateSharpeRatio()
{
    double returns[];
    ArrayResize(returns, HistoryDealsTotal());
    
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealSelect(ticket) && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
        {
            returns[i] = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        }
    }
    
    return SharpeRatio(returns, 0.02 / 252); // Assuming 2% risk-free rate and 252 trading days
}

//+------------------------------------------------------------------+
//| Calculate position risk                                          |
//+------------------------------------------------------------------+
double CalculatePositionRisk()
{
    double lotSize = PositionGetDouble(POSITION_VOLUME);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double stopLoss = PositionGetDouble(POSITION_SL);
    double tickValue = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_TRADE_TICK_VALUE);
    
    return MathAbs(openPrice - stopLoss) * lotSize * tickValue;
}

//+------------------------------------------------------------------+
//| Close the position with the highest risk                         |
//+------------------------------------------------------------------+
void CloseRiskiestPosition()
{
    double maxRisk = 0;
    ulong ticketToClose = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            double positionRisk = CalculatePositionRisk();
            if(positionRisk > maxRisk)
            {
                maxRisk = positionRisk;
                ticketToClose = PositionGetTicket(i);
            }
        }
    }
    
    if(ticketToClose != 0)
    {
        trade.PositionClose(ticketToClose);
        Print("Closed riskiest position. Ticket: ", ticketToClose);
    }
}

//+------------------------------------------------------------------+
//| Analyze and potentially trade a specific symbol                  |
//+------------------------------------------------------------------+
void AnalyzeSymbol(string symbol)
{
    if(!SymbolSelect(symbol, true))
    {
        Print("Failed to select symbol: ", symbol);
        return;
    }

    bool isLong = false;
    bool entrySignal = false;

    // Check for entry signals using various methods
    if(UseSMC && CheckSMCEntry(isLong))
        entrySignal = true;
    else if(UseSupplyDemand && CheckSupplyDemandEntry(isLong))
        entrySignal = true;
    else if(UseFibonacci && CheckFibonacciEntry(isLong))
        entrySignal = true;
    else if(UseChartPatterns && CheckChartPatterns(isLong))
        entrySignal = true;

    if(entrySignal)
    {
        double lotSize = CalculatePositionSize(isLong);
        if(CheckRiskManagement(lotSize) && CheckCorrelationFilter(symbol))
        {
            if(isLong)
                OpenBuyTrade(lotSize);
            else
                OpenSellTrade(lotSize);
        }
    }
}

//+------------------------------------------------------------------+
//| Custom function to handle errors                                 |
//+------------------------------------------------------------------+
void HandleErrors(int errorCode)
{
    switch(errorCode)
    {
        case ERR_NO_ERROR:
            break;
        case ERR_NO_RESULT:
            Print("No error returned, but no operations performed");
            break;
        case ERR_COMMON_ERROR:
            Print("Common error");
            break;
        case ERR_INVALID_TRADE_PARAMETERS:
            Print("Invalid trade parameters");
            break;
        case ERR_SERVER_BUSY:
            Print("Trade server is busy");
            break;
        case ERR_OLD_VERSION:
            Print("Old version of the client terminal");
            break;
        case ERR_NO_CONNECTION:
            Print("No connection with trade server");
            break;
        case ERR_NOT_ENOUGH_RIGHTS:
            Print("Not enough rights");
            break;
        case ERR_TOO_FREQUENT_REQUESTS:
            Print("Too frequent requests");
            break;
        case ERR_MALFUNCTIONAL_TRADE:
            Print("Malfunctional trade operation");
            break;
        default:
            Print("Unknown error occurred: ", errorCode);
            break;
    }
}
