
#include <Object.mqh>
#include <Trade/Trade.mqh>

input double RiskPercent = 0.5;
input double TpPercent = 0.5;
input double MartingaleF = 2.0;

input ENUM_TIMEFRAMES TF = PERIOD_H1;
input int MinRangeBars = 20;
input int CompBars = 40;
input double MinRangeFactor = 0.5;

class CSetup : public CObject {
public:
   datetime time1;
   datetime timeX;
   double high;
   double low;
   
   ulong Posticket;
   double LostMoney;
   
   void drawRect() {
      string objName = MQLInfoString(MQL_PROGRAM_NAME)+" "+TimeToString(time1);
      ObjectCreate(0,objName,OBJ_RECTANGLE,0,time1,high,timeX,low);
   }
   
};

CSetup setup;
CTrade trade;

int OnInit()
  {
//---
//---
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
//---
   
  }



void OnTick()
{
//---
   int HighestIndex = iHighest(_Symbol,TF,MODE_HIGH,MinRangeBars,1);
   int LowestIndex = iLowest(_Symbol,TF,MODE_LOW,MinRangeBars,1);
   double Rhigh = iHigh(_Symbol,TF,HighestIndex);
   double Rlow = iLow(_Symbol,TF,LowestIndex);
   double RBarsSize = Rhigh - Rlow;
   
   double CompHigh = iHigh(_Symbol,TF,iHighest(_Symbol,TF,MODE_HIGH,CompBars,1));
   double CompLow = iLow(_Symbol,TF,iLowest(_Symbol,TF,MODE_LOW,CompBars,1));
   double CompBarsSize = CompHigh - CompLow;
   
   if(setup.time1 <= 0 ) {                               //Look for Setup and update variable values
      if(RBarsSize < CompBarsSize * MinRangeFactor) {
         setup.time1 = iTime(_Symbol,TF,1);
         setup.timeX = iTime(_Symbol,TF,MinRangeBars+1);
         setup.high = Rhigh;
         setup.low = Rlow;
         setup.drawRect();
      }
   }else {
      double Bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      
      double RiskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent/100);
      double RiskPerLot = (setup.high - setup.low) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE); //Range value $$ @1.00 lots
      double lots = RiskPerLot/RiskMoney;
      
      //Check Signals(Breakouts)
      if(Bid >= setup.high) {
         //Open and Manage Orders
         if(PositionSelectByTicket(setup.Posticket)) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               lots = PositionGetDouble(POSITION_VOLUME) * MartingaleF;
               if(trade.PositionClose(setup.Posticket)) {
                  setup.Posticket = 0;
                  setup.LostMoney += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
                  Print(setup.Posticket," CloseSell_NewBuy");
               }
            }
         }
         
         if(setup.Posticket <= 0) {
            lots = NormalizeDouble(lots,2);
            if(trade.Buy(lots)) {
               setup.Posticket = trade.ResultOrder();
            }
         }  
      }else if(Bid <= setup.low) {
         if(PositionSelectByTicket(setup.Posticket)) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               lots = PositionGetDouble(POSITION_VOLUME) * MartingaleF;
               if(trade.PositionClose(setup.Posticket)) {
                  setup.Posticket = 0;
                  setup.LostMoney += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
                  Print(setup.Posticket," CloseBuy_NewSell");
               }
            }
         }
      
         if(setup.Posticket <= 0) {
            lots = NormalizeDouble(lots,2);
            if(trade.Sell(lots)) {
               setup.Posticket = trade.ResultOrder();
            }
         }
      }
      //Close opened positions if TpPercent reached
      PositionSelectByTicket(setup.Posticket);
      if(setup.LostMoney + PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) > AccountInfoDouble(ACCOUNT_BALANCE) * TpPercent/100) {
         if(trade.PositionClose(setup.Posticket)) {
            setup.time1 = 0;
            setup.Posticket = 0;
            setup.LostMoney = 0;
            Print(setup.Posticket," TP% reached Trade Closed");
         }
      }
   }
//---
}
//+------------------------------------------------------------------+

