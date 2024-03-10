//+------------------------------------------------------------------+
//|                                                AdoRecordList.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include <Arrays\List.mqh>
#include "AdoRecord.mqh"
#include "..\AdoTypes.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian �����, �������������� ��������� �������
///         \~english Represents row list
class CAdoRecordList : public CList
  {
public:
   /// \brief  \~russian ������� ������ ���� CAdoRecord. ����������� �����
   ///         \~english Creates new row. Virtual
   virtual CObject *CreateElement() { return new CAdoRecord(); }

   /// \brief  \~russian ���������� ��� ���������
   ///         \~english Gets collection type
   virtual int Type() { return ADOTYPE_RECORDLIST; }

   /// \brief  \~russian ���������� ������ �� �������
   ///         \~english Gets row by index
   CAdoRecord       *GetRecord(const int index);
  };
//--------------------------------------------------------------------
CAdoRecord *CAdoRecordList::GetRecord(const int index)
  {
   return GetNodeAtIndex(index);
  }
//+------------------------------------------------------------------+
