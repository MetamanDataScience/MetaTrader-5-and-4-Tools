
#property copyright "ChrisMeta1"
#property version   "1.20"
#property description "  | EXPERT - TestOne-V1.20 | "
#property description "From the 'PortfolioOne' Stack of MT5 Programs which are a comprehensive collection "
#property description "of fully functional EA's and Libraries which are the foundatins for future Developments"

#include <Trade/Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <CHistoryPositionInfo.mqh>
#include <Comment.mqh>

enum TRADE_INDICATOR {   // | Switch between indicator to determine Buy\Sell 
   TRADE_UMA,                                    // | Trade-UniversalMA MT5
   TRADE_HAS,                                    // | Trade-Heiken Ashi Smoothed
   TRADE_StepMA,                                 // | Trade-StepMA Alerts
   TRADE_ALL,                                    // | Trade-ALL Indicators!!
};

enum TRADE_MODE {        // | How should we trade..? Trade_NextLevel(with incremental Lots & recceding TP Levels...), Trade_OneShot(which implies TSL to be used), Trade_All_HEDGE(which implies trade mode TRADE_ALL, and will trade all signals... with considerations to MaxExposure )
   TRADE_MODE_CFNS,                              // | Close trades at NewSignal or if PositionsTotal Profit reahces specified target( Non-standard TP ) ... UseReEntry / AtEveryXPips
   TRADE_MODE_ONESHOT,                           // | Open trades with set TP and Dynamic SL level ... with Dynamic Lotsize as per Trade&Signal-History to achieve InpSetTarget in $Amount, %Account or Points/Pips
   TRADE_MODE_REENTRY,                           // | ReEntry AtEveryXPips ... with a set moderate&dynamic Target Objective for the first&following Trades After Opening Trade similar to TRADE_MODE_ONESHOT 
};

enum LOT_MODE {          // | How to calculate LotSize for OrderSend ... as fixed amount or based on Risked amount as $$money or Risked amount as percentage of account balance 
   LOT_MODE_FIXED,                               // | Fixed Lotsize
   LOT_MODE_RISKMONEY,                           // | Lotsize based on Risk-Money
   LOT_MODE_RISKACCOUNT_PCT,                     // | Lotsize based on Risk Percent of Account
   LOT_MODE_DYNAMIC,                             // | Dynamic LotSize calculation based on Trading Results( LostP, HSequence, ... ) 
};

enum LOT_MULTIPLE {      // | How to calculate Lot Factors, On LostPoints, ClosedProfit/TodayTarget, 
   WEIGHT_LOSTPOINTS,                            // | As LOSTPOINTS value increases, Traded Lotsize also increase ... ( LOSTPOINTS/LPIncreaseFactor ) would be used to weight Lots, also considering LastLost and LastWon From SYMBOL-DealHistory ...
   WEIGHT_LOST_GAINED,                           // | Considering LOSTPOINTS and GAINEDPOINTS as separate values to assign a different weight to each and obtain a different LotMultiple Factor 
   WEIGHT_NETPOINTS,                             // | Considering NETPOINTS meaning a sum total of points with a single weight and a single LotMultiple Factor to be Obtained
   WEIGHT_LOSTMONEY,
   WEIGHT_NETMONEY,
   M_FACTOR,
   P_DIVIDE_LOSTPOINTS,
   P_DIVIDE_NETPOINTS,
};

enum TARGET_MODE {       // | How to determine Trading Target Objective ... In what type
   TARGET_MODE_MONEY,                            // | TargetIn-$Amount
   TARGET_MODE_ACCOUNT_PCT,                      // | TargetIn-%ofAccount
   TARGET_MODE_NETPOINTS,                        // | TargetIn-Points
};

enum PRICE_MODE // Type of constant
  {
   HIGHLOW,                                      // | High-Low
   CLOSECLOSE,                                   // | Close-Close
  };

string HAS           = "Heiken Ashi Smoothed.ex5";
string StepMA        = "stepma_line.ex5";
string StepMA_Alerts = "StepMA Alerts.ex5";
string UMA           = "UniversalMA MT5.ex5";
string PAIR          = Symbol();
ENUM_TIMEFRAMES PERIOD = PERIOD_CURRENT;
int tester, visual_mode;
double WinRate=0, CWon=0, CLost=0;  
double TodaysTarget=0, TradeRisk=0;
string TodaysTargetPrint="", TradeRiskPrint="";
string TRADE_CMNT = " | ";

   ENUM_POSITION_TYPE   last_pos_type  = WRONG_VALUE;
   ulong                last_pos_time  = 0;            // "0" -> D'1970.01.01 00:00';
   string               POSText        = "";

   //----------------------------------------------------------- |
   double SymbolAskHigh = SymbolInfoDouble(PAIR,SYMBOL_ASKHIGH);
   double SymbolBidLow  = SymbolInfoDouble(PAIR,SYMBOL_BIDLOW);
   //----------------------------------------------------------- |
   int    _digits   = (int)SymbolInfoInteger(PAIR,SYMBOL_DIGITS);    // int    _digits(string SYMBOL) { return((int)SymbolInfoInteger(SYMBOL,SYMBOL_DIGITS)); } 
   double _point    = SymbolInfoDouble(PAIR,SYMBOL_POINT);
   double ticksize  = SymbolInfoDouble(PAIR,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(PAIR,SYMBOL_TRADE_TICK_VALUE);        
   double lotstep   = SymbolInfoDouble(PAIR,SYMBOL_VOLUME_STEP);
   double lotmin    = SymbolInfoDouble(PAIR,SYMBOL_VOLUME_MIN);
   double lotmax    = SymbolInfoDouble(PAIR,SYMBOL_VOLUME_MAX);
   //----------------------------------------------------------- |
   string basecurrency = AccountInfoString(ACCOUNT_CURRENCY);
   double accbalance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double accequity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double freemargin   = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double floatpnl     = AccountInfoDouble(ACCOUNT_PROFIT);
   //----------------------------------------------------------- |
   // datetime TOPEN = iTime(PAIR,PERIOD_D1,0);
   datetime TOPEN = (datetime)SeriesInfoInteger(PAIR,PERIOD_D1,SERIES_LASTBAR_DATE);      // | 'SERIES_LASTBAR_DATE' Obtains the opentime of the specified Symbol-Period 
   #define HDStart 24                                                                     // | Alternative for TOPEN, used as TimeCurrent()-HDStart Where the value can be set as an input, or a condition that will always equate to the time at the start of today(TimeCurrent() - TodayOpen as int/datetime/seconds ...)
   //----------------------------------------------------------- |
   #define CheckInpParam( _condition, _text )  if( _condition ) { \Print( "Error:  ", _text ); return INIT_PARAMETERS_INCORRECT; }    // | Define macro for invalid parameter values
   #define CheckCondition( _condition, _text ) if( _condition ) { \Print( "Error:  ", _text ); return false; }                        // | Universal-Check ... Ex;if volume is valid before OrderSend 
   //----------------------------------------------------------- |
       

// |============== INPUTS ========================================================= |

input int TradeStartHour  = 1;
input int TradeStartMin   = 00;
input int TradeEndHour    = 22;
input int TradeEndMin     = 00;
input int CloseAllHour    = 23;
input int CloseAllMin     = 00;

input TRADE_INDICATOR InpTradeIndicator = TRADE_HAS;        // |  TradeIndicator  |
input double InpTakeProfit      = 100;
input double InpStopLoss        = 1000;
input double InpBETriggerpoints = 200;                        
input double InpBEatPoints      = 50 ;                       
input LOT_MODE InpLotMode       = LOT_MODE_FIXED;           // |  TradeLotMode  |
input double InpLots            = 0.1;                      // | Lotsize /-Initial-LotSize
input double InpRiskPercent     = 0.55;                     // | RiskIn% /-LOT_MODE_ACCOUNT_PCT
input double InpRiskMoney       = 11.1;                     // | RiskIn$ /-LOT_MODE_MONEY
input TRADE_MODE  InpTradeMode  = TRADE_MODE_ONESHOT;       // |  TRADEMODE     |    
input double InpReEntryatPoints = 40;                       // | ReEnter-After
input double InpReEntryFactor   = 1.33;                     // | ReEntry-Lots*
input double InpIncreasePoints  = 50;                       // | IncreasePoints
input double InpPointsDivideBy  = 2.50;                     // | DividePointsBy
input double InpLotsFactor      = 1.37;                     // | LotsFactor*
input double InpCloseAllAt      = 50;                       // | CloseAllAt-$ 
input double InpCloseAllAtPerc  = 0.5;                      // | CloseAllAt-%
input TARGET_MODE InpTargetMode = TARGET_MODE_MONEY;        // |  TARGETMODE    |
input double InpTargetPoints  = 100;                        // | TargetInPoints /-TARGET_MODE_POINTS     |     // input double InpSetTarget = 100;   // | Target/-TARGET_MODE Generalized input that will look at desired InpTargetode      
input double InpTargetAmount  = 100;                        // | TargetIn$      /-TARGET_MODE_MONEY      
input double InpTargetAccPerc = 1.0;                        // | TargetIn%      /-TARGET_MODE_ACCOUNT_PCT
input int MaxSlippage         = 10;                         // | Deviation
input int BaseMagicN0         = 1011;                       // | BaseMagicN0   
input bool UseBE           = true;                             // | BreakEven
input bool UseTSL          = true;                             // | TrailingSL
input bool UseCFNS         = true;                             // | CloseForNewSignal
input bool UseCAllAt       = true;                             // | CloseAllAt
input bool UseCloseAllTime = true;                             // | CloseAllTime
input bool COMMENT_Show    = true;                             // | ShowCOMMENT
input bool ChartIndiADD    = true;                             // | Add the Traded Indicator to the Chart-Window
input bool PNotify         = false;
   
input group "  ";
input group " |    | Indicator-Parameters |     | ";
input group " || --- Heikin Ashi Smoothed ";
input int SmoothingPeriod            = 7;
input ENUM_MA_METHOD SmoothingMethod = MODE_SMMA;
input int Stepsize                   = 3; 
input group " || --- StepMA Alerts        ";
input int VoltyLength            = 250;
input double SensitivityFactor   = 0.35;
input double ConstantStepSize    = 0;
input PRICE_MODE AppliedPrice    = CLOSECLOSE;

input group " || --- UniversalMA MT5      ";
input int Phase = 99;


// |=============================================================================== |


//+------------------------------------------------------------------+
      int OnInit()
      {
      OnInitE();
      OnInitE_COMMENT();
      // InitCounters();      sample function 
      if(InpTargetMode == TARGET_MODE_MONEY) { TodaysTarget = InpTargetAmount; TodaysTargetPrint = "$"+DoubleToString(TodaysTarget,2);
      } else if(InpTargetMode == TARGET_MODE_ACCOUNT_PCT) { TodaysTarget = InpTargetAccPerc; TodaysTargetPrint = " $"+DoubleToString((AccountInfoDouble(ACCOUNT_BALANCE)*InpTargetAccPerc/100),2)+" | %"+DoubleToString(TodaysTarget,2)+" ";
      } else if(InpTargetMode == TARGET_MODE_NETPOINTS) { TodaysTarget = InpTargetPoints; TodaysTargetPrint = DoubleToString(TodaysTarget,2)+"POINTS"; }
      
      if(InpLotMode == LOT_MODE_RISKMONEY) { TradeRisk = InpRiskMoney; TradeRiskPrint = "$"+DoubleToString(TradeRisk,2)+"/trade";
      } else if(InpLotMode == LOT_MODE_RISKACCOUNT_PCT) { TradeRisk = InpRiskPercent; TradeRiskPrint = " $"+DoubleToString((AccountInfoDouble(ACCOUNT_BALANCE)*InpRiskPercent/100),2)+" | %"+DoubleToString(TradeRisk,2)+" ";
      } else if(InpLotMode == LOT_MODE_FIXED)   { TradeRisk = InpLots; TradeRiskPrint = DoubleToString(TradeRisk,2)+"Lot/trade"; 
      } else if(InpLotMode == LOT_MODE_DYNAMIC) { TradeRisk = InpLots; TradeRiskPrint = DoubleToString(TradeRisk,2)+"Lot/dynamic"; }
      
      SYMBOLI.Name(PAIR);
      TRADE.SetExpertMagicNumber(BaseMagicN0);
         
         double H = HistoryIndex(0);
         Print(DoubleToString(H,2));
      
         return(INIT_SUCCEEDED);
      }
      
      void OnDeinit(const int reason)
      {
         // Remove Panel
         COMMENT.Destroy();
         Comment("");
         EventKillTimer();
      }
      
      void OnTick()     
      {        
      double TNPoints, TNProfit, TotalCOST, BuyP, SellP, GainedP, GainedProfit=0, LostP, LostProfit=0;
      int CNTBUY, CNTSELL;
      double Floating, CalculatedLots;
      double Pointvalue=0, MarginPerLot=0;
      //if(ISNEW_DEAL(" OnTick | ",false)) { ... }
      TOPEN = (datetime)SeriesInfoInteger(PAIR,PERIOD_D1,SERIES_LASTBAR_DATE);
      
         TNPoints     = Todays_Net_Points(PAIR,false,BuyP,SellP,GainedP,LostP);               // | Always Refreshes TOPEN first ... since its the first called function and - TOPEN is declared on a global scope
         CalculatedLots = Lots_Calc(LostP,GainedP,InpLotsFactor,WEIGHT_LOSTPOINTS);                     
         TNProfit     = Todays_Net_Profit(PAIR,false,GainedProfit,LostProfit,TotalCOST);
         TRADE_CMNT   = DoubleToString(LostP,2);
         COPforStrategy(CNTBUY,CNTSELL,BaseMagicN0,Floating);            // | MagicN0 Optional Position Selection
                                                                         // | * Make Sure to Check &&|| Synchronize Floating and History Positions Select at PreCondition check ... Both either do or dont check for MagicN0 ...
                                                                         
         CalcLotsRiskPercent(PAIR,InpStopLoss,InpRiskPercent,InpRiskMoney,false);             // | RISKMONEY( InpRiskMoney ) has no application inside the function currently
                  
            // Pass -double Flaoting to a function(Single Run) that will reopen trades at certain values of the current Net Floating value of trades
            
            if(CNTBUY == 0 && CNTSELL == 0) { LastOpenedPos = 0; }       // | keep Note of ExpertMagicN0 
         Pointvalue   = PointValue(PAIR,false);                                               // | Value of one Point/Tick-change or ( 1Pip/10 ) per 1.00Lot ... of the specified currency
         MarginPerLot = MarginRequired(PAIR,1.00);                                            // | Required margin to trade second argument FOR_VOLUME of the specified currency
         
         ulong PSelect=0;
         double OP=0,CP=0,NetPoints=0,RePrice=0;
         
         if(PositionSelect(PAIR)) {       // | Select position with the smaller Ticket Number, which usually turns out to be the furthest by Open-time also
            PSelect = PositionGetInteger(POSITION_TICKET);
            if( (CNTBUY > 0 || CNTSELL > 0) && LastOpenedPos == 0) { LastOpenedPos = PSelect; } 

            if(PositionSelectByTicket(PSelect)) {
               OP = PositionGetDouble(POSITION_PRICE_OPEN);
               CP = PositionGetDouble(POSITION_PRICE_CURRENT);
               
               ENUM_POSITION_TYPE TYPE = ENUM_POSITION_TYPE(PositionGetInteger(POSITION_TYPE));
               if(TYPE == POSITION_TYPE_BUY) { 
                  NetPoints = (CP-OP)/_point;  
                  RePrice  = OP - InpReEntryatPoints * _point; 
                  if(SYMBOL_ASK == RePrice) {    // if(NetPoints > InpReEntryatPoints) { }
                     OnePrint(" OPEN Re-BUY @ "+DoubleToString(RePrice,_Digits),"Notification");
                  }
               } else if(TYPE == POSITION_TYPE_SELL) { 
                  NetPoints = (OP-CP)/_point; 
                  RePrice  = OP + InpReEntryatPoints * _point;
                  if(SYMBOL_ASK == RePrice) {    // if(NetPoints > InpReEntryatPoints) { }
                     OnePrint(" OPEN Re-SELL @ "+DoubleToString(RePrice,_Digits),"Notification"); 
                  }
               }
            }
         }
         
         COMMENT.SetText(0,"+=====================================+",clrRed);
         COMMENT.SetText(3," (Mode)  : "+EnumToString(InpTradeIndicator),clrLightBlue);
         COMMENT.SetText(4,"(Points) : "+DoubleToString(TNPoints,2)+"  | ("+DoubleToString(GainedP,2)+"/"+DoubleToString(LostP,2)+")",clrOrangeRed);     
         COMMENT.SetText(5,"(Profit) : $"+DoubleToString(TNProfit,2)+" | ("+DoubleToString(GainedProfit,2)+"/"+DoubleToString(LostProfit,2)+"+("+DoubleToString(TotalCOST,2)+"))",clrOrangeRed); 
         COMMENT.SetText(6,"(Target) : ("+TodaysTargetPrint+") ",clrOrangeRed);
         COMMENT.SetText(7," (Risk)  : ("+TradeRiskPrint+") / Trade",clrOrangeRed);
         COMMENT.SetText(8," :       : NextLOT> "+DoubleToString(CalculatedLots,2),clrOrangeRed);
         COMMENT.SetText(9,"  (+/-)  : ("+DoubleToString(WinRate,2)+"%) | ("+DoubleToString(CWon,0)+"/"+DoubleToString(CLost,0)+")",clrYellow);
         COMMENT.SetText(10," (Float) : > "+DoubleToString(Floating,2)+" | ("+IntegerToString(CNTBUY)+" | "+IntegerToString(CNTSELL)+")",clrYellow);    
         COMMENT.SetText(11," PValue/1.00LOT : "+DoubleToString(Pointvalue,6),clrBlue);      //  +" _Digits : "+IntegerToString(_digits),clrBlue);
         COMMENT.SetText(12," Margin/1.00LOT : "+DoubleToString(MarginPerLot,2)+basecurrency,clrBlue);
         COMMENT.SetText(13," LastPos   > "+IntegerToString(LastOpenedPos),clrWhite);
         // COMMENT.SetText(13,"Properties > "+POSText,clrWhite);
         COMMENT.SetText(14," CURRENT : "+IntegerToString(PSelect),clrWhite);
         COMMENT.SetText(15,"  Net  > "+DoubleToString(NetPoints,_digits),clrWhite);
         COMMENT.SetText(16,"  ReAt > "+DoubleToString(RePrice,_digits),clrWhite);
         // COMMENT.SetText(15," TOPEN : "+(string)TOPEN,clrAliceBlue);
         COMMENT.SetText(17,"+=====================================+",clrRed);  

         if(ISTRADE_ALLOWED(TradeStartHour,TradeStartMin,TradeEndHour,TradeEndMin)) { 
            OnTickE(PAIR,CalculatedLots);
            SetBEStop(PSelect,InpBEatPoints);
         }
                    
         
         for(int i=PositionsTotal()-1; i>=0; i--) {        // | returns the number of current positions
         if(POSITION.SelectByIndex(i)) {                   // | selects the position by index for further access to its properties
            if(POSITION.Symbol()==SYMBOLI.Name() && POSITION.Magic()==BaseMagicN0)
              {
               ulong pos_time=POSITION.TimeMsc();
                  if(pos_time > 0)
                     {
                     last_pos_type=POSITION.PositionType();
                     last_pos_time=pos_time;
                     //---
                     POSText = EnumToString(last_pos_type)+" | "+POSITION.Symbol()+" | "+
                               IntegerToString(POSITION.Ticket())+" | "+TimeToString(POSITION.Time(),TIME_DATE|TIME_SECONDS)+" | "+
                               DoubleToString(POSITION.Volume(),2);
                    }
                 }
            }
         }
         
      // -----
      }
      
      void OnTrade() {
      ISNEW_DEAL(" | OnTrade -:- "+Symbol(),true);
      Deal(true);            
      // LOST_POINTS(PAIR,false);
      
      // if(started) SimpleTradeProcessor();       sample ...
      // else InitCounters();
      // -----
      }
             
      void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
      {
       int RES = COMMENT.OnChartEvent(id,lparam,dparam,sparam);
       //---Move Panel Event
         if(RES == EVENT_MOVE)
         return;
         //---Change Background Color
         if(RES == EVENT_CHANGE)
         COMMENT.Show();
      }
      
      void OnTimer()
      {
         if(!tester || visual_mode)
         {
         COMMENT.SetText(2," (TIME)  : "+TimeToString(TimeCurrent(),TIME_MINUTES|TIME_SECONDS),clrLightGoldenrod);
         if(COMMENT_Show) { COMMENT.Show(); }
         }
      }

//+------------------------------------------------------------------+

/*|========================================================================================================================|
  | For a faster/smoother running programme remove the following functionalities :
  |   1. CComment::Show as COMMENT>Show(); & int OnChartEvent() from Comment class responsible for Panel Mobility & ObjectGetInteger related to the position of the Panel
  |   2. void OnTimer(), datetime iTime(), int CopyBuffer(), ...
  |   :: In conclusion, runtime profiling show's that the Comment.mqh class and its functionalities are the most resource intensive, 
  |      followed by datetime iTime() function, then the int CopyBuffer() function. A separate programme can be created for the Comment.mqh
  |      functionality alone which has inputs such as - select for SymbolSelect, SelectStartTime, ... !
  |   To improve the runtime of a programme, it is crutial to only create objects once at a global scope, where every function down the line will access the properties and the 
  |   Information through the same instance. Ex: MqlTick TICK; is to be declared once globally, TOPEN=(datetime)SeriesInfoInteger(Symbol,PERIOD_D1,SEREIS_LASTBAR_DATE); is 
  |   to be declared once inside OnTick, and System Functions like iTime, AccountInfo functions are to be declared once 
  |   ::
  |   For future developments, it is important to note out and use the points of identification/selection criterea mainly for all things related to order managment inside 
  |   functions, these are Symbol,Comment & MagicN0. 1.Comment is to be used for more specific and targeted selection of trades perhaps by Entry-condition, StrategyId within  
  |   basket trading approach, EntryId within a sequence of trades opened subsequently ..., 2.Symbol can be used to identify things on a larger scope such as HistoryState()  
  |   of Points, Profit, WinRate, Sequence of Win/Loss trades ... . 3.MagicN0 is perhaps used similarly to Comment without selecting individual trades within the same pair, 
  |   but this can be a more effective way of selection by Strategy for MultiStrategy within a Symbol.
*/

//+------------------------------------------------------------------+
//       CUSTOM FUNCTIONS                                            +
//       |::                                                         +
//+------------------------------------------------------------------+
int Handle_UniMA, Handle_HAS, Handle_StepMA, Handle_StepMA_Alerts, Handle_PSAR;
int LastHDeal=0, HDLast=0;                                            // | Used@ ... ISNEW_DEAL(), isNewHDeal()
ulong LastOpenedPos, ClosedTicketCFNS=0, OutDealCFNS=0;               // | Used@ ... CloseFNS(), OrderSend ...
   double LastPRICE,LastVOLUME;
   string LastOPSymbol;
   ENUM_ORDER_TYPE LastTYPE;

CTrade TRADE;
CPositionInfo POSITION;    
CSymbolInfo SYMBOLI;
CDealInfo m_deal;

CComment COMMENT;
CHistoryPositionInfo HPOSInfo;


//+------------------------------------------------------------------+
int OnInitE() {
   Handle_HAS           = iCustom(PAIR,PERIOD,HAS,SmoothingPeriod,SmoothingMethod,Stepsize);
   Handle_StepMA        = iCustom(PAIR,PERIOD,StepMA,VoltyLength,SensitivityFactor,ConstantStepSize);   
   Handle_StepMA_Alerts = iCustom(PAIR,PERIOD,StepMA_Alerts,VoltyLength,SensitivityFactor,ConstantStepSize);
   Handle_PSAR          = iSAR(PAIR,PERIOD,0.02,0.2);
   
   if(InpTradeIndicator == TRADE_UMA || InpTradeIndicator == TRADE_ALL) {   
      CheckInpParam(Phase < -100 || Phase > 100, "Invalid Phase input for UnivesalMA MT5")
      Handle_UniMA  = iCustom(PAIR,PERIOD,UMA);    
   } 
   if(InpTradeIndicator != TRADE_UMA) { ChartIndicatorDelete(0,0,UMA); }
   // Load MA on Heikin Ashi-Smoothed for trading Swing bias ...
   
   TRADE.SetExpertMagicNumber(BaseMagicN0);
   
   return(INIT_SUCCEEDED);
}

 #define EXPERT_NAME "TestOne-"
 #define EXPERT_VERSION "1.2"
 
int OnInitE_COMMENT() {
   // COMMENT PANNEL  |
   tester=MQLInfoInteger(MQL_TESTER);                       // | Is the Indicator loaded inside the- Strategy Tester
   visual_mode=MQLInfoInteger(MQL_VISUAL_MODE);             // | Is the Indicator loaded inside- Visual Testing Mode
   // Panel Position
   int y=150;
   int x=20;
   if(ChartGetInteger(0,CHART_SHOW_ONE_CLICK)) { y=120; }
   // Panel Name
   string name="Comment_Panel";
   COMMENT.Create(name,x,y);                                // | Create a new Display Panel ... Create("Name", X-position, Y-position);
   // Panel Style                                           // | Set Panel Properties
   COMMENT.SetAutoColors(false);                            // | 
   COMMENT.SetGraphMode(true);                              // |
   COMMENT.SetColor(clrGreenYellow,clrBlack,255);           // | 
   COMMENT.SetFont("Lucida Console",13,false,1.7);          // | ...
 #ifdef __MQL5__
    COMMENT.SetGraphMode(!tester);
 #endif
   COMMENT.SetText(1,StringFormat("(EXPERT) : %sV%s",EXPERT_NAME,EXPERT_VERSION)+" -:- ("+Symbol()+","+IntegerToString(BaseMagicN0)+")",clrDodgerBlue);   
   // Run Timer
   if(!tester)
      EventSetMillisecondTimer(500);
   OnTimer();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+

void OnTickE(string SYMBOL, double TRADE_LOTS) {
   MqlTick TICK;     NormalizeDouble(SymbolInfoTick(SYMBOL,TICK),_digits);
   // double sl, tp;

   // Trade_NextPrice(LastOPSymbol,LastTYPE,LastPRICE,LastVOLUME);

   if(!IsNewBar(SYMBOL,PERIOD,false)) { return; } 
   TOPEN = (datetime)SeriesInfoInteger(PAIR,PERIOD_D1,SERIES_LASTBAR_DATE);   
   
   //-------"Heiken Ashi Smoothed.ex5" data |
   double open, high, low, close, Popen, Phigh, Plow, Pclose;
   double HAopen[];    CopyBuffer(Handle_HAS,0,0,3,HAopen);
   double HAhigh[];    CopyBuffer(Handle_HAS,1,0,3,HAhigh);
   double HAlow[];     CopyBuffer(Handle_HAS,2,0,3,HAlow);
   double HAclose[];   CopyBuffer(Handle_HAS,3,0,3,HAclose);   
   open  = HAopen[0];     Popen  = HAopen[1];
   high  = HAhigh[0];     Phigh  = HAhigh[1];
   low   = HAlow[0];      Plow   = HAlow[1];
   close = HAclose[0];    Pclose = HAclose[1];
   
      bool BUYSIGNAL_HAS  = Pclose > Popen && close < open ? true : false;
      bool SELLSIGNAL_HAS = Pclose < Popen && close > open ? true : false; 
      
         if(InpTradeIndicator == TRADE_HAS) {
         double FB_Price,FB_Volume,NB_Price,NB_Volume,FS_Price,FS_Volume,NS_Price,NS_Volume;
         
            if(BUYSIGNAL_HAS) { 
              double sl = TICK.ask - InpStopLoss * _Point;     NormalizeDouble(sl,_digits);
              double tp = TICK.ask + InpTakeProfit * _Point;   NormalizeDouble(tp,_digits);
              double SL = MathAbs(TICK.ask - sl);
              CalcLotsRiskPercent(SYMBOL,SL,InpRiskPercent,InpRiskMoney,false);
              if(LastOpenedPos > 0) { CloseFNS(LastOpenedPos,POSITION_TYPE_SELL,true); LastOpenedPos = 0; }
              if(TRADE.Buy(TRADE_LOTS,SYMBOL,TICK.ask,sl,tp,TRADE_CMNT)) {   if(PNotify) { SendNotification("BUYSIGNAL_HAS "+Symbol()+" New Buy Opened"); }
              LastOpenedPos = TRADE.ResultOrder();
                   FB_Price  = TRADE.ResultPrice();
                   FB_Volume = TRADE.ResultVolume();
                   NB_Price  = FB_Price - InpReEntryatPoints * _Point;  NormalizeDouble(NB_Price,_digits);
                   NB_Volume = FB_Volume*InpReEntryFactor;              
                         NB_Volume = NormalizeDouble(NB_Volume,2);
                  double NB_SL     = 0;
                  double NB_TP     = 0;
                  // Print("  NEXT Buy-Price = ",NB_Price," @ ",NB_Volume,"Lots");
                  LastOPSymbol = SYMBOL;
                  LastTYPE = ORDER_TYPE_BUY;
                  LastPRICE = FB_Price;
                  LastVOLUME = FB_Volume;
                  //if(TICK.ask < NB_Price) { 
                     //TRADE.Buy(NB_Volume,SYMBOL,TICK.ask,NULL,NULL,"R_E"); }            // | Second Entry at InpReEntryPoints away from first entry price               
                  //if(TRADE.ResultRetcode() == TRADE_RETCODE_DONE) { ulong posticket = TRADE.ResultOrder();  } 
              }
            } else if(SELLSIGNAL_HAS) { 
                     double sl = TICK.bid + InpStopLoss * _Point;      NormalizeDouble(sl,_digits);
                     double tp = TICK.bid - InpTakeProfit * _Point;    NormalizeDouble(tp,_digits);
                     double SL = MathAbs(TICK.ask - sl);                     
                     CalcLotsRiskPercent(SYMBOL,SL,InpRiskPercent,InpRiskMoney,false); 
                     if(LastOpenedPos > 0) { CloseFNS(LastOpenedPos,POSITION_TYPE_BUY,true); LastOpenedPos = 0; }                   
                     if(TRADE.Sell(TRADE_LOTS,SYMBOL,TICK.bid,sl,tp,TRADE_CMNT)) {   if(PNotify) { SendNotification("SELLSIGNAL_HAS "+Symbol()+" New Sell Opened"); }
                     LastOpenedPos = TRADE.ResultOrder();                     
                         FS_Price  = TRADE.ResultPrice();
                         FS_Volume = TRADE.ResultVolume();
                         NS_Price  = FS_Price + InpReEntryatPoints * _Point;   NormalizeDouble(NS_Price,_digits);
                         NS_Volume = FS_Volume*InpReEntryFactor;               
                               NS_Volume = NormalizeDouble(NS_Volume,2);
                        double NS_SL     = 0;
                        double NS_TP     = 0;
                        // Print("  NEXT Sell-Price = ",NS_Price," @ ",NS_Volume,"Lots");
                        LastOPSymbol = SYMBOL;
                        LastTYPE = ORDER_TYPE_SELL;
                        LastPRICE = FS_Price;
                        LastVOLUME = FS_Volume;
                        //if(TICK.bid > NS_Price) { 
                           //TRADE.Sell(NS_Volume,SYMBOL,TICK.bid,NULL,NULL,"R_E"); }     // | Second Entry at InpReEntryPoints away from first entry price
                        //if(TRADE.ResultRetcode() == TRADE_RETCODE_DONE) { ulong posticket = TRADE.ResultOrder(); } 
                     }
            }
            //if(InpTradeMode == TRADE_MODE_REENTRY && PositionsTotal() > 0) {
               //Trade_NextPrice(LastTYPE,LastPRICE,LastVOLUME);      // CHECK it Via Print function output ...
            //}
         //------             
         }
      
   //-------"StepMA .ex5" data        |
   double StepMALine[]; CopyBuffer(Handle_StepMA,0,0,3,StepMALine);                                             // | Calling StepMA-Line Value ... more can be done with this
   double SMABuy[];     CopyBuffer(Handle_StepMA_Alerts,0,1,1,SMABuy);                                          // | Only calling the last candles value to process at Boolean value
   double SMASell[];    CopyBuffer(Handle_StepMA_Alerts,1,1,1,SMASell);                                         // | ...
   
      bool BUYSIGNAL_StepMA  =  ArraySize(SMABuy)  > 0 && SMABuy[0]  != EMPTY_VALUE && SMABuy[0]  != 0 ? true : false; // Fixed problem for CopyBuffer by setting deafult and Non-Signal indexes to 0.00 // StepMALine[1] > StepMALine[2];
      bool SELLSIGNAL_StepMA =  ArraySize(SMASell) > 0 && SMASell[0] != EMPTY_VALUE && SMASell[0] != 0 ? true : false; //  Print(" BUY ",SMABuy[0]," SELL ",SMASell[0]);                                // StepMALine[1] < StepMALine[2];
      
      if(InpTradeIndicator == TRADE_StepMA) { 
         if(BUYSIGNAL_StepMA) {
             // if(TRADE.Buy(InpLots,SYMBOL)) { SendNotification("BUYSIGNAL_StepMA "+Symbol()+" New Buy Opened");
             //    if(TRADE.ResultRetcode() == TRADE_RETCODE_DONE) { ulong posticket = TRADE.ResultOrder(); } 
             // }
              double sl = TICK.ask - InpStopLoss * _Point;     NormalizeDouble(sl,_digits);
              double tp = TICK.ask + InpTakeProfit * _Point;   NormalizeDouble(tp,_digits);
              if(LastOpenedPos > 0) { CloseFNS(LastOpenedPos,POSITION_TYPE_SELL,true); LastOpenedPos = 0; }
              if(TRADE.Buy(TRADE_LOTS,SYMBOL,TICK.ask,sl,tp,TRADE_CMNT)) { if(PNotify) { SendNotification("BUYSIGNAL_StepMA "+Symbol()+" New Buy Opened"); }
              LastOpenedPos = TRADE.ResultOrder();              
                  double FB_Price  = TRADE.ResultPrice();
                  double FB_Volume = TRADE.ResultVolume();
                  double NB_Price  = FB_Price - InpReEntryatPoints * _Point;  NormalizeDouble(NB_Price,_digits);
                  double NB_Volume = FB_Volume*InpReEntryFactor;              
                         NB_Volume = NormalizeDouble(NB_Volume,2);
                  double NB_SL     = 0;
                  double NB_TP     = 0;
                  // Print("  NEXT Buy-Price = ",NB_Price," @ ",NB_Volume,"Lots");
                  if(InpTradeMode == TRADE_MODE_REENTRY) {
                     // Trade_NextPrice(ORDER_TYPE_BUY,FB_Price,FB_Volume);      // CHECK it Via Print function output ...
                     if(TICK.ask < NB_Price) { 
                        TRADE.Buy(NB_Volume,SYMBOL,TICK.ask,NULL,NULL,"R_E"); }            // | Second Entry at InpReEntryPoints away from first entry price
                  }
              }         
         } else if(SELLSIGNAL_StepMA) {
                     //if(TRADE.Sell(InpLots,SYMBOL)) { SendNotification("SELLSIGNAL_StepMA "+Symbol()+" New Sell Opened"); 
                     //   if(TRADE.ResultRetcode() == TRADE_RETCODE_DONE) { ulong posticket = TRADE.ResultOrder(); } 
                     //}
                     double sl = TICK.bid + InpStopLoss * _Point;      NormalizeDouble(sl,_digits);
                     double tp = TICK.bid - InpTakeProfit * _Point;    NormalizeDouble(tp,_digits);
                     if(LastOpenedPos > 0) { CloseFNS(LastOpenedPos,POSITION_TYPE_BUY,true); LastOpenedPos = 0; }                                        
                     if(TRADE.Sell(TRADE_LOTS,SYMBOL,TICK.bid,sl,tp,TRADE_CMNT)) { if(PNotify) { SendNotification("SELLSIGNAL_StepMA "+Symbol()+" New Sell Opened"); }
                     LastOpenedPos = TRADE.ResultOrder();
                        double FS_Price  = TRADE.ResultPrice();
                        double FS_Volume = TRADE.ResultVolume();
                        double NS_Price  = FS_Price + InpReEntryatPoints * _Point;   NormalizeDouble(NS_Price,_digits);
                        double NS_Volume = FS_Volume*InpReEntryFactor;               
                               NS_Volume = NormalizeDouble(NS_Volume,2);
                        double NS_SL     = 0;
                        double NS_TP     = 0;
                        // Print("  NEXT Sell-Price = ",NS_Price," @ ",NS_Volume,"Lots");
                        if(InpTradeMode == TRADE_MODE_REENTRY) {
                           // Trade_NextPrice(ORDER_TYPE_SELL,FS_Price,FS_Volume);
                           if(TICK.bid > NS_Price) { 
                              TRADE.Sell(NS_Volume,SYMBOL,TICK.bid,NULL,NULL,"R_E"); }     // | Second Entry at InpReEntryPoints away from first entry price
                        }
                     } 
         }
      // -----                         
      }
      
   //-------"UniversalMA MT5.ex5" data      |   
   if(InpTradeIndicator == TRADE_UMA) {
      double BUFFER1[];      CopyBuffer(Handle_UniMA,0,0,10,BUFFER1);      ArraySetAsSeries(BUFFER1,true);      // | Buffer1- 0                    | Points at all indexes hold values
      double TREND[];        CopyBuffer(Handle_UniMA,2,0,10,TREND);        ArraySetAsSeries(TREND,true);        // | Trend- 2                      | 
      double RES_ATSIGNAL[]; CopyBuffer(Handle_UniMA,3,0,10,RES_ATSIGNAL); ArraySetAsSeries(RES_ATSIGNAL,true); // | Result(At-Signal != 0)- 3     | 
      double SIGNAL_UP[];    CopyBuffer(Handle_UniMA,4,0,10,SIGNAL_UP);    ArraySetAsSeries(SIGNAL_UP,true);    // | SignalUp- 4                   | 
      double SIGNAL_DOWN[];  CopyBuffer(Handle_UniMA,5,0,10,SIGNAL_DOWN);  ArraySetAsSeries(SIGNAL_DOWN,true);  // | SignalDown- 5                 | 
      double RESULT_FLOAT[]; CopyBuffer(Handle_UniMA,6,0,10,RESULT_FLOAT); ArraySetAsSeries(RESULT_FLOAT,true); // | Result0(Current Floating)- 6  | ...
      double RESULT1[];      CopyBuffer(Handle_UniMA,7,0,10,RESULT1);      ArraySetAsSeries(RESULT1,true);      // | Result1(Last-Closed)- 7
      double RESULT2[];      CopyBuffer(Handle_UniMA,8,0,10,RESULT2);      ArraySetAsSeries(RESULT2,true);      // | Result2(Before LastC)- 8
      double RESULT3[];      CopyBuffer(Handle_UniMA,9,0,10,RESULT3);      ArraySetAsSeries(RESULT3,true);      // | Result3()- 9
      double RESULT4[];      CopyBuffer(Handle_UniMA,10,0,10,RESULT4);     ArraySetAsSeries(RESULT4,true);      // | Result4()- 10
      double RESULT5[];      CopyBuffer(Handle_UniMA,11,0,10,RESULT5);     ArraySetAsSeries(RESULT5,true);      // | Result5()- 11
      double RESULT6[];      CopyBuffer(Handle_UniMA,12,0,10,RESULT6);     ArraySetAsSeries(RESULT6,true);      // | Result6()- 12
      // Comment(" | ",BUFFER1[0],"\n | ",TREND[1],"\n | ",SIGNAL_UP[1],"\n | ",SIGNAL_DOWN[1],"\n | ",RESULT_FLOAT[0],"\n | ",RESULT1[0],"\n | ",RESULT2[0],"\n | ",RESULT3[0],"\n | ",RESULT4[0],"\n | ",RESULT5[0],"\n | ",RESULT6[0]);   
      // Print("  Copied Data for UniversalMA MT5");
      
         bool BUYSIGNAL_UMA  = SIGNAL_UP[1]   != 0 && SIGNAL_UP[2]   == 0 ? true : false;
         bool SELLSIGNAL_UMA = SIGNAL_DOWN[1] != 0 && SIGNAL_DOWN[2] == 0 ? true : false;
         
         if(BUYSIGNAL_UMA) {
         
         } else if(SELLSIGNAL_UMA) {
         
         }
   }
// ----- 
}
               
                 
//+------------------------------------------------------------------+
bool ISNEW_BAR(string SYMBOL, ENUM_TIMEFRAMES TF) {
   static int BarsTotal = 0;  //iBars(PAIR,PERIOD_M1);
   int BTotal     = iBars(SYMBOL,TF);
   if( BarsTotal != BTotal) {
       BarsTotal  = BTotal;   
       Print(__FUNCTION__+" @ "+EnumToString(TF));       
       return true; 
   }
   return false;
}

bool IsNewBar(string SYMBOL, ENUM_TIMEFRAMES TF, bool PRINT) {                                        //Updates pTime to cTime and returns once per new bar                           
   static datetime pTime = 0;
   datetime cTime = iTime(SYMBOL,TF,0);
   if(pTime != cTime) {
      pTime  = cTime;
      if(PRINT) { Print("  NEWBAR"+SYMBOL+EnumToString(TF)); }
      return true;
   }
   return false;
}

bool ISTRADE_ALLOWED(int STARTHOUR, int STARTMIN, int ENDHOUR, int ENDMIN) {
   double GP, LP, TC;
   MqlDateTime StructTime;
   TimeCurrent(StructTime);

   StructTime.hour = STARTHOUR;            // | Set Start time values
   StructTime.min  = STARTMIN;
   datetime TimeStart = StructToTime(StructTime);
   StructTime.hour = ENDHOUR;              // | Start End time values
   StructTime.min  = ENDMIN;
   datetime TimeEnd = StructToTime(StructTime);

   double TodaysTotal = Todays_Net_Profit(Symbol(),false,GP,LP,TC);
   bool isTradeTime   = TimeCurrent() >= TimeStart && TimeCurrent() < TimeEnd;
   bool TargetReached=false;
   string TargetP;
   if(InpTargetMode == TARGET_MODE_MONEY) { TargetReached = TodaysTotal < InpTargetAmount ? true : false;  TargetP = "$"+DoubleToString(InpTargetAmount,2);
   } else if(InpTargetMode == TARGET_MODE_ACCOUNT_PCT) { TargetReached = TodaysTotal < ((accbalance*InpTargetAccPerc)/100) ? true : false;  TargetP = "$"+DoubleToString(((accbalance*InpTargetAccPerc)/100),2)+"(%"+DoubleToString(InpTargetAccPerc,2)+")"; }
   
   if(!TargetReached) { string TargetAccPer = DoubleToString((TodaysTotal/accbalance)*100,2); OnePrint(" ("+Symbol()+")-|TODAY'S TARGET REACHED|>  ($"+DoubleToString(TodaysTotal,2)+"(%"+TargetAccPer+") / "+"("+TargetP+")","Notification"); }    // +EnumToString(InpTargetMode)

   if(isTradeTime && TargetReached) { return true; }   
   
   return false;
}

void OnePrint(string txt, string ACTION)
{
   static bool onerun = false;
   if(onerun) return;
   if(ACTION == "Print")         { Print(txt); }
   if(ACTION == "Notification")  { SendNotification(txt); }
   onerun = true;
}

bool ISCLOSEALL_TIME(int CLOSEHOUR, int CLOSEMIN, string SYMBOL) {      // if(UseCloseAllTime) { CloseAll_Time(CloseHour,CloseMinute); }
   MqlDateTime StructTime;
   TimeCurrent(StructTime);
            
   StructTime.hour = CLOSEHOUR;
   StructTime.min  = CLOSEMIN;
   datetime TimeCloseAll = StructToTime(StructTime);
   
   bool isCloseTime = TimeCurrent() > TimeCloseAll;
   if(isCloseTime) {
      if(PositionSelect(SYMBOL)) {
         string PosSymbol = PositionGetString(POSITION_SYMBOL);
         if(SYMBOL ==  PosSymbol) {
            if(TRADE.PositionClose(PosSymbol,MaxSlippage)) {
               ulong ClosedTicketCloseAllTime = TRADE.ResultOrder();
               Print(" CloseAll-Time Reached-:-",PosSymbol," |", ClosedTicketCloseAllTime,"|");
            }
         }
      }
      return true;
   }
   return false;
} 

//+------------------------------------------------------------------+
// |====================| ORDER,DEALS && POSITIONS MANAGMENT |====================| +
//+------------------------------------------------------------------+

bool ISNEW_DEAL(string WHERE, bool PRINT) {        
   int DTotal    = HistoryDealsTotal();
   if( DTotal   != LastHDeal ) {
       LastHDeal = DTotal;
       if(PRINT) { Print("  |-> DEALS |",DTotal,"| ",LastHDeal,"",WHERE); }
       return true;
   }
   return false;
}

string isNewHDeal(bool P, string WHERE) {          // | Check for NewDeal and provide Print Utility
   string POut;
   if(HistorySelect(TimeCurrent()-(HDStart*60*60),TimeCurrent())) {
      int HDTotal  =  HistoryDealsTotal();
      if( HDTotal != HDLast) {
          HDLast   =  HDTotal;
          
          if(P) { Deal(false); Print("  |->New|",HDLast,"(",WHERE,")"); }
      }
   }
   return POut = WHERE+IntegerToString(HDLast);    
}

double HistoryIndex(int I) {
   double PosAT=0;
   for(int i=HistoryDealsTotal()-1; i>=0; i--) {
   ulong Ticket = HistoryDealGetTicket(I);
   ulong PId    = HistoryDealGetInteger(Ticket,DEAL_POSITION_ID);
   ENUM_DEAL_ENTRY DealEntry   = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(Ticket,DEAL_ENTRY);
               PosAT = HistoryDealGetDouble(Ticket,DEAL_PROFIT);

   static int count = 1;
         if(count == I) {
//            PosAT = HistoryDealGetDouble(Ticket,DEAL_PROFIT);
            break;
         } 
      count++;
   }
   return PosAT; 
}

bool Deal(bool PRINT) {                            // | Last Position Closed due to _SL_/_TP_ or if UseCFNS == true, _EXPERT_  ...
   string NewDeal    = " ..";
   string LastReason = " ..";
   
   if(HistorySelect(TOPEN,TimeCurrent())) {   
      for(int i = HistoryDealsTotal()-1; i>=0; i--) {
         ulong DealTicket  = HistoryDealGetTicket(i);
         double DealProfit = HistoryDealGetDouble(DealTicket,DEAL_PROFIT);
         string DealSymbol = HistoryDealGetString(DealTicket,DEAL_SYMBOL);
         ENUM_DEAL_ENTRY DealEntry   = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(DealTicket,DEAL_ENTRY);
         ENUM_DEAL_REASON DealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(DealTicket,DEAL_REASON);
         
            if(DealEntry  == DEAL_ENTRY_OUT) { NewDeal = "(Out)"; 
               if(DealReason == DEAL_REASON_SL) {      LastReason = "|_SL_|"; } 
               if(DealReason == DEAL_REASON_TP) {      LastReason = "|_TP_|"; }   /*break;*/  
               if(DealReason == DEAL_REASON_EXPERT) {  LastReason = "|_EXPERT_|"; break; }                  // | Could be reason if CloseForNewSignal/Non-Standard TP ... are met and the Expert CLOSES the position
            } else if(DealEntry == DEAL_ENTRY_IN) { NewDeal = "(In)"; 
                     if(DealReason == DEAL_REASON_EXPERT) { LastReason = "|_EXPERT_|"; break;               // | New trade OPENED by the Expert
                     } else if(DealReason != DEAL_REASON_EXPERT) { LastReason = "|_NOTBYEXPERT_|"; }  }     // | For new trades not OPENED by the Expert 
            //string Update = isNewHDeal(true,NewDeal+" | "+LastReason);  /* ... */   
            
            if(ISNEW_DEAL("  | New_Deal | "+__FUNCTION__,false)) { 
            string Update = isNewHDeal(true,NewDeal+" | "+LastReason);  /* ... */   
               if(PRINT) { Print(NewDeal,LastReason," -:- ",__FUNCTION__); }     
               if(DealReason == DEAL_REASON_SL || DealReason == DEAL_REASON_TP) {   
                  if(PRINT) { Print("  |->Out-DealId |",DealTicket,"| ",EnumToString(DealReason)," |$$->",DealProfit); 
                  return true; } 
                  break;
               }      
            }
      }
   }   
   return false;
}

   int          _orders;            // number of active orders
   int          _positions;         // number of open positions
   int          _deals;             // number of deals in the trade history cache
   int          history_orders;    // number of orders in the trade history cache
   bool         started=false;     // flag of initialization of the counters
   datetime _start=TOPEN, _end=TimeCurrent();
   int days = 1;

void InitCounters() {
   ResetLastError();
   //--- load history
   bool selected=HistorySelect(_start,_end);
   if(!selected)
     {
      PrintFormat("%s. Failed to load the history from %s to %s to the cache. Error code: %d",
                  __FUNCTION__,TimeToString(_start),TimeToString(_end),GetLastError());
      return;
     }
   //--- get current values
   _orders=OrdersTotal();
   _positions=PositionsTotal();
   _deals=HistoryDealsTotal();
   history_orders=HistoryOrdersTotal();
   started=true;
   Print("The counters of orders, positions and deals are successfully initialized");

}

//+------------------------------------------------------------------+
//| simple example of processing changes in trade and history        |
//+------------------------------------------------------------------+
void SimpleTradeProcessor() {
   _end=TimeCurrent();
   ResetLastError();
//--- load history
   bool selected=HistorySelect(_start,_end);
   if(!selected)
     {
      PrintFormat("%s. Failed to load the history from %s to %s to the cache. Error code: %d",
                  __FUNCTION__,TimeToString(_start),TimeToString(_end),GetLastError());
      return;
     }

//--- get current values
   int curr_orders=OrdersTotal();
   int curr_positions=PositionsTotal();
   int curr_deals=HistoryDealsTotal();
   int curr_history_orders=HistoryOrdersTotal();

//--- check whether the number of active orders has been changed
   if(curr_orders!=_orders)
     {
      //--- number of active orders is changed
      PrintFormat("Number of orders has been changed. Previous number is %d, current number is %d",
                  _orders,curr_orders);
     /*
       other actions connected with changes of orders
     */
      //--- update value
      _orders=curr_orders;
     }

//--- change in the number of open positions
   if(curr_positions!=_positions)
     {
      //--- number of open positions has been changed
      PrintFormat("Number of positions has been changed. Previous number is %d, current number is %d",
                  _positions,curr_positions);
      /*
      other actions connected with changes of positions
      */
      //--- update value
      _positions=curr_positions;
     }

//--- change in the number of deals in the trade history cache
   if(curr_deals!=_deals)
     {
      //--- number of deals in the trade history cache has been changed
      PrintFormat("Number of deals has been changed. Previous number is %d, current number is %d",
                  _deals,curr_deals);
      /*
       other actions connected with change of the number of deals
       */
      //--- update value
      _deals=curr_deals;
     }

//--- change in the number of history orders in the trade history cache
   if(curr_history_orders!=history_orders)
     {
      //--- the number of history orders in the trade history cache has been changed
      PrintFormat("Number of orders in the history has been changed. Previous number is %d, current number is %d",
                  history_orders,curr_history_orders);
     /*
       other actions connected with change of the number of order in the trade history cache
      */
     //--- update value
     history_orders=curr_history_orders;
     }
//--- check whether it is necessary to change the limits of trade history to be requested in cache
   CheckStartDateInTradeHistory();
}

//+------------------------------------------------------------------+
//|  Changing start date for the request of trade history            |
//+------------------------------------------------------------------+
void CheckStartDateInTradeHistory() {
//--- initial interval, as if we started working right now
   datetime curr_start=TimeCurrent()-days*PeriodSeconds(PERIOD_D1);
//--- make sure that the start limit of the trade history period has not gone 
//--- more than 1 day over intended date
   if(curr_start-_start>PeriodSeconds(PERIOD_D1))
     {
      //--- we need to correct the date of start of history loaded in the cache
      _start=curr_start;
      PrintFormat("New start limit of the trade history to be loaded: start => %s",
                  TimeToString(_start));

      //--- now load the trade history for the corrected interval again
      HistorySelect(_start,_end);

      //--- correct the counters of deals and orders in the history for further comparison
      history_orders=HistoryOrdersTotal();
      _deals=HistoryDealsTotal();
     }
}
#ifdef   SAMPLE_TEMPLATE 

   template <typename COne>                                         // | template function definitions helps to avoid multiple function Overloads ... functions of this type must be definded with conditions such that it will be compatible with var DataTypes passed in at function call 
      COne HistoryLoop(COne START, COne END) {                      // | Function template example, used for Function OverLoading cases to minimize number of functions defined with valid OverLoading parameters ... This template will serve as a general use case (COne being where OverLoading would have been implemented)
          HistorySelect(START,END);                                 // | template is usefull for cases where the inner workings of >1 functions are the same but there is a difference between parameter DataTypes - COne here is a placeholder for whatever datatype needs to be passed in at function call
                              
          return HistoryDealsTotal();                               // | the compiler automatically generates a function with the definition( '{ ... }' ) passed in at template definition with the parameter DataTypes passed in at function call ...
      } 
      
      COne ReturnMaximum(COne A, COne B) {                          // | When we call this function here we can pass in variables of desired Types : ReturnMaximum(First_V, Second_V); where these to arguments are of double type or of int type or of long type ...
         return(A > B) ? A : B;
      }
      
      /*  'Explicit Conversion' call Ex: ReturnMaximum(double) (First_, Second_) where First_ & Second_ or one of them is not of double type  ...  this is neccessary because parametes var Types are the same at function declaration  */

#endif                       
//+------------------------------------------------------------------+
      
double Todays_Net_Profit(string SYMBOL, bool PRINT, double &GAINEDPROFIT, double &LOSTPROFIT, double &TCOST) {
   double TodayP=0, TodayNetP=0;       
   double TGProfit=0, TLProfit=0, TotalCost=0;
   
   if(HistorySelect(TOPEN,TimeCurrent())) {
      for(int i=HistoryDealsTotal()-1; i>=0; i--) {
         ulong DTICKET  = HistoryDealGetTicket(i);
         string DSYMBOL = HistoryDealGetString(DTICKET,DEAL_SYMBOL);
         double DRESULT = HistoryDealGetDouble(DTICKET,DEAL_PROFIT);
         double DVOLUME = HistoryDealGetDouble(DTICKET,DEAL_VOLUME);
         double DCOST   = HistoryDealGetDouble(DTICKET,DEAL_COMMISSION);
         ENUM_DEAL_ENTRY DENTRY = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(DTICKET,DEAL_ENTRY);
         
         if(DSYMBOL == SYMBOL) {
            if(DRESULT < 0) { TLProfit += DRESULT; }
            if(DRESULT > 0) { TGProfit += DRESULT; }
            TodayP      += DRESULT;                            // | Todays Profit as Net of Trade Outcomes
            TotalCost   += DCOST;
            GAINEDPROFIT = NormalizeDouble(TGProfit,2);
            LOSTPROFIT   = NormalizeDouble(TLProfit,2);
            TCOST        = NormalizeDouble(TotalCost,2);
            TodayNetP    = (TodayP)+(TotalCost);               // | Todays Profit as Net of Trade Outcomes and Trading Costs
            if(PRINT) { Print("  |->",DSYMBOL," | HDeals |-> ",DTICKET," $$-> ",TLProfit," | ",TGProfit); }
         }
         // TodayNetP    = (TodayP)+(TotalCost);
      }
   }
   return TodayNetP;
}

double Todays_Net_Points(string SYMBOL, bool PRINT, double &BUYPOINTS, double &SELLPOINTS, double &GAINEDPOINTS, double &LOSTPOINTS) {       // | Pass in Separate values by reference ... &BuyPoints, %SellPoints, &TGainedPoints, &TLostPoints for use at different points throughout the EA
   CHistoryPositionInfo HPInfo;                                                                                   // | Select History Positions
   double SOPrice, SCPrice, SPVolume, SPProfit, BOPrice, BCPrice, BPVolume, BPProfit;                             // | History Position Info by PositionType()
   double BuyPoints=0, SellPoints=0, GainedBuyPoints=0, LostBuyPoints=0, GainedSellPoints=0, LostSellPoints=0;    // | Separate Points Results by PositionType()
   double TodayNetPoints=0, TotalNetVolume=0;                                                                     // | Net result of Trade Outcomes in Points( Price Difference )
   double CountWon=0, CountLost=0, CTotal=0;

   if(HPInfo.HistorySelect(TOPEN,TimeCurrent())) {                                                                // | Select Todays Deals ... or else as specified via TOPEN assignment(Since today, this week,month ... start /opentime )
      for(int i=HPInfo.PositionsTotal()-1; i>=0; i--) { 
         if(HPInfo.SelectByIndex(i)) {
            string PSymbol = HPInfo.Symbol();
            if(PSymbol == SYMBOL) {
               ulong HPTicket           = HPInfo.Ticket();                    // | if(HistorySelectByPosition) { ... }
               ENUM_POSITION_TYPE PType = HPInfo.PositionType();
               
               // | Get Points Information Based on PositionType() ...
               if(PType == POSITION_TYPE_BUY) {    BOPrice = HPInfo.PriceOpen(); BCPrice = HPInfo.PriceClose(); BPVolume = HPInfo.Volume();    
                  BPProfit   = HPInfo.Profit();
                  BPVolume   = HPInfo.Volume();
                  BuyPoints  = (BCPrice - BOPrice) / _Point;                  // Print("|  BUYPOINTS(",BuyPoints,")");
                  /*  Weighted Calculation of Position NetPoints    BuyPoints = (BCPrice - BOPrice) / _Point * (BPVolume / InpLots);     */                  
                  // | Get Points Information Based on History Profit()
                     if(BPProfit > 0) {         GainedBuyPoints +=  BuyPoints;  CountWon++;
                     } else if(BPProfit <= 0) { LostBuyPoints   += (BuyPoints); CountLost++; }
                     BUYPOINTS += BuyPoints;                  
                     if(PRINT) { Print("  Buy |",HPTicket,"| V(",BPVolume,"Lots) Points(",NormalizeDouble(BuyPoints,1),")  |TOTAL->   GainedBP | ",GainedBuyPoints,"  LostBP | ",LostBuyPoints,"\n ..."); }
               } else if(PType == POSITION_TYPE_SELL) {    SOPrice = HPInfo.PriceOpen(); SCPrice = HPInfo.PriceClose(); SPVolume = HPInfo.Volume();  
                  SPProfit   = HPInfo.Profit();
                  SPVolume   = HPInfo.Volume();
                  SellPoints = (SOPrice - SCPrice) / _Point;                  // Print("|  SellPOINTS",SellPoints,")");
                  /*  Weighted Calculation of Position NetPoints   SellPoints = (SOPrice - SCPrice) / _Point * (SPVolume / InpLots);     */
                  // | Get Points Information Based on History Position Result
                     if(SPProfit > 0) {         GainedSellPoints +=  SellPoints;  CountWon++;  
                     } else if(SPProfit <= 0) { LostSellPoints   += (SellPoints); CountLost++; }
                     SELLPOINTS += SellPoints;                                                             
                     if(PRINT) { Print("  Sell|",HPTicket,"| V(",SPVolume,"Lots) Points(",NormalizeDouble(SellPoints,1),")  |TOTAL->   GainedSP | ",GainedSellPoints,"  LostSP | ",LostSellPoints,"\n ..."); }
               }
               CWon    = CountWon;  
               CLost   = CountLost;
               CTotal  = CountWon+CountLost;
               WinRate = (CountWon/CTotal)*100; 
               GAINEDPOINTS   = NormalizeDouble(GainedBuyPoints+GainedSellPoints,2);
               LOSTPOINTS     = NormalizeDouble(LostBuyPoints+LostSellPoints,2);
               TodayNetPoints = NormalizeDouble((GAINEDPOINTS+LOSTPOINTS),2);
               // Print();            
            }            
            // TodayNetPoints = NormalizeDouble((GAINEDPOINTS+LOSTPOINTS),3);
         }
      }     
   }
   return TodayNetPoints;
}

double Todays_Net_Points_VolumeWeighted() {
   
   double TNP_VolWeighted=0;
   
   return TNP_VolWeighted;
}

int TodayHistoryState() {                          // | Universal function ... for Hedging account type only
   MqlDateTime SelectTime;
   TimeCurrent(SelectTime);
   SelectTime.hour = TradeStartHour;
   SelectTime.min  = TradeStartMin;
   datetime HSelectFrom = StructToTime(SelectTime);
   
      if(HPOSInfo.HistorySelect(HSelectFrom,TimeCurrent())) {
         int HTotal = HPOSInfo.PositionsTotal();
         for(int i=HTotal-1; i>=0; i--) {
            if(HPOSInfo.SelectByIndex(i)) {
               double POpen  = HPOSInfo.PriceOpen();
               double PClose = HPOSInfo.PriceClose();
               double Profit = HPOSInfo.Profit();
               string SYMBOL = HPOSInfo.Symbol();
               long   PId    = HPOSInfo.Identifier();
               
               Print("  |->PId: ",PId,"    |->SYMBOL: ",SYMBOL,"   |->Profit: ",Profit,"   |->POpen: ",POpen,"   |->PClose: ",PClose);
            }
         }
      }
      return 1;
}

bool LOST_POINTS(string SYMBOL, bool PRINT) {
   double NetPoints = 0;
   // static int C;
   
   if(HistorySelect(TOPEN,TimeCurrent())) {
      for(int i=HistoryDealsTotal()-1; i>=0; i--) {
         ulong DTicket  = HistoryDealGetTicket(i);
         string DSYMBOL = HistoryDealGetString(DTicket,DEAL_SYMBOL);
         // if(DSYMBOL == SYMBOL) {
         if(HistoryDealGetInteger(DTicket,DEAL_ENTRY) == DEAL_ENTRY_IN) { ulong DTicket = HistoryDealGetTicket(i); ulong PId = HistoryDealGetInteger(DTicket,DEAL_POSITION_ID); double DPr = HistoryDealGetDouble(DTicket,DEAL_PROFIT); if(PRINT) { Print(" IN |  | ",PId," | ",DPr); } }
         if(HistoryDealGetInteger(DTicket,DEAL_ENTRY) == DEAL_ENTRY_OUT) { ulong DTicket = HistoryDealGetTicket(i); ulong PId = HistoryDealGetInteger(DTicket,DEAL_POSITION_ID); double DPr = HistoryDealGetDouble(DTicket,DEAL_PROFIT); if(PRINT) { Print("   OUT |  | ",PId," | ",DPr); }
         break; }    // C++; for DealsTotal
         // }
         }
      return true;
   }
   return false;
}


bool CountOpenPositions(int &cntBuy, int &cntSell){
      cntBuy=0; cntSell=0;
                                                                                                                     //Inside For Loop, Iteration through all open positions
      int total = PositionsTotal();                                                                                  //Total number of open positions
      for(int i=total-1; i>=0; i--){                                                                                 //Iterate through total all open positions backwards
         ulong ticket = PositionGetTicket(i);                                                                        //PositionGetTicket for all open positions
         if(ticket<=0){Print("Failed to get position ticket -:- "+__FUNCTION__); return false;}                                        //Check for error
         if(!PositionSelectByTicket(ticket)){Print("Failed to select position by ticket -:- "+__FUNCTION__); return false;}            //Select individual positions by their ticket
         long magic;                                                                                                 //Handle Individual positions by magicnumber to identify opening condition(Placed By EA or Manually, Or by Strategy1 or Strategy2 ...)
         if(!PositionGetInteger(POSITION_MAGIC,magic)){Print("Failed to get position magicnumber -:- "+__FUNCTION__); return false;}   //Identify positions with the desired magicnumber, to identify which ones were placed by the EA, or which strategy inside the EA opened the specific position
         if(magic==BaseMagicN0){                                                                                     //Possible to use more If/separatemultiple magicnumbers can exsist
            long type;
            if(!PositionGetInteger(POSITION_TYPE,type)){Print("Failed to get positon type -:- "+__FUNCTION__); return false;}
            if(type==POSITION_TYPE_BUY)  { cntBuy++;  }
            if(type==POSITION_TYPE_SELL) { cntSell++; }
         
         }//else if(magic==Magic01){long type01; ...}
      }                                                                                                      
      return true;   
}

bool COPforStrategy(int &cntBuy, int &cntSell, int INPMAGIC, double &CFLOAT) {     //Count Open Positions for a specific strategy ... identified with MagicN0 passed as argument/parameter
      cntBuy=0; cntSell=0;     
      double Floating=0;
                                                                                                                     //Inside For Loop, Iteration through all open positions
      int total = PositionsTotal();                                                                                  //Total number of open positions
      for(int i=total-1; i>=0; i--){                                                                                 //Iterate through total all open positions backwards
         ulong ticket = PositionGetTicket(i);                                                                        //PositionGetTicket for all open positions
         if(ticket<=0){Print("Failed to get position ticket -:- "+__FUNCTION__); return false;}                      //Check for error
         if(!PositionSelectByTicket(ticket)){Print("Failed to select position by ticket -:- "); return false;}       //Select individual positions by their ticket
         long magic;                                                                                                 //Handle Individual positions by magicnumber to identify opening condition(Placed By EA or Manually, Or by Strategy1 or Strategy2 ...)
         if(!PositionGetInteger(POSITION_MAGIC,magic)){Print("Failed to get position magicnumber -:- "+__FUNCTION__); return false;}   //Identify positions with the desired magicnumber, to identify which ones were placed by the EA, or which strategy inside the EA opened the specific position
         if(magic==INPMAGIC){                                                                                        //Possible to use more If/separatemultiple magicnumbers can exsist
            long type;
            Floating += PositionGetDouble(POSITION_PROFIT);       // | Floating holds net results for positions with the INPMAGIC ...
            if(!PositionGetInteger(POSITION_TYPE,type)){Print("Failed to get positon type -:- "+__FUNCTION__); return false;}
            if(type==POSITION_TYPE_BUY)  { cntBuy++;  }
            if(type==POSITION_TYPE_SELL) { cntSell++; }
         }//else if(magic==Magic01) {long type01; ...}
         ulong PMagic = PositionGetInteger(POSITION_MAGIC);
      if(Floating > InpCloseAllAt) {   
         if(PMagic == INPMAGIC) {                                 // | Only close positions with INPMAGIC ...   
            if(TRADE.PositionClose(ticket))
               Print("  CloseAll TP Reached> "," @",INPMAGIC," -:- ",__FUNCTION__);
            }       
         }   
      }
      CFLOAT = Floating;                         // | Total Net of positions opened for Inpmagic                                                       
      return true;   
}

   
bool CloseFNS(ulong SymbolLastPOS, ENUM_POSITION_TYPE TYPE, bool PRINT) {      // | double &RESULT, double &VOLUME
   if(PositionSelectByTicket(SymbolLastPOS)) {                       // | Select currently/last opened Position for this Symbol, then reassign SymbolLastPOS with new PId at if(TRADE.open) { SymbolLastPos = TRADE.ResultOrder(); }
      double ClosedAt = PositionGetDouble(POSITION_PROFIT);
      double VOLUME   = PositionGetDouble(POSITION_VOLUME);
      string SYMBOL   = PositionGetString(POSITION_SYMBOL);
      if(PositionGetInteger(POSITION_TYPE) == TYPE && SYMBOL == PAIR) {
         if(UseCFNS) {
            if(TRADE.PositionClose(SymbolLastPOS,MaxSlippage)) {
               ClosedTicketCFNS = TRADE.ResultOrder();               // | Closed position's POSITION_ID
               OutDealCFNS      = TRADE.ResultDeal();                // | Closed position's Out-DealId
            }
            ISNEW_DEAL(__FUNCTION__,true);
         }
      }
      if(PRINT) { Print("  |->Out-DealId |",OutDealCFNS,"| CLOSE_FOR_NEW_SIGNAL |",SymbolLastPOS,"  $(",DoubleToString(ClosedAt,2),") "); }
      return true;
   }
   return false;
}

double Lots_Calc(double LOSTPOINTS, double GAINEDPOINTS, double LOTSFACTOR, LOT_MULTIPLE WEIGHT) {

    double LP=LOSTPOINTS, GP=GAINEDPOINTS, LF=LOTSFACTOR;
    double Calculated_Lots=0, Lots=InpLots;
    double IncFact_LP, IncFact_NetP, IncFact_PDiv;
    double Trade_Lots_NetP, Trade_Lots_LP, Trade_Lots_PDiv;
    // if(LP < 0 || GP < 0) { Calculated_Lots = InpLots; }
      
      if(InpLotMode == LOT_MODE_DYNAMIC) {
      
      double LP_GP = MathAbs(LP-GP);
      double LP_   = MathAbs(LP);
      
         IncFact_LP      = MathAbs(LP / InpIncreasePoints);
         /* if(LP > INCREASEPOINTS) { IncFact_LP =  MathAbs(LP / INCREASEPOINTS);   } else if(LP >= INCREASEPOINTS) { IncFact_LP = MathAbs(LP / (LP-INCREASEPOINTS)); }    // Ex: INCREASEPOINTS = InpStopLoss / 2.5; */
         IncFact_NetP    = MathAbs(LP_GP / InpIncreasePoints); // * MathPow(LOTSFACTOR,LOTSFACTOR);          // Becomes a Larger Value when NetPoints is a Larger Value to either direction
         IncFact_PDiv    = MathAbs(LP / InpPointsDivideBy);
         
         Trade_Lots_NetP = Lots * MathPow(LF,IncFact_NetP); //Lots * (LOTSFACTOR*IncFact_NetP);                 // Calculated as LOTSFACTOR*InpFact_NetP ... this value increases faster as IncFact_NetP increases compared to MathPow(LOTSFACTOR,IncFact_LP) 
         Trade_Lots_LP   = Lots * MathPow(IncFact_LP,LF);            // Calculated as ' LOTSFACTOR*LOTSFACTOR*.../LOTSFACTOR^(IncFact_LP) '  an InpFact_LP Number of times
                Trade_Lots_LP = NormalizeDouble(Trade_Lots_LP,2);
         Trade_Lots_PDiv = Lots * MathPow(LF,IncFact_PDiv);
      
         switch(WEIGHT) {
         
            case(WEIGHT_LOSTPOINTS):    Calculated_Lots = Trade_Lots_LP;
            case(WEIGHT_NETPOINTS):     Calculated_Lots = Trade_Lots_NetP;
            // case(WEIGHT_NETMONEY):   Calculated_Lots = ... ;
            case(P_DIVIDE_LOSTPOINTS):  Calculated_Lots = Trade_Lots_PDiv;
         }
      } else if(InpLotMode == LOT_MODE_FIXED) { 
         Calculated_Lots = Lots; }
                   
   return Calculated_Lots;
}

void Trade_NextPrice(string SYMBOL, ENUM_ORDER_TYPE LASTTYPE, double LASTPRICE, double LASTVOLUME) {
   MqlRates PRICE[];     
   ArraySetAsSeries(PRICE,true);
   MqlTick  TICK;        
   NormalizeDouble(SymbolInfoTick(PAIR,TICK),_digits);
   int PriceData = CopyRates(PAIR,PERIOD_M1,0,100,PRICE);
   
   int N                 = LASTTYPE == ORDER_TYPE_BUY ? 1 : -1;
   static double NextEntryPrice = LASTPRICE-(N*InpReEntryatPoints*_point);
          NextEntryPrice = NormalizeDouble(NextEntryPrice,_digits);
   static double NextEntryLots  = LASTVOLUME*InpReEntryFactor;       
          NextEntryLots  = NormalizeDouble(NextEntryLots,2);
   
   if(Symbol() == SYMBOL)
      // OnePrint("  OrderType/N-> "+IntegerToString(N)+"  NExtPrice- "+DoubleToString(NextEntryPrice,_digits)+"  @"+DoubleToString(NextEntryLots,2)+" -:- "+__FUNCTION__);
      // Print("  OrderType/N-> ",N,"  NExtPrice- ",NextEntryPrice,"  @",NextEntryLots," -:- ",__FUNCTION__);
      
      //if(InpTradeMode == TRADE_MODE_REENTRY) { 
         if(N == 1) { if(TICK.ask <= NextEntryPrice) { 
              TRADE.Buy(NextEntryLots,PAIR); 
             /* Print("  ReEntry-BUY -:- ",__FUNCTION__);*/ }
                  // return true;
         } 
         if(N == -1) { if(TICK.bid >= NextEntryPrice) {
              TRADE.Sell(NextEntryLots,PAIR);
             /* Print("  ReEntry-SELL -:- ",__FUNCTION__);*/ }
                  //return true;
         }
      //}     
     // return false;
}

  
bool Trade_ReEntry() {
   int total = PositionsTotal();
   if(total > 0)
   for( int i=PositionsTotal()-1; i<=0; i-- ) {
      ulong ticket = PositionGetTicket(i);
      PositionSelectByTicket(ticket);
      Print("  OPEN... |",ticket,"|");
      return true;
   }
   return false;
}

void HPos(double &ResultArray[]) {
   int TC=0;

   if(HistorySelect(0,TimeCurrent())) {
      for(int i=HistoryDealsTotal()-1; i>=0; i--) {
         ulong Ticket = HistoryDealGetTicket(i);
         if(HistoryDealSelect(Ticket)) {       
            TC = i;
            ArrayResize(ResultArray,HistoryDealsTotal());
            ArrayPrint(ResultArray,2," | ");
            ResultArray[TC] = HistoryDealGetDouble(Ticket,DEAL_PROFIT);
         }
      }
   }
   
}

void SetBEStop(ulong PT, double BE_AT) {
   MqlTick Tick;
   double NewSL;
   NormalizeDouble(SymbolInfoTick(_Symbol,Tick),_Digits);
 
   if(PositionSelectByTicket(PT)) {                             
      string PSymbol = PositionGetString(POSITION_SYMBOL);                                 // | Select and Obtain neccessary PositionInfo
      double PVolume = PositionGetDouble(POSITION_VOLUME);                                 // |            
      double POPrice = PositionGetDouble(POSITION_PRICE_OPEN);                             // | 
      double PTP     = PositionGetDouble(POSITION_TP);                                     // | 
      double PSL     = PositionGetDouble(POSITION_SL);                                     // | 
      ENUM_POSITION_TYPE PTYPE = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // | ...
      // Breakeven-Stop
      if(PTYPE == POSITION_TYPE_BUY) {
         if(Tick.bid > POPrice + InpBETriggerpoints * _Point) {
            NewSL = POPrice + BE_AT * _Point;
            NormalizeDouble(NewSL,_Digits);
            if(NewSL > PSL && NewSL != PSL) {         // | Check if the NewSL is more closer to CurrentPrice than CurrentPSL ... and check NewSL != PSL to avoid Failed PositionModify attempt- '[no changes]'  
               if(TRADE.PositionModify(PT,NewSL,PTP)) { Print(" ---POSITION_MODIFY |",PT,"| ",NewSL); }             
            }
         }
         // Print(" ---SELECTBYTICKET  SET_BESTOP-> ",PT);
         // Print(" -",PSymbol," | ",EnumToString(PTYPE)," | ",PVolume," | ",POPrice," |> SL_TP ",PSL,"_",PTP);
      } else if(PTYPE == POSITION_TYPE_SELL) {
         if(Tick.ask < POPrice - InpBETriggerpoints * _Point) {
            NewSL = POPrice - BE_AT * _Point;
            NormalizeDouble(NewSL,_Digits);
            if(NewSL < PSL && NewSL != PSL) { 
               if(TRADE.PositionModify(PT,NewSL,PTP)) { Print(" ---POSITION_MODIFY |",PT,"| ",NewSL); } 
            }
         }
         // Print(" ---SELECTBYTICKET  SET_BESTOP-> ",PT);
         // Print(" -",PSymbol," | ",EnumToString(PTYPE)," | ",PVolume," | ",POPrice," |> SL_TP ",PSL,"_",PTP);
      }
      //---------------
   }
// ---   
}

void BreakEven_AT(ulong PT, double BE_AT) {
   // Manage Position state check and Update SL
}

void UpdateSL_() {          // Call in OnTick() function of the programme after Sending orders
   MqlTick TICK;
   NormalizeDouble(SymbolInfoTick(PAIR,TICK),_Digits);
   
   if(InpStopLoss == 0 || !UseTSL) { return; }
   int total = PositionsTotal();
   for(int i=total - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0) { Print("Unable to get ticket"); return; }
      if(!PositionSelectByTicket(ticket)) { Print("Unable to select by ticket"); return; }
      ulong MagicNo;
      if(!PositionGetInteger(POSITION_MAGIC,MagicNo)) { Print("Failed to get position MagicNo"); return; }
      if( BaseMagicN0 == MagicNo ) {
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type)) { Print("Unable to get position type"); return; }
         double CurrentTP, CurrentSL;
         if(!PositionGetDouble(POSITION_TP,CurrentTP)) { Print("Unable to get CurrentTP"); return; }
         if(!PositionGetDouble(POSITION_SL,CurrentSL)) { Print("Unable to get CurrentSL"); return; }
         
         double Currentprice = type==POSITION_TYPE_BUY ? TICK.bid : TICK.ask;
         int N = type==POSITION_TYPE_BUY ? 1 : -1;                                              // The value of this N variable will be used inside the NewSL calc to determine if we should add or subtract the new sl value from the Currentprice value
         double NewSL = NormalizeDouble(Currentprice - ((InpStopLoss*_Point)*N),_Digits);       // Subtract from current price if N=1(BUY) or we add new sl value from current price if N=-1(SELL) 
         
         if((NewSL*N) < (CurrentSL*N) || NormalizeDouble(MathAbs(NewSL-CurrentSL),_Digits) < _Point) {  // | Check if NewSL is significantly different from CurrentSL, and if NewSL is closer to current price than previous stoploss
            //Print("No new Stoploss needed, TO_TIGHT");
            continue;      // Proccess for loop for next position
         }
         long level = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
         if(level!=0 && MathAbs(Currentprice-NewSL)<=level*_Point) {
            Print("NewSL < SYMBOL_TRADE_STOPS_LEVEL");
            continue;
         }
         if(!TRADE.PositionModify(ticket, NewSL, CurrentTP)) { Print(ticket," ->PositionModify(NewSL) Failed!"); return; }
      }
   }
// ----
}

void UpdateSL_BeforeProfit() {

}

//+------------------------------------------------------------------+
// |======================| TRADE,RISK && MONEY MNAGMENT |=======================| +
//+------------------------------------------------------------------+

double PointValue(string SYMBOL, bool PRINT) {

   double point     = SymbolInfoDouble(SYMBOL,SYMBOL_POINT);               // | ==
   double tickSize  = SymbolInfoDouble(SYMBOL,SYMBOL_TRADE_TICK_SIZE);     // | ==
   double tickValue = SymbolInfoDouble(SYMBOL,SYMBOL_TRADE_TICK_VALUE);        
   double ticksPerPoint = tickSize / _point;                  // | Will usually equate to 1, since Ticksize and _Point are the same value across all brokers
   double pointValue    = tickValue / ticksPerPoint;          // | Since Ticksize and _Point are equal, PointValue and TickValue will also always be equal values

   if(PRINT) { PrintFormat( "tickSize=%f, point=%f, tickValue=%f, pointValue=%f, ticksPerPoint=%f, -:-=%f", tickSize, point, tickValue, pointValue, ticksPerPoint, __FUNCTION__); }
   return ( pointValue );
}

double MarginRequired(string SYMBOL, double FOR_VOLUME) {       // | Calculates required margin to open a 1.00Lot position for the specified SYMBOL/ Can be adjusted for desired VOLUME
   double Rate = 0;
   double Price = SymbolInfoDouble(SYMBOL,SYMBOL_ASK);
   ENUM_ORDER_TYPE Type = ORDER_TYPE_BUY;
   if(!OrderCalcMargin(Type,SYMBOL,FOR_VOLUME,Price,Rate)) { return(0.0); }
   return Rate;
}


/*

   //	Situation 1, fixed lots and stop loss points, how much $$ is at risk
   double riskPoints = 75;                                    // | 0.075 for EURJPY, 0.00075 for EURGBP and AUDNZD( _Digits vary for pairs with different profit-currency )
   double riskLots   = 0.60;                                  // | Set LotSize for trade
   double riskAmount = pointValue * riskLots * riskPoints;    // | Risked Amount on the trade with Set Lot&SLdistance ~ riskLots&riskPoints
   PrintFormat( "Risk amount for %s trading %f lots with risk of %f points is %f", symbol, riskLots, riskPoints, riskAmount );
   
   //	Situation 2, fixed lots and risk amount, how many points to set stop loss( SL Distance )
   riskAmount = 100;                                          // | Set Loss amount in $$Money
   riskLots   = 0.60;                                         // | Set LotSize for trade
   riskPoints = riskAmount / ( pointValue * riskLots );       // | SL Disatance to be set to the trade
   PrintFormat( "Risk points for %s trading %f lots placing %f at risk is %f", symbol, riskLots, riskAmount, riskPoints );
    
   //	Situation 3, fixed risk amount and stop loss, how many lots to trade ( Lots for specified Risk Amount in &&Money )
   riskAmount = 100;                                          // | Set Risk Money, in $$Amount
   riskPoints = 50;                                           // | Set SL distance in points
   riskLots   = riskAmount / ( pointValue * riskPoints );     // | Lots to trade that will yield a loss ~ riskAmount at SL distance ~ riskPoints
   riskLots = NormalizeDouble(riskLots,2);
   PrintFormat( "Risk lots for %s value %f and stop loss at %f points is %f", symbol, riskAmount, riskPoints, riskLots );
   
*/

   
double CalcLotsRiskPercent(string SYMBOL, double SLDISTANCE, double RISKPERCENT, double RISKMONEY, bool PRINT) {  // | ( Lots for specified Risked Percentage of AccountBalance )For specified SLpoints & RiskPercent parameter, calculate the lotsize that would be Risked Percentage of AccountBalance 
 
   double pointvalue = PointValue(SYMBOL,false);                               // | Can be used in the place of tickvalue ...
   double point      = SymbolInfoDouble(SYMBOL,SYMBOL_POINT);                  // | Can be used in place of ticksize ...
   double lotStep    = SymbolInfoDouble(SYMBOL,SYMBOL_VOLUME_STEP);
   int    digits     = (int)SymbolInfoInteger(SYMBOL,SYMBOL_DIGITS);
   double riskmoney  = (AccountInfoDouble(ACCOUNT_BALANCE)*RISKPERCENT)/100;
   // if( UseRISKMONEY ) { riskmoney = RISKMONEY; }
   
   double Moneyperlotstep = (SLDISTANCE/point) *pointvalue *lotStep;           // | Risked Money at SLPOINTS per 0.01LOT(lotStep)
   double Lot             = (riskmoney/Moneyperlotstep) *lotStep;              // | MathFloor ...
   
   if(lotmin != 0) { Lot = MathMax(Lot,lotmin); }                    // | Check if calculated lotsize is acceptable on the Broker-server side
   if(lotmax != 0) { Lot = MathMin(Lot,lotmax); }                    // | ...
   Lot = NormalizeDouble(Lot,2);
   Moneyperlotstep = NormalizeDouble(Moneyperlotstep,2);
   
   if(PRINT) { Print(" | (",InpStopLoss,"points-SL @0.01Lot= $",Moneyperlotstep,") -> FOR-",SYMBOL,"(",InpStopLoss,"points-SL) RISK(",riskmoney,"$ or %",RISKPERCENT,") TRADE(",Lot,"Lots) -:- ",__FUNCTION__); }
   return Lot;
}   

 double LotSizeStep    = 0.01;                         // | Alternative Progressive LotSize Calc | LotSizeStep *(AccountBalance()/AmountPerStep) ... LotSizeStep *(AccountBalance() *(AccPercPerStep/100)) 
 double AmountPerStep  = 100;                          // |                                      | Money Amount of Account Balance used per LotSizeStep
 double AccPercPerStep = 0.1;                          // | ...                                  | Percentage of Account Balance used per LotSizeStep    

double CalcLotSizeStep() {
// Lot = LotSizeStep *(accbalance *(AccPercPerStep/100));  
   double Lot = LotSizeStep *(accbalance/AmountPerStep);
   Lot = NormalizeDouble(Lot,2);
   return Lot;
}              


bool TradeReEntry(double FE_PRICE, double FE_VOLUME, double RE_ATPIPS, int RE_MULTIPLE, int MAXENTRIES) {      // | RE_MULTIPLE > 0 for incremental LotSizes on ReEntry Trades
   static double NextEntryPrice=0.0; double NextEntryVolume=0.0;
   MqlRates Rates[];
   
      NextEntryVolume = FE_VOLUME * RE_MULTIPLE;
   
return false;
}

//Expert Settings
 double   FIXLOT            = 0.1;      //if 0, uses maximumrisk, else uses only this while trading
 double   MINLOTS           = 0.1;      //minimum lot
 double   MAXLOTS           = 5;        //maximum lot
 double   MAXIMUMRISK       = 0.05;     //maximum risk, if FIXLOT = 0

 int      FIRSTMULTIPLICATOR   = 4;     //multiply lots when position -1 was loss
 int      SECONDMULTIPLICATOR  = 2;     //multiply lots when position -2 was loss
 int      THIRDMULTIPLICATOR   = 5;     //multiply lots when position -3 was loss
 int      FOURTHMULTIPLICATOR  = 5;     //multiply lots when position -4 was loss
 int      FIFTHMULTIPLICATOR   = 1;     //multiply lots when position -5 was loss


double GetLots()
{
   double lot=0.0;
   if(FIXLOT==0)
      lot=NormalizeDouble(freemargin*MAXIMUMRISK/1000.0,1);
   else
      lot=FIXLOT;

//--- история за последние 7 календарных дней
//--- 60(кол-во секунд в минуте) * 60 (кол-во минут в часе) * 24 (кол-во часов в сутках) * 7 (семь дней)
   datetime from_date=TimeCurrent()-60*60*24*7;
   datetime to_date=TimeCurrent()+60*60*24;

   HistorySelect(from_date,to_date);
   for(int i=HistoryDealsTotal()-1;i>=0;i--)                                  // | Returns the number of history deals
      if(m_deal.SelectByIndex(i))                                             // | Selects the history deal by index for further access to its properties
         if(m_deal.Symbol()==SYMBOLI.Name() && m_deal.Magic()==BaseMagicN0)   // | Check for Deal Symbol and Magic, Pass as arguments
            if(m_deal.Entry()==DEAL_ENTRY_OUT)
              {
               static int count=1;
               if(m_deal.Profit()>0)
                  break;
               if(m_deal.Profit()<0)
                 {
                  if(count==1)
                     lot*=FIRSTMULTIPLICATOR;
                  if(count==2)
                     lot*=SECONDMULTIPLICATOR;
                  if(count==3)
                     lot*=THIRDMULTIPLICATOR;
                  if(count==4)
                     lot*=FOURTHMULTIPLICATOR;
                  if(count==5)
                    {
                     lot*=FIFTHMULTIPLICATOR;
                     break;
                    }
                 }
               count++;
              }

   if(lot>NormalizeDouble(freemargin/1000.0,1))
      lot=NormalizeDouble(freemargin/1000.0,1);

   if(lot<MINLOTS)
      lot=MINLOTS;
   else if(lot>MAXLOTS)
      lot=MAXLOTS;

   return(lot);
}