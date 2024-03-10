//+------------------------------------------------------------------+
//|                                             OleDbDataAdapter.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbDataAdapter.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian ����� ������ ��� ��������� AdoTable ������� �� ��������� OLE DB
///         \~english Used for filling AdoTable from an OLE DB data source
class COleDbDataAdapter : public CDbDataAdapter
  {
public:
   /// \brief  \~russian ����������� ������
   ///         \~english constructor
                     COleDbDataAdapter();
  };
//--------------------------------------------------------------------
COleDbDataAdapter::COleDbDataAdapter()
  {
   MqlTypeName("COleDbDataAdapter");
  }
//+------------------------------------------------------------------+
