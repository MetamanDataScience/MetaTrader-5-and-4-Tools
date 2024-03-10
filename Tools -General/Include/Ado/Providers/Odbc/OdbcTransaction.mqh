//+------------------------------------------------------------------+
//|                                              OdbcTransaction.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbTransaction.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian �����, �������������� ���������� ODBC
///         \~english Represents transaction in an ODBC data source
class COdbcTransaction : public CDbTransaction
  {
public:
   /// \brief  \~russian ����������� ������
   ///         \~english constructor
                     COdbcTransaction();
  };
//--------------------------------------------------------------------
COdbcTransaction::COdbcTransaction()
  {
   MqlTypeName("COdbcTransaction");
  }
//+------------------------------------------------------------------+
