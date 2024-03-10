#property copyright "ChrisMeta1"
#property version "1.0"

#include <Trade/Trade.mqh>
#include <Comment.mqh>

string StepMA = "StepMA Alerts.ex5";
                                       // TargetProfit ... /* | This is to be a dynamic value for future developments ... Updating every Quarterly cycle(6HR) for example */
input int TPpoints = 100;
input int SLpoints = 200;
input int BETriggerpoints = 25;
input int BEat            = 15;
input int TargetProfit    = 100;      
input int IncreasePoints  = 50;       //  | Increase-Points
input double LotsFactor   = 1.35;     //  | Lot-Factor
input double InpLots      = 0.1;      //  | Lots
input bool UseCloseFNS    = true;

input int TradeStartHour   = 2;
input int TradeStartMinute = 0;
input int TradeEndHour   = 22;
input int TradeEndMinute = 0;

input bool UseCloseAllTime = true;
input int CloseHour   = 22;
input int CloseMinute = 0;
input bool COMMENT_Show = true;

//+-------------------------------------------------------+
//+============== Indicator Settings =====================+
enum MA_MODE // Type of constant
  {
   SMA,      // SMA
   LWMA      // LWMA
  };
//+---
enum PRICE_MODE // Type of constant
  {
   HighLow,     // High/Low
   CloseClose   // Close/Close
  };
//+---
input group " INDICATOR INPUTS ";
input int Length = 50;
input double Kv = 0.25;
input int StepSize = 0;    // Constant Stepsize(Kv*StepSize)
input MA_MODE Mode = SMA;
input PRICE_MODE Switch = HighLow;
input bool PNot = false;
//+-------------------------------------------------------+

int    Handle;
int    barsTotal;
int    LostPoints;
ulong  PosTicket;    // | Recently Opened PosId
double LastLot;      // | Recently Opened Position Volume
double MLots;
int    LLost;
int    LastHD;

ENUM_DEAL_REASON LR;
bool ComputeMLots;
int tester, visual_mode;      // | For CComment class

CTrade Trade;
CComment COMMENT;

//+------------------------------------------------------------------+
      int OnInit()
      {
         OnInitE();
         OnInitE_COMMENT();
         return(INIT_SUCCEEDED);
      }
      
      void OnDeinit(const int reason)
      {
         COMMENT.Destroy();
         Comment("");
      }
      
      void OnTick()
      {  
         if(isTradeAllowed(TradeStartHour,TradeStartMinute,TradeEndHour,TradeEndMinute)) {
            OnTickE(); 
            SetBEStop(PosTicket); 
            
         }
         
         string TNet = (string)NormalizeDouble(Todays_Net_Profit(_Symbol,false,false),_Digits);
         string TargetP = (string)TargetProfit;
         
         COMMENT.SetText(1,"|| LostPoints-> ",clrGoldenrod);
         COMMENT.SetText(2,"|| TODAY-> $"+TNet+" / "+TargetP,clrOrangeRed);
         COMMENT.SetText(3,"------------------------",clrRed);
         
         //Comment("POSTICKET->   ",PosTicket,"\n","LOSTPOINTS-> ",LostPoints,"\n || Today$$->  ( ",TNet," / ",TargetProfit," )","\n || Points->      ( ",")");

         if(UseCloseAllTime) { CloseAll_Time(CloseHour,CloseMinute); }
      // ---
      }

      
      void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
      {
       int RES = COMMENT.OnChartEvent(id,lparam,dparam,sparam);
       //---Move Panel Event
         if(RES == EVENT_MOVE)
         return;
         //---Change Background Color
         if(RES == EVENT_CHANGE)
         if(COMMENT_Show) { COMMENT.Show(); }
      }
      
      void OnTimer()
      {
         if(!tester || visual_mode)
         {
         COMMENT.SetText(0,"(TIME) "+TimeToString(TimeCurrent(),TIME_MINUTES|TIME_SECONDS),clrLightGoldenrod);
         if(COMMENT_Show) { COMMENT.Show(); }
         }
      }
      // | ============================================================================ |

//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//       CUSTOM FUNCTIONS                                            +
//       |:: Most Functions built for universality for future EA's   +
//+------------------------------------------------------------------+
int OnInitE_COMMENT() {
   tester=MQLInfoInteger(MQL_TESTER);              // Is the Indicator loaded inside the strategy tester
   visual_mode=MQLInfoInteger(MQL_VISUAL_MODE);    // Is the Indicator loaded inside visual testing mode
   // ---
   COMMENT.Create("TestOne-V1",15,45);
   COMMENT.SetAutoColors(false);
   COMMENT.SetColor(clrGreenYellow,clrBlack,255);
   COMMENT.SetFont("Lucida Sans Typewriter",13,true,1.6);
   // ---
 #ifdef __MQL5__
    COMMENT.SetGraphMode(!tester);
 #endif
   // ---
   if(!tester)
      EventSetTimer(1);
   OnTimer();
   // Done
   return(INIT_SUCCEEDED);
}

int OnInitE() {   
   Handle = iCustom(NULL, PERIOD_CURRENT, StepMA, Length, Kv, StepSize, Mode, Switch, PNot);
   Trade.SetExpertMagicNumber(10001);
   Trade.SetDeviationInPoints(20);     // Max Deviation(Max Slippage in points)
      
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTickE() {
   // Deal();     | Optional call of DealHistory check functions here
   ComputeMLots = false;      // | Pass to CFNS & Deal, if the last closed trade was true assign ComputeLots true. NextLine Check if ComputeLots == true, run TRADELOTS function/ or pass ComputeLots to TRADELOTS for internal checking
   MLots = InpLots;
   LLost = 0;
   if(Deal(LR)) { if(LR == DEAL_REASON_SL) { Print("SL_LOSTLAST"); } }     // | If Deal(Return.MLots), feed to Trade Object

   int bars = iBars(_Symbol,PERIOD_CURRENT);
   if(barsTotal != bars) {      
      barsTotal = bars;
      
      double BBuy[], BSell[];
      datetime DayStart = iTime(_Symbol,PERIOD_D1,0);
      MqlTick Tick;
      
      string Spread = "Spread-> " + IntegerToString(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD));
      NormalizeDouble(SymbolInfoTick(_Symbol,Tick),_Digits);
      // Copy info since DayStart(00), upto TimeCurrent() or a desired number of values
      CopyBuffer(Handle,0,1,1,BBuy);
      CopyBuffer(Handle,1,1,1,BSell);
            if(ArraySize(BBuy) > 0 && BBuy[0] != EMPTY_VALUE && BBuy[0] != 0) {
               //buy signal .. Normalize for Buy
               double sl = Tick.ask - SLpoints * _Point;
               double tp = Tick.ask + TPpoints * _Point;
               NormalizeDouble(sl,_Digits);
               NormalizeDouble(tp,_Digits);
               if(SLpoints == 0) { sl = NULL; }
               if(PosTicket > 0) { CloseForNewSignal(POSITION_TYPE_SELL,UseCloseFNS,true,LLost); }    // | PosTicket = 0; ...  CloseForNewSignal(Return.MLots), feed to Trade Object, recieve LotsMultiple factor by totallostpoints/money ... 
               if(LR == DEAL_REASON_SL || LLost == 6) { MLots*=2; /*Print("CFNS_LOSTLAST");*/ } // Recieve and process LotMultiple Factor here ... if(LR == DEAL_REASON_SL) { Mlot*=LLostM } else if(LR == DEAL_REASON_TP) { Mlot*=LWonM or LastLot/1.33 } 
               if(Trade.Buy(MLots,_Symbol,Tick.ask,sl,tp,Spread)) {  // Trade_Grid() or Trade_BE() ... the first one being usefull for XAUUSD, GBPNZD ... and the later for less volitail instruments
                  PosTicket = Trade.ResultOrder();                   // ( M5 )New Trade at every-X pips against First-entry price with X percentage increase in lotsize from first/last position   
               // LastLot = Trade.ResultVolume();                    Substitute SL for Add_Grid(3+3pips)
               }   
            }
            if(ArraySize(BSell) > 0 && BSell[0] != EMPTY_VALUE && BSell[0] != 0) {
               //sell signal ... Normalize for Sell
               double sl = Tick.bid + SLpoints * _Point;
               double tp = Tick.bid - TPpoints * _Point;
               NormalizeDouble(sl,_Digits);
               NormalizeDouble(tp,_Digits);
               if(SLpoints == 0) { sl = NULL; }
               if(PosTicket > 0) { CloseForNewSignal(POSITION_TYPE_BUY,UseCloseFNS,true,LLost); }    // | PosTicket = 0;
               if(LR == DEAL_REASON_SL || LLost == 6) { MLots*=2; /*Print("CFNS_LOSTLAST");*/ } // Recieve and process LotMultiple Factor here ... if(LR == DEAL_REASON_SL) { Mlot*=LLostM } else if(LR == DEAL_REASON_TP) { Mlot*=LWonM or LastLot/1.33 } 
               if(Trade.Sell(MLots,_Symbol,Tick.bid,sl,tp,Spread)) {
                  PosTicket = Trade.ResultOrder();                                                   // | Assign PosTicket with new Ticket number(PosTicket is 0 after the CloseForNewSignal)   
               // LastLot = Trade.ResultVolume();                  
               }   
            }
            // Deal();
   }
   // SetBEStop(PosTicket);
  // double TNet = Todays_Net_Profit(_Symbol,false);
  // Comment("POSTICKET-> ",PosTicket,"\n","LOSTPOINTS-> ",LostPoints,"\n TNET->| ",TNet," |");
   
// ---   
}


//+--------------------------------------------------------------------------------+
//+         POSITION-MANAGMENT, TIME-MANAGMENT, LOT-SIZE CONTROL                   +
//+--------------------------------------------------------------------------------+

bool CloseAll_Time(int CHour, int CMin) {
   MqlDateTime StructTime;
   TimeCurrent(StructTime);
            
   StructTime.hour = CHour;
   StructTime.min = CMin;
   datetime TimeCloseAll = StructToTime(StructTime);
   bool isCloseTime = TimeCurrent() > TimeCloseAll;
   if(isCloseTime) { 
   // Close All Positions
      for( int i=PositionsTotal()-1; i>=0; i--) {
      ulong PTicket = PositionGetTicket(i);
         if(PositionSelectByTicket(PTicket)) {
            if(Trade.PositionClose(PTicket)) {
               Print(" CloseAll-Time Reached:- ", PTicket);
            }
         }
      }
      // Comment("TRUE"); 
      return true; 
   }
   // Comment("");
   return false;
// ---      
}

//+------------------------------------------------------------------+

bool isTradeAllowed(int StartHour, int StartMin, int EndHour, int EndMin) {
   MqlDateTime StructTime;
   TimeCurrent(StructTime);

   StructTime.hour = StartHour;            // | Set Start time values
   StructTime.min  = StartMin;
   datetime TimeStart = StructToTime(StructTime);
   StructTime.hour = EndHour;              // | Start End time values
   StructTime.min  = EndMin;
   datetime TimeEnd = StructToTime(StructTime);

   bool isTradeTime = TimeCurrent() >= TimeStart && TimeCurrent() < TimeEnd;
   double TodaysTotal = Todays_Net_Profit(_Symbol,false,false);

   if(isTradeTime && TodaysTotal < TargetProfit) { return true; }    // Input Target Profit ... If TodaysTotal == Input TargetProfit (Alert / SendNotification)
   
   return false;
}

//+------------------------------------------------------------------+
   ulong ClosedTicket;     // Ticket Closed by CloseForNewSignal
   ulong OutDEALID;

bool CloseForNewSignal(ENUM_POSITION_TYPE TYPE, bool CFNS, bool PRINT,int &LLOST) {     // Last Position Closed Due to New Opposite signal
      if(PositionSelectByTicket(PosTicket)) {   
      double ClosedNet = PositionGetDouble(POSITION_PROFIT);
         if(PositionGetInteger(POSITION_TYPE) == TYPE && CFNS) {
            if(isNewHDeal(true)) {              
            if(Trade.PositionClose(PosTicket)) {
               ClosedTicket = Trade.ResultOrder();          // | Closed position POSITION_ID
               OutDEALID    = Trade.ResultDeal();           // | Closed position's Out-DealId
               
               ClosedForNewSignal_AT(ClosedTicket);         // | Get Position properties for closed(by CFNS) position
               UpdateLostPoints(PosTicket);                 // | Process Total Points Net for all opened-closed trades
               
               PosTicket = 0;                               // | Can skip if used after call of CloseForNewSignal() function
               if(PRINT) { Print("  |->Out-DealId |",OutDEALID,"| CLOSE_FOR_NEW_SIGNAL |$$->",ClosedNet); }
               if(ClosedNet < 0) { LLOST = 6; }
            }
            }
         }
         return true;
      }
   return false;
}

bool ClosedForNewSignal_AT(ulong CLOSEDTICKET) {            // Get Net for Last Closed Position by ClosedForNewSignal()
   if(HistoryDealSelect(ClosedTicket)) {
      double ClosedAT = HistoryDealGetDouble(CLOSEDTICKET,DEAL_PROFIT);
      ulong Total     = HistoryDealsTotal() - 1;
      if(ClosedAT < 0) { Print("  |-> CloseFNS_LOST |",CLOSEDTICKET,"| $$-> ",ClosedAT); 
      
      return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+

bool Deal(ENUM_DEAL_REASON &LastReason) {     // Last Position Closed due to SL/TP
   
   if(HistorySelect(TimeCurrent()-(12*60*60),TimeCurrent())) {   
      for(int i = HistoryDealsTotal()-1; i>=0; i--) {
         ulong DealTicket  = HistoryDealGetTicket(i);
         double DealProfit = HistoryDealGetDouble(DealTicket,DEAL_PROFIT);
         string DealSymbol = HistoryDealGetString(DealTicket,DEAL_SYMBOL);
         ENUM_DEAL_ENTRY DealEntry   = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(DealTicket,DEAL_ENTRY);
         ENUM_DEAL_REASON DealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(DealTicket,DEAL_REASON);
         
           // if(isNewHDeal(true)) { if(DealEntry == DEAL_ENTRY_OUT && DealProfit < 0 && DealSymbol == _Symbol) { string NewDeal = "Out"; } else if(DealEntry == DEAL_ENTRY_IN) { NewDeal = "In"; }
           if(isNewHDeal(false)) { 
              // if(DealProfit < 0) { LLOST = 3; }
              if(DealReason == DEAL_REASON_SL || DealReason == DEAL_REASON_TP) { Print("  |->Out-DealId |",DealTicket,"| ",EnumToString(DealReason)," |$$->",DealProfit);                
              LastReason = DealReason;  
              return true; break; }
           }      // 
      }
   }   
   return false;
}

bool isNewHDeal(bool PRINT) {
   int DTotal =  HistoryDealsTotal();
   if( DTotal != LastHD) {
       LastHD =  DTotal;
       
       /* Deal(Last Reason && Last Reasult Passed as refference ... and pass in where this Function is being called into it ) */
      if(PRINT) { Print(" (ONTRADE) ||-> DEALS |",DTotal,"| ",LastHD); }
      return true;
   }
   return false;
}

double TRADELOTS(ENUM_DEAL_REASON LASTREASON) {       // | Pass in TempVariable, which has been passed into Deal function
   double TLOTS = 0;
   if(LASTREASON == DEAL_REASON_SL) { TLOTS = TLOTS * 2; } else if(LASTREASON == DEAL_REASON_TP) { TLOTS = InpLots; }
   
   return TLOTS;
}
//+------------------------------------------------------------------+

void UpdateLostPoints(ulong POSTICKET) {
   double OPrice   = 0;
   double CPrice   = 0;
   double DVolume  = 0;
   int PDirection  = 0;
   datetime SelectStart = iTime(Symbol(),PERIOD_D1,0);

   
// if(HistorySelect(SelectStart,TimeCurrent()))
   if(HistorySelectByPosition(POSTICKET)) {
      for(int i = HistoryDealsTotal()-1; i>=0; i--) {
         ulong DTicket = HistoryDealGetTicket(i);
         
         if(HistoryDealSelect(DTicket)) {
            if(HistoryDealGetInteger(DTicket,DEAL_ENTRY) == DEAL_ENTRY_IN) {
               OPrice  = HistoryDealGetDouble(DTicket,DEAL_PRICE);
               DVolume = HistoryDealGetDouble(DTicket,DEAL_VOLUME);
               if(HistoryDealGetInteger(DTicket,DEAL_TYPE) == DEAL_TYPE_BUY) {
                  PDirection = 1;
               } else if(HistoryDealGetInteger(DTicket,DEAL_TYPE) == DEAL_TYPE_SELL) {
                  PDirection = -1;  
               } 
            } else if(HistoryDealGetInteger(DTicket,DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                  CPrice = HistoryDealGetDouble(DTicket,DEAL_PRICE);
            }
         }
      }
   }  // HistorySelectByPosition() ... Select HistoryDeal By passing PositionTicket from last closed position 
   
   if(OPrice > 0 && CPrice > 0) {
      if(PDirection == 1) {
         LostPoints += (int)((CPrice - OPrice) / _Point * (DVolume/InpLots));    // Input Commision charge here( (PerLot=? * DVolume)/_Point )
      } else if(PDirection == -1) {
         LostPoints += (int)((OPrice - CPrice) / _Point * (DVolume/InpLots));
      }
   }
   // return LostPoints;
   // if(LostPoints > 0) LostPoints = 0;
// ---
}

double Todays_Net_Profit(string SYMBOL, bool PRINT, bool NORMALIZEVolume) {
   double TodayNP = 0;
   datetime TOPEN = iTime(SYMBOL,PERIOD_D1,0);
   
   if(HistorySelect(TOPEN,TimeCurrent())) {
      for(int i=HistoryDealsTotal()-1; i>=0; i--) {
         ulong DTICKET  = HistoryDealGetTicket(i);
         string DSYMBOL = HistoryDealGetString(DTICKET,DEAL_SYMBOL);
         double DRESULT = HistoryDealGetDouble(DTICKET,DEAL_PROFIT);
         double DVOLUME = HistoryDealGetDouble(DTICKET,DEAL_VOLUME);
         
         if(DSYMBOL == SYMBOL && DRESULT != 0) {
            TodayNP += DRESULT;
            // if(NORMALIZEVolume) { TodayNP += DRESULT ; }
            if(PRINT) { Print("  |->",DSYMBOL," | HDeals |-> ",DTICKET," $$-> ",DRESULT); }
         }
      }
   }
   return TodayNP;
}

//+---------------------------------------------------------------------------------+
//+         BREAK-EVEN, PARTIAL-CLOSE, OMS...                                       +
//+---------------------------------------------------------------------------------+

void SetBEStop(ulong PT) {
   MqlTick Tick;
   double NewSL;
   NormalizeDouble(SymbolInfoTick(_Symbol,Tick),_Digits);
 
   if(PositionSelectByTicket(PT)) {                             
      string PSymbol = PositionGetString(POSITION_SYMBOL);                                 // |
      double PVolume = PositionGetDouble(POSITION_VOLUME);                                 // |            
      double POPrice = PositionGetDouble(POSITION_PRICE_OPEN);                             // |
      double PTP     = PositionGetDouble(POSITION_TP);                                     // |
      double PSL     = PositionGetDouble(POSITION_SL);                                     // | 
      ENUM_POSITION_TYPE PTYPE = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // | Select and Obtain neccessary PositionInfo
      // Breakeven-Stop
      if(PTYPE == POSITION_TYPE_BUY) {
         if(Tick.bid > POPrice + BETriggerpoints * _Point) {
            NewSL = POPrice + BEat * _Point;
            NormalizeDouble(NewSL,_Digits);
            if(NewSL > PSL) { 
               if(Trade.PositionModify(PT,NewSL,PTP)) { Print(" ---POSITION_MODIFY |",PT,"| ",NewSL); }             
            }
         }
         // Print(" ---SELECTBYTICKET  SET_BESTOP-> ",PT);
         // Print(" -",PSymbol," | ",EnumToString(PTYPE)," | ",PVolume," | ",POPrice," |> SL_TP ",PSL,"_",PTP);
      } else if(PTYPE == POSITION_TYPE_SELL) {
         if(Tick.ask < POPrice - BETriggerpoints * _Point) {
            NewSL = POPrice - BEat * _Point;
            NormalizeDouble(NewSL,_Digits);
            if(NewSL < PSL) { 
               if(Trade.PositionModify(PT,NewSL,PTP)) { Print(" ---POSITION_MODIFY |",PT,"| ",NewSL); } 
            }
         }
         // Print(" ---SELECTBYTICKET  SET_BESTOP-> ",PT);
         // Print(" -",PSymbol," | ",EnumToString(PTYPE)," | ",PVolume," | ",POPrice," |> SL_TP ",PSL,"_",PTP);
      }
      //---------------
   }
// ---   
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

bool IsLastLoss(){
   if(HistorySelect(TimeCurrent()-(12*60*60),TimeCurrent())) {
      ulong Total = HistoryDealsTotal()-1;
      ulong LastTicket = MaxValue(Total,ClosedTicket);
         //double PREVprofit = HistoryDealGetDouble(,DEAL_PROFIT);
         Print("  ---IsLastLoss ",Total," | MaxValue-> ",LastTicket);
         return true;
   }
      //double MULTIPLIER;
      //MULTIPLIER = PREVprofit < 0 ? MULTIPLIER * InpIncreaseFactor : 1;
      //double NewLOT = InpLots * MULTIPLIER;
      //return NewLOT;
      Print("  ---IsLastLoss Failed !!!");
   return false;
// ---   
}


ulong MaxValue(ulong &value1, ulong &value2) {
   if(value1 > value2) {
      return value2;
   } else {
      return value1;
   }
}

// bool ClosedForSL_AT() {int History}



double GetLastClosedLoss() {
   double loss = 0.0;

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {            // loop from the last order to the first one
      ulong Ticket = HistoryDealGetTicket(i);
       if(HistoryDealSelect(Ticket)) {               // continue; // if failed to select order, continue to next iteration
          double Profit = HistoryDealGetDouble(Ticket,DEAL_PROFIT);
          if(Profit < 0) { 
            ENUM_DEAL_TYPE Type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(Ticket,DEAL_TYPE);
            loss = Profit;  // get the loss
            break;   // exit the loop
          }
       }
     }
     return loss;
}

// 
// This function `GetLastClosedLoss()` will return the profit (which will be a negative number) of the last closed losing position. Here's how it works:
// 
// 1. `OrdersHistoryTotal()` is used to get the total number of closed orders.
// 2. A for loop is used to iterate over these orders from the most recent one to the oldest one.
// 3. `OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)` is used to select the order at the ith position in the history. If this fails, the loop continues to the next iteration.
// 4. If the profit of the selected order is negative (i.e., it was a loss) and the order was a buy or sell order (not a pending order), then the profit of this order is stored in the `loss` variable and the loop is exited.
// 5. Finally, the function returns the `loss` (which will be a negative number).
