  
 #include <Trade\Trade.mqh>
 
 class CHASmoothedStrategy : public CObject {
 private:
   
   //inptus
   string Pair;
   ENUM_TIMEFRAMES TimeFrame;
   
   double Lots;
   int TPpoints, SLpoints;
   int TslTriggerpoints, Tslpoints;
   long MagicNumber;
   int Deviation;
   //Indicator
   int HAmaperiod;
   ENUM_MA_METHOD HAmamethod;
   int HAstepsize;
   int Handle;
   string IndiPath;
   int Handle_G;
   string HAsmoothed;
   
   int barsTotal;
   CTrade Trade;
   MqlTick Tick;
   MqlDateTime DTime;
   
public:

      // Parametric Constructor
      CHASmoothedStrategy(string pair, ENUM_TIMEFRAMES timeframe, double lots,  int tpPoints, int slPoints, int tsltriggerpoints, int tslPoints, int hamaPeriod, ENUM_MA_METHOD hamamethod, int hastep, string Path, long magicNo, int deviation) {
         Pair      = pair;
         TimeFrame = timeframe;
         
         Lots     = lots;
         TPpoints = tpPoints;
         SLpoints = slPoints;
         TslTriggerpoints = tsltriggerpoints;
         Tslpoints   = tslPoints;
         MagicNumber = magicNo;
         Deviation   = deviation;
         
         IndiPath   = Path;
         HAmaperiod = hamaPeriod;
         HAmamethod = hamamethod;
         HAstepsize = hastep;
         HAsmoothed = "Heiken Ashi Smoothed";
      }
      // Default constructor
      CHASmoothedStrategy();
      //---
      void OnTickEvent();
      void OnTickEvent_M();                  //Martingale Incorporated
      void OnTickEvent_R();                  //Randomized
      void OnTickEvent_I();                  //Index Counter && Filtering
      datetime lastsignal;
      
      //--- Positions ---------
      bool CountOpenPositions(int &cntBUY,int &cntSELL,string PAIR);
      bool CloseOpenPositions(int all_buy_sell,string PAIR);
      bool CountTProfit(int DAYSBACK,string PAIR);    // bool CountProfit(int DAYSBACK, ENUM_ORDER_TYPE TYPE, string PAIR/int MAGIC); to count buy and sell position results separatly
      
      //--- Signals&&Orders ---
      bool CheckSignal();
      bool MTFSignalState();
      bool ComputeMLots(string PAIR,double MFACTOR,double &MLots);
      void UpdateLostPoints();
      
      
protected:
   void showError(string msg, int ercode);   //function for use to display error messages

public:
   int OnInitEvent() {
      //if(!Handle!=iCustom(Pair,TimeFrame,IndiPath,HAmaperiod,HAmamethod,HAstepsize) ) { Print(__FUNCTION__,"-> Indicator Handle ", Pair); }
      Handle = iCustom(Pair,TimeFrame,IndiPath,HAmaperiod,HAmamethod,HAstepsize);
      Handle_G = iCustom(Pair,TimeFrame,HAsmoothed);
      
      Trade.SetExpertMagicNumber(MagicNumber);                                         //Identify strategies independently via various MagicNumbers(~ FxBlue Analizer)
      Trade.SetDeviationInPoints(Deviation);
   
      return (INIT_SUCCEEDED);
   }
   //---
   
   void OnDeinitEvent (const int reason) {

   }
   //---
   
};

// ----------------------------------------------------------------------------------------------------------+
//          MEMBER FUNCTIONS CONSTRUCTION                                                                    +
// ----------------------------------------------------------------------------------------------------------+

void CHASmoothedStrategy::OnTickEvent(void) {
      
      int bars = iBars(Pair,TimeFrame);
      if(barsTotal != bars) {
         barsTotal = bars;
         
         //Normalize values to Pair argumment, beneficial when using this function on multiple instances of different symbol digit types
         double _point = SymbolInfoDouble(Pair,SYMBOL_POINT);
         int _digits = (int)SymbolInfoInteger(Pair,SYMBOL_DIGITS);
         
         double ticksize = SymbolInfoDouble(Pair,SYMBOL_TRADE_TICK_SIZE);
         double tickvalue = SymbolInfoDouble(Pair,SYMBOL_TRADE_TICK_VALUE);
         
         string Spread = "Spread> "+IntegerToString( int (SymbolInfoInteger(Pair, SYMBOL_SPREAD)),_digits);
         double AccEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         double UsedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
         double FreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         NormalizeDouble(SymbolInfoTick(Pair,Tick),_digits);

         //-------------------- FOR HA ALERTS.EX5 ----------------------------------------------------------+
         
         double Bbuy[], Bsell[];
         CopyBuffer(Handle,0,1,1,Bsell);
         CopyBuffer(Handle,1,1,1,Bbuy);
         if(ArraySize(Bbuy) > 0 && Bbuy[0] != EMPTY_VALUE && Bbuy[0] != 0) {
            //buy signal
            //Normalize for Buy
            double sl = Tick.ask - SLpoints * _point;
            double tp = Tick.ask + TPpoints * _point;
            NormalizeDouble(sl,_digits);
            NormalizeDouble(tp,_digits);
            Trade.Buy(Lots,Pair,Tick.ask,sl,tp,Spread);
         }
         if(ArraySize(Bsell) > 0 && Bsell[0] != EMPTY_VALUE && Bsell[0] != 0) {
            //sell signal
            //Normalize for Sell
            double sl = Tick.bid + SLpoints * _point;
            double tp = Tick.bid - TPpoints * _point;
            NormalizeDouble(sl,_digits);
            NormalizeDouble(tp,_digits);
            Trade.Sell(Lots,Pair,Tick.bid,sl,tp,Spread);
         }
         
         //-------------------------------------------------------------------------------------------------+
         //------------------- FOR HA-SMOOTHED && RELATED --------------------------------------------------+ 
         double HAopen[], HAhigh[], HAlow[], HAclose[];
         CopyBuffer(Handle_G,0,0,3,HAopen);
         CopyBuffer(Handle_G,1,0,3,HAhigh);
         CopyBuffer(Handle_G,2,0,3,HAlow);
         CopyBuffer(Handle_G,3,0,3,HAclose);
         
         double Copen, Chigh, Clow, Cclose, Popen, Phigh, Plow, Pclose;
         Copen = HAopen[0];      Popen = HAopen[1];
         Chigh = HAhigh[0];      Phigh = HAhigh[1];
         Clow = HAlow[0];        Plow = HAlow[1];
         Cclose = HAclose[0];    Pclose = HAclose[1];
         
         
         
         //-------------------------------------------------------------------------------------------------+
         
         //Daily-Bias and where is currentTick at ( bid > PrevdayH/L, ...)
         double LastOpen = iOpen(Pair,PERIOD_D1,1);
         double LastClose = iClose(Pair,PERIOD_D1,1);
         //if(){} 
         

      
      }
      
// ---      
}   

// ----------------------------------------------------------------------------------------------------------+

void CHASmoothedStrategy::OnTickEvent_M(void) {

      int bars = iBars(Pair,TimeFrame);
      if(barsTotal != bars) {
         barsTotal = bars;
         
         //Normalize values to Pair argumment, beneficial when using this function on multiple instances of different symbol digit types
         double _point = SymbolInfoDouble(Pair,SYMBOL_POINT);
         int _digits = (int)SymbolInfoInteger(Pair,SYMBOL_DIGITS);
         
         double ticksize = SymbolInfoDouble(Pair,SYMBOL_TRADE_TICK_SIZE);
         double tickvalue = SymbolInfoDouble(Pair,SYMBOL_TRADE_TICK_VALUE);
         
         string Spread = "Spread> "+IntegerToString( int (SymbolInfoInteger(Pair, SYMBOL_SPREAD)),_digits);
         double AccEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         double UsedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
         double FreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         NormalizeDouble(SymbolInfoTick(Pair,Tick),_digits);

         //-------------------- FOR HA ALERTS.EX5 ----------------------------------------------------------+
         
         double Bbuy[], Bsell[];
         CopyBuffer(Handle,0,1,1,Bsell);
         CopyBuffer(Handle,1,1,1,Bbuy);
         if(ArraySize(Bbuy) > 0 && Bbuy[0] != EMPTY_VALUE && Bbuy[0] != 0) {
            //buy signal
            //Normalize for Buy
            double sl = Tick.ask - SLpoints * _point;
            double tp = Tick.ask + TPpoints * _point;
            NormalizeDouble(sl,_digits);
            NormalizeDouble(tp,_digits);
            double TradeLots = 0;
            if(!ComputeMLots(Pair,1.25,TradeLots)) { return; }
            Trade.Buy(TradeLots,Pair,Tick.ask,sl,tp,Spread);
         }
         if(ArraySize(Bsell) > 0 && Bsell[0] != EMPTY_VALUE && Bsell[0] != 0) {
            //sell signal
            //Normalize for Sell
            double sl = Tick.bid + SLpoints * _point;
            double tp = Tick.bid - TPpoints * _point;
            NormalizeDouble(sl,_digits);
            NormalizeDouble(tp,_digits);
            double TradeLots = 0;
            if(!ComputeMLots(Pair,1.25,TradeLots)) { return; }
            Trade.Sell(TradeLots,Pair,Tick.bid,sl,tp,Spread);
         }
      }   
         
// ---
}

// ----------------------------------------------------------------------------------------------------------+

void CHASmoothedStrategy::OnTickEvent_I(void) {       
         int indexcurrent = -1, indexlast = -1;
         for( int i = 0; i < 1000; i++) {
            double indired[];
            CopyBuffer(Handle,0,i,1,indired);
            
            double indigreen[];
            CopyBuffer(Handle,1,i,1,indigreen);
            
            if(ArraySize(indigreen) > 0 && indigreen[0] != EMPTY_VALUE && indigreen[0] != 0 || ArraySize(indired) > 0 && indired[0] != EMPTY_VALUE && indired[0] != 0) {
               if(indexcurrent < 0) {
                  indexcurrent = i;
               }else {
                  indexlast = i;
                  
                  datetime time = iTime(Pair,TimeFrame,i);
                  if(time > lastsignal) {
                     if(indigreen[0] > 0) {              // Check for Buy and open trade
                     
                     }else if(indired[0] > 0) {          // Check for Sell and open trade
                     
                     
                     }
                  }
                  lastsignal = time;
                  
                  break;   
               }   
            }
         }
         Comment("\nIndex Current: ", indexcurrent,
                  "\nIndex Last: ", indexlast,
                  "\nLast Signal: ", lastsignal,
                  "\nDIFF- ", (indexcurrent - indexlast) );        // The initial value of indexlast at the point of indexcurrent[0]
                  //Last Difference value. When updating indexcurrent & indexlast with new signal, store last value of indexcurrent inside a variable
                  //This value is the proximity between the last two signals, indicating if they occured in close succesion of each other or not
                  
// ---                  
}

// ----------------------------------------------------------------------------------------------------------+

bool CHASmoothedStrategy::ComputeMLots(string PAIR,double MFACTOR,double &MLots) {           
            MLots = 0;
            double TodayRez = 0;
            
            TimeToStruct(TimeCurrent(),DTime);
            datetime CHour = DTime.hour;
            datetime Today = iTime(_Symbol,PERIOD_D1,0);

            if(HistorySelect(Today,TimeCurrent())) {                               // Select HistoryDeals for DaysBack(Daily-OpenTime) value
               int HTotal = HistoryDealsTotal();                                   // Selct all within the TimePeriod
               for( int i = HTotal-1; i>=0; i--) {
                  ulong HDTicket = HistoryDealGetTicket(i);                        // Select by ticket
                  if(HistoryDealSelect(HDTicket)) {
                     if(HistoryDealGetString(HDTicket,DEAL_SYMBOL) == PAIR) {
                        if(HistoryDealGetInteger(HDTicket,DEAL_ENTRY) == DEAL_ENTRY_OUT) { 
                           double HDResults;
                           double HDVolume;
                           if(HistoryDealGetDouble(HDTicket,DEAL_PROFIT,HDResults)) {     // Fill DEAL_PROFIT values to HDResults variable
                              TodayRez += HDResults;
                              if(HDResults <= 0) {
                                 HDVolume = HistoryDealGetDouble(HDTicket,DEAL_VOLUME);
                                 double Nlot = HDVolume*MFACTOR;
                                 MLots = (Nlot < HDVolume*1.2) ? Nlot*1.25 : Nlot;
                              }
                           }
                           // ...
                           Print("HDTICKET->", HDTicket, " RESULTS+ ", DoubleToString(TodayRez));
                        }
                     }
                  }     
               }
               Print(TodayRez);
            }
            return true;
// ---
}

// ----------------------------------------------------------------------------------------------------------+



















// ----------------------------------------------------------------------------------------------------------+

//class CMAonHAS : private CHASmoothedStrategy {
   




//};

//--------------------------------------------------------------------------------+

//class CExtender_HAS : protected CHASmoothedStrategy {                           //Extend trades holding time if entry allignes with higher timeframe trend/trend shifts. Hopefully, smaller timeframes provide sniper entries, higher timeframes provide higher pip targets !!




//};

//--------------------------------------------------------------------------------+

//class CHAS_OMS_GRIDMARTINGALE : public CSIGNAL {                               //Order management intaking signals that puts into practice Grid and Mertingale



//};

//--------------------------------------------------------------------------------+

void CHASmoothedStrategy::showError(string msg,int ercode)       //Performs Alert() function with input parameters as string messege and int errorcode
{
   Alert(msg,"-error:",ercode,"!!");
}

