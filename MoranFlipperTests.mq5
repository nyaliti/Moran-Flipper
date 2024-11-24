
//+------------------------------------------------------------------+
//|                                           MoranFlipperTests.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Expert\Expert.mqh>
#include "MoranFlipper_v1.0.mq5"

// Declare test functions
void TestCalculatePositionSize();
void TestBacktest();
void TestWalkForwardAnalysis();

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    // Run all tests
    TestCalculatePositionSize();
    TestBacktest();
    TestWalkForwardAnalysis();
    
    Print("All tests completed.");
}

//+------------------------------------------------------------------+
//| Test CalculatePositionSize function                              |
//+------------------------------------------------------------------+
void TestCalculatePositionSize()
{
    Print("Testing CalculatePositionSize...");
    
    MoranFlipper flipper;
    
    // Test case 1: Normal conditions
    double lotSize = flipper.CalculatePositionSize();
    if(lotSize > 0 && lotSize <= flipper.MaxLotSize)
        Print("Test case 1 passed.");
    else
        Print("Test case 1 failed. Unexpected lot size: ", lotSize);
    
    // Test case 2: Low balance (simulated)
    flipper.SetTestBalance(100); // Set a low balance for testing
    lotSize = flipper.CalculatePositionSize();
    if(lotSize > 0 && lotSize < 0.1) // Expecting a small lot size
        Print("Test case 2 passed.");
    else
        Print("Test case 2 failed. Unexpected lot size: ", lotSize);
    
    // Test case 3: High balance (simulated)
    flipper.SetTestBalance(100000); // Set a high balance for testing
    lotSize = flipper.CalculatePositionSize();
    if(lotSize > 0 && lotSize <= flipper.MaxLotSize) // Should not exceed MaxLotSize
        Print("Test case 3 passed.");
    else
        Print("Test case 3 failed. Unexpected lot size: ", lotSize);
    
    flipper.ResetTestBalance(); // Reset the test balance
}

//+------------------------------------------------------------------+
//| Test Backtest function                                           |
//+------------------------------------------------------------------+
void TestBacktest()
{
    Print("Testing Backtest...");
    
    MoranFlipper flipper;
    
    datetime startDate = D'2023.01.01';
    datetime endDate = D'2023.06.01';
    
    BacktestResult result = flipper.Backtest(startDate, endDate);
    
    if(result.totalTrades > 0 && result.totalProfit != 0)
    {
        Print("Backtest test passed.");
        Print("Total trades: ", result.totalTrades);
        Print("Total profit: ", result.totalProfit);
        Print("Win rate: ", result.winRate, "%");
        Print("Max drawdown: ", result.maxDrawdown);
    }
    else
        Print("Backtest test failed. Unexpected results: Trades=", result.totalTrades, ", Profit=", result.totalProfit);
}

//+------------------------------------------------------------------+
//| Test WalkForwardAnalysis function                                |
//+------------------------------------------------------------------+
void TestWalkForwardAnalysis()
{
    Print("Testing WalkForwardAnalysis...");
    
    MoranFlipper flipper;
    
    datetime startDate = D'2023.01.01';
    datetime endDate = D'2023.06.01';
    int numSegments = 3;
    
    // Store initial parameters
    int initialFastMA = flipper.GetFastMA();
    int initialSlowMA = flipper.GetSlowMA();
    int initialRSIPeriod = flipper.GetRSIPeriod();
    
    flipper.WalkForwardAnalysis(startDate, endDate, numSegments);
    
    // Check if the optimization parameters have changed
    if(flipper.GetFastMA() != initialFastMA || 
       flipper.GetSlowMA() != initialSlowMA || 
       flipper.GetRSIPeriod() != initialRSIPeriod)
    {
        Print("WalkForwardAnalysis test passed. Parameters were optimized.");
        Print("New FastMA: ", flipper.GetFastMA());
        Print("New SlowMA: ", flipper.GetSlowMA());
        Print("New RSIPeriod: ", flipper.GetRSIPeriod());
    }
    else
    {
        Print("WalkForwardAnalysis test failed. Parameters were not changed.");
    }
    
    Print("WalkForwardAnalysis test completed. Check logs for detailed results.");
}
