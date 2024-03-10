#include <Trade\Trade.mqh>

enum SIGNAL_MODE {
   EXIT_CROSS_NORMAL,      //exit cross normal
   ENTRY_CROSS_NORMAL,     //entry cross normal
   EXIT_CROSS_REVERSED,    //exit cross reversed
   ENTRY_CROSS_REVERSED,   //entry cross reversed
};

input group "===== General ======";
input long InpMagicNumber = 100001;                      //Magic number
input double InpLotSize = 0.01;                          //Lot size
input int InpSlippage = 20;                              //Deviation
input group "===== Trading ======";
input SIGNAL_MODE InpSignalMode = EXIT_CROSS_NORMAL;     //Signal mode
input int InpStoploss = 50;                             //Stoploss in points(0=off)
input int InpTakeprofit = 70;                           //Takeprofit in points(0=off)
input bool InpCloseSignal = false;                       //Close trades by opposite signal
input group "===== Stochastic settings";
input int InpKPeriod = 10;                               //K period
input int InpUpperLevel = 80;                            //Upper level
input group "===== ClearBars Filter";
input bool InpClearBarsReversed = false;                 //Reverse clear bar filter
input int InpClearBars = 0;                              //Clear bars(0=off)

int handle;
double buffermain[];
MqlTick cT;
CTrade trade;

int OnInit()
{
//---
   //check user inputs 
   // ....
   
   //set Magicnumber and Deviation to trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   handle = iStochastic(_Symbol, PERIOD_CURRENT, InpKPeriod, 1, 3, MODE_EMA, STO_LOWHIGH);
   if(handle == INVALID_HANDLE) { Alert("Failed to create indicator handle"); return INIT_FAILED; }
   
   ArraySetAsSeries(buffermain,true);
   
   
   
//---
   return(INIT_SUCCEEDED);
}
  

void OnDeinit(const int reason)
{
//---
   if(handle!=INVALID_HANDLE) { IndicatorRelease(handle); }
   
//---
}
  

void OnTick()
{
//---
   //check for new bar
   if(!IsNewBar()) { return; }
   
   //get current tick
   if(!SymbolInfoTick(_Symbol,cT)) { Print("Failed to get current tick"); return; }
   
   //get indicator values
   if(CopyBuffer(handle,0,0,3 + InpClearBars,buffermain) != (3+InpClearBars)) { Print("Failed to get indicator values"); return; }
   
   //count open positions
   int cntBuy, cntSell;
   if(!CountOpenPositions(cntBuy,cntSell)) { Print("Failed to count open positions"); return; }
   
   //check for buy position
   if(CheckSignal(true, cntBuy) && CheckClearBars(true)) {
      if(InpCloseSignal) { if(!ClosePositions(2)) { return; } }
      double sl = InpStoploss==0 ? 0 : cT.bid - InpStoploss * _Point;
      double tp = InpTakeprofit==0 ? 0 : cT.bid + InpTakeprofit * _Point;
      if(!NormalizePrice(sl)) { return; }
      if(!NormalizePrice(tp)) { return; }
      
      //double riskLots = CalcLots(5,sl);               //Calculate lots as percentage of account lost at specified SL distance
      trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLotSize,cT.bid,sl,tp,"StochasticOne");
   }
   
   //check for sell position
   if(CheckSignal(false, cntSell) && CheckClearBars(false)) {
      if(InpCloseSignal) { if(!ClosePositions(1)) { return; } }
      double sl = InpStoploss==0 ? 0 : cT.ask + InpStoploss * _Point;
      double tp = InpTakeprofit==0 ? 0 : cT.ask - InpTakeprofit * _Point;
      if(!NormalizePrice(sl)) { return; }
      if(!NormalizePrice(tp)) { return; }
      
      //double riskLots = CalcLots(5,sl);             //Calculate lots as percentage of account lost at specified SL distance
      trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLotSize,cT.ask,sl,tp,"StochasticOne");
   }
   
   
   
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|  Custom Functions                                                |
//+------------------------------------------------------------------+


bool IsNewBar() {                                        //Updates pTime to cTime and returns once per new bar                           
   static datetime pTime = 0;
   datetime cTime = iTime(_Symbol,PERIOD_CURRENT,0);
   if(pTime != cTime) {
      pTime = cTime;
      return true;
   }
   return false;
}

bool CountOpenPositions (int &cntBuy, int &cntSell) {    //Count open positions and updates arguments passed by reference
   cntBuy = 0;
   cntSell = 0;
   int total = PositionsTotal();
   for(int i=total-1; i>=0 ; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0) { Print("Failed to get position ticket"); return false; }
      if(!PositionSelectByTicket(ticket)) { Print("Failed to select position by ticket"); return false; }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC,magic)) { Print("Failed to get position magic number"); return false; }
      if(magic == InpMagicNumber) {
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)) { Print("Failed to get position type"); return false; }
         if(type == POSITION_TYPE_BUY) { cntBuy++; }
         if(type == POSITION_TYPE_SELL) { cntSell++; }
      }
   }
   return true;
}

bool NormalizePrice (double &price) {
   double ticksize = 0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,ticksize)) { Print("Failed to get tick size"); return false; }
   price = NormalizeDouble(MathRound(price/ticksize) * ticksize,_Digits);
   return true;
}

bool ClosePositions(int all_buy_sell) {                  //all_buy_sell ~ 0_1_2 | close positions by passed argument value
   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0) { Print("Failed to get position ticket"); return false; }
      if(!PositionSelectByTicket(ticket)) { Print("Failed to select by ticket"); return false; }
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC,magic)) { Print("Failed to get magic"); return false; }
      if(magic == InpMagicNumber) {
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type)) { Print("Failed to get position type"); return false; }
         if(all_buy_sell==1 && type==POSITION_TYPE_BUY) { continue; }
         if(all_buy_sell==2 && type==POSITION_TYPE_SELL) { continue; }
         trade.PositionClose(ticket);
         if(trade.ResultRetcode() != TRADE_RETCODE_DONE) { Print("Failed to close position. ticket:", (string)ticket, 
                                                           "result:", (string)trade.ResultRetcode(),":", trade.CheckResultRetcodeDescription()); }
      }
   }
   return true;
}

bool CheckSignal(bool buy_sell, int cntBuySell) {        //buy_sell ~ true_false | Check for signal, based on enum SIGNAL_MODE input
   //return false if a position is open
   if(cntBuySell>0) { return false; }
   
   //check crossover   
   int lowerLevel = 100 - InpUpperLevel;
   bool upperExitCross = buffermain[1] >= InpUpperLevel && buffermain[2] < InpUpperLevel;
   bool upperEntryCross = buffermain[1] <= InpUpperLevel && buffermain[2] > InpUpperLevel;
   bool lowerExitCross = buffermain[1] <= lowerLevel && buffermain[2] > lowerLevel;
   bool lowerEntryCross = buffermain[1] >= lowerLevel && buffermain[2] < lowerLevel;
   
   //check signal
   switch(InpSignalMode) {
      case EXIT_CROSS_NORMAL:    return ((buy_sell && lowerExitCross) || (!buy_sell && upperExitCross));
      case ENTRY_CROSS_NORMAL:   return ((buy_sell && lowerEntryCross) || (!buy_sell && upperEntryCross));         
      case EXIT_CROSS_REVERSED:  return ((buy_sell && upperExitCross) || (!buy_sell && lowerExitCross));
      case ENTRY_CROSS_REVERSED: return ((buy_sell && upperEntryCross) || (!buy_sell && lowerEntryCross));
   }  
   return false;
}

bool CheckClearBars(bool buy_sell) {
   //return true if filter is inactive
   if(InpClearBars==0) { return true; }
   
   bool checklower = ((buy_sell && (InpSignalMode==EXIT_CROSS_NORMAL || InpSignalMode==ENTRY_CROSS_NORMAL))
                     || (!buy_sell && (InpSignalMode==EXIT_CROSS_REVERSED || InpSignalMode==EXIT_CROSS_NORMAL)));
   for(int i=3; i<(3+InpClearBars); i++) {
      
      //check upper level
      if(!checklower && ((buffermain[i-1]>InpUpperLevel && buffermain[i]<=InpUpperLevel)
         || (buffermain[i-1]<InpUpperLevel && buffermain[i]>=InpUpperLevel))) {
         
         if(InpClearBarsReversed) { return true; }
         else { Print("Clearbars filter prevented ", buy_sell ? "Buy" : "Sell", "Signal. Cross of upperlevel at index ", (i-1),">",i); return false; }  
      }
      
      //check lower level
      if(checklower && ((buffermain[i-1]<100-InpUpperLevel) && buffermain[i]>=(100-InpUpperLevel))
         || (buffermain[i-1]>(100-InpUpperLevel) && (buffermain[i]<=100-InpUpperLevel))) {
         
         if(InpClearBarsReversed) { return true; }
         else { Print("Clearbars filter prevented ", buy_sell ? "Buy" : "Sell", "Signal. Cross of lowerlevel at index ", (i-1),">",i); return false; }   
      }
   }
   if(InpClearBarsReversed) { Print("Clearbars filter prevented ", buy_sell ? "buy" : "sell", "signal. No cross detected"); return false; }
   else{ return true; }
   
}

// Trade with risk percentage of account. Relative to accountsize, calculate lotsize for specified SL distance
double CalcLots(double riskPercent, double slPoints) {
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   
   Print(" || Tsize= ",ticksize,"\n"," || Tvalue= ",tickvalue,"  @(1.00 LOT)");
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent/100;
   double lossLotStep = (slPoints/ticksize) * tickvalue * lotstep;
   
   if(lossLotStep == 0) { Print(" || ",__FUNCTION__," - Lotsize cannot be calculated"); return 0; } 
   double lotsPerRisk = MathFloor(riskMoney/lossLotStep) * lotstep;

   return lotsPerRisk;
}