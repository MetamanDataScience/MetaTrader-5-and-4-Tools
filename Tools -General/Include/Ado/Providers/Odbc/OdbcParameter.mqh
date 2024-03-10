//+------------------------------------------------------------------+
//|                                                OdbcParameter.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbParameter.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian �����, �������������� �������� ������� ODBC
///         \~english Represents command parameter in an ODBC data source
class COdbcParameter : public CDbParameter
  {
public:
   /// \brief  \~russian ����������� ������
   ///         \~english constructor
                     COdbcParameter();
  };
//--------------------------------------------------------------------
COdbcParameter::COdbcParameter()
  {
   MqlTypeName("COdbcParameter");
   CreateClrObject("System.Data","System.Data.Odbc.OdbcParameter");
  }
//+------------------------------------------------------------------+
