# MoranFlipper v1.5

## Overview

MoranFlipper v1.5 is an Expert Advisor (EA) designed for automated trading in the Forex market. It utilizes various technical indicators and advanced strategies, including Smart Money Concepts (SMC) and Machine Learning techniques, to analyze market conditions and execute trades on multiple currency pairs.

## Features

- **Risk Management**: Configurable risk percentage per trade.
- **Technical Indicators**: Integrates ATR, RSI, Stochastic, and custom SMC strategies.
- **Multi-Timeframe Analysis**: Analyzes trends across different timeframes (H4, H1, M15).
- **Machine Learning**: Implements Long Short-Term Memory (LSTM) for predicting market movements.
- **Sentiment Analysis**: Incorporates news sentiment analysis to avoid trading during high-impact news events.
- **Adaptive Optimization**: Performs periodic optimization of trading parameters based on historical data.

## Input Parameters

- `RiskPercent`: Risk per trade as a percentage of account balance (default: 1.0).
- `ATRPeriod`: Period for Average True Range calculation (default: 14).
- `SMC_OB_Lookback`: Lookback period for identifying Order Blocks (default: 10).
- `SMC_FVG_Lookback`: Lookback period for identifying Fair Value Gaps (default: 5).
- `TimeframeHigh`: Higher timeframe for trend analysis (default: H4).
- `TimeframeMid`: Middle timeframe for trend analysis (default: H1).
- `TimeframeLow`: Lower timeframe for trend analysis (default: M15).
- `LSTMSequenceLength`: Sequence length for LSTM input (default: 60).
- `LSTMPredictionHorizon`: Number of future bars to predict (default: 5).
- `TradingPairs`: List of trading pairs (default: `{"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD"}`).
- `RSIPeriod`: Period for RSI calculation (default: 14).
- `StochasticKPeriod`: K period for Stochastic (default: 14).
- `StochasticDPeriod`: D period for Stochastic (default: 3).
- `StochasticSlowing`: Slowing for Stochastic (default: 3).
- `OptimizationPeriod`: Number of bars for optimization (default: 1000).
- `ValidationPeriod`: Number of bars for validation after optimization (default: 500).

## Installation

1. Download the `MoranFlipper_v1.5.mq5` file.
2. Place the file in the `Experts` directory of your MetaTrader 5 installation.
3. Restart MetaTrader 5.
4. Attach the EA to a chart of your desired trading pair.

## Acknowledgements

This project was developed by **Bryson N. Omullo**, a seasoned Forex trader since 2020 and a full-stack software engineer. Work on this project began in December 2022 and was completed in December 2023. For more information, visit [GitHub](https://github.com/nyaliti).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

For support or inquiries, please contact Bryson N. Omullo via [GitHub](https://github.com/nyaliti)