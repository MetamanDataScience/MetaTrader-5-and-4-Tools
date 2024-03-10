//+------------------------------------------------------------------+
//|                                                     AdoTable.mqh |
//|                                             Copyright GF1D, 2010 |
//|                                             garf1eldhome@mail.ru |
//+------------------------------------------------------------------+
#property copyright "GF1D, 2010"
#property link      "garf1eldhome@mail.ru"

#include "AdoColumnList.mqh"
#include "AdoRecordList.mqh"
#include "AdoRecord.mqh"
#include "..\AdoTypes.mqh"
//--------------------------------------------------------------------
/// \brief  \~russian �����, �������������� ������� � �������
///         \~english Represents table
class CAdoTable
  {
private:
   CAdoColumnList   *_Columns;
   CAdoRecordList   *_Records;
   string            _TableName;

protected:
   /// \brief  \~russian ������� ��������� �������� �������. ����������� �����
   ///         \~english Creates column collection for the table
   virtual CAdoColumnList *CreateColumns() { return new CAdoColumnList(); }
   /// \brief  \~russian ������� ��������� ������� �������. ����������� �����
   ///         \~english Creates row collection for the table
   virtual CAdoRecordList *CreateRecords() { return new CAdoRecordList(); }

public:
   /// \brief  \~russian ���������� ������
   ///         \~english destructor
                    ~CAdoTable();

   // proprerties

   /// \brief  \~russian ���������� ��� �������
   ///         \~english Gets table name
   const string TableName() { return _TableName; }
   /// \brief  \~russian ������ ��� �������
   ///         \~english Sets table name
   void TableName(const string value) { _TableName=value; }

   /// \brief  \~russian ���������� ��������� ��������
   ///         \~english Gets column collection 
   CAdoColumnList   *Columns();
   /// \brief  \~russian ���������� ��������� �������
   ///         \~english Gets row collection
   CAdoRecordList   *Records();

   /// \brief  \~russian ��������� ���� �� ������ � �������
   ///         \~english Checks if the table has rows
   const bool HasRows() { return Records().Total()>0; }

   // method

   /// \brief  \~russian ������� ������ � ����������� ����������. ������� ������������ ������ ���� �����!
   ///         \~english Creates new row with neccessary scheme. You should use this method only!
   CAdoRecord       *CreateRecord();
  };
//--------------------------------------------------------------------
CAdoTable::~CAdoTable(void)
  {
   if(CheckPointer(_Columns)) delete _Columns;
   if(CheckPointer(_Records)) delete _Records;
  }
//--------------------------------------------------------------------
CAdoColumnList *CAdoTable::Columns()
  {
   if(!CheckPointer(_Columns))
      _Columns=CreateColumns();

   return _Columns;
  }
//--------------------------------------------------------------------
CAdoRecordList *CAdoTable::Records(void)
  {
   if(!CheckPointer(_Records))
      _Records=CreateRecords();

   return _Records;
  }
//--------------------------------------------------------------------
CAdoRecord *CAdoTable::CreateRecord()
  {
   CAdoRecord *rec=Records().CreateElement();
   rec.SetColumns(Columns());
   return rec;
  }
//+------------------------------------------------------------------+
