//+------------------------------------------------------------------+
//|                                                 AdoValueList.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include <Arrays\List.mqh>
#include "AdoValue.mqh"
#include "..\AdoTypes.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian �����, �������������� ������ CAdoValue
///         \~english Represents CAdoValue collection
class CAdoValueList : public CList
  {
public:
   /// \brief  \~russian ������� ������ ���� CAdoValue. ����������� �����
   ///         \~english Creates new value. Virtual
   virtual CObject *CreateElement() { return new CAdoValue(); }

   /// \brief  \~russian ���������� ��� ���������
   ///         \~english Gets collection type
   virtual int Type() { return ADOTYPE_VALUELIST; }

   /// \brief  \~russian ���������� �������� �� �������
   ///         \~english Gets value by index
   CAdoValue        *GetValue(const int index);
  };
//--------------------------------------------------------------------
CAdoValue *CAdoValueList::GetValue(const int index)
  {
   return GetNodeAtIndex(index);
  }
//+------------------------------------------------------------------+
