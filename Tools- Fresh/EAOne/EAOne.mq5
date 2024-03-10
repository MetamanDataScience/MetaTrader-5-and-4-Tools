//+------------------------------------------------------------------+
//|                                                        EAOne.mq5 |
//|                                                       ChrisMeta1 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "ChrisMeta1"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <ClassOne.mqh>

input int ADX_Period = 14;
input int MA_Period = 9;
input double ADX_Min = 22.0;
input double Lot = 0.01;
input int Stoploss = 20; 
input int Takeprofit = 30;
input int EA_Magic = 0010;
input int Margin_Check = 1;            //Check Margin{0=NO || 1=YES}
input double Percent_Trade = 5.0;      //Max % of Free Margin to use

int STP,TKP;
MyOne COne;                            //COne can be used to access all public member functions of MyOne class

int OnInit()
{
//---
   //Initialization Function
   COne.doInit(ADX_Period,MA_Period);
   //Set all other relevant values
   COne.setPeriod(_Period);
   COne.setSymbol(_Symbol);
   COne.setMagic(EA_Magic);
   COne.setADXmin(ADX_Min);
   COne.setLots(Lot);
   COne.setCheckMargin(Margin_Check);
   COne.setTpercent(Percent_Trade);
   //Digits Normalization
   STP = Stoploss;
   TKP = Takeprofit;
      if(_Digits==5 || _Digits==3) {
         STP = STP * 10;
         TKP = TKP * 10;
      }
//---
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
//---
   COne.doUninit();
}

void OnTick()
{
//---
   int MyBars = iBars(_Symbol,_Period);
      if(MyBars<60) { Alert("Less than 60 bars"); return; }
      
   MqlTick LatestTick;
   MqlRates Barsrate[];
   
   ArraySetAsSeries(Barsrate,true);
      if(!SymbolInfoTick(_Symbol,LatestTick)) { Alert("Failed to get LatestTick !! ",GetLastError()); return; }
      if(!CopyRates(_Symbol,_Period,0,3,Barsrate)) { Alert("Failed to get Barsrate !! ",GetLastError()); return; }
      
   static datetime PrevT;
   datetime BarT[1];
   BarT[0] = Barsrate[0].time;
   //We dont have a new bar when both times are the same
      if(PrevT == BarT[0]) { return; }
      PrevT = BarT[0];
      
   //Are their open positions
   bool Buy_opened = false, Sell_opened = false;
      if(PositionSelect(_Symbol) == true ) {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) { 
            Buy_opened = true; } else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) { Sell_opened = true; }
      }
      
   COne.setCloseprice(Barsrate[1].close);   //Prev bar close price
   
   if(COne.checkBuySignal() == true) {
      if(Buy_opened) { Alert("Buy position present"); return; }
      //Normalize price inputs
      double askprice = NormalizeDouble(LatestTick.ask,_Digits);
      double STP = NormalizeDouble(LatestTick.ask - STP * _Point,_Digits);
      double TKP = NormalizeDouble(LatestTick.ask + TKP * _Point,_Digits);
      int MaxDev = 100;
      //Send order
      COne.openBuy(ORDER_TYPE_BUY,askprice,STP,TKP,MaxDev);   
   }
   
   if(COne.checkSellSignal() == true) {
      if(Sell_opened) { Alert("Sell position present"); return; }
      //Normalize price inputs
      double bidprice = NormalizeDouble(LatestTick.bid,_Digits);
      double STP = NormalizeDouble(LatestTick.bid + STP * _Point,_Digits);
      double TKP = NormalizeDouble(LatestTick.bid - TKP * _Point,_Digits);
      int MaxDev = 100;
      //Send order
      COne.openSell(ORDER_TYPE_BUY,bidprice,STP,TKP,MaxDev);   
   }  
   

}
//+------------------------------------------------------------------+
