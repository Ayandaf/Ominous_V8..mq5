//+------------------------------------------------------------------+
//|                                     Ominous_V8.mq5               |
//|                    O'Neil Aggressive V3 - Improved               |
//|                          High Probability Entries                |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>

// ========== INPUT PARAMETERS ==========
input int      InpPeriod          = 20;      // SMA Period (faster trend)
input int      InpConfirmation    = 2;       // Candles to confirm trend
input double   InpVolSurge        = 1.0;     // Standard volume (no extra surge)
input double   InpStopLoss        = 1.0;     // Stop Loss %
input double   InpTakeProfit      = 3.0;     // Take Profit %
input double   InpLotSize         = 0.01;    // Lot Size
input int      InpMaxPositions    = 3;       // Maximum concurrent positions
input bool     InpUseTrailingStop = true;    // Use trailing stop loss
input double   InpTrailAmount     = 0.5;     // Trailing stop %

// ========== GLOBAL VARIABLES ==========
CTrade         trade;
int            handleSMA;
int            positionCount = 0;

int OnInit() {
   handleSMA = iMA(_Symbol, _Period, InpPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(handleSMA == INVALID_HANDLE) {
      Print("Failed to create SMA handle");
      return(INIT_FAILED);
   }
   
   trade.SetExpertMagicNumber(123456);
   Print("EA Initialized successfully. SMA Period: ", InpPeriod);
   
   return(INIT_SUCCEEDED);
}

void OnTick() {
   // Count existing positions
   positionCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionSelect(i) && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         positionCount++;
      }
   }
   
   // Apply trailing stop if enabled
   if(InpUseTrailingStop) {
      UpdateTrailingStops();
   }

   // Don't open new trades if max positions reached
   if(positionCount >= InpMaxPositions) return;

   double smaValue[], closeValue[];
   ArraySetAsSeries(smaValue, true);
   ArraySetAsSeries(closeValue, true);

   // Copy SMA data (need more bars for confirmation)
   if(CopyBuffer(handleSMA, 0, 0, InpConfirmation + 1, smaValue) < InpConfirmation + 1) return;
   if(CopyClose(_Symbol, _Period, 0, InpConfirmation + 1, closeValue) < InpConfirmation + 1) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // ========== BUY LOGIC ==========
   // Confirm: Current candle ABOVE SMA and previous candle ABOVE SMA
   if(closeValue[0] > smaValue[0] && closeValue[1] > smaValue[1] && ask > smaValue[0]) {
      // Additional filter: Price breaking above previous high
      double highValue[];
      ArraySetAsSeries(highValue, true);
      if(CopyHigh(_Symbol, _Period, 0, 3, highValue) >= 3) {
         if(ask > highValue[1]) {
            double slBuy = ask - (ask * (InpStopLoss / 100));
            double tpBuy = ask + (ask * (InpTakeProfit / 100));
            
            if(trade.Buy(InpLotSize, _Symbol, ask, slBuy, tpBuy)) {
               Print("BUY Order placed at ", ask, " | SL: ", slBuy, " | TP: ", tpBuy);
            } else {
               Print("BUY Order failed: ", trade.ResultRetcodeDescription());
            }
         }
      }
   }
   
   // ========== SELL LOGIC ==========
   // Confirm: Current candle BELOW SMA and previous candle BELOW SMA
   if(closeValue[0] < smaValue[0] && closeValue[1] < smaValue[1] && bid < smaValue[0]) {
      // Additional filter: Price breaking below previous low
      double lowValue[];
      ArraySetAsSeries(lowValue, true);
      if(CopyLow(_Symbol, _Period, 0, 3, lowValue) >= 3) {
         if(bid < lowValue[1]) {
            double slSell = bid + (bid * (InpStopLoss / 100));
            double tpSell = bid - (bid * (InpTakeProfit / 100));
            
            if(trade.Sell(InpLotSize, _Symbol, bid, slSell, tpSell)) {
               Print("SELL Order placed at ", bid, " | SL: ", slSell, " | TP: ", tpSell);
            } else {
               Print("SELL Order failed: ", trade.ResultRetcodeDescription());
            }
         }
      }
   }
}

void UpdateTrailingStops() {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionSelect(i) && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double posSL = PositionGetDouble(POSITION_SL);
         double posTP = PositionGetDouble(POSITION_TP);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         if(posType == POSITION_TYPE_BUY) {
            // For BUY: Move SL up if price moved up
            double newSL = ask - (ask * (InpTrailAmount / 100));
            if(newSL > posSL) {
               trade.PositionModify(PositionGetTicket(i), newSL, posTP);
            }
         }
         else if(posType == POSITION_TYPE_SELL) {
            // For SELL: Move SL down if price moved down
            double newSL = bid + (bid * (InpTrailAmount / 100));
            if(newSL < posSL && newSL > 0) {
               trade.PositionModify(PositionGetTicket(i), newSL, posTP);
            }
         }
      }
   }
}

void OnDeinit(const int reason) {
   if(handleSMA != INVALID_HANDLE) {
      IndicatorRelease(handleSMA);
   }
   Print("EA Deinitialized. Reason: ", reason);
}
