
//+------------------------------------------------------------------+
//|                                           MoranFlipper_v1.0.mq5 |
//|                                     Copyright 2023, Bryson Nyaliti Omullo |
//|                                  https://github.com/nyaliti/Moran-Flipper |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Bryson Nyaliti Omullo"
#property link      "https://github.com/nyaliti/Moran-Flipper"
#property version   "1.0"
#property strict

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Expert\Expert.mqh>

// Main MoranFlipper class definition
// ... (rest of the code remains unchanged)

// Moran Flipper v1.0
// Main structure outline

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Expert\Expert.mqh>

// Define global variables
input string   InpSymbol = "EURUSD";     // Trading symbol
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5;  // Timeframe

// Parameters for supply/demand zone identification
input int    InpZoneLookback = 100;    // Number of candles to look back
input double InpZoneStrength = 3.0;    // Minimum strength for a valid zone
input int    InpZoneTimeout  = 50;     // Zone timeout in candles

// Structure to hold backtest results
struct BacktestResult
{
    int totalTrades;
    int winningTrades;
    double totalProfit;
    double maxDrawdown;
    double winRate;
    double profitFactor;
    double profits[];
};

// Create class for Moran Flipper v1.0
class MoranFlipper : public CExpert
{
public:
    // Constructor and destructor
    MoranFlipper();
    ~MoranFlipper();

    // Main trading functions
    virtual bool Init();
    virtual void Deinit();
    virtual void Processing();

    // Helper functions
    bool IsNewBar();
    bool InitializeIndicators();
    void ReleaseIndicators();
    void CloseAllPositions();
    void CancelAllPendingOrders();
    void ManageOpenPositions();

    // Backtesting and optimization
    BacktestResult Backtest(datetime startDate, datetime endDate);
    void Optimize(datetime startDate, datetime endDate);
    void WalkForwardAnalysis(datetime startDate, datetime endDate, int numSegments);

    // Logging function
    void Log(string message, int logLevel = 0);

    // Save and load optimized parameters
    void SaveOptimizedParameters(string filename = "optimized_params.csv");
    bool LoadOptimizedParameters(string filename = "optimized_params.csv");

    // Visualization function
    void VisualizeBacktestResults(const BacktestResult &result, datetime startDate, datetime endDate);

    // Getter methods for strategy parameters
    int GetFastMA() const { return m_fastMA; }
    int GetSlowMA() const { return m_slowMA; }
    int GetRSIPeriod() const { return m_rsiPeriod; }

    // Methods for test balance
    void SetTestBalance(double balance) { m_testBalance = balance; m_useTestBalance = true; }
    void ResetTestBalance() { m_useTestBalance = false; }

    // Override AccountInfoDouble to use test balance when set
    double AccountInfoDouble(ENUM_ACCOUNT_INFO_DOUBLE property_id)
    {
        if (m_useTestBalance && property_id == ACCOUNT_BALANCE)
            return m_testBalance;
        return ::AccountInfoDouble(property_id);
    }

    // Risk management parameters
    input double RiskPercentage = 1.0;  // Risk per trade as a percentage of account balance
    input double MaxLotSize = 10.0;     // Maximum allowed lot size
    input int LogLevel = 1;             // Logging level: 0 - None, 1 - Errors, 2 - Warnings, 3 - Info

    // Strategy parameters (to be optimized)
    input int FastMA = 10;              // Fast Moving Average period
    input int SlowMA = 20;              // Slow Moving Average period
    input int RSIPeriod = 14;           // RSI period
    input int RSIOverBought = 70;       // RSI overbought level
    input int RSIOverSold = 30;         // RSI oversold level

private:
    // Private member variables for various components
    CPositionInfo m_position;
    CTrade        m_trade;
    
    // Strategy parameters
    int m_fastMA;
    int m_slowMA;
    int m_rsiPeriod;
    
    // Test balance
    double m_testBalance;
    bool m_useTestBalance;
    
    // Strategy components
    void SupplyDemandZones();
    void ChartPatterns();
    void FibonacciRetracements();
    void OrderBlocks();
    void FairValueGaps();
    void SupportResistance();
    void MarketStructureBreaks();
    void TrendlineAnalysis();

    // Structure to hold Trendline information
    struct Trendline {
        datetime startTime;
        datetime endTime;
        double startPrice;
        double endPrice;
        bool isResistance;
    };

    // Array to store identified Trendlines
    CArrayObj m_trendlines;

    // Helper functions for TrendlineAnalysis
    void FindTrendlines(bool isResistance);
    bool IsTrendlineValid(int start, int end, bool isResistance);
    void AddTrendline(int start, int end, bool isResistance);

    // Risk management
    double CalculatePositionSize();
    void SetStopLoss();
    void SetTakeProfit();
    
    // Helper functions
    bool IsNewBar();
    
    // Variables for IsNewBar function
    datetime m_last_bar_time;

    // Private helper functions
    bool IsBuySignal(double currentPrice);
    bool IsSellSignal(double currentPrice);

    // Structure to hold Market Structure Break information
    struct MSB {
        datetime time;
        double price;
        bool isBullish;
    };

    // Array to store identified Market Structure Breaks
    CArrayObj m_msb;

    // Helper functions for MarketStructureBreaks
    bool IsHigherHigh(int candle, int left, int right);
    bool IsLowerLow(int candle, int left, int right);
    void AddMSB(int candle, bool isBullish);

    // Structure to hold Support/Resistance level information
    struct SRLevel {
        double price;
        datetime time;
        bool isSupport;
        int strength;
    };
};

// Constructor
MoranFlipper::MoranFlipper() : m_fastMA(FastMA), m_slowMA(SlowMA), m_rsiPeriod(RSIPeriod), 
                               m_testBalance(0), m_useTestBalance(false)
{
    // Initialize other members if necessary
}

// Destructor
MoranFlipper::~MoranFlipper()
{
    // Clean up resources if necessary
}

// Logging function
void MoranFlipper::Log(string message, int logLevel)
{
    if (logLevel <= LogLevel)
    {
        string levelText;
        color messageColor;

        switch (logLevel)
        {
            case 1:
                levelText = "ERROR: ";
                messageColor = clrRed;
                break;
            case 2:
                levelText = "WARNING: ";
                messageColor = clrYellow;
                break;
            case 3:
                levelText = "INFO: ";
                messageColor = clrWhite;
                break;
            default:
                levelText = "";
                messageColor = clrGray;
        }

        Print(levelText, message);
        Comment(levelText, message);
        
        if (logLevel == 1) // Error
        {
            Alert(levelText, message);
        }
    }
}

    // Array to store identified Support/Resistance levels
    CArrayObj m_srLevels;
};

// Constructor
MoranFlipper::MoranFlipper() : m_fastMA(FastMA), m_slowMA(SlowMA), m_rsiPeriod(RSIPeriod), 
                               m_testBalance(0), m_useTestBalance(false)
{
    // Initialize other members if necessary
}

// Destructor
MoranFlipper::~MoranFlipper()
{
    // Clean up resources if necessary
    ReleaseIndicators();
}

// Logging function
void MoranFlipper::Log(string message, int logLevel)
{
    if (logLevel <= LogLevel)
    {
        string levelText;
        color messageColor;

        switch (logLevel)
        {
            case 1:
                levelText = "ERROR: ";
                messageColor = clrRed;
                break;
            case 2:
                levelText = "WARNING: ";
                messageColor = clrYellow;
                break;
            case 3:
                levelText = "INFO: ";
                messageColor = clrWhite;
                break;
            default:
                levelText = "";
                messageColor = clrGray;
        }

        Print(levelText, message);
        Comment(levelText, message);
        
        if (logLevel == 1) // Error
        {
            Alert(levelText, message);
        }
    }
}

// Helper function to check for a new bar
bool MoranFlipper::IsNewBar()
{
    static datetime last_time = 0;
    datetime current_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(current_time != last_time)
    {
        last_time = current_time;
        return true;
    }
    return false;
}

// Helper function to initialize indicators
bool MoranFlipper::InitializeIndicators()
{
    // Initialize indicators here
    // For example:
    // m_fastMAHandle = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    // if(m_fastMAHandle == INVALID_HANDLE) return false;
    
    return true; // Return true if all indicators are initialized successfully
}

// Helper function to release indicator handles
void MoranFlipper::ReleaseIndicators()
{
    // Release indicator handles here
    // For example:
    // IndicatorRelease(m_fastMAHandle);
}

// Helper function to close all open positions
void MoranFlipper::CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                m_trade.PositionClose(m_position.Ticket());
            }
        }
    }
}

// Helper function to cancel all pending orders
void MoranFlipper::CancelAllPendingOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == _Symbol)
            {
                m_trade.OrderDelete(OrderTicket());
            }
        }
    }
}

// Helper function to manage open positions
void MoranFlipper::ManageOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                // Implement your position management logic here
                // For example, trailing stop, time-based exit, etc.
            }
        }
    }
}

// Constructor
MoranFlipper::MoranFlipper() : m_fastMA(FastMA), m_slowMA(SlowMA), m_rsiPeriod(RSIPeriod), 
                               m_testBalance(0), m_useTestBalance(false)
{
    // Initialize other members if necessary
}

// Destructor
MoranFlipper::~MoranFlipper()
{
    // Clean up resources if necessary
    ReleaseIndicators();
}

// Logging function
void MoranFlipper::Log(string message, int logLevel)
{
    if (logLevel <= LogLevel)
    {
        string levelText;
        color messageColor;

        switch (logLevel)
        {
            case 1:
                levelText = "ERROR: ";
                messageColor = clrRed;
                break;
            case 2:
                levelText = "WARNING: ";
                messageColor = clrYellow;
                break;
            case 3:
                levelText = "INFO: ";
                messageColor = clrWhite;
                break;
            default:
                levelText = "";
                messageColor = clrGray;
        }

        Print(levelText, message);
        Comment(levelText, message);
        
        if (logLevel == 1) // Error
        {
            Alert(levelText, message);
        }
    }
}

// Helper function to check for a new bar
bool MoranFlipper::IsNewBar()
{
    static datetime last_time = 0;
    datetime current_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(current_time != last_time)
    {
        last_time = current_time;
        return true;
    }
    return false;
}

// Helper function to initialize indicators
bool MoranFlipper::InitializeIndicators()
{
    // Initialize indicators here
    // For example:
    // m_fastMAHandle = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    // if(m_fastMAHandle == INVALID_HANDLE) return false;
    
    return true; // Return true if all indicators are initialized successfully
}

// Helper function to release indicator handles
void MoranFlipper::ReleaseIndicators()
{
    // Release indicator handles here
    // For example:
    // IndicatorRelease(m_fastMAHandle);
}

// Helper function to close all open positions
void MoranFlipper::CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                m_trade.PositionClose(m_position.Ticket());
            }
        }
    }
}

// Helper function to cancel all pending orders
void MoranFlipper::CancelAllPendingOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == _Symbol)
            {
                m_trade.OrderDelete(OrderTicket());
            }
        }
    }
}

// Helper function to manage open positions
void MoranFlipper::ManageOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                // Implement your position management logic here
                // For example, trailing stop, time-based exit, etc.
            }
        }
    }
}

// Constructor
MoranFlipper::MoranFlipper() : m_fastMA(FastMA), m_slowMA(SlowMA), m_rsiPeriod(RSIPeriod), 
                               m_testBalance(0), m_useTestBalance(false)
{
    // Initialize other members if necessary
}

// Destructor
MoranFlipper::~MoranFlipper()
{
    // Clean up resources if necessary
    ReleaseIndicators();
}

// Helper function to check for a new bar
bool MoranFlipper::IsNewBar()
{
    static datetime last_time = 0;
    datetime current_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(current_time != last_time)
    {
        last_time = current_time;
        return true;
    }
    return false;
}

// Helper function to initialize indicators
bool MoranFlipper::InitializeIndicators()
{
    // Initialize indicators here
    // For example:
    // m_fastMAHandle = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    // if(m_fastMAHandle == INVALID_HANDLE) return false;
    
    return true; // Return true if all indicators are initialized successfully
}

// Helper function to release indicator handles
void MoranFlipper::ReleaseIndicators()
{
    // Release indicator handles here
    // For example:
    // IndicatorRelease(m_fastMAHandle);
}

// Helper function to close all open positions
void MoranFlipper::CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                m_trade.PositionClose(m_position.Ticket());
            }
        }
    }
}

// Helper function to cancel all pending orders
void MoranFlipper::CancelAllPendingOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == _Symbol)
            {
                m_trade.OrderDelete(OrderTicket());
            }
        }
    }
}

// Helper function to manage open positions
void MoranFlipper::ManageOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                // Implement your position management logic here
                // For example, trailing stop, time-based exit, etc.
            }
        }
    }
}

// Logging function
void MoranFlipper::Log(string message, int logLevel)
{
    if (logLevel <= LogLevel)
    {
        string levelText;
        color messageColor;

        switch (logLevel)
        {
            case 1:
                levelText = "ERROR: ";
                messageColor = clrRed;
                break;
            case 2:
                levelText = "WARNING: ";
                messageColor = clrYellow;
                break;
            case 3:
                levelText = "INFO: ";
                messageColor = clrWhite;
                break;
            default:
                levelText = "";
                messageColor = clrGray;
        }

        Print(levelText, message);
        Comment(levelText, message);
        
        if (logLevel == 1) // Error
        {
            Alert(levelText, message);
        }
    }
}

// Initialization function
bool MoranFlipper::Init()
{
    Log("Initializing Moran Flipper v1.0", 3);

    // Initialize trade object
    if(!m_trade.SetExpertMagicNumber(123456))
    {
        Log("Failed to set expert magic number", 1);
        return false;
    }

    // Initialize indicators
    if(!InitializeIndicators())
    {
        Log("Failed to initialize indicators", 1);
        return false;
    }

    // Set up symbol and timeframe
    if(!SymbolSelect(_Symbol, true))
    {
        Log("Failed to select symbol: " + _Symbol, 1);
        return false;
    }

    // Check if the symbol is available for trading
    if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE))
    {
        Log("Symbol is not available for trading: " + _Symbol, 1);
        return false;
    }

    Log("Moran Flipper v1.0 initialized successfully", 3);
    return true;
}

// Deinitialization function
void MoranFlipper::Deinit()
{
    Log("Deinitializing Moran Flipper v1.0", 3);

    // Close all open positions
    CloseAllPositions();

    // Remove all pending orders
    CancelAllPendingOrders();

    // Release indicator handles
    ReleaseIndicators();

    Log("Moran Flipper v1.0 deinitialized successfully", 3);
}

// Main processing function
void MoranFlipper::Processing()
{
    if (!IsNewBar())
        return;
    
    Log("Starting new bar processing", 3);
    
    // Get current market data
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate indicators
    double fastMA = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    double slowMA = iMA(_Symbol, PERIOD_CURRENT, m_slowMA, 0, MODE_SMA, PRICE_CLOSE);
    double rsi = iRSI(_Symbol, PERIOD_CURRENT, m_rsiPeriod, PRICE_CLOSE);
    
    // Perform analysis
    SupplyDemandZones();
    ChartPatterns();
    FibonacciRetracements();
    OrderBlocks();
    FairValueGaps();
    SupportResistance();
    MarketStructureBreaks();
    TrendlineAnalysis();
    
    // Decision making based on indicators and analysis
    bool shouldBuy = false;
    bool shouldSell = false;
    
    // Check for buy signals
    if (fastMA > slowMA && rsi < RSIOverSold && IsBuySignal(currentPrice))
    {
        shouldBuy = true;
        Log("Buy signal detected", 3);
    }
    // Check for sell signals
    else if (fastMA < slowMA && rsi > RSIOverBought && IsSellSignal(currentPrice))
    {
        shouldSell = true;
        Log("Sell signal detected", 3);
    }
    
    // Execute trades if conditions are met
    if (shouldBuy || shouldSell)
    {
        double lotSize = CalculatePositionSize();
        
        if (shouldBuy)
        {
            if (m_trade.Buy(lotSize, _Symbol, 0, 0, 0, "Moran Flipper Buy"))
            {
                SetStopLoss();
                SetTakeProfit();
                Log("Buy order executed", 3);
            }
            else
            {
                Log("Failed to execute buy order: " + IntegerToString(GetLastError()), 1);
            }
        }
        else if (shouldSell)
        {
            if (m_trade.Sell(lotSize, _Symbol, 0, 0, 0, "Moran Flipper Sell"))
            {
                SetStopLoss();
                SetTakeProfit();
                Log("Sell order executed", 3);
            }
            else
            {
                Log("Failed to execute sell order: " + IntegerToString(GetLastError()), 1);
            }
        }
    }
    
    // Check for exit conditions
    ManageOpenPositions();
}

// Helper function to initialize indicators
bool MoranFlipper::InitializeIndicators()
{
    // Initialize indicators here
    // For example:
    // m_fastMAHandle = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    // if(m_fastMAHandle == INVALID_HANDLE) return false;
    
    return true; // Return true if all indicators are initialized successfully
}

// Helper function to release indicator handles
void MoranFlipper::ReleaseIndicators()
{
    // Release indicator handles here
    // For example:
    // IndicatorRelease(m_fastMAHandle);
}

// Helper function to close all open positions
void MoranFlipper::CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                m_trade.PositionClose(m_position.Ticket());
            }
        }
    }
}

// Helper function to cancel all pending orders
void MoranFlipper::CancelAllPendingOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                m_trade.OrderDelete(m_position.Ticket());
            }
        }
    }
}

// Helper function to manage open positions
void MoranFlipper::ManageOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                // Implement your position management logic here
                // For example, trailing stop, time-based exit, etc.
            }
        }
    }
}

// Implementation of MoranFlipper methods

// Constructor
MoranFlipper::MoranFlipper()
{
    // Initialize components
    m_last_bar_time = 0;
    m_zones = new CArrayObj();
    m_patterns = new CArrayObj();
    m_srLevels = new CArrayObj();
    m_orderBlocks = new CArrayObj();
    m_fvg = new CArrayObj();
    m_msb = new CArrayObj();
    m_trendlines = new CArrayObj();
    m_fibLevels = new CArrayObj();
}

// Destructor
MoranFlipper::~MoranFlipper()
{
    // Clean up resources
    delete m_zones;
    delete m_patterns;
    delete m_srLevels;
    delete m_orderBlocks;
    delete m_fvg;
    delete m_msb;
    delete m_trendlines;
    delete m_fibLevels;
}

// Initialization
bool MoranFlipper::Init()
{
    Log("Initializing Moran Flipper v1.0", 3);

    // Try to load optimized parameters
    if(LoadOptimizedParameters())
    {
        Log("Loaded optimized parameters", 3);
    }
    else
    {
        Log("Using default parameters", 3);
    }

    // Initialize trade object
    if(!m_trade.SetExpertMagicNumber(123456))
    {
        Log("Failed to set expert magic number", 1);
        return false;
    }

    // Initialize indicators
    if(!InitializeIndicators())
    {
        Log("Failed to initialize indicators", 1);
        return false;
    }

    // Set up symbol and timeframe
    if(!SymbolSelect(_Symbol, true))
    {
        Log("Failed to select symbol: " + _Symbol, 1);
        return false;
    }

    // Check if the symbol is available for trading
    if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE))
    {
        Log("Symbol is not available for trading: " + _Symbol, 1);
        return false;
    }

    Log("Moran Flipper v1.0 initialized successfully", 3);
    return true;
}

// Helper function to initialize indicators
bool MoranFlipper::InitializeIndicators()
{
    // Initialize your indicators here
    // For example:
    // m_maHandle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    // if(m_maHandle == INVALID_HANDLE)
    // {
    //     Log("Failed to create MA indicator", 1);
    //     return false;
    // }

    return true; // Return true if all indicators are initialized successfully
}

// Deinitialization
void MoranFlipper::Deinit()
{
    Log("Deinitializing Moran Flipper v1.0", 3);

    // Release indicator handles
    ReleaseIndicators();

    // Close any open positions
    CloseAllPositions();

    // Clear all objects from the chart
    ObjectsDeleteAll(0, "MoranFlipper_");

    Log("Moran Flipper v1.0 deinitialized successfully", 3);
}

// Helper function to release indicator handles
void MoranFlipper::ReleaseIndicators()
{
    // Release your indicator handles here
    // For example:
    // if(m_maHandle != INVALID_HANDLE)
    // {
    //     IndicatorRelease(m_maHandle);
    //     m_maHandle = INVALID_HANDLE;
    // }
}

// Helper function to close all open positions
void MoranFlipper::CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0)
        {
            Log("Failed to get position ticket", 2);
            continue;
        }

        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == m_trade.RequestMagic())
            {
                if(!m_trade.PositionClose(ticket))
                {
                    Log("Failed to close position: " + IntegerToString(ticket) + ", Error: " + IntegerToString(GetLastError()), 2);
                }
                else
                {
                    Log("Closed position: " + IntegerToString(ticket), 3);
                }
            }
        }
    }
}

// Implementation of IsNewBar function
bool MoranFlipper::IsNewBar()
{
    datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    if (current_bar_time != m_last_bar_time)
    {
        m_last_bar_time = current_bar_time;
        return true;
    }
    
    return false;
}

// Implementation of Log function
void MoranFlipper::Log(string message, int logLevel = 0)
{
    if (logLevel <= LogLevel)
    {
        string levelText;
        color messageColor;

        switch (logLevel)
        {
            case 1:
                levelText = "ERROR: ";
                messageColor = clrRed;
                break;
            case 2:
                levelText = "WARNING: ";
                messageColor = clrYellow;
                break;
            case 3:
                levelText = "INFO: ";
                messageColor = clrWhite;
                break;
            default:
                levelText = "";
                messageColor = clrGray;
        }

        Print(levelText, message);
        Comment(levelText, message);
        
        if (logLevel == 1) // Error
        {
            Alert(levelText, message);
        }
    }
}

// Backtesting function
BacktestResult MoranFlipper::Backtest(datetime startDate, datetime endDate)
{
    Log("Starting backtest from " + TimeToString(startDate) + " to " + TimeToString(endDate), 3);

    BacktestResult result = {0};
    double peak = 0;
    ArrayResize(result.profits, 0);

    // Loop through historical data
    for(datetime current = startDate; current <= endDate; current += PeriodSeconds(PERIOD_CURRENT))
    {
        // Update current bar time
        m_last_bar_time = current;

        // Process the current bar
        Processing();

        // Check for open positions and update performance metrics
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(PositionSelectByTicket(PositionGetTicket(i)))
            {
                if(PositionGetInteger(POSITION_TIME) >= current)
                {
                    result.totalTrades++;
                    double profit = PositionGetDouble(POSITION_PROFIT);
                    result.totalProfit += profit;
                    ArrayResize(result.profits, result.totalTrades);
                    result.profits[result.totalTrades - 1] = profit;

                    if(profit > 0) result.winningTrades++;

                    // Update peak and drawdown
                    if(result.totalProfit > peak)
                    {
                        peak = result.totalProfit;
                    }
                    else
                    {
                        double drawdown = peak - result.totalProfit;
                        if(drawdown > result.maxDrawdown) result.maxDrawdown = drawdown;
                    }
                }
            }
        }
    }

    // Calculate performance metrics
    result.winRate = result.totalTrades > 0 ? (double)result.winningTrades / result.totalTrades * 100 : 0;
    result.profitFactor = result.totalProfit > 0 ? result.totalProfit / (peak - result.totalProfit) : 0;

    Log("Backtest completed. Results:", 3);
    Log("Total trades: " + IntegerToString(result.totalTrades), 3);
    Log("Winning trades: " + IntegerToString(result.winningTrades), 3);
    Log("Win rate: " + DoubleToString(result.winRate, 2) + "%", 3);
    Log("Total profit: " + DoubleToString(result.totalProfit, 2), 3);
    Log("Max drawdown: " + DoubleToString(result.maxDrawdown, 2), 3);
    Log("Profit factor: " + DoubleToString(result.profitFactor, 2), 3);

    return result;
}

// Optimization function
void MoranFlipper::Optimize(datetime startDate, datetime endDate)
{
    Log("Starting optimization from " + TimeToString(startDate) + " to " + TimeToString(endDate), 3);

    // Define parameter ranges for optimization
    int fastMAStart = 5, fastMAEnd = 50, fastMAStep = 5;
    int slowMAStart = 10, slowMAEnd = 100, slowMAStep = 10;
    int rsiPeriodStart = 7, rsiPeriodEnd = 21, rsiPeriodStep = 7;
    int rsiOverboughtStart = 60, rsiOverboughtEnd = 80, rsiOverboughtStep = 5;
    int rsiOversoldStart = 20, rsiOversoldEnd = 40, rsiOversoldStep = 5;

    BacktestResult bestResult = {0};
    int bestFastMA = 0, bestSlowMA = 0, bestRSIPeriod = 0, bestRSIOverBought = 0, bestRSIOverSold = 0;

    int totalCombinations = ((fastMAEnd - fastMAStart) / fastMAStep + 1) *
                            ((slowMAEnd - slowMAStart) / slowMAStep + 1) *
                            ((rsiPeriodEnd - rsiPeriodStart) / rsiPeriodStep + 1) *
                            ((rsiOverboughtEnd - rsiOverboughtStart) / rsiOverboughtStep + 1) *
                            ((rsiOversoldEnd - rsiOversoldStart) / rsiOversoldStep + 1);
    int currentCombination = 0;

    // Nested loops for grid search
    for(int fastMA = fastMAStart; fastMA <= fastMAEnd; fastMA += fastMAStep)
    {
        for(int slowMA = slowMAStart; slowMA <= slowMAEnd; slowMA += slowMAStep)
        {
            if(fastMA >= slowMA) continue; // Skip invalid combinations

            for(int rsiPeriod = rsiPeriodStart; rsiPeriod <= rsiPeriodEnd; rsiPeriod += rsiPeriodStep)
            {
                for(int rsiOverbought = rsiOverboughtStart; rsiOverbought <= rsiOverboughtEnd; rsiOverbought += rsiOverboughtStep)
                {
                    for(int rsiOversold = rsiOversoldStart; rsiOversold <= rsiOversoldEnd; rsiOversold += rsiOversoldStep)
                    {
                        if(rsiOversold >= rsiOverbought) continue; // Skip invalid combinations

                        currentCombination++;
                        Log("Testing combination " + IntegerToString(currentCombination) + " of " + IntegerToString(totalCombinations), 3);

                        // Update strategy parameters
                        FastMA = fastMA;
                        SlowMA = slowMA;
                        RSIPeriod = rsiPeriod;
                        RSIOverBought = rsiOverbought;
                        RSIOverSold = rsiOversold;

                        // Run backtest with current parameters
                        BacktestResult result;
                        
                        try
                        {
                            result = Backtest(startDate, endDate);
                        }
                        catch (const exception& e)
                        {
                            Log("Error during backtest: " + e.what(), 1);
                            continue;
                        }

                        // Check if this combination is better than the previous best
                        if(result.totalProfit > bestResult.totalProfit)
                        {
                            bestResult = result;
                            bestFastMA = fastMA;
                            bestSlowMA = slowMA;
                            bestRSIPeriod = rsiPeriod;
                            bestRSIOverBought = rsiOverbought;
                            bestRSIOverSold = rsiOversold;
                        }
                    }
                }
            }
        }
    }

    // Log the best parameters
    Log("Optimization completed. Best parameters:", 3);
    Log("Fast MA: " + IntegerToString(bestFastMA), 3);
    Log("Slow MA: " + IntegerToString(bestSlowMA), 3);
    Log("RSI Period: " + IntegerToString(bestRSIPeriod), 3);
    Log("RSI Overbought: " + IntegerToString(bestRSIOverBought), 3);
    Log("RSI Oversold: " + IntegerToString(bestRSIOverSold), 3);
    Log("Best Profit: " + DoubleToString(bestResult.totalProfit, 2), 3);

    // Update the EA parameters with the best values
    FastMA = bestFastMA;
    SlowMA = bestSlowMA;
    RSIPeriod = bestRSIPeriod;
    RSIOverBought = bestRSIOverBought;
    RSIOverSold = bestRSIOverSold;

    // Save the optimized parameters
    SaveOptimizedParameters();
}

// Save optimized parameters to a CSV file
void MoranFlipper::SaveOptimizedParameters(string filename)
{
    int fileHandle = FileOpen(filename, FILE_WRITE|FILE_CSV);
    
    if(fileHandle != INVALID_HANDLE)
    {
        FileWrite(fileHandle, "Parameter", "Value");
        FileWrite(fileHandle, "FastMA", FastMA);
        FileWrite(fileHandle, "SlowMA", SlowMA);
        FileWrite(fileHandle, "RSIPeriod", RSIPeriod);
        FileWrite(fileHandle, "RSIOverBought", RSIOverBought);
        FileWrite(fileHandle, "RSIOverSold", RSIOverSold);
        
        FileClose(fileHandle);
        Log("Optimized parameters saved to " + filename, 3);
    }
    else
    {
        Log("Failed to save optimized parameters: " + IntegerToString(GetLastError()), 1);
    }
}

// Load optimized parameters from a CSV file
bool MoranFlipper::LoadOptimizedParameters(string filename)
{
    int fileHandle = FileOpen(filename, FILE_READ|FILE_CSV);
    
    if(fileHandle != INVALID_HANDLE)
    {
        // Skip header
        FileReadString(fileHandle);
        FileReadString(fileHandle);
        
        FastMA = (int)StringToInteger(FileReadString(fileHandle));
        SlowMA = (int)StringToInteger(FileReadString(fileHandle));
        RSIPeriod = (int)StringToInteger(FileReadString(fileHandle));
        RSIOverBought = (int)StringToInteger(FileReadString(fileHandle));
        RSIOverSold = (int)StringToInteger(FileReadString(fileHandle));
        
        FileClose(fileHandle);
        Log("Optimized parameters loaded from " + filename, 3);
        return true;
    }
    else
    {
        Log("Failed to load optimized parameters: " + IntegerToString(GetLastError()), 1);
        return false;
    }
}

// Visualization function
void MoranFlipper::VisualizeBacktestResults(const BacktestResult &result, datetime startDate, datetime endDate)
{
    // Create equity curve chart
    long equityChartId = ChartOpen("Equity Curve", 0, 0);
    if(equityChartId == 0)
    {
        Log("Failed to create equity curve chart", 1);
        return;
    }

    // Set up equity curve chart properties
    ChartSetInteger(equityChartId, CHART_AUTOSCROLL, false);
    ChartSetInteger(equityChartId, CHART_SHIFT, true);
    ChartSetInteger(equityChartId, CHART_MODE, CHART_LINE);

    // Create equity curve series
    string equityCurveName = "EquityCurve";
    if(!ObjectCreate(0, equityCurveName, OBJ_TREND, 0, startDate, 0, endDate, result.totalProfit))
    {
        Log("Failed to create equity curve object", 1);
        ChartClose(equityChartId);
        return;
    }

    // Set equity curve properties
    ObjectSetInteger(0, equityCurveName, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, equityCurveName, OBJPROP_WIDTH, 2);

    // Add equity points
    double equity = 0;
    for(int i = 0; i < result.totalTrades; i++)
    {
        equity += result.profits[i];
        string pointName = equityCurveName + IntegerToString(i);
        if(!ObjectCreate(0, pointName, OBJ_ARROW, 0, 
                         startDate + (endDate - startDate) * i / result.totalTrades, equity))
        {
            Log("Failed to create equity point object: " + pointName, 1);
        }
        else
        {
            ObjectSetInteger(0, pointName, OBJPROP_ARROWCODE, 159); // Small dot
            ObjectSetInteger(0, pointName, OBJPROP_COLOR, clrBlue);
        }
    }

    // Create trade distribution chart
    long distributionChartId = ChartOpen("Trade Distribution", 0, 0);
    if(distributionChartId == 0)
    {
        Log("Failed to create trade distribution chart", 1);
        return;
    }

    // Set up trade distribution chart properties
    ChartSetInteger(distributionChartId, CHART_AUTOSCROLL, false);
    ChartSetInteger(distributionChartId, CHART_SHIFT, true);
    ChartSetInteger(distributionChartId, CHART_MODE, CHART_HISTOGRAM);

    // Create trade distribution series
    string profitableTradeName = "ProfitableTrades";
    string unprofitableTradeName = "UnprofitableTrades";

    if(!ObjectCreate(0, profitableTradeName, OBJ_HISTOGRAM, 0, startDate, result.winningTrades) ||
       !ObjectCreate(0, unprofitableTradeName, OBJ_HISTOGRAM, 0, endDate, result.totalTrades - result.winningTrades))
    {
        Log("Failed to create trade distribution objects", 1);
        ChartClose(distributionChartId);
        return;
    }

    // Set trade distribution properties
    ObjectSetInteger(0, profitableTradeName, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, profitableTradeName, OBJPROP_WIDTH, 20);
    ObjectSetInteger(0, unprofitableTradeName, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, unprofitableTradeName, OBJPROP_WIDTH, 20);

    Log("Backtest results visualization created successfully", 3);
}

// Walk-forward analysis
void MoranFlipper::WalkForwardAnalysis(datetime startDate, datetime endDate, int numSegments)
{
    Log("Starting walk-forward analysis", 3);

    // Calculate the total time range
    long totalSeconds = endDate - startDate;
    long segmentSeconds = totalSeconds / numSegments;

    double totalProfit = 0;
    int totalTrades = 0;
    int winningTrades = 0;

    for (int i = 0; i < numSegments; i++)
    {
        datetime segmentStart = startDate + i * segmentSeconds;
        datetime segmentMiddle = segmentStart + segmentSeconds / 2;
        datetime segmentEnd = segmentStart + segmentSeconds;

        if (i == numSegments - 1)
            segmentEnd = endDate;  // Ensure the last segment ends exactly at the endDate

        Log("Segment " + IntegerToString(i+1) + " of " + IntegerToString(numSegments), 3);

        // Optimize on the first half of the segment
        Optimize(segmentStart, segmentMiddle);

        // Test on the second half of the segment
        BacktestResult result = Backtest(segmentMiddle, segmentEnd);

        totalProfit += result.totalProfit;
        totalTrades += result.totalTrades;
        winningTrades += result.winningTrades;

        Log("Segment " + IntegerToString(i+1) + " results:", 3);
        Log("Profit: " + DoubleToString(result.totalProfit, 2), 3);
        Log("Trades: " + IntegerToString(result.totalTrades), 3);
        Log("Win rate: " + DoubleToString(result.winRate, 2) + "%", 3);
    }

    double overallWinRate = totalTrades > 0 ? (double)winningTrades / totalTrades * 100 : 0;

    Log("Walk-forward analysis completed. Overall results:", 3);
    Log("Total profit: " + DoubleToString(totalProfit, 2), 3);
    Log("Total trades: " + IntegerToString(totalTrades), 3);
    Log("Overall win rate: " + DoubleToString(overallWinRate, 2) + "%", 3);
}

// Main processing function
void MoranFlipper::Processing()
{
    if (!IsNewBar())
        return;
    
    Log("Starting new bar processing", 3);
    
    try
    {
        // Get current market data
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // Calculate indicators
        double fastMA = iMA(_Symbol, PERIOD_CURRENT, FastMA, 0, MODE_SMA, PRICE_CLOSE);
        double slowMA = iMA(_Symbol, PERIOD_CURRENT, SlowMA, 0, MODE_SMA, PRICE_CLOSE);
        double rsi = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
        
        // Perform other analyses
        SupplyDemandZones();
        ChartPatterns();
        FibonacciRetracements();
        OrderBlocks();
        FairValueGaps();
        SupportResistance();
        MarketStructureBreaks();
        TrendlineAnalysis();
        
        // Decision making based on indicators and analyses
        bool shouldBuy = false;
        bool shouldSell = false;
        
        // Check for buy signals
        if (fastMA > slowMA && rsi < RSIOverSold && IsBuySignal(currentPrice))
        {
            shouldBuy = true;
            Log("Buy signal detected", 3);
        }
        // Check for sell signals
        else if (fastMA < slowMA && rsi > RSIOverBought && IsSellSignal(currentPrice))
        {
            shouldSell = true;
            Log("Sell signal detected", 3);
        }
        
        // Execute trades if conditions are met
        if (shouldBuy || shouldSell)
        {
            double lotSize = CalculatePositionSize();
            
            if (shouldBuy)
            {
                if (m_trade.Buy(lotSize, _Symbol, 0, 0, 0, "Moran Flipper Buy"))
                {
                    SetStopLoss();
                    SetTakeProfit();
                    Log("Buy order executed", 3);
                }
                else
                {
                    Log("Failed to execute buy order: " + IntegerToString(GetLastError()), 1);
                }
            }
            else if (shouldSell)
            {
                if (m_trade.Sell(lotSize, _Symbol, 0, 0, 0, "Moran Flipper Sell"))
                {
                    SetStopLoss();
                    SetTakeProfit();
                    Log("Sell order executed", 3);
                }
                else
                {
                    Log("Failed to execute sell order: " + IntegerToString(GetLastError()), 1);
                }
            }
        }
        
        // Check for exit conditions
        if (PositionSelect(_Symbol))
        {
            ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double positionProfit = PositionGetDouble(POSITION_PROFIT);
            
            bool shouldExit = false;
            
            if (positionType == POSITION_TYPE_BUY && (fastMA < slowMA || rsi > RSIOverBought))
            {
                shouldExit = true;
            }
            else if (positionType == POSITION_TYPE_SELL && (fastMA > slowMA || rsi < RSIOverSold))
            {
                shouldExit = true;
            }
            
            if (shouldExit)
            {
                if (m_trade.PositionClose(_Symbol))
                {
                    Log("Position closed. Profit: " + DoubleToString(positionProfit, 2), 3);
                }
                else
                {
                    Log("Failed to close position: " + IntegerToString(GetLastError()), 1);
                }
            }
        }
    }
    catch (const exception& e)
    {
        Log("Error in Processing: " + e.what(), 1);
    }
}

// Helper function to check for buy signals
bool MoranFlipper::IsBuySignal(double currentPrice)
{
    // Implement your buy signal logic here
    // This is a placeholder implementation
    bool hasSupplyZone = false;
    bool hasBullishPattern = false;
    bool isAboveSupportLevel = false;
    
    // Check for supply zone
    for(int i = 0; i < m_zones.Total(); i++)
    {
        Zone* zone = m_zones.At(i);
        if(!zone.isSupply && currentPrice > zone.price)
        {
            hasSupplyZone = true;
            break;
        }
    }
    
    // Check for bullish chart pattern
    for(int i = 0; i < m_patterns.Total(); i++)
    {
        ChartPattern* pattern = m_patterns.At(i);
        if(pattern.type == ChartPattern::INVERSE_HEAD_AND_SHOULDERS || 
           pattern.type == ChartPattern::DOUBLE_BOTTOM ||
           pattern.type == ChartPattern::ASCENDING_TRIANGLE)
        {
            hasBullishPattern = true;
            break;
        }
    }
    
    // Check if price is above support level
    for(int i = 0; i < m_srLevels.Total(); i++)
    {
        SRLevel* level = m_srLevels.At(i);
        if(level.isSupport && currentPrice > level.price)
        {
            isAboveSupportLevel = true;
            break;
        }
    }
    
    return hasSupplyZone && hasBullishPattern && isAboveSupportLevel;
}

// Helper function to check for sell signals
bool MoranFlipper::IsSellSignal(double currentPrice)
{
    // Implement your sell signal logic here
    // This is a placeholder implementation
    bool hasDemandZone = false;
    bool hasBearishPattern = false;
    bool isBelowResistanceLevel = false;
    
    // Check for demand zone
    for(int i = 0; i < m_zones.Total(); i++)
    {
        Zone* zone = m_zones.At(i);
        if(zone.isSupply && currentPrice < zone.price)
        {
            hasDemandZone = true;
            break;
        }
    }
    
    // Check for bearish chart pattern
    for(int i = 0; i < m_patterns.Total(); i++)
    {
        ChartPattern* pattern = m_patterns.At(i);
        if(pattern.type == ChartPattern::HEAD_AND_SHOULDERS || 
           pattern.type == ChartPattern::DOUBLE_TOP ||
           pattern.type == ChartPattern::DESCENDING_TRIANGLE)
        {
            hasBearishPattern = true;
            break;
        }
    }
    
    // Check if price is below resistance level
    for(int i = 0; i < m_srLevels.Total(); i++)
    {
        SRLevel* level = m_srLevels.At(i);
        if(!level.isSupport && currentPrice < level.price)
        {
            isBelowResistanceLevel = true;
            break;
        }
    }
    
    return hasDemandZone && hasBearishPattern && isBelowResistanceLevel;
}

// Entry point of the Expert Advisor
void OnTick()
{
    static MoranFlipper ea;
    ea.Processing();
}

void OnInit()
{
    MoranFlipper ea;
    ea.Init();
}

void OnDeinit(const int reason)
{
    MoranFlipper ea;
    ea.Deinit();
}

// Implement other necessary functions...

// Implementation of IsNewBar function
bool MoranFlipper::IsNewBar()
{
    datetime current_bar_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    if (current_bar_time != m_last_bar_time)
    {
        m_last_bar_time = current_bar_time;
        return true;
    }
    
    return false;
}

// Implementation of CalculatePositionSize function
double MoranFlipper::CalculatePositionSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

    // Use the smaller of balance or equity to be conservative
    double accountSize = MathMin(balance, equity);

    // Calculate the risk amount based on the risk percentage
    double riskAmount = accountSize * (RiskPercentage / 100.0);

    // Get the current market price
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Calculate the stop loss level (you may want to replace this with your own stop loss calculation)
    double stopLossPoints = 50 * _Point; // Example: 50 points stop loss
    double stopLossLevel = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) 
                           ? currentPrice - stopLossPoints 
                           : currentPrice + stopLossPoints;

    // Calculate the risk per unit (point)
    double riskPerUnit = MathAbs(currentPrice - stopLossLevel);

    // Calculate the position size based on the risk amount and risk per unit
    double positionSize = riskAmount / riskPerUnit;

    // Get symbol trade information
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    // Normalize the position size to the allowed lot step
    positionSize = MathFloor(positionSize / lotStep) * lotStep;

    // Ensure the position size is within the allowed range
    positionSize = MathMax(minLot, MathMin(positionSize, maxLot));

    // Ensure the position size doesn't exceed the maximum allowed lot size
    positionSize = MathMin(positionSize, MaxLotSize);

    // Check if we have enough free margin for this position size
    double margin = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
    if (positionSize * margin > freeMargin)
    {
        // If not enough free margin, reduce the position size
        positionSize = MathFloor(freeMargin / margin / lotStep) * lotStep;
    }

    return NormalizeDouble(positionSize, 2);
}

// Update constructor to initialize m_last_bar_time
MoranFlipper::MoranFlipper()
{
    m_last_bar_time = 0;
}

// Implementation of SetStopLoss function
void MoranFlipper::SetStopLoss()
{
    // Get the current position
    if (!m_position.Select(_Symbol))
        return;

    double currentStopLoss = m_position.StopLoss();
    double newStopLoss = 0;

    // Calculate new stop loss based on your strategy
    // This is a simple example, replace with your own logic
    if (m_position.Type() == POSITION_TYPE_BUY)
    {
        newStopLoss = m_position.PriceOpen() - (100 * _Point); // 100 points below entry
    }
    else if (m_position.Type() == POSITION_TYPE_SELL)
    {
        newStopLoss = m_position.PriceOpen() + (100 * _Point); // 100 points above entry
    }

    // Modify the position if the new stop loss is different
    if (newStopLoss != currentStopLoss)
    {
        m_trade.PositionModify(m_position.Ticket(), newStopLoss, m_position.TakeProfit());
    }
}

// Implementation of SetTakeProfit function
void MoranFlipper::SetTakeProfit()
{
    // Get the current position
    if (!m_position.Select(_Symbol))
        return;

    double currentTakeProfit = m_position.TakeProfit();
    double newTakeProfit = 0;

    // Calculate new take profit based on your strategy
    // This is a simple example, replace with your own logic
    if (m_position.Type() == POSITION_TYPE_BUY)
    {
        newTakeProfit = m_position.PriceOpen() + (200 * _Point); // 200 points above entry
    }
    else if (m_position.Type() == POSITION_TYPE_SELL)
    {
        newTakeProfit = m_position.PriceOpen() - (200 * _Point); // 200 points below entry
    }

    // Modify the position if the new take profit is different
    if (newTakeProfit != currentTakeProfit)
    {
        m_trade.PositionModify(m_position.Ticket(), m_position.StopLoss(), newTakeProfit);
    }
}

// Implementation of TrendlineAnalysis method
void MoranFlipper::TrendlineAnalysis()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (bars < 100) return; // Ensure we have enough bars to analyze

    // Clear old Trendlines
    m_trendlines.Clear();

    // Find resistance trendlines
    FindTrendlines(true);

    // Find support trendlines
    FindTrendlines(false);
}

// Helper function to find trendlines
void MoranFlipper::FindTrendlines(bool isResistance)
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    int lookback = MathMin(bars, 100); // Look back up to 100 bars

    for (int start = lookback - 1; start >= 2; start--)
    {
        for (int end = start - 1; end >= 1; end--)
        {
            if (IsTrendlineValid(start, end, isResistance))
            {
                AddTrendline(start, end, isResistance);
                break; // Move to the next starting point
            }
        }
    }
}

// Helper function to check if a trendline is valid
bool MoranFlipper::IsTrendlineValid(int start, int end, bool isResistance)
{
    double startPrice = isResistance ? iHigh(_Symbol, PERIOD_CURRENT, start) : iLow(_Symbol, PERIOD_CURRENT, start);
    double endPrice = isResistance ? iHigh(_Symbol, PERIOD_CURRENT, end) : iLow(_Symbol, PERIOD_CURRENT, end);

    // Calculate the slope and intercept of the potential trendline
    double slope = (endPrice - startPrice) / (end - start);
    double intercept = startPrice - slope * start;

    // Check if the trendline touches or is very close to at least 3 points
    int touchCount = 0;
    for (int i = start; i >= end; i--)
    {
        double expectedPrice = slope * i + intercept;
        double actualPrice = isResistance ? iHigh(_Symbol, PERIOD_CURRENT, i) : iLow(_Symbol, PERIOD_CURRENT, i);

        if (MathAbs(expectedPrice - actualPrice) <= 5 * _Point) // Allow for a small deviation
        {
            touchCount++;
        }
    }

    return (touchCount >= 3);
}

// Helper function to add identified Trendlines
void MoranFlipper::AddTrendline(int start, int end, bool isResistance)
{
    Trendline* trendline = new Trendline;
    trendline.startTime = iTime(_Symbol, PERIOD_CURRENT, start);
    trendline.endTime = iTime(_Symbol, PERIOD_CURRENT, end);
    trendline.startPrice = isResistance ? iHigh(_Symbol, PERIOD_CURRENT, start) : iLow(_Symbol, PERIOD_CURRENT, start);
    trendline.endPrice = isResistance ? iHigh(_Symbol, PERIOD_CURRENT, end) : iLow(_Symbol, PERIOD_CURRENT, end);
    trendline.isResistance = isResistance;

    m_trendlines.Add(trendline);
}

// Implementation of MarketStructureBreaks method
void MoranFlipper::MarketStructureBreaks()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (bars < 100) return; // Ensure we have enough bars to analyze

    // Clear old Market Structure Breaks
    m_msb.Clear();

    int left = 5;  // Number of candles to check on the left side
    int right = 5; // Number of candles to check on the right side

    // Look for Market Structure Breaks in the last 100 bars
    for (int i = right; i < MathMin(bars - left, 100); i++)
    {
        // Check for Higher High (Bullish Break)
        if (IsHigherHigh(i, left, right))
        {
            AddMSB(i, true);
        }
        // Check for Lower Low (Bearish Break)
        else if (IsLowerLow(i, left, right))
        {
            AddMSB(i, false);
        }
    }
}

// Helper function to identify Higher High
bool MoranFlipper::IsHigherHigh(int candle, int left, int right)
{
    double high = iHigh(_Symbol, PERIOD_CURRENT, candle);
    
    for (int i = candle - left; i < candle; i++)
    {
        if (iHigh(_Symbol, PERIOD_CURRENT, i) >= high)
            return false;
    }
    
    for (int i = candle + 1; i <= candle + right; i++)
    {
        if (iHigh(_Symbol, PERIOD_CURRENT, i) > high)
            return false;
    }
    
    return true;
}

// Helper function to identify Lower Low
bool MoranFlipper::IsLowerLow(int candle, int left, int right)
{
    double low = iLow(_Symbol, PERIOD_CURRENT, candle);
    
    for (int i = candle - left; i < candle; i++)
    {
        if (iLow(_Symbol, PERIOD_CURRENT, i) <= low)
            return false;
    }
    
    for (int i = candle + 1; i <= candle + right; i++)
    {
        if (iLow(_Symbol, PERIOD_CURRENT, i) < low)
            return false;
    }
    
    return true;
}

// Helper function to add identified Market Structure Breaks
void MoranFlipper::AddMSB(int candle, bool isBullish)
{
    MSB* msb = new MSB;
    msb.time = iTime(_Symbol, PERIOD_CURRENT, candle);
    msb.price = isBullish ? iHigh(_Symbol, PERIOD_CURRENT, candle) : iLow(_Symbol, PERIOD_CURRENT, candle);
    msb.isBullish = isBullish;
    
    m_msb.Add(msb);
}

// Implementation of SupportResistance method
void MoranFlipper::SupportResistance()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (bars < 100) return; // Ensure we have enough bars to analyze

    // Clear old Support/Resistance levels
    m_srLevels.Clear();

    int left = 5;  // Number of candles to check on the left side
    int right = 5; // Number of candles to check on the right side

    // Look for Support/Resistance levels in the last 100 bars
    for (int i = right; i < MathMin(bars - left, 100); i++)
    {
        // Check for Support level
        if (IsSupport(i, left, right))
        {
            double supportPrice = iLow(_Symbol, PERIOD_CURRENT, i);
            datetime supportTime = iTime(_Symbol, PERIOD_CURRENT, i);
            int strength = CalculateLevelStrength(supportPrice, true);
            AddSRLevel(supportPrice, supportTime, true, strength);
        }
        // Check for Resistance level
        else if (IsResistance(i, left, right))
        {
            double resistancePrice = iHigh(_Symbol, PERIOD_CURRENT, i);
            datetime resistanceTime = iTime(_Symbol, PERIOD_CURRENT, i);
            int strength = CalculateLevelStrength(resistancePrice, false);
            AddSRLevel(resistancePrice, resistanceTime, false, strength);
        }
    }
}

// Helper function to identify Support levels
bool MoranFlipper::IsSupport(int candle, int left, int right)
{
    double low = iLow(_Symbol, PERIOD_CURRENT, candle);
    
    for (int i = candle - left; i < candle; i++)
    {
        if (iLow(_Symbol, PERIOD_CURRENT, i) > low)
            return false;
    }
    
    for (int i = candle + 1; i <= candle + right; i++)
    {
        if (iLow(_Symbol, PERIOD_CURRENT, i) > low)
            return false;
    }
    
    return true;
}

// Helper function to identify Resistance levels
bool MoranFlipper::IsResistance(int candle, int left, int right)
{
    double high = iHigh(_Symbol, PERIOD_CURRENT, candle);
    
    for (int i = candle - left; i < candle; i++)
    {
        if (iHigh(_Symbol, PERIOD_CURRENT, i) < high)
            return false;
    }
    
    for (int i = candle + 1; i <= candle + right; i++)
    {
        if (iHigh(_Symbol, PERIOD_CURRENT, i) < high)
            return false;
    }
    
    return true;
}

// Helper function to add identified Support/Resistance levels
void MoranFlipper::AddSRLevel(double price, datetime time, bool isSupport, int strength)
{
    SRLevel* level = new SRLevel;
    level.price = price;
    level.time = time;
    level.isSupport = isSupport;
    level.strength = strength;
    
    m_srLevels.Add(level);
}

// Helper function to calculate the strength of a Support/Resistance level
int MoranFlipper::CalculateLevelStrength(double price, bool isSupport)
{
    int strength = 0;
    int touchCount = 0;
    double touchThreshold = 10 * _Point; // Adjust this value based on the instrument

    for (int i = 0; i < 1000; i++) // Check the last 1000 candles
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);

        if (isSupport)
        {
            if (MathAbs(low - price) <= touchThreshold)
            {
                touchCount++;
                strength += 2;
            }
            else if (low < price && high > price)
            {
                strength++;
            }
        }
        else // Resistance
        {
            if (MathAbs(high - price) <= touchThreshold)
            {
                touchCount++;
                strength += 2;
            }
            else if (high > price && low < price)
            {
                strength++;
            }
        }

        if (touchCount >= 3) break; // Consider the level strong enough after 3 touches
    }

    return strength;
}

// Implementation of FairValueGaps method
void MoranFlipper::FairValueGaps()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (bars < 100) return; // Ensure we have enough bars to analyze

    // Clear old Fair Value Gaps
    m_fvg.Clear();

    // Look for Fair Value Gaps in the last 100 bars
    for (int i = 2; i < 100; i++)
    {
        // Check for bullish Fair Value Gap
        if (IsFairValueGap(i, true))
        {
            AddFairValueGap(i, true);
        }
        // Check for bearish Fair Value Gap
        else if (IsFairValueGap(i, false))
        {
            AddFairValueGap(i, false);
        }
    }
}

// Helper function to identify Fair Value Gaps
bool MoranFlipper::IsFairValueGap(int startBar, bool isBullish)
{
    double bar1High = iHigh(_Symbol, PERIOD_CURRENT, startBar);
    double bar1Low = iLow(_Symbol, PERIOD_CURRENT, startBar);
    double bar2High = iHigh(_Symbol, PERIOD_CURRENT, startBar - 1);
    double bar2Low = iLow(_Symbol, PERIOD_CURRENT, startBar - 1);
    double bar3High = iHigh(_Symbol, PERIOD_CURRENT, startBar - 2);
    double bar3Low = iLow(_Symbol, PERIOD_CURRENT, startBar - 2);
    
    if (isBullish)
    {
        // Bullish FVG: Low of bar1 > High of bar3
        return (bar1Low > bar3High);
    }
    else
    {
        // Bearish FVG: High of bar1 < Low of bar3
        return (bar1High < bar3Low);
    }
}

// Helper function to add identified Fair Value Gaps
void MoranFlipper::AddFairValueGap(int startBar, bool isBullish)
{
    FairValueGap* gap = new FairValueGap;
    gap.time = iTime(_Symbol, PERIOD_CURRENT, startBar - 1);
    
    if (isBullish)
    {
        gap.upperBound = iLow(_Symbol, PERIOD_CURRENT, startBar);
        gap.lowerBound = iHigh(_Symbol, PERIOD_CURRENT, startBar - 2);
    }
    else
    {
        gap.upperBound = iLow(_Symbol, PERIOD_CURRENT, startBar - 2);
        gap.lowerBound = iHigh(_Symbol, PERIOD_CURRENT, startBar);
    }
    
    gap.isBullish = isBullish;
    
    m_fvg.Add(gap);
}

// Implementation of OrderBlocks method
void MoranFlipper::OrderBlocks()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (bars < 100) return; // Ensure we have enough bars to analyze

    // Clear old Order Blocks
    m_orderBlocks.Clear();

    // Look for Order Blocks in the last 100 bars
    for (int i = 1; i < 100; i++)
    {
        // Check for bullish Order Block
        if (IsOrderBlock(i, true))
        {
            AddOrderBlock(i, true);
        }
        // Check for bearish Order Block
        else if (IsOrderBlock(i, false))
        {
            AddOrderBlock(i, false);
        }
    }
}

// Helper function to identify Order Blocks
bool MoranFlipper::IsOrderBlock(int startBar, bool isBullish)
{
    double currentOpen = iOpen(_Symbol, PERIOD_CURRENT, startBar);
    double currentClose = iClose(_Symbol, PERIOD_CURRENT, startBar);
    double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, startBar);
    double currentLow = iLow(_Symbol, PERIOD_CURRENT, startBar);
    
    double nextOpen = iOpen(_Symbol, PERIOD_CURRENT, startBar - 1);
    double nextClose = iClose(_Symbol, PERIOD_CURRENT, startBar - 1);
    
    if (isBullish)
    {
        // Bullish Order Block: Current candle is bearish, next candle is bullish and breaks the high
        return (currentClose < currentOpen) && (nextClose > nextOpen) && (nextClose > currentHigh);
    }
    else
    {
        // Bearish Order Block: Current candle is bullish, next candle is bearish and breaks the low
        return (currentClose > currentOpen) && (nextClose < nextOpen) && (nextClose < currentLow);
    }
}

// Helper function to add identified Order Blocks
void MoranFlipper::AddOrderBlock(int startBar, bool isBullish)
{
    OrderBlock* block = new OrderBlock;
    block.time = iTime(_Symbol, PERIOD_CURRENT, startBar);
    block.high = iHigh(_Symbol, PERIOD_CURRENT, startBar);
    block.low = iLow(_Symbol, PERIOD_CURRENT, startBar);
    block.isBullish = isBullish;
    
    m_orderBlocks.Add(block);
}

// Implementation of FibonacciRetracements method
void MoranFlipper::FibonacciRetracements()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (bars < 100) return; // Ensure we have enough bars to analyze

    // Clear old Fibonacci levels
    m_fibLevels.Clear();

    // Find the most recent swing high and low
    int swingHighBar = FindSwingHigh(0, 100);
    int swingLowBar = FindSwingLow(0, 100);

    if (swingHighBar == -1 || swingLowBar == -1) return; // No valid swing points found

    double swingHigh = iHigh(_Symbol, PERIOD_CURRENT, swingHighBar);
    double swingLow = iLow(_Symbol, PERIOD_CURRENT, swingLowBar);

    // Determine if we're in an uptrend or downtrend
    bool isUptrend = swingHighBar < swingLowBar;

    // Calculate and store Fibonacci levels
    CalculateFibLevels(swingHigh, swingLow, isUptrend);
}

// Helper function to calculate Fibonacci retracement levels
void MoranFlipper::CalculateFibLevels(double high, double low, bool isUptrend)
{
    double fibLevels[] = {0.236, 0.382, 0.5, 0.618, 0.786};
    double range = high - low;

    for (int i = 0; i < ArraySize(fibLevels); i++)
    {
        FibLevel* level = new FibLevel;
        level.level = fibLevels[i];
        level.price = isUptrend ? high - range * fibLevels[i] : low + range * fibLevels[i];
        m_fibLevels.Add(level);
    }
}

// Helper function to find the most recent swing high
int MoranFlipper::FindSwingHigh(int startBar, int barsToCheck)
{
    int swingHighBar = -1;
    double swingHigh = 0;

    for (int i = startBar; i < startBar + barsToCheck; i++)
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        if (high > swingHigh && IsSwingHigh(i))
        {
            swingHigh = high;
            swingHighBar = i;
        }
    }

    return swingHighBar;
}

// Helper function to find the most recent swing low
int MoranFlipper::FindSwingLow(int startBar, int barsToCheck)
{
    int swingLowBar = -1;
    double swingLow = DBL_MAX;

    for (int i = startBar; i < startBar + barsToCheck; i++)
    {
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        if (low < swingLow && IsSwingLow(i))
        {
            swingLow = low;
            swingLowBar = i;
        }
    }

    return swingLowBar;
}

// Implementation of ChartPatterns method
void MoranFlipper::ChartPatterns()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (bars < 100) return; // Ensure we have enough bars to analyze

    // Clear old patterns
    m_patterns.Clear();

    // Look for patterns in the last 100 bars
    for (int i = 0; i < 100; i++)
    {
        // Check for Head and Shoulders pattern
        if (IsHeadAndShoulders(i, false))
        {
            ChartPattern* pattern = new ChartPattern;
            pattern.type = ChartPattern::HEAD_AND_SHOULDERS;
            pattern.startTime = iTime(_Symbol, PERIOD_CURRENT, i + 30); // Approximate pattern length
            pattern.endTime = iTime(_Symbol, PERIOD_CURRENT, i);
            pattern.entryPrice = iLow(_Symbol, PERIOD_CURRENT, i); // Neckline break
            pattern.stopLoss = iHigh(_Symbol, PERIOD_CURRENT, i + 15); // Head of the pattern
            pattern.takeProfit = pattern.entryPrice - (pattern.stopLoss - pattern.entryPrice); // 1:1 risk-reward
            m_patterns.Add(pattern);
        }

        // Check for Inverse Head and Shoulders pattern
        if (IsHeadAndShoulders(i, true))
        {
            ChartPattern* pattern = new ChartPattern;
            pattern.type = ChartPattern::INVERSE_HEAD_AND_SHOULDERS;
            pattern.startTime = iTime(_Symbol, PERIOD_CURRENT, i + 30);
            pattern.endTime = iTime(_Symbol, PERIOD_CURRENT, i);
            pattern.entryPrice = iHigh(_Symbol, PERIOD_CURRENT, i);
            pattern.stopLoss = iLow(_Symbol, PERIOD_CURRENT, i + 15);
            pattern.takeProfit = pattern.entryPrice + (pattern.entryPrice - pattern.stopLoss);
            m_patterns.Add(pattern);
        }

        // Check for Double Top pattern
        if (IsDoubleTopBottom(i, true))
        {
            ChartPattern* pattern = new ChartPattern;
            pattern.type = ChartPattern::DOUBLE_TOP;
            pattern.startTime = iTime(_Symbol, PERIOD_CURRENT, i + 20);
            pattern.endTime = iTime(_Symbol, PERIOD_CURRENT, i);
            pattern.entryPrice = iLow(_Symbol, PERIOD_CURRENT, i + 10); // Neckline break
            pattern.stopLoss = iHigh(_Symbol, PERIOD_CURRENT, i);
            pattern.takeProfit = pattern.entryPrice - (pattern.stopLoss - pattern.entryPrice);
            m_patterns.Add(pattern);
        }

        // Check for Double Bottom pattern
        if (IsDoubleTopBottom(i, false))
        {
            ChartPattern* pattern = new ChartPattern;
            pattern.type = ChartPattern::DOUBLE_BOTTOM;
            pattern.startTime = iTime(_Symbol, PERIOD_CURRENT, i + 20);
            pattern.endTime = iTime(_Symbol, PERIOD_CURRENT, i);
            pattern.entryPrice = iHigh(_Symbol, PERIOD_CURRENT, i + 10);
            pattern.stopLoss = iLow(_Symbol, PERIOD_CURRENT, i);
            pattern.takeProfit = pattern.entryPrice + (pattern.entryPrice - pattern.stopLoss);
            m_patterns.Add(pattern);
        }

        // Check for Triangle patterns
        int triangleType;
        if (IsTriangle(i, triangleType))
        {
            ChartPattern* pattern = new ChartPattern;
            pattern.type = (ChartPattern::PatternType)triangleType;
            pattern.startTime = iTime(_Symbol, PERIOD_CURRENT, i + 20);
            pattern.endTime = iTime(_Symbol, PERIOD_CURRENT, i);
            pattern.entryPrice = iClose(_Symbol, PERIOD_CURRENT, i);
            pattern.stopLoss = (triangleType == ChartPattern::ASCENDING_TRIANGLE) ? iLow(_Symbol, PERIOD_CURRENT, i + 20) : iHigh(_Symbol, PERIOD_CURRENT, i + 20);
            pattern.takeProfit = pattern.entryPrice + (pattern.entryPrice - pattern.stopLoss) * (triangleType == ChartPattern::DESCENDING_TRIANGLE ? -1 : 1);
            m_patterns.Add(pattern);
        }
    }
}

// Helper function to identify Head and Shoulders pattern
bool MoranFlipper::IsHeadAndShoulders(int startBar, bool inverse)
{
    double leftShoulder = inverse ? iLow(_Symbol, PERIOD_CURRENT, startBar + 30) : iHigh(_Symbol, PERIOD_CURRENT, startBar + 30);
    double head = inverse ? iLow(_Symbol, PERIOD_CURRENT, startBar + 15) : iHigh(_Symbol, PERIOD_CURRENT, startBar + 15);
    double rightShoulder = inverse ? iLow(_Symbol, PERIOD_CURRENT, startBar) : iHigh(_Symbol, PERIOD_CURRENT, startBar);

    if (inverse)
    {
        return (head < leftShoulder && head < rightShoulder && MathAbs(leftShoulder - rightShoulder) / _Point < 50);
    }
    else
    {
        return (head > leftShoulder && head > rightShoulder && MathAbs(leftShoulder - rightShoulder) / _Point < 50);
    }
}

// Helper function to identify Double Top/Bottom pattern
bool MoranFlipper::IsDoubleTopBottom(int startBar, bool isTop)
{
    double first = isTop ? iHigh(_Symbol, PERIOD_CURRENT, startBar + 20) : iLow(_Symbol, PERIOD_CURRENT, startBar + 20);
    double second = isTop ? iHigh(_Symbol, PERIOD_CURRENT, startBar) : iLow(_Symbol, PERIOD_CURRENT, startBar);

    return (MathAbs(first - second) / _Point < 20);
}

// Helper function to identify Triangle patterns
bool MoranFlipper::IsTriangle(int startBar, int &outType)
{
    double high1 = iHigh(_Symbol, PERIOD_CURRENT, startBar + 20);
    double high2 = iHigh(_Symbol, PERIOD_CURRENT, startBar + 10);
    double high3 = iHigh(_Symbol, PERIOD_CURRENT, startBar);

    double low1 = iLow(_Symbol, PERIOD_CURRENT, startBar + 20);
    double low2 = iLow(_Symbol, PERIOD_CURRENT, startBar + 10);
    double low3 = iLow(_Symbol, PERIOD_CURRENT, startBar);

    if (high1 > high2 && high2 > high3 && low1 < low2 && low2 < low3)
    {
        outType = ChartPattern::DESCENDING_TRIANGLE;
        return true;
    }
    else if (high1 < high2 && high2 < high3 && low1 > low2 && low2 > low3)
    {
        outType = ChartPattern::ASCENDING_TRIANGLE;
        return true;
    }
    else if ((high1 > high2 && high2 > high3 && low1 < low2 && low2 < low3) ||
             (high1 < high2 && high2 < high3 && low1 > low2 && low2 > low3))
    {
        outType = ChartPattern::SYMMETRIC_TRIANGLE;
        return true;
    }

    return false;
}

// Implementation of SupplyDemandZones method
void MoranFlipper::SupplyDemandZones()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (bars < InpZoneLookback) return;

    for (int i = InpZoneLookback; i > 1; i--)
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        double close = iClose(_Symbol, PERIOD_CURRENT, i);
        double volume = iVolume(_Symbol, PERIOD_CURRENT, i);

        // Check for potential supply zone
        if (IsSwingHigh(i))
        {
            double zoneStrength = CalculateZoneStrength(high, volume, true);
            if (zoneStrength >= InpZoneStrength)
            {
                Zone* newZone = new Zone;
                newZone.price = high;
                newZone.time = iTime(_Symbol, PERIOD_CURRENT, i);
                newZone.isSupply = true;
                m_zones.Add(newZone);
            }
        }
        
        // Check for potential demand zone
        if (IsSwingLow(i))
        {
            double zoneStrength = CalculateZoneStrength(low, volume, false);
            if (zoneStrength >= InpZoneStrength)
            {
                Zone* newZone = new Zone;
                newZone.price = low;
                newZone.time = iTime(_Symbol, PERIOD_CURRENT, i);
                newZone.isSupply = false;
                m_zones.Add(newZone);
            }
        }
    }

    // Remove expired zones
    for (int i = m_zones.Total() - 1; i >= 0; i--)
    {
        Zone* zone = m_zones.At(i);
        if (iBarShift(_Symbol, PERIOD_CURRENT, zone.time) > InpZoneTimeout)
        {
            m_zones.Delete(i);
        }
    }
}

// Helper function to check if a bar is a swing high
bool MoranFlipper::IsSwingHigh(int shift)
{
    double high = iHigh(_Symbol, PERIOD_CURRENT, shift);
    return (high > iHigh(_Symbol, PERIOD_CURRENT, shift + 1) &&
            high > iHigh(_Symbol, PERIOD_CURRENT, shift - 1));
}

// Helper function to check if a bar is a swing low
bool MoranFlipper::IsSwingLow(int shift)
{
    double low = iLow(_Symbol, PERIOD_CURRENT, shift);
    return (low < iLow(_Symbol, PERIOD_CURRENT, shift + 1) &&
            low < iLow(_Symbol, PERIOD_CURRENT, shift - 1));
}

// Helper function to calculate zone strength based on price and volume
double MoranFlipper::CalculateZoneStrength(double price, double volume, bool isSupply)
{
    // Implement your own logic to calculate zone strength
    // This is a simplified example
    double averageVolume = iVolume(_Symbol, PERIOD_CURRENT, 1);
    for (int i = 2; i <= 10; i++)
    {
        averageVolume += iVolume(_Symbol, PERIOD_CURRENT, i);
    }
    averageVolume /= 10;

    double volumeStrength = volume / averageVolume;
    double priceStrength = isSupply ? 1.0 : -1.0; // Simplified, you may want to implement more sophisticated logic

    return volumeStrength * priceStrength;
}



// Helper function to check for a new bar
bool MoranFlipper::IsNewBar()
{
    static datetime last_time = 0;
    datetime current_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(current_time != last_time)
    {
        last_time = current_time;
        return true;
    }
    return false;
}

// Helper function to initialize indicators
bool MoranFlipper::InitializeIndicators()
{
    // Initialize indicators here
    // For example:
    // m_fastMAHandle = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    // if(m_fastMAHandle == INVALID_HANDLE) return false;
    
    return true; // Return true if all indicators are initialized successfully
}

// Helper function to release indicator handles
void MoranFlipper::ReleaseIndicators()
{
    // Release indicator handles here
    // For example:
    // IndicatorRelease(m_fastMAHandle);
}

// Helper function to close all open positions
void MoranFlipper::CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                m_trade.PositionClose(m_position.Ticket());
            }
        }
    }
}

// Helper function to cancel all pending orders
void MoranFlipper::CancelAllPendingOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == _Symbol)
            {
                m_trade.OrderDelete(OrderTicket());
            }
        }
    }
}

// Helper function to manage open positions
void MoranFlipper::ManageOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol)
            {
                // Implement your position management logic here
                // For example, trailing stop, time-based exit, etc.
            }
        }
    }
}


// Initialization function
bool MoranFlipper::Init()
{
    Log("Initializing Moran Flipper v1.0", 3);

    // Initialize trade object
    if(!m_trade.SetExpertMagicNumber(123456))
    {
        Log("Failed to set expert magic number", 1);
        return false;
    }

    // Initialize indicators
    if(!InitializeIndicators())
    {
        Log("Failed to initialize indicators", 1);
        return false;
    }

    // Set up symbol and timeframe
    if(!SymbolSelect(_Symbol, true))
    {
        Log("Failed to select symbol: " + _Symbol, 1);
        return false;
    }

    // Check if the symbol is available for trading
    if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE))
    {
        Log("Symbol is not available for trading: " + _Symbol, 1);
        return false;
    }

    // Initialize strategy parameters
    m_fastMA = FastMA;
    m_slowMA = SlowMA;
    m_rsiPeriod = RSIPeriod;

    // Run function tests
    if(!TestFunctions())
    {
        Log("Function tests failed", 1);
        return false;
    }

    Log("Moran Flipper v1.0 initialized successfully", 3);
    return true;
}


// Main processing function
void MoranFlipper::Processing()
{
    if (!IsNewBar())
        return;
    
    Log("Starting new bar processing", 3);
    
    // Get current market data
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate indicators
    double fastMA = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    double slowMA = iMA(_Symbol, PERIOD_CURRENT, m_slowMA, 0, MODE_SMA, PRICE_CLOSE);
    double rsi = iRSI(_Symbol, PERIOD_CURRENT, m_rsiPeriod, PRICE_CLOSE);
    
    // Perform analysis
    SupplyDemandZones();
    ChartPatterns();
    FibonacciRetracements();
    OrderBlocks();
    FairValueGaps();
    SupportResistance();
    MarketStructureBreaks();
    TrendlineAnalysis();
    
    // Decision making based on indicators and analysis
    bool shouldBuy = false;
    bool shouldSell = false;
    
    // Check for buy signals
    if (fastMA > slowMA && rsi < RSIOverSold && IsBuySignal(currentPrice))
    {
        shouldBuy = true;
        Log("Buy signal detected", 3);
    }
    // Check for sell signals
    else if (fastMA < slowMA && rsi > RSIOverBought && IsSellSignal(currentPrice))
    {
        shouldSell = true;
        Log("Sell signal detected", 3);
    }
    
    // Execute trades if conditions are met
    if (shouldBuy || shouldSell)
    {
        double lotSize = CalculatePositionSize();
        
        if (shouldBuy)
        {
            if (m_trade.Buy(lotSize, _Symbol, 0, 0, 0, "Moran Flipper Buy"))
            {
                SetStopLoss();
                SetTakeProfit();
                Log("Buy order executed", 3);
            }
            else
            {
                Log("Failed to execute buy order: " + IntegerToString(GetLastError()), 1);
            }
        }
        else if (shouldSell)
        {
            if (m_trade.Sell(lotSize, _Symbol, 0, 0, 0, "Moran Flipper Sell"))
            {
                SetStopLoss();
                SetTakeProfit();
                Log("Sell order executed", 3);
            }
            else
            {
                Log("Failed to execute sell order: " + IntegerToString(GetLastError()), 1);
            }
        }
    }
    
    // Manage open positions
    ManageOpenPositions();
}


// Calculate position size based on risk percentage
double MoranFlipper::CalculatePositionSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = MathMin(balance, equity) * (RiskPercentage / 100.0);
    
    double stopLoss = 50 * _Point; // Default 50 points stop loss, adjust as needed
    
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    
    double lotSize = riskAmount / (stopLoss * tickValue / tickSize);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    lotSize = MathMax(minLot, MathMin(lotSize, MathMin(maxLot, MaxLotSize)));
    
    return NormalizeDouble(lotSize, 2);
}


// Set stop loss for the current position
void MoranFlipper::SetStopLoss()
{
    if (!m_position.Select(_Symbol)) return;

    double stopLoss = 0;
    double currentStopLoss = m_position.StopLoss();
    double openPrice = m_position.PriceOpen();

    if (m_position.PositionType() == POSITION_TYPE_BUY)
    {
        stopLoss = openPrice - (50 * _Point); // 50 points below entry for buy
    }
    else if (m_position.PositionType() == POSITION_TYPE_SELL)
    {
        stopLoss = openPrice + (50 * _Point); // 50 points above entry for sell
    }

    if (stopLoss != currentStopLoss)
    {
        if (!m_trade.PositionModify(m_position.Ticket(), stopLoss, m_position.TakeProfit()))
        {
            Log("Failed to set stop loss: " + IntegerToString(GetLastError()), 1);
        }
    }
}

// Set take profit for the current position
void MoranFlipper::SetTakeProfit()
{
    if (!m_position.Select(_Symbol)) return;

    double takeProfit = 0;
    double currentTakeProfit = m_position.TakeProfit();
    double openPrice = m_position.PriceOpen();

    if (m_position.PositionType() == POSITION_TYPE_BUY)
    {
        takeProfit = openPrice + (100 * _Point); // 100 points above entry for buy
    }
    else if (m_position.PositionType() == POSITION_TYPE_SELL)
    {
        takeProfit = openPrice - (100 * _Point); // 100 points below entry for sell
    }

    if (takeProfit != currentTakeProfit)
    {
        if (!m_trade.PositionModify(m_position.Ticket(), m_position.StopLoss(), takeProfit))
        {
            Log("Failed to set take profit: " + IntegerToString(GetLastError()), 1);
        }
    }
}


// Check for buy signal
bool MoranFlipper::IsBuySignal(double currentPrice)
{
    // Implement your buy signal logic here
    // This is a basic example and should be expanded based on your strategy
    double fastMA = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    double slowMA = iMA(_Symbol, PERIOD_CURRENT, m_slowMA, 0, MODE_SMA, PRICE_CLOSE);
    double rsi = iRSI(_Symbol, PERIOD_CURRENT, m_rsiPeriod, PRICE_CLOSE);

    bool maSignal = fastMA > slowMA;
    bool rsiSignal = rsi < RSIOverSold;
    bool priceAction = currentPrice > fastMA;

    return maSignal && rsiSignal && priceAction;
}

// Check for sell signal
bool MoranFlipper::IsSellSignal(double currentPrice)
{
    // Implement your sell signal logic here
    // This is a basic example and should be expanded based on your strategy
    double fastMA = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    double slowMA = iMA(_Symbol, PERIOD_CURRENT, m_slowMA, 0, MODE_SMA, PRICE_CLOSE);
    double rsi = iRSI(_Symbol, PERIOD_CURRENT, m_rsiPeriod, PRICE_CLOSE);

    bool maSignal = fastMA < slowMA;
    bool rsiSignal = rsi > RSIOverBought;
    bool priceAction = currentPrice < fastMA;

    return maSignal && rsiSignal && priceAction;
}


// Identify supply and demand zones
void MoranFlipper::SupplyDemandZones()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (bars < 100) return; // Ensure we have enough bars to analyze

    // Clear old zones
    m_zones.Clear();

    for (int i = 1; i < 100; i++) // Check the last 100 bars
    {
        // Check for potential supply zone
        if (IsSwingHigh(i))
        {
            Zone* zone = new Zone;
            zone.price = iHigh(_Symbol, PERIOD_CURRENT, i);
            zone.time = iTime(_Symbol, PERIOD_CURRENT, i);
            zone.isSupply = true;
            m_zones.Add(zone);
        }
        // Check for potential demand zone
        else if (IsSwingLow(i))
        {
            Zone* zone = new Zone;
            zone.price = iLow(_Symbol, PERIOD_CURRENT, i);
            zone.time = iTime(_Symbol, PERIOD_CURRENT, i);
            zone.isSupply = false;
            m_zones.Add(zone);
        }
    }
}

// Helper function to identify swing highs
bool MoranFlipper::IsSwingHigh(int shift)
{
    double high = iHigh(_Symbol, PERIOD_CURRENT, shift);
    return (high > iHigh(_Symbol, PERIOD_CURRENT, shift + 1) &&
            high > iHigh(_Symbol, PERIOD_CURRENT, shift - 1) &&
            high > iHigh(_Symbol, PERIOD_CURRENT, shift + 2) &&
            high > iHigh(_Symbol, PERIOD_CURRENT, shift - 2));
}

// Helper function to identify swing lows
bool MoranFlipper::IsSwingLow(int shift)
{
    double low = iLow(_Symbol, PERIOD_CURRENT, shift);
    return (low < iLow(_Symbol, PERIOD_CURRENT, shift + 1) &&
            low < iLow(_Symbol, PERIOD_CURRENT, shift - 1) &&
            low < iLow(_Symbol, PERIOD_CURRENT, shift + 2) &&
            low < iLow(_Symbol, PERIOD_CURRENT, shift - 2));
}


// Identify chart patterns
void MoranFlipper::ChartPatterns()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (bars < 100) return; // Ensure we have enough bars to analyze

    // Clear old patterns
    m_patterns.Clear();

    for (int i = 20; i < 100; i++) // Check the last 100 bars, starting from bar 20 to have enough room for pattern detection
    {
        // Check for double top
        if (IsDoubleTop(i))
        {
            ChartPattern* pattern = new ChartPattern;
            pattern.type = DOUBLE_TOP;
            pattern.startTime = iTime(_Symbol, PERIOD_CURRENT, i);
            pattern.endTime = iTime(_Symbol, PERIOD_CURRENT, i-10);
            m_patterns.Add(pattern);
        }
        // Check for double bottom
        else if (IsDoubleBottom(i))
        {
            ChartPattern* pattern = new ChartPattern;
            pattern.type = DOUBLE_BOTTOM;
            pattern.startTime = iTime(_Symbol, PERIOD_CURRENT, i);
            pattern.endTime = iTime(_Symbol, PERIOD_CURRENT, i-10);
            m_patterns.Add(pattern);
        }
        // Add more pattern checks here (e.g., head and shoulders, triangles, etc.)
    }
}

// Helper function to identify double tops
bool MoranFlipper::IsDoubleTop(int shift)
{
    double high1 = iHigh(_Symbol, PERIOD_CURRENT, shift);
    double high2 = iHigh(_Symbol, PERIOD_CURRENT, shift - 10);
    
    if (MathAbs(high1 - high2) <= 10 * _Point) // Peaks should be within 10 points of each other
    {
        double lowBetween = iLow(_Symbol, PERIOD_CURRENT, shift - 5);
        if (lowBetween < high1 - 20 * _Point && lowBetween < high2 - 20 * _Point) // Trough should be at least 20 points below peaks
        {
            return true;
        }
    }
    return false;
}

// Helper function to identify double bottoms
bool MoranFlipper::IsDoubleBottom(int shift)
{
    double low1 = iLow(_Symbol, PERIOD_CURRENT, shift);
    double low2 = iLow(_Symbol, PERIOD_CURRENT, shift - 10);
    
    if (MathAbs(low1 - low2) <= 10 * _Point) // Troughs should be within 10 points of each other
    {
        double highBetween = iHigh(_Symbol, PERIOD_CURRENT, shift - 5);
        if (highBetween > low1 + 20 * _Point && highBetween > low2 + 20 * _Point) // Peak should be at least 20 points above troughs
        {
            return true;
        }
    }
    return false;
}


// Updated check for buy signal
bool MoranFlipper::IsBuySignal(double currentPrice)
{
    // Original conditions
    double fastMA = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    double slowMA = iMA(_Symbol, PERIOD_CURRENT, m_slowMA, 0, MODE_SMA, PRICE_CLOSE);
    double rsi = iRSI(_Symbol, PERIOD_CURRENT, m_rsiPeriod, PRICE_CLOSE);

    bool maSignal = fastMA > slowMA;
    bool rsiSignal = rsi < RSIOverSold;
    bool priceAction = currentPrice > fastMA;

    // New conditions
    bool nearDemandZone = false;
    bool bullishPattern = false;

    // Check if price is near a demand zone
    for (int i = 0; i < m_zones.Total(); i++)
    {
        Zone* zone = m_zones.At(i);
        if (!zone.isSupply && MathAbs(currentPrice - zone.price) <= 20 * _Point)
        {
            nearDemandZone = true;
            break;
        }
    }

    // Check for bullish chart patterns
    for (int i = 0; i < m_patterns.Total(); i++)
    {
        ChartPattern* pattern = m_patterns.At(i);
        if (pattern.type == DOUBLE_BOTTOM)
        {
            bullishPattern = true;
            break;
        }
    }

    return maSignal && rsiSignal && priceAction && (nearDemandZone || bullishPattern);
}

// Updated check for sell signal
bool MoranFlipper::IsSellSignal(double currentPrice)
{
    // Original conditions
    double fastMA = iMA(_Symbol, PERIOD_CURRENT, m_fastMA, 0, MODE_SMA, PRICE_CLOSE);
    double slowMA = iMA(_Symbol, PERIOD_CURRENT, m_slowMA, 0, MODE_SMA, PRICE_CLOSE);
    double rsi = iRSI(_Symbol, PERIOD_CURRENT, m_rsiPeriod, PRICE_CLOSE);

    bool maSignal = fastMA < slowMA;
    bool rsiSignal = rsi > RSIOverBought;
    bool priceAction = currentPrice < fastMA;

    // New conditions
    bool nearSupplyZone = false;
    bool bearishPattern = false;

    // Check if price is near a supply zone
    for (int i = 0; i < m_zones.Total(); i++)
    {
        Zone* zone = m_zones.At(i);
        if (zone.isSupply && MathAbs(currentPrice - zone.price) <= 20 * _Point)
        {
            nearSupplyZone = true;
            break;
        }
    }

    // Check for bearish chart patterns
    for (int i = 0; i < m_patterns.Total(); i++)
    {
        ChartPattern* pattern = m_patterns.At(i);
        if (pattern.type == DOUBLE_TOP)
        {
            bearishPattern = true;
            break;
        }
    }

    return maSignal && rsiSignal && priceAction && (nearSupplyZone || bearishPattern);
}


// Manage open positions
void MoranFlipper::ManageOpenPositions()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (m_position.SelectByIndex(i))
        {
            if (m_position.Symbol() == _Symbol)
            {
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double openPrice = m_position.PriceOpen();
                double stopLoss = m_position.StopLoss();
                double takeProfit = m_position.TakeProfit();

                // Move stop loss to breakeven if profit is twice the initial risk
                if (m_position.PositionType() == POSITION_TYPE_BUY)
                {
                    if (currentPrice >= openPrice + 2 * (openPrice - stopLoss) && stopLoss < openPrice)
                    {
                        m_trade.PositionModify(m_position.Ticket(), openPrice, takeProfit);
                        Log("Moved stop loss to breakeven for buy position", 3);
                    }
                }
                else if (m_position.PositionType() == POSITION_TYPE_SELL)
                {
                    if (currentPrice <= openPrice - 2 * (stopLoss - openPrice) && stopLoss > openPrice)
                    {
                        m_trade.PositionModify(m_position.Ticket(), openPrice, takeProfit);
                        Log("Moved stop loss to breakeven for sell position", 3);
                    }
                }

                // Implement trailing stop
                double trailingStop = 100 * _Point; // 100 points trailing stop
                if (m_position.PositionType() == POSITION_TYPE_BUY)
                {
                    if (currentPrice - stopLoss > trailingStop)
                    {
                        double newStopLoss = currentPrice - trailingStop;
                        if (newStopLoss > stopLoss)
                        {
                            m_trade.PositionModify(m_position.Ticket(), newStopLoss, takeProfit);
                            Log("Updated trailing stop for buy position", 3);
                        }
                    }
                }
                else if (m_position.PositionType() == POSITION_TYPE_SELL)
                {
                    if (stopLoss - currentPrice > trailingStop)
                    {
                        double newStopLoss = currentPrice + trailingStop;
                        if (newStopLoss < stopLoss)
                        {
                            m_trade.PositionModify(m_position.Ticket(), newStopLoss, takeProfit);
                            Log("Updated trailing stop for sell position", 3);
                        }
                    }
                }
            }
        }
    }
}


// Test all major functions of the trading bot
bool MoranFlipper::TestFunctions(string specificTest = "")
{
    Log("Starting comprehensive function tests", 3);
    
    bool allTestsPassed = true;
    
    if (specificTest == "" || specificTest == "CalculatePositionSize")
        if (!TestCalculatePositionSize()) allTestsPassed = false;

    if (specificTest == "" || specificTest == "SupplyDemandZones")
        if (!TestSupplyDemandZones()) allTestsPassed = false;

    if (specificTest == "" || specificTest == "ChartPatterns")
        if (!TestChartPatterns()) allTestsPassed = false;

    if (specificTest == "" || specificTest == "Signals")
        if (!TestSignals()) allTestsPassed = false;

    if (specificTest == "" || specificTest == "StopLossAndTakeProfit")
        if (!TestStopLossAndTakeProfit()) allTestsPassed = false;

    if (specificTest == "" || specificTest == "ManageOpenPositions")
        if (!TestManageOpenPositions()) allTestsPassed = false;

    if (specificTest == "" || specificTest == "IsNewBar")
        if (!TestIsNewBar()) allTestsPassed = false;

    if (allTestsPassed)
        Log("All function tests completed successfully", 3);
    else
        Log("Some function tests failed. Please review the log for details.", 1);

    return allTestsPassed;
}

// Helper function to create a mock position for testing
void MoranFlipper::CreateMockPosition(ENUM_POSITION_TYPE type, double openPrice, double stopLoss, double takeProfit)
{
    m_position.Select(_Symbol);
    m_position.PositionType(type);
    m_position.PriceOpen(openPrice);
    m_position.StopLoss(stopLoss);
    m_position.TakeProfit(takeProfit);
}

bool MoranFlipper::TestCalculatePositionSize()
{
    Log("Testing CalculatePositionSize function", 3);
    
    double lotSize = CalculatePositionSize();
    if (lotSize <= 0 || lotSize > MaxLotSize)
    {
        Log("CalculatePositionSize test failed. Returned lot size: " + DoubleToString(lotSize, 2), 1);
        return false;
    }
    Log("CalculatePositionSize test passed. Lot size: " + DoubleToString(lotSize, 2), 3);
    return true;
}

bool MoranFlipper::TestSupplyDemandZones()
{
    Log("Testing SupplyDemandZones function", 3);
    
    SupplyDemandZones();
    if (m_zones.Total() == 0)
    {
        Log("SupplyDemandZones test failed. No zones identified.", 1);
        return false;
    }
    Log("SupplyDemandZones test passed. Zones identified: " + IntegerToString(m_zones.Total()), 3);
    
    // Additional checks
    for (int i = 0; i < m_zones.Total(); i++)
    {
        Zone* zone = m_zones.At(i);
        Log("Zone " + IntegerToString(i) + ": Price = " + DoubleToString(zone.price, _Digits) + 
            ", Time = " + TimeToString(zone.time) + ", IsSupply = " + (zone.isSupply ? "true" : "false"), 3);
    }
    
    return true;
}

bool MoranFlipper::TestChartPatterns()
{
    Log("Testing ChartPatterns function", 3);
    
    ChartPatterns();
    if (m_patterns.Total() == 0)
    {
        Log("ChartPatterns test failed. No patterns identified.", 1);
        return false;
    }
    Log("ChartPatterns test passed. Patterns identified: " + IntegerToString(m_patterns.Total()), 3);
    
    // Additional checks
    for (int i = 0; i < m_patterns.Total(); i++)
    {
        ChartPattern* pattern = m_patterns.At(i);
        Log("Pattern " + IntegerToString(i) + ": Type = " + EnumToString(pattern.type) + 
            ", Start Time = " + TimeToString(pattern.startTime) + ", End Time = " + TimeToString(pattern.endTime), 3);
    }
    
    return true;
}

bool MoranFlipper::TestSignals()
{
    Log("Testing IsBuySignal and IsSellSignal functions", 3);
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    bool buySignal = IsBuySignal(currentPrice);
    bool sellSignal = IsSellSignal(currentPrice);
    
    Log("Current price: " + DoubleToString(currentPrice, _Digits), 3);
    Log("IsBuySignal test result: " + (buySignal ? "Buy signal detected" : "No buy signal"), 3);
    Log("IsSellSignal test result: " + (sellSignal ? "Sell signal detected" : "No sell signal"), 3);
    
    if (buySignal && sellSignal)
    {
        Log("Signal test failed. Both buy and sell signals detected simultaneously.", 1);
        return false;
    }
    
    return true;
}

bool MoranFlipper::TestStopLossAndTakeProfit()
{
    Log("Testing SetStopLoss and SetTakeProfit functions", 3);
    
    if (PositionsTotal() > 0)
    {
        double initialStopLoss = 0, initialTakeProfit = 0;
        if (m_position.SelectByIndex(0))
        {
            initialStopLoss = m_position.StopLoss();
            initialTakeProfit = m_position.TakeProfit();
        }
        
        SetStopLoss();
        SetTakeProfit();
        
        if (m_position.SelectByIndex(0))
        {
            double newStopLoss = m_position.StopLoss();
            double newTakeProfit = m_position.TakeProfit();
            
            Log("Initial Stop Loss: " + DoubleToString(initialStopLoss, _Digits) + ", New Stop Loss: " + DoubleToString(newStopLoss, _Digits), 3);
            Log("Initial Take Profit: " + DoubleToString(initialTakeProfit, _Digits) + ", New Take Profit: " + DoubleToString(newTakeProfit, _Digits), 3);
            
            if (newStopLoss == initialStopLoss && newTakeProfit == initialTakeProfit)
            {
                Log("SetStopLoss and SetTakeProfit test failed. Values were not updated.", 1);
                return false;
            }
        }
        
        Log("SetStopLoss and SetTakeProfit tests completed successfully.", 3);
    }
    else
    {
        Log("SetStopLoss and SetTakeProfit tests skipped. No open positions.", 2);
    }
    
    return true;
}

bool MoranFlipper::TestManageOpenPositions()
{
    Log("Testing ManageOpenPositions function", 3);
    
    if (PositionsTotal() > 0)
    {
        double initialStopLoss = 0;
        if (m_position.SelectByIndex(0))
        {
            initialStopLoss = m_position.StopLoss();
        }
        
        ManageOpenPositions();
        
        if (m_position.SelectByIndex(0))
        {
            double newStopLoss = m_position.StopLoss();
            
            Log("Initial Stop Loss: " + DoubleToString(initialStopLoss, _Digits) + ", New Stop Loss: " + DoubleToString(newStopLoss, _Digits), 3);
            
            if (newStopLoss == initialStopLoss)
            {
                Log("ManageOpenPositions test completed. No changes were made to the position.", 2);
            }
            else
            {
                Log("ManageOpenPositions test completed. Position was modified.", 3);
            }
        }
    }
    else
    {
        Log("ManageOpenPositions test skipped. No open positions.", 2);
    }
    
    return true;
}

bool MoranFlipper::TestIsNewBar()
{
    Log("Testing IsNewBar function", 3);
    
    bool initialResult = IsNewBar();
    Log("Initial IsNewBar result: " + (initialResult ? "New bar" : "Not a new bar"), 3);
    
    // Wait for a short time
    Sleep(100);
    
    bool secondResult = IsNewBar();
    Log("Second IsNewBar result: " + (secondResult ? "New bar" : "Not a new bar"), 3);
    
    if (initialResult == secondResult)
    {
        Log("IsNewBar test passed. Function returns consistent results for the same bar.", 3);
    }
    else
    {
        Log("IsNewBar test failed. Function returns inconsistent results.", 1);
        return false;
    }
    
    return true;
}


// Backtesting function
BacktestResult MoranFlipper::Backtest(datetime startDate, datetime endDate)
{
    BacktestResult result = {0};
    
    Log("Starting backtest from " + TimeToString(startDate) + " to " + TimeToString(endDate), 3);

    // Store the current market position
    double initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double peak = initialBalance;

    // Loop through historical data
    for(datetime current = startDate; current <= endDate; current += PeriodSeconds(PERIOD_CURRENT))
    {
        // Update current bar time
        m_last_bar_time = current;

        // Process the current bar
        Processing();

        // Check for open positions and update performance metrics
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(m_position.SelectByIndex(i))
            {
                if(m_position.Symbol() == _Symbol)
                {
                    double profit = m_position.Profit();
                    result.totalProfit += profit;

                    if(profit > 0)
                    {
                        result.winningTrades++;
                    }

                    result.totalTrades++;

                    // Update peak and drawdown
                    double currentBalance = initialBalance + result.totalProfit;
                    if(currentBalance > peak)
                    {
                        peak = currentBalance;
                    }
                    else
                    {
                        double drawdown = peak - currentBalance;
                        if(drawdown > result.maxDrawdown)
                        {
                            result.maxDrawdown = drawdown;
                        }
                    }

                    // Store profit for this trade
                    ArrayResize(result.profits, result.totalTrades);
                    result.profits[result.totalTrades - 1] = profit;
                }
            }
        }
    }

    // Calculate final metrics
    result.winRate = result.totalTrades > 0 ? (double)result.winningTrades / result.totalTrades * 100 : 0;
    double grossProfit = 0, grossLoss = 0;
    for(int i = 0; i < result.totalTrades; i++)
    {
        if(result.profits[i] > 0)
            grossProfit += result.profits[i];
        else
            grossLoss += MathAbs(result.profits[i]);
    }
    result.profitFactor = grossLoss > 0 ? grossProfit / grossLoss : 0;

    Log("Backtest completed. Results:", 3);
    Log("Total trades: " + IntegerToString(result.totalTrades), 3);
    Log("Winning trades: " + IntegerToString(result.winningTrades), 3);
    Log("Win rate: " + DoubleToString(result.winRate, 2) + "%", 3);
    Log("Total profit: " + DoubleToString(result.totalProfit, 2), 3);
    Log("Max drawdown: " + DoubleToString(result.maxDrawdown, 2), 3);
    Log("Profit factor: " + DoubleToString(result.profitFactor, 2), 3);

    return result;
}

// Run a backtest and visualize the results
void MoranFlipper::RunAndVisualizeBacktest(datetime startDate, datetime endDate)
{
    Log("Running backtest from " + TimeToString(startDate) + " to " + TimeToString(endDate), 3);

    // Run the backtest
    BacktestResult result = Backtest(startDate, endDate);

    // Visualize the results
    VisualizeBacktestResults(result, startDate, endDate);

    Log("Backtest and visualization completed", 3);
}

// Save optimized parameters to a CSV file
void MoranFlipper::SaveOptimizedParameters(string filename)
{
    int fileHandle = FileOpen(filename, FILE_WRITE|FILE_CSV);
    
    if(fileHandle != INVALID_HANDLE)
    {
        FileWrite(fileHandle, "Parameter", "Value");
        FileWrite(fileHandle, "FastMA", FastMA);
        FileWrite(fileHandle, "SlowMA", SlowMA);
        FileWrite(fileHandle, "RSIPeriod", RSIPeriod);
        FileWrite(fileHandle, "RSIOverBought", RSIOverBought);
        FileWrite(fileHandle, "RSIOverSold", RSIOverSold);
        
        FileClose(fileHandle);
        Log("Optimized parameters saved to " + filename, 3);
    }
    else
    {
        Log("Failed to save optimized parameters: " + IntegerToString(GetLastError()), 1);
    }
}

// Load optimized parameters from a CSV file
bool MoranFlipper::LoadOptimizedParameters(string filename)
{
    int fileHandle = FileOpen(filename, FILE_READ|FILE_CSV);
    
    if(fileHandle != INVALID_HANDLE)
    {
        // Skip header
        FileReadString(fileHandle);
        FileReadString(fileHandle);
        
        FastMA = (int)StringToInteger(FileReadString(fileHandle));
        SlowMA = (int)StringToInteger(FileReadString(fileHandle));
        RSIPeriod = (int)StringToInteger(FileReadString(fileHandle));
        RSIOverBought = (int)StringToInteger(FileReadString(fileHandle));
        RSIOverSold = (int)StringToInteger(FileReadString(fileHandle));
        
        FileClose(fileHandle);
        Log("Optimized parameters loaded from " + filename, 3);
        return true;
    }
    else
    {
        Log("Failed to load optimized parameters: " + IntegerToString(GetLastError()), 1);
        return false;
    }
}

// Run the complete trading system
void MoranFlipper::RunTradingSystem()
{
    Log("Starting Moran Flipper v1.0 Trading System", 3);

    // Step 1: Load optimized parameters if available
    if (LoadOptimizedParameters("optimized_params.csv"))
    {
        Log("Loaded optimized parameters", 3);
    }
    else
    {
        Log("No optimized parameters found. Will use default parameters.", 2);
    }

    // Step 2: Optimize parameters (if needed)
    datetime optimizationStartDate = D'2022.01.01';
    datetime optimizationEndDate = D'2022.12.31';
    
    if (MessageBox("Do you want to run optimization?", "Optimization", MB_YESNO) == IDYES)
    {
        Optimize(optimizationStartDate, optimizationEndDate);
    }

    // Step 3: Run backtest with current parameters
    datetime backtestStartDate = D'2023.01.01';
    datetime backtestEndDate = D'2023.06.30';
    
    Log("Running backtest with current parameters", 3);
    RunAndVisualizeBacktest(backtestStartDate, backtestEndDate);

    // Step 4: Start live trading
    if (MessageBox("Do you want to start live trading?", "Live Trading", MB_YESNO) == IDYES)
    {
        Log("Starting live trading", 3);
        while(!IsStopped())
        {
            Processing();
            Sleep(1000); // Wait for 1 second before next iteration
        }
    }

    Log("Moran Flipper v1.0 Trading System finished", 3);
}

// Global variables
MoranFlipper* g_moranFlipper = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Create an instance of MoranFlipper
    g_moranFlipper = new MoranFlipper();
    
    if (g_moranFlipper == NULL)
    {
        Print("Failed to create MoranFlipper instance");
        return INIT_FAILED;
    }
    
    // Initialize the MoranFlipper instance
    if (!g_moranFlipper.Init())
    {
        Print("Failed to initialize MoranFlipper");
        delete g_moranFlipper;
        return INIT_FAILED;
    }
    
    // Run the trading system
    g_moranFlipper.RunTradingSystem();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if (g_moranFlipper != NULL)
    {
        g_moranFlipper.Deinit();
        delete g_moranFlipper;
        g_moranFlipper = NULL;
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if (g_moranFlipper != NULL)
    {
        g_moranFlipper.Processing();
    }
}

// Dynamic Position Sizing
double MoranFlipper::CalculateDynamicPositionSize(double riskPercentage, double stopLossPoints)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (riskPercentage / 100.0);
    
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    
    double riskPerPoint = tickValue / tickSize;
    double positionSize = riskAmount / (stopLossPoints * riskPerPoint);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    positionSize = MathFloor(positionSize / lotStep) * lotStep;
    positionSize = MathMax(minLot, MathMin(positionSize, maxLot));
    
    return NormalizeDouble(positionSize, 2);
}

// Update Processing method to use dynamic position sizing
void MoranFlipper::Processing()
{
    if (!IsNewBar())
        return;
    
    Log("Starting new bar processing", 3);
    
    bool shouldBuy = false;
    bool shouldSell = false;
    
    if (!AdvancedEntryExitStrategy(shouldBuy, shouldSell))
        return;
    
    // Execute trades if conditions are met
    if (shouldBuy || shouldSell)
    {
        double stopLossPoints = 50; // Example: 50 points stop loss
        double riskPercentage = 1.0; // Example: 1% risk per trade
        double lotSize = CalculateDynamicPositionSize(riskPercentage, stopLossPoints);
        
        if (shouldBuy)
        {
            if (m_trade.Buy(lotSize, _Symbol, 0, 0, 0, "Moran Flipper Buy"))
            {
                SetStopLoss();
                SetTakeProfit();
                Log("Buy order executed with lot size: " + DoubleToString(lotSize, 2), 3);
            }
            else
            {
                Log("Failed to execute buy order: " + IntegerToString(GetLastError()), 1);
            }
        }
        else if (shouldSell)
        {
            if (m_trade.Sell(lotSize, _Symbol, 0, 0, 0, "Moran Flipper Sell"))
            {
                SetStopLoss();
                SetTakeProfit();
                Log("Sell order executed with lot size: " + DoubleToString(lotSize, 2), 3);
            }
            else
            {
                Log("Failed to execute sell order: " + IntegerToString(GetLastError()), 1);
            }
        }
    }
    
    // Manage open positions
    ManageOpenPositions();
}

// Genetic Algorithm Optimization
void MoranFlipper::GeneticAlgorithmOptimize(datetime startDate, datetime endDate, int populationSize, int generations)
{
    Log("Starting Genetic Algorithm Optimization", 3);

    // Define parameter ranges
    int fastMAMin = 5, fastMAMax = 50;
    int slowMAMin = 10, slowMAMax = 100;
    int rsiPeriodMin = 7, rsiPeriodMax = 21;
    int rsiOverboughtMin = 60, rsiOverboughtMax = 80;
    int rsiOversoldMin = 20, rsiOversoldMax = 40;

    // Initialize population
    int[][] population = new int[populationSize][5];
    double[] fitness = new double[populationSize];

    for (int i = 0; i < populationSize; i++)
    {
        population[i][0] = MathRand() % (fastMAMax - fastMAMin + 1) + fastMAMin;
        population[i][1] = MathRand() % (slowMAMax - slowMAMin + 1) + slowMAMin;
        population[i][2] = MathRand() % (rsiPeriodMax - rsiPeriodMin + 1) + rsiPeriodMin;
        population[i][3] = MathRand() % (rsiOverboughtMax - rsiOverboughtMin + 1) + rsiOverboughtMin;
        population[i][4] = MathRand() % (rsiOversoldMax - rsiOversoldMin + 1) + rsiOversoldMin;
    }

    // Main loop
    for (int gen = 0; gen < generations; gen++)
    {
        // Evaluate fitness
        for (int i = 0; i < populationSize; i++)
        {
            FastMA = population[i][0];
            SlowMA = population[i][1];
            RSIPeriod = population[i][2];
            RSIOverBought = population[i][3];
            RSIOverSold = population[i][4];

            BacktestResult result = Backtest(startDate, endDate);
            fitness[i] = result.profitFactor;
        }

        // Select best individuals
        int[][] newPopulation = new int[populationSize][5];
        for (int i = 0; i < populationSize; i++)
        {
            int parent1 = TournamentSelection(fitness);
            int parent2 = TournamentSelection(fitness);

            // Crossover
            if (MathRand() / 32767.0 < 0.7) // 70% crossover rate
            {
                for (int j = 0; j < 5; j++)
                {
                    if (MathRand() / 32767.0 < 0.5)
                        newPopulation[i][j] = population[parent1][j];
                    else
                        newPopulation[i][j] = population[parent2][j];
                }
            }
            else
            {
                for (int j = 0; j < 5; j++)
                    newPopulation[i][j] = population[parent1][j];
            }

            // Mutation
            for (int j = 0; j < 5; j++)
            {
                if (MathRand() / 32767.0 < 0.1) // 10% mutation rate
                {
                    switch(j)
                    {
                        case 0: newPopulation[i][j] = MathRand() % (fastMAMax - fastMAMin + 1) + fastMAMin; break;
                        case 1: newPopulation[i][j] = MathRand() % (slowMAMax - slowMAMin + 1) + slowMAMin; break;
                        case 2: newPopulation[i][j] = MathRand() % (rsiPeriodMax - rsiPeriodMin + 1) + rsiPeriodMin; break;
                        case 3: newPopulation[i][j] = MathRand() % (rsiOverboughtMax - rsiOverboughtMin + 1) + rsiOverboughtMin; break;
                        case 4: newPopulation[i][j] = MathRand() % (rsiOversoldMax - rsiOversoldMin + 1) + rsiOversoldMin; break;
                    }
                }
            }
        }

        population = newPopulation;

        Log("Generation " + IntegerToString(gen + 1) + " completed", 3);
    }

    // Find best individual
    int bestIndex = 0;
    for (int i = 1; i < populationSize; i++)
    {
        if (fitness[i] > fitness[bestIndex])
            bestIndex = i;
    }

    // Set best parameters
    FastMA = population[bestIndex][0];
    SlowMA = population[bestIndex][1];
    RSIPeriod = population[bestIndex][2];
    RSIOverBought = population[bestIndex][3];
    RSIOverSold = population[bestIndex][4];

    Log("Genetic Algorithm Optimization completed", 3);
    Log("Best parameters: FastMA=" + IntegerToString(FastMA) + 
        ", SlowMA=" + IntegerToString(SlowMA) + 
        ", RSIPeriod=" + IntegerToString(RSIPeriod) + 
        ", RSIOverBought=" + IntegerToString(RSIOverBought) + 
        ", RSIOverSold=" + IntegerToString(RSIOverSold), 3);
}

// Tournament Selection
int MoranFlipper::TournamentSelection(double& fitness[])
{
    int tournamentSize = 3;
    int best = MathRand() % ArraySize(fitness);
    
    for (int i = 1; i < tournamentSize; i++)
    {
        int contender = MathRand() % ArraySize(fitness);
        if (fitness[contender] > fitness[best])
            best = contender;
    }
    
    return best;
}

// Multi-pair support
class MoranFlipperMultiPair
{
private:
    MoranFlipper* m_flippers[];
    string m_symbols[];

public:
    MoranFlipperMultiPair(string& symbols[])
    {
        ArrayCopy(m_symbols, symbols);
        ArrayResize(m_flippers, ArraySize(symbols));
        
        for (int i = 0; i < ArraySize(symbols); i++)
        {
            m_flippers[i] = new MoranFlipper();
            m_flippers[i].SetSymbol(symbols[i]);
        }
    }

    ~MoranFlipperMultiPair()
    {
        for (int i = 0; i < ArraySize(m_flippers); i++)
        {
            delete m_flippers[i];
        }
    }

    bool Init()
    {
        for (int i = 0; i < ArraySize(m_flippers); i++)
        {
            if (!m_flippers[i].Init())
                return false;
        }
        return true;
    }

    void Deinit()
    {
        for (int i = 0; i < ArraySize(m_flippers); i++)
        {
            m_flippers[i].Deinit();
        }
    }

    void Processing()
    {
        for (int i = 0; i < ArraySize(m_flippers); i++)
        {
            m_flippers[i].Processing();
        }
    }

    void RunTradingSystem()
    {
        for (int i = 0; i < ArraySize(m_flippers); i++)
        {
            m_flippers[i].RunTradingSystem();
        }
    }
};

// Update MoranFlipper class to support different symbols
void MoranFlipper::SetSymbol(string symbol)
{
    _Symbol = symbol;
}

// User Interface for Moran Flipper
class MoranFlipperUI
{
private:
    MoranFlipper* m_flipper;
    long m_chart_id;
    int m_sub_window;
    
    string m_button_optimize;
    string m_button_start_trading;
    string m_button_stop_trading;
    
    string m_edit_fast_ma;
    string m_edit_slow_ma;
    string m_edit_rsi_period;
    string m_edit_rsi_overbought;
    string m_edit_rsi_oversold;
    
    string m_label_profit;
    string m_label_drawdown;
    string m_label_trades;
    
public:
    MoranFlipperUI(MoranFlipper* flipper) : m_flipper(flipper)
    {
        m_chart_id = ChartID();
        m_sub_window = 0;
        
        m_button_optimize = "MF_ButtonOptimize";
        m_button_start_trading = "MF_ButtonStartTrading";
        m_button_stop_trading = "MF_ButtonStopTrading";
        
        m_edit_fast_ma = "MF_EditFastMA";
        m_edit_slow_ma = "MF_EditSlowMA";
        m_edit_rsi_period = "MF_EditRSIPeriod";
        m_edit_rsi_overbought = "MF_EditRSIOverbought";
        m_edit_rsi_oversold = "MF_EditRSIOversold";
        
        m_label_profit = "MF_LabelProfit";
        m_label_drawdown = "MF_LabelDrawdown";
        m_label_trades = "MF_LabelTrades";
    }
    
    void Create()
    {
        // Create buttons
        ButtonCreate(m_chart_id, m_button_optimize, m_sub_window, 10, 10, 100, 30, CORNER_LEFT_UPPER, "Optimize", "Arial", 10, clrBlack, clrLightGray, clrWhite, false, false, false, true, 0);
        ButtonCreate(m_chart_id, m_button_start_trading, m_sub_window, 120, 10, 100, 30, CORNER_LEFT_UPPER, "Start Trading", "Arial", 10, clrBlack, clrLightGray, clrWhite, false, false, false, true, 0);
        ButtonCreate(m_chart_id, m_button_stop_trading, m_sub_window, 230, 10, 100, 30, CORNER_LEFT_UPPER, "Stop Trading", "Arial", 10, clrBlack, clrLightGray, clrWhite, false, false, false, true, 0);
        
        // Create edit boxes for parameters
        EditCreate(m_chart_id, m_edit_fast_ma, m_sub_window, 10, 50, 100, 20, "Fast MA:", "Arial", 10, ALIGN_LEFT, false, CORNER_LEFT_UPPER, clrBlack, clrWhite, clrBlack, false, false, false, 0);
        EditCreate(m_chart_id, m_edit_slow_ma, m_sub_window, 10, 80, 100, 20, "Slow MA:", "Arial", 10, ALIGN_LEFT, false, CORNER_LEFT_UPPER, clrBlack, clrWhite, clrBlack, false, false, false, 0);
        EditCreate(m_chart_id, m_edit_rsi_period, m_sub_window, 10, 110, 100, 20, "RSI Period:", "Arial", 10, ALIGN_LEFT, false, CORNER_LEFT_UPPER, clrBlack, clrWhite, clrBlack, false, false, false, 0);
        EditCreate(m_chart_id, m_edit_rsi_overbought, m_sub_window, 10, 140, 100, 20, "RSI Overbought:", "Arial", 10, ALIGN_LEFT, false, CORNER_LEFT_UPPER, clrBlack, clrWhite, clrBlack, false, false, false, 0);
        EditCreate(m_chart_id, m_edit_rsi_oversold, m_sub_window, 10, 170, 100, 20, "RSI Oversold:", "Arial", 10, ALIGN_LEFT, false, CORNER_LEFT_UPPER, clrBlack, clrWhite, clrBlack, false, false, false, 0);
        
        // Create labels for performance metrics
        LabelCreate(m_chart_id, m_label_profit, m_sub_window, 10, 200, CORNER_LEFT_UPPER, "Profit: $0.00", "Arial", 10, clrBlack, 0, ANCHOR_LEFT_UPPER, false, false, false, 0);
        LabelCreate(m_chart_id, m_label_drawdown, m_sub_window, 10, 230, CORNER_LEFT_UPPER, "Drawdown: $0.00", "Arial", 10, clrBlack, 0, ANCHOR_LEFT_UPPER, false, false, false, 0);
        LabelCreate(m_chart_id, m_label_trades, m_sub_window, 10, 260, CORNER_LEFT_UPPER, "Trades: 0", "Arial", 10, clrBlack, 0, ANCHOR_LEFT_UPPER, false, false, false, 0);
    }
    
    void Destroy()
    {
        ObjectDelete(m_chart_id, m_button_optimize);
        ObjectDelete(m_chart_id, m_button_start_trading);
        ObjectDelete(m_chart_id, m_button_stop_trading);
        
        ObjectDelete(m_chart_id, m_edit_fast_ma);
        ObjectDelete(m_chart_id, m_edit_slow_ma);
        ObjectDelete(m_chart_id, m_edit_rsi_period);
        ObjectDelete(m_chart_id, m_edit_rsi_overbought);
        ObjectDelete(m_chart_id, m_edit_rsi_oversold);
        
        ObjectDelete(m_chart_id, m_label_profit);
        ObjectDelete(m_chart_id, m_label_drawdown);
        ObjectDelete(m_chart_id, m_label_trades);
    }
    
    void UpdateParameters()
    {
        m_flipper.FastMA = (int)StringToInteger(ObjectGetString(m_chart_id, m_edit_fast_ma, OBJPROP_TEXT));
        m_flipper.SlowMA = (int)StringToInteger(ObjectGetString(m_chart_id, m_edit_slow_ma, OBJPROP_TEXT));
        m_flipper.RSIPeriod = (int)StringToInteger(ObjectGetString(m_chart_id, m_edit_rsi_period, OBJPROP_TEXT));
        m_flipper.RSIOverBought = (int)StringToInteger(ObjectGetString(m_chart_id, m_edit_rsi_overbought, OBJPROP_TEXT));
        m_flipper.RSIOverSold = (int)StringToInteger(ObjectGetString(m_chart_id, m_edit_rsi_oversold, OBJPROP_TEXT));
    }
    
    void UpdatePerformanceMetrics()
    {
        double profit = AccountInfoDouble(ACCOUNT_PROFIT);
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        int trades = HistoryDealsTotal();
        
        ObjectSetString(m_chart_id, m_label_profit, OBJPROP_TEXT, "Profit: $" + DoubleToString(profit, 2));
        ObjectSetString(m_chart_id, m_label_drawdown, OBJPROP_TEXT, "Drawdown: $" + DoubleToString(balance - equity, 2));
        ObjectSetString(m_chart_id, m_label_trades, OBJPROP_TEXT, "Trades: " + IntegerToString(trades));
    }
    
    bool OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
    {
        if(id == CHARTEVENT_OBJECT_CLICK)
        {
            if(sparam == m_button_optimize)
            {
                m_flipper.GeneticAlgorithmOptimize(D'2022.01.01', D'2023.06.30', 50, 20);
                return true;
            }
            if(sparam == m_button_start_trading)
            {
                UpdateParameters();
                m_flipper.StartTrading();
                return true;
            }
            if(sparam == m_button_stop_trading)
            {
                m_flipper.StopTrading();
                return true;
            }
        }
        return false;
    }
};

// Add UI-related methods to MoranFlipper class
class MoranFlipper
{
    // ... (existing code) ...

public:
    void StartTrading()
    {
        // Implement trading start logic
    }

    void StopTrading()
    {
        // Implement trading stop logic
    }
};

// Update OnInit, OnDeinit, and OnTick functions
MoranFlipper* g_moranFlipper = NULL;
MoranFlipperUI* g_moranFlipperUI = NULL;

int OnInit()
{
    g_moranFlipper = new MoranFlipper();
    if(!g_moranFlipper.Init())
    {
        return INIT_FAILED;
    }
    
    g_moranFlipperUI = new MoranFlipperUI(g_moranFlipper);
    g_moranFlipperUI.Create();
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    if(g_moranFlipperUI != NULL)
    {
        g_moranFlipperUI.Destroy();
        delete g_moranFlipperUI;
        g_moranFlipperUI = NULL;
    }
    
    if(g_moranFlipper != NULL)
    {
        g_moranFlipper.Deinit();
        delete g_moranFlipper;
        g_moranFlipper = NULL;
    }
}

void OnTick()
{
    if(g_moranFlipper != NULL)
    {
        g_moranFlipper.Processing();
    }
    
    if(g_moranFlipperUI != NULL)
    {
        g_moranFlipperUI.UpdatePerformanceMetrics();
    }
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(g_moranFlipperUI != NULL)
    {
        g_moranFlipperUI.OnChartEvent(id, lparam, dparam, sparam);
    }
}

// Add this near the top of the file, after the #include statements
#include <JAson.mqh>

// Add this to the MoranFlipper class
class MoranFlipper
{
private:
    // ... (existing private members)
    
    void LoadConfig()
    {
        CJAVal config;
        if(config.Deserialize(ReadFile("config.json")))
        {
            FastMA = (int)config["FastMA"].ToInt();
            SlowMA = (int)config["SlowMA"].ToInt();
            RSIPeriod = (int)config["RSIPeriod"].ToInt();
            RSIOverBought = (int)config["RSIOverBought"].ToInt();
            RSIOverSold = (int)config["RSIOverSold"].ToInt();
            RiskPercentage = config["RiskPercentage"].ToDbl();
            MaxLotSize = config["MaxLotSize"].ToDbl();
        }
        else
        {
            Print("Failed to load configuration file. Using default values.");
        }
    }
    
    string ReadFile(string filename)
    {
        int filehandle = FileOpen(filename, FILE_READ|FILE_TXT);
        if(filehandle == INVALID_HANDLE)
        {
            Print("Failed to open file: ", filename);
            return "";
        }
        
        string content = "";
        while(!FileIsEnding(filehandle))
        {
            content += FileReadString(filehandle);
        }
        
        FileClose(filehandle);
        return content;
    }

public:
    // ... (existing public members)
    
    bool Init()
    {
        LoadConfig();
        // ... (rest of the Init function)
    }
};

// Update the OnInit function
int OnInit()
{
    // ... (existing code)
    
    if(!g_moranFlipper.Init())
    {
        return INIT_FAILED;
    }
    
    // ... (rest of the OnInit function)
}

// Add this near the top of the file
#include <Files\FileTxt.mqh>

// Add this to the MoranFlipper class
class MoranFlipper
{
private:
    CFileTxt m_logFile;
    
    void Log(string message, int level = 0)
    {
        string levelText;
        switch(level)
        {
            case 1: levelText = "WARNING: "; break;
            case 2: levelText = "ERROR: "; break;
            default: levelText = "INFO: "; break;
        }
        
        string logMessage = TimeToString(TimeCurrent()) + " " + levelText + message;
        Print(logMessage);
        
        if(m_logFile.Open("MoranFlipper.log", FILE_WRITE|FILE_READ|FILE_TXT))
        {
            m_logFile.Seek(0, SEEK_END);
            m_logFile.WriteLine(logMessage);
            m_logFile.Close();
        }
    }

public:
    bool Init()
    {
        if(!LoadConfig())
        {
            Log("Failed to load configuration. Using default values.", 1);
        }
        
        // ... (rest of the Init function)
        
        return true;
    }
    
    void Deinit()
    {
        // ... (existing Deinit code)
        
        Log("MoranFlipper deinitialized");
    }
    
    void Processing()
    {
        if(!IsNewBar())
            return;
        
        Log("Processing new bar");
        
        try
        {
            // ... (existing Processing code)
        }
        catch(const exception& e)
        {
            Log("Error in Processing: " + e.what(), 2);
        }
    }
};

// Add these comments throughout the MoranFlipper_v1.0.mq5 file

// MoranFlipper class
class MoranFlipper
{
    // ... (existing code)

    // Advanced Entry and Exit Strategy
    bool AdvancedEntryExitStrategy(bool& shouldBuy, bool& shouldSell)
    {
        // This function implements a sophisticated entry and exit strategy
        // It uses multiple technical indicators to generate buy and sell signals
        // The strategy considers:
        // 1. Moving Average crossovers
        // 2. RSI (Relative Strength Index) levels
        // 3. MACD (Moving Average Convergence Divergence) crossovers
        // 4. Bollinger Bands
        // ... (existing code)
    }

    // Dynamic Position Sizing
    double CalculateDynamicPositionSize(double riskPercentage, double stopLossPoints)
    {
        // This function calculates the position size based on:
        // 1. Account balance
        // 2. Risk percentage per trade
        // 3. Stop loss in points
        // It ensures that the position size doesn't exceed the maximum allowed lot size
        // ... (existing code)
    }

    // Genetic Algorithm Optimization
    void GeneticAlgorithmOptimize(datetime startDate, datetime endDate, int populationSize, int generations)
    {
        // This function implements a genetic algorithm to optimize strategy parameters
        // The algorithm works as follows:
        // 1. Generate an initial population of random parameter sets
        // 2. Evaluate the fitness of each parameter set using backtesting
        // 3. Select the best performing parameter sets
        // 4. Create a new generation through crossover and mutation
        // 5. Repeat steps 2-4 for the specified number of generations
        // ... (existing code)
    }

    // Backtesting
    BacktestResult Backtest(datetime startDate, datetime endDate)
    {
        // This function performs a backtest of the trading strategy
        // It simulates trading over historical data and records:
        // 1. All trades (entry and exit points)
        // 2. Profit/loss for each trade
        // 3. Overall performance metrics
        // The results are used for strategy optimization and performance evaluation
        // ... (existing code)
    }

    // Generate Backtest Report
    void GenerateBacktestReport(datetime startDate, datetime endDate)
    {
        // This function generates a detailed report of the backtest results
        // The report includes:
        // 1. Trade history (entry/exit times, prices, profit/loss)
        // 2. Performance metrics (total profit, win rate, max drawdown, etc.)
        // 3. Summary statistics
        // The report is saved as a text file for further analysis
        // ... (existing code)
    }

    // User Interface
    void CreateUI()
    {
        // This function creates a user interface for the trading bot
        // It includes:
        // 1. Buttons for starting/stopping trading and optimization
        // 2. Input fields for adjusting strategy parameters
        // 3. Display of current performance metrics
        // The UI allows for easy interaction with the bot during live trading
        // ... (existing code)
    }
};

// Main program entry points

// Initialization function
int OnInit()
{
    // This function is called when the Expert Advisor is first loaded
    // It initializes the MoranFlipper instance and sets up the user interface
    // ... (existing code)
}

// Deinitialization function
void OnDeinit(const int reason)
{
    // This function is called when the Expert Advisor is being removed
    // It ensures proper cleanup of resources and logging of the termination
    // ... (existing code)
}

// Main trading logic function
void OnTick()
{
    // This function is called on each tick of the selected symbol
    // It triggers the main processing logic of the MoranFlipper bot
    // ... (existing code)
}

// Chart event handling function
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // This function handles user interactions with the bot's UI elements
    // It responds to button clicks and updates UI displays
    // ... (existing code)
}
