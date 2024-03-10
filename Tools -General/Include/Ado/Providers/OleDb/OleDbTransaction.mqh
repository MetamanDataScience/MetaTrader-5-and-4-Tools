//+------------------------------------------------------------------+
//|                                             OleDbTransaction.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbTransaction.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian �����, �������������� ���������� OLE DB
///         \~english Represents transaction in an OLE DB data source
class COleDbTransaction : public CDbTransaction
  {
public:
   /// \brief  \~russian ����������� ������
   ///         \~english constructor
                     COleDbTransaction();
  };
//--------------------------------------------------------------------
COleDbTransaction::COleDbTransaction()
  {
   MqlTypeName("COleDbTransaction");
  }
//+------------------------------------------------------------------+
