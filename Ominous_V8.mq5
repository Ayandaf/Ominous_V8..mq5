//+------------------------------------------------------------------+
//|                                     Ominous_V8.mq5               |
//|                          O'Neil Aggressive V3                    |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>

input int      InpPeriod      = 50;     // Faster Trend (50 SMA)
input double   InpVolSurge    = 1.0;    // Standard volume (no extra surge)
input double   InpStopLoss    = 2.0;    // Tighter SL for small balance
input double   InpTakeProfit  = 6.0;    // 3-to-1 Reward
input double   InpLotSize     = 0.01;   // Minimum possible lot

CTrade         trade;
int            handleSMA;

int OnInit() {
   handleSMA = iMA(_Symbol, _Period, InpPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(handleSMA == INVALID_HANDLE) {
      Print("Failed to create SMA handle");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

void OnTick() {
   // Don't trade if position already exists
   if(PositionSelect(_Symbol)) return;

   double smaValue[], highValue[], lowValue[];
   ArraySetAsSeries(smaValue, true);
   ArraySetAsSeries(highValue, true);
   ArraySetAsSeries(lowValue, true);

   // Copy data from indicators
   if(CopyBuffer(handleSMA, 0, 0, 1, smaValue) < 1) return;
   if(CopyHigh(_Symbol, _Period, 0, 2, highValue) < 2) return;
   if(CopyLow(_Symbol, _Period, 0, 2, lowValue) < 2) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentPrice = ask;

   // BUY LOGIC (O'Neil Style) - Price above SMA and above previous high
   if(ask > smaValue[0] && ask > highValue[1]) {
      double slBuy = ask - (ask * (InpStopLoss / 100));
      double tpBuy = ask + (ask * (InpTakeProfit / 100));
      trade.Buy(InpLotSize, _Symbol, ask, slBuy, tpBuy);
   }
   
   // SELL LOGIC - Price below SMA and below previous low
   if(bid < smaValue[0] && bid < lowValue[1]) {
      double slSell = bid + (bid * (InpStopLoss / 100));
      double tpSell = bid - (bid * (InpTakeProfit / 100));
      trade.Sell(InpLotSize, _Symbol, bid, slSell, tpSell);
   }
}

void OnDeinit(const int reason) {
   if(handleSMA != INVALID_HANDLE) {
      IndicatorRelease(handleSMA);
   }
}
