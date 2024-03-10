//+------------------------------------------------------------------+
//|                                               OdbcDataReader.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "..\Base\DbDataReader.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian ����� ��� ������ ������ �� ��������� ODBC � ������ �����������
///         \~english Reads a forward-only stream of rows from an ODBC data source
class COdbcDataReader : public CDbDataReader
  {
public:
   /// \brief  \~russian ����������� ������
   ///         \~english constructor
                     COdbcDataReader();
  };
//--------------------------------------------------------------------
COdbcDataReader::COdbcDataReader()
  {
   MqlTypeName("COdbcDataReader");
  }
//+------------------------------------------------------------------+
