//+------------------------------------------------------------------+
//|                                     Ominous_V8.mq5               |
//|                    O'Neil Aggressive V3 - FIXED                  |
//|                     Controlled Entry Strategy                     |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>

// ========== INPUT PARAMETERS ==========
input int      InpPeriod          = 20;      // SMA Period
input double   InpStopLoss        = 1.5;     // Stop Loss %
input double   InpTakeProfit      = 4.0;     // Take Profit %
input double   InpLotSize         = 0.01;    // Lot Size
input int      InpMaxPositions    = 2;       // Max positions per symbol
input bool     InpUseTrailingStop = true;    // Use trailing stop
input double   InpTrailAmount     = 0.5;     // Trailing stop %

// ========== GLOBAL VARIABLES ==========
CTrade         trade;
int            handleSMA;
int            lastBarTime = 0;              // Prevent multiple trades per bar
int            magicNumber = 123456;

int OnInit() {
   handleSMA = iMA(_Symbol, _Period, InpPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(handleSMA == INVALID_HANDLE) {
      Print("Failed to create SMA handle");
      return(INIT_FAILED);
   }
   
   trade.SetExpertMagicNumber(magicNumber);
   Print("EA Initialized - Period: ", InpPeriod, " | SL: ", InpStopLoss, "% | TP: ", InpTakeProfit, "%");
   
   return(INIT_SUCCEEDED);
}

void OnTick() {
   // CRITICAL: Only process once per bar
   if(lastBarTime == iTime(_Symbol, _Period, 0)) return;
   lastBarTime = iTime(_Symbol, _Period, 0);
   
   // Apply trailing stop if enabled
   if(InpUseTrailingStop) {
      UpdateTrailingStops();
   }

   // Count existing positions
   int positionCount = CountPositions();
   
   // Don't open new trades if max positions reached
   if(positionCount >= InpMaxPositions) return;

   // Get data
   double smaValue[];
   double closeValue[];
   double highValue[];
   double lowValue[];
   
   ArraySetAsSeries(smaValue, true);
   ArraySetAsSeries(closeValue, true);
   ArraySetAsSeries(highValue, true);
   ArraySetAsSeries(lowValue, true);

   // Copy indicator data (3 bars: current + 2 previous)
   if(CopyBuffer(handleSMA, 0, 0, 3, smaValue) < 3) return;
   if(CopyClose(_Symbol, _Period, 0, 3, closeValue) < 3) return;
   if(CopyHigh(_Symbol, _Period, 0, 3, highValue) < 3) return;
   if(CopyLow(_Symbol, _Period, 0, 3, lowValue) < 3) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;

   // ========== BUY LOGIC ==========
   // Entry conditions:
   // 1. Current close > SMA
   // 2. Previous close > SMA
   // 3. Price breaking above previous high
   // 4. Spread is reasonable
   
   if(closeValue[0] > smaValue[0] && closeValue[1] > smaValue[1]) {
      if(highValue[1] > 0 && ask > highValue[1] && spread < (ask * 0.001)) {
         
         double slBuy = ask - (ask * (InpStopLoss / 100.0));
         double tpBuy = ask + (ask * (InpTakeProfit / 100.0));
         
         // Safety check
         if(tpBuy > slBuy && slBuy > 0) {
            if(trade.Buy(InpLotSize, _Symbol, ask, slBuy, tpBuy)) {
               Print("BUY - Entry: ", ask, " | SL: ", slBuy, " | TP: ", tpBuy);
            } else {
               Print("BUY FAILED: ", trade.ResultRetcodeDescription());
            }
            return; // Exit to prevent multiple trades per bar
         }
      }
   }
   
   // ========== SELL LOGIC ==========
   // Entry conditions:
   // 1. Current close < SMA
   // 2. Previous close < SMA
   // 3. Price breaking below previous low
   // 4. Spread is reasonable
   
   if(closeValue[0] < smaValue[0] && closeValue[1] < smaValue[1]) {
      if(lowValue[1] > 0 && bid < lowValue[1] && spread < (bid * 0.001)) {
         
         double slSell = bid + (bid * (InpStopLoss / 100.0));
         double tpSell = bid - (bid * (InpTakeProfit / 100.0));
         
         // Safety check
         if(tpSell > 0 && slSell > tpSell) {
            if(trade.Sell(InpLotSize, _Symbol, bid, slSell, tpSell)) {
               Print("SELL - Entry: ", bid, " | SL: ", slSell, " | TP: ", tpSell);
            } else {
               Print("SELL FAILED: ", trade.ResultRetcodeDescription());
            }
            return; // Exit to prevent multiple trades per bar
         }
      }
   }
}

int CountPositions() {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionSelect(i)) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == magicNumber) {
            count++;
         }
      }
   }
   return count;
}

void UpdateTrailingStops() {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionSelect(i)) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == magicNumber) {
            
            double posSL = PositionGetDouble(POSITION_SL);
            double posTP = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            ulong posTicket = PositionGetTicket(i);
            
            if(posType == POSITION_TYPE_BUY) {
               double newSL = ask - (ask * (InpTrailAmount / 100.0));
               if(newSL > posSL) {
                  trade.PositionModify(posTicket, newSL, posTP);
               }
            }
            else if(posType == POSITION_TYPE_SELL) {
               double newSL = bid + (bid * (InpTrailAmount / 100.0));
               if(newSL > 0 && newSL < posSL) {
                  trade.PositionModify(posTicket, newSL, posTP);
               }
            }
         }
      }
   }
}

void OnDeinit(const int reason) {
   if(handleSMA != INVALID_HANDLE) {
      IndicatorRelease(handleSMA);
   }
   Print("EA Stopped. Reason: ", reason);
}
