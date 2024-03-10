//+------------------------------------------------------------------+
//|                                                     ClassOne.mqh |
//|                                                       ChrisMeta1 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "ChrisMeta1"
#property link      "https://www.mql5.com"

class MyOne {
   //Private Members & Functions
   private:
      int Check_Margin;                        //Check Margin before placing a trade? (1 or 0)
      double Trade_Percent;
      int MagicNo;
      double Lots;
      int ADX_Handle;
      int MA_Handle;
      double ADX_MIN;
      double plusDI[];
      double minusDI[];
      double MAValue[];
      double ADXValue[];
      double Closeprice;
      MqlTradeRequest Trequest;
      MqlTradeResult Tresult;
      string symbol;
      ENUM_TIMEFRAMES period;
      string Errmsg;
      int Errcode;
   //Public Members & Functions
   public:
      void MyOne();              //Class Constructor
      void setSymbol(string syb){ symbol = syb; }              //Function to set current symbol
      void setPeriod(ENUM_TIMEFRAMES prd){ period = prd; }     //function to set current period
      void setCloseprice(double prc){ Closeprice = prc; }      //Function to set previous bar close price
      void setCheckMargin(int mag){ Check_Margin = mag; }      //Function to set Check Margin value
      void setLots(double lot){ Lots = lot; }                  //Function to set Lot Size
      void setTpercent(double tprc){ Trade_Percent = tprc; }   //Function to set Percentage of Free Margin to use for trading
      void setMagic(int magic){ MagicNo = magic; }             //Function to set ExpertMagicNo
      void setADXmin(double adx){ ADX_MIN = adx; }             //Function to set Minimum ADX value
      void doInit(int adx_period,int ma_period);               //function to be used at our EA intialization
      void doUninit();                                         //function to be used at EA de-initialization
      bool checkBuySignal();                                   //function to check for Buy conditions
      bool checkSellSignal();                                  //function to check for Sell conditions
      void openBuy(ENUM_ORDER_TYPE otype,double askprice,double SL,double TP,int dev,string comment="");   //function to open Buy positions
      void openSell(ENUM_ORDER_TYPE otype,double bidprice,double SL,double TP,int dev,string comment="");  //function to open Sell positions
   protected:
   void              showError(string msg, int ercode);   //function for use to display error messages
   void              getBuffers();                        //function for getting Indicator buffers
   bool              MarginOK();                          //function to check if margin required for lots is OK
   
};
//---
void MyOne::MyOne()
{
ZeroMemory(Trequest);
ZeroMemory(Tresult);
ZeroMemory(ADXValue);
ZeroMemory(MAValue);
ZeroMemory(plusDI);
ZeroMemory(minusDI);
Errmsg="";
Errcode=0;
}
//---
void MyOne::showError(string msg,int ercode)       //Performs Alert() function with input parameters as string messege and int errorcode
{
   Alert(msg,"-error:",ercode,"!!");
}
//---
void MyOne::getBuffers()                           //Performs CopyBuffer() function on OnInit(), No input parameters are required
{
   if(CopyBuffer(ADX_Handle,0,0,3,ADXValue)<0 || CopyBuffer(ADX_Handle,1,0,3,plusDI)<0
      || CopyBuffer(ADX_Handle,2,0,3,minusDI)<0 || CopyBuffer(MA_Handle,0,0,3,MAValue)<0) {
         Errmsg = "Error Copying Indicator Buffers";
         Errcode = GetLastError();
         showError(Errmsg,Errcode);                //Output Function for Error checking, Input variables are the Class data members defined in -private, types being == to function parameters
   }
}
//---
bool MyOne::MarginOK()
{
double one_lot_price;
double accFmargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
long accleverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
double contractsize = SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
string basecurrency = SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE);

   if(basecurrency == "USD") {
      one_lot_price = contractsize/accleverage;
   } else {
         double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
         one_lot_price = bid * contractsize/accleverage;
      }
   //Check if margin required to open new position with volume Lots is not greater than the percentage of free margin based on base(input) settings
   if(MathFloor(Lots * one_lot_price)>(MathFloor(accFmargin * Trade_Percent))) {
      return(false);
   } else {
      return(true);
   }

}
//---
void MyOne::doInit(int adx_period,int ma_period)      //To be used on the OnInit() part of the EA create handles
{
   ADX_Handle = iADX(symbol,period,adx_period);
   MA_Handle = iMA(symbol,period,ma_period,0,MODE_EMA,PRICE_CLOSE);
   //Check for error when creating indicator handles
   if(ADX_Handle<0 || MA_Handle<0) {
      Errmsg = "Error Creating Handles for Indicators";
      Errcode = GetLastError();
      showError(Errmsg,Errcode);
   }
   
   ArraySetAsSeries(plusDI,true);
   ArraySetAsSeries(minusDI,true);
   ArraySetAsSeries(ADXValue,true);
   ArraySetAsSeries(MAValue,true);      
}
//---
void MyOne::doUninit()
{
IndicatorRelease(ADX_Handle);
IndicatorRelease(MA_Handle);
}
//---
bool MyOne::checkBuySignal()    //No inputs, Uses the class data members to check for Buy setup based on the defined trade strategy, Returns TRUE if Buy conditions are met or FALSE if not met
{
getBuffers();

bool BUY_CONDITION_1 = (MAValue[0] > MAValue[1]) && (MAValue[1]>MAValue[2]);  //MA Increasing Upwards
bool BUY_CONDITION_2 = (Closeprice > MAValue[1]);                              //Previous close price above MA
bool BUY_CONDITION_3 = (ADXValue[0] > ADX_MIN);                              //ADX value greater then minimum set as input
bool BUY_CONDITION_4 = plusDI[0] > minusDI[0];                             //+DI greater than -DI

   if(BUY_CONDITION_1 && BUY_CONDITION_2 && BUY_CONDITION_3 && BUY_CONDITION_4) {
      return(true);
   } else {
      return(false);       
   }
}
//---
bool MyOne::checkSellSignal()
{
getBuffers();

bool SELL_CONDITION_1=(MAValue[0]<MAValue[1]) && (MAValue[1]<MAValue[2]);  // MA decreasing downwards
bool SELL_CONDITION_2=(Closeprice <MAValue[1]);                         // Previous price closed below MA
bool SELL_CONDITION_3=(ADXValue[0]>ADX_MIN);                            // Current ADX value greater than minimum ADX
bool SELL_CONDITION_4=(plusDI[0]<minusDI[0]);                        // -DI greater than +DI

   if(SELL_CONDITION_1 && SELL_CONDITION_2 && SELL_CONDITION_3 && SELL_CONDITION_4) {
      return(true);
   } else {
      return(false);
   }
}
//---
void MyOne::openBuy(ENUM_ORDER_TYPE otype,double askprice,double SL,double TP,int dev,string comment="")
{
if(Check_Margin==1) {
   if(MarginOK()==false) {
      Errmsg = "Not Enough Free Margin to open new position";
      Errcode = GetLastError();
      showError(Errmsg,Errcode);
   } else {
      Trequest.action=TRADE_ACTION_DEAL;
      Trequest.type=otype;
      Trequest.volume=Lots;
      Trequest.price=askprice;
      Trequest.sl=SL;
      Trequest.tp=TP;
      Trequest.deviation=dev;
      Trequest.magic=MagicNo;
      Trequest.symbol=symbol;
      Trequest.type_filling=ORDER_FILLING_FOK;
      OrderSend(Trequest,Tresult);
      if(Tresult.retcode == 10008 || Tresult.retcode == 10009) {
         Alert(Tresult.order," || Buy order Successful");
      } else {
         Errmsg = "Buy Order Request Unsuccessful";
         Errcode = GetLastError();
         showError(Errmsg,Errcode);
      }
   }
} else {
      Trequest.action=TRADE_ACTION_DEAL;
      Trequest.type=otype;
      Trequest.volume=Lots;
      Trequest.price=askprice;
      Trequest.sl=SL;
      Trequest.tp=TP;
      Trequest.deviation=dev;
      Trequest.magic=MagicNo;
      Trequest.symbol=symbol;
      Trequest.type_filling=ORDER_FILLING_FOK;
      OrderSend(Trequest,Tresult);
      if(Tresult.retcode == 10008 || Tresult.retcode == 10009) {
         Alert(Tresult.order," || Buy order Successful");
      } else {
         Errmsg = "Buy Order Request Unsuccessful";
         Errcode = GetLastError();
         showError(Errmsg,Errcode);
      }
  }
   
   
}
//---
void MyOne::openSell(ENUM_ORDER_TYPE otype,double bidprice,double SL,double TP,int dev,string comment="")
{
if(Check_Margin==1) {
   if(MarginOK()==false) {
      Errmsg = "Not Enough Free Margin to open new position";
      Errcode = GetLastError();
      showError(Errmsg,Errcode);
   } else {
      Trequest.action=TRADE_ACTION_DEAL;
      Trequest.type=otype;
      Trequest.volume=Lots;
      Trequest.price=bidprice;
      Trequest.sl=SL;
      Trequest.tp=TP;
      Trequest.deviation=dev;
      Trequest.magic=MagicNo;
      Trequest.symbol=symbol;
      Trequest.type_filling=ORDER_FILLING_FOK;
      OrderSend(Trequest,Tresult);
      if(Tresult.retcode == 10008 || Tresult.retcode == 10009) {
         Alert(Tresult.order," || Sell order Successful");
      } else {
         Errmsg = "Sell Order Request Unsuccessful";
         Errcode = GetLastError();
         showError(Errmsg,Errcode);
      }
   }
} else {
      Trequest.action=TRADE_ACTION_DEAL;
      Trequest.type=otype;
      Trequest.volume=Lots;
      Trequest.price=bidprice;
      Trequest.sl=SL;
      Trequest.tp=TP;
      Trequest.deviation=dev;
      Trequest.magic=MagicNo;
      Trequest.symbol=symbol;
      Trequest.type_filling=ORDER_FILLING_FOK;
      OrderSend(Trequest,Tresult);
      if(Tresult.retcode == 10008 || Tresult.retcode == 10009) {
         Alert(Tresult.order," || Sell order Successful");
      } else {
         Errmsg = "Sell Order Request Unsuccessful";
         Errcode = GetLastError();
         showError(Errmsg,Errcode);
      }
  }
   
}
//---