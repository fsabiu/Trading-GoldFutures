//+------------------------------------------------------------------+
//|                                                 RecoveryZone.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.1"
#property description "RecoveryZone"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include <Charts\Chart.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\Trade.mqh>

CTrade  trade;

input int magic_number = 12345; // EA magic number
input double size = 0.4; // Size
input int min_volume = 500;
input int max_candles_distance = 25;
input int order_expiration_minutes = 30;
input int max_sl = 250; // Max SL pips
input int min_candle_dist = 5; // Min candle distance (mins)
input bool breakeven = false;


// Global variables
  
string symbol= Symbol();
ENUM_TIMEFRAMES timeframe = PERIOD_M1;
bool exact=false;
datetime last_bar_time = 0;
double dynamic_size;

int OnInit()
  {

   //EventSetTimer(3600); // every hour
   datetime time = TimeCurrent();
   
   int bar_index = iBarShift(symbol, timeframe, time, exact);
   last_bar_time = iTime(Symbol(), PERIOD_M1, bar_index);
   
   Print("Init!!!!");
   return(INIT_SUCCEEDED);
}


void OnTick() {
   // Print("TICK");
   
   // Get last hour bar
   datetime now = TimeCurrent();
   int bar_index = iBarShift(symbol, timeframe, now, exact);
   datetime this_bar_time = iTime(Symbol(), PERIOD_M1, bar_index);
   
   MqlDateTime time = {};
   TimeToStruct(TimeCurrent(), time);
   
   
   // New 1 minute bar
   if(this_bar_time != last_bar_time) {
      last_bar_time = this_bar_time;
      
      // Remove order if important volume in opposite direction
      checkOrders();
      
      // Set breakeven when price is (entry + TP) / 2
      if(breakeven) {
         setBreakeven();
      }
      
      CSymbolInfo symbol_info;
      symbol_info.Name(symbol);
      symbol_info.RefreshRates();
      
      int last_vol = iRealVolume(Symbol(), PERIOD_M1, 1);
      
      string last_candle_type = "";
      double last_candle_open = 0; 
      double last_candle_close = 0;
      double last_candle_low = 0; 
      double last_candle_high = 0;
            
      if(isBullish(symbol, PERIOD_M1, 1)) {
         last_candle_type = "Bullish";
      }
      if(isBearish(symbol, PERIOD_M1, 1)) {
         last_candle_type = "Bearish";
      }
      
      if(last_candle_type != "") {
         last_candle_open = iOpen(symbol, timeframe, 1); 
         last_candle_close = iClose(symbol, timeframe, 1);
         last_candle_low = iLow(symbol, timeframe, 1); 
         last_candle_high = iHigh(symbol, timeframe, 1);
      }
      
      // -------- BUY --------- 
      if(last_candle_type == "Bullish" && last_vol > min_volume) {
      
         // Busco otra bullish anterior
         int prev_candle_idx = searchPrevCandle(symbol, timeframe, max_candles_distance, last_candle_type);
         
         if(prev_candle_idx > min_candle_dist) {
            Print("Bullish signal!!!! Last + ", prev_candle_idx + " th.");
            
            double prev_candle_open = iOpen(symbol, timeframe, prev_candle_idx); // Bullish
            double prev_candle_close = iClose(symbol, timeframe, prev_candle_idx); // Bullish
            double prev_candle_low = iLow(symbol, timeframe, prev_candle_idx); // Bullish
            double prev_candle_high = iHigh(symbol, timeframe, prev_candle_idx); // Bullish
            
            if(prev_candle_high < last_candle_high) {
               double entry = prev_candle_close;
               double sl = MathMax(prev_candle_open, entry - max_sl*symbol_info.Point());
               double tp = iClose(symbol, timeframe, 1); // Last candle close
               
               placeBuyLimit(symbol, size, entry, sl, tp, "");
            }
         }
      }
    
      // -------- SELL ----------
      if(last_candle_type == "Bearish" && last_vol > min_volume) {
      
         // Busco otra bearish anterior
         int prev_candle_idx = searchPrevCandle(symbol, timeframe, max_candles_distance, last_candle_type);
         
         if(prev_candle_idx > min_candle_dist) {
            Print("Bearish signal!!!! Last + ", prev_candle_idx + " th.");
            
            double prev_candle_open = iOpen(symbol, timeframe, prev_candle_idx); // Bearish
            double prev_candle_close = iClose(symbol, timeframe, prev_candle_idx); // Bearish
            double prev_candle_low = iLow(symbol, timeframe, prev_candle_idx); // Bearish
            double prev_candle_high = iHigh(symbol, timeframe, prev_candle_idx); // Bearish
            
            if(prev_candle_low > last_candle_low) {
            
               double entry = prev_candle_close;
               double sl = MathMin(prev_candle_open, entry + max_sl*symbol_info.Point());
               double tp = iClose(symbol, timeframe, 1); // Last candle close
               
               placeSellLimit(symbol, size, entry, sl, tp, "");
            } 
         }
      }
    
    }  
}


int searchPrevCandle(string symbol, ENUM_TIMEFRAMES period, int max_candles_distance, string last_candle_type) {
   
   int i = 2;
   int prev_candle = 0;
   
   if(last_candle_type == "Bullish") {
      while(i < max_candles_distance && prev_candle == 0) {
         if(iRealVolume(symbol, period, i) > min_volume && isBullish(symbol, period, i)) {
            prev_candle = i;
         }
         i++;
      }
   }
   
   if(last_candle_type == "Bearish") {
      while(i <= max_candles_distance && prev_candle == 0) {
         if(iRealVolume(symbol, period, i) > min_volume && isBearish(symbol, period, i)) {
            prev_candle = i;
         }
         i++;
      }
   }
   
   return prev_candle;
}

bool isBullish(string symbol, ENUM_TIMEFRAMES period, int idx) {
      if(iClose(symbol, period, idx) - iOpen(symbol, period, idx) > 0.0)
         return true;
      else
         return false;
}

bool isBearish(string symbol, ENUM_TIMEFRAMES period, int idx) {
      if(iClose(symbol, period, idx) - iOpen(symbol, period, idx) < 0.0)
         return true;
      else
         return false;
}

void placeSellLimit(string symbol, double size, double price, double sl, double tp, string comment){
   
   CSymbolInfo symbol_info;
   
   symbol_info.Name(Symbol());
   symbol_info.RefreshRates();
   
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   
   request.type   = ORDER_TYPE_SELL_LIMIT;
   request.type_filling = ORDER_FILLING_FOK;///
   request.action = TRADE_ACTION_PENDING;  // definir una orden pendiente
   request.magic  = magic_number;    // ORDER_MAGIC
   request.symbol = symbol;         // instrument
   
   request.volume = size;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.comment = comment;
   
   // expiration
   //request.type_time = ORDER_TIME_SPECIFIED; 
   //request.expiration = TimeCurrent()+ 60*order_expiration_minutes;
   
   if(!OrderSend(request,result)){
      Print("Fail to set SELL ", request.order,": Error ",GetLastError(),", retcode = ",result.retcode);
   } else{
      Print("Sell set");
   }
     
}


void placeBuyLimit(string symbol, double size, double price, double sl, double tp, string comment){
   
   CSymbolInfo symbol_info;
   
   symbol_info.Name(Symbol());
   symbol_info.RefreshRates();
   
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   
   request.type   = ORDER_TYPE_BUY_LIMIT;
   request.type_filling = ORDER_FILLING_FOK;///
   request.action = TRADE_ACTION_PENDING;  // definir una orden pendiente
   request.magic  = magic_number;    // ORDER_MAGIC
   request.symbol = symbol;         // instrument
   
   request.volume = size;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.comment = comment;
   
   //request.type_time = ORDER_TIME_SPECIFIED; 
   //request.expiration = TimeCurrent()+ 60*order_expiration_minutes;
   
   if(!OrderSend(request,result)){
      Print("Fail to set BUY ", request.order,": Error ",GetLastError(),", retcode = ",result.retcode);
   } else{
      Print("Buy set");
   }
     
}

void cancelOrder(ulong ticket){
   MqlTradeRequest request = {};
   MqlTradeResult  result = {};
   
   request.action = TRADE_ACTION_REMOVE;
   request.order  = ticket;
   ResetLastError();
   if(!OrderSend(request,result)){
      Print("Fail to delete ticket ", request.order,": Error ",GetLastError(),", retcode = ",result.retcode);
   } else {
      Print("Order cancelled. Opposite big volume");
   }
}

void checkOrders(){

   Print("Checking orders");
   COrderInfo ord_info;	
   int last_vol = iRealVolume(Symbol(), PERIOD_M1, 1);
   
   for (int i = 0; i < OrdersTotal(); i++) {
      if(ord_info.SelectByIndex(i) == false ) {
         Print("ERROR - Unable to select the order - ",GetLastError());
         break;
      } 
      
      if(ord_info.Type() == ORDER_TYPE_BUY_LIMIT) {
         if(isBearish(Symbol(), PERIOD_M1, 1) && last_vol >= min_volume/2) {
            cancelOrder(ord_info.Ticket());
         }
      }
      
      if(ord_info.Type() == ORDER_TYPE_SELL_LIMIT) {
         if(isBullish(Symbol(), PERIOD_M1, 1) && last_vol >= min_volume/2) {
            cancelOrder(ord_info.Ticket());
         }
      }
   }
}

void setBreakeven() {
   CPositionInfo pos_info;
   MqlTradeRequest request;
   MqlTradeResult  result;
   
   CSymbolInfo symbol;
                  
   for(int i = PositionsTotal()-1; i >= 0; i--){
      if(pos_info.SelectByIndex(i) && pos_info.Magic() == magic_number) {
            //int res = OrderDelete(OrderTicket());
            CSymbolInfo symbol_info;
            symbol_info.Name(Symbol());
            symbol_info.RefreshRates();
                  
            if(pos_info.Type() == POSITION_TYPE_BUY) {
               double treshold = (pos_info.PriceOpen() + pos_info.TakeProfit()) / 2;
               
               if(symbol_info.Bid() >= treshold) {
   
                  //--- setting the operation parameters
                  request.action= TRADE_ACTION_SLTP;// type of trade operation
                  request.position= pos_info.Ticket();         // ticket of the position
                  request.symbol= pos_info.Symbol();         // symbol 
                  request.sl  = pos_info.PriceOpen();      // Stop Loss of the position
                  request.tp = pos_info.TakeProfit();
                  
                  //--- send the request
                  if(!OrderSend(request,result)) {
                     Print("Current price: ", pos_info.PriceCurrent());
                     printf("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
                  } else{
                     Print("Breakeven set");
                  }
               }
            }
            
            if(pos_info.Type() == POSITION_TYPE_SELL) {
               double treshold = (pos_info.PriceOpen() + pos_info.TakeProfit()) / 2;
               
               if(symbol_info.Bid() <= treshold) {
               
                  //--- setting the operation parameters
                  request.action= TRADE_ACTION_SLTP;// type of trade operation
                  request.position= pos_info.Ticket();         // ticket of the position
                  request.symbol= pos_info.Symbol();         // symbol 
                  request.sl  = pos_info.PriceOpen();      // Stop Loss of the position
                  request.tp = pos_info.TakeProfit();
                  
                  //--- send the request
                  if(!OrderSend(request,result)) {
                     Print("Current price: ", pos_info.PriceCurrent());
                     printf("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
                  } else{
                     Print("Breakeven set");
                  }
               }
            }
      }
   }
}

