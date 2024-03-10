
#include <ClassOne-V2.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Trade/Trade.mqh>

input group "===== Indicator(@_A) =====";
input int SmoothingPeriodA = 6;
input ENUM_MA_METHOD SmoothingMethodA = MODE_LWMA;
input int StepSizeA = 3;
input string IndicatorNameA = "HA Alerts.ex5";
input long MagicNoA = 100001;
input group " Trading(@_A) ";
input string PairA = "GBPUSDx"; 
input ENUM_TIMEFRAMES TfA = PERIOD_M5;
input double LotSizeA = 0.01;
input int TPpointsA = 100;
input int SLpointsA = 100;
input int TSLTriggerPointsA = 40;
input int TSLpointsA = 20;

input group "===== Indicator(@_B) ====="
input int SmoothingPeriodB = 6;
input ENUM_MA_METHOD SmoothingMethodB = MODE_LWMA;
input int StepSizeB = 3;
input string IndicatorNameB = "HA Alerts.ex5";
input long MagicNoB = 100002;
input group " Trading(@_B) ";
input string PairB = "GBPUSDx"; 
input ENUM_TIMEFRAMES TfB = PERIOD_M1;
input double LotSizeB = 0.01;
input int TPpointsB = 100;
input int SLpointsB = 100;
input int TSLTriggerPointsB = 40;
input int TSLpointsB = 20;

input group "===== Indicator(@_C) ====="
input int SmoothingPeriodC = 6;
input ENUM_MA_METHOD SmoothingMethodC = MODE_LWMA;
input int StepSizeC = 3;
input string IndicatorNameC = "HA Alerts.ex5";
input long MagicNoC = 100002;
input group " Trading(@_C) ";
input string PairC = "GBPJPYx"; 
input ENUM_TIMEFRAMES TfC = PERIOD_M5;
input double LotSizeC = 0.01;
input int TPpointsC = 100;
input int SLpointsC = 100;
input int TSLTriggerPointsC = 40;
input int TSLpointsC = 20;

CTrade Trade;
MqlTick cT;


//CArrayObj StratArray;                    //This will help organize the instances of objects of type 'Cstrategy' type from the ClassOne-V2 file along the OnInit, OnTick and OnDeinit functions !!
CHASmoothedStrategy Strat_A(PairA,TfA,LotSizeA,TPpointsA,SLpointsA,TSLTriggerPointsA,TSLpointsA,SmoothingPeriodA,SmoothingMethodA,StepSizeA,IndicatorNameA,MagicNoA,20);
//CHASmoothedStrategy Strat_B(PairB,TfB,LotSizeB,TPpointsB,SLpointsB,TSLTriggerPointsB,TSLpointsB,SmoothingPeriodB,SmoothingMethodB,StepSizeB,IndicatorNameB,MagicNoB,20);
//CHASmoothedStrategy Strat_C(PairC,TfC,LotSizeC,TPpointsC,SLpointsC,TSLTriggerPointsC,TSLpointsC,SmoothingPeriodC,SmoothingMethodC,StepSizeC,IndicatorNameC,MagicNoC,20);
//CHASmoothedStrategy Strat_A2
//CHASmoothedStrategy Strat_B2
//CHASmoothedStrategy Strat_C2

int OnInit()
{
//---
   Strat_A.OnInitEvent();
   //Strat_B.OnInitEvent();
   //Strat_C.OnInitEvent();
   // Strat_A2.OnInitEvent();
   // Strat_B2.OnInitEvent();
   // Strat_C2.OnInitEvent();
   
//---
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

}

void OnTick()
{
//---
   Strat_A.OnTickEvent();
   //Strat_B.OnTickEvent();
   //Strat_C.OnTickEvent();
   //Strat_A2.OnTickEvent();
   //Strat_B2.OnTickEvent();
   //Strat_C2.OnTickEvent();   
   
   // ...
   
}

//+------------------------------------------------------------------+


