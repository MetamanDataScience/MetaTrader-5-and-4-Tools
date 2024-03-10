#property copyright "ChrisMeta1"
#property version   "1.10"
#include <Trade/Trade.mqh>
#include <CHistoryPositionInfo.mqh>

input bool Pout = true;
input int MaxSlippage = 20;
input int TradeStartHour = 08;
input int TradeStartMin = 01;

//+------------------------------------------------------------------+
         int OnInit()
         {
     //  OnInit_Event();
         DealHistory(false,true);
         
           return(INIT_SUCCEEDED);
         }
         
         
         void OnDeinit(const int reason)
         {
         
         Comment(" ");
         }
         
         
         void OnTick()
         {
         OnTick_Event();
         // IsNewDeal();
         // IsNewBar(_Symbol,PERIOD_M1);
         double Today  = 0;
         double Target = 100;
         if(ISTradeAllowed(1,0,22,0,_Symbol,Target,Today)) {   Print("  Today> ",NormalizeDouble(Today,2)); 
         
         }
         
         // ---
         }
         
         
         void OnTrade() {
         Deal();
         }
         
//+------------------------------------------------------------------+
//+      CUSTOM FUNCTIONS                                            +
//+      |:: GLOBAL VARIABLES                                        +
//+------------------------------------------------------------------+
int Handle_StepMA,Handle_UniMA,Handle_ZZ;           // | Indicator Handles
CTrade Trade;                                       // | Declaration of Trade class object
ulong ROrder, RDeal;                                // | Position Managment
ulong COrder, CDeal;                                // |
ulong PositionTicket;                               // |
int HDLast = 0;                                     // | ...

string PAIR = _Symbol;
ENUM_TIMEFRAMES PERIOD = PERIOD_CURRENT;
int BarsTotal = iBars(_Symbol,PERIOD_M1);



//+------------------------------------------------------------------+
int OnInit_Event() {
   Handle_StepMA = iCustom(PAIR,PERIOD,"StepMA Alerts.ex5");
   // Handle_UniMA = iCustom(PAIR,PERIOD,"");
   // Handle_ZZ = iCustom(PAIR,PERIOD,"ZigZagColor.ex5");
   Trade.SetExpertMagicNumber(101022);
   Trade.SetDeviationInPoints(MaxSlippage);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
         
void OnTick_Event() {
   if(isNewBar(_Symbol,PERIOD_M1)) {
   
      string LClosed   = "WON";
      double LCProfit  = 0;
      double LCVolume  = 0;
      double TODAYNet  = 0;
      double TradeLots = 0.1;
      ulong  LTicket   = 0;
      
      if(PositionsTotal() > 0) {
         Trade.PositionClose(_Symbol);  //DEAL_REASON_EXPERT
         CDeal  = Trade.ResultDeal();      // | Last Closed Position Out-DealId ... Prime Value to work with to handle HistorydDeals !!!
         COrder = Trade.ResultOrder();     // | Last Closed Position POSITION_ID ... corressponding OrderId to Out-DealId

         string P11 = isNewHDeal(false,"(OUT|") ;        // | Essential for obtaining DealHistory Info ... pass here CDeal or LTicket to obtain last closed Out-Deal properties
         string P22 = ")  |->OutDeal |"+IntegerToString(CDeal)+" |$";      
         LTicket  = HistoryDealGetInteger(CDeal,DEAL_POSITION_ID);    // | Proccess last trade result
         LCProfit = HistoryDealGetDouble(CDeal,DEAL_PROFIT);          // |
         LCVolume = HistoryDealGetDouble(CDeal,DEAL_VOLUME);          // | ...
         if(HistoryDealSelect(CDeal)) { if(LCProfit <= 0) { LClosed = "LOST"; } if(LTicket == 0) { LClosed = "_NUUL_"; } }
         if(Pout) { Print("  ",P11,P22,LCProfit,"|"); }  
      // ...
      }
      TODAYNet = DealHistory(true,false);  
      if(Trade.Sell(TradeLots)) {                // LTicket can be used here for ... Multiplied Lot Function ... last exit position properties HistorySelectByPosition(LTicket)
         ROrder = Trade.ResultOrder();     // | Newest Position POSITION_ID ... Compare with POSITION_ID/ HistorySelectByPosition(ROrder)
         RDeal  = Trade.ResultDeal();      // | Newest Position In-DealId
         // if(HistorySelectByPosition(ROrder)) { 
         // for(int i=HistoryDealsTotal()-1; i>=0; i--;) { ulong TicketLast = historydealgetticket(i); break; }
         
         string P1 = isNewHDeal(false,"(IN|");     // | Essential for obtaining DealHistory Info
         string P2 = ")  |LAST("+DoubleToString(LCProfit)+")|"+" |TODAY("+DoubleToString(TODAYNet)+")";       // | string P2 = "|->NewestPositionId |"+ROrder+"|   |->InDeal |"+RDeal+"|   |->ClosedPositionId |"+LTicket+"|  LastREZ> "+;                
         if(Pout) { Sleep(1000); Print("   ",P1,P2); }      // LClosed
         // DealHistory();   
      }
   }
   // For DEAL_REASON ... DealHistory(true,false); } if DealHistory is set to run once only
   Deal();
}

//+------------------------------------------------------------------+
bool isNewBar(string SYMBOL, ENUM_TIMEFRAMES TF) {
   static datetime LastBar = 0;
   datetime NewBar = datetime(SeriesInfoInteger(SYMBOL,TF,SERIES_LASTBAR_DATE));
   if(LastBar == 0) { LastBar = NewBar; return false; }                                // Assign value for first function call
   if(LastBar != NewBar) { LastBar = NewBar; return true; } else return false;         // If the two aren't equal, a new bar has begun, reassign value once
   
}

bool IsNewBar(string SYMBOL, ENUM_TIMEFRAMES TF) {
   int BARSTotal =  iBars(SYMBOL,TF);
   if( BarsTotal != BARSTotal) {
       BarsTotal =  BARSTotal;
      return true;
   }  else return false;
}

//+------------------------------------------------------------------+
#define HDStart 12

string isNewHDeal(bool P, string WHERE) {          // | Check for NewDeal and provide Print Utility
   string POut;
   if(HistorySelect(TimeCurrent()-(HDStart*60*60),TimeCurrent())) {
      int HDTotal =  HistoryDealsTotal();
      if( HDTotal != HDLast) {
          HDLast  =  HDTotal;
          
          Deal();
         // if(P) { Print("  |->New|",HDLast,"(",WHERE,")"); }
      }
   }
   return POut = WHERE+IntegerToString(HDLast);    
}

   int LastHD = 0;
bool isNewhDeal(bool PRINT) {                      // | Simple check/update and Notify/Print
   int DTotal =  HistoryDealsTotal();
   if( DTotal != LastHD) {
       LastHD =  DTotal;
      if(PRINT) { Print("  |-> DEALS |",DTotal,"| ",LastHD); }
      return true;
   }
   return false;
}

bool IsNewDeal() {
   if(HistorySelect(TimeCurrent()-(HDStart*60*60),TimeCurrent())) {
      int HDTotal =  HistoryDealsTotal();
      if( HDTotal != HDLast) {
          HDLast  =  HDTotal;

         Print("  |->LastDeal (",HDLast,") "); 
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
double OnLoss,    OnWin;            // Increase %% for trade sequence
double LastLostP, LastLWonP;        // Last Trade Result in Points
CHistoryPositionInfo HPosInfo;

int TodayHistoryState() {           // | Universal function ... for Hedging account type only
   MqlDateTime SelectTime;
   TimeCurrent(SelectTime);
   SelectTime.hour = TradeStartHour;
   SelectTime.min  = TradeStartMin;
   datetime HSelectFrom = StructToTime(SelectTime);
   
      if(HPosInfo.HistorySelect(HSelectFrom,TimeCurrent())) {
         int HTotal = HPosInfo.PositionsTotal();
         for(int i=HTotal-1; i>=0; i--) {
            if(HPosInfo.SelectByIndex(i)) {
               double POpen  = HPosInfo.PriceOpen();
               double PClose = HPosInfo.PriceClose();
               double Profit = HPosInfo.Profit();
               string SYMBOL = HPosInfo.Symbol();
               long   PId    = HPosInfo.Identifier();
               
               Print("  |->PId: ",PId,"    |->SYMBOL: ",SYMBOL,"   |->Profit: ",Profit,"   |->POpen: ",POpen,"   |->PClose: ",PClose);
            }
         }
      }
      return 1;
}

bool ISTradeAllowed(int TSHour,int TSMin,int TEHour,int TEMin,string TSymbol,double TProfit,double &TODAY) {    // double SymbolPTarget
   MqlDateTime STime;
   TimeCurrent(STime);
   double TNet  = 0;
   double TCost = 0;
   datetime DOpen = iTime(PAIR,PERIOD_D1,0);
      
   STime.hour = TSHour;
   STime.min  = TSMin;
   datetime TradeStart = StructToTime(STime);   
   STime.hour = TEHour;
   STime.min  = TEMin;
   datetime TradeEnd = StructToTime(STime);
   
   if(HistorySelect(DOpen,TimeCurrent())) {
      for(int i=HistoryDealsTotal()-1; i>=0; i--) {
         ulong  DTicket   = HistoryDealGetTicket(i);
         ulong  DPid      = HistoryDealGetInteger(DTicket,DEAL_POSITION_ID);
         string DSymbol   = HistoryDealGetString(DTicket,DEAL_SYMBOL);
         double DProfit   = HistoryDealGetDouble(DTicket,DEAL_PROFIT);
         double DCost     = HistoryDealGetDouble(DTicket,DEAL_COMMISSION); // TCost += DCost;
         ENUM_DEAL_ENTRY DEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(DTicket,DEAL_ENTRY);
         
         if(DSymbol == TSymbol) {
            TCost += DCost;
            if(DEntry == DEAL_ENTRY_OUT) {
               TNet += DProfit;
            }
         }
      }
      TODAY = TNet+TCost;
   }
   
   bool ITAllowed = TimeCurrent() >= TradeStart && TimeCurrent() < TradeEnd;
   if(ITAllowed && TODAY < TProfit) { return true; }
   return false; 
}
  


//+------------------------------------------------------------------+
double DealHistory(bool P1,bool P2) {        // string SYMBOL
   double TL   = 0;
   double TG   = 0;
   double TC   = 0;
   double TNet = 0;
   int CountW  = 0;
   int CountL  = 0;
   // Can also get Deal/Position History values for this Week,Month and Total(Full account history), Hourly ... and store the resulting PnL values inside Their respective 
   datetime TStart = iTime(PAIR,PERIOD_D1,0);
   
   if(HistorySelect(TStart,TimeCurrent())) {                    // | This puts the Deal Selection in the for loop in the Reverse order, from the first deals at TStart till TimrCurrent()
         for(int i = HistoryDealsTotal()-1; i>=0; i--) {                                                     // | 
            ulong  DealTicket    = HistoryDealGetTicket(i);                                                  // | Go through all Deals in History
            ulong  DealPId       = HistoryDealGetInteger(DealTicket,DEAL_POSITION_ID);                       // | and obtain relevant Info, this can 
            double DealProfit    = HistoryDealGetDouble(DealTicket,DEAL_PROFIT);                             // | also be done after HistorySelectByPosition(DealPId)
            string DealSymbol    = HistoryDealGetString(DealTicket,DEAL_SYMBOL);                             // |
            double DealCommision = HistoryDealGetDouble(DealTicket,DEAL_COMMISSION);   TC += DealCommision;  // | 
            //if(HistorySelectByPosition(DealPId)) {          UpdateNetUnits(10Pips,SYMBOL);                 // | Nessaccary only if we are selecting a specific position in history ... replace at HistorySelect(datetime)
            //if(HistoryDealSelect(DealTicket)) {                                                            // | Nessaccary to run bool position property functions if this is used
          //   if(DealSymbol == SYMBOL) { ... }  
               if(HistoryDealGetInteger(DealTicket,DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                  if(DealProfit < 0) { TL += DealProfit; CountL ++; if(P1) { Print(DealTicket," | ",DealPId," | ",DealProfit," |  (",CountW,"/",CountL,")"); }   // .
                  } else if(DealProfit > 0) { TG += DealProfit; CountW ++; }
            //}
            }
         }
         // if(P2) { Print("  | TODAY(",NormalizeDouble(TG+TL,2),")| "); }    // Print("  |->TotalLost |",TL,"|   |->TotalGained |",TG,"| ");
         TNet = NormalizeDouble(TG+TL+TC,2);
         Print(" | W/L>(",CountW,"/",CountL,") | ProfitFactor>(",NormalizeDouble(TG/(TL+TC),2),")");
      //}
   }   
   return TNet;
}

bool Deal() {              // Last Position Closed due to SL/TP
   string NewDeal    = "";
   string LastReason = "";
   datetime TStart   = iTime(PAIR,PERIOD_D1,0);
   
   if(HistorySelect(TStart,TimeCurrent())) {   
      for(int i = HistoryDealsTotal()-1; i>=0; i--) {
         ulong DealTicket  = HistoryDealGetTicket(i);
         double DealProfit = HistoryDealGetDouble(DealTicket,DEAL_PROFIT);
         string DealSymbol = HistoryDealGetString(DealTicket,DEAL_SYMBOL);
         ENUM_DEAL_ENTRY DealEntry   = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(DealTicket,DEAL_ENTRY);
         ENUM_DEAL_REASON DealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(DealTicket,DEAL_REASON);
         
           /*  if(isNewHDeal(true,"WHERE")) {*/  if(DealEntry == DEAL_ENTRY_OUT) { NewDeal = "(Out)"; } else if(DealEntry == DEAL_ENTRY_IN) { NewDeal = "(In)"; } //}//
           /*  if(isNewHDeal(true,"WHERE"+"REASON")) {*/  if(DealReason == DEAL_REASON_SL) { LastReason = "|_SL_|"; } else if(DealReason == DEAL_REASON_TP) { LastReason = "|_TP_|"; } else{ break; } //}//
           //  string Update = isNewHDeal(false,NewDeal+" | "+LastReason); //{ Print(NewDeal,LastReason); }
           
           if(DealReason == DEAL_REASON_SL || DealReason == DEAL_REASON_TP) { 
              if(isNewhDeal(false)) { Print("  |->Out-DealId |",DealTicket,"| ",EnumToString(DealReason)," |$$->",DealProfit); 
              return true; break; }
           }      // 
      }
   }   
   return false;
}



/*

    string P2 = "|->NewestPositionId |"+ROrder+"|   |->InDeal |"+RDeal+"|   |->ClosedPositionId |"+LTicket+"|  LastREZ> "+;         

//+=====================================================================================================+   |  Get ZigZag vertices, Itterate Through vertices and calculate their change
CopyBuffer(Handle_ZZ,0,0,10,ZZBuffer0);    // ZigZag High/Sell/SwingHigh
CopyBuffer(Handle_ZZ,1,0,10,ZZBuffer1);    // ZigZag Low/Buy/SwingLow
for(int i=10; i>=0; i--) {
   double Rez[i] = ZZBuffer[i] - ZZBuffer1[i];
   ArraySize(10);
}

//+=====================================================================================================+   |  Get Total Profit, Close All positions if Target reached
double Profit(void) {
  double Res = 0;

  if(HistorySelect(0, TimeCurrent()))
    for(int i=HistoryDealsTotal()-1; i>=0; i--) {
      const ulong Ticket = HistoryDealGetTicket(i);
      if((HistoryDealGetInteger(Ticket, DEAL_MAGIC) == MagicNumber) && (HistoryDealGetString(Ticket, DEAL_SYMBOL) == Symbol()))
          Res += HistoryDealGetDouble(Ticket, DEAL_PROFIT);
    }      
    return(Res);
}

   if(Profit > TodayTargetProfit | ACCOUNT_EQIUITY > TodayTargetProfit) { CloseAllPositions(); }
//+=====================================================================================================+   |  Last Position Closed due to SL/TP
bool Deal(bool &LOSTLast) {     
   if(HistorySelect(TimeCurrent()-(12*60*60),TimeCurrent())) {   
      for(int i = HistoryDealsTotal()-1; i>=0; i--) {
         ulong DealTicket = HistoryDealGetTicket(i);
         double DealProfit = HistoryDealGetDouble(DealTicket,DEAL_PROFIT);
         string DealSymbol = HistoryDealGetString(DealTicket,DEAL_SYMBOL);
         ENUM_DEAL_ENTRY DealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(DealTicket,DEAL_ENTRY);
         ENUM_DEAL_REASON DealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(DealTicket,DEAL_REASON);
         
//         if(DealEntry == DEAL_ENTRY_OUT && DealProfit < 0 && DealSymbol == _Symbol) { LOSTLast = true; }
           if(DealReason == DEAL_REASON_SL || DealReason == DEAL_REASON_TP) { 
              if(isNewHDeal(true)) { Print("  |-> DEALSTOTAL |",DealTicket,"|",EnumToString(DealReason),"| $$-> ",DealProfit); 
              return true; }
           }
      }
   }   
   return false;
}

      | if(isNewHDeal(true)) { } or break; would work to run only once

bool Deal() {     // Last Position Closed due to SL/TP
   string NewDeal = "";
   string LastReason = "";
   
   if(HistorySelect(TimeCurrent()-(12*60*60),TimeCurrent())) {   
      for(int i = HistoryDealsTotal()-1; i>=0; i--) {
         ulong DealTicket = HistoryDealGetTicket(i);
         double DealProfit = HistoryDealGetDouble(DealTicket,DEAL_PROFIT);
         string DealSymbol = HistoryDealGetString(DealTicket,DEAL_SYMBOL);
         ENUM_DEAL_ENTRY DealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(DealTicket,DEAL_ENTRY);
         ENUM_DEAL_REASON DealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(DealTicket,DEAL_REASON);
         
//         if(isNewHDeal(true,"WHERE")) { if(DealEntry == DEAL_ENTRY_OUT) { NewDeal = "Out"; } else if(DealEntry == DEAL_ENTRY_IN) { NewDeal = "In"; } }//
           if(isNewHDeal(true,"WHERE"+"REASON")) { if(DealReason == DEAL_REASON_SL) { LastReason = "_SL_"; } else if(DealReason == DEAL_REASON_TP) { LastReason = "_TP_"; } else{ LastReason = "_NULL_"; }//
           if(isNewDeal(true,) { Print(NewDeal,LastReason); }
           
           if(DealReason == DEAL_REASON_SL || DealReason == DEAL_REASON_TP) { 
              if(isNewHDeal(true)) { Print("  |-> DEALSTOTAL |",DealTicket,"|",EnumToString(DealReason),"| $$-> ",DealProfit); 
              return true; }
           }      // 
      }
   }   
   return false;
}
