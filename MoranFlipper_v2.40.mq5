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
    // Initialize indicators
    atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(atrHandle == INVALID_HANDLE) return(INIT_FAILED);
    
    ArraySetAsSeries(atrBuffer, true);
    
    for(int i = 0; i < 3; i++)
    {
        momentumHandles[i] = iMomentum(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
        if(momentumHandles[i] == INVALID_HANDLE) return(INIT_FAILED);
        ArraySetAsSeries(momentumBuffers[i], true);
    }
    
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

// ... (The rest of the functions remain the same as in v2.3)