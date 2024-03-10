//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

// This Portfolio Expert works in MetaTrader 5 hedging accounts.
// It opens separate positions for each strategy.
// Every position has an unique magic number, which corresponds to the index of the strategy.

#property strict

static input double Entry_Amount       =    0.01; // Entry lots
static input int    Base_Magic_Number  =     100; // Base Magic Number

static input string ___Options_______  = "-----"; // --- Options ---
static input int    Max_Open_Positions =     100; // Max Open Positions

#define TRADE_RETRY_COUNT 4
#define TRADE_RETRY_WAIT  100
#define OP_FLAT           -1
#define OP_BUY            ORDER_TYPE_BUY
#define OP_SELL           ORDER_TYPE_SELL

// Session time is set in seconds from 00:00
const int sessionSundayOpen           =     0; // 00:00
const int sessionSundayClose          = 86400; // 24:00
const int sessionMondayThursdayOpen   =     0; // 00:00
const int sessionMondayThursdayClose  = 86400; // 24:00
const int sessionFridayOpen           =     0; // 00:00
const int sessionFridayClose          = 86400; // 24:00
const bool sessionIgnoreSunday        = false;
const bool sessionCloseAtSessionClose = false;
const bool sessionCloseAtFridayClose  = false;

const int    strategiesCount = 10;
const double sigma        = 0.000001;
const int    requiredBars = 93;

datetime barTime;
double   stopLevel;
double   pip;
bool     setProtectionSeparately = false;
ENUM_ORDER_TYPE_FILLING orderFillingType = ORDER_FILLING_FOK;
int indHandlers[10][12][2];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum OrderScope
  {
   ORDER_SCOPE_UNDEFINED,
   ORDER_SCOPE_ENTRY,
   ORDER_SCOPE_EXIT
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum OrderDirection
  {
   ORDER_DIRECTION_NONE,
   ORDER_DIRECTION_BUY,
   ORDER_DIRECTION_SELL,
   ORDER_DIRECTION_BOTH
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct Position
  {
   int               Type;
   ulong             Ticket;
   int               MagicNumber;
   double            Lots;
   double            Price;
   double            StopLoss;
   double            TakeProfit;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct Signal
  {
   int               MagicNumber;
   OrderScope        Scope;
   OrderDirection    Direction;
   int               StopLossPips;
   int               TakeProfitPips;
   bool              IsTrailingStop;
   bool              OppositeReverse;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   barTime   = Time(0);
   stopLevel = (int) SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   pip       = GetPipValue();

   InitIndicatorHandlers();

   return ValidateInit();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(IsForceSessionClose())
     {
      CloseAllPositions();
      return;
     }

   datetime time = Time(0);
   if(time > barTime)
     {
      barTime = time;
      OnBar();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnBar()
  {
   if(IsOutOfSession())
      return;

   Signal signalList[];
   SetSignals(signalList);
   int signalsCount = ArraySize(signalList);

   for(int i = 0; i < signalsCount; i++)
      ManageSignal(signalList[i]);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageSignal(Signal &signal)
  {
   Position position = CreatePosition(signal.MagicNumber);

   if(position.Type != OP_FLAT && signal.Scope == ORDER_SCOPE_EXIT)
     {
      if((signal.Direction == ORDER_DIRECTION_BOTH) ||
         (position.Type == OP_BUY  && signal.Direction == ORDER_DIRECTION_SELL) ||
         (position.Type == OP_SELL && signal.Direction == ORDER_DIRECTION_BUY))
        {
         ClosePosition(position);
         return;
        }

      if(signal.IsTrailingStop)
        {
         double trailingStop = GetTrailingStopPrice(position, signal.StopLossPips);
         ManageTrailingStop(position, trailingStop);
        }
     }

   if(position.Type != OP_FLAT && signal.OppositeReverse)
     {
      if((position.Type == OP_BUY  && signal.Direction == ORDER_DIRECTION_SELL) ||
         (position.Type == OP_SELL && signal.Direction == ORDER_DIRECTION_BUY))
        {
         ClosePosition(position);
         ManageSignal(signal);
         return;
        }
     }

   if(position.Type == OP_FLAT && signal.Scope == ORDER_SCOPE_ENTRY)
     {
      if(signal.Direction == ORDER_DIRECTION_BUY || signal.Direction == ORDER_DIRECTION_SELL)
        {
         if(CountPositions() < Max_Open_Positions)
            OpenPosition(signal);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountPositions()
  {
   int minMagic = GetMagicNumber(0);
   int maxMagic = GetMagicNumber(strategiesCount);
   int posTotal = PositionsTotal();
   int count    = 0;

   for(int posIndex = 0; posIndex < posTotal; posIndex++)
     {
      ulong ticket = PositionGetTicket(posIndex);
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
         long magicNumber = PositionGetInteger(POSITION_MAGIC);
         if(magicNumber >= minMagic && magicNumber <= maxMagic)
            count++;
        }
     }

   return count;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Position CreatePosition(int magicNumber)
  {
   Position position;
   position.MagicNumber = magicNumber;
   position.Type        = OP_FLAT;
   position.Ticket      = 0;
   position.Lots        = 0;
   position.Price       = 0;
   position.StopLoss    = 0;
   position.TakeProfit  = 0;

   int posTotal = PositionsTotal();
   for(int posIndex = 0; posIndex < posTotal; posIndex++)
     {
      ulong ticket = PositionGetTicket(posIndex);
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == magicNumber)
        {
         position.Type       = (int) PositionGetInteger(POSITION_TYPE);
         position.Ticket     = ticket;
         position.Lots       = NormalizeDouble(PositionGetDouble(POSITION_VOLUME),           2);
         position.Price      = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
         position.StopLoss   = NormalizeDouble(PositionGetDouble(POSITION_SL),         _Digits);
         position.TakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP),         _Digits);
         break;
        }
     }

   return position;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal CreateEntrySignal(int strategyIndex, bool canOpenLong,    bool canOpenShort,
                         int stopLossPips,  int  takeProfitPips, bool isTrailingStop,
                         bool oppositeReverse = false)
  {
   Signal signal;

   signal.MagicNumber     = GetMagicNumber(strategyIndex);
   signal.Scope           = ORDER_SCOPE_ENTRY;
   signal.StopLossPips    = stopLossPips;
   signal.TakeProfitPips  = takeProfitPips;
   signal.IsTrailingStop  = isTrailingStop;
   signal.OppositeReverse = oppositeReverse;
   signal.Direction       = canOpenLong && canOpenShort ? ORDER_DIRECTION_BOTH
                            : canOpenLong  ? ORDER_DIRECTION_BUY
                            : canOpenShort ? ORDER_DIRECTION_SELL
                            : ORDER_DIRECTION_NONE;

   return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal CreateExitSignal(int strategyIndex, bool canCloseLong,   bool canCloseShorts,
                        int stopLossPips,  int  takeProfitPips, bool isTrailingStop)
  {
   Signal signal;

   signal.MagicNumber     = GetMagicNumber(strategyIndex);
   signal.Scope           = ORDER_SCOPE_EXIT;
   signal.StopLossPips    = stopLossPips;
   signal.TakeProfitPips  = takeProfitPips;
   signal.IsTrailingStop  = isTrailingStop;
   signal.OppositeReverse = false;
   signal.Direction       = canCloseLong && canCloseShorts ? ORDER_DIRECTION_BOTH
                            : canCloseLong   ? ORDER_DIRECTION_SELL
                            : canCloseShorts ? ORDER_DIRECTION_BUY
                            : ORDER_DIRECTION_NONE;

   return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenPosition(Signal &signal)
  {
   int    command    = OrderDirectionToCommand(signal.Direction);
   double stopLoss   = GetStopLossPrice(command,   signal.StopLossPips);
   double takeProfit = GetTakeProfitPrice(command, signal.TakeProfitPips);
   ManageOrderSend(command, Entry_Amount, stopLoss, takeProfit, 0, signal.MagicNumber);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePosition(Position &position)
  {
   int command = position.Type == OP_BUY ? OP_SELL : OP_BUY;
   ManageOrderSend(command, position.Lots, 0, 0, position.Ticket, position.MagicNumber);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i = 0; i < strategiesCount; i++)
     {
      int magicNumber = GetMagicNumber(i);
      Position position = CreatePosition(magicNumber);

      if(position.Type == OP_BUY || position.Type == OP_SELL)
         ClosePosition(position);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOrderSend(int command, double lots, double stopLoss, double takeProfit, ulong ticket, int magicNumber)
  {
   for(int attempt = 0; attempt < TRADE_RETRY_COUNT; attempt++)
     {
      if(IsTradeContextFree())
        {
         MqlTradeRequest request;
         MqlTradeResult  result;
         ZeroMemory(request);
         ZeroMemory(result);

         request.action       = TRADE_ACTION_DEAL;
         request.symbol       = _Symbol;
         request.volume       = lots;
         request.type         = command == OP_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         request.price        = command == OP_BUY ? Ask() : Bid();
         request.type_filling = orderFillingType;
         request.deviation    = 10;
         request.sl           = stopLoss;
         request.tp           = takeProfit;
         request.magic        = magicNumber;
         request.position     = ticket;
         request.comment      = IntegerToString(magicNumber);

         bool isOrderCheck = CheckOrder(request);
         bool isOrderSend  = false;

         if(isOrderCheck)
           {
            ResetLastError();
            isOrderSend = OrderSend(request, result);
           }

         if(isOrderCheck && isOrderSend && result.retcode == TRADE_RETCODE_DONE)
            return;
        }

      Sleep(TRADE_RETRY_WAIT);
      Print("Order Send retry no: " + IntegerToString(attempt + 2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyPosition(double stopLoss, double takeProfit, ulong ticket, int magicNumber)
  {
   for(int attempt = 0; attempt < TRADE_RETRY_COUNT; attempt++)
     {
      if(IsTradeContextFree())
        {
         MqlTradeRequest request;
         MqlTradeResult  result;
         ZeroMemory(request);
         ZeroMemory(result);

         request.action   = TRADE_ACTION_SLTP;
         request.symbol   = _Symbol;
         request.sl       = stopLoss;
         request.tp       = takeProfit;
         request.magic    = magicNumber;
         request.position = ticket;
         request.comment  = IntegerToString(magicNumber);

         bool isOrderCheck = CheckOrder(request);
         bool isOrderSend  = false;

         if(isOrderCheck)
           {
            ResetLastError();
            isOrderSend = OrderSend(request, result);
           }

         if(isOrderCheck && isOrderSend && result.retcode == TRADE_RETCODE_DONE)
            return;
        }

      Sleep(TRADE_RETRY_WAIT);
      Print("Order Send retry no: " + IntegerToString(attempt + 2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckOrder(MqlTradeRequest &request)
  {
   MqlTradeCheckResult check;
   ZeroMemory(check);
   ResetLastError();

   if(OrderCheck(request, check))
      return true;

   Print("Error with OrderCheck: " + check.comment);

   if(check.retcode == TRADE_RETCODE_INVALID_FILL)
     {
      switch(orderFillingType)
        {
         case ORDER_FILLING_FOK:
            Print("Filling mode changed to: ORDER_FILLING_IOC");
            orderFillingType = ORDER_FILLING_IOC;
            break;
         case ORDER_FILLING_IOC:
            Print("Filling mode changed to: ORDER_FILLING_RETURN");
            orderFillingType = ORDER_FILLING_RETURN;
            break;
         case ORDER_FILLING_RETURN:
            Print("Filling mode changed to: ORDER_FILLING_FOK");
            orderFillingType = ORDER_FILLING_FOK;
            break;
        }

      request.type_filling = orderFillingType;

      return CheckOrder(request);
     }

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStopLossPrice(int command, int stopLossPips)
  {
   if(stopLossPips == 0)
      return 0;

   double delta    = MathMax(pip * stopLossPips, _Point * stopLevel);
   double stopLoss = command == OP_BUY ? Bid() - delta : Ask() + delta;

   return NormalizeDouble(stopLoss, _Digits);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTakeProfitPrice(int command, int takeProfitPips)
  {
   if(takeProfitPips == 0)
      return 0;

   double delta      = MathMax(pip * takeProfitPips, _Point * stopLevel);
   double takeProfit = command == OP_BUY ? Bid() + delta : Ask() - delta;

   return NormalizeDouble(takeProfit, _Digits);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTrailingStopPrice(Position &position, int stopLoss)
  {
   double bid = Bid();
   double ask = Ask();
   double spread = ask - bid;
   double stopLevelPoints = _Point * stopLevel;
   double stopLossPoints  = pip * stopLoss;

   if(position.Type == OP_BUY)
     {
      double newStopLoss = High(1) - stopLossPoints;
      if(position.StopLoss <= newStopLoss - pip)
         return newStopLoss < bid
                ? newStopLoss >= bid - stopLevelPoints
                ? bid - stopLevelPoints
                : newStopLoss
                : bid;
     }

   if(position.Type == OP_SELL)
     {
      double newStopLoss = Low(1) + spread + stopLossPoints;
      if(position.StopLoss >= newStopLoss + pip)
         return newStopLoss > ask
                ? newStopLoss <= ask + stopLevelPoints
                ? ask + stopLevelPoints
                : newStopLoss
                : ask;
     }

   return position.StopLoss;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageTrailingStop(Position &position, double trailingStop)
  {
   if((position.Type == OP_BUY  && MathAbs(trailingStop - Bid()) < _Point) ||
      (position.Type == OP_SELL && MathAbs(trailingStop - Ask()) < _Point))
     {
      ClosePosition(position);
      return;
     }

   if(MathAbs(trailingStop - position.StopLoss) > _Point)
     {
      position.StopLoss = NormalizeDouble(trailingStop, _Digits);
      ModifyPosition(position.StopLoss, position.TakeProfit, position.Ticket, position.MagicNumber);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeContextFree()
  {
   if(IsTradeAllowed())
      return true;

   uint startWait = GetTickCount();
   Print("Trade context is busy! Waiting...");

   while(true)
     {
      if(IsStopped())
         return false;

      uint diff = GetTickCount() - startWait;
      if(diff > 30 * 1000)
        {
         Print("The waiting limit exceeded!");
         return false;
        }

      if(IsTradeAllowed())
        {
         RefreshRates();
         return true;
        }

      Sleep(TRADE_RETRY_WAIT);
     }

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOutOfSession()
  {
   int dayOfWeek    = DayOfWeek();
   int periodStart  = int(Time(0) % 86400);
   int periodLength = PeriodSeconds(_Period);
   int periodFix    = periodStart + (sessionCloseAtSessionClose ? periodLength : 0);
   int friBarFix    = periodStart + (sessionCloseAtFridayClose || sessionCloseAtSessionClose ? periodLength : 0);

   return dayOfWeek == 0 && sessionIgnoreSunday ? true
          : dayOfWeek == 0 ? periodStart < sessionSundayOpen         || periodFix > sessionSundayClose
          : dayOfWeek  < 5 ? periodStart < sessionMondayThursdayOpen || periodFix > sessionMondayThursdayClose
          : periodStart < sessionFridayOpen         || friBarFix > sessionFridayClose;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsForceSessionClose()
  {
   if(!sessionCloseAtFridayClose && !sessionCloseAtSessionClose)
      return false;

   int dayOfWeek = DayOfWeek();
   int periodEnd = int(Time(0) % 86400) + PeriodSeconds(_Period);

   return dayOfWeek == 0 && sessionCloseAtSessionClose ? periodEnd > sessionSundayClose
          : dayOfWeek  < 5 && sessionCloseAtSessionClose ? periodEnd > sessionMondayThursdayClose
          : dayOfWeek == 5 ? periodEnd > sessionFridayClose : false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Bid()
  {
   return SymbolInfoDouble(_Symbol, SYMBOL_BID);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Ask()
  {
   return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime Time(int bar)
  {
   datetime buffer[];
   ArrayResize(buffer, 1);
   return CopyTime(_Symbol, _Period, bar, 1, buffer) == 1 ? buffer[0] : 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Open(int bar)
  {
   double buffer[];
   ArrayResize(buffer, 1);
   return CopyOpen(_Symbol, _Period, bar, 1, buffer) == 1 ? buffer[0] : 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double High(int bar)
  {
   double buffer[];
   ArrayResize(buffer, 1);
   return CopyHigh(_Symbol, _Period, bar, 1, buffer) == 1 ? buffer[0] : 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Low(int bar)
  {
   double buffer[];
   ArrayResize(buffer, 1);
   return CopyLow(_Symbol, _Period, bar, 1, buffer) == 1 ? buffer[0] : 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Close(int bar)
  {
   double buffer[];
   ArrayResize(buffer, 1);
   return CopyClose(_Symbol, _Period, bar, 1, buffer) == 1 ? buffer[0] : 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetPipValue()
  {
   return _Digits == 4 || _Digits == 5 ? 0.0001
          : _Digits == 2 || _Digits == 3 ? 0.01
          : _Digits == 1 ? 0.1 : 1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
  {
   return (bool) MQL5InfoInteger(MQL5_TRADE_ALLOWED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RefreshRates()
  {
// Dummy function to make it compatible with MQL4
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int DayOfWeek()
  {
   MqlDateTime mqlTime;
   TimeToStruct(Time(0), mqlTime);
   return mqlTime.day_of_week;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetMagicNumber(int strategyIndex)
  {
   return 1000 * Base_Magic_Number + strategyIndex;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OrderDirectionToCommand(OrderDirection dir)
  {
   return dir == ORDER_DIRECTION_BUY  ? OP_BUY
          : dir == ORDER_DIRECTION_SELL ? OP_SELL
          : OP_FLAT;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_INIT_RETCODE ValidateInit()
  {
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitIndicatorHandlers()
  {
   TesterHideIndicators(true);
// Moving Average (Simple, Close, 14, 0)
   indHandlers[0][0][0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// Williams' Percent Range (9), Level: -95.0
   indHandlers[0][1][0] = iWPR(NULL, 0, 9);
// Commodity Channel Index (Typical, 39)
   indHandlers[0][2][0] = iCCI(NULL, 0, 39, PRICE_TYPICAL);
// RSI (Close, 10), Level: 0
   indHandlers[0][3][0] = iRSI(NULL, 0, 10, PRICE_CLOSE);
// Moving Average (Simple, Close, 14, 0)
   indHandlers[1][0][0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// DeMarker (5)
   indHandlers[1][1][0] = iDeMarker(NULL, 0, 5);
// Alligator (Smoothed, Median, 37, 16, 16, 7, 7, 3)
   indHandlers[1][2][0] = iAlligator(NULL, 0, 37, 16, 16, 7, 7, 3, MODE_SMMA, PRICE_MEDIAN);
// DeMarker (34)
   indHandlers[1][3][0] = iDeMarker(NULL, 0, 34);
// Commodity Channel Index (Typical, 32), Level: 367
   indHandlers[1][4][0] = iCCI(NULL, 0, 32, PRICE_TYPICAL);
// Moving Average (Simple, Close, 14, 0)
   indHandlers[2][0][0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// Commodity Channel Index (Typical, 6)
   indHandlers[2][1][0] = iCCI(NULL, 0, 6, PRICE_TYPICAL);
// Directional Indicators (15)
   indHandlers[2][2][0] = iADX(NULL, 0, 15);
// Bollinger Bands (Close, 5, 3.22)
   indHandlers[2][3][0] = iBands(NULL, 0, 5, 0, 3.22, PRICE_CLOSE);
// Moving Average (Simple, Close, 14, 0)
   indHandlers[3][0][0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// Stochastic (15, 7, 9)
   indHandlers[3][1][0] = iStochastic(NULL, 0, 15, 7, 9, MODE_SMA, 0);
// Envelopes (Close, Simple, 40, 0.44)
   indHandlers[3][2][0] = iEnvelopes(NULL, 0, 40, 0, MODE_SMA, PRICE_CLOSE, 0.44);
// Moving Average (Simple, Close, 14, 0)
   indHandlers[4][0][0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// Moving Average (Simple, Close, 9, 0)
   indHandlers[4][1][0] = iMA(NULL, 0, 9, 0, MODE_SMA, PRICE_CLOSE);
// Stochastic Signal (17, 15, 9)
   indHandlers[4][2][0] = iStochastic(NULL, 0, 17, 15, 9, MODE_SMA, STO_LOWHIGH);
// Envelopes (Close, Simple, 49, 0.44)
   indHandlers[4][3][0] = iEnvelopes(NULL, 0, 49, 0, MODE_SMA, PRICE_CLOSE, 0.44);
// Moving Average (Simple, Close, 14, 0)
   indHandlers[5][0][0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// ADX (45)
   indHandlers[5][1][0] = iADX(NULL, 0, 45);
// Standard Deviation (Close, Simple, 49)
   indHandlers[5][2][0] = iStdDev(NULL, 0, 49, 0, MODE_SMA, PRICE_CLOSE);
// Alligator (Smoothed, Median, 32, 13, 13, 9, 9, 2)
   indHandlers[5][3][0] = iAlligator(NULL, 0, 32, 13, 13, 9, 9, 2, MODE_SMMA, PRICE_MEDIAN);
// Moving Average (Simple, Close, 14, 0)
   indHandlers[6][0][0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// Stochastic (2, 2, 2)
   indHandlers[6][1][0] = iStochastic(NULL, 0, 2, 2, 2, MODE_SMA, 0);
// Accelerator Oscillator
   indHandlers[6][2][0] = iAC(NULL, 0);
// ADX (41), Level: 38.0
   indHandlers[6][3][0] = iADX(NULL, 0, 41);
// Average True Range (18), Level: 0.0032
   indHandlers[6][4][0] = iATR(NULL, 0, 18);
// Moving Average (Simple, Close, 14, 0)
   indHandlers[7][0][0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// Average True Range (34)
   indHandlers[7][1][0] = iATR(NULL, 0, 34);
// Stochastic (13, 11, 12)
   indHandlers[7][2][0] = iStochastic(NULL, 0, 13, 11, 12, MODE_SMA, 0);
// Bollinger Bands (Close, 10, 2.53)
   indHandlers[7][3][0] = iBands(NULL, 0, 10, 0, 2.53, PRICE_CLOSE);
// Moving Average (Simple, Close, 14, 0)
   indHandlers[8][0][0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// RSI (Close, 19)
   indHandlers[8][1][0] = iRSI(NULL, 0, 19, PRICE_CLOSE);
// Commodity Channel Index (Typical, 42)
   indHandlers[8][2][0] = iCCI(NULL, 0, 42, PRICE_TYPICAL);
// Average True Range (31), Level: 0.0030
   indHandlers[8][3][0] = iATR(NULL, 0, 31);
// Bollinger Bands (Close, 19, 3.29)
   indHandlers[8][4][0] = iBands(NULL, 0, 19, 0, 3.29, PRICE_CLOSE);
// Moving Average (Simple, Close, 14, 0)
   indHandlers[9][0][0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
// Standard Deviation (Close, Simple, 48)
   indHandlers[9][1][0] = iStdDev(NULL, 0, 48, 0, MODE_SMA, PRICE_CLOSE);
// Directional Indicators (33)
   indHandlers[9][2][0] = iADX(NULL, 0, 33);
// Average True Range (32), Level: 0.0028
   indHandlers[9][3][0] = iATR(NULL, 0, 32);
   TesterHideIndicators(false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetSignals(Signal &signalList[])
  {
   int i = 0;
   ArrayResize(signalList, 2 * strategiesCount);

   /*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":1,"stopLoss":65,"takeProfit":75,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Moving Average","listIndexes":[4,0,3,0,0],"numValues":[14,0,0,0,0,0]},{"name":"Williams' Percent Range","listIndexes":[4,0,0,0,0],"numValues":[9,-95,0,0,0,0]},{"name":"Commodity Channel Index","listIndexes":[0,5,0,0,0],"numValues":[39,0,0,0,0,0]}],"closeFilters":[{"name":"RSI","listIndexes":[3,3,0,0,0],"numValues":[10,0,0,0,0,0]}]} */
   signalList[i++] = GetExitSignal_00();
   signalList[i++] = GetEntrySignal_00();

   /*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":1,"stopLoss":62,"takeProfit":60,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Moving Average","listIndexes":[4,0,3,0,0],"numValues":[14,0,0,0,0,0]},{"name":"DeMarker","listIndexes":[0,0,0,0,0],"numValues":[5,0,0,0,0,0]},{"name":"Alligator","listIndexes":[3,3,4,0,0],"numValues":[37,16,16,7,7,3]},{"name":"DeMarker","listIndexes":[7,0,0,0,0],"numValues":[34,0,0,0,0,0]}],"closeFilters":[{"name":"Commodity Channel Index","listIndexes":[2,5,0,0,0],"numValues":[32,367,0,0,0,0]}]} */
   signalList[i++] = GetExitSignal_01();
   signalList[i++] = GetEntrySignal_01();

   /*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":0,"stopLoss":85,"takeProfit":14,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Moving Average","listIndexes":[4,0,3,0,0],"numValues":[14,0,0,0,0,0]},{"name":"Commodity Channel Index","listIndexes":[1,5,0,0,0],"numValues":[6,0,0,0,0,0]},{"name":"Directional Indicators","listIndexes":[1,0,0,0,0],"numValues":[15,0,0,0,0,0]}],"closeFilters":[{"name":"Bollinger Bands","listIndexes":[3,3,0,0,0],"numValues":[5,3.22,0,0,0,0]}]} */
   signalList[i++] = GetExitSignal_02();
   signalList[i++] = GetEntrySignal_02();

   /*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":1,"stopLoss":89,"takeProfit":41,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Moving Average","listIndexes":[4,0,3,0,0],"numValues":[14,0,0,0,0,0]},{"name":"Stochastic","listIndexes":[7,0,0,0,0],"numValues":[15,7,9,20,0,0]}],"closeFilters":[{"name":"Envelopes","listIndexes":[5,3,0,0,0],"numValues":[40,0.44,0,0,0,0]}]} */
   signalList[i++] = GetExitSignal_03();
   signalList[i++] = GetEntrySignal_03();

   /*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":1,"stopLoss":81,"takeProfit":21,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Moving Average","listIndexes":[4,0,3,0,0],"numValues":[14,0,0,0,0,0]},{"name":"Moving Average","listIndexes":[7,0,3,0,0],"numValues":[9,0,0,0,0,0]},{"name":"Stochastic Signal","listIndexes":[2,0,0,0,0],"numValues":[17,15,9,0,0,0]}],"closeFilters":[{"name":"Envelopes","listIndexes":[5,3,0,0,0],"numValues":[49,0.44,0,0,0,0]}]} */
   signalList[i++] = GetExitSignal_04();
   signalList[i++] = GetEntrySignal_04();

   /*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":0,"stopLoss":52,"takeProfit":49,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Moving Average","listIndexes":[4,0,3,0,0],"numValues":[14,0,0,0,0,0]},{"name":"ADX","listIndexes":[0,0,0,0,0],"numValues":[45,0,0,0,0,0]},{"name":"Standard Deviation","listIndexes":[7,3,0,0,0],"numValues":[49,0,0,0,0,0]}],"closeFilters":[{"name":"Alligator","listIndexes":[8,3,4,0,0],"numValues":[32,13,13,9,9,2]}]} */
   signalList[i++] = GetExitSignal_05();
   signalList[i++] = GetEntrySignal_05();

   /*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":1,"stopLoss":92,"takeProfit":57,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Moving Average","listIndexes":[4,0,3,0,0],"numValues":[14,0,0,0,0,0]},{"name":"Stochastic","listIndexes":[1,0,0,0,0],"numValues":[2,2,2,20,0,0]},{"name":"Accelerator Oscillator","listIndexes":[6,0,0,0,0],"numValues":[0,0,0,0,0,0]},{"name":"ADX","listIndexes":[3,0,0,0,0],"numValues":[41,38,0,0,0,0]}],"closeFilters":[{"name":"Average True Range","listIndexes":[4,0,0,0,0],"numValues":[18,0.0032,0,0,0,0]}]} */
   signalList[i++] = GetExitSignal_06();
   signalList[i++] = GetEntrySignal_06();

   /*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":1,"stopLoss":95,"takeProfit":66,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Moving Average","listIndexes":[4,0,3,0,0],"numValues":[14,0,0,0,0,0]},{"name":"Average True Range","listIndexes":[7,0,0,0,0],"numValues":[34,0.01,0,0,0,0]},{"name":"Stochastic","listIndexes":[1,0,0,0,0],"numValues":[13,11,12,20,0,0]}],"closeFilters":[{"name":"Bollinger Bands","listIndexes":[2,3,0,0,0],"numValues":[10,2.53,0,0,0,0]}]} */
   signalList[i++] = GetExitSignal_07();
   signalList[i++] = GetEntrySignal_07();

   /*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":1,"stopLoss":69,"takeProfit":41,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Moving Average","listIndexes":[4,0,3,0,0],"numValues":[14,0,0,0,0,0]},{"name":"RSI","listIndexes":[0,3,0,0,0],"numValues":[19,30,0,0,0,0]},{"name":"Commodity Channel Index","listIndexes":[7,5,0,0,0],"numValues":[42,0,0,0,0,0]}],"closeFilters":[{"name":"Average True Range","listIndexes":[2,0,0,0,0],"numValues":[31,0.003,0,0,0,0]},{"name":"Bollinger Bands","listIndexes":[4,3,0,0,0],"numValues":[19,3.29,0,0,0,0]}]} */
   signalList[i++] = GetExitSignal_08();
   signalList[i++] = GetEntrySignal_08();

   /*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":1,"stopLoss":84,"takeProfit":10,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Moving Average","listIndexes":[4,0,3,0,0],"numValues":[14,0,0,0,0,0]},{"name":"Standard Deviation","listIndexes":[7,3,0,0,0],"numValues":[48,0,0,0,0,0]},{"name":"Directional Indicators","listIndexes":[0,0,0,0,0],"numValues":[33,0,0,0,0,0]}],"closeFilters":[{"name":"Average True Range","listIndexes":[5,0,0,0,0],"numValues":[32,0.0028,0,0,0,0]}]} */
   signalList[i++] = GetExitSignal_09();
   signalList[i++] = GetEntrySignal_09();

   if(i != 2 * strategiesCount)
      ArrayResize(signalList, i);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetEntrySignal_00()
  {
// Moving Average (Simple, Close, 14, 0)
   double ind0buffer[];
   CopyBuffer(indHandlers[0][0][0], 0, 1, 3, ind0buffer);
   double ind0val1  = ind0buffer[2];
   double ind0val2  = ind0buffer[1];
   bool   ind0long  = Open(0) > ind0val1 + sigma && Open(1) < ind0val2 - sigma;
   bool   ind0short = Open(0) < ind0val1 - sigma && Open(1) > ind0val2 + sigma;
// Williams' Percent Range (9), Level: -95.0
   double ind1buffer[];
   CopyBuffer(indHandlers[0][1][0], 0, 1, 3, ind1buffer);
   double ind1val1  = ind1buffer[2];
   double ind1val2  = ind1buffer[1];
   bool   ind1long  = ind1val1 > -95.0 + sigma && ind1val2 < -95.0 - sigma;
   bool   ind1short = ind1val1 < -100 - -95.0 - sigma && ind1val2 > -100 - -95.0 + sigma;
// Commodity Channel Index (Typical, 39)
   double ind2buffer[];
   CopyBuffer(indHandlers[0][2][0], 0, 1, 3, ind2buffer);
   double ind2val1  = ind2buffer[2];
   double ind2val2  = ind2buffer[1];
   bool   ind2long  = ind2val1 > ind2val2 + sigma;
   bool   ind2short = ind2val1 < ind2val2 - sigma;

   return CreateEntrySignal(0, ind0long && ind1long && ind2long, ind0short && ind1short && ind2short, 65, 75, false, true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetExitSignal_00()
  {
// RSI (Close, 10), Level: 0
   double ind3buffer[];
   CopyBuffer(indHandlers[0][3][0], 0, 1, 3, ind3buffer);
   double ind3val1  = ind3buffer[2];
   bool   ind3long  = ind3val1 < 0 - sigma;
   bool   ind3short = ind3val1 > 100 - 0 + sigma;

   return CreateExitSignal(0, ind3long, ind3short, 65, 75, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetEntrySignal_01()
  {
// Moving Average (Simple, Close, 14, 0)
   double ind0buffer[];
   CopyBuffer(indHandlers[1][0][0], 0, 1, 3, ind0buffer);
   double ind0val1  = ind0buffer[2];
   double ind0val2  = ind0buffer[1];
   bool   ind0long  = Open(0) > ind0val1 + sigma && Open(1) < ind0val2 - sigma;
   bool   ind0short = Open(0) < ind0val1 - sigma && Open(1) > ind0val2 + sigma;
// DeMarker (5)
   double ind1buffer[];
   CopyBuffer(indHandlers[1][1][0], 0, 1, 3, ind1buffer);
   double ind1val1  = ind1buffer[2];
   double ind1val2  = ind1buffer[1];
   bool   ind1long  = ind1val1 > ind1val2 + sigma;
   bool   ind1short = ind1val1 < ind1val2 - sigma;
// Alligator (Smoothed, Median, 37, 16, 16, 7, 7, 3)
   double ind2buffer0[];
   CopyBuffer(indHandlers[1][2][0], 0, 1, 2, ind2buffer0);
   double ind2buffer1[];
   CopyBuffer(indHandlers[1][2][0], 1, 1, 2, ind2buffer1);
   double ind2buffer2[];
   CopyBuffer(indHandlers[1][2][0], 2, 1, 2, ind2buffer2);
   double ind2val1  = ind2buffer1[1];
   double ind2val2  = ind2buffer1[0];
   bool   ind2long  = ind2val1 < ind2val2 - sigma;
   bool   ind2short = ind2val1 > ind2val2 + sigma;
// DeMarker (34)
   double ind3buffer[];
   CopyBuffer(indHandlers[1][3][0], 0, 1, 3, ind3buffer);
   double ind3val1  = ind3buffer[2];
   double ind3val2  = ind3buffer[1];
   double ind3val3  = ind3buffer[0];
   bool   ind3long  = ind3val1 < ind3val2 - sigma && ind3val2 > ind3val3 + sigma;
   bool   ind3short = ind3val1 > ind3val2 + sigma && ind3val2 < ind3val3 - sigma;

   return CreateEntrySignal(1, ind0long && ind1long && ind2long && ind3long, ind0short && ind1short && ind2short && ind3short, 62, 60, false, true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetExitSignal_01()
  {
// Commodity Channel Index (Typical, 32), Level: 367
   double ind4buffer[];
   CopyBuffer(indHandlers[1][4][0], 0, 1, 3, ind4buffer);
   double ind4val1  = ind4buffer[2];
   bool   ind4long  = ind4val1 > 367 + sigma;
   bool   ind4short = ind4val1 < -367 - sigma;

   return CreateExitSignal(1, ind4long, ind4short, 62, 60, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetEntrySignal_02()
  {
// Moving Average (Simple, Close, 14, 0)
   double ind0buffer[];
   CopyBuffer(indHandlers[2][0][0], 0, 1, 3, ind0buffer);
   double ind0val1  = ind0buffer[2];
   double ind0val2  = ind0buffer[1];
   bool   ind0long  = Open(0) > ind0val1 + sigma && Open(1) < ind0val2 - sigma;
   bool   ind0short = Open(0) < ind0val1 - sigma && Open(1) > ind0val2 + sigma;
// Commodity Channel Index (Typical, 6)
   double ind1buffer[];
   CopyBuffer(indHandlers[2][1][0], 0, 1, 3, ind1buffer);
   double ind1val1  = ind1buffer[2];
   double ind1val2  = ind1buffer[1];
   bool   ind1long  = ind1val1 < ind1val2 - sigma;
   bool   ind1short = ind1val1 > ind1val2 + sigma;
// Directional Indicators (15)
   double ind2buffer0[];
   CopyBuffer(indHandlers[2][2][0], 1, 1, 2, ind2buffer0);
   double ind2buffer1[];
   CopyBuffer(indHandlers[2][2][0], 2, 1, 2, ind2buffer1);
   double ind2val1  = ind2buffer0[1];
   double ind2val2  = ind2buffer1[1];
   double ind2val3  = ind2buffer0[0];
   double ind2val4  = ind2buffer1[0];
   bool   ind2long  = ind2val1 < ind2val2 - sigma && ind2val3 > ind2val4 + sigma;
   bool   ind2short = ind2val1 > ind2val2 + sigma && ind2val3 < ind2val4 - sigma;

   return CreateEntrySignal(2, ind0long && ind1long && ind2long, ind0short && ind1short && ind2short, 85, 14, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetExitSignal_02()
  {
// Bollinger Bands (Close, 5, 3.22)
   double ind3buffer0[];
   CopyBuffer(indHandlers[2][3][0], 1, 1, 2, ind3buffer0);
   double ind3buffer1[];
   CopyBuffer(indHandlers[2][3][0], 2, 1, 2, ind3buffer1);
   double ind3upBand1 = ind3buffer0[1];
   double ind3dnBand1 = ind3buffer1[1];
   double ind3upBand2 = ind3buffer0[0];
   double ind3dnBand2 = ind3buffer1[0];
   bool   ind3long    = Open(0) > ind3upBand1 + sigma && Open(1) < ind3upBand2 - sigma;
   bool   ind3short   = Open(0) < ind3dnBand1 - sigma && Open(1) > ind3dnBand2 + sigma;

   return CreateExitSignal(2, ind3long, ind3short, 85, 14, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetEntrySignal_03()
  {
// Moving Average (Simple, Close, 14, 0)
   double ind0buffer[];
   CopyBuffer(indHandlers[3][0][0], 0, 1, 3, ind0buffer);
   double ind0val1  = ind0buffer[2];
   double ind0val2  = ind0buffer[1];
   bool   ind0long  = Open(0) > ind0val1 + sigma && Open(1) < ind0val2 - sigma;
   bool   ind0short = Open(0) < ind0val1 - sigma && Open(1) > ind0val2 + sigma;
// Stochastic (15, 7, 9)
   double ind1buffer[];
   CopyBuffer(indHandlers[3][1][0], MAIN_LINE, 1, 3, ind1buffer);
   double ind1val1  = ind1buffer[2];
   double ind1val2  = ind1buffer[1];
   double ind1val3  = ind1buffer[0];
   bool   ind1long  = ind1val1 < ind1val2 - sigma && ind1val2 > ind1val3 + sigma;
   bool   ind1short = ind1val1 > ind1val2 + sigma && ind1val2 < ind1val3 - sigma;

   return CreateEntrySignal(3, ind0long && ind1long, ind0short && ind1short, 89, 41, false, true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetExitSignal_03()
  {
// Envelopes (Close, Simple, 40, 0.44)
   double ind2buffer0[];
   CopyBuffer(indHandlers[3][2][0], 0, 1, 2, ind2buffer0);
   double ind2buffer1[];
   CopyBuffer(indHandlers[3][2][0], 1, 1, 2, ind2buffer1);
   double ind2upBand1 = ind2buffer0[1];
   double ind2dnBand1 = ind2buffer1[1];
   double ind2upBand2 = ind2buffer0[0];
   double ind2dnBand2 = ind2buffer1[0];
   bool   ind2long    = Open(0) > ind2dnBand1 + sigma && Open(1) < ind2dnBand2 - sigma;
   bool   ind2short   = Open(0) < ind2upBand1 - sigma && Open(1) > ind2upBand2 + sigma;

   return CreateExitSignal(3, ind2long, ind2short, 89, 41, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetEntrySignal_04()
  {
// Moving Average (Simple, Close, 14, 0)
   double ind0buffer[];
   CopyBuffer(indHandlers[4][0][0], 0, 1, 3, ind0buffer);
   double ind0val1  = ind0buffer[2];
   double ind0val2  = ind0buffer[1];
   bool   ind0long  = Open(0) > ind0val1 + sigma && Open(1) < ind0val2 - sigma;
   bool   ind0short = Open(0) < ind0val1 - sigma && Open(1) > ind0val2 + sigma;
// Moving Average (Simple, Close, 9, 0)
   double ind1buffer[];
   CopyBuffer(indHandlers[4][1][0], 0, 1, 3, ind1buffer);
   double ind1val1  = ind1buffer[2];
   double ind1val2  = ind1buffer[1];
   double ind1val3  = ind1buffer[0];
   bool   ind1long  = ind1val1 < ind1val2 - sigma && ind1val2 > ind1val3 + sigma;
   bool   ind1short = ind1val1 > ind1val2 + sigma && ind1val2 < ind1val3 - sigma;
// Stochastic Signal (17, 15, 9)
   double ind2buffer0[];
   CopyBuffer(indHandlers[4][2][0], MAIN_LINE,   1, 2, ind2buffer0);
   double ind2buffer1[];
   CopyBuffer(indHandlers[4][2][0], SIGNAL_LINE, 1, 2, ind2buffer1);
   double ind2val1  = ind2buffer0[1];
   double ind2val2  = ind2buffer1[1];
   bool   ind2long  = ind2val1 > ind2val2 + sigma;
   bool   ind2short = ind2val1 < ind2val2 - sigma;

   return CreateEntrySignal(4, ind0long && ind1long && ind2long, ind0short && ind1short && ind2short, 81, 21, false, true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetExitSignal_04()
  {
// Envelopes (Close, Simple, 49, 0.44)
   double ind3buffer0[];
   CopyBuffer(indHandlers[4][3][0], 0, 1, 2, ind3buffer0);
   double ind3buffer1[];
   CopyBuffer(indHandlers[4][3][0], 1, 1, 2, ind3buffer1);
   double ind3upBand1 = ind3buffer0[1];
   double ind3dnBand1 = ind3buffer1[1];
   double ind3upBand2 = ind3buffer0[0];
   double ind3dnBand2 = ind3buffer1[0];
   bool   ind3long    = Open(0) > ind3dnBand1 + sigma && Open(1) < ind3dnBand2 - sigma;
   bool   ind3short   = Open(0) < ind3upBand1 - sigma && Open(1) > ind3upBand2 + sigma;

   return CreateExitSignal(4, ind3long, ind3short, 81, 21, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetEntrySignal_05()
  {
// Moving Average (Simple, Close, 14, 0)
   double ind0buffer[];
   CopyBuffer(indHandlers[5][0][0], 0, 1, 3, ind0buffer);
   double ind0val1  = ind0buffer[2];
   double ind0val2  = ind0buffer[1];
   bool   ind0long  = Open(0) > ind0val1 + sigma && Open(1) < ind0val2 - sigma;
   bool   ind0short = Open(0) < ind0val1 - sigma && Open(1) > ind0val2 + sigma;
// ADX (45)
   double ind1buffer[];
   CopyBuffer(indHandlers[5][1][0], 0, 1, 3, ind1buffer);
   double ind1val1  = ind1buffer[2];
   double ind1val2  = ind1buffer[1];
   bool   ind1long  = ind1val1 > ind1val2 + sigma;
   bool   ind1short = ind1long;
// Standard Deviation (Close, Simple, 49)
   double ind2buffer[];
   CopyBuffer(indHandlers[5][2][0], 0, 1, 3, ind2buffer);
   double ind2val1  = ind2buffer[2];
   double ind2val2  = ind2buffer[1];
   double ind2val3  = ind2buffer[0];
   bool   ind2long  = ind2val1 < ind2val2 - sigma && ind2val2 > ind2val3 + sigma;
   bool   ind2short = ind2long;

   return CreateEntrySignal(5, ind0long && ind1long && ind2long, ind0short && ind1short && ind2short, 52, 49, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetExitSignal_05()
  {
// Alligator (Smoothed, Median, 32, 13, 13, 9, 9, 2)
   double ind3buffer0[];
   CopyBuffer(indHandlers[5][3][0], 0, 1, 2, ind3buffer0);
   double ind3buffer1[];
   CopyBuffer(indHandlers[5][3][0], 1, 1, 2, ind3buffer1);
   double ind3buffer2[];
   CopyBuffer(indHandlers[5][3][0], 2, 1, 2, ind3buffer2);
   double ind3val1  = ind3buffer2[1];
   double ind3val2  = ind3buffer0[1];
   double ind3val3  = ind3buffer2[0];
   double ind3val4  = ind3buffer0[0];
   bool   ind3long  = ind3val1 > ind3val2 + sigma && ind3val3 < ind3val4 - sigma;
   bool   ind3short = ind3val1 < ind3val2 - sigma && ind3val3 > ind3val4 + sigma;

   return CreateExitSignal(5, ind3long, ind3short, 52, 49, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetEntrySignal_06()
  {
// Moving Average (Simple, Close, 14, 0)
   double ind0buffer[];
   CopyBuffer(indHandlers[6][0][0], 0, 1, 3, ind0buffer);
   double ind0val1  = ind0buffer[2];
   double ind0val2  = ind0buffer[1];
   bool   ind0long  = Open(0) > ind0val1 + sigma && Open(1) < ind0val2 - sigma;
   bool   ind0short = Open(0) < ind0val1 - sigma && Open(1) > ind0val2 + sigma;
// Stochastic (2, 2, 2)
   double ind1buffer[];
   CopyBuffer(indHandlers[6][1][0], MAIN_LINE, 1, 3, ind1buffer);
   double ind1val1  = ind1buffer[2];
   double ind1val2  = ind1buffer[1];
   bool   ind1long  = ind1val1 < ind1val2 - sigma;
   bool   ind1short = ind1val1 > ind1val2 + sigma;
// Accelerator Oscillator
   double ind2buffer[];
   CopyBuffer(indHandlers[6][2][0], 0, 1, 3, ind2buffer);
   double ind2val1  = ind2buffer[2];
   double ind2val2  = ind2buffer[1];
   double ind2val3  = ind2buffer[0];
   bool   ind2long  = ind2val1 > ind2val2 + sigma && ind2val2 < ind2val3 - sigma;
   bool   ind2short = ind2val1 < ind2val2 - sigma && ind2val2 > ind2val3 + sigma;
// ADX (41), Level: 38.0
   double ind3buffer[];
   CopyBuffer(indHandlers[6][3][0], 0, 1, 3, ind3buffer);
   double ind3val1  = ind3buffer[2];
   bool   ind3long  = ind3val1 < 38.0 - sigma;
   bool   ind3short = ind3long;

   return CreateEntrySignal(6, ind0long && ind1long && ind2long && ind3long, ind0short && ind1short && ind2short && ind3short, 92, 57, false, true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetExitSignal_06()
  {
// Average True Range (18), Level: 0.0032
   double ind4buffer[];
   CopyBuffer(indHandlers[6][4][0], 0, 1, 3, ind4buffer);
   double ind4val1  = ind4buffer[2];
   double ind4val2  = ind4buffer[1];
   bool   ind4long  = ind4val1 > 0.0032 + sigma && ind4val2 < 0.0032 - sigma;
   bool   ind4short = ind4long;

   return CreateExitSignal(6, ind4long, ind4short, 92, 57, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetEntrySignal_07()
  {
// Moving Average (Simple, Close, 14, 0)
   double ind0buffer[];
   CopyBuffer(indHandlers[7][0][0], 0, 1, 3, ind0buffer);
   double ind0val1  = ind0buffer[2];
   double ind0val2  = ind0buffer[1];
   bool   ind0long  = Open(0) > ind0val1 + sigma && Open(1) < ind0val2 - sigma;
   bool   ind0short = Open(0) < ind0val1 - sigma && Open(1) > ind0val2 + sigma;
// Average True Range (34)
   double ind1buffer[];
   CopyBuffer(indHandlers[7][1][0], 0, 1, 3, ind1buffer);
   double ind1val1  = ind1buffer[2];
   double ind1val2  = ind1buffer[1];
   double ind1val3  = ind1buffer[0];
   bool   ind1long  = ind1val1 < ind1val2 - sigma && ind1val2 > ind1val3 + sigma;
   bool   ind1short = ind1long;
// Stochastic (13, 11, 12)
   double ind2buffer[];
   CopyBuffer(indHandlers[7][2][0], MAIN_LINE, 1, 3, ind2buffer);
   double ind2val1  = ind2buffer[2];
   double ind2val2  = ind2buffer[1];
   bool   ind2long  = ind2val1 < ind2val2 - sigma;
   bool   ind2short = ind2val1 > ind2val2 + sigma;

   return CreateEntrySignal(7, ind0long && ind1long && ind2long, ind0short && ind1short && ind2short, 95, 66, false, true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetExitSignal_07()
  {
// Bollinger Bands (Close, 10, 2.53)
   double ind3buffer0[];
   CopyBuffer(indHandlers[7][3][0], 1, 1, 2, ind3buffer0);
   double ind3buffer1[];
   CopyBuffer(indHandlers[7][3][0], 2, 1, 2, ind3buffer1);
   double ind3upBand1 = ind3buffer0[1];
   double ind3dnBand1 = ind3buffer1[1];
   double ind3upBand2 = ind3buffer0[0];
   double ind3dnBand2 = ind3buffer1[0];
   bool   ind3long    = Open(0) < ind3upBand1 - sigma && Open(1) > ind3upBand2 + sigma;
   bool   ind3short   = Open(0) > ind3dnBand1 + sigma && Open(1) < ind3dnBand2 - sigma;

   return CreateExitSignal(7, ind3long, ind3short, 95, 66, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetEntrySignal_08()
  {
// Moving Average (Simple, Close, 14, 0)
   double ind0buffer[];
   CopyBuffer(indHandlers[8][0][0], 0, 1, 3, ind0buffer);
   double ind0val1  = ind0buffer[2];
   double ind0val2  = ind0buffer[1];
   bool   ind0long  = Open(0) > ind0val1 + sigma && Open(1) < ind0val2 - sigma;
   bool   ind0short = Open(0) < ind0val1 - sigma && Open(1) > ind0val2 + sigma;
// RSI (Close, 19)
   double ind1buffer[];
   CopyBuffer(indHandlers[8][1][0], 0, 1, 3, ind1buffer);
   double ind1val1  = ind1buffer[2];
   double ind1val2  = ind1buffer[1];
   bool   ind1long  = ind1val1 > ind1val2 + sigma;
   bool   ind1short = ind1val1 < ind1val2 - sigma;
// Commodity Channel Index (Typical, 42)
   double ind2buffer[];
   CopyBuffer(indHandlers[8][2][0], 0, 1, 3, ind2buffer);
   double ind2val1  = ind2buffer[2];
   double ind2val2  = ind2buffer[1];
   double ind2val3  = ind2buffer[0];
   bool   ind2long  = ind2val1 < ind2val2 - sigma && ind2val2 > ind2val3 + sigma;
   bool   ind2short = ind2val1 > ind2val2 + sigma && ind2val2 < ind2val3 - sigma;

   return CreateEntrySignal(8, ind0long && ind1long && ind2long, ind0short && ind1short && ind2short, 69, 41, false, true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetExitSignal_08()
  {
// Average True Range (31), Level: 0.0030
   double ind3buffer[];
   CopyBuffer(indHandlers[8][3][0], 0, 1, 3, ind3buffer);
   double ind3val1  = ind3buffer[2];
   bool   ind3long  = ind3val1 > 0.0030 + sigma;
   bool   ind3short = ind3long;
// Bollinger Bands (Close, 19, 3.29)
   double ind4buffer0[];
   CopyBuffer(indHandlers[8][4][0], 1, 1, 2, ind4buffer0);
   double ind4buffer1[];
   CopyBuffer(indHandlers[8][4][0], 2, 1, 2, ind4buffer1);
   double ind4upBand1 = ind4buffer0[1];
   double ind4dnBand1 = ind4buffer1[1];
   double ind4upBand2 = ind4buffer0[0];
   double ind4dnBand2 = ind4buffer1[0];
   bool   ind4long    = Open(0) < ind4dnBand1 - sigma && Open(1) > ind4dnBand2 + sigma;
   bool   ind4short   = Open(0) > ind4upBand1 + sigma && Open(1) < ind4upBand2 - sigma;

   return CreateExitSignal(8, ind3long || ind4long, ind3short || ind4short, 69, 41, false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetEntrySignal_09()
  {
// Moving Average (Simple, Close, 14, 0)
   double ind0buffer[];
   CopyBuffer(indHandlers[9][0][0], 0, 1, 3, ind0buffer);
   double ind0val1  = ind0buffer[2];
   double ind0val2  = ind0buffer[1];
   bool   ind0long  = Open(0) > ind0val1 + sigma && Open(1) < ind0val2 - sigma;
   bool   ind0short = Open(0) < ind0val1 - sigma && Open(1) > ind0val2 + sigma;
// Standard Deviation (Close, Simple, 48)
   double ind1buffer[];
   CopyBuffer(indHandlers[9][1][0], 0, 1, 3, ind1buffer);
   double ind1val1  = ind1buffer[2];
   double ind1val2  = ind1buffer[1];
   double ind1val3  = ind1buffer[0];
   bool   ind1long  = ind1val1 < ind1val2 - sigma && ind1val2 > ind1val3 + sigma;
   bool   ind1short = ind1long;
// Directional Indicators (33)
   double ind2buffer0[];
   CopyBuffer(indHandlers[9][2][0], 1, 1, 2, ind2buffer0);
   double ind2buffer1[];
   CopyBuffer(indHandlers[9][2][0], 2, 1, 2, ind2buffer1);
   double ind2val1  = ind2buffer0[1];
   double ind2val2  = ind2buffer1[1];
   double ind2val3  = ind2buffer0[0];
   double ind2val4  = ind2buffer1[0];
   bool   ind2long  = ind2val1 > ind2val2 + sigma && ind2val3 < ind2val4 - sigma;
   bool   ind2short = ind2val1 < ind2val2 - sigma && ind2val3 > ind2val4 + sigma;

   return CreateEntrySignal(9, ind0long && ind1long && ind2long, ind0short && ind1short && ind2short, 84, 10, false, true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Signal GetExitSignal_09()
  {
// Average True Range (32), Level: 0.0028
   double ind3buffer[];
   CopyBuffer(indHandlers[9][3][0], 0, 1, 3, ind3buffer);
   double ind3val1  = ind3buffer[2];
   double ind3val2  = ind3buffer[1];
   bool   ind3long  = ind3val1 < 0.0028 - sigma && ind3val2 > 0.0028 + sigma;
   bool   ind3short = ind3long;

   return CreateExitSignal(9, ind3long, ind3short, 84, 10, false);
  }
//+------------------------------------------------------------------+
/*STRATEGY MARKET Premium Data; EURUSD; M15 */
